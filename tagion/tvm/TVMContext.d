module tagion.tvm.TVMContext;

enum TVMError {
    NONE,
    TRUNC_RANGE,
    STACK_EMPTY,
    STACK_OVERFLOW,
    OUT_OF_MEMORY,
    INTEGER_OVERFLOW,
    INTEGER_DIVISION_BY_ZERO,
}
/* Execution environment */
@safe @nogc struct TVMContext {
    import tagion.tvm.TVMBasic : WasmType, WasmTypes, isWasmType;
    import tagion.tvm.TVMLoader : ModuleInstance;
    import tagion.basic.Basic : isOneOf;
    import core.exception : RangeError, onRangeError;
    import std.meta : allSatisfy;
    import std.traits : isIntegral, isSigned, isNumeric, isFloatingPoint, isUnsigned;
    import std.math : isNaN;
    import std.format;

    private uint page_size = 0x1_0000;
    private uint max_pages = 128;
    void set_exception(const size_t ip, string msg) nothrow pure
    in (ip <= uint.max) {
    }

    bool get_exception() nothrow pure {
        return false;
    }

    bool enlarge_memory(ref const(ModuleInstance) mod_instance, const uint delta) pure nothrow {
        return false;
    }

    WasmType[] locals;
    WasmType[] globals;
    //    WASM_STACK wasm_stack;
    WasmType[] stack;
    ubyte[] memory;
    int sp; // Stack pointer;
    uint cur_page_count;
    TVMError error;
    // ALU function
    const(T) pop(T)() pure if (isWasmType!T) {
        scope(exit) {
            sp--;
        }
        return stack[sp-1].get!T;
    }

    void push(T)(const T x) if (isWasmType!T) {
        stack[sp] = x;
        sp++;
    }

    void pop(Args...)(ref Args args) pure if (allSatisfy!(isWasmType, Args)) {
        static foreach_reverse (i_sp, ref arg; args) {
            arg = stack[sp - i_sp - 1].get!(Args[i]);
        }
        sp -= Args.length;
    }

    const(T) peek(T)() const pure if (isOneOf!(T, WasmTypes)) {
        return stack[sp - 1].get!T;
    }

    void op_drop() pure {

        sp--;
        if (sp < 0) {
            onRangeError;
        }
    }

    void op_cat(T, string OP)() pure {
        enum code = format!q{stack[sp-2] %s= stack[sp-1].get!T;}(OP);
        mixin(code);
        sp--;
    }

    void op_unary(T, string OP)() pure {
        import math = std.math;
        enum code = format!q{stack[sp-1] = %s stack[sp-1].get!T;}(OP);
        mixin(code);
    }

    void op_math(T, string func)() pure {

        import std.math;
        static if (func == "trunc") {
            enum code = format!q{stack[sp-1] = cast(T)%s(stack[sp-1].get!T);}(func);
        }
        else {
            enum code = format!q{stack[sp-1] = %s(stack[sp-1].get!T);}(func);
            mixin(code);
        }
    }

    void op_eqz(T)() pure if (isIntegral!T) {
        stack[sp - 1] = stack[sp - 1].get!T == T(0);
    }

    void op_cmp(T, string OP)() pure if (isNumeric!T) {
        enum code = format!q{stack[sp-2] = stack[sp-2].get!T %s stack[sp-1].get!T;}(OP);
        mixin(code);
        sp--;
    }

    void op_min(T)() pure if (isFloatingPoint!T) {
        import std.math : fmin;
        stack[sp - 2] = fmin(stack[sp - 1].get!T, stack[sp - 2].get!T);
        sp--;
    }

    void op_max(T)() pure if (isFloatingPoint!T) {
        import std.math : fmax;
        stack[sp - 2] = fmax(stack[sp - 1].get!T, stack[sp - 2].get!T);
        sp--;
    }

    void op_convert(DST, SRC)() pure if (isNumeric!DST && isNumeric!SRC) {
        stack[sp - 1] = cast(DST) stack[sp - 1].get!SRC;
    }

