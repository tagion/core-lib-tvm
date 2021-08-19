/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.wasm_runtime;

// #ifndef _WASM_RUNTIME_H
// #define _WASM_RUNTIME_H

import tagion.tvm.wamr.wasm;
import tagion.tvm.wamr.bh_hashmap;
import tagion.tvm.wamr.bh_list;
import tagion.tvm.wamr.wasm_runtime_common;
import tagion.tvm.wamr.wasm_exec_env;

// #ifdef __cplusplus
// extern "C" {
// #endif

// typedef struct WASMModuleInstance WASMModuleInstance;
// typedef struct WASMFunctionInstance WASMFunctionInstance;
// typedef struct WASMMemoryInstance WASMMemoryInstance;
// typedef struct WASMTableInstance WASMTableInstance;
// typedef struct WASMGlobalInstance WASMGlobalInstance;

struct WASMMemoryInstance {
    version(WASM_ENABLE_SHARED_MEMORY) {
    /* shared memory flag */
    bool is_shared;
    }
    /* Number bytes per page */
    uint num_bytes_per_page;
    /* Current page count */
    uint cur_page_count;
    /* Maximum page count */
    uint max_page_count;

    /* Heap base offset of wasm app */
    int heap_base_offset;
    /* Heap data base address */
    ubyte *heap_data;
    /* The heap created */
    void* heap_handle;

    /* Memory data */
    ubyte* memory_data;

    /* End address of memory */
    ubyte* end_addr;

    version(WASM_ENABLE_MULTI_MODULE) {
    /* to indicate which module instance create it */
        WASMModuleInstance *owner;
    }
    /* Base address, the layout is:
       heap_data + memory data
       memory data init size is: num_bytes_per_page * cur_page_count
       Note: when memory is re-allocated, the heap data and memory data
             must be copied to new memory also.
     */
    ubyte[1] base_addr;
}

struct WASMTableInstance {
    /* The element type, TABLE_ELEM_TYPE_ANY_FUNC currently */
    ubyte elem_type;
    /* Current size */
    uint cur_size;
    /* Maximum size */
    uint max_size;
    version(WASM_ENABLE_MULTI_MODULE) {
    /* just for import, keep the reference here */
    WASMTableInstance *table_inst_linked;
    }
    /* Base address */
    ubyte[1] base_addr;
}

struct WASMGlobalInstance {
    /* value type, VALUE_TYPE_I32/I64/F32/F64 */
    ubyte type;
    /* mutable or constant */
    bool is_mutable;
    /* data offset to base_addr of WASMMemoryInstance */
    uint data_offset;
    /* initial value */
    WASMValue initial_value;
    version(WASM_ENABLE_MULTI_MODULE) {
    /* just for import, keep the reference here */
    WASMModuleInstance *import_module_inst;
    WASMGlobalInstance *import_global_inst;
    }
}

struct WASMFunctionInstance {
    /* whether it is import function or WASM function */
    bool is_import_func;
    /* parameter count */
    ushort param_count;
    /* local variable count, 0 for import function */
    ushort local_count;
    /* cell num of parameters */
    ushort param_cell_num;
    /* cell num of return type */
    ushort ret_cell_num;
    /* cell num of local variables, 0 for import function */
    ushort local_cell_num;
    version(WASM_ENABLE_FAST_INTERP) {
    /* cell num of consts */
    ushort const_cell_num;
    }
    ushort *local_offsets;
    /* parameter types */
    ubyte *param_types;
    /* local types, NULL for import function */
    ubyte *local_types;
    union U {
        WASMFunctionImport *func_import;
        WASMFunction *func;
    }
    U u;
    version(WASM_ENABLE_MULTI_MODULE) {
        WASMModuleInstance *import_module_inst;
        WASMFunctionInstance *import_func_inst;
    }
}

struct WASMExportFuncInstance {
    char *name;
    WASMFunctionInstance* func;
}

version(WASM_ENABLE_MULTI_MODULE) {
    struct WASMExportGlobInstance {
        char *name;
        WASMGlobalInstance *global;
    }
}

struct WASMExportTabInstance {
    char *name;
    WASMTableInstance *table;
}

struct WASMExportMemInstance {
    char *name;
    WASMMemoryInstance *memory;
}

struct WASMModuleInstance {
    /* Module instance type, for module instance loaded from
       WASM bytecode binary, this field is Wasm_Module_Bytecode;
       for module instance loaded from AOT file, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModuleInstance structure. */
    uint module_type; // CBR: Should be an enum

    uint memory_count;
    uint table_count;
    uint global_count;
    uint function_count;

    uint export_func_count;
    version(WASM_ENABLE_MULTI_MODULE) {
        uint export_glob_count;
        uint export_mem_count;
        uint export_tab_count;
    }

    WASMMemoryInstance **memories;
    WASMTableInstance **tables;
    WASMGlobalInstance *globals;
    WASMFunctionInstance[] functions;

    WASMExportFuncInstance *export_functions;
    version(WASM_ENABLE_MULTI_MODULE) {
        WASMExportGlobInstance *export_globals;
        WASMExportMemInstance *export_memories;
        WASMExportTabInstance *export_tables;
    }

    WASMMemoryInstance *default_memory;
    WASMTableInstance *default_table;
    /* Global data of global instances */
    ubyte *global_data;

    WASMFunctionInstance *start_function;

    WASMModule* wasm_module;

    version(WASM_ENABLE_LIBC_WASI) {
        WASIContext *wasi_ctx;
    }

    uint temp_ret;
    uint llvm_stack;

    /* Default WASM stack size of threads of this Module instance. */
    uint default_wasm_stack_size;

    /* The exception buffer of wasm interpreter for current thread. */
    char[128] cur_exception;

    /* The custom data that can be set/get by
     * wasm_set_custom_data/wasm_get_custom_data */
    void *custom_data;

    /* Main exec env */
    WASMExecEnv *main_exec_env;

    version(WASM_ENABLE_MULTI_MODULE) {
    // TODO: mutex ? mutli-threads ?
    bh_list sub_module_inst_list_head;
    bh_list *sub_module_inst_list;
    }
}

alias WASMRuntimeFrame = WASMInterpFrame;

version(WASM_ENABLE_MULTI_MODULE) {
    struct WASMSubModInstNode {
        bh_list_link l;
        /* point to a string pool */
        const char *module_name;
        WASMModuleInstance *module_inst;
    }
}

/**
 * Return the code block of a function.
 *
 * @param func the WASM function instance
 *
 * @return the code block of the function
 */
static ubyte*
wasm_get_func_code(WASMFunctionInstance *func)
{
    version(WASM_ENABLE_FAST_INTERP) {
    return func.is_import_func ? null : func.u.func.code;
    }
    else {
    return func.is_import_func ? null : func.u.func.code_compiled;
    }
}

/**
 * Return the code block end of a function.
 *
 * @param func the WASM function instance
 *
 * @return the code block end of the function
 */
static ubyte*
wasm_get_func_code_end(WASMFunctionInstance *func)
{
    version(WASM_ENABLE_FAST_INTERP) {
    return func.is_import_func
             ? null : func.u.func.code + func.u.func.code_size;
    }
    else {
    return func.is_import_func
             ? null
             : func.u.func.code_compiled + func.u.func.code_compiled_size;
    }
}

// WASMModule *
// wasm_load(const uint8 *buf, uint size,
//           char *error_buf, uint error_buf_size);

// WASMModule *
// wasm_load_from_sections(WASMSection *section_list,
//                         char *error_buf, uint_t error_buf_size);

// void
// wasm_unload(WASMModule *module);

// WASMModuleInstance *
// wasm_instantiate(WASMModule *module, bool is_sub_inst,
//                  uint stack_size, uint heap_size,
//                  char *error_buf, uint error_buf_size);

// void
// wasm_deinstantiate(WASMModuleInstance *module_inst, bool is_sub_inst);

// WASMFunctionInstance *
// wasm_lookup_function(const WASMModuleInstance *module_inst,
//                              const char *name, const char *signature);

// version(WASM_ENABLE_MULTI_MODULE) {
// WASMGlobalInstance *
// wasm_lookup_global(const WASMModuleInstance *module_inst, const char *name);

// WASMMemoryInstance *
// wasm_lookup_memory(const WASMModuleInstance *module_inst, const char *name);

// WASMTableInstance *
// wasm_lookup_table(const WASMModuleInstance *module_inst, const char *name);
// #endif

// bool
// wasm_call_function(WASMExecEnv *exec_env,
//                    WASMFunctionInstance *function,
//                    unsigned argc, uint argv[]);

// bool
// wasm_create_exec_env_and_call_function(WASMModuleInstance *module_inst,
//                                        WASMFunctionInstance *function,
//                                        unsigned argc, uint argv[]);

