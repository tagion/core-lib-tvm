module tagion.tvm.TVMBasic;

import tagion.wasm.WasmBase : Types; //, Section, ExprRange, IR, IRType, instrTable, WasmArg;
import tagion.basic.Basic : isOneOf, isEqual;
import LEB128=tagion.utils.LEB128;
import std.meta : AliasSeq, allSatisfy, anySatisfy, ApplyLeft, staticIndexOf;
import std.traits : isIntegral, Unqual, EnumMembers, getUDAs;
import std.format;
import std.algorithm.iteration : map;
import std.array : array;

alias WasmTypes = AliasSeq!(int, long, float, double, uint, ulong, short,
        ushort, byte, ubyte, WasmType);

//pragma(msg, ApplyLeft!(Unqual, int, const(ubyte)));

enum isWasmType(T) = anySatisfy!(ApplyLeft!(isEqual, Unqual!T), WasmTypes);

static unittest {
    static assert(isWasmType!uint);
    static assert(isWasmType!(const(uint)));
    static assert(isWasmType!WasmType);
    static assert(!isWasmType!string);
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

static unittest {
    import tagion.wasm.WasmBase; // : IRType, getInstr, IR, Instr;
    enum InstrUnreachable =Instr("unreachable", 1, IRType.CODE);
    enum ir = IR.UNREACHABLE;
    static assert(getInstr!(ir) == InstrUnreachable); //Instr("unreachable", 1, IRType.CODE));
}

@nogc @safe struct FunctionInstance {
    import tagion.tvm.TVMExtOpcode : InternalIR, convert, ILLEGAL_IR;
    import tagion.wasm.WasmBase : IRType, getInstr, IR, Instr;
    struct FuncBody {
        struct BlockSegment {
            size_t start_index, end_index;
        }
        BlockSegment[] block_segments;
        ushort local_count;
        ushort param_count;
        ushort return_count;
    }

//    enum Function
    union {
        struct {
            immutable(ubyte)[] frame;
            immutable(ubyte[])[] blocks;
            //uint ip; // Bincode instruction pointer
//            ushort local_size; /// local variable count, 0 for import function

        }
    }
    ushort local_count;
    ushort param_count; /// parameter count
    ushort return_count;

    this(const(FuncBody) func_body, immutable(ubyte[]) full_frame) {
        local_count = func_body.local_count;
        param_count = func_body.param_count;
        return_count = func_body.return_count;
        auto range=func_body.block_segments.map!((segment) => full_frame[segment.start_index..segment.end_index]);
        frame = range.front;
        range.popFront;
        blocks = range.array;
    }

    this(immutable(ubyte[]) frame, const ushort local_size, const ushort param_count) {
        // Something is super odd.
        // If we don't do this loop before the getInstr can't locate the UDA
        // static foreach(ir; EnumMembers!IR) {{
        //     enum irInstr = getInstr!ir;
        //     }}
        this.frame = frame;
        immutable(ubyte[])[] result_blocks;
        size_t block_start_ip;
        foreach(ip; 0..frame.length) {
            const opcode = frame[ip];
//            with(InternalIR) {
            OpCodeCase: final switch (opcode) {
                static foreach(internalIR; EnumMembers!InternalIR) {{
                        enum ir = convert(internalIR);
                        static if (ir is ILLEGAL_IR) {
                            // Internal IR which do not have a Instr UDA
                            case internalIR:
                                //pragma(msg, "ILLEGAL_IR ", internalIR);
                                break OpCodeCase;
                        }
                        else {
                            case internalIR:
                                //pragma(msg, "IR ", internalIR);
                                //enum ir = convert(E);
                                enum instr = getInstr!(ir);
                            with(IRType) {
                                final switch(instr.irtype) {
                                case BLOCK:
                                    block_start_ip = ip;
                                    break OpCodeCase;
                                case END:

                                    break;
                                case BRANCH:
                                    ip += LEB128.calc_size(frame[ip..$]);
                                    break OpCodeCase;
                                case BRANCH_TABLE:
                                    const decoded = LEB128.decode!uint(frame[ip..$]);
                                    ip+=decoded.sizeof;
                                    ip+=uint.sizeof * (decoded.size+1);
                                    break OpCodeCase;
                                case CALL:
                                    ip += LEB128.calc_size(frame[ip..$]);
                                    break OpCodeCase;
                                case LOCAL:
                                case GLOBAL:
                                    ip += LEB128.calc_size(frame[ip..$]);
                                    break OpCodeCase;
                                case MEMOP:
                                    ip += LEB128.calc_size(frame[ip..$]);
                                    ip += LEB128.calc_size(frame[ip..$]);
                                    break OpCodeCase;
                                case CONST:
                                    switch(ir) {
                                    case IR.I32_CONST:
                                    case IR.I64_CONST:
                                        ip += LEB128.calc_size(frame[ip..$]);
                                        break;
                                    case IR.F32_CONST:
                                        ip += float.sizeof;
                                        break;
                                    case IR.F64_CONST:
                                        ip += double.sizeof;
                                        break;
                                    default:
                                        assert(0, format!"Bad const instuction %s"(ir.stringof));
                                    }
                                    break OpCodeCase;
                                case CALL_INDIRECT:
                                case CODE:
                                case MEMORY:
                                    break OpCodeCase;
                                case PREFIX:
                                    assert(0, format!"%s Should  be expared to an internale extra instruction"(internalIR.stringof));
                                    ip += ubyte.sizeof;
                                    break OpCodeCase;
                                }
                            }
                            assert(0);
//                            break OpCodeCase;
                        }}
                    }
                }
//            }
        }
    }

    // //                     enum
    // //                 }
    // //             case BR_IF:
    // //                 ip += uint.sizeof;
    // //                 break;
    // //                                                 case I32_LOAD:
    // //                             case F32_LOAD:
    // //                             case I64_LOAD:
    // //                             case F64_LOAD:
    // //                             case I32_LOAD8_S:
    // //                             case I32_LOAD8_U:
    // //                             case I32_LOAD16_S:
    // //                             case I32_LOAD16_U:
    // //                             case I64_LOAD8_S:
    // //                             case I64_LOAD8_U:
    // //                             case I64_LOAD16_S:
    // //                             case I64_LOAD16_U:
    // //                             case I64_LOAD32_S:
    // //                             case I64_LOAD32_U:
    // //                             case I32_STORE:
    // //                             case F32_STORE:
    // //                             case I64_STORE:
    // //                             case F64_STORE:
    // //                             case I32_STORE8:
    // //                             case I32_STORE16:
    // //                             case I64_STORE8:
    // //                             case I64_STORE16:
    // //                             case I64_STORE32:
    // //                             case MEMORY_SIZE:
    // //                             case MEMORY_GROW:
    // //                             case I32_CONST:
    // //                                 op_const!int;
    // //                                 continue;
    // //                             case I64_CONST:
    // //                                 op_const!long;
    // //                                 continue;
    // //                             case F32_CONST:
    // //                                 op_const!float;
    // //                                 continue;
    // //                             case F64_CONST:
    // //                                 op_const!double;
    // //                                 continue;
    // //                                 /* comparison instructions of i32 */
    // //                             case I32_EQZ:
    // //                             case I32_EQ:
    // //                             case I32_NE:
    // //                             case I32_LT_S:
    // //                             case I32_LT_U:
    // //                             case I32_GT_S:
    // //                             case I32_GT_U:
    // //                             case I32_LE_S:
    // //                             case I32_LE_U:
    // //                                 ctx.op_cmp!(uint, "<=");
    // //                                 continue;
    // //                             case I32_GE_S:
    // //                                 ctx.op_cmp!(int, ">=");
    // //                                 continue;
    // //                             case I32_GE_U:
    // //                                 ctx.op_cmp!(uint, ">=");
    // //                                 continue;
    // //                                 /* comparison instructions of i64 */
    // //                             case I64_EQZ:
    // //                                 ctx.op_eqz!long;
    // //                                 continue;
    // //                             case I64_EQ:
    // //                                 ctx.op_cmp!(ulong, "==");
    // //                                 continue;
    // //                             case I64_NE:
    // //                                 ctx.op_cmp!(ulong, "!=");
    // //                                 continue;
    // //                             case I64_LT_S:
    // //                                 ctx.op_cmp!(long, "<");
    // //                                 continue;
    // //                             case I64_LT_U:
    // //                                 ctx.op_cmp!(ulong, "<");
    // //                                 continue;
    // //                             case I64_GT_S:
    // //                                 ctx.op_cmp!(long, ">");
    // //                                 continue;
    // //                             case I64_GT_U:
    // //                                 ctx.op_cmp!(ulong, ">");
    // //                                 continue;
    // //                             case I64_LE_S:
    // //                                 ctx.op_cmp!(long, "<=");
    // //                                 continue;
    // //                             case I64_LE_U:
    // //                                 ctx.op_cmp!(ulong, "<=");
    // //                                 continue;
    // //                             case I64_GE_S:
    // //                                 ctx.op_cmp!(ulong, ">=");
    // //                                 continue;
    // //                             case I64_GE_U:
    // //                                 ctx.op_cmp!(long, ">=");
    // //                                 continue;
    // //                                 /* comparison instructions of f32 */
    // //                             case F32_EQ:
    // //                                 ctx.op_cmp!(float, "==");
    // //                                 continue;
    // //                             case F32_NE:
    // //                                 ctx.op_cmp!(float, "!=");
    // //                                 continue;
    // //                             case F32_LT:
    // //                                 ctx.op_cmp!(float, "<");
    // //                                 continue;
    // //                             case F32_GT:
    // //                                 ctx.op_cmp!(float, ">");
    // //                                 continue;
    // //                             case F32_LE:
    // //                                 ctx.op_cmp!(float, "<=");
    // //                                 continue;
    // //                             case F32_GE:
    // //                                 ctx.op_cmp!(float, ">=");
    // //                                 continue;
    // //                                 /* comparison instructions of f64 */
    // //                             case F64_EQ:
    // //                                 ctx.op_cmp!(double, "==");
    // //                                 continue;
    // //                             case F64_NE:
    // //                                 ctx.op_cmp!(double, "!=");
    // //                                 continue;
    // //                             case F64_LT:
    // //                                 ctx.op_cmp!(double, "<");
    // //                                 continue;
    // //                             case F64_GT:
    // //                                 ctx.op_cmp!(double, ">");
    // //                                 continue;
    // //                             case F64_LE:
    // //                                 ctx.op_cmp!(double, "<=");
    // //                                 continue;
    // //                             case F64_GE:
    // //                                 ctx.op_cmp!(double, ">=");
    // //                                 continue;
    // //                                 /* numberic instructions of i32 */
    // //                             case I32_CLZ:
    // //                                 ctx.op_clz!int;
    // //                                 continue;
    // //                             case I32_CTZ:
    // //                                 ctx.op_ctz!int;
    // //                                 continue;
    // //                             case I32_POPCNT:
    // //                                 ctx.op_popcount!int;
    // //                                 continue;
    // //                             case I32_ADD:
    // //                                 ctx.op_cat!(uint, "+");
    // //                                 continue;
    // //                             case I32_SUB:
    // //                                 ctx.op_cat!(uint, "-");
    // //                                 continue;
    // //                             case I32_MUL:
    // //                                 ctx.op_cat!(uint, "*");
    // //                                 continue;
    // //                             case I32_DIV_S:
    // //                                 if (ctx.op_div!int(ip)) {
    // //                                     goto case ERROR;
    // //                                 }
    // //                                 continue;
    // //                             case I32_DIV_U:
    // //                                 if (ctx.op_div!uint(ip)) {
    // //                                     goto case ERROR;
    // //                                 }
    // //                                 continue;
    // //                             case I32_REM_S:
    // //                                 if (ctx.op_rem!int) {
    // //                                     goto case ERROR;
    // //                                 }
    // //                                 continue;
    // //                             case I32_REM_U:
    // //                                 if (ctx.op_rem!uint) {
    // //                                     goto case ERROR;
    // //                                 }
    // //                                 continue;
    // //                             case I32_AND:
    // //                                 ctx.op_cat!(uint, "&");
    // //                                 continue;
    // //                             case I32_OR:
    // //                                 ctx.op_cat!(uint, "|");
    // //                                 continue;
    // //                             case I32_XOR:
    // //                                 ctx.op_cat!(uint, "^");
    // //                                 continue;
    // //                             case I32_SHL:
    // //                                 ctx.op_cat!(uint, "<<");
    // //                                 continue;
    // //                             case I32_SHR_S:
    // //                                 ctx.op_cat!(int, ">>");
    // //                                 continue;
    // //                             case I32_SHR_U:
    // //                                 ctx.op_cat!(uint, ">>");
    // //                                 continue;
    // //                             case I32_ROTL:
    // //                                 ctx.op_rotl!int;
    // //                                 continue;
    // //                             case I32_ROTR:
    // //                                 ctx.op_rotr!int;
    // //                                 continue;
    // //                                 /* numberic instructions of i64 */
    // //                             case I64_CLZ:
    // //                                 ctx.op_clz!int;
    // //                                 continue;
    // //                             case I64_CTZ:
    // //                                 ctx.op_ctz!int;
    // //                                 continue;
    // //                             case I64_POPCNT:
    // //                                 ctx.op_popcount!int;
    // //                                 continue;
    // //                             case I64_ADD:
    // //                                 ctx.op_cat!(ulong, "+");
    // //                                 continue;
    // //                             case I64_SUB:
    // //                                 ctx.op_cat!(ulong, "-");
    // //                                 continue;
    // //                             case I64_MUL:
    // //                                 ctx.op_cat!(ulong, "*");
    // //                                 continue;
    // //                             case I64_DIV_S:
    // //                                 if (ctx.op_div!long(ip)) {
    // //                                     goto case ERROR;
    // //                                 }
    // //                                 continue;
    // //                             case I64_DIV_U:
    // //                                 if (ctx.op_div!ulong(ip)) {
    // //                                     goto case ERROR;
    // //                                 }
    // //                                 continue;
    // //                             case I64_REM_S:
    // //                                 if (ctx.op_rem!long) {
    // //                                     goto case ERROR;
    // //                                 }
    // //                                 continue;
    // //                             case I64_REM_U:
    // //                                 if (ctx.op_rem!ulong) {
    // //                                     goto case ERROR;
    // //                                 }
    // //                                 continue;
    // //                             case I64_AND:
    // //                                 ctx.op_cat!(ulong, "&");
    // //                                 continue;
    // //                             case I64_OR:
    // //                                 ctx.op_cat!(ulong, "|");
    // //                                 continue;
    // //                             case I64_XOR:
    // //                                 ctx.op_cat!(ulong, "^");
    // //                                 continue;
    // //                             case I64_SHL:
    // //                                 ctx.op_cat!(ulong, "<<");
    // //                                 continue;
    // //                             case I64_SHR_S:
    // //                                 ctx.op_cat!(long, ">>");
    // //                                 continue;
    // //                             case I64_SHR_U:
    // //                                 ctx.op_cat!(ulong, ">>");
    // //                                 continue;
    // //                             case I64_ROTL:
    // //                                 ctx.op_rotl!long;
    // //                                 continue;
    // //                             case I64_ROTR:
    // //                                 ctx.op_rotr!long;
    // //                                 continue;
    // //                                 /* numberic instructions of f32 */
    // //                             case F32_ABS:
    // //                                 const x = fabs(float(-1));
    // //                                 ctx.op_math!(float, "fabs");
    // //                                 continue;
    // //                             case F32_NEG:
    // //                                 ctx.op_unary!(float, "-");
    // //                                 continue;
    // //                             case F32_CEIL:
    // //                                 ctx.op_math!(float, "ceil");
    // //                                 continue;
    // //                             case F32_FLOOR:
    // //                                 ctx.op_math!(float, "floor");
    // //                                 continue;
    // //                             case F32_TRUNC:
    // //                                 ctx.op_math!(float, "trunc");
    // //                                 continue;
    // //                             case F32_NEAREST:
    // //                                 ctx.op_math!(float, "rint");
    // //                                 continue;
    // //                             case F32_SQRT:
    // //                                 ctx.op_math!(float, "sqrt");
    // //                                 continue;
    // //                             case F32_ADD:
    // //                                 ctx.op_cat!(float, "+");
    // //                                 continue;
    // //                             case F32_SUB:
    // //                                 ctx.op_cat!(float, "-");
    // //                                 continue;
    // //                             case F32_MUL:
    // //                                 ctx.op_cat!(float, "*");
    // //                                 continue;
    // //                             case F32_DIV:
    // //                                 ctx.op_cat!(float, "/");
    // //                                 continue;
    // //                             case F32_MIN:
    // //                                 ctx.op_min!float;
    // //                                 continue;
    // //                             case F32_MAX:
    // //                                 ctx.op_max!float;
    // //                                 continue;
    // //                             case F32_COPYSIGN:
    // //                                 ctx.op_copysign!float;
    // //                                 continue;
    // //                             case F64_ABS:
    // //                                 ctx.op_math!(float, "fabs");
    // //                                 continue;
    // //                             case F64_NEG:
    // //                                 ctx.op_unary!(double, "-");
    // //                                 continue;
    // //                             case F64_CEIL:
    // //                                 ctx.op_math!(double, "ceil");
    // //                                 continue;
    // //                             case F64_FLOOR:
    // //                                 ctx.op_math!(double, "floor");
    // //                                 continue;
    // //                             case F64_TRUNC:
    // //                                 ctx.op_math!(double, "trunc");
    // //                                 continue;
    // //                             case F64_NEAREST:
    // //                                 ctx.op_math!(double, "rint");
    // //                                 continue;
    // //                             case F64_SQRT:
    // //                                 ctx.op_math!(double, "sqrt");
    // //                                 continue;
    // //                             case F64_ADD:
    // //                                 ctx.op_cat!(double, "/");
    // //                                 continue;
    // //                             case F64_SUB:
    // //                                 ctx.op_cat!(double, "-");
    // //                                 continue;
    // //                             case F64_MUL:
    // //                                 ctx.op_cat!(double, "*");
    // //                                 continue;
    // //                             case F64_DIV:
    // //                                 ctx.op_cat!(double, "/");
    // //                                 continue;
    // //                             case F64_MIN:
    // //                                 ctx.op_min!double;
    // //                                 continue;
    // //                             case F64_MAX:
    // //                                 ctx.op_max!double;
    // //                                 continue;
    // //                             case F64_COPYSIGN:
    // //                                 ctx.op_copysign!double;
    // //                                 continue;
    // //                                 /* conversions of i32 */
    // //                             case I32_WRAP_I64:
    // //                                 ctx.op_wrap!(int, long);
    // //                                 // const value = ctx.pop!int; //(int)(PI64() & 0xFFFFFFFFLL);
    // //                                 // ctx.push(value);
    // //                                 continue;
    // //                             case I32_TRUNC_F32_S:
    // //                                 /* We don't use INT_MIN/INT_MAX/UINT_MIN/UINT_MAX,
    // //                                    since float/double values of ieee754 cannot precisely represent
    // //                                    all int/uint/int64/uint64 values, e.g.:
    // //                                    UINT_MAX is 4294967295, but (float32)4294967295 is 4294967296.0f,
    // //                                    but not 4294967295.0f. */
    // //                                 if (ctx.op_trunc!(int, float))
    // //                                     goto case ERROR;
    // //                                 continue;
    // //                             case I32_TRUNC_F32_U:
    // //                                 if (ctx.op_trunc!(uint, float))
    // //                                     goto case ERROR;
    // //                                 continue;
    // //                             case I32_TRUNC_F64_S:
    // //                                 if (ctx.op_trunc!(int, double))
    // //                                     goto case ERROR;
    // //                                 continue;
    // //                             case I32_TRUNC_F64_U:
    // //                                 if (ctx.op_trunc!(int, double))
    // //                                     goto case ERROR;
    // //                                 continue;
    // //                                 /* conversions of i64 */
    // //                             case I64_EXTEND_I32_S:
    // //                                 ctx.op_convert!(long, int);
    // //                                 continue;
    // //                             case I64_EXTEND_I32_U:
    // //                                 ctx.op_convert!(long, uint);
    // //                                 continue;
    // //                             case I64_TRUNC_F32_S:
    // //                                 if (ctx.op_trunc!(long, float))
    // //                                     goto case ERROR;
    // //                                 continue;
    // //                             case I64_TRUNC_F32_U:
    // //                                 if (ctx.op_trunc!(ulong, float))
    // //                                     goto case ERROR;
    // //                                 continue;
    // //                             case I64_TRUNC_F64_S:
    // //                                 if (ctx.op_trunc!(long, double))
    // //                                     goto case ERROR;
    // //                                 continue;
    // //                             case I64_TRUNC_F64_U:
    // //                                 if (ctx.op_trunc!(ulong, double))
    // //                                     goto case ERROR;
    // //                                 continue;
    // //                                 /* conversions of f32 */
    // //                             case F32_CONVERT_I32_S:
    // //                                 ctx.op_convert!(float, int);
    // //                                 continue;
    // //                             case F32_CONVERT_I32_U:
    // //                                 ctx.op_convert!(float, uint);
    // //                                 continue;
    // //                             case F32_CONVERT_I64_S:
    // //                                 ctx.op_convert!(float, long);
    // //                                 continue;
    // //                             case F32_CONVERT_I64_U:
    // //                                 ctx.op_convert!(float, ulong);
    // //                                 continue;
    // //                             case F32_DEMOTE_F64:
    // //                                 ctx.op_convert!(float, double);
    // //                                 continue;
    // //                                 /* conversions of f64 */
    // //                             case F64_CONVERT_I32_S:
    // //                                 ctx.op_convert!(double, int);
    // //                                 continue;
    // //                             case F64_CONVERT_I32_U:
    // //                                 ctx.op_convert!(double, uint);
    // //                                 continue;
    // //                             case F64_CONVERT_I64_S:
    // //                                 ctx.op_convert!(double, long);
    // //                                 continue;
    // //                             case F64_CONVERT_I64_U:
    // //                                 ctx.op_convert!(double, ulong);
    // //                                 continue;
    // //                             case F64_PROMOTE_F32:
    // //                                 ctx.op_convert!(double, float);
    // //                                 continue;
    // //                                 /* reinterpretations */
    // //                             case I32_REINTERPRET_F32:
    // //                             case I64_REINTERPRET_F64:
    // //                             case F32_REINTERPRET_I32:
    // //                             case F64_REINTERPRET_I64:
    // //                                 continue;
    // //                             case I32_EXTEND8_S:
    // //                                 ctx.op_convert!(int, byte);
    // //                                 continue;
    // //                             case I32_EXTEND16_S:
    // //                                 ctx.op_convert!(int, short);
    // //                                 continue;
    // //                             case I64_EXTEND8_S:
    // //                                 ctx.op_convert!(long, byte);
    // //                                 continue;
    // //                             case I64_EXTEND16_S:
    // //                                 ctx.op_convert!(long, short);
    // //                                 continue;
    // //                             case I64_EXTEND32_S:
    // //                                 ctx.op_convert!(long, int);
    // //                                 continue;
    // //                             case I32_TRUNC_SAT_F32_S:
    // //                                 ctx.op_trunc_sat!(int, float);
    // //                                 continue;
    // //                             case I32_TRUNC_SAT_F32_U:
    // //                                 ctx.op_trunc_sat!(uint, float);
    // //                                 continue;
    // //                             case I32_TRUNC_SAT_F64_S:
    // //                                 ctx.op_trunc_sat!(int, double);
    // //                                 continue;
    // //                             case I32_TRUNC_SAT_F64_U:
    // //                                 ctx.op_trunc_sat!(uint, double);
    // //                                 continue;
    // //                             case I64_TRUNC_SAT_F32_S:
    // //                                 ctx.op_trunc_sat!(long, float);
    // //                                 continue;
    // //                             case I64_TRUNC_SAT_F32_U:
    // //                                 ctx.op_trunc_sat!(ulong, float);
    // //                                 continue;
    // //                             case I64_TRUNC_SAT_F64_S:
    // //                                 ctx.op_trunc_sat!(long, double);
    // //                                 continue;
    // //                             case I64_TRUNC_SAT_F64_U:
    // //                                 ctx.op_trunc_sat!(ulong, double);
    // //                                 continue;
    // //                             case ERROR:
    // //                                 unwined = true;
    // //                             }

    // //             }


//        immutable(ubyte)[][]
//        void builda
//    }

    // this(immutable(ubyte[]) _frame, const ushort local_size) {
    //     this._frame = frame;
    //     this.local_size = local_size;
    // }
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

    // immutable(ubyte[]) frame
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
