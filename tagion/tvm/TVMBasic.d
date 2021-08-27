module tagion.tvm.TVMBasic;

import tagion.wasm.WasmBase : Types; //, Section, ExprRange, IR, IRType, instrTable, WasmArg;
import std.meta : AliasSeq, anySatisfy, ApplyLeft, staticIndexOf;
import std.traits : isIntegral, Unqual;
import tagion.basic.Basic : isOneOf, isEqual;

alias WasmTypes = AliasSeq!(int, long, float, double, uint, ulong, short,
        ushort, byte, ubyte, WasmType);

//pragma(msg, ApplyLeft!(Unqual, int, const(ubyte)));

enum isWasmType(T) = anySatisfy!(ApplyLeft!(isEqual, Unqual!T), WasmTypes);

static unittest {
    static assert(isWasmType!uint);
    static assert(isWasmType!(const(uint)));
    static assert(!isWasmType!WasmType);
    static assert(isWasmType!string);
    static assert(allSatisfy!(isWasmType, double, int, ubyte));
}

@safe @nogc union WasmType {
    import std.format;

    @(Types.I32) int i32;
    @(Types.I64) long i64;
    @(Types.F32) float f32;
    @(Types.F64) double f64;
    alias WasmT = typeof(this.tupleof);
    pure nothrow {
        void opAssign(T)(const T x) if (isOneOf!(T, WasmT)) {
            enum index = staticIndexOf!(T, WasmT);
            this.tupleof[index] = x;
        }

        void opAssign(const uint x) {
            i32 = x;
        }

        void opAssign(const ulong x) {
            i64 = x;
        }

        void opAssign(const float x) {
            f32 = x;
        }

        void opAssign(const double x) {
            f64 = x;
        }

        void opOpAssign(string op, T)(const T x) if (isOneOf!(T, WasmT)) {
            enum index = staticIndexOf!(T, WasmT);
            enum code = format(q{this.tupleof[index] %s= x;}, op);
            mixin(code);
        }

        void opOpAssign(string op, T)(const T x)
                if (isIntegral!T && !isOneOf!(T, WasmT)) {
            static if (T.sizeof <= int.sizeof) {
                alias U = int;
            }
            else {
                alias U = long;
            }
            enum index = staticIndexOf!(U, WasmT);
            enum code = format!q{this.tupleof[index] %s= cast(U)x;}(op);
            mixin(code);
        }

        // void opOpAssign(T, string op)(const T x) if(is(T==WasmType)) {
        //     pragma(msg, "WasmType ", T.stringof);
        //     // enum index=staticIndexOf!(T, WasmT);
        //     // enum code=format(q{this.tupleof[index] %s= x}, op);
        //     // mixin(code);
        // }

        const(T) get(T)() const pure nothrow if (isOneOf!(T, WasmT)) {
            enum index = staticIndexOf!(T, WasmT);
            return this.tupleof[index];
        }

        const(T) get(T)() const pure nothrow
                if (isIntegral!T && !isOneOf!(T, WasmT)) {
            static if (T.sizeof <= int.sizeof) {
                return cast(T) i32;
            }
            else {
                return cast(T) i64;
            }
        }
    }
}

@nogc @safe struct FunctionInstance {
//    enum Function
    union {
        struct {
            uint ip; // Bincode instruction pointer
            ushort local_size; /// local variable count, 0 for import function
        }

    }

    ushort param_count; /// parameter count
    /+
    /* cell num of parameters */
    uint16 param_cell_num;
    /* cell num of return type */
    uint16 ret_cell_num;
    /* cell num of local variables, 0 for import function */
    uint16 local_cell_num;
    +/
    /* whether it is import function or WASM function */
    bool is_import_func; /// whether it is import function or WASM function

    bool isLocalFunc() pure const nothrow {
        return !is_import_func;
    }

    version (none) {
        version (WASM_ENABLE_FAST_INTERP) {
            /* cell num of consts */
            uint16 const_cell_num;
        }
        uint16* local_offsets;
        /* parameter types */
        uint8* param_types;
        /* local types, NULL for import function */
        uint8* local_types;
        union U {
            WASMFunctionImport* func_import;
            WASMFunction* func;
        }

        U u;
        version (WASM_ENABLE_MULTI_MODULE) {
            WASMModuleInstance* import_module_inst;
            WASMFunctionInstance* import_func_inst;
        }
    }
}