// void
// wasm_set_exception(WASMModuleInstance *module, const char *exception);

// const char*
// wasm_get_exception(WASMModuleInstance *module);

// int
// wasm_module_malloc(WASMModuleInstance *module_inst, uint size,
//                    void **p_native_addr);

// void
// wasm_module_free(WASMModuleInstance *module_inst, int ptr);

// int
// wasm_module_dup_data(WASMModuleInstance *module_inst,
//                      const char *src, uint size);

// bool
// wasm_validate_app_addr(WASMModuleInstance *module_inst,
//                        int app_offset, uint size);

// bool
// wasm_validate_app_str_addr(WASMModuleInstance *module_inst,
//                            int app_offset);

// bool
// wasm_validate_native_addr(WASMModuleInstance *module_inst,
//                           void *native_ptr, uint size);

// void *
// wasm_addr_app_to_native(WASMModuleInstance *module_inst,
//                         int app_offset);

// int
// wasm_addr_native_to_app(WASMModuleInstance *module_inst,
//                         void *native_ptr);

// bool
// wasm_get_app_addr_range(WASMModuleInstance *module_inst,
//                         int app_offset,
//                         int *p_app_start_offset,
//                         int *p_app_end_offset);

// bool
// wasm_get_native_addr_range(WASMModuleInstance *module_inst,
//                            uint8_t *native_ptr,
//                            uint8_t **p_native_start_addr,
//                            uint8_t **p_native_end_addr);

// bool
// wasm_enlarge_memory(WASMModuleInstance *module, uint inc_page_count);

// bool
// wasm_call_indirect(WASMExecEnv *exec_env,
//                    uint_t element_indices,
//                    uint_t argc, uint_t argv[]);

// #if WASM_ENABLE_THREAD_MGR != 0
// bool
// wasm_set_aux_stack(WASMExecEnv *exec_env,
//                    uint start_offset, uint size);

// bool
// wasm_get_aux_stack(WASMExecEnv *exec_env,
//                    uint *start_offset, uint *size);
// #endif

// #ifdef __cplusplus
// }
// #endif

// #endif /* end of _WASM_RUNTIME_H */

/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.tvm.wamr.wasm_runtime;
import tagion.tvm.wamr.wasm_loader;
//import tagion.tvm.wamr.wasm_interp;
import tagion.tvm.wamr.bh_common;
import tagion.tvm.wamr.bh_log;
//import tagion.tvm.wamr.mem_alloc;
import tagion.tvm.wamr.wasm_runtime_common;
version(WASM_ENABLE_SHARED_MEMORY) {
    import tagion.tvm.wamr.wasm_shared_memory;
}

static void
set_error_buf(char *error_buf, uint error_buf_size, const char *str)
{
    if (error_buf !is null) {
        snprintf(error_buf, error_buf_size, "%s", str);
    }
}

WASMModule*
wasm_load(const ubyte *buf, uint size,
          char *error_buf, uint error_buf_size)
{
    return wasm_loader_load(buf, size, error_buf, error_buf_size);
}

WASMModule*
wasm_load_from_sections(WASMSection *section_list,
                        char *error_buf, uint error_buf_size)
{
    return wasm_loader_load_from_sections(section_list,
                                          error_buf, error_buf_size);
}

void
wasm_unload(WASMModule *wasm_module)
{
    wasm_loader_unload(wasm_module);
}

static void *
runtime_malloc(ulong size, char *error_buf, uint error_buf_size)
{
    void *mem;

    if (size >= UINT32_MAX
        || !(mem = wasm_runtime_malloc(cast(uint32)size))) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module instantiate failed: " ~
                      "allocate memory failed.");
        return null;
    }

    memset(mem, 0, cast(uint32)size);
    return mem;
}

version(WASM_ENABLE_MULTI_MODULE) {
static WASMModuleInstance *
get_sub_module_inst(const WASMModuleInstance *parent_module_inst,
                    const WASMModule *sub_module)
{
    bh_list *sub_module_inst_list = parent_module_inst.sub_module_inst_list;
    WASMSubModInstNode *node = bh_list_first_elem(sub_module_inst_list);

    while (node && sub_module != node.module_inst.wasm_module) {
        node = bh_list_elem_next(node);
    }
    return node ? node.module_inst : NULL;
}
}

/**
 * Destroy memory instances.
 */
static void
memories_deinstantiate(WASMModuleInstance *module_inst,
                       WASMMemoryInstance **memories,
                       uint count)
{
    uint i;
    if (memories) {
        for (i = 0; i < count; i++)
            if (memories[i]) {
                version(WASM_ENABLE_MULTI_MODULE) {
                if (memories[i].owner != module_inst)
                    continue;
                }
                version(WASM_ENABLE_SHARED_MEMORY) {
                if (memories[i].is_shared) {
                    int ref_count =
                        shared_memory_dec_reference(
                            cast(WASMModuleCommon *)module_inst.wasm_module);
                    bh_assert(ref_count >= 0);

                    /* if the reference count is not zero,
                        don't free the memory */
                    if (ref_count > 0)
                        continue;
                }
                }
                if (memories[i].heap_handle) {
                    mem_allocator_destroy(memories[i].heap_handle);
                    memories[i].heap_handle = NULL;
                }
                wasm_runtime_free(memories[i]);
            }
        wasm_runtime_free(memories);
  }
  cast(void)module_inst;
}

static WASMMemoryInstance*
memory_instantiate(WASMModuleInstance *module_inst,
                   uint num_bytes_per_page,
                   uint init_page_count, uint max_page_count,
                   uint heap_size, uint flags,
                   char *error_buf, uint error_buf_size)
{
    WASMMemoryInstance *memory;
    uint64 heap_and_inst_size = offsetof(WASMMemoryInstance, base_addr) +
                                cast(uint64)heap_size;
    uint64 total_size = heap_and_inst_size +
                        num_bytes_per_page * cast(uint64)init_page_count;

    version(WASM_ENABLE_SHARED_MEMORY) {
        bool is_shared_memory = flags & 0x02 ? true : false;
    }
    else {
        enum is_shared_memory = false;
    }
    /* shared memory */
    if (is_shared_memory) {
        WASMSharedMemNode *node =
            wasm_module_get_shared_memory(
                cast(WASMModuleCommon *)module_inst.wasm_module);
        /* If the memory of this module has been instantiated,
            return the memory instance directly */
        if (node) {
            uint ref_count;
            ref_count = shared_memory_inc_reference(
                            cast(WASMModuleCommon *)module_inst.wasm_module);
            bh_assert(ref_count > 0);
            memory = shared_memory_get_memory_inst(node);
            bh_assert(memory);

            cast(void)ref_count;
            return memory;
        }
        /* Allocate max page for shared memory */
        total_size = heap_and_inst_size +
                     num_bytes_per_page * cast(uint64)max_page_count;
    }


    /* Allocate memory space, addr data and global data */
    memory = runtime_malloc(total_size,
        error_buf, error_buf_size);
    if (!(memory)) {
        return null;
    }

    memory.num_bytes_per_page = num_bytes_per_page;
    memory.cur_page_count = init_page_count;
    memory.max_page_count = max_page_count;

    memory.heap_data = memory.base_addr;
    memory.memory_data = memory.heap_data + heap_size;
    if (WASM_ENABLE_SHARED_MEMORY && is_shared_memory) {
        memory.end_addr = memory.memory_data +
                           num_bytes_per_page * memory.max_page_count;
    }
    else
    {
        memory.end_addr = memory.memory_data +
                           num_bytes_per_page * memory.cur_page_count;
    }

    bh_assert(memory.end_addr - cast(ubyte*)memory == cast(uint)total_size);

    /* Initialize heap */
    if (heap_size > 0
        && !(memory.heap_handle =
               mem_allocator_create(memory.heap_data, heap_size))) {
        wasm_runtime_free(memory);
        return NULL;
    }

    memory.heap_base_offset = -cast(int)heap_size;

    version(WASM_ENABLE_SHARED_MEMORY) {
    if (is_shared_memory) {
        memory.is_shared = true;
        if (!shared_memory_set_memory_inst(
                cast(WASMModuleCommon *)module_inst.wasm_module, memory)) {
            set_error_buf(error_buf, error_buf_size,
                          "Instantiate memory failed:" ~
                          "allocate memory failed.");
            wasm_runtime_free(memory);
            return NULL;
        }
    }
    }
    return memory;
}

/**
 * Instantiate memories in a module.
 */
