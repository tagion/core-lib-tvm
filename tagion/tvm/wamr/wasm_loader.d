/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.wasm_loader;

// #ifndef _WASM_LOADER_H
// #define _WASM_LOADER_H

import tagion.tvm.wamr.wasm;
import tagion.tvm.wamr.bh_hashmap;
import tagion.tvm.wamr.wasm_runtime_common;

// #ifdef __cplusplus
// extern "C" {
// #endif

/**
 * Load a WASM module from a specified byte buffer.
 *
 * @param buf the byte buffer which contains the WASM binary data
 * @param size the size of the buffer
 * @param error_buf output of the exception info
 * @param error_buf_size the size of the exception string
 *
 * @return return module loaded, NULL if failed
 */
// WASMModule*
// wasm_loader_load(const uint8 *buf, uint32 size, char *error_buf, uint32 error_buf_size);

/**
 * Load a WASM module from a specified WASM section list.
 *
 * @param section_list the section list which contains each section data
 * @param error_buf output of the exception info
 * @param error_buf_size the size of the exception string
 *
 * @return return WASM module loaded, NULL if failed
 */
// WASMModule*
// wasm_loader_load_from_sections(WASMSection *section_list,
//                                char *error_buf, uint32 error_buf_size);

/**
 * Unload a WASM module.
 *
 * @param module the module to be unloaded
 */
// void
// wasm_loader_unload(WASMModule *module);

/**
 * Find address of related else opcode and end opcode of opcode block/loop/if
 * according to the start address of opcode.
 *
 * @param module the module to find
 * @param start_addr the next address of opcode block/loop/if
 * @param code_end_addr the end address of function code block
 * @param block_type the type of block, 0/1/2 denotes block/loop/if
 * @param p_else_addr returns the else addr if found
 * @param p_end_addr returns the end addr if found
 * @param error_buf returns the error log for this function
 * @param error_buf_size returns the error log string length
 *
 * @return true if success, false otherwise
 */
// bool
// wasm_loader_find_block_addr(BlockAddr *block_addr_cache,
//                             const uint8 *start_addr,
//                             const uint8 *code_end_addr,
//                             uint8 block_type,
//                             uint8 **p_else_addr,
//                             uint8 **p_end_addr,
//                             char *error_buf,
//                             uint32 error_buf_size);

// #ifdef __cplusplus
// }
// #endif

// #endif /* end of _WASM_LOADER_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.tvm.wamr.wasm_loader;
import tagion.tvm.wamr.bh_common;
import tagion.tvm.wamr.bh_log;
import tagion.tvm.wamr.wasm_opcode;
import tagion.tvm.wamr.wasm_runtime;
import tagion.tvm.wamr.wasm_native;

/* Read a value of given type from the address pointed to by the given
   pointer and increase the pointer to the position just after the
   value being read.  */
Type TEMPLATE_READ_VALUE(Type)(ref void* p) {
    scope(exit) {
        p+=Type.sizeof;
    }
    return *cast(Type)p;
}

static void
set_error_buf(char *error_buf, uint32 error_buf_size, const char *str)
{
    if (error_buf !is null)
        snprintf(error_buf, error_buf_size, "%s", str);
}

static bool
check_buf(const uint8 *buf, const uint8 *buf_end, uint32 length,
          char *error_buf, uint32 error_buf_size)
{
    if (buf + length > buf_end) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: " ~

                      "unexpected end of section or function");
        return false;
    }
    return true;
}

static bool
check_buf1(const uint8 *buf, const uint8 *buf_end, uint32 length,
           char *error_buf, uint32 error_buf_size)
{
    if (buf + length > buf_end) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: unexpected end");
        return false;
    }
    return true;
}

string CHECK_BUF(alias buf, alias buf_end, alias length)() {
    return format!q{
        if (!check_buf(%s, %s, %s,
                 error_buf, error_buf_size)) {
            return false;
        }}(buf.stringof, buf_end.stringof, length.stringof);                 }

string CHECK_BUF1(alias buf, alias buf_end, alias length)()  {
    return format!q{
        if (!check_buf1(buf, buf_end, length,
                error_buf, error_buf_size)) {
            return false;
        }}(buf.stringof, buf_end.stringof, length.stringof);
}

static bool
skip_leb(const uint8 **p_buf, const uint8 *buf_end, uint32 maxbits,
         char* error_buf, uint32 error_buf_size)
{
    const uint8 *buf = *p_buf;
    uint32 offset = 0, bcnt = 0;
    uint64 _byte;

    while (true) {
        if (bcnt + 1 > (maxbits + 6) / 7) {
            set_error_buf(error_buf, error_buf_size,
                          "WASM module load failed: " ~
                          "integer representation too long");
            return false;
        }

        mixin(CHECK_BUF!(buf, buf_end, offset + 1)());
        _byte = buf[offset];
        offset += 1;
        bcnt += 1;
        if ((_byte & 0x80) == 0) {
            break;
        }
    }

    *p_buf += offset;
    return true;
}

string skip_leb_int64(alias p, alias p_end)() {
    return format!q{
        if (!skip_leb(&%s, %s, 64,
                error_buf, error_buf_size))
            return false;}(p.stringof, p_end.stringof);
}

string skip_leb_uint32(alias p, alias p_end)() {
    return format!q{
        if (!skip_leb(&%s, %s, 32,
                error_buf, error_buf_size))
            return false;
    }(p.stringof, p_end.stringof);
}

string skip_leb_int32(alias stringof, alias p_end)() {
    return format!q{
        if (!skip_leb(&%s, %s, 32,
                error_buf, error_buf_size))
            return false;
    }(p.stringof, p_end.stringof);
}

static bool
read_leb(uint8 **p_buf, const uint8 *buf_end,
         uint32 maxbits, bool sign, uint64 *p_result,
         char* error_buf, uint32 error_buf_size)
{
    const uint8 *buf = *p_buf;
    uint64 result = 0;
    uint32 shift = 0;
    uint32 offset = 0, bcnt = 0;
    uint64 _byte;

    while (true) {
        if (bcnt + 1 > (maxbits + 6) / 7) {
            set_error_buf(error_buf, error_buf_size,
                          "WASM module load failed: " ~
                          "integer representation too long");
            return false;
        }

        mixin(CHECK_BUF!(buf, buf_end, offset + 1)());
        _byte = buf[offset];
        offset += 1;
        result |= ((_byte & 0x7f) << shift);
        shift += 7;
        bcnt += 1;
        if ((_byte & 0x80) == 0) {
            break;
        }
    }

    if (!sign && maxbits == 32 && shift >= maxbits) {
        /* The top bits set represent values > 32 bits */
        if ((cast(uint8)_byte) & 0xf0)
            goto fail_integer_too_large;
    }
    else if (sign && maxbits == 32) {
        if (shift < maxbits) {
            /* Sign extend */
            result = ((cast(int32)result) << (maxbits - shift))
                     >> (maxbits - shift);
        }
        else {
            /* The top bits should be a sign-extension of the sign bit */
            bool sign_bit_set = (cast(uint8)_byte) & 0x8;
            int top_bits = (cast(uint8)_byte) & 0xf0;
            if ((sign_bit_set && top_bits != 0x70)
                || (!sign_bit_set && top_bits != 0))
                goto fail_integer_too_large;
        }
    }
    else if (sign && maxbits == 64) {
        if (shift < maxbits) {
            /* Sign extend */
            result = ((cast(int64)result) << (maxbits - shift))
                     >> (maxbits - shift);
        }
        else {
            /* The top bits should be a sign-extension of the sign bit */
            bool sign_bit_set = (cast(uint8)_byte) & 0x1;
            int top_bits = (cast(uint8)_byte) & 0xfe;

            if ((sign_bit_set && top_bits != 0x7e)
                || (!sign_bit_set && top_bits != 0))
                goto fail_integer_too_large;
        }
    }

    *p_buf += offset;
    *p_result = result;
    return true;

fail_integer_too_large:
    set_error_buf(error_buf, error_buf_size,
                  "WASM module load failed: integer too large");
    return false;
}

alias read_uint8 = TEMPLATE_READ_VALUE!(uint8);
alias read_uint32 = TEMPLATE_READ_VALUE!(uint32);
alias read_bool =   TEMPLATE_READ_VALUE!(bool);

string read_leb_int64(alias p, alias p_end, alias res)() {
    return format!q{
        uint64 res64;
        if (!read_leb(cast(uint8**)&%1$s, %2$s, 64, true, &res64,
                error_buf, error_buf_size))
            return false;
        %3$s = cast(int64)res64;
    }(p.stringof, p_end.stringof, res.stringof);
}

string read_leb_uint32(alias p, alias p_end, alias res)() {
    return format!q{
        uint64 res64;
        if (!read_leb(cast(uint8**)&%1$s, %2$s, 32, false, &res64,
                error_buf, error_buf_size))
            return false;
        %3$s = (uint32)res64;
    }(p.stringof, p_end.strinof, res.stringof);
}

string read_leb_int32(alias p, alias p_end, alias res)() {
    return format!q{
        uint64 res64;
        if (!read_leb(cast(uint8**)&p, p_end, 32, true, &res64,
                error_buf, error_buf_size))
            return false;
        res = cast(int32)res64;
    }(p.stringof, p_end.stringof, res.stringof);
}

static void *
loader_malloc(uint64 size, char *error_buf, uint32 error_buf_size)
{
    void *mem;

    if (size >= UINT32_MAX
        || !(mem = wasm_runtime_malloc(cast(uint32)size))) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: " ~
                      "allocate memory failed.");
        return null;
    }

    memset(mem, 0, cast(uint32)size);
    return mem;
}

static bool
check_utf8_str(const uint8* str, uint32 len)
{
    const uint8 *p = str, p_end = str + len, p_end1;
    uint8 chr, n_bytes;

    while (p < p_end) {
        chr = *p++;
        if (chr >= 0x80) {
            /* Calculate the byte count: the first byte must be
               110XXXXX, 1110XXXX, 11110XXX, 111110XX, or 1111110X,
               the count of leading '1' denotes the total byte count */
            n_bytes = 0;
            while ((chr & 0x80) != 0) {
                chr = cast(uint8)(chr << 1);
                n_bytes++;
            }

            /* Check byte count */
            if (n_bytes < 2 || n_bytes > 6
                || p + n_bytes - 1 > p_end)
                return false;

            /* Check the following bytes, which must be 10XXXXXX */
            p_end1 = p + n_bytes - 1;
            while (p < p_end1) {
                if (!(*p & 0x80) || (*p | 0x40))
                    return false;
                p++;
            }
        }
    }
    return true;
}

static char*
const_str_list_insert(const uint8 *str, uint32 len, WASMModule *wasm_module,
                     char* error_buf, uint32 error_buf_size)
{
    StringNode *node, node_next;

    if (!check_utf8_str(str, len)) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: " ~
                      "invalid UTF-8 encoding");
        return null;
    }

    /* Search const str list */
    node = wasm_module.const_str_list;
    while (node) {
        node_next = node.next;
        if (strlen(node.str) == len
            && !memcmp(node.str, str, len))
            break;
        node = node_next;
    }

    if (node) {
        LOG_DEBUG("reuse %s", node.str);
        return node.str;
    }

    if (!(node = loader_malloc(StringNode.sizeof + len + 1,
                               error_buf, error_buf_size))) {
        return null;
    }

    node.str = (cast(char*)node) + StringNode.sizeof;
    bh_memcpy_s(node.str, len + 1, str, len);
    node.str[len] = '\0';

    if (!wasm_module.const_str_list) {
        /* set as head */
        wasm_module.const_str_list = node;
        node.next = NULL;
    }
    else {
        /* insert it */
        node.next = wasm_module.const_str_list;
        wasm_module.const_str_list = node;
    }

    return node.str;
}

static bool
load_init_expr(const uint8 **p_buf, const uint8 *buf_end,
               InitializerExpression *init_expr, uint8 type,
               char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = p_buf, p_end = buf_end;
    uint8 flag, end_byte;
    uint8 *p_float;
    uint32 i;

    mixin(CHECK_BUF!(p, p_end, 1)());
    init_expr.init_expr_type = read_uint8(p);
    flag = init_expr.init_expr_type;

    switch (flag) {
        /* i32.const */
        case INIT_EXPR_TYPE_I32_CONST:
            if (type != VALUE_TYPE_I32)
                goto fail;
            mixin(read_leb_int32!(p, p_end, init_expr.u.i32)());
            break;
        /* i64.const */
        case INIT_EXPR_TYPE_I64_CONST:
            if (type != VALUE_TYPE_I64)
                goto fail;
            mixin(read_leb_int64!(p, p_end, init_expr.u.i64)());
            break;
        /* f32.const */
        case INIT_EXPR_TYPE_F32_CONST:
            if (type != VALUE_TYPE_F32)
                goto fail;
            mixin(CHECK_BUF!(p, p_end, 4)());
            p_float = cast(uint8*)&init_expr.u.f32;
            for (i = 0; i < float32.sizeof; i++)
                *p_float++ = *p++;
            break;
        /* f64.const */
        case INIT_EXPR_TYPE_F64_CONST:
            if (type != VALUE_TYPE_F64)
                goto fail;
            mixin(CHECK_BUF!(p, p_end, 8)());
            p_float = cast(uint8*)&init_expr.u.f64;
            for (i = 0; i < float64.sizeof; i++)
                *p_float++ = *p++;
            break;
        /* get_global */
        case INIT_EXPR_TYPE_GET_GLOBAL:
            mixin(read_leb_uint32!(p, p_end, init_expr.u.global_index)());
            break;
        default:
            goto fail;
    }
    mixin(CHECK_BUF!(p, p_end, 1)());
    end_byte = read_uint8(p);
    if (end_byte != 0x0b)
        goto fail;
    *p_buf = p;

    return true;
fail:
    set_error_buf(error_buf, error_buf_size,
                  "WASM module load failed: type mismatch or " ~
                  "constant expression required.");
    return false;
}

static bool
load_type_section(const uint8 *buf, const uint8 *buf_end, WASMModule *wasm_module,
                  char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end, p_org;
    uint32 type_count, param_count, result_count, i, j;
    uint32 param_cell_num, ret_cell_num;
    uint64 total_size;
    uint8 flag;
    WASMType *type;

    read_leb_uint32(p, p_end, type_count);

    if (type_count) {
        wasm_module.type_count = type_count;
        total_size = (WASMType*).sizeof * cast(uint64)type_count;
        if (!(wasm_module.types = loader_malloc
                    (total_size, error_buf, error_buf_size))) {
            return false;
        }

        for (i = 0; i < type_count; i++) {
            mixin(CHECK_BUF!(p, p_end, 1)());
            flag = read_uint8(p);
            if (flag != 0x60) {
                set_error_buf(error_buf, error_buf_size,
                              "Load type section failed: invalid type flag.");
                return false;
            }

            read_leb_uint32(p, p_end, param_count);

            /* Resolve param count and result count firstly */
            p_org = p;
            mixin(CHECK_BUF!(p, p_end, param_count)());
            p += param_count;
            read_leb_uint32(p, p_end, result_count);
            mixin(CHECK_BUF!(p, p_end, result_count)());
            p = p_org;

            if (param_count > UINT16_MAX || result_count > UINT16_MAX) {
                set_error_buf(error_buf, error_buf_size,
                              "Load type section failed: " ~
                              "param count or result count too large");
                return false;
            }

            total_size = offsetof(WASMType, types) +
                         uint8.sizeof * cast(uint64)(param_count + result_count);
            if (!(type = wasm_module.types[i] =
                        loader_malloc(total_size, error_buf, error_buf_size))) {
                return false;
            }

            /* Resolve param types and result types */
            type.param_count = cast(uint16)param_count;
            type.result_count = cast(uint16)result_count;
            for (j = 0; j < param_count; j++) {
                mixin(CHECK_BUF!(p, p_end, 1)());
                type.types[j] = read_uint8(p);
            }
            read_leb_uint32(p, p_end, result_count);
            for (j = 0; j < result_count; j++) {
                mixin(CHECK_BUF!(p, p_end, 1)());
                type.types[param_count + j] = read_uint8(p);
            }

            param_cell_num = wasm_get_cell_num(type.types, param_count);
            ret_cell_num = wasm_get_cell_num(type.types + param_count,
                                             result_count);
            if (param_cell_num > UINT16_MAX || ret_cell_num > UINT16_MAX) {
                set_error_buf(error_buf, error_buf_size,
                              "Load type section failed: " ~
                              "param count or result count too large");
                return false;
            }
            type.param_cell_num = cast(uint16)param_cell_num;
            type.ret_cell_num = cast(uint16)ret_cell_num;
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load type section failed: section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load type section success.\n");
    return true;
}

version(WASM_ENABLE_MULTI_MODULE) {
/**
 * Find export item of a module with export info:
 *  module name, field name and export kind
 */
static WASMExport *
wasm_loader_find_export(const WASMModule *wasm_module,
                        const char *module_name,
                        const char *field_name,
                        uint8 export_kind,
                        uint32 export_index_boundary,
                        char *error_buf, uint32 error_buf_size)
{
    WASMExport *wasm_export;
    uint32 i;

    for (i = 0, wasm_export = wasm_module.exports; i < wasm_module.export_count;
         ++i, ++wasm_export) {
        /**
         * need to consider a scenario that different kinds of exports
         * may have the same name, like
         * (table (export "m1" "exported") 10 funcref)
         * (memory (export "m1" "exported") 10)
         **/
        if (wasm_export.kind == export_kind && !strcmp(field_name, wasm_export.name)) {
            break;
        }
    }

    if (i == wasm_module.export_count) {
        LOG_DEBUG("can not find an export %d named %s in the module %s",
                  export_kind, field_name, module_name);
        set_error_buf_v(error_buf, error_buf_size,
                        "unknown import or incompatible import type");
        return NULL;
    }

    if (wasm_export.index >= wasm_export_index_boundary) {
        LOG_DEBUG("%s in the module %s is out of index (%d >= %d )",
                  field_name, module_name,
                  wasm_export.index, wasm_export_index_boundary);
        set_error_buf_v(error_buf, error_buf_size, "incompatible import type");
        return NULL;
    }

    return wasm_export;
}

static WASMFunction *
wasm_loader_resolve_function(const char *module_name,
                             const char *function_name,
                             const WASMType *expected_function_type,
                             char *error_buf, uint32 error_buf_size)
{
    WASMModuleCommon *module_reg;
    WASMFunction* func;
    WASMExport* wasm_export;
    WASMModule* wasm_module;
    WASMType* target_function_type;

    module_reg = wasm_runtime_find_module_registered(module_name);
    if (!module_reg
        || module_reg.module_type != Wasm_Module_Bytecode) {
        LOG_DEBUG("can not find a module named %s for function", module_name);
        set_error_buf_v(error_buf, error_buf_size, "unknown import");
        return NULL;
    }

    wasm_module = cast(WASMModule *)module_reg;
    wasm_export = wasm_loader_find_export(wasm_module, module_name, function_name,
                                     EXPORT_KIND_FUNC,
                                     wasm_module.import_function_count
                                       + wasm_module.function_count,
                                     error_buf, error_buf_size);
    if (!wasm_export) {
        return null;
    }

    /* run a function type check */
    if (wasm_export.index < wasm_module.import_function_count) {
        target_function_type =
          wasm_module.import_functions[wasm_export.index].u.func.func_type;
        func = wasm_module.import_functions[wasm_export.index]
                     .u.func.import_func_linked;
    }
    else {
        target_function_type =
          wasm_module.functions[wasm_export.index - wasm_module.import_function_count]
            .func_type;
        func =
          wasm_module.functions[wasm_export.index - wasm_module.import_function_count];
    }

    if (!wasm_type_equal(expected_function_type, target_function_type)) {
        LOG_DEBUG("%s.%s failed the type check", module_name, function_name);
        set_error_buf_v(error_buf, error_buf_size, "incompatible import type");
        return NULL;
    }

    return func;
}

static WASMTable*
wasm_loader_resolve_table(const char *module_name, const char *table_name,
                          uint32 init_size, uint32 max_size,
                          char *error_buf, uint32 error_buf_size)
{
    WASMModuleCommon* module_reg;
    WASMTable* table;
    WASMExport* wasm_export;
    WASMModule* wasm_module;

    module_reg = wasm_runtime_find_module_registered(module_name);
    if (!module_reg
        || module_reg.module_type != Wasm_Module_Bytecode) {
        LOG_DEBUG("can not find a module named %s for table", module_name);
        set_error_buf_v(error_buf, error_buf_size, "unknown import");
        return NULL;
    }

    wasm_module = cast(WASMModule *)module_reg;
    wasm_export = wasm_loader_find_export(wasm_module, module_name, table_name,
                                     EXPORT_KIND_TABLE,
                                     wasm_module.table_count
                                       + wasm_module.import_table_count,
                                     error_buf, error_buf_size);
    if (!wasm_export) {
        return null;
    }

    /* run a table type check */
    if (wasm_export.index < wasm_module.import_table_count) {
        table =
          wasm_module.import_tables[wasm_export.index].u.table.import_table_linked;
    }
    else {
        table = &(wasm_module.tables[wasm_export.index - wasm_module.import_table_count]);
    }
    if (table.init_size < init_size || table.max_size > max_size) {
        LOG_DEBUG("%s,%s failed type check(%d-%d), expected(%d-%d)",
                  module_name, table_name, table.init_size, table.max_size,
                  init_size, max_size);
        set_error_buf_v(error_buf, error_buf_size, "incompatible import type");
        return NULL;
    }

    return table;
}

static WASMMemory *
wasm_loader_resolve_memory(const char *module_name, const char *memory_name,
                           uint32 init_page_count, uint32 max_page_count,
                           char *error_buf, uint32 error_buf_size)
{
    WASMModuleCommon *module_reg;
    WASMMemory *memory = NULL;
    WASMExport *wasm_export = NULL;
    WASMModule *wasm_module = NULL;

    module_reg = wasm_runtime_find_module_registered(module_name);
    if (!module_reg
        || module_reg.module_type != Wasm_Module_Bytecode) {
        LOG_DEBUG("can not find a module named %s for memory", module_name);
        set_error_buf_v(error_buf, error_buf_size, "unknown import");
        return null;
    }

    wasm_module = cast(WASMModule *)module_reg;
    wasm_export = wasm_loader_find_export(wasm_module, module_name, memory_name,
                                     EXPORT_KIND_MEMORY,
                                     wasm_module.import_memory_count
                                       + wasm_module.memory_count,
                                     error_buf, error_buf_size);
    if (!wasm_export) {
        return null;
    }


    /* run a memory check */
    if (wasm_export.index < wasm_module.import_memory_count) {
        memory =
          wasm_module.import_memories[wasm_export.index].u.memory.import_memory_linked;
    }
    else {
        memory =
          &(wasm_module.memories[wasm_export.index - wasm_module.import_memory_count]);
    }
    if (memory.init_page_count < init_page_count ||
        memory.max_page_count > max_page_count) {
        LOG_DEBUG("%s,%s failed type check(%d-%d), expected(%d-%d)",
                  module_name, memory_name, memory.init_page_count,
                  memory.max_page_count, init_page_count, max_page_count);
        set_error_buf_v(error_buf, error_buf_size, "incompatible import type");
        return NULL;
    }
    return memory;
}

static WASMGlobal *
wasm_loader_resolve_global(const char *module_name,
                           const char *global_name,
                           uint8 type, bool is_mutable,
                           char *error_buf, uint32 error_buf_size)
{
    WASMModuleCommon* module_reg;
    WASMGlobal* global = NULL;
    WASMWasm_Export* wasm_export;
    WASMModule* wasm_module = NULL;

    module_reg = wasm_runtime_find_module_registered(module_name);
    if (!module_reg
        || module_reg.module_type != Wasm_Module_Bytecode) {
        LOG_DEBUG("can not find a module named %s for global", module_name);
        set_error_buf_v(error_buf, error_buf_size, "unknown import");
        return NULL;
    }

    wasm_module = cast(WASMModule*)module_reg;
    wasm_export = wasm_loader_find_export(wasm_module, module_name, global_name,
                                      EXPORT_KIND_GLOBAL,
                                      wasm_module.import_global_count
                                        + wasm_module.global_count,
                                      error_buf, error_buf_size);
    if (!wasm_export) {
        return null;
    }

    /* run a global check */
    if (wasm_export.index < wasm_module.import_global_count) {
        global =
          wasm_module.import_globals[wasm_export.index].u.global.import_global_linked;
    } else {
        global =
          &(wasm_module.globals[wasm_export.index - wasm_module.import_global_count]);
    }
    if (global.type != type || global.is_mutable != is_mutable) {
        LOG_DEBUG("%s,%s failed type check(%d, %d), expected(%d, %d)",
                  module_name, global_name, global.type, global.is_mutable,
                  type, is_mutable);
        set_error_buf_v(error_buf, error_buf_size, "incompatible import type");
        return NULL;
    }
    return global;
}
} /* end of WASM_ENABLE_MULTI_MODULE */

static bool
load_function_import(const WASMModule *parent_module, WASMModule *sub_module,
                     char *sub_module_name, char *function_name,
                     const uint8 **p_buf, const uint8 *buf_end,
                     WASMFunctionImport *func,
                     char *error_buf, uint32 error_buf_size)
{
    const uint8* p = p_buf, p_end = buf_end;
    uint32 declare_type_index = 0;
    WASMType *declare_func_type = NULL;
    WASMFunction *linked_func = NULL;
    const char *linked_signature = NULL;
    void *linked_attachment = NULL;
    bool linked_call_conv_raw = false;
    bool is_built_in_module = false;

    mixin(CHECK_BUF!(p, p_end, 1)());
    read_leb_uint32(p, p_end, declare_type_index);
    *p_buf = p;

    if (declare_type_index >= parent_module.type_count) {
        set_error_buf(error_buf, error_buf_size,
                      "Load import section failed: unknown type.");
        LOG_DEBUG("the type index is out of range");
        return false;
    }

    declare_func_type = parent_module.types[declare_type_index];

    is_built_in_module = wasm_runtime_is_built_in_module(sub_module_name);
    if (is_built_in_module) {
        LOG_DEBUG("%s is a function of a built-in module %s",
                  function_name,
                  sub_module_name);
        /* check built-in modules */
        linked_func = wasm_native_resolve_symbol(sub_module_name,
                                                 function_name,
                                                 declare_func_type,
                                                 &linked_signature,
                                                 &linked_attachment,
                                                 &linked_call_conv_raw);
    }
    else static if (WASM_ENABLE_MULTI_MODULE) {
        LOG_DEBUG("%s is a function of a sub-module %s",
                  function_name,
                  sub_module_name);
        linked_func = wasm_loader_resolve_function(sub_module_name,
                                                   function_name,
                                                   declare_func_type,
                                                   error_buf,
                                                   error_buf_size);
    }


    if (!linked_func) {
        version(WASM_ENABLE_SPEC_TEST) {
        set_error_buf(error_buf,
                      error_buf_size,
                      "unknown import or incompatible import type");
        return false;
        }
        else {
            version(WASM_ENABLE_WAMR_COMPILER) {
                LOG_WARNING(
                    "warning: fail to link import function (%s, %s)",
                    sub_module_name, function_name);
            }
        }
    }

    func.module_name = sub_module_name;
    func.field_name = function_name;
    func.func_type = declare_func_type;
    /* func_ptr_linked is for built-in functions */
    func.func_ptr_linked = is_built_in_module ? linked_func : NULL;
    func.signature = linked_signature;
    func.attachment = linked_attachment;
    func.call_conv_raw = linked_call_conv_raw;
    version(WASM_ENABLE_MULTI_MODULE) {
    func.import_module = is_built_in_module ? NULL : sub_module;
    /* can not set both func_ptr_linked and import_func_linked not NULL */
    func.import_func_linked = is_built_in_module ? NULL : linked_func;
    }
    return true;
}

static bool
check_table_max_size(uint32 init_size, uint32 max_size,
                     char *error_buf, uint32 error_buf_size)
{
    if (max_size < init_size) {
        set_error_buf(error_buf, error_buf_size,
                      "size minimum must not be greater than maximum");
        return false;
    }
    return true;
}

static bool
load_table_import(WASMModule *sub_module, const char *sub_module_name,
                  const char *table_name, const uint8 **p_buf,
                  const uint8 *buf_end, WASMTableImport *table,
                  char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, p_end = buf_end;
    uint32 declare_elem_type = 0;
    uint32 declare_max_size_flag = 0;
    uint32 declare_init_size = 0;
    uint32 declare_max_size = 0;
    version(WASM_ENABLE_MULTI_MODULE) {
        WASMTable *linked_table = NULL;
    }

    mixin(CHECK_BUF!(p, p_end, 1)());
    /* 0x70 */
    declare_elem_type = read_uint8(p);
    if (TABLE_ELEM_TYPE_ANY_FUNC != declare_elem_type) {
        set_error_buf(error_buf, error_buf_size, "incompatible import type");
        return false;
    }

    read_leb_uint32(p, p_end, declare_max_size_flag);
    read_leb_uint32(p, p_end, declare_init_size);
    if (declare_max_size_flag & 1) {
        read_leb_uint32(p, p_end, declare_max_size);
        if (!check_table_max_size(table.init_size, table.max_size,
                                  error_buf, error_buf_size))
            return false;
    } else {
        declare_max_size = 0x10000;
    }
    *p_buf = p;

    version(WASM_ENABLE_MULTI_MODULE) {
    if (!wasm_runtime_is_built_in_module(sub_module_name)) {
        linked_table = wasm_loader_resolve_table(
                            sub_module_name, table_name,
                            declare_init_size, declare_max_size,
                            error_buf, error_buf_size);
        if (!linked_table) {
            LOG_DEBUG("(%s, %s) is not an exported from one of modules",
                      table_name, sub_module_name);
            return false;
        }

        /**
         * reset with linked table limit
         */
        declare_elem_type = linked_table.elem_type;
        declare_init_size = linked_table.init_size;
        declare_max_size = linked_table.max_size;
        declare_max_size_flag = linked_table.flags;
        table.import_table_linked = linked_table;
        table.import_module = sub_module;
    }
    }

    /* (table (export "table") 10 20 funcref) */
    if (!strcmp("spectest", sub_module_name)) {
        uint32 spectest_table_init_size = 10;
        uint32 spectest_table_max_size = 20;

        if (strcmp("table", table_name)) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type or unknown import");
            return false;
        }

        if (declare_init_size > spectest_table_init_size
            || declare_max_size < spectest_table_max_size) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type");
            return false;
        }

        declare_init_size = spectest_table_init_size;
        declare_max_size = spectest_table_max_size;
    }

    /* now we believe all declaration are ok */
    table.elem_type = declare_elem_type;
    table.init_size = declare_init_size;
    table.flags = declare_max_size_flag;
    table.max_size = declare_max_size;
    return true;
}

