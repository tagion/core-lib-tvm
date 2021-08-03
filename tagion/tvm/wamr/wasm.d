/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.wasm;

import tagion.tvm.wamr.bh_platform;
import tagion.tvm.wamr.bh_hashmap;
import tagion.tvm.wamr.bh_assert;
import tagion.tvm.wamr.bh_list;

// #ifndef _WASM_H_
// #define _WASM_H_

// #include "bh_platform.h"
// #include "bh_hashmap.h"
// #include "bh_assert.h"

// #ifdef __cplusplus
// extern "C" {
// #endif

/** Value Type */
enum VALUE_TYPE_I32 = 0x7F;
enum VALUE_TYPE_I64 = 0X7E;
enum VALUE_TYPE_F32 = 0x7D;
enum VALUE_TYPE_F64 = 0x7C;
enum VALUE_TYPE_VOID = 0x40;
/* Used by AOT */
enum VALUE_TYPE_I1  = 0x41;
/*  Used by loader to represent any type of i32/i64/f32/f64 */
enum VALUE_TYPE_ANY = 0x42;

/* Table Element Type */
enum TABLE_ELEM_TYPE_ANY_FUNC = 0x70;

enum DEFAULT_NUM_BYTES_PER_PAGE = 65536;

enum INIT_EXPR_TYPE_I32_CONST = 0x41;
enum INIT_EXPR_TYPE_I64_CONST = 0x42;
enum INIT_EXPR_TYPE_F32_CONST = 0x43;
enum INIT_EXPR_TYPE_F64_CONST = 0x44;
enum INIT_EXPR_TYPE_GET_GLOBAL = 0x23;
enum INIT_EXPR_TYPE_ERROR = 0xff;

enum WASM_MAGIC_NUMBER = 0x6d736100;
enum WASM_CURRENT_VERSION = 1;

enum SECTION_TYPE_USER = 0;
enum SECTION_TYPE_TYPE = 1;
enum SECTION_TYPE_IMPORT = 2;
enum SECTION_TYPE_FUNC = 3;
enum SECTION_TYPE_TABLE = 4;
enum SECTION_TYPE_MEMORY = 5;
enum SECTION_TYPE_GLOBAL = 6;
enum SECTION_TYPE_EXPORT = 7;
enum SECTION_TYPE_START = 8;
    enum SECTION_TYPE_ELEM = 9;
enum SECTION_TYPE_CODE = 10;
enum SECTION_TYPE_DATA = 11;
version(WASM_ENABLE_BULK_MEMORY) {
    enum SECTION_TYPE_DATACOUNT = 12;
}

enum IMPORT_KIND_FUNC = 0;
enum IMPORT_KIND_TABLE = 1;
enum IMPORT_KIND_MEMORY = 2;
enum IMPORT_KIND_GLOBAL = 3;

enum EXPORT_KIND_FUNC = 0;
enum EXPORT_KIND_TABLE = 1;
enum EXPORT_KIND_MEMORY = 2;
enum EXPORT_KIND_GLOBAL = 3;

enum LABEL_TYPE_BLOCK = 0;
enum LABEL_TYPE_LOOP = 1;
enum LABEL_TYPE_IF = 2;
enum LABEL_TYPE_FUNCTION = 3;

// typedef struct WASMModule WASMModule;
// typedef struct WASMFunction WASMFunction;
// typedef struct WASMGlobal WASMGlobal;

alias uintptr_t = ulong;

union WASMValue {
    int i32;
    uint u32;
    long i64;
    ulong u64;
    float f32;
    double f64;
    uintptr_t addr;
}

struct InitializerExpression {
    /* type of INIT_EXPR_TYPE_XXX */
    ubyte init_expr_type;
    union U {
        int i32;
        long i64;
        float f32;
        double f64;
        uint global_index;
    };
    U u;
}

struct WASMType {
    ushort param_count;
    ushort result_count;
    ushort param_cell_num;
    ushort ret_cell_num;
    /* types of params and results */
    ubyte[1] types;
}

struct WASMTable {
    ubyte elem_type;
    uint flags;
    uint init_size;
    /* specified if (flags & 1), else it is 0x10000 */
    uint max_size;
}

struct WASMMemory {
    uint flags;
    uint num_bytes_per_page;
    uint init_page_count;
    uint max_page_count;
}

struct WASMTableImport {
    char* module_name;
    char* field_name;
    ubyte elem_type;
    uint flags;
    uint init_size;
    /* specified if (flags & 1), else it is 0x10000 */
    uint max_size;
    version(WASM_ENABLE_MULTI_MODULE) {
        WASMModule *import_module;
        WASMTable *import_table_linked;
    }
}

