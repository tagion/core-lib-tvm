module tagion.tvm.TVM;

import std.traits : isFunctionPointer, ParameterStorageClassTuple,
    ParameterStorageClass, ParameterTypeTuple, ReturnType, Fields,
    isBasicType, Unqual, isCallable, isPointer, isFunction, isFloatingPoint,
isSomeString, ForeachType, hasMember, isImplicitlyConvertible, TemplateOf, TemplateArgsOf,
PointerTarget;
import std.meta : staticMap, Alias, AliasSeq, allSatisfy, anySatisfy, ApplyLeft;
import std.typecons : Typedef, TypedefType;
import std.array : join;
import std.format;
import std.typecons : Tuple;
import std.string : toStringz, fromStringz;
import std.exception : assumeWontThrow;

import outbuffer = std.outbuffer;
import tagion.tvm.c.wasm_export;
import tagion.tvm.c.lib_export;
import tagion.tvm.c.wasm_exec_env;
import core.stdc.stdlib : calloc, free;
import std.stdio;

alias wasm_ptr_t = Typedef!(int, int.init, "wasm_ptr");

struct WasmPointerType(T) {
    static assert(isPointer!T);
    wasm_ptr_t wasm_ptr;
    T _value;
    auto opDispatch(string name)() {
        mixin(format!(q{return _value.%s;})(name));
    }
}

//version(none)
@safe class ParamBuffer : outbuffer.OutBuffer {
    this() {
        alignSize(int.sizeof);
    }

    final uint size() const pure {
        return cast(uint)(offset / int.sizeof);
    }

    final uint* ptr() @trusted const {
        return cast(uint*) data.ptr;
    }
    // final write(S)(ref const S s) if(is(S == struct)) {
    //     static if (isWasmType!S) {
    //         write((cast(void*)&s)[0..S.sizeof]);
    //     }
    //     else {
    //         static assert(0, "Not implemented yet!!");
    //     }
    // }
}

alias isWasmTypes(T...) = allSatisfy!(isWasmType, T);

template isWasmType(alias S) {
    static if (is(S == struct)) {
        enum isWasmType = isWasmTypes!(Fields!S);
    }
    else {
        // enum isTypeEqual(T1, T2) = is(T1 == T2);
        // pragma(msg, isTypeEqual!(S, int));
        enum isWasmType = anySatisfy!(ApplyLeft!(isImplicitlyConvertible, S),
                    int, long, float, double);
        // enum isWasmType = anySatisfy!(ApplyLeft!(isTypeEqual, S),
        //      int, long, float, double);
    }
}

static unittest {
    pragma(msg, "isWasmType!int ", isWasmType!int);
    static assert(isWasmType!int);
    static struct S {
        int x;
        long y;
        float f;
        double d;
        uint ux;
        ulong uy;
        char c;
        byte b;
        ubyte ub;
        short s;
        ushort us;
    }

    static assert(isWasmType!S);
}

@safe class TVMEngine {
    private {
        RuntimeInitArgs runtime_args;
        char[] error_buf;
        @nogc {
            wasm_module_t wasm_module;
            wasm_module_inst_t module_inst;
            wasm_exec_env_t exec_env;
        }
    }

    this(const WamrSymbols symbols, const uint heap_size, const uint stack_size,
            ref uint[] global_heap, immutable(ubyte[]) wasm_code,
            string module_name = "env", const uint error_buf_size = 128) nothrow @trusted {
        // global_heap.length=global_heap_size;
        error_buf.length = error_buf_size;
        runtime_args.mem_alloc_type = mem_alloc_type_t.Alloc_With_Pool;
        runtime_args.mem_alloc_option.pool.heap_buf = global_heap.ptr;
        runtime_args.mem_alloc_option.pool.heap_size = cast(uint) global_heap.length;

        // Native symbols need below registration phase
        runtime_args.native_module_name = toStringz(module_name);
        runtime_args.n_native_symbols = cast(uint) symbols.native_symbols.length;
        runtime_args.native_symbols = cast(NativeSymbol*) symbols.native_symbols.ptr;

        const runtime_init_success = wasm_runtime_full_init(&runtime_args);
        //.check(runtime_init_success, "Faild to initialize wamr runtime");

        wasm_module = wasm_runtime_load(wasm_code.ptr,
                cast(uint) wasm_code.length, error_buf.ptr, cast(uint) error_buf.length);

        //.check(wasm_module !is null, format("Faild to load the wasm module %s", module_name));

        module_inst = wasm_runtime_instantiate(wasm_module, stack_size,
                heap_size, error_buf.ptr, cast(uint) error_buf.length);

        exec_env = wasm_runtime_create_exec_env(module_inst, stack_size);

    }

