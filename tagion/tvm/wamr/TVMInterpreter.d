/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.TVMInterpreter;

import std.stdio;

import tagion.tvm.wamr.wasm;
import tagion.tvm.wamr.TVMExtOpcode;
import tagion.tvm.wamr.TVMBasic : FunctionInstance;
import tagion.tvm.wamr.TVMLoader : ModuleInstance;
import tagion.tvm.wamr.TVMExecEnv : TVMExecEnv;
import std.traits : isIntegral, isFloatingPoint, isNumeric;
import LEB128 = tagion.utils.LEB128;
import std.bitmanip : binpeek = peek;

struct WASMInterpFrame {
  /* The frame of the caller that are calling the current function. */
    WASMInterpFrame *prev_frame;

    /* The current WASM function. */
    FunctionInstance* func;

    /* Instruction pointer of the bytecode array.  */
  ubyte *ip;

    version(WASM_ENABLE_FAST_INTERP) {
  /* return offset of the first return value of current frame.
    the callee will put return values here continuously */
        uint ret_offset;
        uint *lp;
        uint[1] operand;
    }
    else {
  /* Operand stack top pointer of the current frame.  The bottom of
     the stack is the next cell after the last local variable.  */
        uint *sp_bottom;
        uint *sp_boundary;
        uint *sp;

        WASMBranchBlock *csp_bottom;
        WASMBranchBlock *csp_boundary;
        WASMBranchBlock *csp;

  /* Frame data, the layout is:
     lp: param_cell_count + local_cell_count
     sp_bottom to sp_boundary: stack of data
     csp_bottom to csp_boundary: stack of block
     ref to frame end: data types of local vairables and stack data
     */
        uint[1] lp;
    }
}