unsigned
wasm_runtime_memory_pool_size();

static bool
check_memory_init_size(uint32 init_size,
                       char *error_buf, uint32 error_buf_size)
{
    if (init_size > 65536) {
        set_error_buf(error_buf, error_buf_size,
                      "memory size must be at most 65536 pages (4GiB)");
        return false;
    }
    return true;
}

static bool
check_memory_max_size(uint32 init_size, uint32 max_size,
                      char *error_buf, uint32 error_buf_size)
{
    if (max_size < init_size) {
        set_error_buf(error_buf, error_buf_size,
                      "size minimum must not be greater than maximum");
        return false;
    }

    if (max_size > 65536) {
        set_error_buf(error_buf, error_buf_size,
                      "memory size must be at most 65536 pages (4GiB)");
        return false;
    }
    return true;
}

static bool
load_memory_import(WASMModule *sub_module, const char *sub_module_name,
                   const char *memory_name, const uint8 **p_buf,
                   const uint8 *buf_end, WASMMemoryImport *memory,
                   char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, p_end = buf_end;
    uint32 pool_size = wasm_runtime_memory_pool_size();
    version(WASM_ENABLE_APP_FRAMEWORK) {
    uint32 max_page_count = pool_size * APP_MEMORY_MAX_GLOBAL_HEAP_PERCENT
                            / DEFAULT_NUM_BYTES_PER_PAGE;
    }
    else {
    uint32 max_page_count = pool_size / DEFAULT_NUM_BYTES_PER_PAGE;
    } /* WASM_ENABLE_APP_FRAMEWORK */
    uint32 declare_max_page_count_flag = 0;
    uint32 declare_init_page_count = 0;
    uint32 declare_max_page_count = 0;
    version(WASM_ENABLE_MULTI_MODULE) {
    WASMMemory *linked_memory = NULL;
    }

    read_leb_uint32(p, p_end, declare_max_page_count_flag);
    read_leb_uint32(p, p_end, declare_init_page_count);
    if (!check_memory_init_size(declare_init_page_count, error_buf,
                                error_buf_size)) {
        return false;
    }

    if (declare_max_page_count_flag & 1) {
        read_leb_uint32(p, p_end, declare_max_page_count);
        if (!check_memory_max_size(declare_init_page_count,
                                   declare_max_page_count, error_buf,
                                   error_buf_size)) {
            return false;
        }
        if (declare_max_page_count > max_page_count) {
            declare_max_page_count = max_page_count;
        }
    }
    else {
        /* Limit the maximum memory size to max_page_count */
        declare_max_page_count = max_page_count;
    }

    version(WASM_ENABLE_MULTI_MODULE) {
    if (!wasm_runtime_is_built_in_module(sub_module_name)) {
        linked_memory = wasm_loader_resolve_memory(
                    sub_module_name, memory_name,
                    declare_init_page_count, declare_max_page_count,
                    error_buf, error_buf_size);
        if (!linked_memory) {
            return false;
        }

        /**
         * reset with linked memory limit
         */
        memory.import_module = sub_module;
        memory.import_memory_linked = linked_memory;
        declare_init_page_count = linked_memory.init_page_count;
        declare_max_page_count = linked_memory.max_page_count;
    }
    }

    /* (memory (export "memory") 1 2) */
    if (!strcmp("spectest", sub_module_name)) {
        uint32 spectest_memory_init_page = 1;
        uint32 spectest_memory_max_page = 2;

        if (strcmp("memory", memory_name)) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type or unknown import");
            return false;
        }

        if (declare_init_page_count > spectest_memory_init_page
            || declare_max_page_count < spectest_memory_max_page) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type");
            return false;
        }

        declare_init_page_count = spectest_memory_init_page;
        declare_max_page_count = spectest_memory_max_page;
    }

    /* now we believe all declaration are ok */
    memory.flags = declare_max_page_count_flag;
    memory.init_page_count = declare_init_page_count;
    memory.max_page_count = declare_max_page_count;
    memory.num_bytes_per_page = DEFAULT_NUM_BYTES_PER_PAGE;

    *p_buf = p;
    return true;
}

static bool
load_global_import(const WASMModule *parent_module,
                   WASMModule *sub_module,
                   char *sub_module_name, char *global_name,
                   const uint8 **p_buf, const uint8 *buf_end,
                   WASMGlobalImport *global,
                   char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, p_end = buf_end;
    uint8 declare_type = 0;
    uint8 declare_mutable = 0;
    bool is_mutable = false;
    bool ret = false;

    mixin(CHECK_BUF!(p, p_end, 2)());
    declare_type = read_uint8(p);
    declare_mutable = read_uint8(p);
    *p_buf = p;

    if (declare_mutable >= 2) {
        set_error_buf(error_buf, error_buf_size,
                      "Load import section failed: " ~
                      "invalid mutability");
        return false;
    }

    is_mutable = declare_mutable & 1 ? true : false;

    version(WASM_ENABLE_LIBC_BUILTIN) {
        ret = wasm_runtime_is_built_in_module(sub_module_name);
        if (ret) {
            /* check built-in modules */
            ret = wasm_native_lookup_libc_builtin_global(sub_module_name,
                global_name, global);
            if (ret) {
                LOG_DEBUG("(%s, %s) is a global of a built-in module",
                      sub_module_name, global_name);
            }
        }
    } /* WASM_ENABLE_LIBC_BUILTIN */

    version(WASM_ENABLE_MULTI_MODULE) {
    if (!ret) {
        /* check sub modules */
        WASMGlobal *linked_global =
            wasm_loader_resolve_global(sub_module_name, global_name,
                                       declare_type, declare_mutable,
                                       error_buf, error_buf_size);
        if (linked_global) {
            LOG_DEBUG("(%s, %s) is a global of external module",
                      sub_module_name, global_name);
            global.import_module = sub_module;
            global.import_global_linked = linked_global;
            ret = true;
        }
    }
    }

    if (!ret) {
        set_error_buf_v(error_buf, error_buf_size,
                        "unknown import or incompatible import type");
        return false;
    }

    global.module_name = sub_module_name;
    global.field_name = global_name;
    global.type = declare_type;
    global.is_mutable = is_mutable;
    return true;
}

static bool
load_table(const uint8 **p_buf, const uint8 *buf_end, WASMTable *table,
           char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, p_end = buf_end;

    mixin(CHECK_BUF!(p, p_end, 1)());
    /* 0x70 */
    table.elem_type = read_uint8(p);
    if (TABLE_ELEM_TYPE_ANY_FUNC != table.elem_type) {
        set_error_buf(error_buf, error_buf_size, "incompatible import type");
        return false;
    }

    read_leb_uint32(p, p_end, table.flags);
    read_leb_uint32(p, p_end, table.init_size);
    if (table.flags & 1) {
        read_leb_uint32(p, p_end, table.max_size);
        if (!check_table_max_size(table.init_size, table.max_size,
                                  error_buf, error_buf_size))
            return false;
    }
    else
        table.max_size = 0x10000;

    if ((table.flags & 1) && table.init_size > table.max_size) {
        set_error_buf(error_buf, error_buf_size,
                      "size minimum must not be greater than maximum");
        return false;
    }

    *p_buf = p;
    return true;
}

static bool
load_memory(const uint8 **p_buf, const uint8 *buf_end, WASMMemory *memory,
            char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, p_end = buf_end;
    uint32 pool_size = wasm_runtime_memory_pool_size();
    version(WASM_ENABLE_APP_FRAMEWORK) {
    uint32 max_page_count = pool_size * APP_MEMORY_MAX_GLOBAL_HEAP_PERCENT
                            / DEFAULT_NUM_BYTES_PER_PAGE;
    }
    else {
    uint32 max_page_count = pool_size / DEFAULT_NUM_BYTES_PER_PAGE;
    }

    read_leb_uint32(p, p_end, memory.flags);
    read_leb_uint32(p, p_end, memory.init_page_count);
    if (!check_memory_init_size(memory.init_page_count,
                                error_buf, error_buf_size))
        return false;

    if (memory.flags & 1) {
        read_leb_uint32(p, p_end, memory.max_page_count);
        if (!check_memory_max_size(memory.init_page_count,
                                   memory.max_page_count,
                                   error_buf, error_buf_size))
                return false;
        if (memory.max_page_count > max_page_count)
            memory.max_page_count = max_page_count;
    }
    else
        /* Limit the maximum memory size to max_page_count */
        memory.max_page_count = max_page_count;

    memory.num_bytes_per_page = DEFAULT_NUM_BYTES_PER_PAGE;

    *p_buf = p;
    return true;
}

version(WASM_ENABLE_MULTI_MODULE) {
static WASMModule *
search_sub_module(const WASMModule *parent_module, const char *sub_module_name)
{
    WASMRegisteredModule *node =
      bh_list_first_elem(parent_module.import_module_list);
    while (node && strcmp(sub_module_name, node.module_name)) {
        node = bh_list_elem_next(node);
    }
    return node ? cast(WASMModule*)node.wasm_module : NULL;
}

static bool
register_sub_module(const WASMModule *parent_module,
                    const char *sub_module_name, WASMModule *sub_module)
{
    /* register a sub_module on its parent sub module list */
    WASMRegisteredModule *node = NULL;
    bh_list_status ret;

    if (search_sub_module(parent_module, sub_module_name)) {
        LOG_DEBUG("%s has been registered in its parent", sub_module_name);
        return true;
    }

    node = wasm_runtime_malloc(sizeof(WASMRegisteredModule));
    if (!node) {
        LOG_DEBUG("malloc WASMRegisteredModule failed. SZ %d\n",
                  sizeof(WASMRegisteredModule));
        return false;
    }

    node.module_name = sub_module_name;
    node.wasm_module = cast(WASMModuleCommon*)sub_module;
    ret = bh_list_insert(parent_module.import_module_list, node);
    bh_assert(BH_LIST_SUCCESS == ret);
//    (void)ret;
    return true;
}

static WASMModule *
load_depended_module(const WASMModule *parent_module,
                     const char *sub_module_name, char *error_buf,
                     uint32 error_buf_size)
{
    WASMModule *sub_module = NULL;
    bool ret = false;
    uint8 *buffer = NULL;
    uint32 buffer_size = 0;
    const module_reader reader = wasm_runtime_get_module_reader();
    const module_destroyer destroyer = wasm_runtime_get_module_destroyer();

    /* check the registered module list of the parent */
    sub_module = search_sub_module(parent_module, sub_module_name);
    if (sub_module) {
        LOG_DEBUG("%s has been loaded before", sub_module_name);
        return sub_module;
    }

    /* check the global registered module list */
    sub_module =
      cast(WASMModule *)wasm_runtime_find_module_registered(sub_module_name);
    if (sub_module) {
        LOG_DEBUG("%s has been loaded", sub_module_name);
        goto REGISTER_SUB_MODULE;
    }

    LOG_VERBOSE("to load %s", sub_module_name);

    if (!reader) {
        LOG_DEBUG("error: there is no sub_module reader to load %s",
                  sub_module_name);
        set_error_buf_v(error_buf, error_buf_size,
                        "error: there is no sub_module reader to load %s",
                        sub_module_name);
        return NULL;
    }

    /* start to maintain a loading module list */
    ret = wasm_runtime_is_loading_module(sub_module_name);
    if (ret) {
        LOG_DEBUG("find a circular dependency on %s", sub_module_name);
        set_error_buf_v(error_buf, error_buf_size,
                        "error: find a circular dependency on %s",
                        sub_module_name);
        return NULL;
    }

    ret = wasm_runtime_add_loading_module(sub_module_name, error_buf,
                                          error_buf_size);
    if (!ret) {
        LOG_DEBUG("can not add %s into loading module list\n",
                  sub_module_name);
        return NULL;
    }

    ret = reader(sub_module_name, &buffer, &buffer_size);
    if (!ret) {
        LOG_DEBUG("read the file of %s failed", sub_module_name);
        set_error_buf_v(error_buf, error_buf_size,
                        "error: can not read the module file of %s",
                        sub_module_name);
        goto DELETE_FROM_LOADING_LIST;
    }

    sub_module =
      wasm_loader_load(buffer, buffer_size, error_buf, error_buf_size);
    if (!sub_module) {
        LOG_DEBUG("error: can not load the sub_module %s", sub_module_name);
        /*
         * others will be destroyed in runtime_destroy()
         */
        goto DESTROY_FILE_BUFFER;
    }

    wasm_runtime_delete_loading_module(sub_module_name);

    /* register on a global list */
    ret = wasm_runtime_register_module_internal(sub_module_name,
                                                cast(WASMModuleCommon*)sub_module,
                                                buffer, buffer_size, error_buf,
                                                error_buf_size);
    if (!ret) {
        LOG_DEBUG("error: can not register module %s globally\n",
                  sub_module_name);
        /*
         * others will be unload in runtime_destroy()
         */
        goto UNLOAD_MODULE;
    }

    /* register on its parent list */
REGISTER_SUB_MODULE:
    ret = register_sub_module(parent_module, sub_module_name, sub_module);
    if (!ret) {
        LOG_DEBUG("error: can not register a sub module %s with its parent",
                  sizeof(WASMRegisteredModule));
        set_error_buf_v(
          error_buf, error_buf_size,
          "error: can not register a sub module %s with its parent",
          sizeof(WASMRegisteredModule));
        /*
         * since it is in the global module list, there is no need to
         * unload the module. the runtime_destroy() will do it
         */
        return NULL;
    }

    return sub_module;

UNLOAD_MODULE:
    wasm_loader_unload(sub_module);

DESTROY_FILE_BUFFER:
    if (destroyer) {
        destroyer(buffer, buffer_size);
    }
    else {
        LOG_WARNING("need to release the reading buffer of %s manually",
                    sub_module_name);
    }

DELETE_FROM_LOADING_LIST:
    wasm_runtime_delete_loading_module(sub_module_name);
    return NULL;
}
} /* WASM_ENABLE_MULTI_MODULE */

