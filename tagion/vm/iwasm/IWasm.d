module tagion.vm.iwasm.IWasm;

import std.traits : isFunctionPointer, ParameterStorageClassTuple, ParameterStorageClass, ParameterTypeTuple,
ReturnType, isBasicType, Unqual, isCallable;

import std.format;
import std.typecons : Tuple;
import std.string : toStringz, fromStringz;

import tagion.vm.iwasm.c.wasm_export;
import tagion.vm.iwasm.c.lib_export;
import tagion.TagionExceptions;
import core.stdc.stdlib : calloc, free;


@safe
class IWasmException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}
alias check=Check!IWasmException;

@safe
struct IWasmEngine {
    private {
        RuntimeInitArgs runtime_args;
        // ubyte[] global_heap;
        char[] error_buf;
        wasm_module_t wasm_module;
        wasm_module_inst_t module_inst;
    }

    @trusted
    this(
        const NativeSymbol[] native_symbols,
        const uint heap_size,
        const uint stack_size,
        ref uint[] global_heap,
        string module_name,
        immutable(ubyte[]) wasm_code,
        const uint error_buf_size=128) {
        // global_heap.length=global_heap_size;
        error_buf.length=error_buf_size;
        runtime_args.mem_alloc_type = mem_alloc_type_t.Alloc_With_Pool;
        runtime_args.mem_alloc_option.pool.heap_buf = global_heap.ptr;
        runtime_args.mem_alloc_option.pool.heap_size = cast(uint)global_heap.length;

        // Native symbols need below registration phase
        runtime_args.native_module_name = toStringz(module_name);
        runtime_args.n_native_symbols = cast(uint)native_symbols.length;
        runtime_args.native_symbols = cast(NativeSymbol*)native_symbols.ptr;

        .check(wasm_runtime_full_init(&runtime_args), "Faild to initialize iwasm runtime");

        wasm_module=wasm_runtime_load(
            wasm_code.ptr,
            cast(uint)wasm_code.length,
            error_buf.ptr,
            cast(uint)error_buf.length);

        .check(wasm_module !is null, format("Faild to load the wasm module %s", module_name));

        module_inst = wasm_runtime_instantiate(
            wasm_module,
            stack_size,
            heap_size,
            error_buf.ptr,
            cast(uint)error_buf.length);

        .check(module_inst !is null, format("Instantiate wasm module failed. error: %s", fromStringz(error_buf.ptr)));


        // with (runtime_args) {
        //     mem_alloc_type =
        // }
        //wasm_engine=wasm_engine_new();
    }


    @trusted
    ~this() {
//        if(wasm_buffer) wasm_runtime_module_free(module_inst, wasm_buffer);
//        wasm_runtime_destroy_exec_env(exec_env);
        wasm_runtime_deinstantiate(module_inst);
        wasm_runtime_destroy();
    }
}

@safe
struct WasmModule {
    private {
        NativeSymbol[] native_symbols;
        size_t[string] native_index;
    }

    void opCall(F)(string symbol, F func, string signature, void* attachment=null) if (isCallable!F) {
        NativeSymbol native_symbol;
        native_symbol.symbol=symbol.toStringz;
        native_symbol.func_ptr=func;
        native_symbol.signature=signature.toStringz;
        native_symbol.attachment=attachment;
        .check(!(symbol in native_index), format("Native symbol %s is already definded", symbol));
        native_index[symbol]=native_symbols.length;
        native_symbols~=native_symbol;
    }

    template Symbol(T) {
        alias BaseT=Unqual!T;
        static if (is(T==long) || is(T==ulong)) {
            enum Symbol="I";
        }
        else static if (is(T==int) || is(T==uint)) {
            enum Symbol="i";
        }
        else static if (is(T==float)) {
            enum Symbol="f";
        }
        else static if (is(T==double)) {
            enum Symbol="F";
        }
        else static if (is(T==string)) {
            enum Symbol="$";
        }
        else {
            static assert(0, format("No wasm symbol found for %s", T.stringof));
        }
    }

    static string symbols(F)() if (isCallable!F) {
        alias Params=ParameterTypeTuple!F;
        string result;
        result~='(';
        static foreach(i, P; Params) {
            result~=Symbol!(Params[i]);
        }
        result~=')';

        alias Returns=ReturnType!F;
        static if (!is(Returns==void)) {
            results~=Symbol!(Returns);
        }
        return result;
    }

