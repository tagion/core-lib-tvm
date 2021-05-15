import tagion.vm.warm.WasmVM;

@safe
struct WasmVM {
    union WasmType {
        @(Types.I32) int i32;
        @(Types.I64) long i64;
        @(Types.F32) float f32;
        @(Types.F64) double f64;
    }
    WasmType[] stack;
    WasmType[] globals;
    WasmType[] locals;
    uint ip;
    uint sp;

    struct OpCode {
        void delegate() op;
        int arg;
    }

    nothrow {
        final void push(T)(T x) {
            static if (is(T:int)) {
                stack[sp++].i32=x;
            }
            else static if (is(T:long)) {
                stack[sp++].i64=x;
            }
            else static if (is(T:float)) {
                stack[sp++].f32=x;
            }
            else static if (is(T:double)) {
                stack[sp++].f64=x;
            }
            else {
                static assert(0, T.stringof~" is not supported");
            }
        }

        final auto pop(T)() {
            static if (is(T:int)) {
                return stack[--sp].i32;
            }
            else static if (is(T:long)) {
                return stack[--sp].i64;
            }
            else static if (is(T:float)) {
                return stack[--sp].f32;
            }
            else static if (is(T:double)) {
                return stack[--sp].f64;
            }
            else {
                static assert(0, T.stringof~" is not supported");
            }
        }

        final void binop(T, string op)() {
            enum code=format(q{stack[sp] %s= pop!T;}, op);
            mixin(code);
            ip++;
        }

        final void unop(T, string op)() {
            enum code=format(q{stack[sp]= %s stack[sp].get!T;}, op);
            mixin(code);
            ip++;
        }

        final void funcop(T, string func)() {
            enum code=format(q{stack[sp]= %s(stack[sp].get!T);}, func);
            mixin(code);
            ip++;
        }

        final void comp(T, string cond)() {
            enum code=format(q{stack[sp]= int(stack[sp].get!T cond pop!T));}, cond);
            mixin(code);
            ip++;
        }

    }

    class Function {
        WasmType[] frame_lp;
        immutable(ubyte[]) frame_ip;
        size_t ip;
        @nogc private ushort get_offset() pure nothrow {
            scope(exit) {
                ip+=2;
            }
            return cast(ushort)(&frame_ip[ip]);
        }
        @nogc final void push(T)(const T x) if ((isIntegral!T || isFloat!T) && ((T.sizeof is int.sizeof) || (T.sizeof is long.sizeof))) pure nothrow {
            static if (is(T:int)) {
                frame_lp[get_offset].i32 = x;
            }
            else static if (is(T:long)) {
                frame_lp[get_offset].i64 = x;
            }
            else static if (is(T:float)) {
                frame_lp[get_offset].f32 = x;
            }
            else static if (is(T:double)) {
                frame_lp[get_offset].f64 = x;
            }
        }

#define DEF_OP_CMP(src_type, src_op_type, cond) do {                \
    SET_OPERAND(uint32, 4, GET_OPERAND(src_type, 2) cond            \
        GET_OPERAND(src_type, 0));                                  \
    frame_ip += 6;                                                  \
  } while (0)

//    uint[] frame_lp;
    #define GET_OPERAND(type, off) (*(type*)(frame_lp + *(int16*)(frame_ip + off)))

          HANDLE_OP (WASM_OP_I64_GE_S):
        DEF_OP_CMP(int64, I64, >=);2
        HANDLE_OP_END ();