static bool
load_import_section(const uint8 *buf, const uint8 *buf_end, WASMModule *wasm_module,
                    char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end, p_old;
    uint32 import_count, name_len, type_index, i, u32, flags;
    uint64 total_size;
    WASMImport* wasm_import;
    WASMImport* import_functions, import_tables;
    WASMImport* import_memories, import_globals;
    char* sub_module_name, field_name;
    uint8 u8, kind;

    read_leb_uint32(p, p_end, import_count);

    if (import_count) {
        wasm_module.import_count = import_count;
        total_size = WASMImport.sizeof * cast(uint64)import_count;
        if (!(wasm_module.imports = loader_malloc
                    (total_size, error_buf, error_buf_size))) {
            return false;
        }

        p_old = p;

        /* Scan firstly to get import count of each type */
        for (i = 0; i < import_count; i++) {
            /* module name */
            read_leb_uint32(p, p_end, name_len);
            mixin(CHECK_BUF!(p, p_end, name_len)());
            p += name_len;

            /* field name */
            read_leb_uint32(p, p_end, name_len);
            mixin(CHECK_BUF!(p, p_end, name_len)());
            p += name_len;

            mixin(CHECK_BUF!(p, p_end, 1)());
            /* 0x00/0x01/0x02/0x03 */
            kind = read_uint8(p);

            switch (kind) {
                case IMPORT_KIND_FUNC: /* import function */
                    read_leb_uint32(p, p_end, type_index);
                    wasm_module.import_function_count++;
                    break;

                case IMPORT_KIND_TABLE: /* import table */
                    mixin(CHECK_BUF!(p, p_end, 1)());
                    /* 0x70 */
                    u8 = read_uint8(p);
                    read_leb_uint32(p, p_end, flags);
                    read_leb_uint32(p, p_end, u32);
                    if (flags & 1)
                        read_leb_uint32(p, p_end, u32);
                    wasm_module.import_table_count++;
                    if (wasm_module.import_table_count > 1) {
                        set_error_buf(error_buf, error_buf_size,
                                      "Load import section failed: multiple tables");
                        return false;
                    }
                    break;

                case IMPORT_KIND_MEMORY: /* import memory */
                    read_leb_uint32(p, p_end, flags);
                    read_leb_uint32(p, p_end, u32);
                    if (flags & 1)
                        read_leb_uint32(p, p_end, u32);
                    wasm_module.import_memory_count++;
                    if (wasm_module.import_memory_count > 1) {
                        set_error_buf(error_buf, error_buf_size,
                                      "Load import section failed: multiple memories");
                        return false;
                    }
                    break;

                case IMPORT_KIND_GLOBAL: /* import global */
                    mixin(CHECK_BUF!(p, p_end, 2)());
                    p += 2;
                    wasm_module.import_global_count++;
                    break;

                default:
                    set_error_buf(error_buf, error_buf_size,
                                  "Load import section failed: invalid import type.");
                    return false;
            }
        }

        if (wasm_module.import_function_count)
            import_functions = wasm_module.import_functions = wasm_module.imports;
        if (wasm_module.import_table_count)
            import_tables = wasm_module.import_tables =
                wasm_module.imports + wasm_module.import_function_count;
        if (wasm_module.import_memory_count)
            import_memories = wasm_module.import_memories =
                wasm_module.imports + wasm_module.import_function_count + wasm_module.import_table_count;
        if (wasm_module.import_global_count)
            import_globals = wasm_module.import_globals =
                wasm_module.imports + wasm_module.import_function_count + wasm_module.import_table_count
                + wasm_module.import_memory_count;

        p = p_old;

        // TODO: move it out of the loop
        /* insert "env", "wasi_unstable" and "wasi_snapshot_preview1" to const str list */
        if (!const_str_list_insert(cast(uint8*)"env", 3, wasm_module, error_buf, error_buf_size)
            || !const_str_list_insert(cast(uint8*)"wasi_unstable", 13, wasm_module,
                                     error_buf, error_buf_size)
            || !const_str_list_insert(cast(uint8*)"wasi_snapshot_preview1", 22, wasm_module,
                                     error_buf, error_buf_size)) {
            return false;
        }

        /* Scan again to read the data */
        for (i = 0; i < import_count; i++) {
            WASMModule *sub_module = NULL;

            /* load module name */
            read_leb_uint32(p, p_end, name_len);
            mixin(CHECK_BUF!(p, p_end, name_len)());
            if (!(sub_module_name = const_str_list_insert(
                    p, name_len, wasm_module, error_buf, error_buf_size))) {
                return false;
            }
            p += name_len;

            /* load field name */
            read_leb_uint32(p, p_end, name_len);
            mixin(CHECK_BUF!(p, p_end, name_len)());
            if (!(field_name = const_str_list_insert(
                    p, name_len, wasm_module, error_buf, error_buf_size))) {
                return false;
            }
            p += name_len;

            LOG_DEBUG("import #%d: (%s, %s)", i, sub_module_name, field_name);
            version(WASM_ENABLE_MULTI_MODULE) {
            /* assume built-in modules have been loaded */
            if (!wasm_runtime_is_built_in_module(sub_module_name)) {
                LOG_DEBUG("%s is an exported field of a %s", field_name,
                          sub_module_name);
                /*
                * if it returns well, guarantee that
                * the sub_module_name and its dependencies
                * have been loaded well
                */
                sub_module = load_depended_module(wasm_module, sub_module_name,
                                                  error_buf, error_buf_size);
                if (!sub_module) {
                    return false;
                }
            }
            }

            mixin(CHECK_BUF!(p, p_end, 1)());
            /* 0x00/0x01/0x02/0x03 */
            kind = read_uint8(p);
            switch (kind) {
                case IMPORT_KIND_FUNC: /* import function */
                    bh_assert(import_functions);
                    wasm_import = import_functions++;
                    if (!load_function_import(wasm_module, sub_module,
                                              sub_module_name, field_name, &p,
                                              p_end, &wasm_import.u.func,
                                              error_buf, error_buf_size)) {
                        return false;
                    }
                    break;

                case IMPORT_KIND_TABLE: /* import table */
                    bh_assert(import_tables);
                    wasm_import = import_tables++;
                    if (!load_table_import(sub_module,
                                           sub_module_name,
                                           field_name,
                                           &p,
                                           p_end,
                            &wasm_import.u.table,
                                           error_buf,
                                           error_buf_size)) {
                        LOG_DEBUG("can not import such a table (%s,%s)",
                                  sub_module_name, field_name);
                        return false;
                    }
                    break;

                case IMPORT_KIND_MEMORY: /* import memory */
                    bh_assert(import_memories);
                    wasm_import = import_memories++;
                    if (!load_memory_import(sub_module,
                                            sub_module_name,
                                            field_name,
                                            &p,
                                            p_end,
                                            &wasm_import.u.memory,
                                            error_buf,
                                            error_buf_size)) {
                        return false;
                    }
                    break;

                case IMPORT_KIND_GLOBAL: /* import global */
                    bh_assert(import_globals);
                    wasm_import = import_globals++;
                    if (!load_global_import(wasm_module, sub_module,
                                            sub_module_name, field_name,
                                            &p, p_end, &wasm_import.u.global,
                                            error_buf, error_buf_size)) {
                        return false;
                    }
                    break;

                default:
                    set_error_buf(error_buf, error_buf_size,
                                  "Load import section failed: " ~
                                  "invalid import type.");
                    return false;
            }
            wasm_import.kind = kind;
            wasm_import.u.names.module_name = sub_module_name;
            wasm_import.u.names.field_name = field_name;
            //(void)sub_module;
        }

        version(WASM_ENABLE_LIBC_WASI) {
            wasm_import = wasm_module.import_functions;
        for (i = 0; i < wasm_module.import_function_count; i++, wasm_import++) {
            if (!strcmp(wasm_import.u.names.module_name, "wasi_unstable")
                || !strcmp(wasm_import.u.names.module_name, "wasi_snapshot_preview1")) {
                wasm_module.is_wasi_module = true;
                break;
            }
        }
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load import section failed: section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load import section success.\n");
    // (void)u8;
    // (void)u32;
    // (void)type_index;
    return true;
}

static bool
init_function_local_offsets(WASMFunction *func,
                            char *error_buf, uint32 error_buf_size)
{
    WASMType *param_type = func.func_type;
    uint32 param_count = param_type.param_count;
    uint8 *param_types = param_type.types;
    uint32 local_count = func.local_count;
    uint8 *local_types = func.local_types;
    uint32 i, local_offset = 0;
    uint64 total_size = uint16.sizeof * (cast(uint64)param_count + local_count);

    if (!(func.local_offsets =
                loader_malloc(total_size, error_buf, error_buf_size))) {
        return false;
    }

    for (i = 0; i < param_count; i++) {
        func.local_offsets[i] = cast(uint16)local_offset;
        local_offset += wasm_value_type_cell_num(param_types[i]);
    }

    for (i = 0; i < local_count; i++) {
        func.local_offsets[param_count + i] = cast(uint16)local_offset;
        local_offset += wasm_value_type_cell_num(local_types[i]);
    }

    bh_assert(local_offset == func.param_cell_num + func.local_cell_num);
    return true;
}

static bool
load_function_section(const uint8 *buf, const uint8 *buf_end,
                      const uint8 *buf_code, const uint8 *buf_code_end,
                      WASMModule *wasm_module,
                      char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end;
    const uint8 *p_code = buf_code, p_code_end, p_code_save;
    uint32 func_count;
    uint64 total_size;
    uint32 code_count = 0, code_size, type_index, i, j, k, local_type_index;
    uint32 local_count, local_set_count, sub_local_count;
    uint8 type;
    WASMFunction *func;

    read_leb_uint32(p, p_end, func_count);

    if (buf_code)
        read_leb_uint32(p_code, buf_code_end, code_count);

    if (func_count != code_count) {
        set_error_buf(error_buf, error_buf_size,
                      "Load function section failed: " ~
                      "function and code section have inconsistent lengths");
        return false;
    }

    if (func_count) {
        wasm_module.function_count = func_count;
        total_size = (WASMFunction*).sizeof * cast(uint64)func_count;
        if (!(wasm_module.functions =
                    loader_malloc(total_size, error_buf, error_buf_size))) {
            return false;
        }

        for (i = 0; i < func_count; i++) {
            /* Resolve function type */
            read_leb_uint32(p, p_end, type_index);
            if (type_index >= wasm_module.type_count) {
                set_error_buf(error_buf, error_buf_size,
                              "Load function section failed: " ~
                              "unknown type.");
                return false;
            }

            read_leb_uint32(p_code, buf_code_end, code_size);
            if (code_size == 0
                || p_code + code_size > buf_code_end) {
                set_error_buf(error_buf, error_buf_size,
                              "Load function section failed: " ~
                              "invalid function code size.");
                return false;
            }

            /* Resolve local set count */
            p_code_end = p_code + code_size;
            local_count = 0;
            read_leb_uint32(p_code, buf_code_end, local_set_count);
            p_code_save = p_code;

            /* Calculate total local count */
            for (j = 0; j < local_set_count; j++) {
                read_leb_uint32(p_code, buf_code_end, sub_local_count);
                if (sub_local_count > UINT32_MAX - local_count) {
                    set_error_buf(error_buf, error_buf_size,
                                  "Load function section failed: " ~
                                  "too many locals");
                    return false;
                }
                mixin(CHECK_BUF!(p_code, buf_code_end, 1)());
                /* 0x7F/0x7E/0x7D/0x7C */
                type = read_uint8(p_code);
                local_count += sub_local_count;
            }

            /* Alloc memory, layout: function structure + local types */
            code_size = cast(uint32)(p_code_end - p_code);

            total_size = WASMFunction.sizeof + cast(uint64)local_count;
            if (!(func = wasm_module.functions[i] =
                        loader_malloc(total_size, error_buf, error_buf_size))) {
                return false;
            }

            /* Set function type, local count, code size and code body */
            func.func_type = wasm_module.types[type_index];
            func.local_count = local_count;
            if (local_count > 0)
                func.local_types = cast(uint8*)func + WASMFunction.sizeof;
            func.code_size = code_size;
            /*
             * we shall make a copy of code body [p_code, p_code + code_size]
             * when we are worrying about inappropriate releasing behaviour.
             * all code bodies are actually in a buffer which user allocates in
             * his embedding environment and we don't have power on them.
             * it will be like:
             * code_body_cp = malloc(code_size);
             * memcpy(code_body_cp, p_code, code_size);
             * func.code = code_body_cp;
             */
            func.code = cast(uint8*)p_code;

            /* Load each local type */
            p_code = p_code_save;
            local_type_index = 0;
            for (j = 0; j < local_set_count; j++) {
                read_leb_uint32(p_code, buf_code_end, sub_local_count);
                if (local_type_index + sub_local_count <= local_type_index
                    || local_type_index + sub_local_count > local_count) {
                    set_error_buf(error_buf, error_buf_size,
                                  "Load function section failed: " ~
                                  "invalid local count.");
                    return false;
                }
                mixin(CHECK_BUF!(p_code, buf_code_end, 1)());
                /* 0x7F/0x7E/0x7D/0x7C */
                type = read_uint8(p_code);
                if (type < VALUE_TYPE_F64 || type > VALUE_TYPE_I32) {
                    set_error_buf(error_buf, error_buf_size,
                                  "Load function section failed: " ~
                                  "invalid local type.");
                    return false;
                }
                for (k = 0; k < sub_local_count; k++) {
                    func.local_types[local_type_index++] = type;
                }
            }

            func.param_cell_num = func.func_type.param_cell_num;
            func.ret_cell_num = func.func_type.ret_cell_num;
            func.local_cell_num =
                wasm_get_cell_num(func.local_types, func.local_count);

            if (!init_function_local_offsets(func, error_buf, error_buf_size))
                return false;

            p_code = p_code_end;
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load function section failed: section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load function section success.\n");
    return true;
}

static bool
load_table_section(const uint8 *buf, const uint8 *buf_end, WASMModule *wasm_module,
                   char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end;
    uint32 table_count, i;
    uint64 total_size;
    WASMTable *table;

    read_leb_uint32(p, p_end, table_count);
    /* a total of one table is allowed */
    if (wasm_module.import_table_count + table_count > 1) {
        set_error_buf(error_buf, error_buf_size, "multiple tables");
        return false;
    }

    if (table_count) {
        wasm_module.table_count = table_count;
        total_size = WASMTable.sizeof * cast(uint64)table_count;
        if (!(wasm_module.tables = loader_malloc
                    (total_size, error_buf, error_buf_size))) {
            return false;
        }

        /* load each table */
        table = wasm_module.tables;
        for (i = 0; i < table_count; i++, table++)
            if (!load_table(&p, p_end, table, error_buf, error_buf_size))
                return false;
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load table section failed: section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load table section success.\n");
    return true;
}

static bool
load_memory_section(const uint8 *buf, const uint8 *buf_end, WASMModule * wasm_module,
                    char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end;
    uint32 memory_count, i;
    uint64 total_size;
    WASMMemory *memory;

    read_leb_uint32(p, p_end, memory_count);
    /* a total of one memory is allowed */
    if (wasm_module.import_memory_count + memory_count > 1) {
        set_error_buf(error_buf, error_buf_size, "multiple memories");
        return false;
    }

    if (memory_count) {
        wasm_module.memory_count = memory_count;
        total_size = WASMMemory.sizeof * cast(uint64)memory_count;
        if (!(wasm_module.memories = loader_malloc
                    (total_size, error_buf, error_buf_size))) {
            return false;
        }

        /* load each memory */
        memory = wasm_module.memories;
        for (i = 0; i < memory_count; i++, memory++)
            if (!load_memory(&p, p_end, memory, error_buf, error_buf_size))
                return false;
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load memory section failed: section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load memory section success.\n");
    return true;
}

static bool
load_global_section(const uint8 *buf, const uint8 *buf_end, WASMModule *wasm_module,
                    char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end;
    uint32 global_count, i;
    uint64 total_size;
    WASMGlobal *global;
    uint8 mutable;

    read_leb_uint32(p, p_end, global_count);

    if (global_count) {
        wasm_module.global_count = global_count;
        total_size = WASMGlobal.sizeof * cast(uint64)global_count;
        if (!(wasm_module.globals = loader_malloc
                    (total_size, error_buf, error_buf_size))) {
            return false;
        }

        global = wasm_module.globals;

        for(i = 0; i < global_count; i++, global++) {
            mixin(CHECK_BUF!(p, p_end, 2)());
            global.type = read_uint8(p);
            mutable = read_uint8(p);
            if (mutable >= 2) {
                set_error_buf(error_buf, error_buf_size,
                              "Load import section failed: " ~
                              "invalid mutability");
                return false;
            }
            global.is_mutable = mutable ? true : false;

            /* initialize expression */
            if (!load_init_expr(&p, p_end, &(global.init_expr),
                                global.type, error_buf, error_buf_size))
                return false;

            if (INIT_EXPR_TYPE_GET_GLOBAL == global.init_expr.init_expr_type) {
                /**
                 * Currently, constant expressions occurring as initializers
                 * of globals are further constrained in that contained
                 * global.get instructions are
                 * only allowed to refer to imported globals.
                 */
                uint32 target_global_index = global.init_expr.u.global_index;
                if (target_global_index >= wasm_module.import_global_count) {
                    set_error_buf(error_buf, error_buf_size, "unknown global");
                    return false;
                }
            }
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load global section failed: section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load global section success.\n");
    return true;
}

static bool
load_export_section(const uint8 *buf, const uint8 *buf_end, WASMModule *wasm_module,
                    char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end;
    uint32 export_count, i, j, index;
    uint64 total_size;
    uint32 str_len;
    WASMExport *wasm_export;
    const char *name;

    read_leb_uint32(p, p_end, export_count);

    if (export_count) {
        wasm_module.export_count = export_count;
        total_size = WASMExport.sizeof * cast(uint64)export_count;
        if (!(wasm_module.exports = loader_malloc
                    (total_size, error_buf, error_buf_size))) {
            return false;
        }

        wasm_export = wasm_module.wasm_exports;
        for (i = 0; i < export_count; i++, wasm_export++) {
            read_leb_uint32(p, p_end, str_len);
            mixin(CHECK_BUF!(p, p_end, str_len)());

            for (j = 0; j < i; j++) {
                name = wasm_module.exports[j].name;
                if (strlen(name) == str_len
                    && memcmp(name, p, str_len) == 0) {
                   set_error_buf(error_buf, error_buf_size,
                                 "duplicate export name");
                   return false;
                }
            }

            if (!(wasm_export.name = const_str_list_insert(p, str_len, wasm_module,
                            error_buf, error_buf_size))) {
                return false;
            }

            p += str_len;
            mixin(CHECK_BUF!(p, p_end, 1)());
            wasm_export.kind = read_uint8(p);
            read_leb_uint32(p, p_end, index);
            wasm_export.index = index;

            switch(wasm_export.kind) {
                /*function index*/
                case EXPORT_KIND_FUNC:
                    if (index >= wasm_module.function_count + wasm_module.import_function_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "Load export section failed: " ~
                                      "unknown function.");
                        return false;
                    }
                    break;
                /*table index*/
                case EXPORT_KIND_TABLE:
                    if (index >= wasm_module.table_count + wasm_module.import_table_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "Load export section failed: " ~
                                      "unknown table.");
                        return false;
                    }
                    break;
                /*memory index*/
                case EXPORT_KIND_MEMORY:
                    if (index >= wasm_module.memory_count + wasm_module.import_memory_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "Load export section failed: " ~
                                      "unknown memory.");
                        return false;
                    }
                    break;
                /*global index*/
                case EXPORT_KIND_GLOBAL:
                    if (index >= wasm_module.global_count + wasm_module.import_global_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "Load export section failed: " ~
                                      "unknown global.");
                        return false;
                    }
                    break;
                default:
                    set_error_buf(error_buf, error_buf_size,
                                  "Load export section failed: " ~
                                  "invalid export kind.");
                    return false;
            }
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load export section failed: section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load export section success.\n");
    return true;
}

static bool
load_table_segment_section(const uint8 *buf, const uint8 *buf_end, WASMModule *wasm_module,
                           char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end;
    uint32 table_segment_count, i, j, table_index, function_count, function_index;
    uint64 total_size;
    WASMTableSeg *table_segment;

    read_leb_uint32(p, p_end, table_segment_count);

    if (table_segment_count) {
        wasm_module.table_seg_count = table_segment_count;
        total_size = WASMTableSeg.sizeof * cast(uint64)table_segment_count;
        if (!(wasm_module.table_segments = loader_malloc
                (total_size, error_buf, error_buf_size))) {
            return false;
        }

        table_segment = wasm_module.table_segments;
        for (i = 0; i < table_segment_count; i++, table_segment++) {
            if (p >= p_end) {
                set_error_buf(error_buf, error_buf_size,
                              "Load table segment section failed: " ~
                              "unexpected end");
                return false;
            }
            read_leb_uint32(p, p_end, table_index);
            if (table_index
                >= wasm_module.import_table_count + wasm_module.table_count) {
                LOG_DEBUG("table#%d does not exist", table_index);
                set_error_buf(error_buf, error_buf_size, "unknown table");
                return false;
            }

            table_segment.table_index = table_index;

            /* initialize expression */
            if (!load_init_expr(&p, p_end, &(table_segment.base_offset),
                                VALUE_TYPE_I32, error_buf, error_buf_size))
                return false;

            read_leb_uint32(p, p_end, function_count);
            table_segment.function_count = function_count;
            total_size = uint32.sizeof * cast(uint64)function_count;
            if (!(table_segment.func_indexes = cast(uint32 *)
                    loader_malloc(total_size, error_buf, error_buf_size))) {
                return false;
            }
            for (j = 0; j < function_count; j++) {
                read_leb_uint32(p, p_end, function_index);
                if (function_index >= wasm_module.import_function_count
                                      + wasm_module.function_count) {
                    set_error_buf(error_buf, error_buf_size,
                                  "Load table segment section failed: " ~
                                  "unknown function");
                    return false;
                }
                table_segment.func_indexes[j] = function_index;
            }
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                     "Load table segment section failed: section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load table segment section success.\n");
    return true;
}

static bool
load_data_segment_section(const uint8 *buf, const uint8 *buf_end,
                          WASMModule *wasm_module,
                          char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end;
    uint32 data_seg_count, i, mem_index, data_seg_len;
    uint64 total_size;
    WASMDataSeg *dataseg;
    InitializerExpression init_expr;
    version(WASM_ENABLE_BULK_MEMORY) {
    bool is_passive = false;
    uint32 mem_flag;
    }

    read_leb_uint32(p, p_end, data_seg_count);

    version(WASM_ENABLE_BULK_MEMORY) {
    if ((wasm_module.data_seg_count1 != 0)
        && (data_seg_count != wasm_module.data_seg_count1)) {
        set_error_buf(error_buf, error_buf_size,
                      "data count and data section have inconsistent lengths");
        return false;
    }
    }

    if (data_seg_count) {
        wasm_module.data_seg_count = data_seg_count;
        total_size = (WASMDataSeg*).sizeof * cast(uint64)data_seg_count;
        if (!(wasm_module.data_segments = loader_malloc
                    (total_size, error_buf, error_buf_size))) {
            return false;
        }

        for (i = 0; i < data_seg_count; i++) {
            read_leb_uint32(p, p_end, mem_index);
            version(WASM_ENABLE_BULK_MEMORY) {
            is_passive = false;
            mem_flag = mem_index & 0x03;
            switch (mem_flag) {
                case 0x01:
                    is_passive = true;
                    break;
                case 0x00:
                    /* no memory index, treat index as 0 */
                    mem_index = 0;
                    goto check_mem_index;
                case 0x02:
                    /* read following memory index */
                    read_leb_uint32(p, p_end, mem_index);
check_mem_index:
                    if (mem_index
                        >= wasm_module.import_memory_count + wasm_module.memory_count) {
                        LOG_DEBUG("memory#%d does not exist", mem_index);
                        set_error_buf(error_buf, error_buf_size, "unknown memory");
                        return false;
                    }
                    break;
                case 0x03:
                default:
                    set_error_buf(error_buf, error_buf_size, "unknown memory");
                        return false;
                    break;
            }
            }
            else {
            if (mem_index
                >= wasm_module.import_memory_count + wasm_module.memory_count) {
                LOG_DEBUG("memory#%d does not exist", mem_index);
                set_error_buf(error_buf, error_buf_size, "unknown memory");
                return false;
            }
            }
 /* WASM_ENABLE_BULK_MEMORY */

            if (!WASM_ENABLE_BULK_MEMORY || !is_passive)
                if (!load_init_expr(&p, p_end, &init_expr, VALUE_TYPE_I32,
                                    error_buf, error_buf_size))
                    return false;

            read_leb_uint32(p, p_end, data_seg_len);

            if (!(dataseg = wasm_module.data_segments[i] = loader_malloc
                        (sizeof(WASMDataSeg), error_buf, error_buf_size))) {
                return false;
            }

            version(WASM_ENABLE_BULK_MEMORY) {
            dataseg.is_passive = is_passive;
            }
            if (!WASM_ENABLE_BULK_MEMORY || !is_passive)
            {
                bh_memcpy_s(&dataseg.base_offset, sizeof(InitializerExpression),
                            &init_expr, sizeof(InitializerExpression));

                dataseg.memory_index = mem_index;
            }

            dataseg.data_length = data_seg_len;
            mixin(CHECK_BUF!(p, p_end, data_seg_len)());
            dataseg.data = cast(uint8*)p;
            p += data_seg_len;
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load data segment section failed: section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load data segment section success.\n");
    return true;
}

version(WASM_ENABLE_BULK_MEMORY) {
static bool
load_datacount_section(const uint8 *buf, const uint8 *buf_end, WASMModule *wasm_module,
                       char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end;
    uint32 data_seg_count1 = 0;

    read_leb_uint32(p, p_end, data_seg_count1);
    wasm_module.data_seg_count1 = data_seg_count1;

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load datacount section failed: section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load datacount section success.\n");
    return true;
}
}

static bool
load_code_section(const uint8 *buf, const uint8 *buf_end,
                  const uint8 *buf_func,
                  const uint8 *buf_func_end,
                  WASMModule *wasm_module,
                  char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end;
    const uint8 *p_func = buf_func;
    uint32 func_count = 0, code_count;

    /* code has been loaded in function section, so pass it here, just check
     * whether function and code section have inconsistent lengths */
    read_leb_uint32(p, p_end, code_count);

    if (buf_func)
        read_leb_uint32(p_func, buf_func_end, func_count);

    if (func_count != code_count) {
        set_error_buf(error_buf, error_buf_size,
                      "Load code section failed: " ~
                      "function and code section have inconsistent lengths");
        return false;
    }

    LOG_VERBOSE("Load code segment section success.\n");
    return true;
}

static bool
load_start_section(const uint8 *buf, const uint8 *buf_end, WASMModule *wasm_module,
                   char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end;
    WASMType *type;
    uint32 start_function;

    read_leb_uint32(p, p_end, start_function);

    if (start_function
        >= wasm_module.function_count + wasm_module.import_function_count) {
        set_error_buf(error_buf, error_buf_size,
                      "Load start section failed: " ~
                      "unknown function.");
        return false;
    }

    if (start_function < wasm_module.import_function_count)
        type = wasm_module.import_functions[start_function].u.func.func_type;
    else
        type =
          wasm_module.functions[start_function - wasm_module.import_function_count]
            .func_type;
    if (type.param_count != 0 || type.result_count != 0) {
        set_error_buf(error_buf, error_buf_size,
                      "Load start section failed: " ~
                      "invalid start function.");
        return false;
    }

    wasm_module.start_function = start_function;

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load start section failed: section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load start section success.\n");
    return true;
}

static bool
load_user_section(const uint8 *buf, const uint8 *buf_end, WASMModule *wasm_module,
                  char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, p_end = buf_end;
    uint32 name_len;

    if (p >= p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load custom section failed: unexpected end");
        return false;
    }

    read_leb_uint32(p, p_end, name_len);

    if (name_len == 0
        || p + name_len > p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "Load custom section failed: unexpected end");
        return false;
    }

    if (!check_utf8_str(p, name_len)) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: " ~
                      "invalid UTF-8 encoding");
        return false;
    }

    LOG_VERBOSE("Load custom section success.\n");
    return true;
}


static bool
wasm_loader_prepare_bytecode(WASMModule *wasm_module, WASMFunction *func,
                             BlockAddr *block_addr_cache,
                             char *error_buf, uint32 error_buf_size);

// #if WASM_ENABLE_FAST_INTERP != 0
// void **
// wasm_interp_get_handle_table();

// static void **handle_table;
// #endif

static bool
load_from_sections(WASMModule *wasm_module, WASMSection *sections,
                   char *error_buf, uint32 error_buf_size)
{
    WASMExport *wasm_export;
    WASMSection *section = sections;
    const uint8 *buf, buf_end, buf_code = NULL, buf_code_end = NULL,
                buf_func = NULL, buf_func_end = NULL;
    WASMGlobal *llvm_data_end_global = NULL, llvm_heap_base_global = NULL;
    WASMGlobal *llvm_stack_top_global = NULL, global;
    uint32 llvm_data_end = UINT32_MAX, llvm_heap_base = UINT32_MAX;
    uint32 llvm_stack_top = UINT32_MAX, global_index, i;
    uint32 stack_top_global_index = UINT32_MAX;
    BlockAddr *block_addr_cache;
    uint64 total_size;

    /* Find code and function sections if have */
    while (section) {
        if (section.section_type == SECTION_TYPE_CODE) {
            buf_code = section.section_body;
            buf_code_end = buf_code + section.section_body_size;
        }
        else if (section.section_type == SECTION_TYPE_FUNC) {
            buf_func = section.section_body;
            buf_func_end = buf_func + section.section_body_size;
        }
        section = section.next;
    }

    section = sections;
    while (section) {
        buf = section.section_body;
        buf_end = buf + section.section_body_size;
        LOG_DEBUG("to section %d", section.section_type);
        switch (section.section_type) {
            case SECTION_TYPE_USER:
                /* unsupported user section, ignore it. */
                if (!load_user_section(buf, buf_end, wasm_module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_TYPE:
                if (!load_type_section(buf, buf_end, wasm_module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_IMPORT:
                if (!load_import_section(buf, buf_end, wasm_module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_FUNC:
                if (!load_function_section(buf, buf_end, buf_code, buf_code_end,
                            wasm_module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_TABLE:
                if (!load_table_section(buf, buf_end, wasm_module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_MEMORY:
                if (!load_memory_section(buf, buf_end, wasm_module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_GLOBAL:
                if (!load_global_section(buf, buf_end, wasm_module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_EXPORT:
                if (!load_export_section(buf, buf_end, wasm_module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_START:
                if (!load_start_section(buf, buf_end, wasm_module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_ELEM:
                if (!load_table_segment_section(buf, buf_end, wasm_module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_CODE:
                if (!load_code_section(buf, buf_end, buf_func, buf_func_end,
                                       wasm_module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_DATA:
                if (!load_data_segment_section(buf, buf_end, wasm_module, error_buf, error_buf_size))
                    return false;
                break;
                version(WASM_ENABLE_BULK_MEMORY) {
            case SECTION_TYPE_DATACOUNT:
                if (!load_datacount_section(buf, buf_end, wasm_module, error_buf, error_buf_size))
                    return false;
                break;
                }
            default:
                set_error_buf(error_buf, error_buf_size,
                              "WASM module load failed: invalid section id");
                return false;
        }

        section = section.next;
    }

    version(WASM_ENABLE_FAST_INTERP) {
        handle_table = wasm_interp_get_handle_table();
    }

    total_size = BlockAddr.sizeof * cast(uint64)BLOCK_ADDR_CACHE_SIZE * BLOCK_ADDR_CONFLICT_SIZE;
    if (!(block_addr_cache = loader_malloc
                (total_size, error_buf, error_buf_size))) {
        return false;
    }

    for (i = 0; i < wasm_module.function_count; i++) {
        WASMFunction *func = wasm_module.functions[i];
        memset(block_addr_cache, 0, cast(uint32)total_size);
        if (!wasm_loader_prepare_bytecode(wasm_module, func, block_addr_cache,
                                          error_buf, error_buf_size)) {
            wasm_runtime_free(block_addr_cache);
            return false;
        }
    }
    wasm_runtime_free(block_addr_cache);

    /* Resolve llvm auxiliary data/stack/heap info and reset memory info */
    wasm_export = wasm_module.exports;
    for (i = 0; i < wasm_module.export_count; i++, wasm_export++) {
        if (wasm_export.kind == EXPORT_KIND_GLOBAL) {
            if (!strcmp(wasm_export.name, "__heap_base")) {
                global_index = wasm_export.index - wasm_module.import_global_count;
                global = wasm_module.globals + global_index;
                if (global.type == VALUE_TYPE_I32
                    && !global.is_mutable
                    && global.init_expr.init_expr_type ==
                            INIT_EXPR_TYPE_I32_CONST) {
                    llvm_heap_base_global = global;
                    llvm_heap_base = global.init_expr.u.i32;
                    LOG_VERBOSE("found llvm __heap_base global, value: %d\n",
                                llvm_heap_base);
                }
            }
            else if (!strcmp(wasm_export.name, "__data_end")) {
                global_index = wasm_export.index - wasm_module.import_global_count;
                global = wasm_module.globals + global_index;
                if (global.type == VALUE_TYPE_I32
                    && !global.is_mutable
                    && global.init_expr.init_expr_type ==
                            INIT_EXPR_TYPE_I32_CONST) {
                    llvm_data_end_global = global;
                    llvm_data_end = global.init_expr.u.i32;
                    LOG_VERBOSE("found llvm __data_end global, value: %d\n",
                                llvm_data_end);

                    llvm_data_end = align_uint(llvm_data_end, 16);
                }
            }

            /* For module compiled with -pthread option, the global is:
                [0] stack_top       <-- 0
                [1] tls_pointer
                [2] tls_size
                [3] data_end        <-- 3
                [4] global_base
                [5] heap_base       <-- 5
                [6] dso_handle

                For module compiled without -pthread option:
                [0] stack_top       <-- 0
                [1] data_end        <-- 1
                [2] global_base
                [3] heap_base       <-- 3
                [4] dso_handle
            */
            if (llvm_data_end_global && llvm_heap_base_global) {
                /* Resolve aux stack top global */
                for (global_index = 0; global_index < wasm_module.global_count; global_index++) {
                    global = wasm_module.globals + global_index;
                    if (global != llvm_data_end_global
                        && global != llvm_heap_base_global
                        && global.type == VALUE_TYPE_I32
                        && global.is_mutable
                        && global.init_expr.init_expr_type ==
                                    INIT_EXPR_TYPE_I32_CONST
                        && (global.init_expr.u.i32 ==
                                    llvm_heap_base_global.init_expr.u.i32
                            || global.init_expr.u.i32 ==
                                    llvm_data_end_global.init_expr.u.i32)) {
                        llvm_stack_top_global = global;
                        llvm_stack_top = global.init_expr.u.i32;
                        stack_top_global_index = global_index;
                        LOG_VERBOSE("found llvm stack top global, " ~
                                    "value: %d, global index: %d\n",
                                    llvm_stack_top, global_index);
                        break;
                    }
                }

                wasm_module.llvm_aux_data_end = llvm_data_end;
                wasm_module.llvm_aux_stack_bottom = llvm_stack_top;
                wasm_module.llvm_aux_stack_size = llvm_stack_top > llvm_data_end
                                              ? llvm_stack_top - llvm_data_end
                                              : llvm_stack_top;
                wasm_module.llvm_aux_stack_global_index = stack_top_global_index;
                LOG_VERBOSE("aux stack bottom: %d, size: %d\n",
                            wasm_module.llvm_aux_stack_bottom,
                            wasm_module.llvm_aux_stack_size);
                break;
            }
        }
    }

    if (!wasm_module.possible_memory_grow) {
        if (llvm_data_end_global
            && llvm_heap_base_global
            && llvm_stack_top_global
            && llvm_stack_top <= llvm_heap_base) {
            WASMMemoryImport *memory_import;
            WASMMemory *memory;
            uint64 init_memory_size;
            uint32 shrunk_memory_size = llvm_heap_base > llvm_data_end
                                        ? llvm_heap_base : llvm_data_end;
            if (wasm_module.import_memory_count) {
                memory_import = &wasm_module.import_memories[0].u.memory;
                init_memory_size = cast(uint64)memory_import.num_bytes_per_page *
                                   memory_import.init_page_count;
                if (llvm_heap_base <= init_memory_size
                    && llvm_data_end <= init_memory_size) {
                    /* Reset memory info to decrease memory usage */
                    memory_import.num_bytes_per_page = shrunk_memory_size;
                    memory_import.init_page_count = 1;
                    LOG_VERBOSE("reset import memory size to %d\n",
                                shrunk_memory_size);
                }
            }
            if (wasm_module.memory_count) {
                memory = &wasm_module.memories[0];
                init_memory_size = cast(uint64)memory.num_bytes_per_page *
                             memory.init_page_count;
                if (llvm_heap_base <= init_memory_size
                    && llvm_data_end <= init_memory_size) {
                    /* Reset memory info to decrease memory usage */
                    memory.num_bytes_per_page = shrunk_memory_size;
                    memory.init_page_count = 1;
                    LOG_VERBOSE("reset memory size to %d\n", shrunk_memory_size);
                }
            }
        }
    }

    return true;
}

version(BH_ENABLE_MEMORY_PROFILING) {
static void wasm_loader_free(void *ptr)
{
    wasm_runtime_free(ptr);
}
}
else {
alias wasm_loader_free =  wasm_free;
}

static WASMModule*
create_module(char *error_buf, uint32 error_buf_size)
{
    WASMModule *wasm_module = loader_malloc(WASMModule.sizeof,
                                       error_buf, error_buf_size);

    if (!wasm_module) {
        return null;
    }

    wasm_module.module_type = Wasm_Module_Bytecode;

    /* Set start_function to -1, means no start function */
    wasm_module.start_function = cast(uint32)-1;

    version(WASM_ENABLE_MULTI_MODULE) {
        wasm_module.import_module_list = &wasm_module.import_module_list_head;
    }
    return wasm_module;
}

WASMModule*
wasm_loader_load_from_sections(WASMSection *section_list,
                               char* error_buf, uint32 error_buf_size)
{
    WASMModule *wasm_module = create_module(error_buf, error_buf_size);
    if (!wasm_module)
        return null;

    if (!load_from_sections(wasm_module, section_list, error_buf, error_buf_size)) {
        wasm_loader_unload(wasm_module);
        return null;
    }

    LOG_VERBOSE("Load module from sections success.\n");
    return wasm_module;
}

static void
destroy_sections(WASMSection *section_list)
{
    WASMSection *section = section_list, next;
    while (section) {
        next = section.next;
        wasm_runtime_free(section);
        section = next;
    }
}

static uint8[] section_ids = [
    SECTION_TYPE_USER,
    SECTION_TYPE_TYPE,
    SECTION_TYPE_IMPORT,
    SECTION_TYPE_FUNC,
    SECTION_TYPE_TABLE,
    SECTION_TYPE_MEMORY,
    SECTION_TYPE_GLOBAL,
    SECTION_TYPE_EXPORT,
    SECTION_TYPE_START,
    SECTION_TYPE_ELEM,
//    static if(WASM_ENABLE_BULK_MEMORY) {
        SECTION_TYPE_DATACOUNT,
//            }
    SECTION_TYPE_CODE,
    SECTION_TYPE_DATA
];

static uint8
get_section_index(uint8 section_type)
{
    uint8 max_id = sizeof(section_ids) / sizeof(uint8);

    for (uint8 i = 0; i < max_id; i++) {
        if (section_type == section_ids[i])
            return i;
    }

    return (uint8)-1;
}

static bool
create_sections(const uint8 *buf, uint32 size,
                WASMSection **p_section_list,
                char *error_buf, uint32 error_buf_size)
{
    WASMSection *section_list_end = NULL, section;
    const uint8 *p = buf, p_end = buf + size/*, *section_body*/;
    uint8 section_type, section_index, last_section_index = (uint8)-1;
    uint32 section_size;

    bh_assert(!*p_section_list);

    p += 8;
    while (p < p_end) {
        mixin(CHECK_BUF!(p, p_end, 1)());
        section_type = read_uint8(p);
        section_index = get_section_index(section_type);
        if (section_index != (uint8)-1) {
            if (section_type != SECTION_TYPE_USER) {
                /* Custom sections may be inserted at any place,
                   while other sections must occur at most once
                   and in prescribed order. */
                if (last_section_index != (uint8)-1
                    && (section_index <= last_section_index)) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM module load failed: " ~
                                  "junk after last section");
                    return false;
                }
                last_section_index = section_index;
            }
            mixin(CHECK_BUF1!(p, p_end, 1)());
            read_leb_uint32(p, p_end, section_size);
            mixin(CHECK_BUF1!(p, p_end, section_size)());

            if (!(section = loader_malloc(sizeof(WASMSection),
                                          error_buf, error_buf_size))) {
                return false;
            }

            section.section_type = section_type;
            section.section_body = cast(uint8*)p;
            section.section_body_size = section_size;

            if (!*p_section_list)
                *p_section_list = section_list_end = section;
            else {
                section_list_end.next = section;
                section_list_end = section;
            }

            p += section_size;
        }
        else {
            set_error_buf(error_buf, error_buf_size,
                          "WASM module load failed: invalid section id");
            return false;
        }
    }

    return true;
}

static void
exchange32(uint8* p_data)
{
    uint8 value = *p_data;
    *p_data = *(p_data + 3);
    *(p_data + 3) = value;

    value = *(p_data + 1);
    *(p_data + 1) = *(p_data + 2);
    *(p_data + 2) = value;
}

union UE {
    int a;
    char b;
}
UE __ue = { .a = 1 };

bool is_little_endian() {
    return __ue.b == 1;
}

static bool
load(const uint8 *buf, uint32 size, WASMModule *wasm_module,
     char *error_buf, uint32 error_buf_size)
{
    const uint8 *buf_end = buf + size;
    const uint8 *p = buf, p_end = buf_end;
    uint32 magic_number, wasm_version;
    WASMSection *section_list = NULL;

    mixin(CHECK_BUF1!(p, p_end, sizeof(uint32))());
    magic_number = read_uint32(p);
    if (!is_little_endian())
        exchange32(cast(uint8*)&magic_number);

    if (magic_number != WASM_MAGIC_NUMBER) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: magic header not detected");
        return false;
    }

        mixin(CHECK_BUF1!(p, p_end, sizeof(uint32))());
    wasm_version = read_uint32(p);
    if (!is_little_endian())
        exchange32(cast(uint8*)&wasm_version);

    if (wasm_version != WASM_CURRENT_VERSION) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: unknown binary version");
        return false;
    }

    if (!create_sections(buf, size, &section_list, error_buf, error_buf_size)
        || !load_from_sections(wasm_module, section_list, error_buf, error_buf_size)) {
        destroy_sections(section_list);
        return false;
    }

    destroy_sections(section_list);
    return true;
}

WASMModule*
wasm_loader_load(const uint8 *buf, uint32 size, char *error_buf, uint32 error_buf_size)
{
    WASMModule *wasm_module = create_module(error_buf, error_buf_size);
    if (!wasm_module) {
        return NULL;
    }

    if (!load(buf, size, wasm_module, error_buf, error_buf_size)) {
        LOG_VERBOSE("Load module failed, %s", error_buf);
        goto fail;
    }

    LOG_VERBOSE("Load module success");
    return wasm_module;

fail:
    wasm_loader_unload(wasm_module);
    return NULL;
}

void
wasm_loader_unload(WASMModule *wasm_module)
{
    uint32 i;

    if (!wasm_module)
        return;

    if (wasm_module.types) {
        for (i = 0; i < wasm_module.type_count; i++) {
            if (wasm_module.types[i])
                wasm_runtime_free(wasm_module.types[i]);
        }
        wasm_runtime_free(wasm_module.types);
    }

    if (wasm_module.imports)
        wasm_runtime_free(wasm_module.imports);

    if (wasm_module.functions) {
        for (i = 0; i < wasm_module.function_count; i++) {
            if (wasm_module.functions[i]) {
                if (wasm_module.functions[i].local_offsets)
                    wasm_runtime_free(wasm_module.functions[i].local_offsets);
                version(WASM_ENABLE_FAST_INTERP) {
                if (wasm_module.functions[i].code_compiled)
                    wasm_runtime_free(wasm_module.functions[i].code_compiled);
                if (wasm_module.functions[i].consts)
                    wasm_runtime_free(wasm_module.functions[i].consts);
                }
                wasm_runtime_free(wasm_module.functions[i]);
            }
        }
        wasm_runtime_free(wasm_module.functions);
    }

    if (wasm_module.tables)
        wasm_runtime_free(wasm_module.tables);

    if (wasm_module.memories)
        wasm_runtime_free(wasm_module.memories);

    if (wasm_module.globals)
        wasm_runtime_free(wasm_module.globals);

    if (wasm_module.exports)
        wasm_runtime_free(wasm_module.exports);

    if (wasm_module.table_segments) {
        for (i = 0; i < wasm_module.table_seg_count; i++) {
            if (wasm_module.table_segments[i].func_indexes)
                wasm_runtime_free(wasm_module.table_segments[i].func_indexes);
        }
        wasm_runtime_free(wasm_module.table_segments);
    }

    if (wasm_module.data_segments) {
        for (i = 0; i < wasm_module.data_seg_count; i++) {
            if (wasm_module.data_segments[i])
                wasm_runtime_free(wasm_module.data_segments[i]);
        }
        wasm_runtime_free(wasm_module.data_segments);
    }

    if (wasm_module.const_str_list) {
        StringNode *node = wasm_module.const_str_list, node_next;
        while (node) {
            node_next = node.next;
            wasm_runtime_free(node);
            node = node_next;
        }
    }

    version(WASM_ENABLE_MULTI_MODULE) {
    /* just release the sub module list */
    if (wasm_module.import_module_list) {
        WASMRegisteredModule *node =
          bh_list_first_elem(wasm_module.import_module_list);
        while (node) {
            WASMRegisteredModule *next = bh_list_elem_next(node);
            bh_list_remove(wasm_module.import_module_list, node);
            /*
             * unload(sub_module) will be trigged during runtime_destroy().
             * every module in the global module list will be unloaded one by
             * one. so don't worry.
             */
            wasm_runtime_free(node);
            /*
             *
             * the module file reading buffer will be released
             * in runtime_destroy()
             */
            node = next;
        }
    }
    }

    wasm_runtime_free(wasm_module);
}

bool
wasm_loader_find_block_addr(BlockAddr *block_addr_cache,
                            const uint8 *start_addr,
                            const uint8 *code_end_addr,
                            uint8 label_type,
                            uint8 **p_else_addr,
                            uint8 **p_end_addr,
                            char *error_buf,
                            uint32 error_buf_size)
{
    const uint8 *p = start_addr, p_end = code_end_addr;
    uint8 *else_addr;
    uint32 block_nested_depth = 1, count, i, j, t;
    uint8 opcode, u8;
    BlockAddr[16] block_stack;
    BlockAddr* block;

    i = (cast(uintptr_t)start_addr) % BLOCK_ADDR_CACHE_SIZE;
    block = block_addr_cache + BLOCK_ADDR_CONFLICT_SIZE * i;

    for (j = 0; j < BLOCK_ADDR_CONFLICT_SIZE; j++) {
        if (block[j].start_addr == start_addr) {
            /* Cache hit */
            *p_else_addr = block[j].else_addr;
            *p_end_addr = block[j].end_addr;
            return true;
        }
    }

    /* Cache unhit */
    block_stack[0].start_addr = start_addr;

    while (p < code_end_addr) {
        opcode = *p++;

        switch (opcode) {
            case WASM_OP_UNREACHABLE:
            case WASM_OP_NOP:
                break;

            case WASM_OP_BLOCK:
            case WASM_OP_LOOP:
            case WASM_OP_IF:
                mixin(CHECK_BUF!(p, p_end, 1)());
                /* block result type: 0x40/0x7F/0x7E/0x7D/0x7C */
                u8 = read_uint8(p);
                if (block_nested_depth < sizeof(block_stack)/sizeof(BlockAddr)) {
                    block_stack[block_nested_depth].start_addr = p;
                    block_stack[block_nested_depth].else_addr = NULL;
                }
                block_nested_depth++;
                break;

            case EXT_OP_BLOCK:
            case EXT_OP_LOOP:
            case EXT_OP_IF:
                /* block type */
                mixin(skip_leb_uint32!(p, p_end)());
                if (block_nested_depth < sizeof(block_stack)/sizeof(BlockAddr)) {
                    block_stack[block_nested_depth].start_addr = p;
                    block_stack[block_nested_depth].else_addr = NULL;
                }
                block_nested_depth++;
                break;

            case WASM_OP_ELSE:
                if (label_type == LABEL_TYPE_IF && block_nested_depth == 1)
                    else_addr = cast(uint8*)(p - 1);
                if (block_nested_depth - 1 < block_stack.sizeof/BlockAddr.sizeof)
                    block_stack[block_nested_depth - 1].else_addr = cast(uint8*)(p - 1);
                break;

            case WASM_OP_END:
                if (block_nested_depth == 1) {
                    if (label_type == LABEL_TYPE_IF)
                        *p_else_addr = else_addr;
                    *p_end_addr = cast(uint8*)(p - 1);

                    block_stack[0].end_addr = cast(uint8*)(p - 1);
                    for (t = 0; t < block_stack.sizeof/BlockAddr.sizeof; t++) {
                        start_addr = block_stack[t].start_addr;
                        if (start_addr) {
                            i = (cast(uintptr_t)start_addr) % BLOCK_ADDR_CACHE_SIZE;
                            block = block_addr_cache + BLOCK_ADDR_CONFLICT_SIZE * i;
                            for (j = 0; j < BLOCK_ADDR_CONFLICT_SIZE; j++)
                                if (!block[j].start_addr)
                                    break;

                            if (j == BLOCK_ADDR_CONFLICT_SIZE) {
                                memmove(block + 1, block, (BLOCK_ADDR_CONFLICT_SIZE - 1) *
                                                          sizeof(BlockAddr));
                                j = 0;

                            }
                            block[j].start_addr = block_stack[t].start_addr;
                            block[j].else_addr = block_stack[t].else_addr;
                            block[j].end_addr = block_stack[t].end_addr;
                        }
                        else
                            break;
                    }
                    return true;
                }
                else {
                    block_nested_depth--;
                    if (block_nested_depth < sizeof(block_stack)/sizeof(BlockAddr))
                        block_stack[block_nested_depth].end_addr = cast(uint8*)(p - 1);
                }
                break;

            case WASM_OP_BR:
            case WASM_OP_BR_IF:
                skip_leb_uint32(p, p_end); /* labelidx */
                break;

            case WASM_OP_BR_TABLE:
                read_leb_uint32(p, p_end, count); /* lable num */
                for (i = 0; i <= count; i++) /* lableidxs */
                    skip_leb_uint32(p, p_end);
                break;

            case WASM_OP_RETURN:
                break;

            case WASM_OP_CALL:
                skip_leb_uint32(p, p_end); /* funcidx */
                break;

            case WASM_OP_CALL_INDIRECT:
                skip_leb_uint32(p, p_end); /* typeidx */
                mixin(CHECK_BUF!(p, p_end, 1)());
                u8 = read_uint8(p); /* 0x00 */
                break;

            case WASM_OP_DROP:
            case WASM_OP_SELECT:
            case WASM_OP_DROP_64:
            case WASM_OP_SELECT_64:
                break;

            case WASM_OP_GET_LOCAL:
            case WASM_OP_SET_LOCAL:
            case WASM_OP_TEE_LOCAL:
            case WASM_OP_GET_GLOBAL:
            case WASM_OP_SET_GLOBAL:
            case WASM_OP_GET_GLOBAL_64:
            case WASM_OP_SET_GLOBAL_64:
            case WASM_OP_SET_GLOBAL_AUX_STACK:
                skip_leb_uint32(p, p_end); /* localidx */
                break;

            case EXT_OP_GET_LOCAL_FAST:
            case EXT_OP_SET_LOCAL_FAST:
            case EXT_OP_TEE_LOCAL_FAST:
                mixin(CHECK_BUF!(p, p_end, 1)());
                p++;
                break;

            case WASM_OP_I32_LOAD:
            case WASM_OP_I64_LOAD:
            case WASM_OP_F32_LOAD:
            case WASM_OP_F64_LOAD:
            case WASM_OP_I32_LOAD8_S:
            case WASM_OP_I32_LOAD8_U:
            case WASM_OP_I32_LOAD16_S:
            case WASM_OP_I32_LOAD16_U:
            case WASM_OP_I64_LOAD8_S:
            case WASM_OP_I64_LOAD8_U:
            case WASM_OP_I64_LOAD16_S:
            case WASM_OP_I64_LOAD16_U:
            case WASM_OP_I64_LOAD32_S:
            case WASM_OP_I64_LOAD32_U:
            case WASM_OP_I32_STORE:
            case WASM_OP_I64_STORE:
            case WASM_OP_F32_STORE:
            case WASM_OP_F64_STORE:
            case WASM_OP_I32_STORE8:
            case WASM_OP_I32_STORE16:
            case WASM_OP_I64_STORE8:
            case WASM_OP_I64_STORE16:
            case WASM_OP_I64_STORE32:
                skip_leb_uint32(p, p_end); /* align */
                skip_leb_uint32(p, p_end); /* offset */
                break;

            case WASM_OP_MEMORY_SIZE:
            case WASM_OP_MEMORY_GROW:
                skip_leb_uint32(p, p_end); /* 0x00 */
                break;

            case WASM_OP_I32_CONST:
                mixin(skip_leb_int32!(p, p_end)());
                break;
            case WASM_OP_I64_CONST:
                mixin(skip_leb_int64!(p, p_end)());
                break;
            case WASM_OP_F32_CONST:
                p += sizeof(float32);
                break;
            case WASM_OP_F64_CONST:
                p += sizeof(float64);
                break;

            case WASM_OP_I32_EQZ:
            case WASM_OP_I32_EQ:
            case WASM_OP_I32_NE:
            case WASM_OP_I32_LT_S:
            case WASM_OP_I32_LT_U:
            case WASM_OP_I32_GT_S:
            case WASM_OP_I32_GT_U:
            case WASM_OP_I32_LE_S:
            case WASM_OP_I32_LE_U:
            case WASM_OP_I32_GE_S:
            case WASM_OP_I32_GE_U:
            case WASM_OP_I64_EQZ:
            case WASM_OP_I64_EQ:
            case WASM_OP_I64_NE:
            case WASM_OP_I64_LT_S:
            case WASM_OP_I64_LT_U:
            case WASM_OP_I64_GT_S:
            case WASM_OP_I64_GT_U:
            case WASM_OP_I64_LE_S:
            case WASM_OP_I64_LE_U:
            case WASM_OP_I64_GE_S:
            case WASM_OP_I64_GE_U:
            case WASM_OP_F32_EQ:
            case WASM_OP_F32_NE:
            case WASM_OP_F32_LT:
            case WASM_OP_F32_GT:
            case WASM_OP_F32_LE:
            case WASM_OP_F32_GE:
            case WASM_OP_F64_EQ:
            case WASM_OP_F64_NE:
            case WASM_OP_F64_LT:
            case WASM_OP_F64_GT:
            case WASM_OP_F64_LE:
            case WASM_OP_F64_GE:
            case WASM_OP_I32_CLZ:
            case WASM_OP_I32_CTZ:
            case WASM_OP_I32_POPCNT:
            case WASM_OP_I32_ADD:
            case WASM_OP_I32_SUB:
            case WASM_OP_I32_MUL:
            case WASM_OP_I32_DIV_S:
            case WASM_OP_I32_DIV_U:
            case WASM_OP_I32_REM_S:
            case WASM_OP_I32_REM_U:
            case WASM_OP_I32_AND:
            case WASM_OP_I32_OR:
            case WASM_OP_I32_XOR:
            case WASM_OP_I32_SHL:
            case WASM_OP_I32_SHR_S:
            case WASM_OP_I32_SHR_U:
            case WASM_OP_I32_ROTL:
            case WASM_OP_I32_ROTR:
            case WASM_OP_I64_CLZ:
            case WASM_OP_I64_CTZ:
            case WASM_OP_I64_POPCNT:
            case WASM_OP_I64_ADD:
            case WASM_OP_I64_SUB:
            case WASM_OP_I64_MUL:
            case WASM_OP_I64_DIV_S:
            case WASM_OP_I64_DIV_U:
            case WASM_OP_I64_REM_S:
            case WASM_OP_I64_REM_U:
            case WASM_OP_I64_AND:
            case WASM_OP_I64_OR:
            case WASM_OP_I64_XOR:
            case WASM_OP_I64_SHL:
            case WASM_OP_I64_SHR_S:
            case WASM_OP_I64_SHR_U:
            case WASM_OP_I64_ROTL:
            case WASM_OP_I64_ROTR:
            case WASM_OP_F32_ABS:
            case WASM_OP_F32_NEG:
            case WASM_OP_F32_CEIL:
            case WASM_OP_F32_FLOOR:
            case WASM_OP_F32_TRUNC:
            case WASM_OP_F32_NEAREST:
            case WASM_OP_F32_SQRT:
            case WASM_OP_F32_ADD:
            case WASM_OP_F32_SUB:
            case WASM_OP_F32_MUL:
            case WASM_OP_F32_DIV:
            case WASM_OP_F32_MIN:
            case WASM_OP_F32_MAX:
            case WASM_OP_F32_COPYSIGN:
            case WASM_OP_F64_ABS:
            case WASM_OP_F64_NEG:
            case WASM_OP_F64_CEIL:
            case WASM_OP_F64_FLOOR:
            case WASM_OP_F64_TRUNC:
            case WASM_OP_F64_NEAREST:
            case WASM_OP_F64_SQRT:
            case WASM_OP_F64_ADD:
            case WASM_OP_F64_SUB:
            case WASM_OP_F64_MUL:
            case WASM_OP_F64_DIV:
            case WASM_OP_F64_MIN:
            case WASM_OP_F64_MAX:
            case WASM_OP_F64_COPYSIGN:
            case WASM_OP_I32_WRAP_I64:
            case WASM_OP_I32_TRUNC_S_F32:
            case WASM_OP_I32_TRUNC_U_F32:
            case WASM_OP_I32_TRUNC_S_F64:
            case WASM_OP_I32_TRUNC_U_F64:
            case WASM_OP_I64_EXTEND_S_I32:
            case WASM_OP_I64_EXTEND_U_I32:
            case WASM_OP_I64_TRUNC_S_F32:
            case WASM_OP_I64_TRUNC_U_F32:
            case WASM_OP_I64_TRUNC_S_F64:
            case WASM_OP_I64_TRUNC_U_F64:
            case WASM_OP_F32_CONVERT_S_I32:
            case WASM_OP_F32_CONVERT_U_I32:
            case WASM_OP_F32_CONVERT_S_I64:
            case WASM_OP_F32_CONVERT_U_I64:
            case WASM_OP_F32_DEMOTE_F64:
            case WASM_OP_F64_CONVERT_S_I32:
            case WASM_OP_F64_CONVERT_U_I32:
            case WASM_OP_F64_CONVERT_S_I64:
            case WASM_OP_F64_CONVERT_U_I64:
            case WASM_OP_F64_PROMOTE_F32:
            case WASM_OP_I32_REINTERPRET_F32:
            case WASM_OP_I64_REINTERPRET_F64:
            case WASM_OP_F32_REINTERPRET_I32:
            case WASM_OP_F64_REINTERPRET_I64:
            case WASM_OP_I32_EXTEND8_S:
            case WASM_OP_I32_EXTEND16_S:
            case WASM_OP_I64_EXTEND8_S:
            case WASM_OP_I64_EXTEND16_S:
            case WASM_OP_I64_EXTEND32_S:
                break;
            case WASM_OP_MISC_PREFIX:
            {
                opcode = read_uint8(p);
                switch (opcode) {
                    case WASM_OP_I32_TRUNC_SAT_S_F32:
                    case WASM_OP_I32_TRUNC_SAT_U_F32:
                    case WASM_OP_I32_TRUNC_SAT_S_F64:
                    case WASM_OP_I32_TRUNC_SAT_U_F64:
                    case WASM_OP_I64_TRUNC_SAT_S_F32:
                    case WASM_OP_I64_TRUNC_SAT_U_F32:
                    case WASM_OP_I64_TRUNC_SAT_S_F64:
                    case WASM_OP_I64_TRUNC_SAT_U_F64:
                        break;
                        static if (WASM_ENABLE_BULK_MEMORY) {
                    case WASM_OP_MEMORY_INIT:
                        skip_leb_uint32(p, p_end);
                        /* skip memory idx */
                        p++;

                        break;
                    case WASM_OP_DATA_DROP:
                        skip_leb_uint32(p, p_end);
                        break;
                    case WASM_OP_MEMORY_COPY:
                        /* skip two memory idx */
                        p += 2;
                        break;
                    case WASM_OP_MEMORY_FILL:
                        /* skip memory idx */
                        p++;
                        break;
                        }
                    default:
                        if (error_buf)
                            snprintf(error_buf, error_buf_size,
                                    "WASM loader find block addr failed: " ~
                                    "invalid opcode fc %02x.", opcode);
                        return false;
                }
                break;
            }

            default:
                if (error_buf)
                    snprintf(error_buf, error_buf_size,
                             "WASM loader find block addr failed: " ~
                             "invalid opcode %02x.", opcode);
                return false;
        }
    }

//    (void)u8;
    return false;
}

enum REF_I32   = VALUE_TYPE_I32;
enum REF_F32   = VALUE_TYPE_F32;
enum REF_I64_1 = VALUE_TYPE_I64;
enum REF_I64_2 = VALUE_TYPE_I64;
enum REF_F64_1 = VALUE_TYPE_F64;
enum REF_F64_2 = VALUE_TYPE_F64;
enum REF_ANY   = VALUE_TYPE_ANY;

version(WASM_ENABLE_FAST_INTERP) {

    version(WASM_DEBUG_PREPROCESSOR) {
        alias LOG_OP =      os_printf;
    }
    else {
        void LOG_OP(Args...)(Args args) {
            //empty
        }
    }

    enum PATCH_ELSE = 0;
    enum PATCH_END  = 1;
    struct BranchBlockPatch {
        BranchBlockPatch *next;
        uint8 patch_type;
        uint8 *code_compiled;
    }
}

struct BranchBlock {
    uint8 label_type;
    BlockType block_type;
    uint8 *start_addr;
    uint8 *else_addr;
    uint8 *end_addr;
    uint32 stack_cell_num;
    static if (WASM_ENABLE_FAST_INTERP) {
    uint16 dynamic_offset;
    uint8 *code_compiled;
    BranchBlockPatch *patch_list;
    /* This is used to save params frame_offset of of if block */
    int16 *param_frame_offsets;
    }

    /* Indicate the operand stack is in polymorphic state.
     * If the opcode is one of unreachable/br/br_table/return, stack is marked
     * to polymorphic state until the block's 'end' opcode is processed.
     * If stack is in polymorphic state and stack is empty, instruction can
     * pop any type of value directly without decreasing stack top pointer
     * and stack cell num. */
    bool is_stack_polymorphic;
};

struct WASMLoaderContext {
    /* frame ref stack */
    uint8 *frame_ref;
    uint8 *frame_ref_bottom;
    uint8 *frame_ref_boundary;
    uint32 frame_ref_size;
    uint32 stack_cell_num;
    uint32 max_stack_cell_num;

    /* frame csp stack */
    BranchBlock *frame_csp;
    BranchBlock *frame_csp_bottom;
    BranchBlock *frame_csp_boundary;
    uint32 frame_csp_size;
    uint32 csp_num;
    uint32 max_csp_num;

    static if (WASM_ENABLE_FAST_INTERP) {
    /* frame offset stack */
    int16 *frame_offset;
    int16 *frame_offset_bottom;
    int16 *frame_offset_boundary;
    uint32 frame_offset_size;
    int16 dynamic_offset;
    int16 start_dynamic_offset;
    int16 max_dynamic_offset;

    /* preserved local offset */
    int16 preserved_local_offset;

    /* const buffer */
    uint8 *const_buf;
    uint16 num_const;
    uint16 const_buf_size;
    uint16 const_cell_num;

    /* processed code */
    uint8 *p_code_compiled;
    uint8 *p_code_compiled_end;
    uint32 code_compiled_size;
    }
}

struct Const {
    WASMValue value;
    uint16 slot_index;
    uint8 value_type;
}

static void*
memory_realloc(void *mem_old, uint32 size_old, uint32 size_new,
               char *error_buf, uint32 error_buf_size)
{
    uint8 *mem_new;
    bh_assert(size_new > size_old);
    if ((mem_new = loader_malloc
                (size_new, error_buf, error_buf_size))) {
        bh_memcpy_s(mem_new, size_new, mem_old, size_old);
        memset(mem_new + size_old, 0, size_new - size_old);
        wasm_runtime_free(mem_old);
    }
    return mem_new;
}

string MEM_REALLOC(alias mem, alias size_old, alias size_new)() {
    return format!q{
        void* mem_new = memory_realloc(%1$s, %2$s, %3$s,
                                   error_buf, error_buf_size);
        if (!mem_new) {
            goto fail;
        }
        %1$s = mem_new;
    }(mem.stringof, size_old.stringof, size_new.stringof);
}

string CHECK_CSP_PUSH() {
    return q{
    if (ctx.frame_csp >= ctx.frame_csp_boundary) {
        mixin(MEM_REALLOC!(ctx.frame_csp_bottom, ctx.frame_csp_size,
                  cast(uint32)(ctx.frame_csp_size
                      + 8 * BranchBlock.sizeof))());
      ctx.frame_csp_size += cast(uint32)(8 * BranchBlock.sizeof);
      ctx.frame_csp_boundary = ctx.frame_csp_bottom +
                    ctx.frame_csp_size / BranchBlock.sizeof;
      ctx.frame_csp = ctx.frame_csp_bottom + ctx.csp_num;
    }};
}

enum CHECK_CSP_POP = q{
    if (ctx.csp_num < 1) {
        set_error_buf(error_buf, error_buf_size,
            "WASM module load failed: type mismatch: " ~
            "expect data but block stack was empty");
        goto fail;
    }
};

version(WASM_ENABLE_FAST_INTERP) {
static bool
check_offset_push(WASMLoaderContext *ctx,
                  char *error_buf, uint32 error_buf_size)
{
    uint32 cell_num = (ctx.frame_offset - ctx.frame_offset_bottom);
    if (ctx.frame_offset >= ctx.frame_offset_boundary) {
        mixin(MEM_REALLOC!(ctx.frame_offset_bottom, ctx.frame_offset_size,
                ctx.frame_offset_size + 16)());
        ctx.frame_offset_size += 16;
        ctx.frame_offset_boundary = ctx.frame_offset_bottom +
                    ctx.frame_offset_size / sizeof(int16);
        ctx.frame_offset = ctx.frame_offset_bottom + cell_num;
    }
    return true;
fail:
    return false;
}

static bool
check_offset_pop(WASMLoaderContext *ctx, uint32 cells)
{
    if (ctx.frame_offset - cells < ctx.frame_offset_bottom)
        return false;
    return true;
}

static void
free_label_patch_list(BranchBlock *frame_csp)
{
    BranchBlockPatch *label_patch = frame_csp.patch_list;
    BranchBlockPatch *next;
    while (label_patch != NULL) {
        next = label_patch.next;
        wasm_runtime_free(label_patch);
        label_patch = next;
    }
    frame_csp.patch_list = NULL;
}

static void
free_all_label_patch_lists(BranchBlock *frame_csp, uint32 csp_num)
{
    BranchBlock *tmp_csp = frame_csp;

    for (uint32 i = 0; i < csp_num; i++) {
        free_label_patch_list(tmp_csp);
        tmp_csp ++;
    }
}

}

static bool
check_stack_push(WASMLoaderContext *ctx,
                 char *error_buf, uint32 error_buf_size)
{
    if (ctx.frame_ref >= ctx.frame_ref_boundary) {
        mixin(MEM_REALLOC!(ctx.frame_ref_bottom, ctx.frame_ref_size,
                ctx.frame_ref_size + 16)());
        ctx.frame_ref_size += 16;
        ctx.frame_ref_boundary = ctx.frame_ref_bottom + ctx.frame_ref_size;
        ctx.frame_ref = ctx.frame_ref_bottom + ctx.stack_cell_num;
    }
    return true;
fail:
    return false;
}


static bool
check_stack_top_values(uint8 *frame_ref, int32 stack_cell_num, uint8 type,
                       char *error_buf, uint32 error_buf_size)
{
    char*[] type_str = [ "f64", "f32", "i64", "i32" ];

    if (((type == VALUE_TYPE_I32 || type == VALUE_TYPE_F32)
         && stack_cell_num < 1)
        || ((type == VALUE_TYPE_I64 || type == VALUE_TYPE_F64)
            && stack_cell_num < 2)) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: " ~
                      "type mismatch: expect data but stack was empty");
        return false;
    }

    if ((type == VALUE_TYPE_I32 && *(frame_ref - 1) != REF_I32)
        || (type == VALUE_TYPE_F32 && *(frame_ref - 1) != REF_F32)
        || (type == VALUE_TYPE_I64
            && (*(frame_ref - 2) != REF_I64_1
                || *(frame_ref - 1) != REF_I64_2))
        || (type == VALUE_TYPE_F64
            && (*(frame_ref - 2) != REF_F64_1
                || *(frame_ref - 1) != REF_F64_2))) {
        if (error_buf != NULL)
            snprintf(error_buf, error_buf_size, "%s%s%s",
                     "WASM module load failed: type mismatch: expect ",
                     type_str[type - VALUE_TYPE_F64], " but got other");
        return false;
    }

    return true;
}

static bool
check_stack_pop(WASMLoaderContext *ctx, uint8 type,
                char *error_buf, uint32 error_buf_size)
{
    int32 block_stack_cell_num = cast(int32)
        (ctx.stack_cell_num - (ctx.frame_csp - 1).stack_cell_num);

    if (block_stack_cell_num > 0
        && *(ctx.frame_ref - 1) == VALUE_TYPE_ANY) {
        /* the stack top is a value of any type, return success */
        return true;
    }

    if (!check_stack_top_values(ctx.frame_ref, block_stack_cell_num,
                                type, error_buf, error_buf_size))
        return false;

    return true;
}

static void
wasm_loader_ctx_destroy(WASMLoaderContext *ctx)
{
    if (ctx) {
        if (ctx.frame_ref_bottom)
            wasm_runtime_free(ctx.frame_ref_bottom);
        if (ctx.frame_csp_bottom) {
            version(WASM_ENABLE_FAST_INTERP) {
            free_all_label_patch_lists(ctx.frame_csp_bottom, ctx.csp_num);
            }
            wasm_runtime_free(ctx.frame_csp_bottom);
        }
        version(WASM_ENABLE_FAST_INTERP) {
        if (ctx.frame_offset_bottom)
            wasm_runtime_free(ctx.frame_offset_bottom);
        if (ctx.const_buf)
            wasm_runtime_free(ctx.const_buf);
        }
        wasm_runtime_free(ctx);
    }
}

static WASMLoaderContext*
wasm_loader_ctx_init(WASMFunction *func)
{
    WASMLoaderContext *loader_ctx =
        wasm_runtime_malloc(sizeof(WASMLoaderContext));
    if (!loader_ctx)
        return false;
    memset(loader_ctx, 0, sizeof(WASMLoaderContext));

    loader_ctx.frame_ref_size = 32;
    if (!(loader_ctx.frame_ref_bottom = loader_ctx.frame_ref =
            wasm_runtime_malloc(loader_ctx.frame_ref_size)))
        goto fail;
    memset(loader_ctx.frame_ref_bottom, 0, loader_ctx.frame_ref_size);
    loader_ctx.frame_ref_boundary = loader_ctx.frame_ref_bottom +
                                        loader_ctx.frame_ref_size;

    loader_ctx.frame_csp_size = BranchBlock.sizeof * 8;
    if (!(loader_ctx.frame_csp_bottom = loader_ctx.frame_csp =
            wasm_runtime_malloc(loader_ctx.frame_csp_size)))
        goto fail;
    memset(loader_ctx.frame_csp_bottom, 0, loader_ctx.frame_csp_size);
    loader_ctx.frame_csp_boundary = loader_ctx.frame_csp_bottom + 8;

    version(WASM_ENABLE_FAST_INTERP) {
        loader_ctx.frame_offset_size = int16.sizeof * 32;
    if (!(loader_ctx.frame_offset_bottom = loader_ctx.frame_offset =
            wasm_runtime_malloc(loader_ctx.frame_offset_size)))
        goto fail;
    memset(loader_ctx.frame_offset_bottom, 0,
           loader_ctx.frame_offset_size);
    loader_ctx.frame_offset_boundary = loader_ctx.frame_offset_bottom + 32;

    loader_ctx.num_const = 0;
    loader_ctx.const_buf_size = sizeof(Const) * 8;
    if (!(loader_ctx.const_buf = wasm_runtime_malloc(loader_ctx.const_buf_size)))
        goto fail;
    memset(loader_ctx.const_buf, 0, loader_ctx.const_buf_size);

    loader_ctx.start_dynamic_offset = loader_ctx.dynamic_offset =
        loader_ctx.max_dynamic_offset = func.param_cell_num +
                                            func.local_cell_num;
    }
    return loader_ctx;

fail:
    wasm_loader_ctx_destroy(loader_ctx);
    return NULL;
}

static bool
wasm_loader_push_frame_ref(WASMLoaderContext *ctx, uint8 type,
                           char *error_buf, uint32 error_buf_size)
{
    if (type == VALUE_TYPE_VOID)
        return true;

    if (!check_stack_push(ctx, error_buf, error_buf_size))
        return false;

    *ctx.frame_ref++ = type;
    ctx.stack_cell_num++;
    if (ctx.stack_cell_num > ctx.max_stack_cell_num)
        ctx.max_stack_cell_num = ctx.stack_cell_num;

    if (type == VALUE_TYPE_I32
        || type == VALUE_TYPE_F32
        || type == VALUE_TYPE_ANY)
        return true;

    if (!check_stack_push(ctx, error_buf, error_buf_size))
        return false;
    *ctx.frame_ref++ = type;
    ctx.stack_cell_num++;
    if (ctx.stack_cell_num > ctx.max_stack_cell_num)
        ctx.max_stack_cell_num = ctx.stack_cell_num;
    return true;
}

static bool
wasm_loader_pop_frame_ref(WASMLoaderContext *ctx, uint8 type,
                          char *error_buf, uint32 error_buf_size)
{
    BranchBlock *cur_block = ctx.frame_csp - 1;
    int32 available_stack_cell = cast(int32)
        (ctx.stack_cell_num - cur_block.stack_cell_num);

    /* Directly return success if current block is in stack
     * polymorphic state while stack is empty. */
    if (available_stack_cell <= 0 && cur_block.is_stack_polymorphic)
        return true;

    if (type == VALUE_TYPE_VOID)
        return true;

    if (!check_stack_pop(ctx, type, error_buf, error_buf_size))
        return false;

    ctx.frame_ref--;
    ctx.stack_cell_num--;

    if (type == VALUE_TYPE_I32
        || type == VALUE_TYPE_F32
        || *ctx.frame_ref == VALUE_TYPE_ANY)
        return true;

    ctx.frame_ref--;
    ctx.stack_cell_num--;
    return true;
}

static bool
wasm_loader_push_pop_frame_ref(WASMLoaderContext *ctx, uint8 pop_cnt,
                               uint8 type_push, uint8 type_pop,
                               char *error_buf, uint32 error_buf_size)
{
    for (int i = 0; i < pop_cnt; i++) {
        if (!wasm_loader_pop_frame_ref(ctx, type_pop, error_buf, error_buf_size))
            return false;
    }
    if (!wasm_loader_push_frame_ref(ctx, type_push, error_buf, error_buf_size))
        return false;
    return true;
}

static bool
wasm_loader_push_frame_csp(WASMLoaderContext *ctx, uint8 label_type,
                           BlockType block_type, uint8* start_addr,
                           char *error_buf, uint32 error_buf_size)
{
    mixin(CHECK_CSP_PUSH());
    memset(ctx.frame_csp, 0, sizeof(BranchBlock));
    ctx.frame_csp.label_type = label_type;
    ctx.frame_csp.block_type = block_type;
    ctx.frame_csp.start_addr = start_addr;
    ctx.frame_csp.stack_cell_num = ctx.stack_cell_num;
    version(WASM_ENABLE_FAST_INTERP) {
    ctx.frame_csp.dynamic_offset = ctx.dynamic_offset;
    ctx.frame_csp.patch_list = NULL;
    }
    ctx.frame_csp++;
    ctx.csp_num++;
    if (ctx.csp_num > ctx.max_csp_num)
        ctx.max_csp_num = ctx.csp_num;
    return true;
fail:
    return false;
}

static bool
wasm_loader_pop_frame_csp(WASMLoaderContext *ctx,
                          char *error_buf, uint32 error_buf_size)
{
    mixin(CHECK_CSP_POP);
    version(WASM_ENABLE_FAST_INTERP) {
    if ((ctx.frame_csp - 1).param_frame_offsets)
        wasm_runtime_free((ctx.frame_csp - 1).param_frame_offsets);
    }
    ctx.frame_csp--;
    ctx.csp_num--;

    return true;
fail:
    return false;
}

version(WASM_ENABLE_FAST_INTERP) {

    version(WASM_ENABLE_ABS_LABEL_ADDR) {

        string emit_label(alias opcode)() {
            return format!q{
                wasm_loader_emit_ptr(loader_ctx, handle_table[%1$s]);
                LOG_OP("\nemit_op [%02x]\t", %1$s);
            }(opcode.stringof);
        }

    enum skip_label = q{
        wasm_loader_emit_backspace(loader_ctx, sizeof(void *));
        LOG_OP("\ndelete last op\n");
    };
}
else {

    string emit_label(alias opcode)() {
        return format!q{
            int32 offset = cast(int32)(handle_table[%1$s] - handle_table[0]);
            if (!(offset >= INT16_MIN && offset < INT16_MAX)) {
                set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: " ~
                      "pre-compiled label offset out of range");
                goto fail;
            }
            wasm_loader_emit_int16(loader_ctx, offset);
            LOG_OP("\nemit_op [%02x]\t", %1$s);
        }(opcode.stringof);
    }

// drop local.get / const / block / loop / end
    enum skip_label = q{
        wasm_loader_emit_backspace(loader_ctx, int16.sizeof);
        LOG_OP("\ndelete last op\n");
    };
}

string emit_empty_label_addr_and_frame_ip(alias type)() {
    return format!q{
        if (!add_label_patch_to_list(loader_ctx.frame_csp - 1, %1$s,
                loader_ctx.p_code_compiled,
                error_buf, error_buf_size))
            goto fail;
        /* label address, to be patched */
        wasm_loader_emit_ptr(loader_ctx, null);
    }(type.stringof);
}


string emit_br_info(alias frame_csp)() {
    return format!q{
        if (!wasm_loader_emit_br_info(loader_ctx, frame_csp,
                error_buf, error_buf_size))
            goto fail;
    }(frame_csp.stringof);
}

bool LAST_OP_OUTPUT_I32(const uint8 last_op) {
    return (last_op >= WASM_OP_I32_EQZ
    && last_op <= WASM_OP_I32_ROTR)
    || (last_op == WASM_OP_I32_LOAD
        || last_op == WASM_OP_F32_LOAD)
    || (last_op >= WASM_OP_I32_LOAD8_S
        && last_op <= WASM_OP_I32_LOAD16_U)
    || (last_op >= WASM_OP_F32_ABS
        && last_op <= WASM_OP_F32_COPYSIGN)
    || (last_op >= WASM_OP_I32_WRAP_I64
        && last_op <= WASM_OP_I32_TRUNC_U_F64)
    || (last_op >= WASM_OP_F32_CONVERT_S_I32
        && last_op <= WASM_OP_F32_DEMOTE_F64)
    || (last_op == WASM_OP_I32_REINTERPRET_F32)
    || (last_op == WASM_OP_F32_REINTERPRET_I32)
    || (last_op == EXT_OP_COPY_STACK_TOP);
}

bool LAST_OP_OUTPUT_I64(const uint8 last_op) {
    return (last_op >= WASM_OP_I64_CLZ
        && last_op <= WASM_OP_I64_ROTR)
        || (last_op >= WASM_OP_F64_ABS
            && last_op <= WASM_OP_F64_COPYSIGN)
        || (last_op == WASM_OP_I64_LOAD
            || last_op == WASM_OP_F64_LOAD)
        || (last_op >= WASM_OP_I64_LOAD8_S
            && last_op <= WASM_OP_I64_LOAD32_U)
        || (last_op >= WASM_OP_I64_EXTEND_S_I32
            && last_op <= WASM_OP_I64_TRUNC_U_F64)
        || (last_op >= WASM_OP_F64_CONVERT_S_I32
            && last_op <= WASM_OP_F64_PROMOTE_F32)
        || (last_op == WASM_OP_I64_REINTERPRET_F64)
        || (last_op == WASM_OP_F64_REINTERPRET_I64)
        || (last_op == EXT_OP_COPY_STACK_TOP_I64);
}

string GET_CONST_OFFSET(alias type, alias val)() {                                return format!q{
        if (!(wasm_loader_get_const_offset(loader_ctx, %1$s,
                    &%1$s, &operand_offset,
                    error_buf, error_buf_size)))
            goto fail;
    }(type.stringof, val.stringof);
}

string GET_CONST_F32_OFFSET(alias type, alias fval)()  {
    return format!q{
        if (!(wasm_loader_get_const_offset(loader_ctx, %1$s,
                    &%2$s, &operand_offset,
                    error_buf, error_buf_size)))
            goto fail;
    };
}

string GET_CONST_F64_OFFSET(alias type, alias fval)() {
    return format!q{
        if (!(wasm_loader_get_const_offset(loader_ctx, %1$s,
                    &%2$s, &operand_offset,
                    error_buf, error_buf_size)))
        goto fail;
    }(type.stringof, fval.stringof);
}

string emit_operand(alias ctx, alias offset)() {
    return format!q{
        wasm_loader_emit_int16(%1$s, %2$s);
        LOG_OP("%d\t", %1$s);
    }(ctx.stringof, offset.stringof);
}

string emit_byte(alias ctx, alias _byte)() {
    return format!q{
        wasm_loader_emit_uint8(%1$s, %2$s);
        LOG_OP("%d\t", %2$s);
    }(ctx.stringof, _byte.stringof);
}

string emit_uint32(alias ctx, alias value)()  {
    return format!q{
        wasm_loader_emit_uint32(%1$s, %2$s);
        LOG_OP("%d\t", %2$s);
    }(ctx.stringof, value.stringof);
}

enum emit_leb = q{
    wasm_loader_emit_leb(loader_ctx, p_org, p);
};

static bool
wasm_loader_ctx_reinit(WASMLoaderContext *ctx)
{
    if (!(ctx.p_code_compiled = wasm_runtime_malloc(ctx.code_compiled_size)))
        return false;
    memset(ctx.p_code_compiled, 0, ctx.code_compiled_size);
    ctx.p_code_compiled_end = ctx.p_code_compiled +
                                    ctx.code_compiled_size;

    /* clean up frame ref */
    memset(ctx.frame_ref_bottom, 0, ctx.frame_ref_size);
    ctx.frame_ref = ctx.frame_ref_bottom;
    ctx.stack_cell_num = 0;

    /* clean up frame csp */
    memset(ctx.frame_csp_bottom, 0, ctx.frame_csp_size);
    ctx.frame_csp = ctx.frame_csp_bottom;
    ctx.csp_num = 0;
    ctx.max_csp_num = 0;

    /* clean up frame offset */
    memset(ctx.frame_offset_bottom, 0, ctx.frame_offset_size);
    ctx.frame_offset = ctx.frame_offset_bottom;
    ctx.dynamic_offset = ctx.start_dynamic_offset;

    /* init preserved local offsets */
    ctx.preserved_local_offset = ctx.max_dynamic_offset;

    /* const buf is reserved */
    return true;
}

static void
wasm_loader_emit_uint32(WASMLoaderContext *ctx, uint32 value)
{
    if (ctx.p_code_compiled) {
        *cast(uint32*)(ctx.p_code_compiled) = value;
        ctx.p_code_compiled += uint32.sizeof;
    }
    else
        ctx.code_compiled_size += sizeof(uint32);
}

static void
wasm_loader_emit_int16(WASMLoaderContext *ctx, int16 value)
{
    if (ctx.p_code_compiled) {
        *cast(int16*)(ctx.p_code_compiled) = value;
        ctx.p_code_compiled += sizeof(int16);
    }
    else
        ctx.code_compiled_size += sizeof(int16);
}

static void
wasm_loader_emit_uint8(WASMLoaderContext *ctx, uint8 value)
{
    if (ctx.p_code_compiled) {
        *(ctx.p_code_compiled) = value;
        ctx.p_code_compiled += sizeof(uint8);
    }
    else
        ctx.code_compiled_size += sizeof(uint8);
}

static void
wasm_loader_emit_ptr(WASMLoaderContext *ctx, void *value)
{
    if (ctx.p_code_compiled) {
        *cast(uint8**)(ctx.p_code_compiled) = value;
        ctx.p_code_compiled += (void*).sizeof;
    }
    else {
        ctx.code_compiled_size += (void*).sizeof;
    }
}

static void
wasm_loader_emit_backspace(WASMLoaderContext *ctx, uint32 size)
{
    if (ctx.p_code_compiled) {
        ctx.p_code_compiled -= size;
    }
    else
        ctx.code_compiled_size -= size;
}

static void
wasm_loader_emit_leb(WASMLoaderContext *ctx, uint8* start, uint8* end)
{
    if (ctx.p_code_compiled) {
        bh_memcpy_s(ctx.p_code_compiled,
                    ctx.p_code_compiled_end - ctx.p_code_compiled,
                    start, end - start);
        ctx.p_code_compiled += (end - start);
    }
    else {
        ctx.code_compiled_size += (end - start);
    }

}

static bool
preserve_referenced_local(WASMLoaderContext *loader_ctx, uint8 opcode,
                          uint32 local_index, uint32 local_type, bool *preserved,
                          char *error_buf, uint32 error_buf_size)
{
    int16 preserved_offset = cast(int16)local_index;
    *preserved = false;
    for (uint32 i = 0; i < loader_ctx.stack_cell_num; i++) {
        /* move previous local into dynamic space before a set/tee_local opcode */
        if (loader_ctx.frame_offset_bottom[i] == cast(int16)local_index) {
            if (preserved_offset == cast(int16)local_index) {
                *preserved = true;
                mixin(skip_label);
                if (local_type == VALUE_TYPE_I32
                    || local_type == VALUE_TYPE_F32) {
                    preserved_offset = loader_ctx.preserved_local_offset;
                    /* Only increase preserve offset in the second traversal */
                    if (loader_ctx.p_code_compiled)
                        loader_ctx.preserved_local_offset++;
                    mixin(emit_label!(EXT_OP_COPY_STACK_TOP)());
                }
                else {
                    preserved_offset = loader_ctx.preserved_local_offset;
                    if (loader_ctx.p_code_compiled)
                        loader_ctx.preserved_local_offset += 2;
                    mixin(emit_label!(EXT_OP_COPY_STACK_TOP_I64)());
                }
                mixin(emit_operand!(loader_ctx, local_index)());
                mixin(emit_operand!(loader_ctx, preserved_offset)());
                mixin(emit_label!(opcode)());
            }
            loader_ctx.frame_offset_bottom[i] = preserved_offset;
        }
    }

    return true;

    version(WASM_ENABLE_ABS_LABEL_ADDR) {
fail:
    return false;
    }
}

static bool
add_label_patch_to_list(BranchBlock *frame_csp,
                        uint8 patch_type, uint8 *p_code_compiled,
                        char *error_buf, uint32 error_buf_size)
{
    BranchBlockPatch *patch = loader_malloc
        (sizeof(BranchBlockPatch), error_buf, error_buf_size);
    if (!patch) {
        return false;
    }
    patch.patch_type = patch_type;
    patch.code_compiled = p_code_compiled;
    if (!frame_csp.patch_list) {
        frame_csp.patch_list = patch;
        patch.next = NULL;
    }
    else {
        patch.next = frame_csp.patch_list;
        frame_csp.patch_list = patch;
    }
    return true;
}

static void
apply_label_patch(WASMLoaderContext *ctx, uint8 depth,
                  uint8 patch_type)
{
    BranchBlock *frame_csp = ctx.frame_csp - depth;
    BranchBlockPatch *node = frame_csp.patch_list;
    BranchBlockPatch *node_prev = NULL, node_next;

    if (!ctx.p_code_compiled)
        return;

    while (node) {
        node_next = node.next;
        if (node.patch_type == patch_type) {
            *(cast(uint8**)node.code_compiled) = ctx.p_code_compiled;
            if (node_prev == null) {
                frame_csp.patch_list = node_next;
            }
            else {
                node_prev.next = node_next;
            }
            wasm_runtime_free(node);
        }
        else {
            node_prev = node;
        }
        node = node_next;
    }
}

static bool
wasm_loader_emit_br_info(WASMLoaderContext *ctx, BranchBlock *frame_csp,
                         char *error_buf, uint32 error_buf_size)
{
    /* br info layout:
     *  a) arity of target block
     *  b) total cell num of arity values
     *  c) each arity value's cell num
     *  d) each arity value's src frame offset
     *  e) each arity values's dst dynamic offset
     *  f) branch target address
     *
     *  Note: b-e are omitted when arity is 0 so that
     *  interpreter can recover the br info quickly.
     */
    BlockType *block_type = &frame_csp.block_type;
    uint8 *types = NULL, cell;
    uint32 arity = 0;
    int32 i;
    int16 *frame_offset = ctx.frame_offset;
    uint16 dynamic_offset;

    /* Note: loop's arity is different from if and block. loop's arity is
     * its parameter count while if and block arity is result count.
     */
    if (frame_csp.label_type == LABEL_TYPE_LOOP)
        arity = block_type_get_param_types(block_type, &types);
    else
        arity = block_type_get_result_types(block_type, &types);

    /* Part a */
    mixin(emit_uint32!(ctx, arity)());

    if (arity) {
        /* Part b */
        mixin(emit_uint32!(ctx, wasm_get_cell_num(types, arity))());
        /* Part c */
        for (i = cast(int32)arity - 1; i >= 0; i--) {
            cell = wasm_value_type_cell_num(types[i]);
            mixin(emit_byte!(ctx, cell)());
        }
        /* Part d */
        for (i = cast(int32)arity - 1; i >= 0; i--) {
            cell = wasm_value_type_cell_num(types[i]);
            frame_offset -= cell;
            emit_operand(ctx, *cast(int16*)(frame_offset));
        }
        /* Part e */
        dynamic_offset = frame_csp.dynamic_offset
                         + wasm_get_cell_num(types, arity);
        for (i = cast(int32)arity - 1; i >= 0; i--) {
            cell = wasm_value_type_cell_num(types[i]);
            dynamic_offset -= cell;
            emit_operand(ctx, dynamic_offset);
        }
    }

    /* Part f */
    if (frame_csp.label_type == LABEL_TYPE_LOOP) {
        wasm_loader_emit_ptr(ctx, frame_csp.code_compiled);
    }
    else {
        if (!add_label_patch_to_list(frame_csp, PATCH_END,
                                     ctx.p_code_compiled,
                                     error_buf, error_buf_size))
            return false;
        /* label address, to be patched */
        wasm_loader_emit_ptr(ctx, NULL);
    }

    return true;
}

static bool
wasm_loader_push_frame_offset(WASMLoaderContext *ctx, uint8 type,
                              bool disable_emit, int16 operand_offset,
                              char *error_buf, uint32 error_buf_size)
{
    if (type == VALUE_TYPE_VOID)
        return true;

    // only check memory overflow in first traverse
    if (ctx.p_code_compiled == NULL) {
        if (!check_offset_push(ctx, error_buf, error_buf_size))
            return false;
    }

    if (disable_emit) {
        *ctx.frame_offset = operand_offset;
        ctx.frame_offset++;
    }
    else {
        emit_operand(ctx, ctx.dynamic_offset);
        *ctx.frame_offset = ctx.dynamic_offset;
        ctx.dynamic_offset+=2;
        if (ctx.dynamic_offset > ctx.max_dynamic_offset)
            ctx.max_dynamic_offset = ctx.dynamic_offset;
    }

    if (type == VALUE_TYPE_I32 || type == VALUE_TYPE_F32)
        return true;

    if (ctx.p_code_compiled == NULL) {
        if (!check_offset_push(ctx, error_buf, error_buf_size))
            return false;
    }

    ctx.frame_offset++;
    if (!disable_emit) {
        ctx.dynamic_offset++;
        if (ctx.dynamic_offset > ctx.max_dynamic_offset)
            ctx.max_dynamic_offset = ctx.dynamic_offset;
    }
    return true;
}

/* This function should be in front of wasm_loader_pop_frame_ref
    as they both use ctx.stack_cell_num, and ctx.stack_cell_num
    will be modified by wasm_loader_pop_frame_ref */
static bool
wasm_loader_pop_frame_offset(WASMLoaderContext *ctx, uint8 type,
                             char *error_buf, uint32 error_buf_size)
{
    /* if ctx.frame_csp equals ctx.frame_csp_bottom,
        then current block is the function block */
    uint32 depth = ctx.frame_csp > ctx.frame_csp_bottom ? 1 : 0;
    BranchBlock *cur_block = ctx.frame_csp - depth;
    int32 available_stack_cell = cast(int32)
        (ctx.stack_cell_num - cur_block.stack_cell_num);

    /* Directly return success if current block is in stack
     * polymorphic state while stack is empty. */
    if (available_stack_cell <= 0 && cur_block.is_stack_polymorphic)
        return true;

    if (type == VALUE_TYPE_VOID)
        return true;

    if (type == VALUE_TYPE_I32 || type == VALUE_TYPE_F32) {
        /* Check the offset stack bottom to ensure the frame offset
            stack will not go underflow. But we don't thrown error
            and return true here, because the error msg should be
            given in wasm_loader_pop_frame_ref */
        if (!check_offset_pop(ctx, 1))
            return true;

        ctx.frame_offset -= 1;
        if ((*(ctx.frame_offset) > ctx.start_dynamic_offset)
            && (*(ctx.frame_offset) < ctx.max_dynamic_offset))
            ctx.dynamic_offset -= 1;
    }
    else {
        if (!check_offset_pop(ctx, 2))
            return true;

        ctx.frame_offset -= 2;
        if ((*(ctx.frame_offset) > ctx.start_dynamic_offset)
            && (*(ctx.frame_offset) < ctx.max_dynamic_offset))
            ctx.dynamic_offset -= 2;
    }
    emit_operand(ctx, *(ctx.frame_offset));
    return true;
}

static bool
wasm_loader_push_pop_frame_offset(WASMLoaderContext *ctx, uint8 pop_cnt,
                                  uint8 type_push, uint8 type_pop,
                                  bool disable_emit, int16 operand_offset,
                                  char *error_buf, uint32 error_buf_size)
{
    for (int i = 0; i < pop_cnt; i++) {
        if (!wasm_loader_pop_frame_offset(ctx, type_pop, error_buf, error_buf_size))
            return false;
    }
    if (!wasm_loader_push_frame_offset(ctx, type_push,
                                       disable_emit, operand_offset,
                                       error_buf, error_buf_size))
        return false;

    return true;
}

static bool
wasm_loader_push_frame_ref_offset(WASMLoaderContext *ctx, uint8 type,
                                  bool disable_emit, int16 operand_offset,
                                  char *error_buf, uint32 error_buf_size)
{
    if (!(wasm_loader_push_frame_offset(ctx, type, disable_emit, operand_offset,
                                        error_buf, error_buf_size)))
        return false;
    if (!(wasm_loader_push_frame_ref(ctx, type, error_buf, error_buf_size)))
        return false;

    return true;
}

static bool
wasm_loader_pop_frame_ref_offset(WASMLoaderContext *ctx, uint8 type,
                                 char *error_buf, uint32 error_buf_size)
{
    /* put wasm_loader_pop_frame_offset in front of wasm_loader_pop_frame_ref */
    if (!wasm_loader_pop_frame_offset(ctx, type, error_buf, error_buf_size))
        return false;
    if (!wasm_loader_pop_frame_ref(ctx, type, error_buf, error_buf_size))
        return false;

    return true;
}

static bool
wasm_loader_push_pop_frame_ref_offset(WASMLoaderContext *ctx, uint8 pop_cnt,
                                      uint8 type_push, uint8 type_pop,
                                      bool disable_emit, int16 operand_offset,
                                      char *error_buf, uint32 error_buf_size)
{
    if (!wasm_loader_push_pop_frame_offset(ctx, pop_cnt, type_push, type_pop,
                                           disable_emit, operand_offset,
                                           error_buf, error_buf_size))
        return false;
    if (!wasm_loader_push_pop_frame_ref(ctx, pop_cnt, type_push, type_pop,
                                        error_buf, error_buf_size))
        return false;

    return true;
}

static bool
wasm_loader_get_const_offset(WASMLoaderContext *ctx, uint8 type,
                             void *value, int16 *offset,
                             char *error_buf, uint32 error_buf_size)
{
    int16 operand_offset = 0;
    Const *c;
    for (c = cast(Const*)ctx.const_buf;
         cast(uint8*)c < ctx.const_buf + ctx.num_const * sizeof(Const); c ++) {
        if ((type == c.value_type)
            && ((type == VALUE_TYPE_I64 && *cast(int64*)value == c.value.i64)
            || (type == VALUE_TYPE_I32 && *cast(int32*)value == c.value.i32)
            || (type == VALUE_TYPE_F64
                && (0 == memcmp(value, &(c.value.f64), sizeof(float64))))
            || (type == VALUE_TYPE_F32
                && (0 == memcmp(value, &(c.value.f32), sizeof(float32)))))) {
            operand_offset = c.slot_index;
            break;
        }
        if (c.value_type == VALUE_TYPE_I64
            || c.value_type == VALUE_TYPE_F64){
            operand_offset += 2;
        }
        else {
            operand_offset += 1;
        }
    }
    if (cast(uint8 *)c == ctx.const_buf + ctx.num_const * sizeof(Const)) {
        if (cast(uint8 *)c == ctx.const_buf + ctx.const_buf_size) {
            mixin(MEM_REALLOC!(ctx.const_buf,
                        ctx.const_buf_size,
                    ctx.const_buf_size + 4 * sizeof(Const))());
            ctx.const_buf_size += 4 * sizeof(Const);
            c = cast(Const *)(ctx.const_buf + ctx.num_const * sizeof(Const));
        }
        c.value_type = type;
        switch (type) {
        case VALUE_TYPE_F64:
            bh_memcpy_s(&(c.value.f64), sizeof(WASMValue), value, sizeof(float64));
            ctx.const_cell_num += 2;
            /* The const buf will be reversed, we use the second cell */
            /* of the i64/f64 const so the finnal offset is corrent */
            operand_offset ++;
            break;
        case VALUE_TYPE_I64:
            c.value.i64 = *cast(int64*)value;
            ctx.const_cell_num += 2;
            operand_offset ++;
            break;
        case VALUE_TYPE_F32:
            bh_memcpy_s(&(c.value.f32), sizeof(WASMValue), value, sizeof(float32));
            ctx.const_cell_num ++;
            break;
        case VALUE_TYPE_I32:
            c.value.i32 = *cast(int32*)value;
            ctx.const_cell_num ++;
            break;
        default:
            break;
        }
        c.slot_index = operand_offset;
        ctx.num_const ++;
        LOG_OP("#### new const [%d]: %ld\n",
            ctx.num_const, cast(int64)c.value.i64);
    }
    /* use negetive index for const */
    operand_offset = -(operand_offset + 1);
    *offset = operand_offset;
    return true;
fail:
    return false;
}

/*
    PUSH(POP)_XXX = push(pop) frame_ref + push(pop) frame_offset
    -- Mostly used for the binary / compare operation
    PUSH(POP)_OFFSET_TYPE only push(pop) the frame_offset stack
    -- Mostly used in block / control instructions

    The POP will always emit the offset on the top of the frame_offset stack
    PUSH can be used in two ways:
    1. directly PUSH:
            PUSH_XXX();
        will allocate a dynamic space and emit
    2. silent PUSH:
            operand_offset = xxx; disable_emit = true;
            PUSH_XXX();
        only push the frame_offset stack, no emit
*/
enum PUSH_I32 = q{
    if (!wasm_loader_push_frame_ref_offset(loader_ctx, VALUE_TYPE_I32,
                                           disable_emit, operand_offset,
                                           error_buf, error_buf_size))
        goto fail;
};

enum PUSH_F32 = q{
    if (!wasm_loader_push_frame_ref_offset(loader_ctx, VALUE_TYPE_F32,
                                           disable_emit, operand_offset,
                                           error_buf, error_buf_size))
        goto fail;
};

enum PUSH_I64 = q{
    if (!wasm_loader_push_frame_ref_offset(loader_ctx, VALUE_TYPE_I64,
                                           disable_emit, operand_offset,
                                           error_buf, error_buf_size))
        goto fail;
};

enum PUSH_F64 = q{
    if (!wasm_loader_push_frame_ref_offset(loader_ctx, VALUE_TYPE_F64,
                                           disable_emit, operand_offset,
                                           error_buf, error_buf_size))
        goto fail;
};

enum POP_I32 = q{
    if (!wasm_loader_pop_frame_ref_offset(loader_ctx, VALUE_TYPE_I32,
            error_buf, error_buf_size))
        goto fail;
};

enum POP_F32 = q{
    if (!wasm_loader_pop_frame_ref_offset(loader_ctx, VALUE_TYPE_F32,
                                          error_buf, error_buf_size))
        goto fail;
};

enum POP_I64 = q{
    if (!wasm_loader_pop_frame_ref_offset(loader_ctx, VALUE_TYPE_I64,
                                          error_buf, error_buf_size))
        goto fail;
};

enum POP_F64 =  q{
    if (!wasm_loader_pop_frame_ref_offset(loader_ctx, VALUE_TYPE_F64,
                                          error_buf, error_buf_size))
        goto fail;
};

string PUSH_OFFSET_TYPE(alias type)() {
    return format!q{
        if (!(wasm_loader_push_frame_offset(loader_ctx, %1$s,
                                        disable_emit, operand_offset,
                                        error_buf, error_buf_size)))
        goto fail;
    }(type.stringof);
}

string POP_OFFSET_TYPE(alias type)() {
    return format!q{
        if (!(wasm_loader_pop_frame_offset(loader_ctx, %1$s,
                                       error_buf, error_buf_size)))
        goto fail;
    }(type.stringof);
};

string POP_AND_PUSH(alias type_pop, alias type_push)() {
    return format!q{
        if (!(wasm_loader_push_pop_frame_ref_offset(loader_ctx, 1,
                    %2$s, %1$s,
                    disable_emit, operand_offset,
                    error_buf, error_buf_size)))
        goto fail;
    }(type_pop.stringof, type_push.stringof);
}

/* type of POPs should be the same */
string POP2_AND_PUSH(alias type_pop, alias type_push)() {
    return format!q{
        if (!(wasm_loader_push_pop_frame_ref_offset(loader_ctx, 2,
                                                %2$s, %1%s,
                                                disable_emit, operand_offset,
                                                error_buf, error_buf_size)))
        goto fail;
    }(type_pop.stringof, type_push.stringof);
}
}
else { /* WASM_ENABLE_FAST_INTERP */

enum PUSH_I32 = q{
    if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_I32,
                                     error_buf, error_buf_size)))
        goto fail;
};

enum PUSH_F32 =  q{
    if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_F32,
                                     error_buf, error_buf_size)))
        goto fail;
};

enum PUSH_I64 = q{
    if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_I64,
                                     error_buf, error_buf_size)))
        goto fail;
};

enum PUSH_F64 = q{
    if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_F64,
                                     error_buf, error_buf_size)))
        goto fail;
};

enum POP_I32 = q{
    if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32,
                                    error_buf, error_buf_size)))
        goto fail;
};

enum POP_F32() = q{
    if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_F32,
                                    error_buf, error_buf_size)))
        goto fail;
};

enum POP_I64 = q{
    if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I64,
                                    error_buf, error_buf_size)))
        goto fail;
};

enum POP_F64 = q{
    if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_F64,
                                    error_buf, error_buf_size)))
        goto fail;
};

