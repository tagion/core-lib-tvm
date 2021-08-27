module tagion.tvm.TVMExecuter;

import std.stdio;

//import tagion.tvm.wasm;
import tagion.tvm.TVMExtOpcode;
import tagion.tvm.TVMBasic : FunctionInstance;
import tagion.tvm.TVMLoader : TVMModules;
import tagion.tvm.TVMContext : TVMError, TVMContext;
import std.traits : isIntegral, isFloatingPoint, isNumeric;
import LEB128 = tagion.utils.LEB128;
import std.bitmanip : binpeek = peek;
import core.exception : RangeError;

struct TVMExecuter {
    bool unwined;
    void bytecode_call(ref const(TVMModules.ModuleInstance) mod_instance, ref TVMContext ctx) {
        scope (exit) {
            if (unwined) {
                // Do some unwineding
            }
        }
        void bytecode_func(size_t ip, const uint local_offset, const uint local_size) {
            try {
                scope (exit) {
                    if (unwined) {
                        // Do some unwineding
                    }
                }
                auto locals = ctx.locals[local_offset .. local_offset + local_size];
                FETCH_LOOP: while (ip < mod_instance.frame.length) {
                    const opcode = mod_instance.frame[ip++];
                    @safe void read_leb(T)(ref T x) nothrow if (isIntegral!T) {
                        const result = LEB128.decode!T(mod_instance.frame[ip .. $]);
                        ip += cast(uint) result.size;
                        x = result.value;
                    }

                    void op_const(T)() @trusted nothrow {
                        static if (isIntegral!T) {
                            T x;
                            read_leb(x);
                            ctx.push(x);
                        }
                        else static if (isFloatingPoint!T) {
                            T x = *cast(T*)&mod_instance.frame[ip];
                            ip += T.sizeof;
                            ctx.push(x);
                        }
                        else {
                            static assert(0, format!"%s is not supported"(T.stringof));
                        }
                    }

                    @safe bool load(DST, SRC)() nothrow {
                        uint offset, alignment;
                        read_leb!uint(alignment);
                        assert(alignment <= 3, "Max value for aligment is 3");
                        read_leb!uint(offset);
                        return ctx.op_load!(DST, SRC)(offset << alignment, ip);
                    }

                    @safe bool store(DST, SRC)() nothrow {
                        uint offset, alignment;
                        read_leb!uint(alignment);
                        assert(alignment <= 3, "Max value for aligment is 3");
                        read_leb!uint(offset);
                        return ctx.op_store!(DST, SRC)(offset << alignment, ip);
                    }

                    version (none) @safe void op_trunc(DST, SRC, bool saturating)() nothrow
                            if (isNumeric!DST && isNumeric!SRC) {
                        const src_value = ctx.pop!SRC;
                        static if (isFloatingPoint!SRC && !saturating) {
                            if (isnan(src_value)) {
                                wasm_set_exception(wasm_module, "invalid conversion to integer");
                                return true;
                            }
                            else if (src_value <= src.value || src_value >= src_max) {
                                wasm_set_exception(wasm_module, "integer overflow");
                                return true;
                            }
                        }
                        const res = trunc!DST(x);
                        ctx.push(res);
                        return false;

                    }

                    import std.math;

                    with (ExtendedIR) {
                        final switch (opcode) {
                        case UNREACHABLE:
                            ctx.set_exception(ip, "unreachable");
                            goto case ERROR;
                            continue;
                        case BR_IF:
                            const cond = ctx.pop!int;
                            const branch_else = mod_instance.frame[ip .. $].binpeek!uint(&ip);
                            //ip+=uint.sizeof;
                            /* condition of the if branch is false, else condition is met */
                            if (cond == 0) {
                                ip = branch_else;
                            }
                            continue;
                        case BR_TABLE:
                            uint lN;
                            read_leb(lN);
                            const L = (cast(uint*)&mod_instance.frame[ip])[0 .. lN + 1];
                            const didx = ctx.pop!uint;
                            if (didx < lN) {
                                ip = L[didx];
                            }
                            else {
                                ip = L[$ - 1];
                            }
                            continue;
                        case RETURN:
                            return;
                        case CALL:
                            uint fidx;
                            read_leb(fidx);
                            const func = mod_instance.funcs_table[fidx];
                            bytecode_func(func.ip, local_offset + local_size, func.local_size);
                            continue;
                        case EXTERNAL_CALL:
                            uint fidx;
                            read_leb(fidx);
                            const func = mod_instance.funcs_table[fidx];
                            //if (func.isLocalFunc) {
                            assert(0, "Imported function is not supported yet");
                            //bytecode_func(func.ip, local_offset+local_size, func.local_size);
                            continue;
                        case CALL_INDIRECT:
                            const fidx = ctx.pop!uint;
                            const func = mod_instance.funcs_table[fidx];
                            if (func.isLocalFunc) {
                                bytecode_func(func.ip, local_offset + local_size, func.local_size);
                            }
                            else {
                                assert(0, "Imported function is not supported yet");
                            }
                            continue;
                            /* parametric instructions */
                        case DROP:
                            ctx.op_drop;
                            continue;
                        case SELECT:
                            ctx.op_select;
                            continue;
                        case LOCAL_GET:
                            uint local_index;
                            read_leb(local_index);
                            ctx.push(locals[local_index]);
                            continue;
                        case LOCAL_SET:
                            uint local_index;
                            read_leb(local_index);
                            locals[local_index] = ctx.pop!long;
                            continue;
                        case LOCAL_TEE:
                            uint local_index;
                            read_leb(local_index);
                            locals[local_index] = ctx.peek!long;
                            continue;
                        case GLOBAL_GET:
                            uint global_index;
                            read_leb(global_index);
                            ctx.push(ctx.globals[global_index]);
                            continue;
                        case GLOBAL_SET:
                            uint global_index;
                            read_leb(global_index);
                            ctx.globals[global_index] = ctx.pop!long;
                            continue;
                            /* memory load instructions */
                        case I32_LOAD:
                        case F32_LOAD:
                            if (load!(int, int))
                                goto case ERROR;
                            continue;
                        case I64_LOAD:
                        case F64_LOAD:
                            if (load!(long, long))
                                goto case ERROR;
                            continue;
                        case I32_LOAD8_S:
                            if (load!(int, byte))
                                goto case ERROR;
                            continue;
                        case I32_LOAD8_U:
                            if (load!(int, ubyte))
                                goto case ERROR;
                            continue;
                        case I32_LOAD16_S:
                            if (load!(int, short))
                                goto case ERROR;
                            continue;
                        case I32_LOAD16_U:
                            if (load!(int, ushort))
                                goto case ERROR;
                            continue;
                        case I64_LOAD8_S:
                            if (load!(long, byte))
                                goto case ERROR;
                            continue;
                        case I64_LOAD8_U:
                            if (load!(long, ubyte))
                                goto case ERROR;
                            continue;
                        case I64_LOAD16_S:
                            if (load!(long, short))
                                goto case ERROR;
                            continue;
                        case I64_LOAD16_U:
                            if (load!(long, ushort))
                                goto case ERROR;
                            continue;
                        case I64_LOAD32_S:
                            if (load!(long, int))
                                goto case ERROR;
                            continue;
                        case I64_LOAD32_U:
                            if (load!(long, uint))
                                goto case ERROR;
                            continue;
                            /* memory store instructions */
                        case I32_STORE:
                        case F32_STORE:
                            store!(int, int);
                            continue;
                        case I64_STORE:
                        case F64_STORE:
                            store!(long, long);
                            continue;
                        case I32_STORE8:
                            store!(byte, int);
                            continue;

                        case I32_STORE16:
                            store!(short, int);
                            continue;
                        case I64_STORE8:
                            store!(byte, long);
                            continue;

                        case I64_STORE16:
                            store!(short, long);
                            continue;
                        case I64_STORE32:
                            store!(int, long);
                            continue;
                            /* memory size and memory grow instructions */
                        case MEMORY_SIZE:
                            ctx.op_memory_size;
                            continue;

                        case MEMORY_GROW:
                            ctx.op_memory_grow;
                            continue;
                            continue;
                        case I32_CONST:
                            op_const!int;
                            continue;
                        case I64_CONST:
                            op_const!long;
                            continue;
                        case F32_CONST:
                            op_const!float;
                            continue;
                        case F64_CONST:
                            op_const!double;
                            continue;
                            /* comparison instructions of i32 */
                        case I32_EQZ:
                            ctx.op_eqz!int;
                            continue;
                        case I32_EQ:
                            ctx.op_cmp!(int, "==");
                            continue;
                        case I32_NE:
                            ctx.op_cmp!(int, "!=");
                            continue;
                        case I32_LT_S:
                            ctx.op_cmp!(int, "<");
                            continue;
                        case I32_LT_U:
                            ctx.op_cmp!(uint, "<");
                            continue;
                        case I32_GT_S:
                            ctx.op_cmp!(int, ">");
                            continue;
                        case I32_GT_U:
                            ctx.op_cmp!(uint, ">");
                            continue;
                        case I32_LE_S:
                            ctx.op_cmp!(int, "<=");
                            continue;
                        case I32_LE_U:
                            ctx.op_cmp!(uint, "<=");
                            continue;
                        case I32_GE_S:
                            ctx.op_cmp!(int, ">=");
                            continue;
                        case I32_GE_U:
                            ctx.op_cmp!(uint, ">=");
                            continue;
                            /* comparison instructions of i64 */
                        case I64_EQZ:
                            ctx.op_eqz!long;
                            continue;
                        case I64_EQ:
                            ctx.op_cmp!(ulong, "==");
                            continue;
                        case I64_NE:
                            ctx.op_cmp!(ulong, "!=");
                            continue;
                        case I64_LT_S:
                            ctx.op_cmp!(long, "<");
                            continue;
                        case I64_LT_U:
                            ctx.op_cmp!(ulong, "<");
                            continue;
                        case I64_GT_S:
                            ctx.op_cmp!(long, ">");
                            continue;
                        case I64_GT_U:
                            ctx.op_cmp!(ulong, ">");
                            continue;
                        case I64_LE_S:
                            ctx.op_cmp!(long, "<=");
                            continue;
                        case I64_LE_U:
                            ctx.op_cmp!(ulong, "<=");
                            continue;
                        case I64_GE_S:
                            ctx.op_cmp!(ulong, ">=");
                            continue;
                        case I64_GE_U:
                            ctx.op_cmp!(long, ">=");
                            continue;
                            /* comparison instructions of f32 */
                        case F32_EQ:
                            ctx.op_cmp!(float, "==");
                            continue;
                        case F32_NE:
                            ctx.op_cmp!(float, "!=");
                            continue;
                        case F32_LT:
                            ctx.op_cmp!(float, "<");
                            continue;
                        case F32_GT:
                            ctx.op_cmp!(float, ">");
                            continue;
                        case F32_LE:
                            ctx.op_cmp!(float, "<=");
                            continue;
                        case F32_GE:
                            ctx.op_cmp!(float, ">=");
                            continue;
                            /* comparison instructions of f64 */
                        case F64_EQ:
                            ctx.op_cmp!(double, "==");
                            continue;
                        case F64_NE:
                            ctx.op_cmp!(double, "!=");
                            continue;
                        case F64_LT:
                            ctx.op_cmp!(double, "<");
                            continue;
                        case F64_GT:
                            ctx.op_cmp!(double, ">");
                            continue;
                        case F64_LE:
                            ctx.op_cmp!(double, "<=");
                            continue;
                        case F64_GE:
                            ctx.op_cmp!(double, ">=");
                            continue;
                            /* numberic instructions of i32 */
                        case I32_CLZ:
                            ctx.op_clz!int;
                            continue;
                        case I32_CTZ:
                            ctx.op_ctz!int;
                            continue;
                        case I32_POPCNT:
                            ctx.op_popcount!int;
                            continue;
                        case I32_ADD:
                            ctx.op_cat!(uint, "+");
                            continue;
                        case I32_SUB:
                            ctx.op_cat!(uint, "-");
                            continue;
                        case I32_MUL:
                            ctx.op_cat!(uint, "*");
                            continue;
                        case I32_DIV_S:
                            if (ctx.op_div!int(ip)) {
                                goto case ERROR;
                            }
                            continue;
                        case I32_DIV_U:
                            if (ctx.op_div!uint(ip)) {
                                goto case ERROR;
                            }
                            continue;
                        case I32_REM_S:
                            if (ctx.op_rem!int) {
                                goto case ERROR;
                            }
                            continue;
                        case I32_REM_U:
                            if (ctx.op_rem!uint) {
                                goto case ERROR;
                            }
                            continue;
                        case I32_AND:
                            ctx.op_cat!(uint, "&");
                            continue;
                        case I32_OR:
                            ctx.op_cat!(uint, "|");
                            continue;
                        case I32_XOR:
                            ctx.op_cat!(uint, "^");
                            continue;
                        case I32_SHL:
                            ctx.op_cat!(uint, "<<");
                            continue;
                        case I32_SHR_S:
                            ctx.op_cat!(int, ">>");
                            continue;
                        case I32_SHR_U:
                            ctx.op_cat!(uint, ">>");
                            continue;
                        case I32_ROTL:
                            ctx.op_rotl!int;
                            continue;
                        case I32_ROTR:
                            ctx.op_rotr!int;
                            continue;
                            /* numberic instructions of i64 */
                        case I64_CLZ:
                            ctx.op_clz!int;
                            continue;
                        case I64_CTZ:
                            ctx.op_ctz!int;
                            continue;
                        case I64_POPCNT:
                            ctx.op_popcount!int;
                            continue;
                        case I64_ADD:
                            ctx.op_cat!(ulong, "+");
                            continue;
                        case I64_SUB:
                            ctx.op_cat!(ulong, "-");
                            continue;
                        case I64_MUL:
                            ctx.op_cat!(ulong, "*");
                            continue;
                        case I64_DIV_S:
                            if (ctx.op_div!long(ip)) {
                                goto case ERROR;
                            }
                            continue;
                        case I64_DIV_U:
                            if (ctx.op_div!ulong(ip)) {
                                goto case ERROR;
                            }
                            continue;
                        case I64_REM_S:
                            if (ctx.op_rem!long) {
                                goto case ERROR;
                            }
                            continue;
                        case I64_REM_U:
                            if (ctx.op_rem!ulong) {
                                goto case ERROR;
                            }
                            continue;
                        case I64_AND:
                            ctx.op_cat!(ulong, "&");
                            continue;
                        case I64_OR:
                            ctx.op_cat!(ulong, "|");
                            continue;
                        case I64_XOR:
                            ctx.op_cat!(ulong, "^");
                            continue;
                        case I64_SHL:
                            ctx.op_cat!(ulong, "<<");
                            continue;
                        case I64_SHR_S:
                            ctx.op_cat!(long, ">>");
                            continue;
                        case I64_SHR_U:
                            ctx.op_cat!(ulong, ">>");
                            continue;
                        case I64_ROTL:
                            ctx.op_rotl!long;
                            continue;
                        case I64_ROTR:
                            ctx.op_rotr!long;
                            continue;
                            /* numberic instructions of f32 */
                        case F32_ABS:
                            const x = fabs(float(-1));
                            ctx.op_math!(float, "fabs");
                            continue;
                        case F32_NEG:
                            ctx.op_unary!(float, "-");
                            continue;
                        case F32_CEIL:
                            ctx.op_math!(float, "ceil");
                            continue;
                        case F32_FLOOR:
                            ctx.op_math!(float, "floor");
                            continue;
                        case F32_TRUNC:
                            ctx.op_math!(float, "trunc");
                            continue;
                        case F32_NEAREST:
                            ctx.op_math!(float, "rint");
                            continue;
                        case F32_SQRT:
                            ctx.op_math!(float, "sqrt");
                            continue;
                        case F32_ADD:
                            ctx.op_cat!(float, "+");
                            continue;
                        case F32_SUB:
                            ctx.op_cat!(float, "-");
                            continue;
                        case F32_MUL:
                            ctx.op_cat!(float, "*");
                            continue;
                        case F32_DIV:
                            ctx.op_cat!(float, "/");
                            continue;
                        case F32_MIN:
                            ctx.op_min!float;
                            continue;
                        case F32_MAX:
                            ctx.op_max!float;
                            continue;
                        case F32_COPYSIGN:
                            ctx.op_copysign!float;
                            continue;
                        case F64_ABS:
                            ctx.op_math!(float, "fabs");
                            continue;
                        case F64_NEG:
                            ctx.op_unary!(double, "-");
                            continue;
                        case F64_CEIL:
                            ctx.op_math!(double, "ceil");
                            continue;
                        case F64_FLOOR:
                            ctx.op_math!(double, "floor");
                            continue;
                        case F64_TRUNC:
                            ctx.op_math!(double, "trunc");
                            continue;
                        case F64_NEAREST:
                            ctx.op_math!(double, "rint");
                            continue;
                        case F64_SQRT:
                            ctx.op_math!(double, "sqrt");
                            continue;
                        case F64_ADD:
                            ctx.op_cat!(double, "/");
                            continue;
                        case F64_SUB:
                            ctx.op_cat!(double, "-");
                            continue;
                        case F64_MUL:
                            ctx.op_cat!(double, "*");
                            continue;
                        case F64_DIV:
                            ctx.op_cat!(double, "/");
                            continue;
                        case F64_MIN:
                            ctx.op_min!double;
                            continue;
                        case F64_MAX:
                            ctx.op_max!double;
                            continue;
                        case F64_COPYSIGN:
                            ctx.op_copysign!double;
                            continue;
                            /* conversions of i32 */
                        case I32_WRAP_I64:
                            ctx.op_wrap!(int, long);
                            // const value = ctx.pop!int; //(int)(PI64() & 0xFFFFFFFFLL);
                            // ctx.push(value);
                            continue;
                        case I32_TRUNC_F32_S:
                            /* We don't use INT_MIN/INT_MAX/UINT_MIN/UINT_MAX,
           since float/double values of ieee754 cannot precisely represent
           all int/uint/int64/uint64 values, e.g.:
           UINT_MAX is 4294967295, but (float32)4294967295 is 4294967296.0f,
           but not 4294967295.0f. */
                            if (ctx.op_trunc!(int, float))
                                goto case ERROR;
                            continue;
                        case I32_TRUNC_F32_U:
                            if (ctx.op_trunc!(uint, float))
                                goto case ERROR;
                            continue;
                        case I32_TRUNC_F64_S:
                            if (ctx.op_trunc!(int, double))
                                goto case ERROR;
                            continue;
                        case I32_TRUNC_F64_U:
                            if (ctx.op_trunc!(int, double))
                                goto case ERROR;
                            continue;
                            /* conversions of i64 */
                        case I64_EXTEND_I32_S:
                            ctx.op_convert!(long, int);
                            continue;
                        case I64_EXTEND_I32_U:
                            ctx.op_convert!(long, uint);
                            continue;
                        case I64_TRUNC_F32_S:
                            if (ctx.op_trunc!(long, float))
                                goto case ERROR;
                            continue;
                        case I64_TRUNC_F32_U:
                            if (ctx.op_trunc!(ulong, float))
                                goto case ERROR;
                            continue;
                        case I64_TRUNC_F64_S:
                            if (ctx.op_trunc!(long, double))
                                goto case ERROR;
                            continue;
                        case I64_TRUNC_F64_U:
                            if (ctx.op_trunc!(ulong, double))
                                goto case ERROR;
                            continue;
                            /* conversions of f32 */
                        case F32_CONVERT_I32_S:
                            ctx.op_convert!(float, int);
                            continue;
                        case F32_CONVERT_I32_U:
                            ctx.op_convert!(float, uint);
                            continue;
                        case F32_CONVERT_I64_S:
                            ctx.op_convert!(float, long);
                            continue;
                        case F32_CONVERT_I64_U:
                            ctx.op_convert!(float, ulong);
                            continue;
                        case F32_DEMOTE_F64:
                            ctx.op_convert!(float, double);
                            continue;
                            /* conversions of f64 */
                        case F64_CONVERT_I32_S:
                            ctx.op_convert!(double, int);
                            continue;
                        case F64_CONVERT_I32_U:
                            ctx.op_convert!(double, uint);
                            continue;
                        case F64_CONVERT_I64_S:
                            ctx.op_convert!(double, long);
                            continue;
                        case F64_CONVERT_I64_U:
                            ctx.op_convert!(double, ulong);
                            continue;
                        case F64_PROMOTE_F32:
                            ctx.op_convert!(double, float);
                            continue;
                            /* reinterpretations */
                        case I32_REINTERPRET_F32:
                        case I64_REINTERPRET_F64:
                        case F32_REINTERPRET_I32:
                        case F64_REINTERPRET_I64:
                            continue;
                        case I32_EXTEND8_S:
                            ctx.op_convert!(int, byte);
                            continue;
                        case I32_EXTEND16_S:
                            ctx.op_convert!(int, short);
                            continue;
                        case I64_EXTEND8_S:
                            ctx.op_convert!(long, byte);
                            continue;
                        case I64_EXTEND16_S:
                            ctx.op_convert!(long, short);
                            continue;
                        case I64_EXTEND32_S:
                            ctx.op_convert!(long, int);
                            continue;
                        case I32_TRUNC_SAT_F32_S:
                            ctx.op_trunc_sat!(int, float);
                            continue;
                        case I32_TRUNC_SAT_F32_U:
                            ctx.op_trunc_sat!(uint, float);
                            continue;
                        case I32_TRUNC_SAT_F64_S:
                            ctx.op_trunc_sat!(int, double);
                            continue;
                        case I32_TRUNC_SAT_F64_U:
                            ctx.op_trunc_sat!(uint, double);
                            continue;
                        case I64_TRUNC_SAT_F32_S:
                            ctx.op_trunc_sat!(long, float);
                            continue;
                        case I64_TRUNC_SAT_F32_U:
                            ctx.op_trunc_sat!(ulong, float);
                            continue;
                        case I64_TRUNC_SAT_F64_S:
                            ctx.op_trunc_sat!(long, double);
                            continue;
                        case I64_TRUNC_SAT_F64_U:
                            ctx.op_trunc_sat!(ulong, double);
                            continue;
                        case ERROR:
                            unwined = true;
                        }
                    }
                }
            }
            catch (RangeError err) {
                ///
                if (ctx.sp <= 2) {
                    ctx.error = TVMError.STACK_EMPTY;
                }
                else {
                    //                ctx.error = TVMError.STACK_OVERFLOW;
                    // }
                    // else {
                    ctx.error = TVMError.STACK_OVERFLOW;
                }
                unwined =true;
            }
        }
    }
}