    void op_copysign(T)() pure if (isFloatingPoint!T) {
        import std.math : signbit, fabs;
        const a = stack[sp - 2].get!T;
        const b = stack[sp - 1].get!T;
        stack[sp - 2] = (signbit(b) ? -fabs(a) : fabs(a));
        sp--;
    }

    void op_select() pure {
        const flag = stack[sp - 1].get!int;
        if (flag is int(0)) {
            stack[sp - 3] = stack[sp - 2];
        }
        sp -= 2;
    }

    void op_rotl(T)() pure if (isSigned!T) {
        const n = stack[sp - 1].get!T;
        T c = stack[sp - 2].get!T;
        enum mask = T.sizeof * 8 - 1;
        c &= mask;
        stack[sp - 2] = (n >> c) | (n << ((-c) & mask));
        sp--;
    }

    void op_rotr(T)() pure if (isSigned!T) {
        const n = stack[sp - 1].get!T;
        T c = stack[sp - 2].get!T;
        enum mask = T.sizeof * 8 - 1;
        c &= mask;
        stack[sp - 2] = (n >> c) | (n << ((-c) & mask));
        sp--;
    }

    bool op_rem(T)() pure if (isIntegral!T) {
        const a = stack[sp - 2].get!T;
        const b = stack[sp - 1].get!T;
        static if (isSigned!T) {
            if (a == T(T(1) << T.sizeof * 8 - 1) && b == -1) {
                stack[sp - 2] = T(0);
                sp--;
                return false;
            }
        }
        if (b == 0) {
            error = TVMError.INTEGER_DIVISION_BY_ZERO;
            //set_exception(ip, "integer divide by zero");
            return true;
        }
        stack[sp - 2] = a % b;
        sp--;
        return false;
    }

    bool op_div(T)(const size_t ip) pure if (isIntegral!T) {
        const a = stack[sp - 2].get!T;
        const b = stack[sp - 1].get!T;
        static if (isSigned!T) {
            if (a == T(T(1) << T.sizeof * 8 - 1) && b == -1) {
                error = TVMError.INTEGER_OVERFLOW;
                //set_exception(ip, "integer overflow");
                return true;
            }
        }
        if (b == 0) {
            error = TVMError.INTEGER_DIVISION_BY_ZERO;
            //set_exception(ip, "integer divide by zero");
            return true;
        }
        stack[sp - 2] = a / b;
        sp--;
        return false;
    }

    void op_popcount(T)() {
        static uint count_ones(size_t BITS = T.sizeof * 8)(const T x) pure nothrow @nogc @safe {
            static if (BITS == 1) {
                return x & 0x1;
            }
            else if (x == 0) {
                return 0;
            }
            else {
                enum HALF_BITS = BITS / 2;
                enum MASK = T(1UL << (HALF_BITS)) - 1;
                return count_ones!(HALF_BITS)(x & MASK) + count_ones!(HALF_BITS)(x >> HALF_BITS);
            }
        }
        stack[sp - 1] = count_ones(stack[sp - 1].get!T);
    }

    void op_clz(T)() pure {
        static uint count_leading_zeros(size_t BITS = T.sizeof * 8)(const T x) pure nothrow @nogc @safe {
            static if (BITS == 0) {
                return 0;
            }
            else if (x == 0) {
                return BITS;
            }
                enum HALF_BITS = BITS / 2;
                enum MASK = T(T(1) << (HALF_BITS)) - 1;
                const count = count_leading_zeros!HALF_BITS(x & MASK);
                if (count == HALF_BITS) {
                    return count + count_leading_zeros!HALF_BITS(x >> HALF_BITS);
                }
                return count;
        }

        stack[sp - 1] = count_leading_zeros(stack[sp - 1].get!T);
    }

