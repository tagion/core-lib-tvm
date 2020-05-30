module tagion.vm.wamr.Wamr;

import std.traits : isFunctionPointer, ParameterStorageClassTuple, ParameterStorageClass, ParameterTypeTuple,
ReturnType, isBasicType, Unqual, isCallable, isPointer, isFunction, isFloatingPoint, isSomeString, ForeachType, hasMember;
import std.meta : staticMap, Alias, AliasSeq;
import std.typecons : Typedef, TypedefType;
import std.array : join;
import std.format;
import std.typecons : Tuple;
import std.string : toStringz, fromStringz;
//import bin = std.bitmanip;
import outbuffer=std.outbuffer;
import tagion.vm.wamr.c.wasm_export;
import tagion.vm.wamr.c.lib_export;
import tagion.vm.wamr.c.wasm_exec_env;
import tagion.TagionExceptions;
import core.stdc.stdlib : calloc, free;

import std.stdio;

@safe
class WamrException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}
alias check=Check!WamrException;


//alias ParamBuffer=outbuffer.OutBuffer;

//version(none)
class ParamBuffer : outbuffer.OutBuffer {
    // override void write(T)(T x) if (__traits(compiles, super.write(x))) {
    //     super.write(x);
    // }
    // version(none)
    // void write(T)(T x) {
    //     static if (hasMember!(T, "_append")) {
    //         x._append(this);
    //     }
    //     else {
    //         super.write(x);
    //     }
    // }
    this() {
//        super();
        alignSize(int.sizeof);
    }
    uint size() const pure {
        return cast(uint)(offset/int.sizeof);
    }
    uint* ptr() const {
        return cast(uint*)data.ptr;
    }
}

@safe
class WamrEngine {

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
        const WamrSymbols symbols,
        const uint heap_size,
        const uint stack_size,
        ref uint[] global_heap,
        immutable(ubyte[]) wasm_code,
        string module_name="env",
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
        .check(runtime_init_success, "Faild to initialize wamr runtime");

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
            static if (__traits(compiles, Args[0].wasm_sizeof)) {
                enum _S=Args[0].wasm_sizeof;
            }
            else {
                enum _S=Args[0].sizeof;
            }
            enum S=(_S % int.sizeof == 0)?_S:_S+int.sizeof;
            enum SizeOf=S+SizeOf!(Args[1..$]);
        }
    }