    struct Function {
        wasm_function_inst_t func;
        string name;
    }

    Function lookup(string func_name) const nothrow @trusted {
        Function result;
        result.func = wasm_runtime_lookup_function(module_inst, toStringz(func_name), null);
        result.name = func_name;
        return result;
    }

    template SizeOf(Args...) {
        static if (Args.length is 0) {
            enum SizeOf = 0;
        }
        else {
            static if (__traits(compiles, Args[0].wasm_sizeof)) {
                enum _S = Args[0].wasm_sizeof;
            }
            static if (is(Args[0] == struct)) {
                enum _S = SizeOf!(Fields!(Args[0]));
            }
            else {
                enum _S = Args[0].sizeof;
            }
            enum S = (_S % int.sizeof == 0) ? _S : (_S / int.sizeof) * int.sizeof + int.sizeof;
            enum SizeOf = S + SizeOf!(Args[1 .. $]);
        }
    }

    final RetT call(RetT, Args...)(Function f, Args args) @trusted {
        version (BigEndian) static assert(0, "Big-endian not supproted yet!");
        static assert(Args.length !is 0,
                format(
                    "No arguments for is not allowed because it causes a segment faild inside the wamr"));
        auto param_buf = new ParamBuffer;
        alias WasmArgs = WamrSymbols.toWasmTypes!(Args);
        param_buf.reserve(SizeOf!WasmArgs);
        static foreach (i, WP; WasmArgs) {
            static if (hasMember!(WP, "wasm_sizeof")) {
                mixin(format(q{
                            %s wasm_arg_%s;
                        }, WP.stringof, i));
            }
        }

        foreach (i, ref arg; args) {
            alias WasmType = TypedefType!(WasmArgs[i]);
            static if (isCallable!WasmType) {
                enum wasmConvertCallback = true;
                alias Params = ParameterTypeTuple!WasmType;
                static assert(Params.length is 1,
                        format!"Only one parameter is allowed for the WasmConverter %s"(
                            WasmType.stringof));
                alias Returns = ReturnType!WasmType;
            }
            else {
                enum wasmConvertCallback = false;
                // alias Params=AliasSeq!(void);
                // alias Returns=void;
            }

            static if (WamrSymbols.isWasmBasicType!(WasmType)) {
                param_buf.write(cast(WasmType) arg);
            }
            else static if (wasmConvertCallback) {
                alias S = Params[0];
                pragma(msg, "-> is(S == struct) ", is(S == struct), " ", isPointer!S);
                static if (is(S == struct) && is(WasmType == WamrSymbols.structToWasmType!S)) {
                    pragma(msg, "S ", S);
                    //                alias S=Params[0];
                    pragma(msg, "isWasmType!S ", isWasmType!S,
                            " isPointer ", isPointer!S, " ", S);
                    static if (isWasmType!S) {
                        S* _s;
                        //enum WasmSize = SizeOf!S;
                        const s_wasm_ptr = this.map_malloc(arg, _s);
                        writefln("s_wasm_ptr=%d %s %s", s_wasm_ptr, _s, SizeOf!S);
                        param_buf.write(cast(int) s_wasm_ptr);
                    }
                    else static if (is(S == WasmPointerType!(TemplateArgsOf!S))) {
                        param_buf.write(cast(int) arg.wasm_ptr);


                        pragma(msg, "TemplateArgsOf ", TemplateArgsOf!S);
                        pragma(msg, "TemplateOf ", is(S == WasmPointerType!(TemplateArgsOf!S)));
                    }
                    else {
                    alias Temp= TemplateOf!(S);
                    pragma(msg, "TemplateOf ", Temp.stringof, " ", __traits(isTemplate, S));

                    pragma(msg, "TemplateArgs ", TemplateArgsOf!S);
                        static assert(0,
                                "Not implemented yet (Must convert D types to WasmTypes)!!");
                    }
                }
                else static if (isPointer!(S)) {
                    alias Target = PointerTarget!(S);
                    static if (is(Target == struct)) {
                        pragma(msg, "Pointer struct ", WasmType);
                        const s_wasm_ptr = this.malloc(arg);
                        param_buf.write(cast(int) s_wasm_ptr);
                        writefln("s_wasm_ptr=%s", s_wasm_ptr);
                        writefln("arg=%s", arg);

                    }
                    else {
                        static assert(0, format!"Type %s is not supported yet!"(WasmType.stringof));
                    }
                }
            }
            else static if (is(WasmType == class)) {
                enum code = format(q{
                            wasm_arg_%d = new WasmType(arg);
                            wasm_arg_%d.write(param_buf);
                        }, i, i);
                //pragma(msg, code);
                mixin(code);
            }
            else {
                pragma(msg, isCallable!WasmType);
//                pragma(msg, WamrSymbols.structToWasmType!(Params[0]));
                static assert(0, format!"Unsuported type %s"(WasmType.stringof));
            }
        }

        const success = wasm_runtime_call_wasm(exec_env, f.func, param_buf.size, param_buf.ptr);

        foreach (i, arg; args) {
            alias WasmType = TypedefType!(WasmArgs[i]);
            static if (hasMember!(WasmType[i], "collect")) {
                enum code = format(q{
                            wasm_arg_%d.collect;
                        }, i);
                mixin(code);
            }
        }
        static if (!is(RetT == void)) {
            return *cast(RetT*) param_buf.ptr;
        }
    }