string POP_AND_PUSH(alias type_pop, alias type_push)() {
    return format!q{
        if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1,
                                         %1$s, %2$s,
                                         error_buf, error_buf_size)))
        goto fail;
    }(type_pop.stringof, type_push.stringof);
}

/* type of POPs should be the same */
string POP2_AND_PUSH(alias type_pop, alias type_push)() {
    return format!q{
        if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2,
                                         %2$s, %1$s,
                                         error_buf, error_buf_size)))

        goto fail;
    }(type_pop.stringof, type_push.stringof);
}
} /* WASM_ENABLE_FAST_INTERP */

version(WASM_ENABLE_FAST_INTERP) {

static bool
reserve_block_ret(WASMLoaderContext *loader_ctx,
                  uint8 opcode, bool disable_emit,
                  char *error_buf, uint32 error_buf_size)
{
    int16 operand_offset = 0;
    BranchBlock *block = (opcode == WASM_OP_ELSE) ?
                         loader_ctx.frame_csp - 1 : loader_ctx.frame_csp;
    BlockType *block_type = &block.block_type;
    uint8 *return_types = NULL;
    uint32 return_count = 0, value_count = 0, total_cel_num = 0;
    int32 i = 0;
    int16 dynamic_offset, dynamic_offset_org;
    int16* frame_offset, frame_offset_org;

    return_count = block_type_get_result_types(block_type, &return_types);

    /* If there is only one return value, use EXT_OP_COPY_STACK_TOP/_I64 instead
     * of EXT_OP_COPY_STACK_VALUES for interpreter performance. */
    if (return_count == 1) {
        uint8 cell = wasm_value_type_cell_num(return_types[0]);
        if (block.dynamic_offset != *(loader_ctx.frame_offset - cell)) {
            /* insert op_copy before else opcode */
            if (opcode == WASM_OP_ELSE)
                minin(skip_label);
            mixin(emit_label!(cell == 1 ? EXT_OP_COPY_STACK_TOP : EXT_OP_COPY_STACK_TOP_I64)());
            emit_operand(loader_ctx, *(loader_ctx.frame_offset - cell));
            emit_operand(loader_ctx, block.dynamic_offset);

            if (opcode == WASM_OP_ELSE) {
                *(loader_ctx.frame_offset - cell) = block.dynamic_offset;
            }
            else {
                loader_ctx.frame_offset -= cell;
                loader_ctx.dynamic_offset = block.dynamic_offset;
                PUSH_OFFSET_TYPE(return_types[0]);
                wasm_loader_emit_backspace(loader_ctx, sizeof(int16));
            }
            if (opcode == WASM_OP_ELSE)
                mixin(emit_label!(opcode)());
        }
        return true;
    }

    /* Copy stack top values to block's results which are in dynamic space.
     * The instruction format:
     *   Part a: values count
     *   Part b: all values total cell num
     *   Part c: each value's cell_num, src offset and dst offset
     *   Part d: each value's src offset and dst offset
     *   Part e: each value's dst offset
     */
    frame_offset = frame_offset_org = loader_ctx.frame_offset;
    dynamic_offset = dynamic_offset_org =
                              block.dynamic_offset
                               + wasm_get_cell_num(return_types, return_count);

    /* First traversal to get the count of values needed to be copied. */
    for (i = cast(int32)return_count - 1; i >= 0; i--) {
        uint8 cells = wasm_value_type_cell_num(return_types[i]);

        frame_offset -= cells;
        dynamic_offset -= cells;
        if (dynamic_offset != *frame_offset) {
            value_count++;
            total_cel_num += cells;
        }
    }

    if (value_count) {
        uint32 j = 0;
        uint8 *emit_data, cells;
        int16 *src_offsets;
        uint16 *dst_offsets;
        uint64 size = cast(uint64)value_count * (sizeof(*cells)
                                             + sizeof(*src_offsets)
                                             + sizeof(*dst_offsets));

        /* Allocate memory for the emit data */
        if (!(emit_data = loader_malloc(size, error_buf, error_buf_size)))
            return false;

        cells = emit_data;
        src_offsets = cast(int16 *)(cells + value_count);
        dst_offsets = cast(uint16 *)(src_offsets + value_count);

        /* insert op_copy before else opcode */
        if (opcode == WASM_OP_ELSE)
            mixin(skip_label);
        mixin(emit_label!(EXT_OP_COPY_STACK_VALUES)());
        /* Part a) */
        mixin(emit_uint32!(loader_ctx, value_count)());
        /* Part b) */
        mixin(emit_uint32!(loader_ctx, total_cel_num)());

        /* Second traversal to get each value's cell num,  src offset and dst offset. */
        frame_offset = frame_offset_org;
        dynamic_offset = dynamic_offset_org;
        for (i = cast(int32)return_count - 1, j = 0; i >= 0; i--) {
            uint8 cell = wasm_value_type_cell_num(return_types[i]);
            frame_offset -= cell;
            dynamic_offset -= cell;
            if (dynamic_offset != *frame_offset) {
                /* cell num */
                cells[j] = cell;
                /* src offset */
                src_offsets[j] = *frame_offset;
                /* dst offset */
                dst_offsets[j] = dynamic_offset;
                j++;
            }
            if (opcode == WASM_OP_ELSE) {
                *frame_offset = dynamic_offset;
            }
            else {
                loader_ctx.frame_offset = frame_offset;
                loader_ctx.dynamic_offset = dynamic_offset;
                PUSH_OFFSET_TYPE(return_types[i]);
                wasm_loader_emit_backspace(loader_ctx, sizeof(int16));
                loader_ctx.frame_offset = frame_offset_org;
                loader_ctx.dynamic_offset = dynamic_offset_org;
            }
        }

        bh_assert(j == value_count);

        /* Emit the cells, src_offsets and dst_offsets */
        for (j = 0; j < value_count; j++)
            emit_byte(loader_ctx, cells[j]);
        for (j = 0; j < value_count; j++)
            emit_operand(loader_ctx, src_offsets[j]);
        for (j = 0; j < value_count; j++)
            emit_operand(loader_ctx, dst_offsets[j]);

        if (opcode == WASM_OP_ELSE)
            mixin(emit_label!(opcode)());

        wasm_runtime_free(emit_data);
    }

    return true;

fail:
    return false;
}
} /* WASM_ENABLE_FAST_INTERP */

