module tagion.vm.wavm.Wavm;

import tagion.vm.wavm.c.wavm;

struct WasmEngine {
    private {
        wasm_engine_t* engine;
    }

    immutable(string) compartment_name;
    immutable(string) store_name;

    this(string compartment_name, ) {
        this.compartment_name=compartment_name;
        this.store_name=store_name
            engine=wasm_engine_new();
    }

    ~this() {
        wasm_engine_delete(engine);
    }

    WasmModule wasmModule(string module_source) {
        return WasmModule(this, module_source);
    }

    WasmModule wasmModule(string const(ubyte[]) module_binary) {
        return WasmModule(this, module_binary);
    }

}

struct WasmModule {
    private {
        wasm_module_t* wasm_module;
    }

    this(ref WasmEngine e, string module_source) {
        wast_module = wasm_module_new_text(e.engine, module_source.ptr, module_source.length);
        .check(!wast_module, "Bad wasm source");

    }

    this(ref WasmEngine e, const(ubyte[]) module_binary) {
        wast_module = wasm_module_new_(e.engine, cast(const(char*))(module_binary.ptr), module_binary.length);
        .check(!wast_module, "Bad wasm binary");
    }

    ~this() {
        wasm_module_delete(wast_module);
    }

}

struct WasmInstance {
    struct WasmFuncion {
        union {
            wasm_func_callback_t wasm_func;
            wasm_func_callback_with_env_t wasm_func_with_env;
        }
        immutable bool with_env;
        @disable this();
        this (wasm_func_callback_t wasm_func) {
            this.wasm_func=wasm_func;
            with_env=false;
        }
        this (wasm_func_callback_with_env_t wasm_func_with_env) {
            this.wasm_func_with_env=wasm_func_with_env;
            with_env=true;
        }
        @nogc {
            wasm_trap_t* wasm_trap;
        }
    }

    private {
        @nogc {
            wasm_compatement_t* compartment;
            wasm_store_t* store;
            char* store_name_strz;
            char* compartment_name_str;
        }
        WasmFuncion[TypeInfo] imports;
    }

    this(ref WasmEngine e, string store_name, string compartment_name) {
        compartment_name_strz=calloc(compartment_name_name.length+1, 1);
        compartment_name_strz[0..compartment_name.length]=compartment_name;
        store_name_strz=calloc(store_name_name.length+1, 1);
        store_name_strz[0..store_name.length]=store_name;
        compartment=wasm_compartment_new(e.engine, compartment_name_str);
        store=wasm_store_new(compartment, store_name_str);
    }

    ~this() {
        wasm_store_delete(store);
        wasm_compartment_delete(compartment);
        free(store_name_str);
        free(compartment_name_str);
        foreach(ref imp; imports) {
            wasm_trap_delete(imp);
        }
    }

    static void set_params(T)(ref T p,  const wasm_val_t* args, ref size_t argi) {
        scope(success) {
            argi++;
        }
        static if (is(T : const(int) || (T: const(uint)))) {
            p=cast(T)(args[argi].i32);
        }
        else static if (is(T : const(long) || (T: const(ulong)))) {
            p=cast(T)(args[argi].i64);
        }
        else static if (is(T : const(float))) {
            p=cast(T)(args[argi].f32);
        }
        else static if (is(T : const(double))) {
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

    static void set_results(T)(in T result, wasm_val_t* wasm_results, const size_t reti=0) {
        static if (isBasicType!T) {
            alias BaseT=Unqual!T;
            static if(is(BaseT==int) || is(BaseT==uint)) {
                wasm_result[reti].i32=cast(int)result;
            }
            else static if(is(BaseT==long) || is(BaseT=ulong)) {
                wasm_result[reti].i64=cast(long)result;
            }
            else static if(is(BaseT==float)) {
                wasm_result[reti].f32=cast(float)result;
            }
            else static if(is(BaseT==double)) {
                wasm_result[reti].f64=cast(double)result;
            }
            else {
                static assert(0, format("Return type %s not supported", T.stringof));
            }
        }
        else {
            static assert(0, format("Return type %s not implemented yet", T.stringof));
        }
    }

    /++
     Defines a callback function from Wasm to D
     +/
    ref WasmInstance opCall(F)(F func) if (is(F==function)) {
        alias PSTC=ParameterStorageClassTuple!F;
        static foreach(i;0..PSTC.length) {
            static assert(is(PSTC[i] is ParameterStorageClass.none),
                format("Parameter class %s is not allowed", PSTC[i].stringof));
        }
        extern(C) {
            wasm_trap_t* callback(const wasm_val_t* args, wasm_val_t* results) {
                Parameters!F params;
                size_t argi;
                foreach(ref p; params) {
                    set_paranms(p, argi, args);
                }

                try {
                    static if (is(Returns!F==void)) {
                        func(params.expand);
                    }
                    else {
                        auto returns=func(params.expand);
                        set_results(results, results);
                    }
                }
                catch (Exception e) {
                    if (imports[F.typeid].wasm_trap !is null) {
                        wasm_trap_delete(imports[F.typeid].wasm_trap);
                    }
                    imports[F.typeid].wasm_trap=wasm_trap_new(compartment, e.msg, e.msg.length);
                    return imports[F.typeid].wasm_trap;
                }
                return null;
            }
        }
        imports[F.typeid]=WasmFunction(&callback);
        return this;
    }

}