    final wasm_ptr_t malloc(T)(uint size, ref T ptr) nothrow @trusted @nogc
            if (isPointer!T) {
        wasm_ptr_t result = wasm_runtime_module_malloc(module_inst, size, cast(void**)&ptr);
        return result;
    }

    final wasm_ptr_t malloc(T)(ref T ptr) nothrow @trusted @nogc
            if (isPointer!T && is(PointerTarget!T == struct)) {
//                printf("malloc %s\n", T.stringof.ptr);
        return malloc(T.sizeof, ptr);
    }

    final WasmPointerType!T alloc(T)() nothrow @trusted @nogc
        if (isPointer!T && is(PointerTarget!T == struct)) {
            pragma(msg, "alloc ", T);
//            alias Target = PointerTarget!T;
            WasmPointerType!T result;
            result.wasm_ptr=malloc(result._value);
            return result;
        }

    final void free(S)(ref S ptr) nothrow @trusted @nogc {
        static if (is(TypedefType!S == int)) {
        // if (memory_index) {
            wasm_runtime_module_free(module_inst, cast(int) ptr);
        }
        else static if (is(S == WasmPointerType!(TemplateArgsOf!S))) {
            wasm_runtime_module_free(module_inst, cast(TypedefType!wasm_ptr_t)
            ptr.wasm_ptr);
        }
        else {
            static assert(0, format!"Type %s not supported"(PTR.stringof));
        }
    }
    // }

    version(none)
    final void free(S)(ref S ptr) nothrow @trusted @nogc
        if (!is(TypedefType!PTR == int) && is(S == WasmPointerType!(TemplateArgsOf!S))) {
            wasm_runtime_module_free(module_inst, cast(TypedefType!wasm_ptr_t)
            ptr.wasm_ptr);
        }
    //     else {
    //         pragma(msg, "ref S ", S);
    //         static assert(0, "S "~S.stringof~" not supported");
    //     }
    // }

    final wasm_ptr_t map_malloc(T, S)(const ref S s, ref T ptr) nothrow @trusted @nogc
        if (isPointer!T && is(S == struct)) {
        wasm_ptr_t result = wasm_runtime_module_malloc(module_inst, S.sizeof, cast(void**)&ptr);
        version (BigEndian) static assert(0, "Big-endian not supproted yet!");
        import core.stdc.string : memcpy;

        memcpy(ptr, &s, S.sizeof);
        return result;
    }

    /++
     This function copies a struct T to the the wasm runtime memory and return the location.
     Returns:

     +/
    // version(none)
    // final wasm_ptr_t mirror(T)(ref const T ptr) nothrow @trusted @nogc
    //     static if (is(T==struct)) {
    //         wasm_ptr_t result = wasm_runtime_malloc(module_inst, T.sizeof, cast(void**)&ptr);
    //         return result;
    //     }
    //     else {
    //         static assert(0, );
    //     }
    // }

    ~this() @trusted {
        if (exec_env) {
            wasm_runtime_destroy_exec_env(exec_env);
        }
        wasm_runtime_deinstantiate(module_inst);
        wasm_runtime_destroy();
    }

    class WasmArray(BaseU) {
        private {
            BaseU* ptr;
            uint size;
            wasm_ptr_t wasm_ptr;
            BaseU[] d_str;
        }
        enum symbol = "*~"; // Pointer and len
        enum wasm_sizeof = wasm_ptr.sizeof + size.sizeof;
        static uint index;
        this(const(BaseU[]) str) nothrow @trusted @nogc {
            index++;
            size = cast(uint) str.length;
            wasm_ptr = malloc(size, ptr);
            ptr[0 .. size] = str;
        }