    version(none) {
        @trusted
            struct Environment(F) if(isCallable!F) {
            // @nogc:
            F caller;
            protected {
                @nogc wasm_compartment_t* compartment;
                @nogc wasm_trap_t* wasm_trap;
            }
            @disable this();
            this(F caller, wasm_compartment_t* compartment) {
                this.caller=caller;
                this.compartment=compartment;
            }
            wasm_trap_t* trap(Exception e) {
                if (wasm_trap !is null) {
                    wasm_trap_delete(wasm_trap);
                }
                return wasm_trap=wasm_trap_new(compartment, e.msg.ptr, e.msg.length);
            }
            ~this() {
                wasm_trap_delete(wasm_trap);
                compartment=null;
            }
        }

        version(none)
            @trusted
            struct WasmModule {
            wasm_module_t* wasm_module;

            this(WasmEngine e, string module_source) {
                wasm_module = wasm_module_new_text(e.engine, module_source.ptr, module_source.length);
                .check(wasm_module !is null, "Bad wasm source");

            }

            this(WasmEngine e, const(ubyte[]) module_binary) {
                wasm_module = wasm_module_new(e.engine, cast(const(char*))(module_binary.ptr), module_binary.length);
                .check(wasm_module !is null, "Bad wasm binary");
            }

            ~this() {
                wasm_module_delete(wasm_module);
            }
        }

        @trusted
            struct WasmFunction {
            wasm_func_t* wasm_func;
            @disable this();

            this(F) (F d_func, wasm_compartment_t* compartment, string debug_name=null) if (isFunctionPointer!F) {
                // wasm_functype_t* func_type;
                // wasm_functype_t* this(F)(F func) {
                alias Params=ParameterTypeTuple!F;
                pragma(msg, Params);
                auto param_types=new wasm_valtype_t*[Params.length];
                // scope(exit) {
                //     foreach(ref p; param_type) {
                //         free(p);
                //     }
                // }
                static foreach(i, P; Params) {
                    alias BaseT=Unqual!(Params[i]);
                    static if (is(BaseT==int) || is(BaseT==uint)) {
                        param_types[i]=wasm_valtype_new(wasm_valkind_enum.WASM_I32);
                    }
                    else static if (is(BaseT==long) || is(BaseT==ulong)) {
                        param_types[i]=wasm_valtype_new(wasm_valkind_enum.WASM_I64);
                    }
                    else static if (is(BaseT==float)) {
                        param_types[i]=wasm_valtype_new(wasm_valkind_enum.WASM_F32);
                    }
                    else static if (is(BaseT==float)) {
                        param_types[i]=wasm_valtype_new(wasm_valkind_enum.WASM_F64);
                    }
                    else {
                        static assert(0, format("Function parameter %s not supported", Params[i].stringof));
                    }
                }
                alias Returns=ReturnType!F;
                wasm_valtype_t*[] return_types;
                // scope(exit) {
                //     foreach(ref r; return_type) {
                //         free(r);
                //     }
                // }
                pragma(msg, "Returns=",Returns);
                static if (isBasicType!Returns) {
                    return_types.length=1;
                    alias RetT=Unqual!Returns;
                    enum i=0;
                    static if (is(RetT==int) || is(RetT==uint)) {
                        return_types[i]=wasm_valtype_new(wasm_valkind_enum.WASM_I32);
                    }
                    else static if (is(RetT==long) || is(RetT==ulong)) {
                        return_types[i]=wasm_valtype_new(wasm_valkind_enum.WASM_I64);
                    }
                    else static if (is(RetT==float)) {
                        return_types[i]=wasm_valtype_new(wasm_valkind_enum.WASM_F32);
                    }
                    else static if (is(RetT==float)) {
                        return_types[i]=wasm_valtype_new(wasm_valkind_enum.WASM_F64);
                    }
                    else {
                        static assert(0, format("Function parameter %s not supported", Returns.stringof));
                    }
                }
                else {
                    static assert(0, format("Return type %s is not yet supported", Returns.stringof));
                }

                pragma(msg, "param_types.ptr=", typeof(param_types.ptr));
                pragma(msg, "return_types.ptr =", typeof(return_types.ptr));
                wasm_functype_t* func_type = wasm_functype_new(param_types.ptr, param_types.length, return_types.ptr, return_types.length);
                scope(exit) {
                    wasm_functype_delete(func_type);

                }
                extern(C) void function (void*) finalizer;
                auto env=new Environment!F(d_func, compartment);
                auto void_env=cast(void*)env;
                auto func_callback=&callback!F;
                wasm_func = wasm_func_new_with_env (
                    compartment,
                    func_type,
                    func_callback,
                    void_env,
                    finalizer,
                    toStringz(debug_name));

            }

        }

        private {
            @nogc {
                wasm_compartment_t* compartment;
                wasm_store_t* store;
                const(char*) store_name_strz;
                const(char*) compartment_name_strz;
                wasm_instance_t* wasm_instance;
            }
            WasmFunction[] imports;
            wasm_module_t* wasm_module;
            WasmEngine engine;
            //WasmModule wasm_module;
        }

        @trusted
            private void createModule(string module_source) {
            wasm_module = wasm_module_new_text(engine.wasm_engine, module_source.ptr, module_source.length);
            .check(wasm_module !is null, "Bad wasm source");

        }

        @trusted
            private void createModule(const(ubyte[]) module_binary) {
            wasm_module = wasm_module_new(engine.wasm_engine, cast(const(char*))(module_binary.ptr), module_binary.length);
            .check(wasm_module !is null, "Bad wasm binary");
        }

        @disable this();
        @trusted
            this(M)(ref WasmEngine e, M module_source, string store_name, string compartment_name) {
            engine=e;
            compartment_name_strz=create_strz(compartment_name);
            store_name_strz=create_strz(store_name);
            compartment=wasm_compartment_new(e.wasm_engine, compartment_name_strz);
            store=wasm_store_new(compartment, store_name_strz);
            createModule(module_source);
        }

        @trusted
            ~this() {
            wasm_store_delete(store);
            wasm_compartment_delete(compartment);
            free(cast(void*)store_name_strz);
            free(cast(void*)compartment_name_strz);
            wasm_instance_delete(wasm_instance);
            wasm_module_delete(wasm_module);
        }


        @trusted
            static void set_params(T)(ref T p,  const wasm_val_t* args, ref size_t argi) {
            scope(success) {
                argi++;
            }
            alias BaseT=Unqual!T;
            static if (is(BaseT==int) || is(BaseT==uint)) {
                p=cast(T)(args[argi].i32);
            }
            else static if (is(BaseT==long) || is(BaseT==ulong)) {
                p=cast(T)(args[argi].i64);
            }
            else static if (is(BaseT==float)) {
                p=cast(T)(args[argi].f32);
            }
            else static if (is(BaseT==double)) {
                p=cast(T)(args[argi].f64);
            }
            else static if (is(T==struct)) {
                foreach(ref sub_p; p.tupleof) {
                    set_params(sub_p, argi, args);
                }
            }
            else static if (is(isTuple!T)) {
                foreach(ref sub_p; p) {
                    set_params(sub_p, argi, args);
                }
            }
            else {
                static assert(0, format("Paramter type %s is not supported yet", T.stringof));
            }
        }

        @trusted
            static void set_results(T)(in T returns, wasm_val_t* wasm_results, const size_t reti=0) {
            static if (isBasicType!T) {
                alias BaseT=Unqual!T;
                static if(is(BaseT==int) || is(BaseT==uint)) {
                    wasm_results[reti].i32=cast(int)returns;
                }
                else static if(is(BaseT==long) || is(BaseT==ulong)) {
                    wasm_results[reti].i64=cast(long)returns;
                }
                else static if(is(BaseT==float)) {
                    wasm_results[reti].f32=cast(float)returns;
                }
                else static if(is(BaseT==double)) {
                    wasm_results[reti].f64=cast(double)returns;
                }
                else {
                    static assert(0, format("Return type %s not supported", T.stringof));
                }
            }
            else {
                static assert(0, format("Return type %s not implemented yet", T.stringof));
            }
        }

        private static void*[] context;

        extern(C) {
            @trusted
                private static wasm_trap_t* callback(F)(const wasm_val_t* args, wasm_val_t* results) if (isCallable!F) {
                alias Env=Environment!F;
                pragma(msg, "F=", F, " : ", isFunctionPointer!F);
                auto func_env=cast(Env*)env;
                Tuple!(ParameterTypeTuple!(F)) params;
                pragma(msg, ParameterTypeTuple!(F), " # ",  typeof(params));
                size_t argi;
                foreach(ref p; params) {
                    set_params(p, args, argi);
                }

                try {
                    static if (is(Returns!F==void)) {
                        func_env.caller(params.expand);
                    }
                    else {
                        auto returns=func_env.caller(params.expand);
                        set_results(returns, results);
                    }
                }
                catch (Exception e) {
                    return func_env.trap(e);
                }
                return null;
            }
        }

        /++
         Defines a callback function from Wasm to D
         +/
        @trusted
            void external(F)(F func, string debug_name=null) if (isCallable!F) {
            pragma(msg, "is(F==function)=", is(F==function), " ", isFunctionPointer!F) ;
            alias PSTC=ParameterStorageClassTuple!F;
            static foreach(i;0..PSTC.length) {
                static assert(PSTC[i] is ParameterStorageClass.none,
                    format("Parameter class '%s' is not allowed %s", PSTC[i], ParameterStorageClass.none));
            }
//        enum id=typeid(F);
            if (debug_name is null) {
                debug_name=F.stringof;
            }
            pragma(msg, typeof(WasmFunction(func, compartment, debug_name)));
            imports~=WasmFunction(func, compartment, debug_name);
            // return this;
        }

        void internal(F)(ref F func, const uint index, string debug_name=0) if(isFunctionPointer!F) {

        }
        /*
          tagion/vm/wavm/Wavm.d(364): Error:
          function wavm.c.wavm.wasm_instance_new(
          wasm_store_t*,
          const(wasm_module_t)*,
          const(wasm_extern_t*)* imports,
          wasm_trap_t**,
          const(char)* debug_name)
          is not callable using argument types (
          wasm_store_t*,
          wasm_engine_t*,
          wasm_extern_t**,
          typeof(null),
          immutable(char)*)
        */
/*
  tagion/vm/wavm/Wavm.d(328): Error: function
  wavm.c.wavm.wasm_instance_new(
  wasm_store_t*,
  const(wasm_module_t)*,
  const(wasm_extern_t*)* imports,
  wasm_trap_t**,
  const(char)* debug_name)
  is not callable using argument types (
  wasm_store_t*,
  const(wasm_module_t*),
  wasm_extern_t*[],
  typeof(null),
  immutable(char)*)
*/
        @trusted
            private void _import(string debug_name) {
            if (wasm_instance is null) {
                @nogc wasm_extern_t*[] _imports;
                pragma(msg, typeof((cast(wasm_extern_t**)calloc((wasm_extern_t*).sizeof, imports.length))[0..imports.length]));
                _imports=(cast(wasm_extern_t**)calloc((wasm_extern_t*).sizeof, imports.length))[0..imports.length];
                scope(exit) {
                    free(_imports.ptr);
                }
                foreach(i, imp; imports) {
                    _imports[i]=wasm_func_as_extern(imp.wasm_func);
                }
                wasm_instance = wasm_instance_new(store, wasm_module, _imports.ptr, null, "instance\0".ptr);
            }
        }
    }
}


