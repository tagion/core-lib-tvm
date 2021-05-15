module tagion.vm.wamr.WasmInterpreter;

struct WasmInterpreter {
  //   template DEF_OP_CMP(src_type, src_op_type, cond) do {           \
  //   SET_OPERAND(uint32, 4, GET_OPERAND(src_type, 2) cond            \
  //       GET_OPERAND(src_type, 0));                                  \
  //   frame_ip += 6;                                                  \
  // } while (0)


    void run() {
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
                break;
            case I32_SUB:
                break;
            case I32_MUL:
                break;
            case I32_DIV_S:
                break;
            case I32_DIV_U:
                break;
            case I32_REM_S:
                break;
            case I32_REM_U:
                break;
            case I32_AND:
                break;
            case I32_OR:
                break;
            case I32_XOR:
                break;
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
                break;
            case I64_SUB:
                break;
            case I64_MUL:
                break;
            case I64_DIV_S:
                break;
            case I64_DIV_U:
                break;
            case I64_REM_S:
                break;
            case I64_REM_U:
                break;
            case I64_AND:
                break;
            case I64_OR:
                break;
            case I64_XOR:
                break;
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
                break;
            case F32_SUB:
                break;
            case F32_MUL:
                break;
            case F32_DIV:
                break;
            case F32_MIN:
                break;
            case F32_MAX:
                break;
            case F32_COPYSIGN:
                break;

            case F64_ABS:
                break;
            case F64_NEG:
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
                break;
            case F64_SUB:
                break;
            case F64_MUL:
                break;
            case F64_DIV:
                break;
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
