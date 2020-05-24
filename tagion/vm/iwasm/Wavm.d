module tagion.vm.wavm.Wavm;

import std.traits : isFunctionPointer, ParameterStorageClassTuple, ParameterStorageClass, ParameterTypeTuple,
ReturnType, isBasicType, Unqual, isCallable;

import std.format;
import std.typecons : Tuple;
import tagion.vm.wavm.c.wavm;

import tagion.TagionExceptions;
import core.stdc.stdlib : calloc, free;
import std.string : toStringz;

@safe
class WasmException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

alias check=Check!WasmException;

const(char*) create_strz(string str) {
    auto strz=cast(char*)calloc(str.length+1, 1);
    strz[0..str.length]=str;
    return strz;
}

@safe
class WasmEngine {
    @nogc private {
        wasm_engine_t* wasm_engine;
    }

    @trusted
    this() {
        wasm_engine=wasm_engine_new();
    }

    @trusted
    ~this() {
        wasm_engine_delete(wasm_engine);
    }

    // void wasmModule(string module_source) {
    //     return WasmModule(this, module_source);
    // }

    // void wasmModule(string module_name, const(ubyte[]) module_binary) {
    //     _wasm_modules[module_name]=WasmModule(this, module_binary);
    // }

    // const(wasm_module_t*) opIndex(in string module_name) {
    //     return _wasm_modules[module_name].wasm_module;
    // }

}

@safe
struct WasmModule {
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