version(unittest) {
    import std.stdio;
    import std.math;
    import tagion.vm.iwasm.c.wasm_export;
    import tagion.vm.iwasm.c.wasm_runtime_common;

//#include <stdio.h>
//#include "bh_platform.h"
//#include "wasm_export.h"
//#include "math.h"

    extern(C) {

// extern bool
// wasm_runtime_call_indirect(wasm_exec_env_t exec_env,
//                            uint element_indices,
//                            uint argc, uint[] argv);

// The first parameter is not exec_env because it is invoked by native funtions
        void reverse(char* str, int len) {
            int i = 0, j = len - 1;
            char temp;
            while (i < j) {
                temp = str[i];
                str[i] = str[j];
                str[j] = temp;
                i++;
                j--;
            }
        }

// The first parameter exec_env must be defined using type wasm_exec_env_t
// which is the calling convention for exporting native API by WAMR.
//
// Converts a given integer x to string str[].
// digit is the number of digits required in the output.
// If digit is more than the number of digits in x,
// then 0s are added at the beginning.
        int intToStr(wasm_exec_env_t exec_env, int x, char* str, int str_len, int digit) {
            int i = 0;

            writefln("calling into native function: %s", __FUNCTION__);

            while (x) {
                // native is responsible for checking the str_len overflow
                if (i >= str_len) {
                    return -1;
                }
                str[i++] = (x % 10) + '0';
                x = x / 10;
            }

            // If number of digits required is more, then
            // add 0s at the beginning
            while (i < digit) {
                if (i >= str_len) {
                    return -1;
                }
                str[i++] = '0';
            }

            reverse(str, i);

            if (i >= str_len)
                return -1;
            str[i] = '\0';
            return i;
        }

        int get_pow(wasm_exec_env_t exec_env, int x, int y) {
            writefln("calling into native function: %s\n", __FUNCTION__);
            return cast(int)pow(x, y);
        }

        int
            calculate_native(wasm_exec_env_t exec_env, int n, int func1, int func2) {
            writefln("calling into native function: %s, n=%d, func1=%d, func2=%d",
                __FUNCTION__, n, func1, func2);

            uint[] argv = [ n ];
            if (!wasm_runtime_call_indirect(exec_env, func1, 1, argv.ptr)) {
                writeln("call func1 failed");
                return 0xDEAD;
            }

            uint n1 = argv[0];
            writefln("call func1 and return n1=%d", n1);

            if (!wasm_runtime_call_indirect(exec_env, func2, 1, argv.ptr)) {
                writeln("call func2 failed");
                return 0xDEAD;
            }

            uint n2 = argv[0];
            writefln("call func2 and return n2=%d", n2);
            return n1 + n2;
        }
    }

    extern(C) {
        int intToStr(int x, char* str, int str_len, int digit);
        int get_pow(int x, int y);
        int calculate_native(int n, int func1, int func2);
    }
}


