module tagion.vm.iwasm.IWasm;

import std.traits : isFunctionPointer, ParameterStorageClassTuple, ParameterStorageClass, ParameterTypeTuple,
ReturnType, isBasicType, Unqual, isCallable, isPointer;

import std.format;
import std.typecons : Tuple;
import std.string : toStringz, fromStringz;
//import bin = std.bitmanip;
import std.outbuffer;
import tagion.vm.iwasm.c.wasm_export;
import tagion.vm.iwasm.c.lib_export;
import tagion.TagionExceptions;
import core.stdc.stdlib : calloc, free;

import std.stdio;

extern(C)
bool wasm_runtime_call_wasm (
    wasm_exec_env_t exec_env,
    wasm_function_inst_t function_,
    uint argc,
    uint* argv);

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
        @nogc {
            wasm_module_t wasm_module;
            wasm_module_inst_t module_inst;
            wasm_exec_env_t exec_env;
        }
    }

    @trusted
    this(
        const WasmSymbols symbols,
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
        runtime_args.n_native_symbols = cast(uint)symbols.native_symbols.length;
        runtime_args.native_symbols = cast(NativeSymbol*)symbols.native_symbols.ptr;

        const runtime_init_success=wasm_runtime_full_init(&runtime_args);
        .check(runtime_init_success, "Faild to initialize iwasm runtime");

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

        exec_env = wasm_runtime_create_exec_env(module_inst, stack_size);

        // with (runtime_args) {
        //     mem_alloc_type =
        // }
        //wasm_engine=wasm_engine_new();
    }

    struct Function {
        wasm_function_inst_t func;
        string name;
    }

    @trusted
    Function lookup(string func_name) const {
        Function result;
        result.func=wasm_runtime_lookup_function(module_inst, toStringz(func_name), null);
        result.name=func_name;
        return result;
    }

    template SizeOf(Args...) {
        static if (Args.length is 0) {
            enum SizeOf=0;
        }
        else {
            enum _S=Args[0].sizeof;
            enum S=(_S % int.sizeof == 0)?_S:_S+int.sizeof;
            enum SizeOf=S+SizeOf!(Args[1..$]);
        }
    }
//    RetT call(RetT, Args...)(in Function f, Args args) {
    @trusted
    RetT call(RetT, Args...)(Function f, Args args) {
        auto out_buf=new OutBuffer;
        out_buf.alignSize(int.sizeof);
        out_buf.reserve(SizeOf!Args);
        foreach(i, arg; args) {
            out_buf.write(arg);
        }
        assert(out_buf.offset % int.sizeof == 0);
        auto args_buf=cast(uint[])(out_buf.toBytes);
        auto success=wasm_runtime_call_wasm(exec_env, f.func, cast(uint)args_buf.length, args_buf.ptr);
        .check(success, format("Wasm function failed %s %s(%s)\n%s",
                RetT.stringof, f.name, Args.stringof,
                fromStringz(wasm_runtime_get_exception(module_inst))));
        static if (!is(RetT==void)) {
             return *cast(RetT*)args_buf.ptr;
        }
    }

    @trusted
    int malloc(T)(uint size, ref T ptr) if (isPointer!T) {
        return wasm_runtime_module_malloc(module_inst, size, cast(void**)&ptr);
    }

    @trusted
    void free(int memory_index) {
        if(memory_index) {
            wasm_runtime_module_free(module_inst, memory_index);
        }
    }

    @trusted
    ~this() {
//        if(wasm_buffer) wasm_runtime_module_free(module_inst, wasm_buffer);
//        wasm_runtime_destroy_exec_env(exec_env);
        if (exec_env) {
            wasm_runtime_destroy_exec_env(exec_env);
        }
        wasm_runtime_deinstantiate(module_inst);
        wasm_runtime_destroy();
    }
}

@safe
struct WasmSymbols {
//    private {
        NativeSymbol[] native_symbols;
        size_t[string] native_index;
//    }

    void opCall(F)(string symbol, F func, string signature, void* attachment=null) if (isFunctionPointer!F) {
        .check(!(symbol in native_index), format("Native symbol %s is already definded", symbol));
        NativeSymbol native_symbol={
                symbol.toStringz,         // the name of WASM function name
                func,                     // the native function pointer
                signature.toStringz,	  // the function prototype signature, avoid to use i32
                attachment                // attachment if none the null
        };
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

    static string paramSymbols(F)() if (isCallable!F) {
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


version(none) {
//version(unittest) {
    import std.stdio;
    import std.math;
//    import tagion.vm.iwasm.c.wasm_export;
    import tagion.vm.iwasm.c.wasm_runtime_common;

//#include <stdio.h>
//#include "bh_platform.h"
//#include "wasm_export.h"
//#include "math.h"



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
    extern(C) {
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

//}
}

version(none)
extern(C) {
    int intToStr(int x, char* str, int str_len, int digit) {
        return 0;
    }
    int get_pow(int x, int y);
    int calculate_native(int n, int func1, int func2);
}