enum RESERVE_BLOCK_RET = q{
     if (!reserve_block_ret(loader_ctx, opcode, disable_emit,
                            error_buf, error_buf_size))
        goto fail;
};

string PUSH_TYPE(alias type)() {
    return format!q{
    if (!(wasm_loader_push_frame_ref(loader_ctx, %1$s,
                                     error_buf, error_buf_size)))
        goto fail;
    }(type.stringof);
}

string POP_TYPE(alias type)() {
    return format!q{
        if (!(wasm_loader_pop_frame_ref(loader_ctx, %1$s,
                                    error_buf, error_buf_size)))
        goto fail;
    }(type.stringof);
}

string PUSH_CSP(alias label_type, alias block_type, alias _start_addr)() {
    return format!q{
    if (!wasm_loader_push_frame_csp(loader_ctx, %1$s, %2$s,
                                    %3$s, error_buf,
                                    error_buf_size))
        goto fail;
    }(label_type.stringof, block_type.stringof, _start_addr.stringof);
}

enum POP_CSP = q{
    if (!wasm_loader_pop_frame_csp(loader_ctx,
                                   error_buf, error_buf_size))
        goto fail;
};

enum GET_LOCAL_INDEX_TYPE_AND_OFFSET =  q{
    read_leb_uint32(p, p_end, local_idx);
    if (local_idx >= param_count + local_count) {
      set_error_buf(error_buf, error_buf_size,
                    "WASM module load failed: " ~
                    "unknown local.");
      goto fail;
    }
    local_type = local_idx < param_count
        ? param_types[local_idx]
        : local_types[local_idx - param_count];
    local_offset = local_offsets[local_idx];
};