#define SET_OPERAND(type, off, value)           \
    (*(type*)(frame_lp + *(int16*)(frame_ip + off))) = value2


    #define DEF_OP_CMP(src_type, src_op_type, cond) do {                \
    SET_OPERAND(uint32, 4, GET_OPERAND(src_type, 2) cond            \
        GET_OPERAND(src_type, 0));                                  \
    frame_ip += 6;                                                  \
  } while (0)


        with(IR) {
            final switch(op) {
            case UNREACHABLE:
                break;
            case NOP:
                break;
            case BLOCK:
                break;
            case LOOP:
                break;
            case IF:
                break;
            case ELSE:
                break;
            case END:
                break;
            case BR:
                break;
            case BR_IF:
                break;
            case BR_TABLE:
                break;
            case RETURN:
                break;
            case CALL:
                break;
            case CALL_INDIRECT:
                break;
            case DROP:
                break;
            case SELECT:
                break;
            case LOCAL_GET:
                break;
            case LOCAL_SET:
                break;
            case LOCAL_TEE:
                break;
            case GLOBAL_GET:
                break;
            case GLOBAL_SET:
                break;

            case I32_LOAD:
                break;
            case I64_LOAD:
                break;
            case F32_LOAD:
                break;
            case F64_LOAD:
                break;
            case I32_LOAD8_S:
                break;
            case I32_LOAD8_U:
                break;
            case I32_LOAD16_S:
                break;
            case I32_LOAD16_U:
                break;
            case I64_LOAD8_S:
                break;
            case I64_LOAD8_U:
                break;
            case I64_LOAD16_S:
                break;
            case I64_LOAD16_U:
                break;
            case I64_LOAD32_S:
                break;
            case I64_LOAD32_U:
                break;
            case I32_STORE:
                break;
            case I64_STORE:
                break;
            case F32_STORE:
                break;
            case F64_STORE:
                break;
            case I32_STORE8:
                break;
            case I32_STORE16:
                break;
            case I64_STORE8:
                break;
            case I64_STORE16:
                break;
            case I64_STORE32:
                break;
            case MEMORY_SIZE:
                break;
            case MEMORY_GROW:
                break;

            case I32_CONST:
                break;
            case I64_CONST:
                break;
            case F32_CONST:
                break;
            case F64_CONST:

                break;
            case I32_EQZ:
                break;
            case I32_EQ:
                break;
            case I32_NE:
                break;
            case I32_LT_S:
                break;
            case I32_LT_U:
                break;
            case I32_GT_S:
                break;
            case I32_GT_U:
                break;
            case I32_LE_S:
                break;
            case I32_LE_U:
                break;
            case I32_GE_S:
                break;
            case I32_GE_U:

            case I64_EQZ:
                break;
            case I64_EQ:
                break;
            case I64_NE:
                break;
            case I64_LT_S:

                break;
            case I64_LT_U:
                break;
            case I64_GT_S:
                break;
            case I64_GT_U:
                break;
            case I64_LE_S:
                break;
            case I64_LE_U:
                break;
            case I64_GE_S:
                break;
            case I64_GE_U:
                break;

            case F32_EQ:
                break;
            case F32_NE:
                break;
            case F32_LT:
                break;
            case F32_GT:
                break;
            case F32_LE:
                break;
            case F32_GE:
                break;

            case F64_EQ:
                break;
            case F64_NE:
                break;
            case F64_LT:
                break;
            case F64_GT:
                break;
            case F64_LE:
                break;
            case F64_GE:


            case I32_CLZ:
                break;
            case I32_CTZ:
                break;
            case I32_POPCNT:
                break;
            case I32_ADD:
                return OpCode(&binop!(int, "+"), 0);
            case I32_SUB:
                return OpCode(&binop!(int, "-"), 0);
            case I32_MUL:
                return OpCode(&binop!(int, "*"), 0);
            case I32_DIV_S:
                return OpCode(&binop!(int, "/"), 0);
            case I32_DIV_U:
                return OpCode(&binop!(uint, "/"), 0);
            case I32_REM_S:
                return OpCode(&binop!(int, "%"), 0);
            case I32_REM_U:
                return OpCode(&binop!(uint, "%"), 0);
            case I32_AND:
                return OpCode(&binop!(uint, "&"), 0);
            case I32_OR:
                return OpCode(&binop!(uint, "|"), 0);
            case I32_XOR:
                return OpCode(&binop!(uint, "^"), 0);
            case I32_SHL:
                break;
            case I32_SHR_S:
                break;
            case I32_SHR_U:
                break;
            case I32_ROTL:
                break;
            case I32_ROTR:
                break;

            case I64_CLZ:
                break;
            case I64_CTZ:
                break;
            case I64_POPCNT:
                break;
            case I64_ADD:
                return OpCode(&binop!(long, "+"), 0);
            case I64_SUB:
                return OpCode(&binop!(long, "-"), 0);
            case I64_MUL:
                return OpCode(&binop!(long, "*"), 0);
            case I64_DIV_S:
                return OpCode(&binop!(long, "/"), 0);
            case I64_DIV_U:
                return OpCode(&binop!(ulong, "/"), 0);
            case I64_REM_S:
                return OpCode(&binop!(long, "%"), 0);
            case I64_REM_U:
                return OpCode(&binop!(ulong, "%"), 0);
            case I64_AND:
                return OpCode(&binop!(ulong, "&"), 0);
            case I64_OR:
                return OpCode(&binop!(ulong, "|"), 0);
            case I64_XOR:
                return OpCode(&binop!(ulong, "^"), 0);
            case I64_SHL:
                break;
            case I64_SHR_S:
                break;
            case I64_SHR_U:
                break;
            case I64_ROTL:
                break;
            case I64_ROTR:

            case F32_ABS:
                break;
            case F32_NEG:
                break;
            case F32_CEIL:
                break;
            case F32_FLOOR:
                break;
            case F32_TRUNC:
                break;
            case F32_NEAREST:
                break;
            case F32_SQRT:
                break;
            case F32_ADD:
                return OpCode(&binop!(float, "+"), 0);
            case F32_SUB:
                return OpCode(&binop!(float, "-"), 0);
            case F32_MUL:
                return OpCode(&binop!(float, "*"), 0);
            case F32_DIV:
                return OpCode(&binop!(float, "/"), 0);
            case F32_MIN:
                break;
            case F32_MAX:
                break;
            case F32_COPYSIGN:
                break;

            case F64_ABS:
                break;
            case F64_NEG:
                return OpCode(&unop!(double, "+"), 0);
                break;
            case F64_CEIL:
                break;
            case F64_FLOOR:
                break;
            case F64_TRUNC:
                break;
            case F64_NEAREST:
                break;
            case F64_SQRT:
                break;
            case F64_ADD:
                return OpCode(&binop!(double, "+"), 0);
            case F64_SUB:
                return OpCode(&binop!(double, "-"), 0);
                break;
            case F64_MUL:
                return OpCode(&binop!(double, "*"), 0);
            case F64_DIV:
                return OpCode(&binop!(double, "/"), 0);
            case F64_MIN:
                break;
            case F64_MAX:
                break;
            case F64_COPYSIGN:
                break;

            case I32_WRAP_I64:
                break;
            case I32_TRUNC_F32_S:
                break;
            case I32_TRUNC_F32_U:
                break;
            case I32_TRUNC_F64_S:
                break;
            case I32_TRUNC_F64_U:
                break;
            case I64_EXTEND_I32_S:
                break;
            case I64_EXTEND_I32_U:
                break;
            case I64_TRUNC_F32_S:
                break;
            case I64_TRUNC_F32_U:
                break;
            case I64_TRUNC_F64_S:
                break;
            case I64_TRUNC_F64_U:
                break;
            case F32_CONVERT_I32_S:
                break;
            case F32_CONVERT_I32_U:
                break;
            case F32_CONVERT_I64_S:
                break;
            case F32_CONVERT_I64_U:
                break;
            case F32_DEMOTE_F64:
                break;
            case F64_CONVERT_I32_S:
                break;
            case F64_CONVERT_I32_U:
                break;
            case F64_CONVERT_I64_S:
                break;
            case F64_CONVERT_I64_U:
                break;
            case F64_PROMOTE_F32:
                break;
            case I32_REINTERPRET_F32:
                break;
            case I64_REINTERPRET_F64:
                break;
            case F32_REINTERPRET_I32:
                break;
            case F64_REINTERPRET_I64:
                break;


            }
        }
}