static WASMMemoryInstance **
memories_instantiate(const WASMModule *wasm_module,
                     WASMModuleInstance *module_inst,
                     uint heap_size, char *error_buf, uint error_buf_size)
{
    WASMImport *wasm_import;
    uint mem_index = 0, i, memory_count =
        wasm_module.import_memory_count + wasm_module.memory_count;
    uint64 total_size;
    WASMMemoryInstance** memories;
    WASMMemoryInstance* memory;

    total_size = (WASMMemoryInstance*).sizeof * cast(uint64)memory_count;

    if (!(memories = runtime_malloc(total_size,
                                    error_buf, error_buf_size))) {
        return null;
    }

    /* instantiate memories from import section */
    wasm_import = wasm_module.import_memories;
    for (i = 0; i < wasm_module.import_memory_count; i++, wasm_import++) {
        uint num_bytes_per_page = wasm_import.u.memory.num_bytes_per_page;
        uint init_page_count = wasm_import.u.memory.init_page_count;
        uint max_page_count = wasm_import.u.memory.max_page_count;
        uint flags = wasm_import.u.memory.flags;
        uint actual_heap_size = heap_size;

        version(WASM_ENABLE_MULTI_MODULE) {
        WASMMemoryInstance *memory_inst_linked = null;
}
        if (WASM_ENABLE_MULTI_MODULE && wasm_import.u.memory.import_module !is null) {
            LOG_DEBUG("(%s, %s) is a memory of a sub-module",
                wasm_import.u.memory.module_name,
                wasm_import.u.memory.field_name);

            // TODO: how about native memory ?
            WASMModuleInstance *module_inst_linked =
              get_sub_module_inst(
                  module_inst,
                  wasm_import.u.memory.import_module);
            bh_assert(module_inst_linked);

            memory_inst_linked =
              wasm_lookup_memory(module_inst_linked,
                                 wasm_import.u.memory.field_name);
            bh_assert(memory_inst_linked);

            memories[mem_index++] = memory_inst_linked;
            memory = memory_inst_linked;
        }
        else {
            if (!(memory = memories[mem_index++] = memory_instantiate(
                    module_inst, num_bytes_per_page, init_page_count,
                    max_page_count, actual_heap_size, flags,
                    error_buf, error_buf_size))) {
                set_error_buf(error_buf, error_buf_size,
                              "Instantiate memory failed: " ~
                              "allocate memory failed.");
                memories_deinstantiate(
                  module_inst,
                  memories, memory_count);
                return NULL;
            }
        }
    }

    /* instantiate memories from memory section */
    for (i = 0; i < wasm_module.memory_count; i++) {
        if (!(memory = memories[mem_index++] =
                    memory_instantiate(module_inst,
                                       wasm_module.memories[i].num_bytes_per_page,
                                       wasm_module.memories[i].init_page_count,
                                       wasm_module.memories[i].max_page_count,
                        heap_size, wasm_module.memories[i].flags,
                                       error_buf, error_buf_size))) {
            set_error_buf(error_buf, error_buf_size,
                          "Instantiate memory failed: " ~
                          "allocate memory failed.");
            memories_deinstantiate(
              module_inst,
              memories, memory_count);
            return null;
        }
 version(WASM_ENABLE_MULTI_MODULE) {
     memory.owner = module_inst;
 }
    }

    if (mem_index == 0) {
        /**
         * no import memory and define memory, but still need heap
         * for wasm code
         */
        if (!(memory = memories[mem_index++] =
                    memory_instantiate(module_inst, 0, 0, 0, heap_size, 0,
                                       error_buf, error_buf_size))) {
            set_error_buf(error_buf, error_buf_size,
                          "Instantiate memory failed: " ~
                          "allocate memory failed.\n");
            memories_deinstantiate(module_inst, memories, memory_count);
            return NULL;
        }
    }

    bh_assert(mem_index == memory_count);
//    (void)module_inst;
    return memories;
}

/**
 * Destroy table instances.
 */
static void
tables_deinstantiate(WASMTableInstance **tables, uint count)
{
    uint i;
    if (tables) {
        for (i = 0; i < count; i++)
            if (tables[i])
                wasm_runtime_free(tables[i]);
        wasm_runtime_free(tables);
    }
}

/**
 * Instantiate tables in a module.
 */
static WASMTableInstance **
tables_instantiate(const WASMModule *wasm_module,
                   WASMModuleInstance *module_inst,
                   char *error_buf, uint error_buf_size)
{
    WASMImport *wasm_import;
    uint table_index = 0, i, table_count =
        wasm_module.import_table_count + wasm_module.table_count;
    uint64 total_size = (WASMTableInstance*).sizeof * cast(uint64)table_count;
    WASMTableInstance** tables;
    WASMTableInstance* table;
    // tables = runtime_malloc(total_size,
    //     error_buf, error_buf_size))) {

    if ((!(tables = runtime_malloc(total_size,
                    error_buf, error_buf_size)))) {
        return null;
    }

    /* instantiate tables from import section */
    wasm_import = wasm_module.import_tables;
    for (i = 0; i < wasm_module.import_table_count; i++, wasm_import++) {
        version(WASM_ENABLE_MULTI_MODULE) {
        WASMTableInstance *table_inst_linked = NULL;
        WASMModuleInstance *module_inst_linked = NULL;
        }
        if (WASM_ENABLE_MULTI_MODULE && wasm_import.u.table.import_module) {
            LOG_DEBUG("(%s, %s) is a table of a sub-module",
                      wasm_import.u.table.module_name,
                      wasm_import.u.memory.field_name);

            module_inst_linked =
              get_sub_module_inst(module_inst, wasm_import.u.table.import_module);
            bh_assert(module_inst_linked);

            table_inst_linked = wasm_lookup_table(module_inst_linked,
                                                  wasm_import.u.table.field_name);
            bh_assert(table_inst_linked);

            total_size = offsetof(WASMTableInstance, base_addr);
        }
        else
        {
            /* it is a built-in table */
            total_size = offsetof(WASMTableInstance, base_addr)
                + uint.sizeof * cast(uint64)wasm_import.u.table.init_size;
        }

        if (!(table = tables[table_index++] = runtime_malloc
                    (total_size, error_buf, error_buf_size))) {
            tables_deinstantiate(tables, table_count);
            return null;
        }

        /* Set all elements to -1 to mark them as uninitialized elements */
        memset(table, -1, cast(uint)total_size);
        version(WASM_ENABLE_MULTI_MODULE) {
        table.table_inst_linked = table_inst_linked;
        }
        if (WASM_ENABLE_MULTI_MODULE && table_inst_linked != NULL) {
            table.elem_type = table_inst_linked.elem_type;
            table.cur_size = table_inst_linked.cur_size;
            table.max_size = table_inst_linked.max_size;
        }
        else
        {
            table.elem_type = wasm_import.u.table.elem_type;
            table.cur_size = wasm_import.u.table.init_size;
            table.max_size = wasm_import.u.table.max_size;
        }
    }

    /* instantiate tables from table section */
    for (i = 0; i < wasm_module.table_count; i++) {
        total_size = offsetof(WASMTableInstance, base_addr) +
                     uint.sizeof * cast(uint64)wasm_module.tables[i].init_size;
        if (!(table = tables[table_index++] = runtime_malloc
                    (total_size, error_buf, error_buf_size))) {
            tables_deinstantiate(tables, table_count);
            return null;
        }

        /* Set all elements to -1 to mark them as uninitialized elements */
        memset(table, -1, cast(uint)total_size);
        table.elem_type = wasm_module.tables[i].elem_type;
        table.cur_size = wasm_module.tables[i].init_size;
        table.max_size = wasm_module.tables[i].max_size;
        version(WASM_ENABLE_MULTI_MODULE) {
        table.table_inst_linked = null;
        }
    }

    bh_assert(table_index == table_count);
//    (void)module_inst;
    return tables;
}

/**
 * Destroy function instances.
 */
static void
functions_deinstantiate(WASMFunctionInstance *functions, uint count)
{
    if (functions) {
        wasm_runtime_free(functions);
    }
}

/**
 * Instantiate functions in a module.
 */