unittest {
    import std.stdio;
    import std.file : fread=read, exists;
//    enum REPOROOT="../../../";
//    enum testapp_file=REPOROOT~"tests/basic/c/wasm-apps/testapp.wasm";
    enum testapp_file="tests/basic/c/wasm-apps/testapp.wasm";
    immutable wasm_code = cast(immutable(ubyte[]))testapp_file.fread();

    WasmModule wasm_module;
    wasm_module("intToStr", &intToStr, "(i*~i)i");
    wasm_module("get_pow", &get_pow, "(ii)i");
    wasm_module("calculate_native", &calculate_native, "(iii)i");

    uint[] global_heap;
    global_heap.length=512 * 1024;

    auto wasn_engine=IWasmEngine(
        wasm_module.native_symbols,
        8092, // Stack size
        8092, // Heap size
        global_heap,
        __FUNCTION__,
        wasm_code);

//    enum current_dir=getcwd;
//    enum ee="defile.mk".exists;
//    pragma(msg, "dfiles.mk ", ee );
    writefln("%s %s", testapp_file, testapp_file.exists);
//    writefln("%s",
//}
}

version(none)
unittest {
    import std.array : join;
    import std.stdio;
    string hello_wast = [
        "(module",
        "  (import \"\" \"hello\" (func $1 (param i32) (result i32)))",
        "  (func (export \"run\") (param i32) (result i32)",
        "    (call $1 (local.get 0))",
        "  )",
        ")"].join("\n");

    //    @safe
    static int hello_callback(int x) {
        writefln("Hello world! (argument = %d)", x);
        auto result=x+1;
        writefln("results %s\n\0", x);
        return result;
    }

    auto e=new WasmEngine;
//     e.wasmModule("hello_wast", hello_wast);
    auto wasmModule=WasmModule(e, hello_wast, "store", "compartment");
    pragma(msg, typeof(&hello_callback));

    wasmModule.external(&hello_callback);
}