string CHECK_BR(alias depth)() {
    return format!q{
    if (!wasm_loader_check_br(loader_ctx, %1$s,
                              error_buf, error_buf_size))
        goto fail;
    }(depth.stringof);
}

static bool
check_memory(WASMModule *wasm_module,
             char *error_buf, uint32 error_buf_size)
{
    if (wasm_module.memory_count == 0
        && wasm_module.import_memory_count == 0) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: unknown memory");
        return false;
    }
    return true;
}

enum CHECK_MEMORY = q{
    if (!check_memory(wasm_module, error_buf, error_buf_size))
      goto fail;
};

static bool
check_memory_access_align(uint8 opcode, uint32 align,
                          char *error_buf, uint32 error_buf_size)
{
    uint8 mem_access_aligns[] = {
       2, 3, 2, 3, 0, 0, 1, 1, 0, 0, 1, 1, 2, 2, /* loads */
       2, 3, 2, 3, 0, 1, 0, 1, 2                 /* stores */
    };
    bh_assert(opcode >= WASM_OP_I32_LOAD
              && opcode <= WASM_OP_I64_STORE32);
    if (align > mem_access_aligns[opcode - WASM_OP_I32_LOAD]) {
        set_error_buf(error_buf, error_buf_size,
                      "alignment must not be larger than natural");
        return false;
    }
    return true;
}

static bool
is_value_type(uint8 type)
{
    return type == VALUE_TYPE_I32 ||
           type == VALUE_TYPE_I64 ||
           type == VALUE_TYPE_F32 ||
           type == VALUE_TYPE_F64 ||
           type == VALUE_TYPE_VOID;
}

static bool
wasm_loader_check_br(WASMLoaderContext *loader_ctx, uint32 depth,
                     char *error_buf, uint32 error_buf_size)
{
    BranchBlock *target_block, *cur_block;
    BlockType *target_block_type;
    uint8 *types = NULL, *frame_ref;
    uint32 arity = 0;
    int32 i, available_stack_cell;
    uint16 cell_num;

    if (loader_ctx.csp_num < depth + 1) {
      set_error_buf(error_buf, error_buf_size,
                    "WASM module load failed: unknown label, "
                    "unexpected end of section or function");
      return false;
    }

    cur_block = loader_ctx.frame_csp - 1;
    target_block = loader_ctx.frame_csp - (depth + 1);
    target_block_type = &target_block.block_type;
    frame_ref = loader_ctx.frame_ref;

    /* Note: loop's arity is different from if and block. loop's arity is
     * its parameter count while if and block arity is result count.
     */
    if (target_block.label_type == LABEL_TYPE_LOOP)
        arity = block_type_get_param_types(target_block_type, &types);
    else
        arity = block_type_get_result_types(target_block_type, &types);

    /* If the stack is in polymorphic state, just clear the stack
     * and then re-push the values to make the stack top values
     * match block type. */
    if (cur_block.is_stack_polymorphic) {
        for (i = (int32)arity -1; i >= 0; i--) {
            version(WASM_ENABLE_FAST_INTERP) {
                mixin(POP_OFFSET_TYPE!(types[i])());
            }
            mixin(POP_TYPE!(types[i])());
        }
        for (i = 0; i < (int32)arity; i++) {
#if WASM_ENABLE_FAST_INTERP != 0
            bool disable_emit = true;
            int16 operand_offset = 0;
            PUSH_OFFSET_TYPE(types[i]);
#endif
            mixin(PUSH_TYPE!(types[i])());
        }
        return true;
    }

    available_stack_cell = (int32)
                           (loader_ctx.stack_cell_num - cur_block.stack_cell_num);

    /* Check stack top values match target block type */
    for (i = (int32)arity -1; i >= 0; i--) {
        if (!check_stack_top_values(frame_ref, available_stack_cell,
                                    types[i],
                                    error_buf, error_buf_size))
            return false;
        cell_num = wasm_value_type_cell_num(types[i]);
        frame_ref -= cell_num;
        available_stack_cell -= cell_num;
    }

    return true;

fail:
    return false;
}

static BranchBlock *
check_branch_block(WASMLoaderContext *loader_ctx,
                   uint8 **p_buf, uint8 *buf_end,
                   char *error_buf, uint32 error_buf_size)
{
    uint8 *p = *p_buf, *p_end = buf_end;
    BranchBlock *frame_csp_tmp;
    uint32 depth;

    read_leb_uint32(p, p_end, depth);
    mixin(CHECK_BR!(depth)());
    frame_csp_tmp = loader_ctx.frame_csp - depth - 1;
    version(WASM_ENABLE_FAST_INTERP) {
    mixin(emit_br_info!(frame_csp_tmp)());
    }

    *p_buf = p;
    return frame_csp_tmp;
fail:
    return NULL;
}