static WASMFunctionInstance *
functions_instantiate(const WASMModule *wasm_module,
                      WASMModuleInstance *module_inst,
                      char *error_buf, uint error_buf_size)
{
    WASMImport *wasm_import;
    uint i, function_count =
        wasm_module.import_function_count + wasm_module.function_count;
    uint64 total_size = WASMFunctionInstance.sizeof * cast(uint64)function_count;
    WASMFunctionInstance* functions, func;

    if (!(functions = runtime_malloc(total_size,
                                     error_buf, error_buf_size))) {
        return NULL;
    }

    /* instantiate functions from import section */
    func = functions;
    wasm_import = wasm_module.import_functions;
    for (i = 0; i < wasm_module.import_function_count; i++, wasm_import++) {
        func.is_import_func = true;

        if (WASM_ENABLE_MULTI_MODULE && wasm_import.u.func.import_module) {
            LOG_DEBUG("(%s, %s) is a function of a sub-module",
                      wasm_import.u.func.module_name,
                      wasm_import.u.func.field_name);

            func.import_module_inst =
              get_sub_module_inst(module_inst,
                  wasm_import.u.func.import_module);
            bh_assert(func.import_module_inst);

            WASMFunction *function_linked =
              wasm_import.u.func.import_func_linked;

            func.u.func = function_linked;
            func.import_func_inst =
              wasm_lookup_function(func.import_module_inst,
                                   wasm_import.u.func.field_name,
                                   null);
            bh_assert(func.import_func_inst);

            func.param_cell_num = func.u.func.param_cell_num;
            func.ret_cell_num = func.u.func.ret_cell_num;
            func.local_cell_num = func.u.func.local_cell_num;
            func.param_count =
              cast(ushort)func.u.func.func_type.param_count;
            func.local_count = cast(ushort)func.u.func.local_count;
            func.param_types = func.u.func.func_type.types;
            func.local_types = func.u.func.local_types;
            func.local_offsets = func.u.func.local_offsets;
            version(WASM_ENABLE_FAST_INTERP) {
            func.const_cell_num = func.u.func.const_cell_num;
            }
        }
        else
        {
            LOG_DEBUG("(%s, %s) is a function of native",
                      wasm_import.u.func.module_name,
                      wasm_import.u.func.field_name);
            func.u.func_import = &wasm_import.u.func;
            func.param_cell_num =
              wasm_import.u.func.func_type.param_cell_num;
            func.ret_cell_num =
              wasm_import.u.func.func_type.ret_cell_num;
            func.param_count =
              cast(ushort)func.u.func_wasm_import.func_type.param_count;
            func.param_types = func.u.func_wasm_import.func_type.types;
            func.local_cell_num = 0;
            func.local_count = 0;
            func.local_types = NULL;
        }

        func++;
    }

    /* instantiate functions from function section */
    for (i = 0; i < wasm_module.function_count; i++) {
        func.is_import_func = false;
        func.u.func = wasm_module.functions[i];

        func.param_cell_num = func.u.func.param_cell_num;
        func.ret_cell_num = func.u.func.ret_cell_num;
        func.local_cell_num = func.u.func.local_cell_num;

        func.param_count = cast(ushort)func.u.func.func_type.param_count;
        func.local_count = cast(ushort)func.u.func.local_count;
        func.param_types = func.u.func.func_type.types;
        func.local_types = func.u.func.local_types;

        func.local_offsets = func.u.func.local_offsets;

        version(WASM_ENABLE_FAST_INTERP) {
            func.const_cell_num = func.u.func.const_cell_num;
        }

        func++;
    }

    bh_assert(cast(uint)(func - functions) == function_count);
//    (void)module_inst;
    return functions;
}

/**
 * Destroy global instances.
 */
static void
globals_deinstantiate(WASMGlobalInstance *globals)
{
    if (globals) {
        wasm_runtime_free(globals);
    }
}

/**
 * init_expr.u ==> init_val
 */
static bool
parse_init_expr(const InitializerExpression *init_expr,
                const WASMGlobalInstance *global_inst_array,
                uint boundary, WASMValue *init_val)
{
    if (init_expr.init_expr_type == INIT_EXPR_TYPE_GET_GLOBAL) {
        uint target_global_index = init_expr.u.global_index;
        /**
         * a global gets the init value of another global
         */
        if (target_global_index >= boundary) {
            LOG_DEBUG("unknown target global, %d", target_global_index);
            return false;
        }

        /**
         * it will work if using WASMGlobalImport and WASMGlobal in
         * WASMModule, but will have to face complicated cases
         *
         * but we still have no sure the target global has been
         * initialized before
         */
        WASMValue target_value =
          global_inst_array[target_global_index].initial_value;
        bh_memcpy_s(init_val, WASMValue.sizeof, &target_value,
            target_value.sizeof);
    }
    else {
        bh_memcpy_s(init_val, WASMValue.sizeof, &init_expr.u,
                    init_expr.u.sizeof);
    }
    return true;
}

/**
 * Instantiate globals in a module.
 */
static WASMGlobalInstance*
globals_instantiate(const WASMModule *wasm_module,
                    WASMModuleInstance *module_inst,
                    uint *p_global_data_size, char *error_buf,
                    uint error_buf_size)
{
    WASMImport *wasm_import;
    uint global_data_offset = 0;
    uint i, global_count =
        wasm_module.import_global_count + wasm_module.global_count;
    uint64 total_size = WASMGlobalInstance.sizeof * cast(uint64)global_count;
    WASMGlobalInstance* globals, global;

    if (!(globals = runtime_malloc(total_size,
                                   error_buf, error_buf_size))) {
        return null;
    }

    /* instantiate globals from import section */
    global = globals;
    wasm_import = wasm_module.import_globals;
    for (i = 0; i < wasm_module.import_global_count; i++, wasm_import++) {
        WASMGlobalImport *global_import = &wasm_import.u.global;
        global.type = global_import.type;
        global.is_mutable = global_import.is_mutable;
        if (WASM_ENABLE_MULTI_MODULE && global_import.import_module) {
            WASMModuleInstance *sub_module_inst = get_sub_module_inst(
              module_inst, global_import.import_module);
            bh_assert(sub_module_inst);

            WASMGlobalInstance *global_inst_linked =
              wasm_lookup_global(sub_module_inst, global_import.field_name);
            bh_assert(global_inst_linked);

            global.import_global_inst = global_inst_linked;
            global.import_module_inst = sub_module_inst;

            /**
             * although, actually don't need initial_value for an imported
             * global, we keep it here like a place holder because of
             * global-data and
             * (global $g2 i32 (global.get $g1))
             */
            WASMGlobal *linked_global = global_import.import_global_linked;
            InitializerExpression *linked_init_expr =
              &(linked_global.init_expr);

            bool ret = parse_init_expr(
              linked_init_expr,
              sub_module_inst.globals,
              sub_module_inst.global_count, &(global.initial_value));
            if (!ret) {
                set_error_buf(error_buf, error_buf_size,
                              "Instantiate global failed: unknown global.");
                return null;
            }
        }
        else
        {
            /* native globals share their initial_values in one module */
            global.initial_value = global_import.global_data_linked;
        }
        global.data_offset = global_data_offset;
        global_data_offset += wasm_value_type_size(global.type);

        global++;
    }

    /* instantiate globals from global section */
    for (i = 0; i < wasm_module.global_count; i++) {
        bool ret = false;
        uint global_count =
          wasm_module.import_global_count + wasm_module.global_count;
        InitializerExpression *init_expr = &(wasm_module.globals[i].init_expr);

        global.type = wasm_module.globals[i].type;
        global.is_mutable = wasm_module.globals[i].is_mutable;
        global.data_offset = global_data_offset;

        global_data_offset += wasm_value_type_size(global.type);

        /**
         * first init, it might happen that the target global instance
         * has not been initialize yet
         */
        if (init_expr.init_expr_type != INIT_EXPR_TYPE_GET_GLOBAL) {
            ret =
              parse_init_expr(init_expr, globals, global_count,
                              &(global.initial_value));
            if (!ret) {
                set_error_buf(error_buf, error_buf_size,
                              "Instantiate global failed: unknown global.");
                return NULL;
            }
        }
        global++;
    }

    bh_assert(cast(uint)(global - globals) == global_count);
    *p_global_data_size = global_data_offset;
    //(void)module_inst;
    return globals;
}

static bool
globals_instantiate_fix(WASMGlobalInstance *globals,
                        const WASMModule *wasm_module,
                        char *error_buf, uint error_buf_size)
{
    WASMGlobalInstance *global = globals;
    uint i;
    uint global_count = wasm_module.import_global_count + wasm_module.global_count;

    /**
     * second init, only target global instances from global
     * (ignore import_global)
     * to fix skipped init_value in the previous round
     * hope two rounds are enough but how about a chain ?
     */
    for (i = 0; i < wasm_module.global_count; i++) {
        bool ret = false;
        InitializerExpression *init_expr = &wasm_module.globals[i].init_expr;

        if (init_expr.init_expr_type == INIT_EXPR_TYPE_GET_GLOBAL) {
            ret = parse_init_expr(init_expr, globals, global_count,
                                  &global.initial_value);
            if (!ret) {
                set_error_buf(error_buf, error_buf_size,
                              "Instantiate global failed: unknown global.");
                return false;
            }
        }

        global++;
    }
    return true;
}

/**
 * Return export function count in module export section.
 */
static uint
get_export_count(const WASMModule *wasm_module, ubyte kind)
{
    WASMExport *wasm_export = wasm_module.exports;
    uint count = 0, i;

    for (i = 0; i < wasm_module.export_count; i++, wasm_export++)
        if (wasm_export.kind == kind)
            count++;

    return count;
}