        this(BaseU[] str) nothrow @trusted @nogc {
            index++;
            d_str = str;
            size = cast(uint) str.length;
            wasm_ptr = malloc(size, ptr);
            ptr[0 .. size] = str;
        }

        final void collect() nothrow @trusted @nogc {
            if (d_str !is null) {
                d_str[0 .. size] = ptr[0 .. size];
            }
        }

        final void write(ParamBuffer buf) @trusted {
            buf.write(size);
            buf.write(cast(TypedefType!wasm_ptr_t) wasm_ptr);
        }

        ~this() @trusted {
            writefln("free wasm_ptr=%s", wasm_ptr);
            if (wasm_ptr != 0) {
                free(wasm_ptr);
            }
        }
    }
}

@safe struct WamrSymbols {
    private {
        NativeSymbol[] native_symbols;
        size_t[string] native_index;
    }

    void opCall(F)(string symbol, F func, string signature, void* attachment = null) nothrow
            if (isFunctionPointer!F) {
        NativeSymbol native_symbol = {
            symbol.toStringz, // the name of WASM function name
                func, // the native function pointer
                signature.toStringz, // the function prototype signature, avoid to use i32
                attachment // attachment if none the null


        };
        native_index[symbol] = native_symbols.length;
        native_symbols ~= native_symbol;
    }

    void declare(alias func)(void* attachment = null) nothrow if (isCallable!func) {
        enum signature = paramSymbols!func;
        opCall(func.mangleof, &func, signature, attachment);
    }

    alias structToWasmType(S) = wasm_ptr_t function(S s);

    template toWasmType(T, bool check = true) {
        alias BaseT = TypedefType!T;
        static if (isBasicType!BaseT) {
            static if (isFloatingPoint!BaseT) {
                alias toWasmType = BaseT;
            }
            else static if (T.sizeof is int.sizeof) {
                alias toWasmType = int;
            }
            else static if (T.sizeof is long.sizeof) {
                alias toWasmType = long;
            }
            else static if (T.sizeof < int.sizeof) {
                alias toWasmType = int;
            }
            else static if (T.sizeof < long.sizeof) {
                alias toWasmType = long;
            }
        }
        else static if (is(T : U[], U) && isBasicType!U) {
            alias BaseU = Unqual!(U);
            alias toWasmType = TVMEngine.WasmArray!BaseU;
        }
        else static if (is(T == struct)) {
            alias toWasmType = structToWasmType!T;
        }
        else static if (isPointer!T) {
            alias Target = PointerTarget!T;
            pragma(msg, "PointerTarget!T ", PointerTarget!T);
            static if (is(Target == struct)) {
                alias toWasmType = WasmPointerType!T;
            }
            else {
                alias toWasmType = wasm_ptr_t;
            }
        }
        else static if (check) {
            static assert(0, format("%s is not supported", T.stringof));
        }
        else {
            alias toWasmType = void;
        }
    }

    alias isWasmBasicType(T) = isBasicType!T;

    alias toWasmTypes(Params...) = staticMap!(toWasmType, Params);

    static string convertToWasmParams(Params...)() nothrow {
        string[] result;
        static foreach (i, P; Params) {
            result ~= assumeWontThrow(format("%s param_%s", P.stringof, i));
        }
        return result.join(", ");
    }

    static string convertToWasmArguments(Params...)() nothrow {
        alias WasmParams = toWasmTypes!Params;
        string[] result;
        static foreach (i, P; Params) {
            result ~= assumeWontThorw(format("param_%s", i));
        }
        return result.join(", ");
    }

    template Symbol(T) {
        alias BaseT = Unqual!T;
        static if (is(BaseT == long) || is(BaseT == ulong)) {
            enum Symbol = "I";
        }
        else static if (is(BaseT == int) || is(BaseT == uint)) {
            enum Symbol = "i";
        }
        else static if (is(BaseT == float)) {
            enum Symbol = "f";
        }
        else static if (is(BaseT == double)) {
            enum Symbol = "F";
        }
        else static if (is(BaseT == wasm_ptr_t)) {
            enum Symbol = "*";
        }
        else static if (__traits(compiles, T.symbol)) {
            enum Symbol = T.symbol;
        }
        else {
            static assert(0, format("No wasm symbol found for %s", T.stringof));
        }
    }

    static string listSymbols(Args...)() {
        alias WasmParams = toWasmTypes!Args;
        string result;
        static foreach (i, P; WasmParams) {
            result ~= Symbol!(WasmParams[i]);
        }
        return result;

    }

    static string paramsSymbols(Args...)() {
        return "(" ~ listSymbols!(Args)() ~ ")";
    }