void
wasm_interp_call_func_bytecode(ref const(ModuleInstance) mod_instance,
                               ref TVMExecEnv exec_env,
                               FunctionInstance *cur_func,
                               WASMInterpFrame *prev_frame)
{
    void bytecode_func(size_t ip, const uint local_offset, const uint local_size) {
        auto locals = exec_env.locals[local_offset..local_offset+local_size];
FETCH_LOOP: while(ip < mod_instance.frame.length) {
    const opcode = mod_instance.frame[ip++];
    @safe void read_leb(T)(ref T x) nothrow if (isIntegral!T) {
        const result=LEB128.decode!T(mod_instance.frame[ip..$]);
        ip+=cast(uint)result.size;
        x=result.value;
    }
    void op_const(T)() @trusted nothrow {
        static if (isIntegral!T) {
            T x;
            read_leb(x);
            exec_env.push(x);
        }
        else static if (isFloatingPoint!T) {
//            assert(ip+T.sizeof < mod_instance.frame
            T x=*cast(T*)&mod_instance.frame[ip]; //..ip+T.sizeof];
            ip+=T.sizeof;
            exec_env.push(x);
        }
        else {
            static assert(0, format!"%s is not supported"(T.stringof));
        }
    }
    @safe void load(DST,SRC)() {
        uint offset, alignment;
        read_leb!uint(alignment);
        assert(alignment <= 3, "Max value for aligment is 3");
        read_leb!uint(offset);
        exec_env.load!DST(offset << alignment);
    }
    @safe void store(DST,SRC)() {
        uint offset, alignment;
        read_leb!uint(alignment);
        assert(alignment <= 3, "Max value for aligment is 3");
        read_leb!uint(offset);
        exec_env.store!DST(offset << alignment);
    }
    @safe void op_trunc(DST, SRC, bool saturating)() nothrow if (isNumeric!DST && isNumeric!SRC) {
        const src_value = exec_env.pop!SRC;
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
        exec_env.push(res);
        return false;

    }
    import std.math;
    with(ExtendedIR) {
        final switch (opcode) {
      case UNREACHABLE:
          exec_env.set_exception(ip,"unreachable");
        goto case ERROR;
        continue;
      case BR_IF:
        const cond = exec_env.pop!int;
        const branch_else = mod_instance.frame[ip..$].binpeek!uint(&ip);
        //ip+=uint.sizeof;
        /* condition of the if branch is false, else condition is met */
        if (cond == 0) {
            ip = branch_else;
        }
        continue;
      case BR_TABLE:
          uint lN;
          read_leb(lN);
          const L=(cast(uint*)&mod_instance.frame[ip])[0..lN+1];
          const didx = exec_env.pop!uint;
          if (didx < lN) {
              ip = L[didx];
          }
          else {
              ip = L[$-1];
          }
          continue;
      case RETURN:
          return;
        // frame_sp -= cur_func.ret_cell_num;
        // for (i = 0; i < cur_func.ret_cell_num; i++) {
        //   *prev_frame.sp++ = frame_sp[i];
        // }
        // goto return_func;

      case CALL:
          uint fidx;
          read_leb(fidx);
          const func = mod_instance.funcs_table[fidx];
          bytecode_func(func.ip, local_offset+local_size, func.local_size);
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
          const fidx = exec_env.pop!uint;
          const func = mod_instance.funcs_table[fidx];
          if (func.isLocalFunc) {
//              const func = exec_env.funcs[fidx];
              bytecode_func(func.ip, local_offset+local_size, func.local_size);
          }
          else {
              assert(0, "Imported function is not supported yet");
          }
          continue;
      /* parametric instructions */
      case DROP:
          exec_env.drop;
          continue;
      case SELECT:
          exec_env.op_select;
          continue;
      case LOCAL_GET:
          uint local_index;
          read_leb(local_index);
          exec_env.push(locals[local_index]);
          continue;
      case LOCAL_SET:
          uint local_index;
          read_leb(local_index);
          locals[local_index] = exec_env.pop!long;
          continue;
      case LOCAL_TEE:
          uint local_index;
          read_leb(local_index);
          locals[local_index] = exec_env.peek!long;
          continue;
      case GLOBAL_GET:
          uint global_index;
          read_leb(global_index);
          exec_env.push(exec_env.globals[global_index]);
          continue;
        case GLOBAL_SET:
          uint global_index;
          read_leb(global_index);
          exec_env.globals[global_index] = exec_env.pop!long;
          continue;
      /* memory load instructions */
        case I32_LOAD:
        case F32_LOAD:
            load!(int, int);
            continue;
        case I64_LOAD:
        case F64_LOAD:
            load!(long, long);
            continue;
        case I32_LOAD8_S:
            load!(int, byte);
            continue;
        case I32_LOAD8_U:
            load!(int, ubyte);
            continue;
        case I32_LOAD16_S:
            load!(int, short);
            continue;
        case I32_LOAD16_U:
            load!(int, ushort);
            continue;
        case I64_LOAD8_S:
            load!(long, byte);
            continue;
        case I64_LOAD8_U:
            load!(long, ubyte);
            continue;
        case I64_LOAD16_S:
            load!(long, short);
            continue;
        case I64_LOAD16_U:
            load!(long, ushort);
            continue;
        case I64_LOAD32_S:
            load!(long, int);
            continue;
        case I64_LOAD32_U:
            load!(long, uint);
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
            exec_env.op_memory_size;
            continue;

        case MEMORY_GROW:
            exec_env.op_memory_grow;
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
            exec_env.op_eqz!int;
            continue;
        case I32_EQ:
            exec_env.op_cmp!(int, "==");
            continue;
        case I32_NE:
            exec_env.op_cmp!(int, "!=");
            continue;
        case I32_LT_S:
            exec_env.op_cmp!(int, "<");
            continue;
        case I32_LT_U:
            exec_env.op_cmp!(uint, "<");
            continue;
        case I32_GT_S:
            exec_env.op_cmp!(int, ">");
            continue;
        case I32_GT_U:
            exec_env.op_cmp!(uint, ">");
            continue;
        case I32_LE_S:
            exec_env.op_cmp!(int, "<=");
            continue;
        case I32_LE_U:
            exec_env.op_cmp!(uint, "<=");
            continue;
        case I32_GE_S:
            exec_env.op_cmp!(int, ">=");
            continue;
        case I32_GE_U:
            exec_env.op_cmp!(uint, ">=");
            continue;
            /* comparison instructions of i64 */
        case I64_EQZ:
            exec_env.op_eqz!long;
            continue;
        case I64_EQ:
            exec_env.op_cmp!(ulong, "==");
            continue;
        case I64_NE:
            exec_env.op_cmp!(ulong, "!=");
            continue;
        case I64_LT_S:
            exec_env.op_cmp!(long, "<");
            continue;
        case I64_LT_U:
            exec_env.op_cmp!(ulong, "<");
            continue;
        case I64_GT_S:
            exec_env.op_cmp!(long, ">");
            continue;
        case I64_GT_U:
            exec_env.op_cmp!(ulong, ">");
            continue;
        case I64_LE_S:
            exec_env.op_cmp!(long, "<=");
            continue;
        case I64_LE_U:
            exec_env.op_cmp!(ulong, "<=");
            continue;
        case I64_GE_S:
            exec_env.op_cmp!(ulong, ">=");
            continue;
        case I64_GE_U:
            exec_env.op_cmp!(long, ">=");
            continue;
            /* comparison instructions of f32 */
        case F32_EQ:
            exec_env.op_cmp!(float, "==");
            continue;
        case F32_NE:
            exec_env.op_cmp!(float, "!=");
            continue;
        case F32_LT:
            exec_env.op_cmp!(float, "<");
            continue;
        case F32_GT:
            exec_env.op_cmp!(float, ">");
            continue;
        case F32_LE:
            exec_env.op_cmp!(float, "<=");
            continue;
        case F32_GE:
            exec_env.op_cmp!(float, ">=");
            continue;
            /* comparison instructions of f64 */
        case F64_EQ:
            exec_env.op_cmp!(double, "==");
            continue;
        case F64_NE:
            exec_env.op_cmp!(double, "!=");
            continue;
        case F64_LT:
            exec_env.op_cmp!(double, "<");
            continue;
      case F64_GT:
          exec_env.op_cmp!(double, ">");
          continue;
      case F64_LE:
          exec_env.op_cmp!(double, "<=");
          continue;
      case F64_GE:
          exec_env.op_cmp!(double, ">=");
          continue;
      /* numberic instructions of i32 */
      case I32_CLZ:
          exec_env.op_clz!int;
          continue;
      case I32_CTZ:
          exec_env.op_ctz!int;
          continue;
      case I32_POPCNT:
          exec_env.op_popcount!int;
          continue;
      case I32_ADD:
          exec_env.op_cat!(uint, "+");
          continue;
      case I32_SUB:
          exec_env.op_cat!(uint, "-");
          continue;
      case I32_MUL:
          exec_env.op_cat!(uint, "*");
          continue;
      case I32_DIV_S:
          if (exec_env.op_div!int(ip)) {
              goto case ERROR;
          }
          continue;
      case I32_DIV_U:
          if (exec_env.op_div!uint(ip)) {
              goto case ERROR;
          }
          continue;
      case I32_REM_S:
          if(exec_env.op_rem!int(ip)) {
              goto case ERROR;
          }
          continue;
      case I32_REM_U:
          if(exec_env.op_rem!uint(ip)) {
              goto case ERROR;
          }
          continue;
      case I32_AND:
          exec_env.op_cat!(uint, "&");
          continue;
      case I32_OR:
          exec_env.op_cat!(uint, "|");
          continue;
      case I32_XOR:
          exec_env.op_cat!(uint, "^");
          continue;
      case I32_SHL:
          exec_env.op_cat!(uint, "<<");
          continue;
      case I32_SHR_S:
          exec_env.op_cat!(int, ">>");
          continue;
      case I32_SHR_U:
          exec_env.op_cat!(uint, ">>");
          continue;
      case I32_ROTL:
          exec_env.op_rotl!int;
          continue;
      case I32_ROTR:
          exec_env.op_rotr!int;
          continue;
      /* numberic instructions of i64 */
      case I64_CLZ:
          exec_env.op_clz!int;
          continue;
      case I64_CTZ:
          exec_env.op_ctz!int;
          continue;
      case I64_POPCNT:
          exec_env.op_popcount!int;
          continue;
      case I64_ADD:
          exec_env.op_cat!(ulong, "+");
          continue;
      case I64_SUB:
          exec_env.op_cat!(ulong, "-");
          continue;
      case I64_MUL:
          exec_env.op_cat!(ulong, "*");
          continue;
      case I64_DIV_S:
          if (exec_env.op_div!long(ip)) {
              goto case ERROR;
          }
          continue;
      case I64_DIV_U:
          if (exec_env.op_div!ulong(ip)) {
              goto case ERROR;
          }
          continue;
      case I64_REM_S:
          if(exec_env.op_rem!long(ip)) {
              goto case ERROR;
          }
          continue;
      case I64_REM_U:
          if(exec_env.op_rem!ulong(ip)) {
              goto case ERROR;
          }
          continue;
      case I64_AND:
          exec_env.op_cat!(ulong, "&");
          continue;
      case I64_OR:
          exec_env.op_cat!(ulong, "|");
          continue;
      case I64_XOR:
          exec_env.op_cat!(ulong, "^");
          continue;
      case I64_SHL:
          exec_env.op_cat!(ulong, "<<");
          continue;
      case I64_SHR_S:
          exec_env.op_cat!(long, ">>");
          continue;
      case I64_SHR_U:
          exec_env.op_cat!(ulong, ">>");
          continue;
      case I64_ROTL:
          exec_env.op_rotl!long;
          continue;
      case I64_ROTR:
          exec_env.op_rotr!long;
          continue;
      /* numberic instructions of f32 */
      case F32_ABS:
          const x=fabs(float(-1));
          exec_env.op_math!(float, "fabs");
          continue;
      case F32_NEG:
          exec_env.op_unary!(float, "-");
          continue;
      case F32_CEIL:
          exec_env.op_math!(float, "ceil");
          continue;
      case F32_FLOOR:
          exec_env.op_math!(float, "floor");
          continue;
      case F32_TRUNC:
          exec_env.op_math!(float, "trunc");
          continue;
      case F32_NEAREST:
          exec_env.op_math!(float, "rint");
          continue;
      case F32_SQRT:
          exec_env.op_math!(float, "sqrt");
          continue;
      case F32_ADD:
          exec_env.op_cat!(float, "+");
          continue;
      case F32_SUB:
          exec_env.op_cat!(float, "-");
          continue;
      case F32_MUL:
          exec_env.op_cat!(float, "*");
          continue;
      case F32_DIV:
          exec_env.op_cat!(float, "/");
          continue;
      case F32_MIN:
          exec_env.op_min!float;
          continue;
      case F32_MAX:
          exec_env.op_max!float;
          continue;
      case F32_COPYSIGN:
          exec_env.op_copysign!float;
          continue;
      case F64_ABS:
          exec_env.op_math!(float, "fabs");
          continue;
          case F64_NEG:
              exec_env.op_unary!(double, "-");
              continue;
      case F64_CEIL:
          exec_env.op_math!(double, "ceil");
          continue;
      case F64_FLOOR:
          exec_env.op_math!(double, "floor");
          continue;
      case F64_TRUNC:
          exec_env.op_math!(double, "trunc");
          continue;
      case F64_NEAREST:
          exec_env.op_math!(double, "rint");
          continue;
      case F64_SQRT:
          exec_env.op_math!(double, "sqrt");
          continue;
      case F64_ADD:
          exec_env.op_cat!(double, "/");
            continue;
      case F64_SUB:
          exec_env.op_cat!(double, "-");
            continue;
      case F64_MUL:
          exec_env.op_cat!(double, "*");
            continue;
      case F64_DIV:
          exec_env.op_cat!(double, "/");
            continue;
      case F64_MIN:
            exec_env.op_min!double;
            continue;
      case F64_MAX:
          exec_env.op_max!double;
            continue;
      case F64_COPYSIGN:
          exec_env.op_copysign!double;
          continue;
      /* conversions of i32 */
      case I32_WRAP_I64:
          exec_env.op_wrap!(int, long);
          // const value = exec_env.pop!int; //(int)(PI64() & 0xFFFFFFFFLL);
          // exec_env.push(value);
          continue;
      case I32_TRUNC_F32_S:
        /* We don't use INT_MIN/INT_MAX/UINT_MIN/UINT_MAX,
           since float/double values of ieee754 cannot precisely represent
           all int/uint/int64/uint64 values, e.g.:
           UINT_MAX is 4294967295, but (float32)4294967295 is 4294967296.0f,
           but not 4294967295.0f. */
          if (exec_env.op_trunc!(int, float)) goto case ERROR;
          continue;
      case I32_TRUNC_F32_U:
          if (exec_env.op_trunc!(uint, float)) goto case ERROR;
            continue;
      case I32_TRUNC_F64_S:
          if (exec_env.op_trunc!(int, double)) goto case ERROR;
            continue;
      case I32_TRUNC_F64_U:
          if (exec_env.op_trunc!(int, double)) goto case ERROR;
            continue;
      /* conversions of i64 */
      case I64_EXTEND_I32_S:
          exec_env.op_convert!(long, int);
          continue;
      case I64_EXTEND_I32_U:
          exec_env.op_convert!(long, uint);
          continue;
      case I64_TRUNC_F32_S:
          if (exec_env.op_trunc!(long, float)) goto case ERROR;
          continue;
      case I64_TRUNC_F32_U:
          if (exec_env.op_trunc!(ulong, float)) goto case ERROR;
          continue;
      case I64_TRUNC_F64_S:
          if (exec_env.op_trunc!(long, double)) goto case ERROR;
          continue;
      case I64_TRUNC_F64_U:
          if (exec_env.op_trunc!(ulong, double)) goto case ERROR;
          continue;
      /* conversions of f32 */
      case F32_CONVERT_I32_S:
            exec_env.op_convert!(float, int);
            continue;
      case F32_CONVERT_I32_U:
            exec_env.op_convert!(float, uint);
            continue;
      case F32_CONVERT_I64_S:
            exec_env.op_convert!(float, long);
            continue;
      case F32_CONVERT_I64_U:
            exec_env.op_convert!(float, ulong);
            continue;
      case F32_DEMOTE_F64:
            exec_env.op_convert!(float, double);
            continue;
      /* conversions of f64 */
      case F64_CONVERT_I32_S:
            exec_env.op_convert!(double, int);
            continue;
      case F64_CONVERT_I32_U:
            exec_env.op_convert!(double, uint);
            continue;
      case F64_CONVERT_I64_S:
            exec_env.op_convert!(double, long);
            continue;
      case F64_CONVERT_I64_U:
            exec_env.op_convert!(double, ulong);
            continue;
      case F64_PROMOTE_F32:
            exec_env.op_convert!(double, float);
            continue;
      /* reinterpretations */
        case I32_REINTERPRET_F32:
        case I64_REINTERPRET_F64:
        case F32_REINTERPRET_I32:
        case F64_REINTERPRET_I64:
            continue;
      case I32_EXTEND8_S:
            exec_env.op_convert!(int, byte);
            continue;
      case I32_EXTEND16_S:
            exec_env.op_convert!(int, short);
            continue;
      case I64_EXTEND8_S:
            exec_env.op_convert!(long, byte);
            continue;
      case I64_EXTEND16_S:
            exec_env.op_convert!(long, short);
            continue;
      case I64_EXTEND32_S:
            exec_env.op_convert!(long, int);
            continue;
        case I32_TRUNC_SAT_F32_S:
            exec_env.op_trunc_sat!(int, float);
            continue;
        case I32_TRUNC_SAT_F32_U:
            exec_env.op_trunc_sat!(uint, float);
            continue;
        case I32_TRUNC_SAT_F64_S:
            exec_env.op_trunc_sat!(int, double);
            continue;
        case I32_TRUNC_SAT_F64_U:
            exec_env.op_trunc_sat!(uint, double);
            continue;
        case I64_TRUNC_SAT_F32_S:
            exec_env.op_trunc_sat!(long, float);
            continue;
        case I64_TRUNC_SAT_F32_U:
            exec_env.op_trunc_sat!(ulong, float);
            continue;
        case I64_TRUNC_SAT_F64_S:
            exec_env.op_trunc_sat!(long, double);
            continue;
        case I64_TRUNC_SAT_F64_U:
            exec_env.op_trunc_sat!(ulong, double);
            continue;
      case ERROR:

// #if WASM_ENABLE_LABELS_AS_VALUES == 0
//       default:
//         wasm_set_exception(wasm_module, "WASM interp failed: unsupported opcode.");
//         goto case ERROR;
//     }
// #endif
//   call_func_from_interp:
//     /* Only do the copy when it's called from interpreter.  */
//     {
//       WASMInterpFrame *outs_area = wasm_exec_env_wasm_stack_top(exec_env);
//       POP(cur_func.param_cell_num);
//       SYNC_ALL_TO_FRAME();
//       word_copy(outs_area.lp, frame_sp, cur_func.param_cell_num);
//       prev_frame = frame;
//     }

//   call_func_from_entry:
//     {
//       if (cur_func.is_import_func) {
// #if WASM_ENABLE_MULTI_MODULE != 0
//           if (cur_func.import_func_inst) {
//               wasm_interp_call_func_import(wasm_module, exec_env, cur_func,
//                                            prev_frame);
//           }
//           else
// #endif
//           {
//               wasm_interp_call_func_native(wasm_module, exec_env, cur_func,
//                                            prev_frame);
//           }

//           prev_frame = frame.prev_frame;
//           cur_func = frame.function;
//           UPDATE_ALL_FROM_FRAME();

//           memory = wasm_module.default_memory;
//           if (wasm_get_exception(wasm_module))
//               goto case ERROR;
//       }
//       else {
//         WASMFunction *cur_wasm_func = cur_func.u.func;
//         WASMType *func_type;

//         func_type = cur_wasm_func.func_type;

//         all_cell_num = (uint64)cur_func.param_cell_num
//                        + (uint64)cur_func.local_cell_num
//                        + (uint64)cur_wasm_func.max_stack_cell_num
//                        + ((uint64)cur_wasm_func.max_block_num) * sizeof(WASMBranchBlock) / 4;
//         if (all_cell_num >= UINT_MAX) {
//             wasm_set_exception(wasm_module, "WASM interp failed: stack overflow.");
//             goto case ERROR;
//         }

//         frame_size = wasm_interp_interp_frame_size((uint)all_cell_num);
//         if (!(frame = ALLOC_FRAME(exec_env, frame_size, prev_frame))) {
//           frame = prev_frame;
//           goto case ERROR;
//         }

//         /* Initialize the interpreter context. */
//         frame.function = cur_func;
//         frame_ip = wasm_get_func_code(cur_func);
//         frame_ip_end = wasm_get_func_code_end(cur_func);
//         frame_lp = frame.lp;

//         frame_sp = frame.sp_bottom = frame_lp + cur_func.param_cell_num
//                                                + cur_func.local_cell_num;
//         frame.sp_boundary = frame.sp_bottom + cur_wasm_func.max_stack_cell_num;

//         frame_csp = frame.csp_bottom = (WASMBranchBlock*)frame.sp_boundary;
//         frame.csp_boundary = frame.csp_bottom + cur_wasm_func.max_block_num;

//         /* Initialize the local varialbes */
//         memset(frame_lp + cur_func.param_cell_num, 0,
//                (uint)(cur_func.local_cell_num * 4));

//         /* Push function block as first block */
//         cell_num = func_type.ret_cell_num;
//         PUSH_CSP(LABEL_TYPE_FUNCTION, cell_num, frame_ip_end - 1);

//         wasm_exec_env_set_cur_frame(exec_env, (WASMRuntimeFrame*)frame);
//       }
//       HANDLE_OP_END ();
//     }

//   return_func:
//     {
//       FREE_FRAME(exec_env, frame);
//       wasm_exec_env_set_cur_frame(exec_env, (WASMRuntimeFrame*)prev_frame);

//       if (!prev_frame.ip)
//         /* Called from native. */
//         return;

//       mixin(RECOVER_CONTEXT!(prev_frame));
//       HANDLE_OP_END ();
//     }

//   out_of_bounds:
//     wasm_set_exception(wasm_module, "out of bounds memory access");

//         got_exception:
//     return;

// #if WASM_ENABLE_LABELS_AS_VALUES == 0
//   }
// #else
//   FETCH_OPCODE_AND_DISPATCH ();
// #endif
        }
    }
        }
    }
}