/**
 * Destroy export function instances.
 */
static void
export_functions_deinstantiate(WASMExportFuncInstance *functions)
{
    if (functions)
        wasm_runtime_free(functions);
}

/**
 * Instantiate export functions in a module.
 */
static WASMExportFuncInstance*
export_functions_instantiate(const WASMModule *wasm_module,
                             WASMModuleInstance *module_inst,
                             uint export_func_count,
                             char *error_buf, uint error_buf_size)
{
    WASMExportFuncInstance *export_funcs, export_func;
    WASMExport *wasm_export = wasm_module.exports;
    uint i;
    uint64 total_size = WASMExportFuncInstance.sizeof * cast(uint64)export_func_count;

    if (!(export_func = export_funcs = runtime_malloc
                (total_size, error_buf, error_buf_size))) {
        return NULL;
    }

    for (i = 0; i < wasm_module.export_count; i++, wasm_export++)
        if (wasm_export.kind == EXPORT_KIND_FUNC) {
            export_func.name = wasm_export.name;
            export_func.func = &module_inst.functions[wasm_export.index];
            export_func++;
        }


    bh_assert(cast(uint)(export_func - export_funcs) == export_func_count);
    return export_funcs;
}

version(WASM_ENABLE_MULTI_MODULE) {
static void
export_globals_deinstantiate(WASMExportGlobInstance *globals)
{
    if (globals)
        wasm_runtime_free(globals);
}

static WASMExportGlobInstance *
export_globals_instantiate(const WASMModule *wasm_module,
                          WASMModuleInstance *module_inst,
                          uint export_glob_count, char *error_buf,
                          uint error_buf_size)
{
    WASMExportGlobInstance *export_globals, export_global;
    WASMExport *wasm_export = wasm_module.exports;
    uint i;
    uint64 total_size = WASMExportGlobInstance.sizeof * cast(uint64)export_glob_count;

    if (!(export_global = export_globals = runtime_malloc
                (total_size, error_buf, error_buf_size))) {
        return NULL;
    }

    for (i = 0; i < wasm_module.export_count; i++, wasm_export++)
        if (wasm_export.kind == EXPORT_KIND_GLOBAL) {
            export_global.name = wasm_export.name;
            export_global.global = &module_inst.globals[wasm_export.index];
            export_global++;
        }

    bh_assert(cast(uint)(export_global - export_globals) == export_glob_count);
    return export_globals;
}
}

static bool
execute_post_inst_function(WASMModuleInstance *module_inst)
{
    WASMFunctionInstance *post_inst_func = NULL;
    WASMType *post_inst_func_type;
    uint i;

    for (i = 0; i < module_inst.export_func_count; i++)
        if (!strcmp(module_inst.export_functions[i].name, "__post_instantiate")) {
            post_inst_func = module_inst.export_functions[i].func;
            break;
        }

    if (!post_inst_func) {
        /* Not found */
        return true;
    }

    post_inst_func_type = post_inst_func.u.func.func_type;
    if (post_inst_func_type.param_count != 0
        || post_inst_func_type.result_count != 0) {
        /* Not a valid function type, ignore it */
        return true;
    }
    return wasm_create_exec_env_and_call_function(module_inst, post_inst_func,
                                                  0, null);
}

version(WASM_ENABLE_BULK_MEMORY) {
static bool
execute_memory_init_function(WASMModuleInstance *module_inst)
{
    WASMFunctionInstance *memory_init_func = NULL;
    WASMType *memory_init_func_type;
    uint i;

    for (i = 0; i < module_inst.export_func_count; i++)
        if (!strcmp(module_inst.export_functions[i].name, "__wasm_call_ctors")) {
            memory_init_func = module_inst.export_functions[i].func;
            break;
        }

    if (!memory_init_func) {
        /* Not found */
        return true;
    }

    memory_init_func_type = memory_init_func.u.func.func_type;
    if (memory_init_func_type.param_count != 0
        || memory_init_func_type.result_count != 0) {
        /* Not a valid function type, ignore it */
        return true;
    }
    return wasm_create_exec_env_and_call_function(module_inst,
                                                  memory_init_func,
                                                  0, NULL);
}
}

static bool
execute_start_function(WASMModuleInstance *module_inst)
{
    WASMFunctionInstance *func = module_inst.start_function;

    if (!func)
        return true;

    bh_assert(!func.is_import_func && func.param_cell_num == 0
              && func.ret_cell_num == 0);

    return wasm_create_exec_env_and_call_function(module_inst, func, 0, NULL);
}

version(WASM_ENABLE_MULTI_MODULE) {
static bool
sub_module_instantiate(WASMModule *wasm_module, WASMModuleInstance *module_inst,
                          uint stack_size, uint heap_size, char *error_buf,
                          uint error_buf_size)
{
    bh_list *sub_module_inst_list = module_inst.sub_module_inst_list;
    WASMRegisteredModule *sub_module_list_node =
      bh_list_first_elem(wasm_module.import_module_list);

    while (sub_module_list_node) {
        WASMModule *sub_module = cast(WASMModule*)sub_module_list_node.wasm_module;
        WASMModuleInstance *sub_module_inst = wasm_instantiate(
          sub_module, false, stack_size, heap_size, error_buf, error_buf_size);
        if (!sub_module_inst) {
            LOG_DEBUG("instantiate %s failed",
                      sub_module_list_node.module_name);
            set_error_buf_v(error_buf, error_buf_size, "instantiate %s failed",
                            sub_module_list_node.module_name);
            return false;
        }

        WASMSubModInstNode *sub_module_inst_list_node = runtime_malloc
            (sizeof(WASMSubModInstNode), error_buf, error_buf_size);
        if (!sub_module_inst_list_node) {
            LOG_DEBUG("Malloc WASMSubModInstNode failed, SZ:%d",
                      sizeof(WASMSubModInstNode));
            wasm_deinstantiate(sub_module_inst, false);
            return false;
        }

        sub_module_inst_list_node.module_inst = sub_module_inst;
        sub_module_inst_list_node.module_name =
          sub_module_list_node.module_name;
        bh_list_status ret =
          bh_list_insert(sub_module_inst_list, sub_module_inst_list_node);
        bh_assert(BH_LIST_SUCCESS == ret);
        //(void)ret;

        sub_module_list_node = bh_list_elem_next(sub_module_list_node);
    }

    return true;
}

static void
sub_module_deinstantiate(WASMModuleInstance *module_inst)
{
    bh_list *list = module_inst.sub_module_inst_list;
    WASMSubModInstNode *node = bh_list_first_elem(list);
    while (node) {
        WASMSubModInstNode *next_node = bh_list_elem_next(node);
        bh_list_remove(list, node);
        wasm_deinstantiate(node.module_inst, false);
        node = next_node;
    }
}
}

/**
 * Instantiate module
 */