struct WASMMemoryImport {
    char* module_name;
    char* field_name;
    uint flags;
    uint num_bytes_per_page;
    uint init_page_count;
    uint max_page_count;
    version(WASM_ENABLE_MULTI_MODULE) {
    WASMModule *import_module;
    WASMMemory *import_memory_linked;
    }
}

struct WASMFunctionImport {
    char *module_name;
    char *field_name;
    /* function type */
    WASMType *func_type;
    /* native function pointer after linked */
    void *func_ptr_linked;
    /* signature from registered native symbols */
    const char *signature;
    /* attachment */
    void *attachment;
    bool call_conv_raw;
    version(WASM_ENABLE_MULTI_MODULE) {
        WASMModule *import_module;
        WASMFunction *import_func_linked;
    }
}

struct WASMGlobalImport {
    char *module_name;
    char *field_name;
    ubyte type;
    bool is_mutable;
    /* global data after linked */
    WASMValue global_data_linked;
    version(WASM_ENABLE_MULTI_MODULE) {
    /* imported function pointer after linked */
    // TODO: remove if not necessary
    WASMModule* import_module;
    WASMGlobal *import_global_linked;
    }
}

struct WASMImport {
    ubyte kind;
    union U {
        WASMFunctionImport func;
        WASMTableImport table;
        WASMMemoryImport memory;
        WASMGlobalImport global;
        struct Names {
            char *module_name;
            char *field_name;
        }
        Names names;
    }
    U u;
}

struct WASMFunction {
    /* the type of function */
    WASMType* func_type;
    uint local_count;
    ubyte* local_types;

    /* cell num of parameters */
    ushort param_cell_num;
    /* cell num of return type */
    ushort ret_cell_num;
    /* cell num of local variables */
    ushort local_cell_num;
    /* offset of each local, including function parameters
       and local variables */
    ushort* local_offsets;

    uint max_stack_cell_num;
    uint max_block_num;
    /* Whether function has opcode memory.grow */
    bool has_op_memory_grow;
    /* Whether function has opcode call or
       call_indirect */
    bool has_op_func_call;
    uint code_size;
    ubyte* code;
    version(WASM_ENABLE_FAST_INTERP) {
        uint code_compiled_size;
        ubyte* code_compiled;
        ubyte* consts;
        uint const_cell_num;
    }
}

struct WASMGlobal {
    ubyte type;
    bool is_mutable;
    InitializerExpression init_expr;
}

struct WASMExport {
    char* name;
    ubyte kind;
    uint index;
}

struct WASMTableSeg {
    uint table_index;
    InitializerExpression base_offset;
    uint function_count;
    uint* func_indexes;
}

struct WASMDataSeg {
    uint memory_index;
    InitializerExpression base_offset;
    uint data_length;
    version(WASM_ENABLE_BULK_MEMORY) {
        bool is_passive;
    }
    ubyte* data;
}

struct BlockAddr {
    const ubyte* start_addr;
    ubyte* else_addr;
    ubyte* end_addr;
}

version(WASM_ENABLE_LIBC_WASI) {
    struct WASIArguments {
    const char* *dir_list;
    uint dir_count;
    const char* *map_dir_list;
    uint map_dir_count;
    const char* *env;
    uint env_count;
    char* *argv;
    uint argc;
}
}

struct StringNode {
    StringNode* next;
    char* str;
}
//StringNode,* StringList;
alias StringList = StringNode*;

struct WASMModule {
    /* Module type, for module loaded from WASM bytecode binary,
       this field is Wasm_Module_Bytecode;
       for module loaded from AOT file, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModule structure. */
    uint module_type;

    uint type_count;
    uint import_count;
    uint function_count;
    uint table_count;
    uint memory_count;
    uint global_count;
    uint export_count;
    uint table_seg_count;
    /* data seg count read from data segment section */
    uint data_seg_count;
    version(WASM_ENABLE_BULK_MEMORY) {
    /* data count read from datacount section */
    uint data_seg_count1;
    }

    uint import_function_count;
    uint import_table_count;
    uint import_memory_count;
    uint import_global_count;

    WASMImport* import_functions;
    WASMImport* import_tables;
    WASMImport* import_memories;
    WASMImport* import_globals;

    WASMType* *types;
    WASMImport* imports;
    WASMFunction* *functions;
    WASMTable* tables;
    WASMMemory* memories;
    WASMGlobal* globals;
    WASMExport* exports;
    WASMTableSeg* table_segments;
    WASMDataSeg* *data_segments;
    uint start_function;