static bool
check_block_stack(WASMLoaderContext *loader_ctx, BranchBlock *block,
                  char *error_buf, uint32 error_buf_size)
{
    BlockType *block_type = &block.block_type;
    uint8 *return_types = NULL;
    uint32 return_count = 0;
    int32 available_stack_cell, return_cell_num, i;
    uint8 *frame_ref = NULL;

    available_stack_cell = (int32)
                           (loader_ctx.stack_cell_num
                            - block.stack_cell_num);

    return_count = block_type_get_result_types(block_type, &return_types);
    return_cell_num = return_count > 0 ?
                      wasm_get_cell_num(return_types, return_count) : 0;

    /* If the stack is in polymorphic state, just clear the stack
     * and then re-push the values to make the stack top values
     * match block type. */
    if (block.is_stack_polymorphic) {
        for (i = (int32)return_count -1; i >= 0; i--) {
#if WASM_ENABLE_FAST_INTERP != 0
            mixin(POP_OFFSET_TYPE!(return_types[i]);
#endif
                mixin(POP_TYPE!(return_types[i])());
        }

        /* Check stack is empty */
        if (loader_ctx.stack_cell_num != block.stack_cell_num) {
            set_error_buf(error_buf, error_buf_size,
                          "WASM module load failed: "
                          "type mismatch: stack size does not match block type");
            goto fail;
        }

        for (i = 0; i < (int32)return_count; i++) {
#if WASM_ENABLE_FAST_INTERP != 0
            bool disable_emit = true;
            int16 operand_offset = 0;
            PUSH_OFFSET_TYPE(return_types[i]);
#endif
            mixin(PUSH_TYPE!(return_types[i])());
        }
        return true;
    }

    /* Check stack cell num equals return cell num */
    if (available_stack_cell != return_cell_num) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: "
                      "type mismatch: stack size does not match block type");
        goto fail;
    }

    /* Check stack values match return types */
    frame_ref = loader_ctx.frame_ref;
    for (i = (int32)return_count -1; i >= 0; i--) {
        if (!check_stack_top_values(frame_ref, available_stack_cell,
                                    return_types[i],
                                    error_buf, error_buf_size))
            return false;
        frame_ref -= wasm_value_type_cell_num(return_types[i]);
        available_stack_cell -= wasm_value_type_cell_num(return_types[i]);
    }

    return true;

fail:
    return false;
}

#if WASM_ENABLE_FAST_INTERP != 0
/* Copy parameters to dynamic space.
 * 1) POP original parameter out;
 * 2) Push and copy original values to dynamic space.
 * The copy instruction format:
 *   Part a: param count
 *   Part b: all param total cell num
 *   Part c: each param's cell_num, src offset and dst offset
 *   Part d: each param's src offset
 *   Part e: each param's dst offset
 */
static bool
copy_params_to_dynamic_space(WASMLoaderContext *loader_ctx, bool is_if_block,
                             char* error_buf, uint32 error_buf_size)
{
    int16 *frame_offset = NULL;
    uint8 *cells = NULL, cell;
    int16 *src_offsets = NULL;
    uint8 *emit_data = NULL;
    uint32 i;
    BranchBlock *block = loader_ctx.frame_csp - 1;
    BlockType *block_type = &block.block_type;
    WASMType *wasm_type = block_type.u.type;
    uint32 param_count = block_type.u.type.param_count;
    int16 condition_offset = 0;
    bool disable_emit = false;
    int16 operand_offset = 0;

    uint64 size = (uint64)param_count * (sizeof(*cells)
                                         + sizeof(*src_offsets));

    /* For if block, we also need copy the condition operand offset. */
    if (is_if_block)
        size += sizeof(*cells) + sizeof(*src_offsets);

    /* Allocate memory for the emit data */
    if (!(emit_data = loader_malloc(size, error_buf, error_buf_size)))
        return false;

    cells = emit_data;
    src_offsets = (int16 *)(cells + param_count);

    if (is_if_block)
        condition_offset = *loader_ctx.frame_offset;

    /* POP original parameter out */
    for (i = 0; i < param_count; i++) {
        mixin(POP_OFFSET_TYPE!(wasm_type.types[param_count - i - 1]);
        wasm_loader_emit_backspace(loader_ctx, sizeof(int16));
    }
    frame_offset = loader_ctx.frame_offset;

    /* Get each param's cell num and src offset */
    for (i = 0; i < param_count; i++) {
        cell = wasm_value_type_cell_num(wasm_type.types[i]);
        cells[i] = cell;
        src_offsets[i] = *frame_offset;
        frame_offset += cell;
    }

    /* emit copy instruction */
    mixin(emit_label!(EXT_OP_COPY_STACK_VALUES)());
    /* Part a) */
    mixin(emit_uint32!(loader_ctx, is_if_block ? param_count + 1 : param_count)());
    /* Part b) */
    mixin(emit_uint32!(loader_ctx, is_if_block ?
            wasm_type.param_cell_num + 1 :
            wasm_type.param_cell_num)());
    /* Part c) */
    for (i = 0; i < param_count; i++)
        emit_byte(loader_ctx, cells[i]);
    if (is_if_block)
        emit_byte(loader_ctx, 1);

    /* Part d) */
    for (i = 0; i < param_count; i++)
        emit_operand(loader_ctx, src_offsets[i]);
    if (is_if_block)
        emit_operand(loader_ctx, condition_offset);

    /* Part e) */
    /* Push to dynamic space. The push will emit the dst offset. */
    for (i = 0; i < param_count; i++)
        PUSH_OFFSET_TYPE(wasm_type.types[i]);
    if (is_if_block)
        PUSH_OFFSET_TYPE(VALUE_TYPE_I32);

    /* Free the emit data */
    wasm_runtime_free(emit_data);

    return true;

fail:
    return false;
}
#endif

/* reset the stack to the state of before entering the last block */
#if WASM_ENABLE_FAST_INTERP != 0
#define RESET_STACK() do {                                                   \
    loader_ctx.stack_cell_num =                                             \
               (loader_ctx.frame_csp - 1).stack_cell_num;                  \
    loader_ctx.frame_ref =                                                  \
               loader_ctx.frame_ref_bottom + loader_ctx.stack_cell_num;    \
    loader_ctx.frame_offset =                                               \
               loader_ctx.frame_offset_bottom + loader_ctx.stack_cell_num; \
} while (0)
#else
#define RESET_STACK() do {                                                \
    loader_ctx.stack_cell_num =                                          \
               (loader_ctx.frame_csp - 1).stack_cell_num;               \
    loader_ctx.frame_ref =                                               \
               loader_ctx.frame_ref_bottom + loader_ctx.stack_cell_num; \
} while (0)
#endif

/* set current block's stack polymorphic state */
#define SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(flag) do {                  \
    BranchBlock *cur_block = loader_ctx.frame_csp - 1;                   \
    cur_block.is_stack_polymorphic = flag;                               \
} while (0)

#define BLOCK_HAS_PARAM(block_type) \
    (!block_type.is_value_type && block_type.u.type.param_count > 0)

static bool
wasm_loader_prepare_bytecode(WASMModule *module, WASMFunction *func,
                             BlockAddr *block_addr_cache,
                             char *error_buf, uint32 error_buf_size)
{
    uint8 *p = func.code, *p_end = func.code + func.code_size, *p_org;
    uint32 param_count, local_count, global_count;
    uint8 *param_types, *local_types, local_type, global_type;
    BlockType func_type;
    uint16 *local_offsets, local_offset;
    uint32 count, i, local_idx, global_idx, u32, align, mem_offset;
    int32 i32, i32_const = 0;
    int64 i64;
    uint8 opcode, u8;
    bool return_value = false;
    WASMLoaderContext *loader_ctx;
    BranchBlock *frame_csp_tmp;
#if WASM_ENABLE_BULK_MEMORY != 0
    uint32 segment_index;
#endif
#if WASM_ENABLE_FAST_INTERP != 0
    uint8 *func_const_end, *func_const;
    int16 operand_offset;
    uint8 last_op = 0;
    bool disable_emit, preserve_local = false;
    float32 f32;
    float64 f64;

    LOG_OP("\nProcessing func | [%d] params | [%d] locals | [%d] return\n",
        func.param_cell_num,
        func.local_cell_num,
        func.ret_cell_num);
#endif

    global_count = wasm_module.import_global_count + wasm_module.global_count;

    param_count = func.func_type.param_count;
    param_types = func.func_type.types;

    func_type.is_value_type = false;
    func_type.u.type = func.func_type;

    local_count = func.local_count;
    local_types = func.local_types;
    local_offsets = func.local_offsets;

    if (!(loader_ctx = wasm_loader_ctx_init(func))) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM loader prepare bytecode failed: "
                      "allocate memory failed");
        goto fail;
    }

#if WASM_ENABLE_FAST_INTERP != 0
re_scan:
    if (loader_ctx.code_compiled_size > 0) {
        if (!wasm_loader_ctx_reinit(loader_ctx)) {
            set_error_buf(error_buf, error_buf_size,
                          "WASM loader prepare bytecode failed: "
                          "allocate memory failed");
            goto fail;
        }
        p = func.code;
        func.code_compiled = loader_ctx.p_code_compiled;
    }
#endif

    mixin(PUSH_CSP!(LABEL_TYPE_FUNCTION, func_type, p)());

    while (p < p_end) {
        opcode = *p++;
#if WASM_ENABLE_FAST_INTERP != 0
        p_org = p;
        disable_emit = false;
        mixin(emit_label!(opcode)());
#endif

        switch (opcode) {
            case WASM_OP_UNREACHABLE:
                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);
                break;

            case WASM_OP_NOP:
#if WASM_ENABLE_FAST_INTERP != 0
                minin(skip_label);
#endif
                break;

            case WASM_OP_IF:
                mixin(POP_I32);
                goto handle_op_block_and_loop;
            case WASM_OP_BLOCK:
            case WASM_OP_LOOP:
handle_op_block_and_loop:
            {
                uint8 value_type;
                BlockType block_type;

                value_type = read_uint8(p);
                if (is_value_type(value_type)) {
                    /* If the first byte is one of these special values:
                     * 0x40/0x7F/0x7E/0x7D/0x7C, take it as the type of
                     * the single return value. */
                    block_type.is_value_type = true;
                    block_type.u.value_type = value_type;
                }
                else {
                    uint32 type_index;
                    /* Resolve the leb128 encoded type index as block type */
                    p--;
                    read_leb_uint32(p, p_end, type_index);
                    if (type_index >= wasm_module.type_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "WASM loader prepare bytecode failed: "
                                      "unknown type");
                        goto fail;
                    }
                    block_type.is_value_type = false;
                    block_type.u.type = wasm_module.types[type_index];
#if WASM_ENABLE_FAST_INTERP == 0 \
    && WASM_ENABLE_WAMR_COMPILER == 0 \
    && WASM_ENABLE_JIT == 0
                    /* If block use type index as block type, change the opcode
                     * to new extended opcode so that interpreter can resolve the
                     * block quickly.
                     */
                    *(p - 2) = EXT_OP_BLOCK + (opcode - WASM_OP_BLOCK);
#endif
                }

                /* Pop block parameters from stack */
                if (BLOCK_HAS_PARAM(block_type)) {
                    WASMType *wasm_type = block_type.u.type;
                    for (i = 0; i < block_type.u.type.param_count; i++)
                        mixin(POP_TYPE!(wasm_type.types[wasm_type.param_count - i - 1])());
                }

                mixin(PUSH_CSP!(LABEL_TYPE_BLOCK + (opcode - WASM_OP_BLOCK), block_type, p)());

                /* Pass parameters to block */
                if (BLOCK_HAS_PARAM(block_type)) {
                    for (i = 0; i < block_type.u.type.param_count; i++)
                        mixin(PUSH_TYPE!(block_type.u.type.types[i])());
                }

#if WASM_ENABLE_FAST_INTERP != 0
                if (opcode == WASM_OP_BLOCK) {
                    mixin(skip_label);
                } else if (opcode == WASM_OP_LOOP) {
                    mixin(skip_label);
                    if (BLOCK_HAS_PARAM(block_type)) {
                        /* Make sure params are in dynamic space */
                        if (!copy_params_to_dynamic_space(loader_ctx,
                                                          false,
                                                          error_buf,
                                                          error_buf_size))
                            goto fail;
                    }
                    (loader_ctx.frame_csp - 1).code_compiled =
                                        loader_ctx.p_code_compiled;
                } else if (opcode == WASM_OP_IF) {
                    /* If block has parameters, we should make sure they are in
                     * dynamic space. Otherwise, when else branch is missing,
                     * the later opcode may consume incorrect operand offset.
                     * Spec case:
                     *   (func (export "params-id") (param i32) (result i32)
                     *       (i32.const 1)
                     *       (i32.const 2)
                     *       (if (param i32 i32) (result i32 i32) (local.get 0) (then))
                     *       (i32.add)
                     *   )
                     *
                     * So we should emit a copy instruction before the if.
                     *
                     * And we also need to save the parameter offsets and
                     * recover them before entering else branch.
                     *
                     */
                    if (BLOCK_HAS_PARAM(block_type)) {
                        BranchBlock *block = loader_ctx.frame_csp - 1;
                        uint64 size;

                        /* skip the if condition operand offset */
                        wasm_loader_emit_backspace(loader_ctx, sizeof(int16));
                        /* skip the if label */
                        mixin(skip_label);
                        /* Emit a copy instruction */
                        if (!copy_params_to_dynamic_space(loader_ctx,
                                                          true,
                                                          error_buf,
                                                          error_buf_size))
                            goto fail;

                        /* Emit the if instruction */
                        mixin(emit_label!(opcode)());
                        /* Emit the new condition operand offset */
                        mixin(POP_OFFSET_TYPE!(VALUE_TYPE_I32);

                        /* Save top param_count values of frame_offset stack, so that
                         * we can recover it before executing else branch */
                        size = sizeof(int16) *
                               (uint64)block_type.u.type.param_cell_num;
                        if (!(block.param_frame_offsets =
                                    loader_malloc(size, error_buf, error_buf_size)))
                            goto fail;
                        bh_memcpy_s(block.param_frame_offsets,
                                    size,
                                    loader_ctx.frame_offset - size/sizeof(int16),
                                    size);
                    }

                    mixin(emit_empty_label_addr_and_frame_ip!(PATCH_ELSE)());
                    mixin(emit_empty_label_addr_and_frame_ip!(PATCH_END)());
                }
#endif
                break;
            }

            case WASM_OP_ELSE:
            {
                BlockType block_type = (loader_ctx.frame_csp - 1).block_type;

                if (loader_ctx.csp_num < 2
                    || (loader_ctx.frame_csp - 1).label_type != LABEL_TYPE_IF) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "opcode else found without matched opcode if");
                    goto fail;
                }

                /* check whether if branch's stack matches its result type */
                if (!check_block_stack(loader_ctx, loader_ctx.frame_csp - 1,
                                       error_buf, error_buf_size))
                    goto fail;

                (loader_ctx.frame_csp - 1).else_addr = p - 1;

#if WASM_ENABLE_FAST_INTERP != 0
                /* if the result of if branch is in local or const area, add a copy op */
                mixin(RESERVE_BLOCK_RET);

                emit_empty_label_addr_and_frame_ip(PATCH_END);
                apply_label_patch(loader_ctx, 1, PATCH_ELSE);
#endif
                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(false);

                /* Pass parameters to if-false branch */
                if (BLOCK_HAS_PARAM(block_type)) {
                    for (i = 0; i < block_type.u.type.param_count; i++)
                        mixin(PUSH_TYPE!(block_type.u.type.types[i])());
                }

#if WASM_ENABLE_FAST_INTERP != 0
                /* Recover top param_count values of frame_offset stack */
                if (BLOCK_HAS_PARAM((block_type))) {
                    uint32 size;
                    BranchBlock *block = loader_ctx.frame_csp - 1;
                    size = sizeof(int16) *
                           block_type.u.type.param_cell_num;
                    bh_memcpy_s(loader_ctx.frame_offset, size,
                                block.param_frame_offsets, size);
                    loader_ctx.frame_offset += (size/sizeof(int16));
                }