WASMModuleInstance*
wasm_instantiate(WASMModule *wasm_module, bool is_sub_inst,
                 uint stack_size, uint heap_size,
                 char *error_buf, uint error_buf_size)
{
    WASMModuleInstance *module_inst;
    WASMGlobalInstance *globals = null, global;
    uint global_count, global_data_size = 0, i;
    uint base_offset, length;
    ubyte *global_data, global_data_end;
    version(WASM_ENABLE_MULTI_MODULE) {
    bool ret = false;
    }

    if (!wasm_module) {
        return null;
    }

    /* Check heap size */
    heap_size = align_uint(heap_size, 8);
    if (heap_size > APP_HEAP_SIZE_MAX)
        heap_size = APP_HEAP_SIZE_MAX;

    /* Allocate the memory */
    if (!(module_inst = runtime_malloc(WASMModuleInstance.sizeof,
                                       error_buf, error_buf_size))) {
        return NULL;
    }

    LOG_DEBUG("Instantiate a module %p . %p", wasm_module, module_inst);

    memset(module_inst, 0, cast(uint)WASMModuleInstance.sizeof);

    module_inst.wasm_module = wasm_module;

    version(WASM_ENABLE_MULTI_MODULE) {
    module_inst.sub_module_inst_list =
      &module_inst.sub_module_inst_list_head;
    ret = sub_module_instantiate(wasm_module, module_inst, stack_size, heap_size,
                                 error_buf, error_buf_size);
    if (!ret) {
        LOG_DEBUG("build a sub module list failed");
        wasm_deinstantiate(module_inst, false);
        return NULL;
    }
    }

    /* Instantiate global firstly to get the mutable data size */
    global_count = wasm_module.import_global_count + wasm_module.global_count;
    if (global_count && !(globals = globals_instantiate(
                            wasm_module,
                            module_inst,
                            &global_data_size, error_buf, error_buf_size))) {
        wasm_deinstantiate(module_inst, false);
        return NULL;
    }
    module_inst.global_count = global_count;
    module_inst.globals = globals;

    module_inst.memory_count =
        wasm_module.import_memory_count + wasm_module.memory_count;
    module_inst.table_count =
        wasm_module.import_table_count + wasm_module.table_count;
    module_inst.function_count =
        wasm_module.import_function_count + wasm_module.function_count;

    /* export */
    module_inst.export_func_count = get_export_count(wasm_module, EXPORT_KIND_FUNC);
    version(WASM_ENABLE_MULTI_MODULE) {
    module_inst.export_tab_count = get_export_count(wasm_module, EXPORT_KIND_TABLE);
    module_inst.export_mem_count = get_export_count(wasm_module, EXPORT_KIND_MEMORY);
    module_inst.export_glob_count = get_export_count(wasm_module, EXPORT_KIND_GLOBAL);
    }

    if (global_count > 0) {
        if (!(module_inst.global_data = runtime_malloc
                    (global_data_size, error_buf, error_buf_size))) {
            wasm_deinstantiate(module_inst, false);
            return NULL;
        }
    }
    version(WASM_ENABLE_MULTI_MODULE) {
        const multi_flag = (module_inst.export_glob_count > 0
            && !(module_inst.export_globals = export_globals_instantiate(
                    wasm_module, module_inst, module_inst.export_glob_count,
                    error_buf, error_buf_size)));
    }

    /* Instantiate memories/tables/functions */
    if ((module_inst.memory_count > 0
         && !(module_inst.memories =
                memories_instantiate(wasm_module,
                                     module_inst,
                                     heap_size, error_buf, error_buf_size)))
        || (module_inst.table_count > 0
            && !(module_inst.tables =
                   tables_instantiate(wasm_module,
                                      module_inst,
                                      error_buf, error_buf_size)))
        || (module_inst.function_count > 0
            && !(module_inst.functions =
                   functions_instantiate(wasm_module,
                                         module_inst,
                                         error_buf, error_buf_size)))
        || (module_inst.export_func_count > 0
            && !(module_inst.export_functions = export_functions_instantiate(
                    wasm_module, module_inst, module_inst.export_func_count,
                   error_buf, error_buf_size)))
        || multi_flag
    ) {
        wasm_deinstantiate(module_inst, false);
        return null;
    }

    if (global_count > 0) {
        /**
         * since there might be some globals are not instantiate the first
         * instantiate round
         */
        if (!globals_instantiate_fix(globals, wasm_module,
                                     error_buf, error_buf_size)) {
            wasm_deinstantiate(module_inst, false);
            return NULL;
        }

        /* Initialize the global data */
        global_data = module_inst.global_data;
        global_data_end = global_data + global_data_size;
        global = globals;
        for (i = 0; i < global_count; i++, global++) {
            switch (global.type) {
                case VALUE_TYPE_I32:
                case VALUE_TYPE_F32:
                    *cast(int*)global_data = global.initial_value.i32;
                    global_data += int.sizeof;
                    break;
                case VALUE_TYPE_I64:
                case VALUE_TYPE_F64:
                    bh_memcpy_s(global_data, cast(uint)(global_data_end - global_data),
                                &global.initial_value.i64, int64.sizeof);
                    global_data += int64.sizeof;
                    break;
                default:
                    bh_assert(0);
            }
        }
        bh_assert(global_data == global_data_end);
    }

    /* Initialize the memory data with data segment section */
    module_inst.default_memory =
      module_inst.memory_count ? module_inst.memories[0] : NULL;

    for (i = 0; i < wasm_module.data_seg_count; i++) {
        WASMMemoryInstance *memory = NULL;
        ubyte *memory_data = NULL;
        uint memory_size = 0;
        WASMDataSeg *data_seg = wasm_module.data_segments[i];

        version(WASM_ENABLE_BULK_MEMORY) {
        if (data_seg.is_passive)
            continue;
        }

        /* has check it in loader */
        memory = module_inst.memories[data_seg.memory_index];
        bh_assert(memory);

        memory_data = memory.memory_data;
        bh_assert(memory_data);

        memory_size = memory.num_bytes_per_page * memory.cur_page_count;

        bh_assert(data_seg.base_offset.init_expr_type
                    == INIT_EXPR_TYPE_I32_CONST
                  || data_seg.base_offset.init_expr_type
                       == INIT_EXPR_TYPE_GET_GLOBAL);

        if (data_seg.base_offset.init_expr_type
            == INIT_EXPR_TYPE_GET_GLOBAL) {
            bh_assert(data_seg.base_offset.u.global_index < global_count
                        && globals[data_seg.base_offset.u.global_index].type
                            == VALUE_TYPE_I32);
            data_seg.base_offset.u.i32 =
                globals[data_seg.base_offset.u.global_index]
                .initial_value.i32;
        }

        /* check offset since length might negative */
        base_offset = cast(uint)data_seg.base_offset.u.i32;
        if (base_offset > memory_size) {
            LOG_DEBUG("base_offset(%d) > memory_size(%d)", base_offset,
                      memory_size);
            set_error_buf(error_buf, error_buf_size,
                          "data segment does not fit.");
            wasm_deinstantiate(module_inst, false);
            return NULL;
        }

        /* check offset + length(could be zero) */
        length = data_seg.data_length;
        if (base_offset + length > memory_size) {
            LOG_DEBUG("base_offset(%d) + length(%d) > memory_size(%d)",
                      base_offset, length, memory_size);
            set_error_buf(
              error_buf, error_buf_size,
              "Instantiate module failed: data segment does not fit.");
            wasm_deinstantiate(module_inst, false);
            return NULL;
        }

        bh_memcpy_s(memory_data + base_offset, memory_size - base_offset,
                    data_seg.data, length);
    }

    /* Initialize the table data with table segment section */
    module_inst.default_table =
      module_inst.table_count ? module_inst.tables[0] : NULL;
    for (i = 0; i < wasm_module.table_seg_count; i++) {
        WASMTableSeg *table_seg = wasm_module.table_segments + i;
        /* has check it in loader */
        WASMTableInstance *table = module_inst.tables[table_seg.table_index];
        bh_assert(table);

        uint *table_data = cast(uint *)table.base_addr;
        version(WASM_ENABLE_MULTI_MODULE) {
        table_data = table.table_inst_linked
                        ? cast(uint *)table.table_inst_linked.base_addr
                        : table_data;
        }
        bh_assert(table_data);

        /* init vec(funcidx) */
        bh_assert(table_seg.base_offset.init_expr_type
                    == INIT_EXPR_TYPE_I32_CONST
                  || table_seg.base_offset.init_expr_type
                       == INIT_EXPR_TYPE_GET_GLOBAL);

        if (table_seg.base_offset.init_expr_type
            == INIT_EXPR_TYPE_GET_GLOBAL) {
            bh_assert(table_seg.base_offset.u.global_index < global_count
                      && globals[table_seg.base_offset.u.global_index].type
                           == VALUE_TYPE_I32);
            table_seg.base_offset.u.i32 =
              globals[table_seg.base_offset.u.global_index].initial_value.i32;
        }

        /* check offset since length might negative */
        if (cast(uint)table_seg.base_offset.u.i32 > table.cur_size) {
            LOG_DEBUG("base_offset(%d) > table.cur_size(%d)",
                      table_seg.base_offset.u.i32, table.cur_size);
            set_error_buf(error_buf, error_buf_size,
                          "elements segment does not fit");
            wasm_deinstantiate(module_inst, false);
            return NULL;
        }

        /* check offset + length(could be zero) */
        length = table_seg.function_count;
        if (cast(uint)table_seg.base_offset.u.i32 + length > table.cur_size) {
            LOG_DEBUG("base_offset(%d) + length(%d)> table.cur_size(%d)",
                      table_seg.base_offset.u.i32, length, table.cur_size);
            set_error_buf(error_buf, error_buf_size,
                          "elements segment does not fit");
            wasm_deinstantiate(module_inst, false);
            return NULL;
        }

        /**
         * Check function index in the current module inst for now.
         * will check the linked table inst owner in future.
         * so loader check is enough
         */
        bh_memcpy_s(
          table_data + table_seg.base_offset.u.i32,
          cast(uint)((table.cur_size - cast(uint)table_seg.base_offset.u.i32)
              * uint.sizeof),
          table_seg.func_indexes, cast(uint)(length * uint.sizeof));
    }

    version(WASM_ENABLE_LIBC_WASI) {
    /* The sub-instance will get the wasi_ctx from main-instance */
    if (!is_sub_inst) {
        if (heap_size > 0
            && !wasm_runtime_init_wasi(cast(WASMModuleInstanceCommon*)module_inst,
                                       wasm_module.wasi_args.dir_list,
                                       wasm_module.wasi_args.dir_count,
                                       wasm_module.wasi_args.map_dir_list,
                                       wasm_module.wasi_args.map_dir_count,
                                       wasm_module.wasi_args.env,
                                       wasm_module.wasi_args.env_count,
                                       wasm_module.wasi_args.argv,
                                       wasm_module.wasi_args.argc,
                                       error_buf, error_buf_size)) {
            wasm_deinstantiate(module_inst, false);
            return NULL;
        }
    }
    }

    if (wasm_module.start_function != cast(uint)-1) {
        /* TODO: fix start function can be import function issue */
        if (wasm_module.start_function >= wasm_module.import_function_count)
            module_inst.start_function =
                &module_inst.functions[wasm_module.start_function];
    }

    /* module instance type */
    module_inst.module_type = Wasm_Module_Bytecode;

    /* Initialize the thread related data */
    if (stack_size == 0)
        stack_size = DEFAULT_WASM_STACK_SIZE;
    version(WASM_ENABLE_SPEC_TEST) {
    if (stack_size < 48 *1024)
        stack_size = 48 * 1024;
    }
    module_inst.default_wasm_stack_size = stack_size;

    /* Execute __post_instantiate function */
    if (!execute_post_inst_function(module_inst)
        || !execute_start_function(module_inst)) {
        set_error_buf(error_buf, error_buf_size,
                      module_inst.cur_exception);
        wasm_deinstantiate(module_inst, false);
        return NULL;
    }

    version(WASM_ENABLE_BULK_MEMORY) {
    if (WASM_ENABLE_LIBC_WASI || !wasm_module.is_wasi_module) {
        /* Only execute the memory init function for main instance because
            the data segments will be dropped once initialized.
        */
        if (!is_sub_inst) {
            if (!execute_memory_init_function(module_inst)) {
                set_error_buf(error_buf, error_buf_size,
                              module_inst.cur_exception);
                wasm_deinstantiate(module_inst, false);
                return NULL;
            }
        }
    }

    //(void)global_data_end;
    return module_inst;
}

void
wasm_deinstantiate(WASMModuleInstance *module_inst, bool is_sub_inst)
{
    if (!module_inst)
        return;

    version(WASM_ENABLE_MULTI_MODULE) {
    sub_module_deinstantiate(module_inst);
    }

    /* Destroy wasi resource before freeing app heap, since some fields of
       wasi contex are allocated from app heap, and if app heap is freed,
       these fields will be set to NULL, we cannot free their internal data
       which may allocated from global heap. */
    /* Only destroy wasi ctx in the main module instance */
    if (WASM_ENABLE_LIBC_WASI && !is_sub_inst)
        wasm_runtime_destroy_wasi(cast(WASMModuleInstanceCommon*)module_inst);

    if (module_inst.memory_count > 0)
        memories_deinstantiate(
          module_inst,
          module_inst.memories, module_inst.memory_count);

    tables_deinstantiate(module_inst.tables, module_inst.table_count);
    functions_deinstantiate(module_inst.functions, module_inst.function_count);
    globals_deinstantiate(module_inst.globals);
    export_functions_deinstantiate(module_inst.export_functions);
    version(WASM_ENABLE_MULTI_MODULE) {
    export_globals_deinstantiate(module_inst.export_globals);
    }

    if (module_inst.global_data)
        wasm_runtime_free(module_inst.global_data);

    wasm_runtime_free(module_inst);
}

WASMFunctionInstance*
wasm_lookup_function(const WASMModuleInstance *module_inst,
                     const char *name, const char *signature)
{
    uint i;
    for (i = 0; i < module_inst.export_func_count; i++)
        if (!strcmp(module_inst.export_functions[i].name, name))
            return module_inst.export_functions[i].func;
    //(void)signature;
    return null;
}

version(WASM_ENABLE_MULTI_MODULE) {
WASMGlobalInstance *
wasm_lookup_global(const WASMModuleInstance *module_inst, const char *name)
{
    uint i;
    for (i = 0; i < module_inst.export_glob_count; i++)
        if (!strcmp(module_inst.export_globals[i].name, name))
            return module_inst.export_globals[i].global;
    return NULL;
}

WASMMemoryInstance *
wasm_lookup_memory(const WASMModuleInstance *module_inst, const char *name)
{
    /**
     * using a strong assumption that one module instance only has
     * one memory instance
    */
    //(void)module_inst.export_memories;
    return module_inst.memories[0];
}

WASMTableInstance *
wasm_lookup_table(const WASMModuleInstance *module_inst, const char *name)
{
    /**
     * using a strong assumption that one module instance only has
     * one table instance
     */
    //(void)module_inst.export_tables;
    return module_inst.tables[0];
}
}

bool
wasm_call_function(WASMExecEnv *exec_env,
                   WASMFunctionInstance *func,
                   unsigned argc, uint[] argv)
{
    WASMModuleInstance *module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
    wasm_interp_call_wasm(module_inst, exec_env, func, argc, argv);
    return !wasm_get_exception(module_inst) ? true : false;
}

bool
wasm_create_exec_env_and_call_function(WASMModuleInstance *module_inst,
                                       WASMFunctionInstance *func,
                                       unsigned argc, uint[] argv)
{
    WASMExecEnv *exec_env;
    bool ret;

    if (!(exec_env = wasm_exec_env_create(
                            cast(WASMModuleInstanceCommon*)module_inst,
                            module_inst.default_wasm_stack_size))) {
        wasm_set_exception(module_inst, "allocate memory failed.");
        return false;
    }

    /* set thread handle and stack boundary */
    wasm_exec_env_set_thread_info(exec_env);

    ret = wasm_call_function(exec_env, func, argc, argv);
    wasm_exec_env_destroy(exec_env);
    return ret;
}

void
wasm_set_exception(WASMModuleInstance *module_inst,
                   const char *exception)
{
    if (exception)
        snprintf(module_inst.cur_exception,
                 sizeof(module_inst.cur_exception),
                 "Exception: %s", exception);
    else
        module_inst.cur_exception[0] = '\0';
}

const char*
wasm_get_exception(WASMModuleInstance *module_inst)
{
    if (module_inst.cur_exception[0] == '\0')
        return null;
    else
        return module_inst.cur_exception;
}

int
wasm_module_malloc(WASMModuleInstance *module_inst, uint size,
                   void **p_native_addr)
{
    WASMMemoryInstance *memory = module_inst.default_memory;
    ubyte *addr = mem_allocator_malloc(memory.heap_handle, size);
    if (!addr) {
        wasm_set_exception(module_inst, "out of memory");
        return 0;
    }
    if (p_native_addr)
        *p_native_addr = addr;
    return cast(int)(addr - memory.memory_data);
}

void
wasm_module_free(WASMModuleInstance *module_inst, int ptr)
{
    if (ptr) {
        WASMMemoryInstance *memory = module_inst.default_memory;
        ubyte *addr = memory.memory_data + ptr;
        if (memory.heap_data < addr && addr < memory.memory_data)
            mem_allocator_free(memory.heap_handle, addr);
    }
}
}
int
wasm_module_dup_data(WASMModuleInstance *module_inst,
                     const char *src, uint size)
{
    char *buffer;
    int buffer_offset = wasm_module_malloc(module_inst, size,
                                             cast(void**)&buffer);
    if (buffer_offset != 0) {
        buffer = wasm_addr_app_to_native(module_inst, buffer_offset);
        bh_memcpy_s(buffer, size, src, size);
    }
    return buffer_offset;
}