    static string paramSymbols(alias F)() if (isCallable!F) {
        alias Params = ParameterTypeTuple!F;
        string result = paramsSymbols!(Params[1 .. $]);
        alias Returns = ReturnType!F;
        static if (!is(Returns == void)) {
            alias WasmReturns = toWasmTypes!Returns;
            result ~= Symbol!(WasmReturns);
        }
        return result;
    }
}

version (none) unittest {
    import src.native_impl;
    import std.stdio;
    import std.file : fread = read, exists;

    enum testapp_file = "tests/basic/c/wasm-apps/testapp.wasm";
    enum wasm_code = cast(immutable(ubyte[])) import(testapp_file);
    pragma(msg, " wasm_code_1 ", typeof(wasm_code));
    //immutable wasm_code = cast(immutable(ubyte[])) testapp_file.fread();
    WamrSymbols wasm_symbols;
    wasm_symbols("intToStr", &intToStr, "(i*~i)i");
    wasm_symbols("get_pow", &get_pow, "(ii)i");
    wasm_symbols("calculate_native", &calculate_native, "(iii)i");

    uint[] global_heap;
    global_heap.length = 512 * 1024;

    auto wasm_engine = new TVMEngine(wasm_symbols, 8092, // Stack size
            8092, // Heap size
            global_heap, // Global heap
            wasm_code, "env");

    //
    // Calling Wasm functions from D
    //
    float ret_val;

    {
        import std.conv : to;

        auto generate_float = wasm_engine.lookup("generate_float");
        ret_val = wasm_engine.call!float(generate_float, 10, 0.000101, 300.002f);
        assert(ret_val.to!string == "102010");
    }

    {
        auto float_to_string = wasm_engine.lookup("float_to_string");
        char* native_buffer;
        auto wasm_buffer = wasm_engine.malloc(100, native_buffer);
        scope (exit) {
            wasm_engine.free(wasm_buffer);
        }
        wasm_engine.call!void(float_to_string, ret_val, wasm_buffer, 100, 3);
        assert(fromStringz(native_buffer) == "102009.921");
    }

    {
        auto calculate = wasm_engine.lookup("calculate");
        auto ret = wasm_engine.call!int(calculate, 3);
        assert(ret == 120);
    }

    writeln("Passed");
}

version (none) unittest {
    int result;
    int add(int x) {
        result += x;
        return 2 * result;
    }

    pragma(msg, typeof(&add));
    WamrSymbols wasm_symbols;
    wasm_symbols("add", &add);

    string text(int x, float y, string str) {
        result++;
        return format("%s %s %s %d", x, y, str, result);
    }

    wasm_symbols("text", &text);

}

version (none) unittest {
    extern (C) static int __wasm_assert(wasm_exec_env_t exec_env, int x, int y) {
        writefln("__wasm_assert %d %d", x, y);
        //.check(0, format("__wasm_assert x=%d y=%d", x, y));
        return -1;
    }

    import std.stdio;
    import std.file : fread = read, exists;

    enum testapp_file = "tests/advanced/test_array.wasm";
    immutable wasm_code = cast(immutable(ubyte[])) testapp_file.fread();
    WamrSymbols wasm_symbols;
    wasm_symbols("__assert", &__wasm_assert, "(ii)i");
    uint[] global_heap;
    global_heap.length = 512 * 1024;
    auto wasm_engine = new TVMEngine(wasm_symbols, 8092, // Stack size
            8092, // Heap size
            global_heap, // Global heap
            wasm_code);

    auto get_result = wasm_engine.lookup("get_result");
    writefln("get_result = %d", wasm_engine.call!int(get_result, 0));

    {
        auto char_array = wasm_engine.lookup("char_array");
        char[] array;
        array.length = 32;
        const ret = wasm_engine.call!int(char_array, array);
        writefln("ret = %d %s", ret, array);
    }
    version (none) {
        auto ref_char_array = wasm_engine.lookup("ref_char_array");
        char[] array;
        const ret = wasm_engine.call!int(ref_char_array, array);
        writefln("ret = %d", ret);
    }

    {
        auto const_char_array = wasm_engine.lookup("const_char_array");
        const(char[]) array = "Hello";
        auto ret = wasm_engine.call!int(const_char_array, array);
        writefln("ret = %d %d %s", ret, wasm_engine.call!int(get_result, 0), array);
    }

    //        "env");
    // wasm_symbols("intToStr", &intToStr, "(i*~i)i");
    // wasm_symbols("get_pow", &get_pow, "(ii)i");
    // wasm_symbols("calculate_native", &calculate_native, "(iii)i");
}

// int main(string[] args) {
//     return 0;
// }