version(none)
void
wasm_interp_call_wasm(WASMModuleInstance *module_inst,
                      WASMExecEnv *exec_env,
                      WASMFunctionInstance *func,
                      uint argc, uint[] argv)
{
    // TODO: since module_inst = exec_env.module_inst, shall we remove the 1st arg?
    WASMRuntimeFrame *prev_frame = wasm_exec_env_get_cur_frame(exec_env);
    WASMInterpFrame *frame, outs_area;

    /* Allocate sufficient cells for all kinds of return values.  */
    unsigned all_cell_num = func.ret_cell_num > 2 ?
                            func.ret_cell_num : 2, i;
    /* This frame won't be used by JITed code, so only allocate interp
       frame here.  */
    unsigned frame_size = wasm_interp_interp_frame_size(all_cell_num);

    if (argc != func.param_cell_num) {
        char[128] buf;
        snprintf(buf, buf.length,
                 "invalid argument count %d, expected %d",
                 argc, func.param_cell_num);
        wasm_set_exception(module_inst, buf);
        return;
    }

    if (cast(ubyte*)&prev_frame < exec_env.native_stack_boundary) {
        wasm_set_exception(cast(WASMModuleInstance*)exec_env.module_inst,
                           "WASM interp failed: native stack overflow.");
        return;
    }

    if (!(frame = ALLOC_FRAME(exec_env, frame_size, cast(WASMInterpFrame*)prev_frame)))
        return;

    outs_area = wasm_exec_env_wasm_stack_top(exec_env);
    frame.func = null;
    frame.ip = null;
    /* There is no local variable. */
    frame.sp = frame.lp + 0;

    if (argc > 0)
        word_copy(outs_area.lp, argv, argc);

    wasm_exec_env_set_cur_frame(exec_env, frame);

    if (func.is_import_func) {
        if (WASM_ENABLE_MULTI_MODULE && func.import_module_inst) {
            LOG_DEBUG("it is a function of a sub module");
            wasm_interp_call_func_import(module_inst,
                                         exec_env,
                                         func,
                                         frame);
        }
        else
        {
            LOG_DEBUG("it is an native function");
            /* it is a native function */
            wasm_interp_call_func_native(module_inst,
                                         exec_env,
                                         func,
                                         frame);
        }
    }
    else {
        LOG_DEBUG("it is a function of the module itself");
        wasm_interp_call_func_bytecode(module_inst, exec_env, func, frame);
    }

    /* Output the return value to the caller */
    if (!wasm_get_exception(module_inst)) {
        for (i = 0; i < func.ret_cell_num; i++) {
            argv[i] = *(frame.sp + i - func.ret_cell_num);
        }

        if (func.ret_cell_num) {
            LOG_DEBUG("first return value argv[0]=%d", argv[0]);
        } else {
            LOG_DEBUG("no return value");
        }
    } else {
        LOG_DEBUG("meet an exception %s", wasm_get_exception(module_inst));
    }

    wasm_exec_env_set_cur_frame(exec_env, prev_frame);
    FREE_FRAME(exec_env, frame);
}