bool
wasm_validate_app_addr(WASMModuleInstance *module_inst,
                       int app_offset, uint size)
{
    WASMMemoryInstance *memory = module_inst.default_memory;
    int memory_data_size =
        cast(int)(memory.num_bytes_per_page * memory.cur_page_count);

    /* integer overflow check */
    if (app_offset + cast(int)size < app_offset) {
        goto fail;
    }

    if (memory.heap_base_offset <= app_offset
        && app_offset + cast(int)size <= memory_data_size) {
        return true;
    }
fail:
    wasm_set_exception(module_inst, "out of bounds memory access");
    return false;
}

bool
wasm_validate_native_addr(WASMModuleInstance *module_inst,
                          void *native_ptr, uint size)
{
    ubyte *addr = cast(ubyte*)native_ptr;
    WASMMemoryInstance *memory = module_inst.default_memory;
    int memory_data_size =
        cast(int)(memory.num_bytes_per_page * memory.cur_page_count);

    if (addr + size < addr) {
        goto fail;
    }

    if (memory.heap_data <= addr
        && addr + size <= memory.memory_data + memory_data_size) {
        return true;
    }
fail:
    wasm_set_exception(module_inst, "out of bounds memory access");
    return false;
}

void *
wasm_addr_app_to_native(WASMModuleInstance *module_inst,
                        int app_offset)
{
    WASMMemoryInstance *memory = module_inst.default_memory;
    ubyte *addr = memory.memory_data + app_offset;
    int memory_data_size =
        cast(int)(memory.num_bytes_per_page * memory.cur_page_count);

    if (memory.heap_data <= addr
        && addr < memory.memory_data + memory_data_size)
        return addr;
    return NULL;
}