#endif

                break;
            }

            case WASM_OP_END:
            {
                BranchBlock *cur_block = loader_ctx.frame_csp - 1;

                /* check whether block stack matches its result type */
                if (!check_block_stack(loader_ctx, cur_block,
                                       error_buf, error_buf_size))
                    goto fail;

                /* if no else branch, and return types do not match param types, fail */
                if (cur_block.label_type == LABEL_TYPE_IF
                    && !cur_block.else_addr) {
                    uint32 param_count = 0, ret_count = 0;
                    uint8 *param_types = NULL, *ret_types = NULL;
                    BlockType *block_type = &cur_block.block_type;
                    if (block_type.is_value_type) {
                        if (block_type.u.value_type != VALUE_TYPE_VOID) {
                            ret_count = 1;
                            ret_types = &block_type.u.value_type;
                        }
                    }
                    else {
                        param_count = block_type.u.type.param_count;
                        ret_count = block_type.u.type.result_count;
                        param_types = block_type.u.type.types;
                        ret_types = block_type.u.type.types + param_count;
                    }
                    if (param_count != ret_count
                        || (param_count && memcmp(param_types, ret_types, param_count))) {
                        set_error_buf(error_buf, error_buf_size,
                                      "WASM module load failed: "
                                      "type mismatch: else branch missing");
                        goto fail;
                    }
                }

                mixin(POP_CSP);

#if WASM_ENABLE_FAST_INTERP != 0
                mixin(skip_label);
                /* copy the result to the block return address */
                mixin(RESERVE_BLOCK_RET);

                apply_label_patch(loader_ctx, 0, PATCH_END);
                free_label_patch_list(loader_ctx.frame_csp);
                if (loader_ctx.frame_csp.label_type == LABEL_TYPE_FUNCTION) {
                    int32 idx;
                    uint8 ret_type;

                    mixin(emit_label!(WASM_OP_RETURN)());
                    for (idx = (int32)func.func_type.result_count - 1;
                         idx >= 0; idx--) {
                        ret_type = *(func.func_type.types
                                     + func.func_type.param_count + idx);
                        mixin(POP_OFFSET_TYPE!(ret_type);
                    }
                }
#endif
                if (loader_ctx.csp_num > 0) {
                    loader_ctx.frame_csp.end_addr = p - 1;
                }
                else {
                    /* end of function block, function will return,
                       ignore the following bytecodes */
                    p = p_end;

                    continue;
                }

                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(false);
                break;
            }

            case WASM_OP_BR:
            {
                if (!(frame_csp_tmp = check_branch_block(loader_ctx, &p, p_end,
                                                         error_buf, error_buf_size)))
                    goto fail;

                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);
                break;
            }

            case WASM_OP_BR_IF:
            {
                mixin(POP_I32);

                if (!(frame_csp_tmp = check_branch_block(loader_ctx, &p, p_end,
                                                         error_buf, error_buf_size)))
                    goto fail;

                break;
            }

            case WASM_OP_BR_TABLE:
            {
                uint8 *ret_types = NULL;
                uint32 ret_count = 0;

                read_leb_uint32(p, p_end, count);
#if WASM_ENABLE_FAST_INTERP != 0
                mixin(emit_uint32!(loader_ctx, count)());
#endif
                mixin(POP_I32);

                /* TODO: check the const */
                for (i = 0; i <= count; i++) {
                    if (!(frame_csp_tmp =
                            check_branch_block(loader_ctx, &p, p_end,
                                               error_buf, error_buf_size)))
                        goto fail;

                    if (i == 0) {
                        if (frame_csp_tmp.label_type != LABEL_TYPE_LOOP)
                            ret_count =
                                    block_type_get_result_types(&frame_csp_tmp.block_type,
                                                                &ret_types);
                    }
                    else {
                        uint8 *tmp_ret_types = NULL;
                        uint32 tmp_ret_count = 0;

                        /* Check whether all table items have the same return type */
                        if (frame_csp_tmp.label_type != LABEL_TYPE_LOOP)
                            tmp_ret_count =
                                    block_type_get_result_types(&frame_csp_tmp.block_type,
                                                                &tmp_ret_types);

                        if (ret_count != tmp_ret_count
                            || (ret_count
                                && 0 != memcmp(ret_types, tmp_ret_types, ret_count))) {
                            set_error_buf(error_buf, error_buf_size,
                                          "WASM loader prepare bytecode failed: "
                                          "type mismatch: br_table targets must "
                                          "all use same result type");
                            goto fail;
                        }
                    }
                }

                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);
                break;
            }

            case WASM_OP_RETURN:
            {
                int32 idx;
                uint8 ret_type;
                for (idx = (int32)func.func_type.result_count - 1; idx >= 0; idx--) {
                    ret_type = *(func.func_type.types
                                 + func.func_type.param_count + idx);
                    mixin(POP_TYPE!(ret_type)());
#if WASM_ENABLE_FAST_INTERP != 0
                    // emit the offset after return opcode
                    mixin(POP_OFFSET_TYPE!(ret_type);
#endif
                }

                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);

                break;
            }

            case WASM_OP_CALL:
            {
                WASMType *func_type;
                uint32 func_idx;
                int32 idx;

                read_leb_uint32(p, p_end, func_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                // we need to emit func_idx before arguments
                mixin(emit_uint32!(loader_ctx, func_idx)());
#endif

                if (func_idx >= wasm_module.import_function_count + wasm_module.function_count) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "unknown function.");
                    goto fail;
                }

                if (func_idx < wasm_module.import_function_count)
                    func_type = wasm_module.import_functions[func_idx].u.function.func_type;
                else
                    func_type =
                        wasm_module.functions[func_idx - wasm_module.import_function_count].func_type;

                if (func_type.param_count > 0) {
                    for (idx = (int32)(func_type.param_count - 1); idx >= 0; idx--) {
                        mixin(POP_TYPE!(func_type.types[idx])());
#if WASM_ENABLE_FAST_INTERP != 0
                        mixin(POP_OFFSET_TYPE!(func_type.types[idx]);
#endif
                    }
                }

                for (i = 0; i < func_type.result_count; i++) {
                    mixin(PUSH_TYPE!(func_type.types[func_type.param_count + i])());
#if WASM_ENABLE_FAST_INTERP != 0
                    /* Here we emit each return value's dynamic_offset. But in fact
                     * these offsets are continuous, so interpreter only need to get
                     * the first return value's offset.
                     */
                    PUSH_OFFSET_TYPE(func_type.types[func_type.param_count + i]);
#endif
                }

                func.has_op_func_call = true;
                break;
            }

            case WASM_OP_CALL_INDIRECT:
            {
                int32 idx;
                WASMType *func_type;
                uint32 type_idx;

                if (wasm_module.table_count == 0
                    && wasm_module.import_table_count == 0) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "call indirect with unknown table");
                    goto fail;
                }

                read_leb_uint32(p, p_end, type_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                // we need to emit func_idx before arguments
                mixin(emit_uint32!(loader_ctx, type_idx)());
#endif

                /* reserved byte 0x00 */
                if (*p++ != 0x00) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "zero flag expected");
                    goto fail;
                }

                mixin(POP_I32);

                if (type_idx >= wasm_module.type_count) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "unknown type");
                    goto fail;
                }

                func_type = wasm_module.types[type_idx];

                if (func_type.param_count > 0) {
                    for (idx = (int32)(func_type.param_count - 1); idx >= 0; idx--) {
                        mixin(POP_TYPE!(func_type.types[idx])());
#if WASM_ENABLE_FAST_INTERP != 0
                        mixin(POP_OFFSET_TYPE!(func_type.types[idx]);
#endif
                    }
                }

                for (i = 0; i < func_type.result_count; i++) {
                    mixin(PUSH_TYPE!(func_type.types[func_type.param_count + i])());
#if WASM_ENABLE_FAST_INTERP != 0
                    PUSH_OFFSET_TYPE(func_type.types[func_type.param_count + i]);
#endif
                }

                func.has_op_func_call = true;
                break;
            }

            case WASM_OP_DROP:
            case WASM_OP_DROP_64:
            {
                BranchBlock *cur_block = loader_ctx.frame_csp - 1;
                int32 available_stack_cell = (int32)
                    (loader_ctx.stack_cell_num - cur_block.stack_cell_num);

                if (available_stack_cell <= 0
                    && !cur_block.is_stack_polymorphic) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "type mismatch, opcode drop was found "
                                  "but stack was empty");
                    goto fail;
                }

                if (available_stack_cell > 0) {
                    if (*(loader_ctx.frame_ref - 1) == REF_I32
                        || *(loader_ctx.frame_ref - 1) == REF_F32) {
                        loader_ctx.frame_ref--;
                        loader_ctx.stack_cell_num--;
#if WASM_ENABLE_FAST_INTERP != 0
                        mixin(skip_label);
                        loader_ctx.frame_offset--;
                        if (*(loader_ctx.frame_offset) >
                                loader_ctx.start_dynamic_offset)
                            loader_ctx.dynamic_offset --;
#endif
                    }
                    else {
                        loader_ctx.frame_ref -= 2;
                        loader_ctx.stack_cell_num -= 2;
#if (WASM_ENABLE_FAST_INTERP == 0) || (WASM_ENABLE_JIT != 0)
                        *(p - 1) = WASM_OP_DROP_64;
#endif
#if WASM_ENABLE_FAST_INTERP != 0
                        mixin(skip_label);
                        loader_ctx.frame_offset -= 2;
                        if (*(loader_ctx.frame_offset) >
                                loader_ctx.start_dynamic_offset)
                            loader_ctx.dynamic_offset -= 2;
#endif
                    }
                }
                else {
#if WASM_ENABLE_FAST_INTERP != 0
                    mixin(skip_label);
#endif
                }
                break;
            }

            case WASM_OP_SELECT:
            case WASM_OP_SELECT_64:
            {
                uint8 ref_type;
                BranchBlock *cur_block = loader_ctx.frame_csp - 1;
                int32 available_stack_cell;

                mixin(POP_I32);

                available_stack_cell = (int32)
                    (loader_ctx.stack_cell_num - cur_block.stack_cell_num);

                if (available_stack_cell <= 0
                    && !cur_block.is_stack_polymorphic) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "type mismatch, opcode select was found "
                                  "but stack was empty");
                    goto fail;
                }

                if (available_stack_cell > 0) {
                    switch (*(loader_ctx.frame_ref - 1)) {
                        case REF_I32:
                        case REF_F32:
                            break;
                        case REF_I64_2:
                        case REF_F64_2:
#if (WASM_ENABLE_FAST_INTERP == 0) || (WASM_ENABLE_JIT != 0)
                            *(p - 1) = WASM_OP_SELECT_64;
#endif
#if WASM_ENABLE_FAST_INTERP != 0
                            if (loader_ctx.p_code_compiled) {
#if WASM_ENABLE_ABS_LABEL_ADDR != 0
                                *(void**)(loader_ctx.p_code_compiled - 2 - sizeof(void*)) =
                                    handle_table[WASM_OP_SELECT_64];
#else
                                *((int16*)loader_ctx.p_code_compiled - 2) = (int16)
                                    (handle_table[WASM_OP_SELECT_64] - handle_table[0]);
#endif
                            }
#endif
                            break;
                    }

                    ref_type = *(loader_ctx.frame_ref - 1);
#if WASM_ENABLE_FAST_INTERP != 0
                    mixin(POP_OFFSET_TYPE!(ref_type);
#endif
                        mixin(POP_TYPE!(ref_type)());
#if WASM_ENABLE_FAST_INTERP != 0
                    mixin(POP_OFFSET_TYPE!(ref_type);
#endif
                        mixin(POP_TYPE!(ref_type)());
#if WASM_ENABLE_FAST_INTERP != 0
                    PUSH_OFFSET_TYPE(ref_type);
#endif
                        mixin(PUSH_TYPE!(ref_type)());
                }
                else {
#if WASM_ENABLE_FAST_INTERP != 0
                    PUSH_OFFSET_TYPE(VALUE_TYPE_ANY);
#endif
                    mixin(PUSH_TYPE!(VALUE_TYPE_ANY)());
                }
                break;
            }

            case WASM_OP_GET_LOCAL:
            {
                p_org = p - 1;
                mixin(GET_LOCAL_INDEX_TYPE_AND_OFFSET);
                mixin(PUSH_TYPE!(local_type)());

#if WASM_ENABLE_FAST_INTERP != 0
                /* Get Local is optimized out */
                mixin(skip_label);
                disable_emit = true;
                operand_offset = local_offset;
                PUSH_OFFSET_TYPE(local_type);
#else
#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0)
                if (local_offset < 0x80) {
                    *p_org++ = EXT_OP_GET_LOCAL_FAST;
                    if (local_type == VALUE_TYPE_I32
                        || local_type == VALUE_TYPE_F32)
                        *p_org++ = (uint8)local_offset;
                    else
                        *p_org++ = (uint8)(local_offset | 0x80);
                    while (p_org < p)
                        *p_org++ = WASM_OP_NOP;
                }
#endif
#endif
                break;
            }

            case WASM_OP_SET_LOCAL:
            {
                p_org = p - 1;
                mixin(GET_LOCAL_INDEX_TYPE_AND_OFFSET);
                mixin(POP_TYPE!(local_type)());

#if WASM_ENABLE_FAST_INTERP != 0
                if (!(preserve_referenced_local(loader_ctx, opcode, local_offset,
                                                local_type, &preserve_local,
                                                error_buf, error_buf_size)))
                    goto fail;

                if (local_offset < 256) {
                    mixin(skip_label);
                    if ((!preserve_local) && (LAST_OP_OUTPUT_I32(last_op))) {
                        if (loader_ctx.p_code_compiled)
                            *(int16*)(loader_ctx.p_code_compiled - 2) = local_offset;
                        loader_ctx.frame_offset --;
                        loader_ctx.dynamic_offset --;
                    }
                    else if ((!preserve_local) && (LAST_OP_OUTPUT_I64(last_op))) {
                        if (loader_ctx.p_code_compiled)
                            *(int16*)(loader_ctx.p_code_compiled - 2) = local_offset;
                        loader_ctx.frame_offset -= 2;
                        loader_ctx.dynamic_offset -= 2;
                    }
                    else {
                        if (local_type == VALUE_TYPE_I32
                            || local_type == VALUE_TYPE_F32) {
                            mixin(emit_label!(EXT_OP_SET_LOCAL_FAST)());
                            emit_byte(loader_ctx, local_offset);
                        }
                        else {
                            mixin(emit_label!(EXT_OP_SET_LOCAL_FAST_I64)());
                            emit_byte(loader_ctx, local_offset);
                        }
                        mixin(POP_OFFSET_TYPE!(local_type);
                    }
                }
                else {   /* local index larger than 255, reserve leb */
                    p_org ++;
                    mixin(emit_leb);
                    mixin(POP_OFFSET_TYPE!(local_type);
                }
#else
#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0)
                if (local_offset < 0x80) {
                    *p_org++ = EXT_OP_SET_LOCAL_FAST;
                    if (local_type == VALUE_TYPE_I32
                        || local_type == VALUE_TYPE_F32)
                        *p_org++ = (uint8)local_offset;
                    else
                        *p_org++ = (uint8)(local_offset | 0x80);
                    while (p_org < p)
                        *p_org++ = WASM_OP_NOP;
                }
#endif
#endif
                break;
            }

            case WASM_OP_TEE_LOCAL:
            {
                p_org = p - 1;
                mixin(GET_LOCAL_INDEX_TYPE_AND_OFFSET);
#if WASM_ENABLE_FAST_INTERP != 0
                /* If the stack is in polymorphic state, do fake pop and push on
                    offset stack to keep the depth of offset stack to be the same
                    with ref stack */
                BranchBlock *cur_block = loader_ctx.frame_csp - 1;
                if (cur_block.is_stack_polymorphic) {
                    mixin(POP_OFFSET_TYPE!(local_type);
                    PUSH_OFFSET_TYPE(local_type);
                }
#endif
                        mixin(POP_TYPE!(local_type)());
                    mixin(PUSH_TYPE!(local_type)());

#if WASM_ENABLE_FAST_INTERP != 0
                if (!(preserve_referenced_local(loader_ctx, opcode, local_offset,
                                                local_type, &preserve_local,
                                                error_buf, error_buf_size)))
                    goto fail;

                if (local_offset < 256) {
                    mixin(skip_label);
                    if (local_type == VALUE_TYPE_I32
                        || local_type == VALUE_TYPE_F32) {
                        mixin(emit_label!(EXT_OP_TEE_LOCAL_FAST)());
                        emit_byte(loader_ctx, local_offset);
                    }
                    else {
                        mixin(emit_label!(EXT_OP_TEE_LOCAL_FAST_I64)());
                        emit_byte(loader_ctx, local_offset);
                    }
                }
                else {  /* local index larger than 255, reserve leb */
                    p_org ++;
                    mixin(emit_leb);
                }
                emit_operand(loader_ctx, *(loader_ctx.frame_offset -
                        wasm_value_type_cell_num(local_type)));
#else
#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0)
                if (local_offset < 0x80) {
                    *p_org++ = EXT_OP_TEE_LOCAL_FAST;
                    if (local_type == VALUE_TYPE_I32
                        || local_type == VALUE_TYPE_F32)
                        *p_org++ = (uint8)local_offset;
                    else
                        *p_org++ = (uint8)(local_offset | 0x80);
                    while (p_org < p)
                        *p_org++ = WASM_OP_NOP;
                }
#endif
#endif
                break;
            }

            case WASM_OP_GET_GLOBAL:
            {
                p_org = p - 1;
                read_leb_uint32(p, p_end, global_idx);
                if (global_idx >= global_count) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "unknown global.");
                    goto fail;
                }

                global_type =
                  global_idx < wasm_module.import_global_count
                    ? wasm_module.import_globals[global_idx].u.global.type
                    : wasm_module.globals[global_idx - wasm_module.import_global_count]
                        .type;

                mixin(PUSH_TYPE!(global_type)());

#if WASM_ENABLE_FAST_INTERP == 0
#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0)
                if (global_type == VALUE_TYPE_I64
                    || global_type == VALUE_TYPE_F64) {
                    *p_org = WASM_OP_GET_GLOBAL_64;
                }
#endif
#else /* else of WASM_ENABLE_FAST_INTERP */
                if (global_type == VALUE_TYPE_I64
                    || global_type == VALUE_TYPE_F64) {
                    mixin(skip_label);
                    mixin(emit_label!(WASM_OP_GET_GLOBAL_64)());
                }
                mixin(emit_uint32!(loader_ctx, global_idx)());
                PUSH_OFFSET_TYPE(global_type);
#endif /* end of WASM_ENABLE_FAST_INTERP */
                break;
            }

            case WASM_OP_SET_GLOBAL:
            {
                bool is_mutable = false;

                p_org = p - 1;
                read_leb_uint32(p, p_end, global_idx);
                if (global_idx >= global_count) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "unknown global.");
                    goto fail;
                }

                is_mutable =
                  global_idx < wasm_module.import_global_count
                    ? wasm_module.import_globals[global_idx].u.global.is_mutable
                    : wasm_module.globals[global_idx - wasm_module.import_global_count]
                        .is_mutable;
                if (!is_mutable) {
                    set_error_buf(error_buf,
                                  error_buf_size,
                                  "global is immutable");
                    goto fail;
                }

                global_type =
                  global_idx < wasm_module.import_global_count
                    ? wasm_module.import_globals[global_idx].u.global.type
                    : wasm_module.globals[global_idx - wasm_module.import_global_count]
                        .type;

                mixin(POP_TYPE!(global_type)());

#if WASM_ENABLE_FAST_INTERP == 0
#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0)
                if (global_type == VALUE_TYPE_I64
                    || global_type == VALUE_TYPE_F64) {
                    *p_org = WASM_OP_SET_GLOBAL_64;
                }
                else if (wasm_module.llvm_aux_stack_size > 0
                         && global_idx == wasm_module.llvm_aux_stack_global_index) {
                    *p_org = WASM_OP_SET_GLOBAL_AUX_STACK;
                }
#endif
#else /* else of WASM_ENABLE_FAST_INTERP */
                if (global_type == VALUE_TYPE_I64
                    || global_type == VALUE_TYPE_F64) {
                    mixin(skip_label);
                    mixin(emit_label!(WASM_OP_SET_GLOBAL_64)());
                }
                else if (wasm_module.llvm_aux_stack_size > 0
                         && global_idx == wasm_module.llvm_aux_stack_global_index) {
                    mixin(skip_label);
                    mixin(emit_label!(WASM_OP_SET_GLOBAL_AUX_STACK)());
                }
                mixin(emit_uint32!(loader_ctx, global_idx)());
                mixin(POP_OFFSET_TYPE!(global_type)());
#endif /* end of WASM_ENABLE_FAST_INTERP */
                break;
            }

            /* load */
            case WASM_OP_I32_LOAD:
            case WASM_OP_I32_LOAD8_S:
            case WASM_OP_I32_LOAD8_U:
            case WASM_OP_I32_LOAD16_S:
            case WASM_OP_I32_LOAD16_U:
            case WASM_OP_I64_LOAD:
            case WASM_OP_I64_LOAD8_S:
            case WASM_OP_I64_LOAD8_U:
            case WASM_OP_I64_LOAD16_S:
            case WASM_OP_I64_LOAD16_U:
            case WASM_OP_I64_LOAD32_S:
            case WASM_OP_I64_LOAD32_U:
            case WASM_OP_F32_LOAD:
            case WASM_OP_F64_LOAD:
            /* store */
            case WASM_OP_I32_STORE:
            case WASM_OP_I32_STORE8:
            case WASM_OP_I32_STORE16:
            case WASM_OP_I64_STORE:
            case WASM_OP_I64_STORE8:
            case WASM_OP_I64_STORE16:
            case WASM_OP_I64_STORE32:
            case WASM_OP_F32_STORE:
            case WASM_OP_F64_STORE:
            {
#if WASM_ENABLE_FAST_INTERP != 0
                /* change F32/F64 into I32/I64 */
                if (opcode == WASM_OP_F32_LOAD) {
                    mixin(skip_label);
                    mixin(emit_label!(WASM_OP_I32_LOAD)());
                }
                else if (opcode == WASM_OP_F64_LOAD) {
                    mixin(skip_label);
                    mixin(emit_label!(WASM_OP_I64_LOAD)());
                }
                else if (opcode == WASM_OP_F32_STORE) {
                    mixin(skip_label);
                    mixin(emit_label!(WASM_OP_I32_STORE)());
                }
                else if (opcode == WASM_OP_F64_STORE) {
                    mixin(skip_label);
                    mixin(emit_label!(WASM_OP_I64_STORE)());
                }
#endif
                CHECK_MEMORY();
                read_leb_uint32(p, p_end, align); /* align */
                read_leb_uint32(p, p_end, mem_offset); /* offset */
                if (!check_memory_access_align(opcode, align,
                                               error_buf, error_buf_size)) {
                    goto fail;
                }
#if WASM_ENABLE_FAST_INTERP != 0
                mixin(emit_uint32!(loader_ctx, mem_offset)());
#endif
                switch (opcode)
                {
                    /* load */
                    case WASM_OP_I32_LOAD:
                    case WASM_OP_I32_LOAD8_S:
                    case WASM_OP_I32_LOAD8_U:
                    case WASM_OP_I32_LOAD16_S:
                    case WASM_OP_I32_LOAD16_U:
                        POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                        break;
                    case WASM_OP_I64_LOAD:
                    case WASM_OP_I64_LOAD8_S:
                    case WASM_OP_I64_LOAD8_U:
                    case WASM_OP_I64_LOAD16_S:
                    case WASM_OP_I64_LOAD16_U:
                    case WASM_OP_I64_LOAD32_S:
                    case WASM_OP_I64_LOAD32_U:
                        POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I64);
                        break;
                    case WASM_OP_F32_LOAD:
                        POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F32);
                        break;
                    case WASM_OP_F64_LOAD:
                        POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F64);
                        break;
                    /* store */
                    case WASM_OP_I32_STORE:
                    case WASM_OP_I32_STORE8:
                    case WASM_OP_I32_STORE16:
                        mixin(POP_I32);
                        mixin(POP_I32);
                        break;
                    case WASM_OP_I64_STORE:
                    case WASM_OP_I64_STORE8:
                    case WASM_OP_I64_STORE16:
                    case WASM_OP_I64_STORE32:
                        mixin(POP_I64);
                        mixin(POP_I32);
                        break;
                    case WASM_OP_F32_STORE:
                        mixin(POP_F32);
                        mixin(POP_I32);
                        break;
                    case WASM_OP_F64_STORE:
                        mixin(POP_F64);
                        mixin(POP_I32);
                        break;
                    default:
                        break;
                }
                break;
            }

            case WASM_OP_MEMORY_SIZE:
                CHECK_MEMORY();
                /* reserved byte 0x00 */
                if (*p++ != 0x00) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "zero flag expected");
                    goto fail;
                }
                PUSH_I32();
                break;

            case WASM_OP_MEMORY_GROW:
                CHECK_MEMORY();
                /* reserved byte 0x00 */
                if (*p++ != 0x00) {
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "zero flag expected");
                    goto fail;
                }
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);

                func.has_op_memory_grow = true;
                wasm_module.possible_memory_grow = true;
                break;

            case WASM_OP_I32_CONST:
                read_leb_int32(p, p_end, i32_const);
                version(WASM_ENABLE_FAST_INTERP) {
                mixin(skip_label);
                disable_emit = true;
                GET_CONST_OFFSET(VALUE_TYPE_I32, i32_const);
                }
                (void)i32_const;
#endif
                PUSH_I32();
                break;

            case WASM_OP_I64_CONST:
                read_leb_int64(p, p_end, i64);
#if WASM_ENABLE_FAST_INTERP != 0
                mixin(skip_label);
                disable_emit = true;
                GET_CONST_OFFSET(VALUE_TYPE_I64, i64);
#endif
                mixin(PUSH_I64);
                break;

            case WASM_OP_F32_CONST:
                p += sizeof(float32);
#if WASM_ENABLE_FAST_INTERP != 0
                mixin(skip_label);
                disable_emit = true;
                bh_memcpy_s((uint8*)&f32, sizeof(float32), p_org, sizeof(float32));
                mixin(GET_CONST_F32_OFFSET!(VALUE_TYPE_F32, f32)());
#endif
                PUSH_F32();
                break;

            case WASM_OP_F64_CONST:
                p += sizeof(float64);
#if WASM_ENABLE_FAST_INTERP != 0
                mixin(skip_label);
                disable_emit = true;
                /* Some MCU may require 8-byte align */
                bh_memcpy_s((uint8*)&f64, sizeof(float64), p_org, sizeof(float64));
                mixin(GET_CONST_F64_OFFSET!(VALUE_TYPE_F64, f64)());
                mixin(PUSH_F64);
                break;

            case WASM_OP_I32_EQZ:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_EQ:
            case WASM_OP_I32_NE:
            case WASM_OP_I32_LT_S:
            case WASM_OP_I32_LT_U:
            case WASM_OP_I32_GT_S:
            case WASM_OP_I32_GT_U:
            case WASM_OP_I32_LE_S:
            case WASM_OP_I32_LE_U:
            case WASM_OP_I32_GE_S:
            case WASM_OP_I32_GE_U:
                POP2_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EQZ:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EQ:
            case WASM_OP_I64_NE:
            case WASM_OP_I64_LT_S:
            case WASM_OP_I64_LT_U:
            case WASM_OP_I64_GT_S:
            case WASM_OP_I64_GT_U:
            case WASM_OP_I64_LE_S:
            case WASM_OP_I64_LE_U:
            case WASM_OP_I64_GE_S:
            case WASM_OP_I64_GE_U:
                POP2_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I32);
                break;

            case WASM_OP_F32_EQ:
            case WASM_OP_F32_NE:
            case WASM_OP_F32_LT:
            case WASM_OP_F32_GT:
            case WASM_OP_F32_LE:
            case WASM_OP_F32_GE:
                POP2_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                break;

            case WASM_OP_F64_EQ:
            case WASM_OP_F64_NE:
            case WASM_OP_F64_LT:
            case WASM_OP_F64_GT:
            case WASM_OP_F64_LE:
            case WASM_OP_F64_GE:
                POP2_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_CLZ:
            case WASM_OP_I32_CTZ:
            case WASM_OP_I32_POPCNT:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_ADD:
            case WASM_OP_I32_SUB:
            case WASM_OP_I32_MUL:
            case WASM_OP_I32_DIV_S:
            case WASM_OP_I32_DIV_U:
            case WASM_OP_I32_REM_S:
            case WASM_OP_I32_REM_U:
            case WASM_OP_I32_AND:
            case WASM_OP_I32_OR:
            case WASM_OP_I32_XOR:
            case WASM_OP_I32_SHL:
            case WASM_OP_I32_SHR_S:
            case WASM_OP_I32_SHR_U:
            case WASM_OP_I32_ROTL:
            case WASM_OP_I32_ROTR:
                POP2_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_CLZ:
            case WASM_OP_I64_CTZ:
            case WASM_OP_I64_POPCNT:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I64);
                break;

            case WASM_OP_I64_ADD:
            case WASM_OP_I64_SUB:
            case WASM_OP_I64_MUL:
            case WASM_OP_I64_DIV_S:
            case WASM_OP_I64_DIV_U:
            case WASM_OP_I64_REM_S:
            case WASM_OP_I64_REM_U:
            case WASM_OP_I64_AND:
            case WASM_OP_I64_OR:
            case WASM_OP_I64_XOR:
            case WASM_OP_I64_SHL:
            case WASM_OP_I64_SHR_S:
            case WASM_OP_I64_SHR_U:
            case WASM_OP_I64_ROTL:
            case WASM_OP_I64_ROTR:
                POP2_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I64);
                break;

            case WASM_OP_F32_ABS:
            case WASM_OP_F32_NEG:
            case WASM_OP_F32_CEIL:
            case WASM_OP_F32_FLOOR:
            case WASM_OP_F32_TRUNC:
            case WASM_OP_F32_NEAREST:
            case WASM_OP_F32_SQRT:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F32_ADD:
            case WASM_OP_F32_SUB:
            case WASM_OP_F32_MUL:
            case WASM_OP_F32_DIV:
            case WASM_OP_F32_MIN:
            case WASM_OP_F32_MAX:
            case WASM_OP_F32_COPYSIGN:
                POP2_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F64_ABS:
            case WASM_OP_F64_NEG:
            case WASM_OP_F64_CEIL:
            case WASM_OP_F64_FLOOR:
            case WASM_OP_F64_TRUNC:
            case WASM_OP_F64_NEAREST:
            case WASM_OP_F64_SQRT:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_F64);
                break;

            case WASM_OP_F64_ADD:
            case WASM_OP_F64_SUB:
            case WASM_OP_F64_MUL:
            case WASM_OP_F64_DIV:
            case WASM_OP_F64_MIN:
            case WASM_OP_F64_MAX:
            case WASM_OP_F64_COPYSIGN:
                POP2_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_F64);
                break;

            case WASM_OP_I32_WRAP_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_TRUNC_S_F32:
            case WASM_OP_I32_TRUNC_U_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_TRUNC_S_F64:
            case WASM_OP_I32_TRUNC_U_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EXTEND_S_I32:
            case WASM_OP_I64_EXTEND_U_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I64);
                break;

            case WASM_OP_I64_TRUNC_S_F32:
            case WASM_OP_I64_TRUNC_U_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I64);
                break;

            case WASM_OP_I64_TRUNC_S_F64:
            case WASM_OP_I64_TRUNC_U_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I64);
                break;

            case WASM_OP_F32_CONVERT_S_I32:
            case WASM_OP_F32_CONVERT_U_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F32_CONVERT_S_I64:
            case WASM_OP_F32_CONVERT_U_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_F32);
                break;

            case WASM_OP_F32_DEMOTE_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_F32);
                break;

            case WASM_OP_F64_CONVERT_S_I32:
            case WASM_OP_F64_CONVERT_U_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F64);
                break;

            case WASM_OP_F64_CONVERT_S_I64:
            case WASM_OP_F64_CONVERT_U_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_F64);
                break;

            case WASM_OP_F64_PROMOTE_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_F64);
                break;

            case WASM_OP_I32_REINTERPRET_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_REINTERPRET_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I64);
                break;

            case WASM_OP_F32_REINTERPRET_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F64_REINTERPRET_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_F64);
                break;

            case WASM_OP_I32_EXTEND8_S:
            case WASM_OP_I32_EXTEND16_S:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EXTEND8_S:
            case WASM_OP_I64_EXTEND16_S:
            case WASM_OP_I64_EXTEND32_S:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I64);
                break;

            case WASM_OP_MISC_PREFIX:
            {
                opcode = read_uint8(p);
#if WASM_ENABLE_FAST_INTERP != 0
                emit_byte(loader_ctx, opcode);
#endif
                switch (opcode)
                {
                case WASM_OP_I32_TRUNC_SAT_S_F32:
                case WASM_OP_I32_TRUNC_SAT_U_F32:
                    POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                    break;
                case WASM_OP_I32_TRUNC_SAT_S_F64:
                case WASM_OP_I32_TRUNC_SAT_U_F64:
                    POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I32);
                    break;
                case WASM_OP_I64_TRUNC_SAT_S_F32:
                case WASM_OP_I64_TRUNC_SAT_U_F32:
                    POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I64);
                    break;
                case WASM_OP_I64_TRUNC_SAT_S_F64:
                case WASM_OP_I64_TRUNC_SAT_U_F64:
                    POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I64);
                    break;
#if WASM_ENABLE_BULK_MEMORY != 0
                case WASM_OP_MEMORY_INIT:
                    read_leb_uint32(p, p_end, segment_index);
#if WASM_ENABLE_FAST_INTERP != 0
                    mixin(emit_uint32!(loader_ctx, segment_index)());
#endif
                    if (wasm_module.import_memory_count == 0 && wasm_module.memory_count == 0)
                        goto fail_unknown_memory;

                    if (*p++ != 0x00)
                        goto fail_zero_flag_expected;

                    if (segment_index >= wasm_module.data_seg_count) {
                        char msg[128];
                        snprintf(msg, 128, "WASM loader prepare bytecode failed: "
                                           "unknown data segment %d", segment_index);
                        set_error_buf(error_buf, error_buf_size, msg);
                        goto fail;
                    }

                    if (wasm_module.data_seg_count1 == 0)
                        goto fail_data_cnt_sec_require;

                    mixin(POP_I32);
                    mixin(POP_I32);
                    mixin(POP_I32);
                    break;
                case WASM_OP_DATA_DROP:
                    read_leb_uint32(p, p_end, segment_index);
#if WASM_ENABLE_FAST_INTERP != 0
                        mixin(emit_uint32!(loader_ctx, segment_index)());
#endif
                    if (segment_index >= wasm_module.data_seg_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "WASM loader prepare bytecode failed: "
                                      "unknown data segment");
                        goto fail;
                    }

                    if (wasm_module.data_seg_count1 == 0)
                        goto fail_data_cnt_sec_require;

                    break;
                case WASM_OP_MEMORY_COPY:
                    /* both src and dst memory index should be 0 */
                    if (*(int16*)p != 0x0000)
                        goto fail_zero_flag_expected;
                    p += 2;

                    if (wasm_module.import_memory_count == 0 && wasm_module.memory_count == 0)
                        goto fail_unknown_memory;

                    mixin(POP_I32);
                    mixin(POP_I32);
                    mixin(POP_I32);
                    break;
                case WASM_OP_MEMORY_FILL:
                    if (*p++ != 0x00) {
                        goto fail_zero_flag_expected;
                    }
                    if (wasm_module.import_memory_count == 0 && wasm_module.memory_count == 0) {
                        goto fail_unknown_memory;
                    }

                    mixin(POP_I32);
                    mixin(POP_I32);
                    mixin(POP_I32);
                    break;
fail_zero_flag_expected:
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "zero flag expected");
                    goto fail;

fail_unknown_memory:
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "unknown memory 0");
                    goto fail;
fail_data_cnt_sec_require:
                    set_error_buf(error_buf, error_buf_size,
                                  "WASM loader prepare bytecode failed: "
                                  "data count section required");
                    goto fail;
                /* TODO: to support bulk table operation */
#endif /* WASM_ENABLE_BULK_MEMORY */
                default:
                    if (error_buf != NULL)
                        snprintf(error_buf, error_buf_size,
                                 "WASM module load failed: "
                                 "invalid opcode 0xfc %02x.", opcode);
                    goto fail;
                    break;
                }
                break;
            }
            default:
                if (error_buf != NULL)
                    snprintf(error_buf, error_buf_size,
                             "WASM module load failed: "
                             "invalid opcode %02x.", opcode);
                goto fail;
        }

#if WASM_ENABLE_FAST_INTERP != 0
        last_op = opcode;
#endif
    }

    if (loader_ctx.csp_num > 0) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: "
                      "function body must end with END opcode.");
        goto fail;
    }

#if WASM_ENABLE_FAST_INTERP != 0
    if (loader_ctx.p_code_compiled == NULL)
        goto re_scan;

    func.const_cell_num = loader_ctx.const_cell_num;
    if (!(func.consts = func_const =
                loader_malloc(func.const_cell_num * 4,
                              error_buf, error_buf_size))) {
        goto fail;
    }
    func_const_end = func.consts + func.const_cell_num * 4;
    // reverse the const buf
    for (int i = loader_ctx.num_const - 1; i >= 0; i--) {
        Const *c = (Const*)(loader_ctx.const_buf + i * sizeof(Const));
        if (c.value_type == VALUE_TYPE_F64
            || c.value_type == VALUE_TYPE_I64) {
            bh_memcpy_s(func_const, func_const_end - func_const,
                        &(c.value.f64), sizeof(int64));
            func_const += sizeof(int64);
        } else {
            bh_memcpy_s(func_const, func_const_end - func_const,
                        &(c.value.f32), sizeof(int32));
            func_const += sizeof(int32);
        }
    }

    func.max_stack_cell_num = loader_ctx.preserved_local_offset -
                                    loader_ctx.start_dynamic_offset + 1;
#else
    func.max_stack_cell_num = loader_ctx.max_stack_cell_num;
#endif
    func.max_block_num = loader_ctx.max_csp_num;
    return_value = true;

fail:
    wasm_loader_ctx_destroy(loader_ctx);

    (void)u8;
    (void)u32;
    (void)i32;
    (void)i64;
    (void)local_offset;
    (void)p_org;
    (void)mem_offset;
    (void)align;
    return return_value;
}