/++
 32 check_symbol_signature(const WASMType *type, const char *signature)
 33 {
 34     const char *p = signature, *p_end;
 35     char sig_map[] = { 'F', 'f', 'I', 'i' }, sig;
 36     uint32 i = 0;
 37
 38     if (!p || strlen(p) < 2)
 39         return false;
 40
 41     p_end = p + strlen(signature);
 42
 43     if (*p++ != '(')
 44         return false;
 45
 46     if ((uint32)(p_end - p) < type->param_count + 1)
 47         /* signatures of parameters, and ')' */
 48         return false;
 49
 50     for (i = 0; i < type->param_count; i++) {
 51         sig = *p++;
 52         if (sig == sig_map[type->types[i] - VALUE_TYPE_F64])
 53             /* normal parameter */
 54             continue;
 55
 56         if (type->types[i] != VALUE_TYPE_I32)
 57             /* pointer and string must be i32 type */
 58             return false;
 59
 60         if (sig == '*') {
 61             /* it is a pointer */
 62             if (i + 1 < type->param_count
 63                 && type->types[i + 1] == VALUE_TYPE_I32
 64                 && *p == '~') {
 65                 /* pointer length followed */
 66                 i++;
 67                 p++;
 68             }
 69         }
 70         else if (sig == '$') {
 71             /* it is a string */
 72         }
 73         else {
 74             /* invalid signature */
 75             return false;
 76         }
 77     }
 78
 79     if (*p++ != ')')
 80         return false;
 81
 82     if (type->result_count) {
 83         if (p >= p_end)
 84             return false;
 85         if (*p++ != sig_map[type->types[i] - VALUE_TYPE_F64])
 86             return false;
 87     }
 88
 89     if (*p != '\0')
 90         return false;
 91
 92     return true;
 93 }
 +/