//    RetT call(RetT, Args...)(in Function f, Args args) {
    @trusted
    RetT call(RetT, Args...)(Function f, Args args) {
        auto param_buf=new ParamBuffer;
//        out_buf.alignSize(int.sizeof);
        param_buf.reserve(SizeOf!Args);
        foreach(i, arg; args) {
            alias BaseT=TypedefType!(Args[i]);
            static if (__traits(compiles, param_buf.write(cast(BaseT)arg))) {
                writefln("%d %s %s", i, arg, Args[i].stringof);
                param_buf.write(cast(BaseT)arg);
            }
            // static if (hasMembers(Args[i], "Arg") && is(TypedefType!(Args[i]) == Args[i].Arg)) {
            //     writefln("%d %s %s", i, arg, Args[i].stringof);
            //     param_buf.write(cast(TypedefType!(Args[i])arg);
            // }
            else {
                arg.write(param_buf);
            }
        }
        assert(param_buf.offset % int.sizeof == 0);
//        auto args_buf=cast(uint[])(param_buf.toBytes);
        auto success=wasm_runtime_call_wasm(exec_env, f.func, param_buf.size, param_buf.ptr);
        .check(success, format("Wasm function failed %s %s(%s)\n%s",
                RetT.stringof, f.name, Args.stringof,
                fromStringz(wasm_runtime_get_exception(module_inst))));
        static if (!is(RetT==void)) {
             return *cast(RetT*)param_buf.ptr;
        }
    }

    @trusted
    RetT _call(RetT, Args...)(Function f, Args args) {
        auto param_buf=new ParamBuffer;
        alias WasmArgs=WamrSymbols.toWasmTypes!(Args);
        param_buf.reserve(SizeOf!WasmArgs);
        static foreach(i, WP; WasmArgs) {
            static if (hasMember!(WP, "wasm_sizeof")) {
                pragma(msg, format("#### %s wasm_arg_%s;", WP.stringof, i));
                mixin(format(
                        q{
                            %s wasm_arg_%s;
                        }, WP.stringof, i));
            }
        }

        foreach(i, arg; args) {
            static if (WamrSymbols.isWasmBasicType!(Args[i])) {
                writefln("Simple arg %d <%s> %s" , i, arg, typeof(arg).stringof);
                param_buf.write(arg);
            }
            else {
                writefln("wasmarg arg %d", i);
                pragma(msg, "WasmParms[i] =", WasmArgs[i]);
                alias WasmType=WasmArgs[i];
                enum code=format(
                        q{
                            static if (__traits(compiles, WasmType(arg))) {
                                wasm_arg_%d = WasmType(arg);
                            }
                            else {
                                wasm_arg_%d = new WasmType(arg);
                            }
                            wasm_arg_%d.write(param_buf);

                        }, i, i, i);
                pragma(msg, code);
                mixin(code);
                // mixin(format(
                //         q{
                //             static if (__traits(compiles, WasmType(arg))) {
                //                 wasm_arg_%d = WasmType(arg);
                //             }
                //             else {
                //                 wasm_arg_%d = new WasmType(arg);
                //             }
                //             wasm_arg_%d.write(param_buf);
                //             writefln("wasm_arg_%d.wasm_ptr=%s index=%d", wasm_arg_%d.wasm_ptr, wasm_arg_%d.index);
                //         }, i, i, i, i, i, i, i));
                // auto wasm_arg=WasmType(this, arg);
                // wasm_arg.write(param_buf);
            }
        }

        import std.system : Endian;
        import std.bitmanip;
        auto buffer=param_buf.toBytes;
        writefln("### buffer=%s", buffer);
        //      size_t pos;
        foreach(i, T; WasmArgs) {
            static if (WamrSymbols.isWasmBasicType!(Args[i])) {
                writefln("arg %d %s", i, buffer.read!(T, Endian.littleEndian));
                    //        pos+=T.sizeof;
                    }
            else {
                writefln("arg \t%d %s wasm_ptr", i, buffer.read!(int, Endian.littleEndian));
                // pos=+int.sizeof;
                writefln("arg \t%d %s size", i, buffer.read!(int, Endian.littleEndian));
                // pos=+int.sizeof;
            }

        }

//        alias WasmArgs_2=WasmSymbols.toWasmTypes!(char[], int);
//        alias Func=typeof(_call);
//        alias WasmArgs_2=WasmSymbols.toWasmTypes!(ParameterTypeTuple!(typeof(_call)));
//        alias WasmArgs=Args;
        pragma(msg, WasmArgs);
//        pragma(msg, Alias!Args);
        pragma(msg, Args);
        enum symbols=WamrSymbols.paramsSymbols!(Args)()~WamrSymbols.listSymbols!(RetT);
        pragma(msg, symbols); //WasmSymbols.paramsSymbols!(Args)()~);
//        auto success=wasm_runtime_call_wasm(exec_env, f.func, param_buf.size, param_buf.ptr);
        auto success=wasm_runtime_call_wasm(exec_env, f.func, 2, param_buf.ptr);
        .check(success, format("Wasm function failed %s %s %s\n%s",
                RetT.stringof, f.name, Args.stringof,
                fromStringz(wasm_runtime_get_exception(module_inst))));
        foreach(i, arg; args) {
            static if (hasMember!(WasmArgs[i], "collect")) {
                writefln("collect");
                enum code=format(
                        q{
                            wasm_arg_%d.collect;
                        }, i);
                pragma(msg, code);
                mixin(code);
                // arg.collect;
                // mixin(format(
                //         q{
                //             wasm_arg_%d.collect;
                //         }, i));
            }
        }
        //import std.bitmanip;
        buffer=param_buf.toBytes;
//        size_t pos;
        foreach(i, T; WasmArgs) {
            static if (WamrSymbols.isWasmBasicType!(Args[i])) {
                writefln("return %d %s", i, buffer.read!(T,Endian.littleEndian));
                //        pos+=T.sizeof;
            }
            else {
                writefln("return \t%d %d wasm_ptr", i, buffer.read!(int, Endian.littleEndian));
                // pos=+int.sizeof;
                writefln("return \t%d %d size", i, buffer.read!(int, Endian.littleEndian));
                // pos=+int.sizeof;
            }

        }

        static if (!is(RetT==void)) {
             return *cast(RetT*)param_buf.ptr;
        }
    }

    @trusted
    wasm_ptr_t malloc(T)(uint size, ref T ptr) if (isPointer!T) {
        wasm_ptr_t result=wasm_runtime_module_malloc(module_inst, size, cast(void**)&ptr);
        return result;
    }

    @trusted
    void free(wasm_ptr_t memory_index) {
        if(memory_index) {
            wasm_runtime_module_free(module_inst, cast(TypedefType!wasm_ptr_t)memory_index);
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

    alias wasm_ptr_t=Typedef!(int, int.init, "wasm_ptr");

    class WasmArray(BaseU) {
        private {
            BaseU* ptr;
            uint size;
            wasm_ptr_t wasm_ptr;
            //   wasm_module_inst_t module_inst;
//            wasm_exec_env_t env;
            BaseU[] d_str;
        }
        enum symbol="*~"; // Pointer and len
        enum wasm_sizeof=wasm_ptr.sizeof+size.sizeof;
        static uint index;
        @trusted
        this(const(BaseU[]) str) {
            index++;
            //module_inst=eng.module_inst;
            //ptr=str.ptr;
            size=cast(uint)str.length;
            //this.env=env;
            pragma(msg, "this.env.module_inst ", typeof(module_inst));
            wasm_ptr=malloc(size, ptr);
            writefln("malloc wasm_ptr=%s", wasm_ptr);
            ptr[0..size]=str;
        }
        @trusted
        this(BaseU[] str) {
            index++;
            //module_inst=eng.module_inst;
            d_str=str;
            size=cast(uint)str.length;
            pragma(msg, "this.env.module_inst ", typeof(module_inst));
            wasm_ptr=malloc(size, ptr);
            //wasm_ptr=wasm_runtime_module_malloc(module_inst, size, cast(void**)&ptr);
            writefln("malloc wasm_ptr=%s", wasm_ptr);
            ptr[0..size]=str;
        }
        @trusted
        void collect() {
            if (d_str !is null) {
                d_str=ptr[0..size];
            }
        }
        @trusted
        void write(ParamBuffer buf) {
            const x=cast(TypedefType!wasm_ptr_t)wasm_ptr;
            writefln("ParamBuffer ptr=%d size=%d x=%d", wasm_ptr, size, x);
            buf.write(size);
            buf.write(cast(TypedefType!wasm_ptr_t)wasm_ptr);

            int y=-7704;
            buf.write(y);

        }
        @trusted
        ~this() {
            writefln("free wasm_ptr=%s", wasm_ptr);
            if (wasm_ptr != 0) {
                free(wasm_ptr);
            }
        }
    }
}

@safe
struct WamrSymbols {
    private {
        NativeSymbol[] native_symbols;
        size_t[string] native_index;
    }

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


    template toWasmType(T) {
        static if (isBasicType!T) {
            static if (isFloatingPoint!T) {
                alias toWasmType=T;
            }
            else static if (T.sizeof is int.sizeof) {
                alias toWasmType=int;
            }
            else static if (T.sizeof is long.sizeof) {
                alias toWasmType=long;
            }
            else static if (T.sizeof < int.sizeof) {
                alias toWasmType=int;
            }
            else static if (T.sizeof < long.sizeof) {
                alias toWasmType=long;
            }
        }
        else static if (is(T:U[], U) && isBasicType!U) {
            alias BaseU=Unqual!(U);
            alias toWasmType=WamrEngine.WasmArray!BaseU;
        }
        else {
            static assert(0, format("%s is not supported", T.stringof));
        }
    }

    alias isWasmBasicType(T)=isBasicType!T;

    version(none)
    template toWasmTypes(Params...) {
        static if (Params.length == 0) {
            alias toWasmTypes=AliasSeq!();
        }
        else {
            alias toWasmTypes=AliasSeq!(toWasmType!(Params[0]), toWasmTypes!(Params[1..$]));
        }
    }

    alias toWasmTypes(Params...) = staticMap!(toWasmType, Params);

    version(none)
    template ConvertToWasmParams(string code, Params...) {
        static if (Params.length == 0) {
            alias ConvertToWasmParams=code;
        }
        else {
            alias ConvertToWasmParams=void;

        }
    }

    static string convertToWasmParams(Params...)() {
        string[] result;
        static foreach(i, P; Params) {
            result~=format("%s param_%s", P.stringof, i);
        }
        return result.join(", ");
    }

    static string convertToWasmArguments(Params...)() {
        alias WasmParams=toWasmTypes!Params;
        string[] result;
        static foreach(i, P; Params) {
            result~=format("param_%s", i);
        }
        return result.join(", ");
    }

    void opCall(F)(string symbol, F func) if (isCallable!F) {
        enum signature=paramSymbols!F;
        pragma(msg, signature);
        static if (isFunction!F) {

            opCall(symbols, func, signature, null);
        }
        else {
            alias Returns=ReturnType!F;
            alias Params=ParameterTypeTuple!F;
            pragma(msg, "Param :", Params);
            alias WasmReturns=toWasmTypes!Returns;
            enum params=convertToWasmParams!Params();
            enum arguments=convertToWasmArguments!(Params);
            enum convert="// here goes the convert code";
            enum code=format(q{
                    static extern(C) %s caller(wasm_exec_env_t exec_env, %s) {
                        alias F=%s;
                        const dg=cast(F)exec_env.attachment;
                        %s
                        static if (is(Returns == void)) {
                            dg(%s);
                        }
                        else {
                            return dg(%s);
                        }
                    }
                }, WasmReturns.stringof, params, F.stringof, convert, arguments, arguments);
            pragma(msg, code);
            //mixin(code);
            //opCall(symbols, *caller, signature, func.ptr);
        }
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
        else static if (__traits(compiles, T.symbol)) {
            enum Symbol=T.symbol;
        }
        else {
            static assert(0, format("No wasm symbol found for %s", T.stringof));
        }
    }

    static string listSymbols(Args...)() {
        alias WasmParams=toWasmTypes!Args;
        string result;
        static foreach(i, P; WasmParams) {
            result~=Symbol!(WasmParams[i]);
        }
        return result;

    }

    static string paramsSymbols(Args...)() {
        return "("~listSymbols!(Args)()~")";
    }

    static string paramSymbols(F)() if (isCallable!F) {
        alias Params=ParameterTypeTuple!F;
        string result=paramsSymbols!(Params);
        alias Returns=ReturnType!F;
        static if (!is(Returns==void)) {
            alias WasmReturns=toWasmTypes!Returns;
            result~=Symbol!(WasmReturns);
        }
        return result;
    }
/+
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
+/
}

unittest {
    import src.native_impl;
    import std.stdio;
    import std.file : fread=read, exists;
    enum testapp_file="tests/basic/c/wasm-apps/testapp.wasm";
    immutable wasm_code = cast(immutable(ubyte[]))testapp_file.fread();
    WamrSymbols wasm_symbols;
    wasm_symbols("intToStr", &intToStr, "(i*~i)i");
    wasm_symbols("get_pow", &get_pow, "(ii)i");
    wasm_symbols("calculate_native", &calculate_native, "(iii)i");

    uint[] global_heap;
    global_heap.length=512 * 1024;

    auto wasm_engine=new WamrEngine(
        wasm_symbols,
        8092, // Stack size
        8092, // Heap size
        global_heap, // Global heap
        wasm_code,
        "env");

    //
    // Calling Wasm functions from D
    //
    float ret_val;

    {
        import std.conv : to;
        auto generate_float=wasm_engine.lookup("generate_float");
        ret_val=wasm_engine.call!float(generate_float, 10, 0.000101, 300.002f);
        assert(ret_val.to!string == "102010");
    }

    {
        auto float_to_string=wasm_engine.lookup("float_to_string");
        char* native_buffer;
        auto wasm_buffer=wasm_engine.malloc(100, native_buffer);
        scope(exit) {
            wasm_engine.free(wasm_buffer);
        }
        wasm_engine.call!void(float_to_string, ret_val, wasm_buffer, 100, 3);
        assert(fromStringz(native_buffer) == "102009.921");
    }

    {
        auto calculate=wasm_engine.lookup("calculate");
        auto ret=wasm_engine.call!int(calculate, 3);
        assert(ret == 120);
    }

    writeln("Passed");
}

unittest {
    int result;
    int add(int x) {
        result+=x;
        return 2*result;
    }

    pragma(msg, typeof(&add));
    WamrSymbols wasm_symbols;
    wasm_symbols("add", &add);


    string text(int x, float y, string str) {
        result++;
        return format("%s %s %s %d", x, y, str,  result);
    }

    wasm_symbols("text", &text);

}

unittest {
    import std.stdio;
    import std.file : fread=read, exists;
    enum testapp_file="tests/advanced/test_array.wasm";
    immutable wasm_code = cast(immutable(ubyte[]))testapp_file.fread();
    WamrSymbols wasm_symbols;
    uint[] global_heap;
    global_heap.length=512 * 1024;

    auto wasm_engine=new WamrEngine(
        wasm_symbols,
        8092, // Stack size
        8092, // Heap size
        global_heap, // Global heap
        wasm_code);

    auto get_result=wasm_engine.lookup("get_result");
    writefln("get_result = %d", wasm_engine.call!int(get_result,0));


    {
        auto char_array=wasm_engine.lookup("char_array");
        char[] array;
        const ret=wasm_engine._call!int(char_array, array);
        writefln("ret = %d %d", ret, wasm_engine.call!int(get_result,0));

    }
    version(none)
    {
        auto ref_char_array=wasm_engine.lookup("ref_char_array");
        char[] array;
        const ret=wasm_engine._call!int(ref_char_array, array);
        writefln("ret = %d", ret);
    }

    {
        auto const_char_array=wasm_engine.lookup("const_char_array");
        const(char[]) array="Hello";
        auto ret=wasm_engine._call!int(const_char_array, array);
        writefln("ret = %d %d", ret, wasm_engine.call!int(get_result,0));
    }

//        "env");
    // wasm_symbols("intToStr", &intToStr, "(i*~i)i");
    // wasm_symbols("get_pow", &get_pow, "(ii)i");
    // wasm_symbols("calculate_native", &calculate_native, "(iii)i");
}