    void op_ctz(T)() pure nothrow {
        static uint count_trailing_zeros(size_t BITS = T.sizeof * 8)(const T x) pure nothrow {
            static if (BITS == 0) {
                return 0;
            }
            else if (x == 0) {
                return BITS;
            }
                enum HALF_BITS = BITS / 2;
                enum MASK = T(T(1) << (HALF_BITS)) - 1;
                const count = count_trailing_zeros!HALF_BITS(x >> HALF_BITS);
                if (count == HALF_BITS) {
                    return count + count_trailing_zeros!HALF_BITS(x & MASK);
                }
                return count;
        }

        stack[sp - 1] = count_trailing_zeros(stack[sp - 1].get!T);
    }

    void op_trunc_sat(DST, SRC)() pure
        if (isFloatingPoint!SRC && isIntegral!DST) {
        const z = stack[sp - 1].get!SRC;
        if (z.isNaN) {
            stack[sp - 1] = DST(0);
            return;
        }
        if (z is -SRC.infinity) {
            stack[sp - 1] = DST.min;
            return;
        }
        if (z is SRC.infinity) {
            stack[sp - 1] = DST.max;
            return;
        }
        if (isUnsigned!DST && z < SRC(0)) {
            stack[sp - 1] = DST.min;
            return;
        }
        if (z < DST.min) {
            stack[sp - 1] = DST.min;
            return;
        }
        if (z > DST.max) {
            stack[sp - 1] = DST.max;
            return;
        }
        stack[sp - 1] = cast(DST) z;
    }

    bool op_trunc(DST, SRC)() pure if (isFloatingPoint!SRC && isIntegral!DST) {
        const z = stack[sp - 1].get!SRC;
        if (z >= DST.min && z <= DST.max) {
            stack[sp - 1] = cast(DST)(z);
            return false;
        }
        error = TVMError.TRUNC_RANGE;
        return true;
    }

    void op_wrap(DST, SRC)() pure if (isIntegral!DST && isIntegral!SRC) {
        stack[sp - 1] = stack[sp - 1].get!DST;
    }

    void op_memory_size() pure {
        stack[sp] = cast(uint) memory.length / page_size;
        sp++;
    }

    void op_memory_grow() pure {
        const sz = stack[sp - 1].get!uint;
        if (memory.length / page_size + sz <= max_pages) {
            memory.length += page_size * sz;
            stack[sp - 1] = cast(uint) memory.length / page_size;
            return;
        }
        stack[sp - 1] = int(-1);
    }

    bool op_load(DST, SRC)(const size_t effective_offset, const size_t ip) @trusted {
        version (BigEndian) {
            static assert(0, "BigEndian not supported yet");
        }
        const addr = stack[sp - 1].get!uint;
        const effective_index = effective_offset + addr;
        if (effective_index + SRC.sizeof < memory.length) {
            stack[sp - 1] = cast(DST)(*cast(SRC*)&memory[effective_index]);
            return false;
        }
        error = TVMError.OUT_OF_MEMORY;
        return true;
    }

    bool op_store(DST, SRC)(const size_t effective_offset, const size_t ip) @trusted {
        static assert(DST.sizeof <= SRC.sizeof);
        version (BigEndian) {
            static assert(0, "BigEndian not supported yet");
        }
        const addr = stack[sp - 1].get!uint;
        const effective_index = effective_offset + addr;
        if (effective_index + DST.sizeof < memory.length) {

            static if (DST.sizeof is SRC.sizeof) {
                memory[effective_index .. effective_index + DST.sizeof] = (
                        cast(ubyte*)&stack[sp - 2])[0 .. SRC.sizeof];
            }
            else {
                memory[effective_index .. effective_index + DST.sizeof] = 0;
                memory[effective_index .. effective_index + SRC.sizeof] = (
                        cast(ubyte*)&stack[sp - 2])[0 .. DST.sizeof];
            }
            sp--;
            return false;
        }
        error = TVMError.OUT_OF_MEMORY;
        return true;
    }
}