int
wasm_addr_native_to_app(WASMModuleInstance *module_inst,
                        void *native_ptr)
{
    WASMMemoryInstance *memory = module_inst.default_memory;
    ubyte *addr = cast(ubyte*)native_ptr;
    int memory_data_size =
        cast(int)(memory.num_bytes_per_page * memory.cur_page_count);

    if (memory.heap_data <= addr
        && addr < memory.memory_data + memory_data_size)
        return cast(int)(addr - memory.memory_data);
    return 0;
}

bool
wasm_get_app_addr_range(WASMModuleInstance *module_inst,
                        int app_offset,
                        int *p_app_start_offset,
                        int *p_app_end_offset)
{
    WASMMemoryInstance *memory = module_inst.default_memory;
    int memory_data_size =
        cast(int)(memory.num_bytes_per_page * memory.cur_page_count);

    if (memory.heap_base_offset <= app_offset
        && app_offset < memory_data_size) {
        if (p_app_start_offset)
            *p_app_start_offset = memory.heap_base_offset;
        if (p_app_end_offset)
            *p_app_end_offset = memory_data_size;
        return true;
    }
    return false;
}

bool
wasm_get_native_addr_range(WASMModuleInstance *module_inst,
                           ubyte *native_ptr,
                           ubyte **p_native_start_addr,
                           ubyte **p_native_end_addr)
{
    WASMMemoryInstance *memory = module_inst.default_memory;
    ubyte *addr = cast(ubyte*)native_ptr;
    int memory_data_size =
        cast(int)(memory.num_bytes_per_page * memory.cur_page_count);

    if (memory.heap_data <= addr
        && addr < memory.memory_data + memory_data_size) {
        if (p_native_start_addr)
            *p_native_start_addr = memory.heap_data;
        if (p_native_end_addr)
            *p_native_end_addr = memory.memory_data + memory_data_size;
        return true;
    }
    return false;
}

bool
wasm_enlarge_memory(WASMModuleInstance *wasm_module, uint inc_page_count)
{
    WASMMemoryInstance *memory = wasm_module.default_memory, new_memory;
    uint heap_size = memory.memory_data - memory.heap_data;
    uint total_size_old = memory.end_addr - cast(ubyte*)memory;
    uint total_page_count = inc_page_count + memory.cur_page_count;
    uint64 total_size = offsetof(WASMMemoryInstance, base_addr)
                        + cast(uint64)heap_size
                        + memory.num_bytes_per_page * cast(uint64)total_page_count;
    void *heap_handle_old = memory.heap_handle;

    if (inc_page_count <= 0)
        /* No need to enlarge memory */
        return true;

    if (total_page_count < memory.cur_page_count /* integer overflow */
        || total_page_count > memory.max_page_count) {
        wasm_set_exception(wasm_module, "fail to enlarge memory.");
        return false;
    }

    if (total_size >= UINT_MAX) {
        wasm_set_exception(wasm_module, "fail to enlarge memory.");
        return false;
    }

    version(WASM_ENABLE_SHARED_MEMORY) {
    if (memory.is_shared) {
        /* For shared memory, we have reserved the maximum spaces during
            instantiate, only change the cur_page_count here */
        memory.cur_page_count = total_page_count;
        return true;
    }
    }

    if (heap_size > 0) {
        /* Destroy heap's lock firstly, if its memory is re-allocated,
           we cannot access its lock again. */
        mem_allocator_destroy_lock(memory.heap_handle);
    }
    if (!(new_memory = wasm_runtime_realloc(memory, cast(uint)total_size))) {
        if (!(new_memory = wasm_runtime_malloc(cast(uint)total_size))) {
            if (heap_size > 0) {
                /* Restore heap's lock if memory re-alloc failed */
                mem_allocator_reinit_lock(memory.heap_handle);
            }
            wasm_set_exception(wasm_module, "fail to enlarge memory.");
            return false;
        }
        bh_memcpy_s(cast(ubyte*)new_memory, cast(uint)total_size,
                    cast(ubyte*)memory, total_size_old);
        wasm_runtime_free(memory);
    }

    memset(cast(ubyte*)new_memory + total_size_old,
           0, cast(uint)total_size - total_size_old);

    if (heap_size > 0) {
        new_memory.heap_handle = cast(ubyte*)heap_handle_old +
                                  (cast(ubyte*)new_memory - cast(ubyte*)memory);
        if (mem_allocator_migrate(new_memory.heap_handle,
                                  heap_handle_old) != 0) {
            wasm_set_exception(wasm_module, "fail to enlarge memory.");
            return false;
        }
    }

    new_memory.cur_page_count = total_page_count;
    new_memory.heap_data = new_memory.base_addr;
    new_memory.memory_data = new_memory.base_addr + heap_size;
    new_memory.end_addr = new_memory.memory_data +
                            new_memory.num_bytes_per_page * total_page_count;

    wasm_module.memories[0] = wasm_module.default_memory = new_memory;
    return true;
}

bool
wasm_call_indirect(WASMExecEnv *exec_env,
                   uint element_indices,
                   uint argc, uint[] argv)
{
    WASMModuleInstance *module_inst = NULL;
    WASMTableInstance *table_inst = NULL;
    uint_t function_indices = 0;
    WASMFunctionInstance *function_inst = NULL;

    module_inst =
        cast(WASMModuleInstance*)exec_env.module_inst;
    bh_assert(module_inst);

    table_inst = module_inst.default_table;
    if (!table_inst) {
        wasm_set_exception(module_inst, "unknown table");
        goto got_exception;
    }

    if (element_indices >= table_inst.cur_size) {
        wasm_set_exception(module_inst, "undefined element");
        goto got_exception;
    }

    /**
     * please be aware that table_inst.base_addr may point
     * to another module's table
     **/
    function_indices = (cast(uint_t*)table_inst.base_addr)[element_indices];
    if (function_indices == 0xFFFFFFFF) {
        wasm_set_exception(module_inst, "uninitialized element");
        goto got_exception;
    }

    /**
     * we insist to call functions owned by the module itself
     **/
    if (function_indices >= module_inst.function_count) {
        wasm_set_exception(module_inst, "unknown function");
        goto got_exception;
    }

    function_inst = module_inst.functions + function_indices;

    wasm_interp_call_wasm(module_inst, exec_env, function_inst, argc, argv);

    return !wasm_get_exception(module_inst) ? true : false;

got_exception:
    return false;
}

version(WASM_ENABLE_THREAD_MGR) {
bool
wasm_set_aux_stack(WASMExecEnv *exec_env,
                   uint start_offset, uint size)
{
    WASMModuleInstance *module_inst =
        cast(WASMModuleInstance*)exec_env.module_inst;

    uint stack_top_idx =
        module_inst.wasm_module.llvm_aux_stack_global_index;
    uint data_end =
        module_inst.wasm_module.llvm_aux_data_end;
    uint stack_bottom =
        module_inst.wasm_module.llvm_aux_stack_bottom;
    bool is_stack_before_data =
        stack_bottom < data_end ? true : false;

    /* Check the aux stack space, currently we don't allocate space in heap */
    if ((is_stack_before_data && (size > start_offset))
        || ((!is_stack_before_data) && (start_offset - data_end < size)))
        return false;

    if (stack_bottom) {
        /* The aux stack top is a wasm global,
            set the initial value for the global */
        ubyte *global_addr =
            module_inst.global_data +
            module_inst.globals[stack_top_idx].data_offset;
        *cast(int*)global_addr = start_offset;
        /* The aux stack boundary is a constant value,
            set the value to exec_env */
        exec_env.aux_stack_boundary = start_offset - size;
        return true;
    }

    return false;
}

bool
wasm_get_aux_stack(WASMExecEnv *exec_env,
                   uint *start_offset, uint *size)
{
    WASMModuleInstance *module_inst =
        cast(WASMModuleInstance*)exec_env.module_inst;

    /* The aux stack information is resolved in loader
        and store in module */
    uint stack_bottom =
        module_inst.wasm_module.llvm_aux_stack_bottom;
    uint total_aux_stack_size =
        module_inst.wasm_module.llvm_aux_stack_size;

    if (stack_bottom != 0 && total_aux_stack_size != 0) {
        if (start_offset)
            *start_offset = stack_bottom;
        if (size)
            *size = total_aux_stack_size;
        return true;
    }
    return false;
}
}