    /* __data_end global exported by llvm */
    uint llvm_aux_data_end;
    /* auxiliary stack bottom, or __heap_base global exported by llvm */
    uint llvm_aux_stack_bottom;
    /* auxiliary stack size */
    uint llvm_aux_stack_size;
    /* the index of a global exported by llvm, which is
       auxiliary stack top pointer */
    uint llvm_aux_stack_global_index;

    /* Whether there is possible memory grow, e.g. memory.grow opcode */
    bool possible_memory_grow;

    StringList const_str_list;

    version(WASM_ENABLE_LIBC_WASI) {
    WASIArguments wasi_args;
    bool is_wasi_module;
    }

    version(WASM_ENABLE_MULTI_MODULE) {
    // TODO: mutex ? mutli-threads ?
    bh_list import_module_list_head;
    bh_list* import_module_list;
    }
}

struct BlockType {
    /* Block type may be expressed in one of two forms:
     * either by the type of the single return value or
     * by a type index of module.
     */
    union U {
        ubyte value_type;
        WASMType* type;
    }
    U u;
    bool is_value_type;
}

struct WASMBranchBlock {
    ubyte label_type;
    uint cell_num;
    ubyte* target_addr;
    uint* frame_sp;
}

/* Execution environment, e.g. stack info */
/**
 * Align an uint value on a alignment boundary.
 *
 * @param v the value to be aligned
 * @param b the alignment boundary (2, 4, 8, ...)
 *
 * @return the aligned value
 */
protected uint
align_uint (uint v, uint b)
{
    uint m = b - 1;
    return (v + m) & ~m;
}

/**
 * Return the hash value of c string.
 */
protected uint
wasm_string_hash(const char* str)
{
    uint h = cast(uint)strlen(str);
    const ubyte* p = cast(ubyte*)str;
    const ubyte* end = p + h;

    while (p != end) {
        h = ((h << 5) - h) + *p++;
    }
    return h;
}

/**
 * Whether two c strings are equal.
 */
protected bool
wasm_string_equal(const char* s1, const char* s2)
{
    return strcmp(s1, s2) == 0 ? true : false;
}

/**
 * Return the byte size of value type.
 *
 */
protected uint
wasm_value_type_size(ubyte value_type)
{
    switch (value_type) {
        case VALUE_TYPE_I32:
            goto case;
        case VALUE_TYPE_F32:
            return int.sizeof;
        case VALUE_TYPE_I64:
            goto case;
        case VALUE_TYPE_F64:
            return long.sizeof;
        default:
            bh_assert(0);
    }
    return 0;
}

protected ushort
wasm_value_type_cell_num(ubyte value_type)
{
    if (value_type == VALUE_TYPE_VOID) {
        return 0;
    }
    else if (value_type == VALUE_TYPE_I32
        || value_type == VALUE_TYPE_F32) {
        return 1;
    }
    else if (value_type == VALUE_TYPE_I64
        || value_type == VALUE_TYPE_F64) {
        return 2;
    }
    else {
        bh_assert(0);
    }
    return 0;
}

protected uint
wasm_get_cell_num(const ubyte* types, uint type_count)
{
    uint cell_num = 0;
    uint i;
    for (i = 0; i < type_count; i++) {
        cell_num += wasm_value_type_cell_num(types[i]);
    }
    return cell_num;
}

protected bool
wasm_type_equal(const WASMType* type1, const WASMType* type2)
{
    return (type1.param_count == type2.param_count
            && type1.result_count == type2.result_count
            && memcmp(type1.types, type2.types,
                      type1.param_count + type1.result_count) == 0)
        ? true : false;
}

protected uint
block_type_get_param_types(BlockType* block_type,
                           ubyte** p_param_types)
{
    uint param_count = 0;
    if (!block_type.is_value_type) {
        WASMType* wasm_type = block_type.u.type;
        *p_param_types = wasm_type.types;
        param_count = wasm_type.param_count;
    }
    else {
        *p_param_types = NULL;
        param_count  = 0;
    }

    return param_count;
}

protected uint
block_type_get_result_types(BlockType* block_type,
                            ubyte* *p_result_types)
{
    uint result_count = 0;
    if (block_type.is_value_type) {
        if (block_type.u.value_type != VALUE_TYPE_VOID) {
            *p_result_types = &block_type.u.value_type;
            result_count = 1;
        }
    }
    else {
        WASMType* wasm_type = block_type.u.type;
        *p_result_types = wasm_type.types + wasm_type.param_count;
        result_count = wasm_type.result_count;
    }
    return result_count;
}
