/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.wasm_runtime_common;

import tagion.tvm.wamr.bh_platform;
import tagion.tvm.wamr.bh_assert;
import tagion.tvm.wamr.bh_log;
import tagion.tvm.wamr.bh_common;
import tagion.tvm.wamr.bh_list;
import tagion.tvm.wamr.wasm_exec_env;
import tagion.tvm.wamr.wasm_native;
import tagion.tvm.wamr.wasm_export;
import tagion.tvm.wamr.lib_export;
import tagion.tvm.wamr.wasm;
import tagion.tvm.platform.platform;
//import tagion.tvm.wamr.wasmtime_ssp;

import core.stdc.string;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.math : isnan;
import core.stdc.errno;
@nogc:
nothrow:
/+
#ifndef _WASM_COMMON_H
#define _WASM_COMMON_H

#include "bh_platform.h"
#include "bh_common.h"
#include "wasm_exec_env.h"
#include "wasm_native.h"
#include "../include/wasm_export.h"
#include "../interpreter/wasm.h"
#if WASM_ENABLE_LIBC_WASI != 0
#include "wasmtime_ssp.h"
#include "posix.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif
+/

struct WASMModuleCommon {
    /* Module type, for module loaded from WASM bytecode binary,
       this field is Wasm_Module_Bytecode, and this structure should
       be treated as WASMModule structure;
       for module loaded from AOT binary, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModule structure. */
    uint module_type;
    ubyte[1] module_data;
}

struct WASMModuleInstanceCommon {
    /* Module instance type, for module instance loaded from WASM
       bytecode binary, this field is Wasm_Module_Bytecode, and this
       structure should be treated as WASMModuleInstance structure;
       for module instance loaded from AOT binary, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModuleInstance structure. */
    uint module_type;
    ubyte[1] module_inst_data;
}

version (WASM_ENABLE_LIBC_WASI) {
    struct WASIContext {
        /* Use offset but not native address, since these fields are
           allocated from app's heap, and the heap space may be re-allocated
           after memory.grow opcode is executed, the original native address
           cannot be accessed again. */
        int curfds_offset;
        int prestats_offset;
        int argv_environ_offset;
    }
}

version (WASM_ENABLE_MULTI_MODULE) {
    struct WASMRegisteredModule {
        bh_list_link l;
        /* point to a string pool */
        const char* module_name;
        WASMModuleCommon* wasm_mod;
        /* to store the original module file buffer address */
        ubyte* orig_file_buf;
        uint orig_file_buf_size;
    }

    alias PackageType = package_type_t;
    alias WASMSection = wasm_section_t;
    alias AOTSection = wasm_section_t;

    /+
void
set_error_buf_v(char *error_buf, uint error_buf_size, const char *format,
                ...);

/* See wasm_export.h for description */
bool
wasm_runtime_init();

/* See wasm_export.h for description */
bool
wasm_runtime_full_init(RuntimeInitArgs *init_args);

/* See wasm_export.h for description */
void
wasm_runtime_destroy();

/* See wasm_export.h for description */
PackageType
get_package_type(const ubyte *buf, uint size);


/* See wasm_export.h for description */
WASMModuleCommon *
wasm_runtime_load(const ubyte *buf, uint size,
                  char *error_buf, uint error_buf_size);

/* See wasm_export.h for description */
WASMModuleCommon *
wasm_runtime_load_from_sections(WASMSection *section_list, bool is_aot,
                                char *error_buf, uint error_buf_size);

/* See wasm_export.h for description */
void
wasm_runtime_unload(WASMModuleCommon *module);

/* Internal API */
WASMModuleInstanceCommon *
wasm_runtime_instantiate_internal(WASMModuleCommon *module, bool is_sub_inst,
                                  uint stack_size, uint heap_size,
                                  char *error_buf, uint error_buf_size);

/* Internal API */
void
wasm_runtime_deinstantiate_internal(WASMModuleInstanceCommon *module_inst,
                                    bool is_sub_inst);

/* See wasm_export.h for description */
WASMModuleInstanceCommon *
wasm_runtime_instantiate(WASMModuleCommon *module,
                         uint stack_size, uint heap_size,
                         char *error_buf, uint error_buf_size);

/* See wasm_export.h for description */
void
wasm_runtime_deinstantiate(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
WASMFunctionInstanceCommon *
wasm_runtime_lookup_function(WASMModuleInstanceCommon * const module_inst,
                             const char *name, const char *signature);

/* See wasm_export.h for description */
WASMExecEnv *
wasm_runtime_create_exec_env(WASMModuleInstanceCommon *module_inst,
                             uint stack_size);

/* See wasm_export.h for description */
void
wasm_runtime_destroy_exec_env(WASMExecEnv *exec_env);

/* See wasm_export.h for description */
WASMModuleInstanceCommon *
wasm_runtime_get_module_inst(WASMExecEnv *exec_env);

/* See wasm_export.h for description */
void *
wasm_runtime_get_function_attachment(WASMExecEnv *exec_env);

/* See wasm_export.h for description */
void
wasm_runtime_set_user_data(WASMExecEnv *exec_env, void *user_data);

/* See wasm_export.h for description */
void *
wasm_runtime_get_user_data(WASMExecEnv *exec_env);

/* See wasm_export.h for description */
bool
wasm_runtime_call_wasm(WASMExecEnv *exec_env,
                       WASMFunctionInstanceCommon *function,
                       uint argc, uint argv[]);


/**
 * Call a function reference of a given WASM runtime instance with
 * arguments.
 *
 * @param exec_env the execution environment to call the function
 *   which must be created from wasm_create_exec_env()
 * @param element_indices the function ference indicies, usually
 *   prvovided by the caller of a registed native function
 * @param argc the number of arguments
 * @param argv the arguments.  If the function method has return value,
 *   the first (or first two in case 64-bit return value) element of
 *   argv stores the return value of the called WASM function after this
 *   function returns.
 *
 * @return true if success, false otherwise and exception will be thrown,
 *   the caller can call wasm_runtime_get_exception to get exception info.
 */
bool
wasm_runtime_call_indirect(WASMExecEnv *exec_env,
                           uint element_indices,
                           uint argc, uint argv[]);

bool
wasm_runtime_create_exec_env_and_call_wasm(WASMModuleInstanceCommon *module_inst,
                                           WASMFunctionInstanceCommon *function,
                                           uint argc, uint argv[]);

/* See wasm_export.h for description */
bool
wasm_application_execute_main(WASMModuleInstanceCommon *module_inst,
                              int argc, char *argv[]);

/* See wasm_export.h for description */
bool
wasm_application_execute_func(WASMModuleInstanceCommon *module_inst,
                              const char *name, int argc, char *argv[]);

/* See wasm_export.h for description */
void
wasm_runtime_set_exception(WASMModuleInstanceCommon *module,
                           const char *exception);

/* See wasm_export.h for description */
const char *
wasm_runtime_get_exception(WASMModuleInstanceCommon *module);

/* See wasm_export.h for description */
void
wasm_runtime_clear_exception(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
void
wasm_runtime_set_custom_data(WASMModuleInstanceCommon *module_inst,
                             void *custom_data);

/* See wasm_export.h for description */
void *
wasm_runtime_get_custom_data(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
int
wasm_runtime_module_malloc(WASMModuleInstanceCommon *module_inst, uint size,
                           void **p_native_addr);

/* See wasm_export.h for description */
void
wasm_runtime_module_free(WASMModuleInstanceCommon *module_inst, int ptr);

/* See wasm_export.h for description */
int
wasm_runtime_module_dup_data(WASMModuleInstanceCommon *module_inst,
                             const char *src, uint size);

/* See wasm_export.h for description */
bool
wasm_runtime_validate_app_addr(WASMModuleInstanceCommon *module_inst,
                               int app_offset, uint size);

/* See wasm_export.h for description */
bool
wasm_runtime_validate_app_str_addr(WASMModuleInstanceCommon *module_inst,
                                   int app_str_offset);

/* See wasm_export.h for description */
bool
wasm_runtime_validate_native_addr(WASMModuleInstanceCommon *module_inst,
                                  void *native_ptr, uint size);

/* See wasm_export.h for description */
void *
wasm_runtime_addr_app_to_native(WASMModuleInstanceCommon *module_inst,
                                int app_offset);

/* See wasm_export.h for description */
int
wasm_runtime_addr_native_to_app(WASMModuleInstanceCommon *module_inst,
                                void *native_ptr);

/* See wasm_export.h for description */
bool
wasm_runtime_get_app_addr_range(WASMModuleInstanceCommon *module_inst,
                                int app_offset,
                                int *p_app_start_offset,
                                int *p_app_end_offset);

/* See wasm_export.h for description */
bool
wasm_runtime_get_native_addr_range(WASMModuleInstanceCommon *module_inst,
                                   ubyte *native_ptr,
                                   ubyte **p_native_start_addr,
                                   ubyte **p_native_end_addr);

uint
wasm_runtime_get_temp_ret(WASMModuleInstanceCommon *module_inst);

void
wasm_runtime_set_temp_ret(WASMModuleInstanceCommon *module_inst,
                          uint temp_ret);

uint
wasm_runtime_get_llvm_stack(WASMModuleInstanceCommon *module_inst);

void
wasm_runtime_set_llvm_stack(WASMModuleInstanceCommon *module_inst,
                            uint llvm_stack);

#if WASM_ENABLE_MULTI_MODULE != 0
void
wasm_runtime_set_module_reader(const module_reader reader,
                               const module_destroyer destroyer);

module_reader
wasm_runtime_get_module_reader();

module_destroyer
wasm_runtime_get_module_destroyer();

bool
wasm_runtime_register_module_internal(const char *module_name,
                                      WASMModuleCommon *module,
                                      ubyte *orig_file_buf,
                                      uint orig_file_buf_size,
                                      char *error_buf,
                                      uint error_buf_size);

void
wasm_runtime_unregister_module(const WASMModuleCommon *module);

bool
wasm_runtime_is_module_registered(const char *module_name);

bool
wasm_runtime_add_loading_module(const char *module_name,
                                char *error_buf, uint error_buf_size);

void
wasm_runtime_delete_loading_module(const char *module_name);

bool
wasm_runtime_is_loading_module(const char *module_name);

void
wasm_runtime_destroy_loading_module_list();
#endif /* WASM_ENALBE_MULTI_MODULE */

bool
wasm_runtime_is_built_in_module(const char *module_name);

#if WASM_ENABLE_THREAD_MGR != 0
bool
wasm_exec_env_get_aux_stack(WASMExecEnv *exec_env,
                            uint *start_offset, uint *size);

bool
wasm_exec_env_set_aux_stack(WASMExecEnv *exec_env,
                            uint start_offset, uint size);
#endif

#if WASM_ENABLE_LIBC_WASI != 0
/* See wasm_export.h for description */
void
wasm_runtime_set_wasi_args(WASMModuleCommon *module,
                           const char *dir_list[], uint dir_count,
                           const char *map_dir_list[], uint map_dir_count,
                           const char *env_list[], uint env_count,
                           char *argv[], int argc);

/* See wasm_export.h for description */
bool
wasm_runtime_is_wasi_mode(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
WASMFunctionInstanceCommon *
wasm_runtime_lookup_wasi_start_function(WASMModuleInstanceCommon *module_inst);

bool
wasm_runtime_init_wasi(WASMModuleInstanceCommon *module_inst,
                       const char *dir_list[], uint dir_count,
                       const char *map_dir_list[], uint map_dir_count,
                       const char *env[], uint env_count,
                       char *argv[], uint argc,
                       char *error_buf, uint error_buf_size);

void
wasm_runtime_destroy_wasi(WASMModuleInstanceCommon *module_inst);

void
wasm_runtime_set_wasi_ctx(WASMModuleInstanceCommon *module_inst,
                          WASIContext *wasi_ctx);

WASIContext *
wasm_runtime_get_wasi_ctx(WASMModuleInstanceCommon *module_inst);

#endif /* end of WASM_ENABLE_LIBC_WASI */

/* Get module of the current exec_env */
WASMModuleCommon*
wasm_exec_env_get_module(WASMExecEnv *exec_env);

/**
 * Enlarge wasm memory data space.
 *
 * @param module the wasm module instance
 * @param inc_page_count denote the page number to increase
 * @return return true if enlarge successfully, false otherwise
 */
bool
wasm_runtime_enlarge_memory(WASMModuleInstanceCommon *module, uint inc_page_count);

/* See wasm_export.h for description */
bool
wasm_runtime_register_natives(const char *module_name,
                              NativeSymbol *native_symbols,
                              uint n_native_symbols);

/* See wasm_export.h for description */
bool
wasm_runtime_register_natives_raw(const char *module_name,
                                  NativeSymbol *native_symbols,
                                  uint n_native_symbols);

bool
wasm_runtime_invoke_native(WASMExecEnv *exec_env, void *func_ptr,
                           const WASMType *func_type, const char *signature,
                           void *attachment,
                           uint *argv, uint argc, uint *ret);

bool
wasm_runtime_invoke_native_raw(WASMExecEnv *exec_env, void *func_ptr,
                               const WASMType *func_type, const char *signature,
                               void *attachment,
                               uint *argv, uint argc, uint *ret);

#ifdef __cplusplus
}
#endif

#endif /* end of _WASM_COMMON_H */

/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_platform.h"
#include "bh_common.h"
#include "bh_assert.h"
#include "bh_log.h"
#include "wasm_runtime_common.h"
#include "wasm_memory.h"
#if WASM_ENABLE_INTERP != 0
#include "../interpreter/wasm_runtime.h"
#endif
#if WASM_ENABLE_AOT != 0
#include "../aot/aot_runtime.h"
#endif
#if WASM_ENABLE_THREAD_MGR != 0
#include "../libraries/thread-mgr/thread_manager.h"
#endif
#if WASM_ENABLE_SHARED_MEMORY != 0
#include "wasm_shared_memory.h"
#endif
+/
    version (WASM_ENABLE_MULTI_MODULE) {
        /*
 * a safety insurance to prevent
 * circular depencies leading a stack overflow
 * try break early
 */
        struct LoadingModule {
            bh_list_link l;
            /* point to a string pool */
            const char* module_name;
        }

        // static bh_list loading_module_list_head;
        // static bh_list *const loading_module_list = &loading_module_list_head;
        // static korp_mutex loading_module_list_lock;

        /*
 * a list about all exported functions, globals, memories, tables of every
 * fully loaded module
 */
        // static bh_list registered_module_list_head;
        // static bh_list *const registered_module_list = &registered_module_list_head;
        // static korp_mutex registered_module_list_lock;
        // static void
        // wasm_runtime_destroy_registered_module_list();
        // #endif /* WASM_ENABLE_MULTI_MODULE */
        //+/
    }

    void set_error_buf_v(ARG...)(char* error_buf, uint error_buf_size, const char* format, ARG args) {
        va_list args;
        va_start(args, format);
        vsnprintf(error_buf, error_buf_size, format, args);
        va_end(args);
    }

    private void set_error_buf(char* error_buf, uint error_buf_size, const char* str) {
        if (error_buf !is null) {
            snprintf(error_buf, error_buf_size, "%s", str);
        }
    }

    private void* runtime_malloc(uint size,
            WASMModuleInstanceCommon* module_inst, char* error_buf, uint error_buf_size) {
        void* mem;

        if (size >= UINT_MAX || !(mem is wasm_runtime_malloc(cast(uint) size))) {
            if (module_inst !is null) {
                wasm_runtime_set_exception(module_inst, "allocate memory failed.");
            }
            else if (error_buf !is null) {
                set_error_buf(error_buf, error_buf_size, "allocate memory failed.");
            }
            return null;
        }

        memset(mem, 0, cast(uint) size);
        return mem;
    }

    static bool wasm_runtime_env_init() {
        if (bh_platform_init() != 0)
            return false;

        if (wasm_native_init() == false) {
            goto fail1;
        }

        version (WASM_ENABLE_MULTI_MODULE) {
            if (BHT_OK != os_mutex_init(&registered_module_list_lock)) {
                goto fail2;
            }

            if (BHT_OK != os_mutex_init(&loading_module_list_lock)) {
                goto fail3;
            }
        }

        version (WASM_ENABLE_SHARED_MEMORY) {
            if (!wasm_shared_memory_init()) {
                goto fail4;
            }
        }

        version (WASM_ENABLE_THREAD_MGR) {
            if (!thread_manager_init()) {
                goto fail5;
            }
        }

        version (WASM_ENABLE_AOT) {
            version (OS_ENABLE_HW_BOUND_CHECK) {
                if (!aot_signal_init()) {
                    goto fail6;
                }
            }
        }

        return true;

        version (WASM_ENABLE_AOT) {
            version (OS_ENABLE_HW_BOUND_CHECK) {
            fail6:
            }
        }

        version (WASM_ENABLE_THREAD_MGR) {
            thread_manager_destroy();
        fail5:
        }
        version (WASM_ENABLE_SHARED_MEMORY) {
            wasm_shared_memory_destroy();
        fail4:
        }
        version (WASM_ENABLE_MULTI_MODULE) {
            os_mutex_destroy(&loading_module_list_lock);
        fail3:
            os_mutex_destroy(&registered_module_list_lock);
        fail2:
        }
        wasm_native_destroy();
    fail1:
        bh_platform_destroy();

        return false;
    }

    static bool wasm_runtime_exec_env_check(WASMExecEnv* exec_env) {
        return exec_env && exec_env.module_inst && exec_env.wasm_stack_size > 0
            && exec_env.wasm_stack.s.top_boundary == exec_env.wasm_stack.s.bottom + exec_env.wasm_stack_size
            && exec_env.wasm_stack.s.top <= exec_env.wasm_stack.s.top_boundary;
    }

    bool wasm_runtime_init() {
        if (!wasm_runtime_memory_init(Alloc_With_System_Allocator, null))
            return false;

        if (!wasm_runtime_env_init()) {
            wasm_runtime_memory_destroy();
            return false;
        }

        return true;
    }

    void wasm_runtime_destroy() {
        version (WASM_ENABLE_AOT) {
            version (OS_ENABLE_HW_BOUND_CHECK) {
                aot_signal_destroy();
            }
        }

        /* runtime env destroy */
        version (WASM_ENABLE_MULTI_MODULE) {
            wasm_runtime_destroy_loading_module_list();
            os_mutex_destroy(&loading_module_list_lock);

            wasm_runtime_destroy_registered_module_list();
            os_mutex_destroy(&registered_module_list_lock);
        }

        version (WASM_ENABLE_SHARED_MEMORY) {
            wasm_shared_memory_destroy();
        }

        version (WASM_ENABLE_THREAD_MGR) {
            thread_manager_destroy();
        }

        wasm_native_destroy();
        bh_platform_destroy();

        wasm_runtime_memory_destroy();
    }

    bool wasm_runtime_full_init(RuntimeInitArgs* init_args) {
        if (!wasm_runtime_memory_init(init_args.mem_alloc_type, &init_args.mem_alloc_option)) {
            return false;
        }

        if (!wasm_runtime_env_init()) {
            wasm_runtime_memory_destroy();
            return false;
        }

        if (init_args.n_native_symbols > 0 && !wasm_runtime_register_natives(init_args.native_module_name,
                init_args.native_symbols, init_args.n_native_symbols)) {
            wasm_runtime_destroy();
            return false;
        }

        return true;
    }

    PackageType get_package_type(const ubyte* buf, uint size) {
        if (buf && size >= 4) {
            if (buf[0] == '\0' && buf[1] == 'a' && buf[2] == 's' && buf[3] == 'm')
                return Wasm_Module_Bytecode;
            if (buf[0] == '\0' && buf[1] == 'a' && buf[2] == 'o' && buf[3] == 't')
                return Wasm_Module_AoT;
        }
        return Package_Type_Unknown;
    }

    version (WASM_ENABLE_MULTI_MODULE) {
        private module_reader reader;
        private module_destroyer destroyer;
        void wasm_runtime_set_module_reader(const module_reader reader_cb,
                const module_destroyer destroyer_cb) {
            reader = reader_cb;
            destroyer = destroyer_cb;
        }

        module_reader wasm_runtime_get_module_reader() {
            return reader;
        }

        module_destroyer wasm_runtime_get_module_destroyer() {
            return destroyer;
        }

        static WASMRegisteredModule* wasm_runtime_find_module_registered_by_reference(
                WASMModuleCommon* wasm_mod) {
            WASMRegisteredModule* reg_module = null;

            os_mutex_lock(&registered_module_list_lock);
            reg_module = bh_list_first_elem(registered_module_list);
            while (reg_module && wasm_mod != reg_module.wasm_mod) {
                reg_module = bh_list_elem_next(reg_module);
            }
            os_mutex_unlock(&registered_module_list_lock);

            return reg_module;
        }

        bool wasm_runtime_register_module_internal(const char* module_name, WASMModuleCommon* wasm_mod,
                ubyte* orig_file_buf, uint orig_file_buf_size,
                char* error_buf, uint error_buf_size) {
            WASMRegisteredModule* node = null;

            node = wasm_runtime_find_module_registered_by_reference(wasm_mod);
            if (node) { /* module has been registered */
                if (node.module_name) { /* module has name */
                    if (strcmp(node.module_name, module_name)) {
                        /* module has different name */
                        LOG_DEBUG("module(%p) has been registered with name %s",
                                wasm_mod, node.module_name);
                        set_error_buf_v(error_buf, error_buf_size, "can not rename the module");
                        return false;
                    }
                    else {
                        /* module has the same name */
                        LOG_DEBUG("module(%p) has been registered with the same name %s",
                                wasm_mod, node.module_name);
                        return true;
                    }
                }
                else {
                    /* module has empyt name, reset it */
                    node.module_name = module_name;
                    return true;
                }
            }

            /* module hasn't been registered */
            node = runtime_malloc(sizeof(WASMRegisteredModule), null, null, 0);
            if (!node) {
                LOG_DEBUG("malloc WASMRegisteredModule failed. SZ=%d", sizeof(WASMRegisteredModule));
                return false;
            }

            /* share the string and the module */
            node.module_name = module_name;
            node.wasm_mod = wasm_mod;
            node.orig_file_buf = orig_file_buf;
            node.orig_file_buf_size = orig_file_buf_size;

            os_mutex_lock(&registered_module_list_lock);
            bh_list_status ret = bh_list_insert(registered_module_list, node);
            bh_assert(BH_LIST_SUCCESS == ret);
            cast(void) ret;
            os_mutex_unlock(&registered_module_list_lock);
            return true;
        }

        bool wasm_runtime_register_module(const char* module_name,
                WASMModuleCommon* wasm_mod, char* error_buf, uint error_buf_size) {
            if (!error_buf || !error_buf_size) {
                LOG_ERROR("error buffer is required");
                return false;
            }

            if (!module_name || !wasm_mod) {
                LOG_DEBUG("module_name and module are required");
                set_error_buf_v(error_buf, error_buf_size, "module_name and module are required");
                return false;
            }

            if (wasm_runtime_is_built_in_module(module_name)) {
                LOG_DEBUG("%s is a built-in module name", module_name);
                set_error_buf(error_buf, error_buf_size, "can not register as a built-in module");
                return false;
            }

            return wasm_runtime_register_module_internal(module_name, wasm_mod,
                    null, 0, error_buf, error_buf_size);
        }

        void wasm_runtime_unregister_module(const WASMModuleCommon* wasm_mod) {
            WASMRegisteredModule* registered_module = null;

            os_mutex_lock(&registered_module_list_lock);
            registered_module = bh_list_first_elem(registered_module_list);
            while (registered_module && wasm_mod != registered_module.wasm_mod) {
                registered_module = bh_list_elem_next(registered_module);
            }

            /* it does not matter if it is not exist. after all, it is gone */
            if (registered_module) {
                bh_list_remove(registered_module_list, registered_module);
                wasm_runtime_free(registered_module);
            }
            os_mutex_unlock(&registered_module_list_lock);
        }

        WASMModuleCommon* wasm_runtime_find_module_registered(const char* module_name) {
            WASMRegisteredModule* wasm_mod = null;
            WASMRegisteredModule** module_next;

            os_mutex_lock(&registered_module_list_lock);
            wasm_mod = bh_list_first_elem(registered_module_list);
            while (wasm_mod) {
                module_next = bh_list_elem_next(wasm_mod);
                if (wasm_mod.module_name && !strcmp(module_name, wasm_mod.module_name)) {
                    break;
                }
                wasm_mod = module_next;
            }
            os_mutex_unlock(&registered_module_list_lock);

            return wasm_mod ? wasm_mod.wasm_mod : null;
        }

        bool wasm_runtime_is_module_registered(const char* module_name) {
            return null != wasm_runtime_find_module_registered(module_name);
        }

        /*
 * simply destroy all
 */
        static void wasm_runtime_destroy_registered_module_list() {
            WASMRegisteredModule* reg_module = null;

            os_mutex_lock(&registered_module_list_lock);
            reg_module = bh_list_first_elem(registered_module_list);
            while (reg_module) {
                WASMRegisteredModule* next_reg_module = bh_list_elem_next(reg_module);

                bh_list_remove(registered_module_list, reg_module);

                /* now, it is time to release every module in the runtime */
                version (WASM_ENABLE_INTERP) {
                    if (reg_module.wasm_mod.module_type == Wasm_Module_Bytecode) {
                        wasm_unload(cast(WASMModule*) reg_module.wasm_mod);
                    }
                }
                version (WASM_ENABLE_AOT) {
                    if (reg_module.wasm_mod.module_type == Wasm_Module_AoT) {
                        aot_unload(cast(AOTModule*) reg_module.wasm_mod);
                    }
                }

                /* destroy the file buffer */
                if (destroyer && reg_module.orig_file_buf) {
                    destroyer(reg_module.orig_file_buf, reg_module.orig_file_buf_size);
                    reg_module.orig_file_buf = null;
                    reg_module.orig_file_buf_size = 0;
                }

                wasm_runtime_free(reg_module);
                reg_module = next_reg_module;
            }
            os_mutex_unlock(&registered_module_list_lock);
        }

        bool wasm_runtime_add_loading_module(const char* module_name,
                char* error_buf, uint error_buf_size) {
            LOG_DEBUG("add %s into a loading list", module_name);
            LoadingModule* loadingModule = runtime_malloc(sizeof(LoadingModule),
                    null, error_buf, error_buf_size);

            if (!loadingModule) {
                return false;
            }

            /* share the incoming string */
            loadingModule.module_name = module_name;

            os_mutex_lock(&loading_module_list_lock);
            bh_list_status ret = bh_list_insert(loading_module_list, loadingModule);
            bh_assert(BH_LIST_SUCCESS == ret);
            cast(void) ret;
            os_mutex_unlock(&loading_module_list_lock);
            return true;
        }

        void wasm_runtime_delete_loading_module(const char* module_name) {
            LOG_DEBUG("delete %s from a loading list", module_name);

            LoadingModule* wasm_mod = null;

            os_mutex_lock(&loading_module_list_lock);
            wasm_mod = bh_list_first_elem(loading_module_list);
            while (wasm_mod && strcmp(wasm_mod.module_name, module_name)) {
                wasm_mod = bh_list_elem_next(wasm_mod);
            }

            /* it does not matter if it is not exist. after all, it is gone */
            if (wasm_mod) {
                bh_list_remove(loading_module_list, wasm_mod);
                wasm_runtime_free(wasm_mod);
            }
            os_mutex_unlock(&loading_module_list_lock);
        }

        bool wasm_runtime_is_loading_module(const char* module_name) {
            LOG_DEBUG("find %s in a loading list", module_name);

            LoadingModule* wasm_mod = null;

            os_mutex_lock(&loading_module_list_lock);
            wasm_mod = bh_list_first_elem(loading_module_list);
            while (wasm_mod && strcmp(module_name, wasm_mod.module_name)) {
                wasm_mod = bh_list_elem_next(wasm_mod);
            }
            os_mutex_unlock(&loading_module_list_lock);

            return wasm_mod !is null;
        }

        void wasm_runtime_destroy_loading_module_list() {
            LoadingModule* wasm_mod = null;

            os_mutex_lock(&loading_module_list_lock);
            wasm_mod = bh_list_first_elem(loading_module_list);
            while (wasm_mod) {
                LoadingModule* next_module = bh_list_elem_next(wasm_mod);

                bh_list_remove(loading_module_list, wasm_mod);
                /*
         * will not free the module_name since it is
         * shared one of the const string pool
         */
                wasm_runtime_free(wasm_mod);

                wasm_mod = next_module;
            }

            os_mutex_unlock(&loading_module_list_lock);
        }
    }

    bool wasm_runtime_is_built_in_module(const char* module_name) {
        return (!strcmp("env", module_name) || !strcmp("wasi_unstable", module_name)
                || !strcmp("wasi_snapshot_preview1", module_name)
                || !strcmp("spectest", module_name));
    }

    version (WASM_ENABLE_THREAD_MGR) {
        bool wasm_exec_env_set_aux_stack(WASMExecEnv* exec_env, uint start_offset, uint size) {
            WASMModuleInstanceCommon* module_inst = wasm_exec_env_get_module_inst(exec_env);
            version (WASM_ENABLE_INTERP) {
                if (module_inst.module_type == Wasm_Module_Bytecode) {
                    return wasm_set_aux_stack(exec_env, start_offset, size);
                }
            }
            version (WASM_ENABLE_AOT) {
                /* TODO: implement set aux stack in AoT mode */
                cast(void) module_inst;
            }
            return false;
        }

        bool wasm_exec_env_get_aux_stack(WASMExecEnv* exec_env, uint* start_offset, uint* size) {
            WASMModuleInstanceCommon* module_inst = wasm_exec_env_get_module_inst(exec_env);
            version (WASM_ENABLE_INTERP) {
                if (module_inst.module_type == Wasm_Module_Bytecode) {
                    return wasm_get_aux_stack(exec_env, start_offset, size);
                }
            }
            version (WASM_ENABLE_AOT) {
                /* TODO: implement get aux stack in AoT mode */
                cast(void) module_inst;
            }
            return false;
        }

        void wasm_runtime_set_max_thread_num(uint num) {
            wasm_cluster_set_max_thread_num(num);
        }
    }

    static WASMModuleCommon* register_module_with_null_name(
            WASMModuleCommon* module_common, char* error_buf, uint error_buf_size) {
        version (WASM_ENABLE_MULTI_MODULE) {
            if (module_common) {
                if (!wasm_runtime_register_module_internal(null,
                        module_common, null, 0, error_buf, error_buf_size)) {
                    wasm_runtime_unload(module_common);
                    return null;
                }
                return module_common;
            }
            else {
                return null;
            }
        }
        else {
            return module_common;
        }
    }

    WASMModuleCommon* wasm_runtime_load(const ubyte* buf, uint size,
            char* error_buf, uint error_buf_size) {
        WASMModuleCommon* module_common = null;

        if (get_package_type(buf, size) == Wasm_Module_Bytecode) {
            static if (WASM_ENABLE_AOT && WASM_ENABLE_JIT) {
                AOTModule* aot_module;
                WASMModule* wasm_mod = wasm_load(buf, size, error_buf, error_buf_size);
                if (!wasm_mod) {
                    return null;
                }

                if (!(aot_module = aot_convert_wasm_module(wasm_mod, error_buf, error_buf_size))) {
                    wasm_unload(wasm_mod);
                    return null;
                }

                module_common = cast(WASMModuleCommon*) aot_module;
                return register_module_with_null_name(module_common, error_buf, error_buf_size);
            }
            else static if (WASM_ENABLE_INTERP) {
                module_common = cast(WASMModuleCommon*) wasm_load(buf, size,
                        error_buf, error_buf_size);
                return register_module_with_null_name(module_common, error_buf, error_buf_size);
            }
        }
        else if (WASM_ENABLE_AOT && get_package_type(buf, size) == Wasm_Module_AoT) {

            //#if WASM_ENABLE_AOT != 0
            module_common = cast(WASMModuleCommon*) aot_load_from_aot_file(buf,
                    size, error_buf, error_buf_size);
            return register_module_with_null_name(module_common, error_buf, error_buf_size);
            //#endif
        }

        if (size < 4) {
            set_error_buf(error_buf, error_buf_size, "WASM module load failed: unexpected end");
        }
        else {
            set_error_buf(error_buf, error_buf_size,
                    "WASM module load failed: magic header not detected");
        }
        return null;
    }

    WASMModuleCommon* wasm_runtime_load_from_sections(WASMSection* section_list,
            bool is_aot, char* error_buf, uint error_buf_size) {
        WASMModuleCommon* module_common;

        version (WASM_ENABLE_INTERP) {
            if (!is_aot) {
                module_common = cast(WASMModuleCommon*) wasm_load_from_sections(section_list,
                        error_buf, error_buf_size);
                return register_module_with_null_name(module_common, error_buf, error_buf_size);
            }
        }
        version (WASM_ENABLE_AOT) {
            if (is_aot) {
                module_common = cast(WASMModuleCommon*) aot_load_from_sections(section_list,
                        error_buf, error_buf_size);
                return register_module_with_null_name(module_common, error_buf, error_buf_size);
            }
        }

        set_error_buf(error_buf, error_buf_size,
                "WASM module load failed: invalid section list type");
        return null;
    }

    void wasm_runtime_unload(WASMModuleCommon* wasm_mod) {
        version (WASM_ENABLE_MULTI_MODULE) {
            /**
         * since we will unload and free all module when runtime_destroy()
         * we don't want users to unwillingly disrupt it
         */
            return;
        }

        version (WASM_ENABLE_INTERP) {
            if (wasm_mod.module_type == Wasm_Module_Bytecode) {
                wasm_unload(cast(WASMModule*) wasm_mod);
                return;
            }
        }

        version (WASM_ENABLE_AOT) {
            if (wasm_mod.module_type == Wasm_Module_AoT) {
                aot_unload(cast(AOTModule*) wasm_mod);
                return;
            }
        }
    }

    WASMModuleInstanceCommon* wasm_runtime_instantiate_internal(WASMModuleCommon* wasm_mod,
            bool is_sub_inst, uint stack_size, uint heap_size, char* error_buf, uint error_buf_size) {
        version (WASM_ENABLE_INTERP) {
            if (wasm_mod.module_type == Wasm_Module_Bytecode)
                return cast(WASMModuleInstanceCommon*) wasm_instantiate(cast(WASMModule*) wasm_mod,
                        is_sub_inst, stack_size, heap_size, error_buf, error_buf_size);
        }
        version (WASM_ENABLE_AOT) {
            if (wasm_mod.module_type == Wasm_Module_AoT)
                return cast(WASMModuleInstanceCommon*) aot_instantiate(cast(AOTModule*) wasm_mod,
                        is_sub_inst, stack_size, heap_size, error_buf, error_buf_size);
        }
        set_error_buf(error_buf, error_buf_size, "Instantiate module failed, invalid module type");
        return null;
    }

    WASMModuleInstanceCommon* wasm_runtime_instantiate(WASMModuleCommon* wasm_mod,
            uint stack_size, uint heap_size, char* error_buf, uint error_buf_size) {
        return wasm_runtime_instantiate_internal(wasm_mod, false, stack_size,
                heap_size, error_buf, error_buf_size);
    }

    void wasm_runtime_deinstantiate_internal(WASMModuleInstanceCommon* module_inst, bool is_sub_inst) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                wasm_deinstantiate(cast(WASMModuleInstance*) module_inst, is_sub_inst);
                return;
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                aot_deinstantiate(cast(AOTModuleInstance*) module_inst, is_sub_inst);
                return;
            }
        }
    }

    void wasm_runtime_deinstantiate(WASMModuleInstanceCommon* module_inst) {
        return wasm_runtime_deinstantiate_internal(module_inst, false);
    }

    WASMExecEnv* wasm_runtime_create_exec_env(WASMModuleInstanceCommon* module_inst, uint stack_size) {
        return wasm_exec_env_create(module_inst, stack_size);
    }

    void wasm_runtime_destroy_exec_env(WASMExecEnv* exec_env) {
        wasm_exec_env_destroy(exec_env);
    }

    WASMModuleInstanceCommon* wasm_runtime_get_module_inst(WASMExecEnv* exec_env) {
        return wasm_exec_env_get_module_inst(exec_env);
    }

    void* wasm_runtime_get_function_attachment(WASMExecEnv* exec_env) {
        return exec_env.attachment;
    }

    void wasm_runtime_set_user_data(WASMExecEnv* exec_env, void* user_data) {
        exec_env.user_data = user_data;
    }

    void* wasm_runtime_get_user_data(WASMExecEnv* exec_env) {
        return exec_env.user_data;
    }

    WASMFunctionInstanceCommon* wasm_runtime_lookup_function(
            const WASMModuleInstanceCommon* module_inst, const char* name, const char* signature) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode)
                return cast(WASMFunctionInstanceCommon*) wasm_lookup_function(
                        cast(const WASMModuleInstance*) module_inst, name, signature);
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT)
                return cast(WASMFunctionInstanceCommon*) aot_lookup_function(
                        cast(const AOTModuleInstance*) module_inst, name, signature);
        }
        return null;
    }

    bool wasm_runtime_call_wasm(WASMExecEnv* exec_env,
            WASMFunctionInstanceCommon* func, uint argc, uint[] argv) {
        if (!wasm_runtime_exec_env_check(exec_env)) {
            LOG_ERROR("Invalid exec env stack info.");
            return false;
        }

        /* set thread handle and stack boundary */
        wasm_exec_env_set_thread_info(exec_env);

        version (WASM_ENABLE_INTERP) {
            if (exec_env.module_inst.module_type == Wasm_Module_Bytecode)
                return wasm_call_function(exec_env, cast(WASMFunctionInstance*) func, argc, argv);
        }
        version (WASM_ENABLE_AOT) {
            if (exec_env.module_inst.module_type == Wasm_Module_AoT)
                return aot_call_function(exec_env, cast(AOTFunctionInstance*) func, argc, argv);
        }
        return false;
    }

    bool wasm_runtime_create_exec_env_and_call_wasm(WASMModuleInstanceCommon* module_inst,
            WASMFunctionInstanceCommon* func, uint argc, uint[] argv) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode)
                return wasm_create_exec_env_and_call_function(cast(WASMModuleInstance*) module_inst,
                        cast(WASMFunctionInstance*) func, argc, argv);
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT)
                return aot_create_exec_env_and_call_function(cast(AOTModuleInstance*) module_inst,
                        cast(AOTFunctionInstance*) func, argc, argv);
        }
        return false;
    }

    void wasm_runtime_set_exception(WASMModuleInstanceCommon* module_inst, const char* exception) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                wasm_set_exception(cast(WASMModuleInstance*) module_inst, exception);
                return;
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                aot_set_exception(cast(AOTModuleInstance*) module_inst, exception);
                return;
            }

        }

    }

    const char* wasm_runtime_get_exception(WASMModuleInstanceCommon* module_inst) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                return wasm_get_exception(cast(WASMModuleInstance*) module_inst);
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return aot_get_exception(cast(AOTModuleInstance*) module_inst);
            }
        }
        return null;
    }

    void wasm_runtime_clear_exception(WASMModuleInstanceCommon* module_inst) {
        wasm_runtime_set_exception(module_inst, null);
    }

    void wasm_runtime_set_custom_data(WASMModuleInstanceCommon* module_inst, void* custom_data) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                (cast(WASMModuleInstance*) module_inst).custom_data = custom_data;
                return;
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                (cast(AOTModuleInstance*) module_inst).custom_data.ptr = custom_data;
                return;
            }
        }
    }

    void* wasm_runtime_get_custom_data(WASMModuleInstanceCommon* module_inst) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode)
                return (cast(WASMModuleInstance*) module_inst).custom_data;
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return (cast(AOTModuleInstance*) module_inst).custom_data.ptr;
            }
        }
        return null;
    }

    int wasm_runtime_module_malloc(WASMModuleInstanceCommon* module_inst,
            uint size, void** p_native_addr) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode)
                return wasm_module_malloc(cast(WASMModuleInstance*) module_inst,
                        size, p_native_addr);
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return aot_module_malloc(cast(AOTModuleInstance*) module_inst, size, p_native_addr);
            }
        }
        return 0;
    }

    void wasm_runtime_module_free(WASMModuleInstanceCommon* module_inst, int ptr) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                wasm_module_free(cast(WASMModuleInstance*) module_inst, ptr);
                return;
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                aot_module_free(cast(AOTModuleInstance*) module_inst, ptr);
                return;
            }
        }
    }

    int wasm_runtime_module_dup_data(WASMModuleInstanceCommon* module_inst,
            const char* src, uint size) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                return wasm_module_dup_data(cast(WASMModuleInstance*) module_inst, src, size);
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return aot_module_dup_data(cast(AOTModuleInstance*) module_inst, src, size);
            }
        }
        return 0;
    }

    bool wasm_runtime_validate_app_addr(WASMModuleInstanceCommon* module_inst,
            int app_offset, uint size) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode)
                return wasm_validate_app_addr(cast(WASMModuleInstance*) module_inst,
                        app_offset, size);
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT)
                return aot_validate_app_addr(cast(AOTModuleInstance*) module_inst, app_offset, size);
        }
        return false;
    }

    bool wasm_runtime_validate_app_str_addr(WASMModuleInstanceCommon* module_inst,
            int app_str_offset) {
        int app_end_offset;
        char* str;
        char** str_end;

        if (!wasm_runtime_get_app_addr_range(module_inst, app_str_offset, null, &app_end_offset)) {
            goto fail;
        }
        str = wasm_runtime_addr_app_to_native(module_inst, app_str_offset);
        str_end = str + (app_end_offset - app_str_offset);
        while (str < str_end && *str != '\0') {
            str++;
        }
        if (str == str_end) {
            goto fail;
        }
        return true;

    fail:
        wasm_runtime_set_exception(module_inst, "out of bounds memory access");
        return false;
    }

    bool wasm_runtime_validate_native_addr(WASMModuleInstanceCommon* module_inst,
            void* native_ptr, uint size) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                return wasm_validate_native_addr(cast(WASMModuleInstance*) module_inst,
                        native_ptr, size);
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return aot_validate_native_addr(cast(AOTModuleInstance*) module_inst,
                        native_ptr, size);
            }
        }
        return false;
    }

    void* wasm_runtime_addr_app_to_native(WASMModuleInstanceCommon* module_inst, int app_offset) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode)
                return wasm_addr_app_to_native(cast(WASMModuleInstance*) module_inst, app_offset);
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return aot_addr_app_to_native(cast(AOTModuleInstance*) module_inst, app_offset);
            }
        }
        return null;
    }

    int wasm_runtime_addr_native_to_app(WASMModuleInstanceCommon* module_inst, void* native_ptr) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                return wasm_addr_native_to_app(cast(WASMModuleInstance*) module_inst, native_ptr);
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return aot_addr_native_to_app(cast(AOTModuleInstance*) module_inst, native_ptr);
            }
        }
        return 0;
    }

    bool wasm_runtime_get_app_addr_range(WASMModuleInstanceCommon* module_inst,
            int app_offset, int* p_app_start_offset, int* p_app_end_offset) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                return wasm_get_app_addr_range(cast(WASMModuleInstance*) module_inst,
                        app_offset, p_app_start_offset, p_app_end_offset);
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return aot_get_app_addr_range(cast(AOTModuleInstance*) module_inst,
                        app_offset, p_app_start_offset, p_app_end_offset);
            }
        }
        return false;
    }

    bool wasm_runtime_get_native_addr_range(WASMModuleInstanceCommon* module_inst,
            ubyte* native_ptr, ubyte** p_native_start_addr, ubyte** p_native_end_addr) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                return wasm_get_native_addr_range(cast(WASMModuleInstance*) module_inst,
                        native_ptr, p_native_start_addr, p_native_end_addr);
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return aot_get_native_addr_range(cast(AOTModuleInstance*) module_inst,
                        native_ptr, p_native_start_addr, p_native_end_addr);
            }
        }
        return false;
    }

    uint wasm_runtime_get_temp_ret(WASMModuleInstanceCommon* module_inst) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                return (cast(WASMModuleInstance*) module_inst).temp_ret;
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return (cast(AOTModuleInstance*) module_inst).temp_ret;
            }
        }
        return 0;
    }

    void wasm_runtime_set_temp_ret(WASMModuleInstanceCommon* module_inst, uint temp_ret) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                (cast(WASMModuleInstance*) module_inst).temp_ret = temp_ret;
                return;
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                (cast(AOTModuleInstance*) module_inst).temp_ret = temp_ret;
                return;
            }
        }
    }

    uint wasm_runtime_get_llvm_stack(WASMModuleInstanceCommon* module_inst) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                return (cast(WASMModuleInstance*) module_inst).llvm_stack;
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return (cast(AOTModuleInstance*) module_inst).llvm_stack;
            }
        }
        return 0;
    }

    void wasm_runtime_set_llvm_stack(WASMModuleInstanceCommon* module_inst, uint llvm_stack) {
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                (cast(WASMModuleInstance*) module_inst).llvm_stack = llvm_stack;
                return;
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                (cast(AOTModuleInstance*) module_inst).llvm_stack = llvm_stack;
                return;
            }
        }
    }

    bool wasm_runtime_enlarge_memory(WASMModuleInstanceCommon* wasm_mod, uint inc_page_count) {
        version (WASM_ENABLE_INTERP) {
            if (wasm_mod.module_type == Wasm_Module_Bytecode) {
                return wasm_enlarge_memory(cast(WASMModuleInstance*) wasm_mod, inc_page_count);
            }
        }

        version (WASM_ENABLE_AOT) {
            if (wasm_mod.module_type == Wasm_Module_AoT) {
                return aot_enlarge_memory(cast(AOTModuleInstance*) wasm_mod, inc_page_count);
            }
        }
        return false;
    }

    version (WASM_ENABLE_LIBC_WASI) {
        void wasm_runtime_set_wasi_args(WASMModuleCommon* wasm_mod, const char*[] dir_list, uint dir_count,
                const char*[] map_dir_list, uint map_dir_count,
                const char*[] env_list, uint env_count, char*[] argv, int argc) {
            WASIArguments* wasi_args = null;

            static if (WASM_ENABLE_INTERP || WASM_ENABLE_JIT) {
                if (wasm_mod.module_type == Wasm_Module_Bytecode) {
                    wasi_args = &(cast(WASMModule*) wasm_mod).wasi_args;
                }
            }
            static if (WASM_ENABLE_AOT) {
                if (wasm_mod.module_type == Wasm_Module_AoT)
                    wasi_args = &(cast(AOTModule*) wasm_mod).wasi_args;
            }

            if (wasi_args) {
                wasi_args.dir_list = dir_list;
                wasi_args.dir_count = dir_count;
                wasi_args.map_dir_list = map_dir_list;
                wasi_args.map_dir_count = map_dir_count;
                wasi_args.env = env_list;
                wasi_args.env_count = env_count;
                wasi_args.argv = argv;
                wasi_args.argc = argc;
            }
        }

        bool wasm_runtime_init_wasi(WASMModuleInstanceCommon* module_inst, const char*[] dir_list,
                uint dir_count, const char*[] map_dir_list, uint map_dir_count,
                const char*[] env, uint env_count, char*[] argv, uint argc,
                char* error_buf, uint error_buf_size) {
            WASIContext* wasi_ctx;
            size_t* argv_offsets = null;
            char* argv_buf = null;
            size_t* env_offsets = null;
            char* env_buf = null;
            ulong argv_buf_len = 0, env_buf_len = 0;
            uint argv_buf_offset = 0, env_buf_offset = 0;
            fd_table* curfds;
            fd_prestats* prestats;
            argv_environ_values* argv_environ;
            int offset_argv_offsets = 0, offset_env_offsets = 0;
            int offset_argv_buf = 0, offset_env_buf = 0;
            int offset_curfds = 0;
            int offset_prestats = 0;
            int offset_argv_environ = 0;
            __wasi_fd_t wasm_fd = 3;
            int raw_fd;
            char* path;
            char[PATH_MAX] resolved_path;
            ulong total_size;
            uint i;

            if (!(wasi_ctx = runtime_malloc(WASIContext.sizeof, null, error_buf, error_buf_size))) {
                return false;
            }

            wasm_runtime_set_wasi_ctx(module_inst, wasi_ctx);

            version (WASM_ENABLE_INTERP) {
                if (module_inst.module_type == Wasm_Module_Bytecode
                        && !(cast(WASMModuleInstance*) module_inst).default_memory) {
                    return true;
                }
            }

            version (WASM_ENABLE_AOT) {
                if (module_inst.module_type == Wasm_Module_AoT
                        && !(cast(AOTModuleInstance*) module_inst).memory_data.ptr)
                    return true;
            }

            /* process argv[0], trip the path and suffix, only keep the program name */
            for (i = 0; i < argc; i++) {
                argv_buf_len += strlen(argv[i]) + 1;
            }

            total_size = size_t.sizeof * cast(ulong) argc;
            if (total_size >= uint.max || !(offset_argv_offsets = wasm_runtime_module_malloc(module_inst,
                    cast(uint) total_size, cast(void**)&argv_offsets)) || argv_buf_len >= uint.max
                    || !(offset_argv_buf = wasm_runtime_module_malloc(module_inst,
                        cast(uint) argv_buf_len, cast(void**)&argv_buf))) {
                set_error_buf(error_buf, error_buf_size,
                        "Init wasi environment failed: allocate memory failed.");
                goto fail;
            }

            for (i = 0; i < argc; i++) {
                argv_offsets[i] = argv_buf_offset;
                bh_strcpy_s(argv_buf + argv_buf_offset,
                        cast(uint) argv_buf_len - argv_buf_offset, argv[i]);
                argv_buf_offset += cast(uint)(strlen(argv[i]) + 1);
            }

            for (i = 0; i < env_count; i++) {
                env_buf_len += strlen(env[i]) + 1;
            }

            total_size = size_t.sizeof * cast(ulong) argc;
            if (total_size >= UINT_MAX || !(offset_env_offsets = wasm_runtime_module_malloc(module_inst,
                    cast(uint) total_size, cast(void**)&env_offsets)) || env_buf_len >= UINT_MAX
                    || !(offset_env_buf = wasm_runtime_module_malloc(module_inst,
                        cast(uint) env_buf_len, cast(void**)&env_buf))) {
                set_error_buf(error_buf, error_buf_size,
                        "Init wasi environment failed: allocate memory failed.");
                goto fail;
            }

            for (i = 0; i < env_count; i++) {
                env_offsets[i] = env_buf_offset;
                bh_strcpy_s(env_buf + env_buf_offset, cast(uint) env_buf_len - env_buf_offset,
                        env[i]);
                env_buf_offset += cast(uint)(strlen(env[i]) + 1);
            }

            if (!(offset_curfds = wasm_runtime_module_malloc(module_inst, fd_table.sizeof,
                    cast(void**)&curfds)) || !(offset_prestats = wasm_runtime_module_malloc(module_inst,
                    fd_prestats.sizeof,
                    cast(void**)&prestats))
                    || !(offset_argv_environ = wasm_runtime_module_malloc(module_inst,
                        argv_environ_values.sizeof, cast(void**)&argv_environ))) {
                set_error_buf(error_buf, error_buf_size,
                        "Init wasi environment failed: allocate memory failed.");
                goto fail;
            }

            wasi_ctx.curfds_offset = offset_curfds;
            wasi_ctx.prestats_offset = offset_prestats;
            wasi_ctx.argv_environ_offset = offset_argv_environ;

            fd_table_init(curfds);
            fd_prestats_init(prestats);

            if (!argv_environ_init(argv_environ, argv_offsets, argc, argv_buf,
                    argv_buf_len, env_offsets, env_count, env_buf, env_buf_len)) {
                set_error_buf(error_buf, error_buf_size,
                        "Init wasi environment failed: " ~ "init argument environment failed.");
                goto fail;
            }

            /* Prepopulate curfds with stdin, stdout, and stderr file descriptors. */
            if (!fd_table_insert_existing(curfds, 0, 0) || !fd_table_insert_existing(curfds,
                    1, 1) || !fd_table_insert_existing(curfds, 2, 2)) {
                set_error_buf(error_buf, error_buf_size,
                        "Init wasi environment failed: init fd table failed.");
                goto fail;
            }

            wasm_fd = 3;
            for (i = 0; i < dir_count; i++, wasm_fd++) {
                path = realpath(dir_list[i], resolved_path);
                if (!path) {
                    if (error_buf)
                        snprintf(error_buf, error_buf_size,
                                "error while pre-opening directory %s: %d\n", dir_list[i], errno);
                    goto fail;
                }

                raw_fd = open(path, O_RDONLY | O_DIRECTORY, 0);
                if (raw_fd == -1) {
                    if (error_buf)
                        snprintf(error_buf, error_buf_size,
                                "error while pre-opening directory %s: %d\n", dir_list[i], errno);
                    goto fail;
                }

                fd_table_insert_existing(curfds, wasm_fd, raw_fd);
                fd_prestats_insert(prestats, dir_list[i], wasm_fd);
            }

            return true;

        fail:
            if (offset_curfds != 0)
                wasm_runtime_module_free(module_inst, offset_curfds);
            if (offset_prestats != 0)
                wasm_runtime_module_free(module_inst, offset_prestats);
            if (offset_argv_environ != 0)
                wasm_runtime_module_free(module_inst, offset_argv_environ);
            if (offset_argv_buf)
                wasm_runtime_module_free(module_inst, offset_argv_buf);
            if (offset_argv_offsets)
                wasm_runtime_module_free(module_inst, offset_argv_offsets);
            if (offset_env_buf)
                wasm_runtime_module_free(module_inst, offset_env_buf);
            if (offset_env_offsets)
                wasm_runtime_module_free(module_inst, offset_env_offsets);
            return false;
        }

        bool wasm_runtime_is_wasi_mode(WASMModuleInstanceCommon* module_inst) {
            version (WASM_ENABLE_INTERP) {
                if (module_inst.module_type == Wasm_Module_Bytecode
                        && (cast(WASMModuleInstance*) module_inst).wasm_mod.is_wasi_module) {
                    return true;
                }
            }
            version (WASM_ENABLE_AOT) {
                if (module_inst.module_type == Wasm_Module_AoT
                        && (cast(AOTModule*)(cast(AOTModuleInstance*) module_inst).aot_module.ptr)
                        .is_wasi_module) {
                    return true;
                }
            }
            return false;
        }

        WASMFunctionInstanceCommon* wasm_runtime_lookup_wasi_start_function(
                WASMModuleInstanceCommon* module_inst) {
            uint i;

            version (WASM_ENABLE_INTERP) {
                if (module_inst.module_type == Wasm_Module_Bytecode) {
                    WASMModuleInstance* wasm_inst = cast(WASMModuleInstance*) module_inst;
                    WASMFunctionInstance* func;
                    for (i = 0; i < wasm_inst.export_func_count; i++) {
                        if (!strcmp(wasm_inst.export_functions[i].name, "_start")) {
                            func = wasm_inst.export_functions[i].func;
                            if (func.u.func.func_type.param_count != 0
                                    || func.u.func.func_type.result_count != 0) {
                                LOG_ERROR(
                                        "Lookup wasi _start function failed: "
                                        ~ "invalid function type.\n");
                                return null;
                            }
                            return cast(WASMFunctionInstanceCommon*) func;
                        }
                    }
                    return null;
                }
            }

            version (WASM_ENABLE_AOT) {
                if (module_inst.module_type == Wasm_Module_AoT) {
                    AOTModuleInstance* aot_inst = cast(AOTModuleInstance*) module_inst;
                    AOTModule* wasm_mod = cast(AOTModule*) aot_inst.aot_module.ptr;
                    for (i = 0; i < wasm_mod.export_func_count; i++) {
                        if (!strcmp(wasm_mod.export_funcs[i].func_name, "_start")) {
                            AOTFuncType* func_type = wasm_mod.export_funcs[i].func_type;
                            if (func_type.param_count != 0 || func_type.result_count != 0) {
                                LOG_ERROR(
                                        "Lookup wasi _start function failed: "
                                        ~ "invalid function type.\n");
                                return null;
                            }
                            return cast(WASMFunctionInstanceCommon*)&wasm_mod.export_funcs[i];
                        }
                    }
                    return null;
                }
            }

            return null;
        }

        void wasm_runtime_destroy_wasi(WASMModuleInstanceCommon* module_inst) {
            WASIContext* wasi_ctx = wasm_runtime_get_wasi_ctx(module_inst);
            argv_environ_values* argv_environ;
            fd_table* curfds;
            fd_prestats* prestats;

            if (wasi_ctx) {
                if (wasi_ctx.argv_environ_offset) {
                    argv_environ = cast(argv_environ_values*) wasm_runtime_addr_app_to_native(module_inst,
                            wasi_ctx.argv_environ_offset);
                    argv_environ_destroy(argv_environ);
                    wasm_runtime_module_free(module_inst, wasi_ctx.argv_environ_offset);
                }
                if (wasi_ctx.curfds_offset) {
                    curfds = cast(fd_table*) wasm_runtime_addr_app_to_native(module_inst,
                            wasi_ctx.curfds_offset);
                    fd_table_destroy(curfds);
                    wasm_runtime_module_free(module_inst, wasi_ctx.curfds_offset);
                }
                if (wasi_ctx.prestats_offset) {
                    prestats = cast(fd_prestats*) wasm_runtime_addr_app_to_native(module_inst,
                            wasi_ctx.prestats_offset);
                    fd_prestats_destroy(prestats);
                    wasm_runtime_module_free(module_inst, wasi_ctx.prestats_offset);
                }
                wasm_runtime_free(wasi_ctx);
            }
        }

        WASIContext* wasm_runtime_get_wasi_ctx(WASMModuleInstanceCommon* module_inst) {
            version (WASM_ENABLE_INTERP) {
                if (module_inst.module_type == Wasm_Module_Bytecode) {
                    return (cast(WASMModuleInstance*) module_inst).wasi_ctx;
                }
            }

            version (WASM_ENABLE_AOT) {
                if (module_inst.module_type == Wasm_Module_AoT) {
                    return (cast(AOTModuleInstance*) module_inst).wasi_ctx.ptr;
                }
            }
            return null;
        }

        void wasm_runtime_set_wasi_ctx(WASMModuleInstanceCommon* module_inst, WASIContext* wasi_ctx) {
            version (WASM_ENABLE_INTERP) {
                if (module_inst.module_type == Wasm_Module_Bytecode) {
                    (cast(WASMModuleInstance*) module_inst).wasi_ctx = wasi_ctx;
                }
            }
            version (WASM_ENABLE_AOT) {
                if (module_inst.module_type == Wasm_Module_AoT) {
                    (cast(AOTModuleInstance*) module_inst).wasi_ctx.ptr = wasi_ctx;
                }
            }
        }
    }

    WASMModuleCommon* wasm_exec_env_get_module(WASMExecEnv* exec_env) {
        WASMModuleInstanceCommon* module_inst = wasm_runtime_get_module_inst(exec_env);
        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                return cast(WASMModuleCommon*)(cast(WASMModuleInstance*) module_inst).wasm_mod;
            }
        }
        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                return cast(WASMModuleCommon*)(cast(AOTModuleInstance*) module_inst).aot_module.ptr;
            }
        }
        return null;
    }

    /**
 * Implementation of wasm_application_execute_main()
 */

    // static WASMFunctionInstanceCommon * resolve_function(
    //         const WASMModuleInstanceCommon * module_inst, const char * name);

    static bool check_main_func_type(const WASMType* type) {
        if (!(type.param_count == 0 || type.param_count == 2) || type.result_count > 1) {
            LOG_ERROR("WASM execute application failed: invalid main function type.\n");
            return false;
        }

        if (type.param_count == 2 && !(type.types[0] == VALUE_TYPE_I32
                && type.types[1] == VALUE_TYPE_I32)) {
            LOG_ERROR("WASM execute application failed: invalid main function type.\n");
            return false;
        }

        if (type.result_count && type.types[type.param_count] != VALUE_TYPE_I32) {
            LOG_ERROR("WASM execute application failed: invalid main function type.\n");
            return false;
        }

        return true;
    }

    bool wasm_application_execute_main(WASMModuleInstanceCommon* module_inst,
            int argc, char*[] argv) {
        WASMFunctionInstanceCommon* func;
        WASMType* func_type = null;
        uint argc1 = 0;
        uint[2] argv1;
        uint total_argv_size = 0;
        ulong total_size;
        int argv_buf_offset, i;
        char* argv_buf;
        char** p, p_end;
        int* argv_offsets;

        version (WASM_ENABLE_LIBC_WASI) {
            if (wasm_runtime_is_wasi_mode(module_inst)) {
                /* In wasi mode, we should call function named "_start"
           which initializes the wasi envrionment and then calls
           the actual main function. Directly call main function
           may cause exception thrown. */
                if ((func = wasm_runtime_lookup_wasi_start_function(module_inst))) {
                    return wasm_runtime_create_exec_env_and_call_wasm(module_inst, func, 0, null);
                    /* if no start function is found, we execute
                   the main function as normal */
                }
            }
        }

        func = resolve_function(module_inst, "_main");
        if (!func) {
            func = resolve_function(module_inst, "main");
        }

        if (!func) {
            wasm_runtime_set_exception(module_inst, "lookup main function failed.");
            return false;
        }

        version (WASM_ENABLE_INTERP) {
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                if ((cast(WASMFunctionInstance*) func).is_import_func) {
                    wasm_runtime_set_exception(module_inst, "lookup main function failed.");
                    return false;
                }
                func_type = (cast(WASMFunctionInstance*) func).u.func.func_type;
            }
        }

        version (WASM_ENABLE_AOT) {
            if (module_inst.module_type == Wasm_Module_AoT) {
                func_type = (cast(AOTFunctionInstance*) func).func_type;
            }
        }

        if (!check_main_func_type(func_type)) {
            wasm_runtime_set_exception(module_inst, "invalid function type of main function.");
            return false;
        }

        if (func_type.param_count) {
            for (i = 0; i < argc; i++)
                total_argv_size += cast(uint)(strlen(argv[i]) + 1);
            total_argv_size = align_uint(total_argv_size, 4);

            total_size = cast(ulong) total_argv_size + int.sizeof * cast(ulong) argc;

            if (total_size >= uint.max || !(argv_buf_offset = wasm_runtime_module_malloc(module_inst,
                    cast(uint) total_size, cast(void**)&argv_buf))) {
                wasm_runtime_set_exception(module_inst, "allocate memory failed.");
                return false;
            }

            p = argv_buf;
            argv_offsets = cast(int*)(p + total_argv_size);
            p_end = p + total_size;

            for (i = 0; i < argc; i++) {
                bh_memcpy_s(p, cast(uint)(p_end - p), argv[i], cast(uint)(strlen(argv[i]) + 1));
                argv_offsets[i] = argv_buf_offset + cast(int)(p - argv_buf);
                p += strlen(argv[i]) + 1;
            }

            argc1 = 2;
            argv1[0] = cast(uint) argc;
            argv1[1] = cast(uint) wasm_runtime_addr_native_to_app(module_inst, argv_offsets);
        }

        return wasm_runtime_create_exec_env_and_call_wasm(module_inst, func, argc1, argv1);
    }
}
version (WASM_ENABLE_MULTI_MODULE) {
    protected WASMModuleInstance* get_sub_module_inst(
            const WASMModuleInstance* parent_module_inst, const char* sub_module_name) {
        WASMSubModInstNode* node = bh_list_first_elem(parent_module_inst.sub_module_inst_list);

        while (node && strcmp(node.module_name, sub_module_name)) {
            node = bh_list_elem_next(node);
        }
        return node ? node.module_inst : null;
    }

    static bool parse_function_name(char* orig_function_name,
            char** p_module_name, char** p_function_name) {
        if (orig_function_name[0] != '$') {
            *p_module_name = null;
            *p_function_name = orig_function_name;
            return true;
        }

        /**
     * $module_name$function_name\0
     *  ===>
     * module_name\0function_name\0
     *  ===>
     * module_name
     * function_name
     */
        char* p1 = orig_function_name;
        char* p2 = strchr(p1 + 1, '$');
        if (!p2) {
            LOG_DEBUG("can not parse the incoming function name");
            return false;
        }

        *p_module_name = p1 + 1;
        *p2 = '\0';
        *p_function_name = p2 + 1;
        return strlen(*p_module_name) && strlen(*p_function_name);
    }
}

/**
 * Implementation of wasm_application_execute_func()
 */

protected WASMFunctionInstanceCommon* resolve_function(
        const WASMModuleInstanceCommon* module_inst, const char* name) {
    uint i = 0;
    WASMFunctionInstanceCommon* ret = null;
    version (WASM_ENABLE_MULTI_MODULE) {
        WASMModuleInstance* sub_module_inst = null;
        char* orig_name = null;
        char* sub_module_name = null;
        char* function_name = null;
        uint length = strlen(name) + 1;

        orig_name = runtime_malloc(char.sizeof * length, null, null, 0);
        if (!orig_name) {
            return null;
        }

        strncpy(orig_name, name, length);

        if (!parse_function_name(orig_name, &sub_module_name, &function_name)) {
            goto LEAVE;
        }

        LOG_DEBUG("%s . %s and %s", name, sub_module_name, function_name);

        if (sub_module_name) {
            sub_module_inst = get_sub_module_inst(cast(WASMModuleInstance*) module_inst,
                    sub_module_name);
            if (!sub_module_inst) {
                LOG_DEBUG("can not find a sub module named %s", sub_module_name);
                goto LEAVE;
            }
        }
    }
    else {
        const char* function_name = name;
    }

    version (WASM_ENABLE_INTERP) {
        if (module_inst.module_type == Wasm_Module_Bytecode) {
            WASMModuleInstance* wasm_inst = cast(WASMModuleInstance*) module_inst;

            version (WASM_ENABLE_MULTI_MODULE) {
                wasm_inst = sub_module_inst ? sub_module_inst : wasm_inst;
            }

            for (i = 0; i < wasm_inst.export_func_count; i++) {
                if (!strcmp(wasm_inst.export_functions[i].name, function_name)) {
                    ret = wasm_inst.export_functions[i].func;
                    break;
                }
            }
        }
    }

    version (WASM_ENABLE_AOT) {
        if (module_inst.module_type == Wasm_Module_AoT) {
            AOTModuleInstance* aot_inst = cast(AOTModuleInstance*) module_inst;
            AOTModule* wasm_mod = cast(AOTModule*) aot_inst.aot_module.ptr;
            for (i = 0; i < wasm_mod.export_func_count; i++) {
                if (!strcmp(wasm_mod.export_funcs[i].func_name, function_name)) {
                    ret = cast(WASMFunctionInstance*)&wasm_mod.export_funcs[i];
                    break;
                }
            }
        }
    }

    version (WASM_ENABLE_MULTI_MODULE) {
    LEAVE:
        wasm_runtime_free(orig_name);
    }
    return ret;
}

union ieee754_float {
    float f;

    /* This is the IEEE 754 single-precision format.  */
    union {
        struct IEEE_BIG_ENDIAN {
            uint negative = 1;
            uint exponent = 8;
            uint mantissa = 23;
        }

        IEEE_BIG_ENDIAN ieee_big_endian;
        struct IEEE_LITTLE_ENDIAN {
            uint mantissa = 23;
            uint exponent = 8;
            uint negative = 1;
        }

        IEEE_LITTLE_ENDIAN ieee_little_endian;
    }
}

union ieee754_double {
    double d;

    /* This is the IEEE 754 double-precision format.  */
    union {
        struct IEEE_BIG_ENDIAN {
            uint negative = 1;
            uint exponent = 11;
            /* Together these comprise the mantissa.  */
            uint mantissa0 = 20;
            uint mantissa1 = 32;
        }

        IEEE_BIG_ENDIAN ieee_big_endian;

        struct IEEE_LITTLE_ENDIAN {
            /* Together these comprise the mantissa.  */
            uint mantissa1 = 32;
            uint mantissa0 = 20;
            uint exponent = 11;
            uint negative = 1;
        }

        IEEE_LITTLE_ENDIAN ieee_little_endian;
    }
}

union __UE {
    int a;
    ubyte b;
}

static __UE __ue = {a: 1};

static bool is_little_endian() {
    return __ue.b == 1;
}

bool wasm_application_execute_func(WASMModuleInstanceCommon* module_inst,
        const char* name, int argc, char*[] argv) {
    WASMFunctionInstanceCommon* func;
    WASMType* type = null;
    uint argc1, cell_num, j, k = 0;
    uint* argv1 = null;
    int i, p;
    ulong total_size;
    const char* exception;
    char[128] buf;

    bh_assert(argc >= 0);
    LOG_DEBUG("call a function \"%s\" with %d arguments", name, argc);
    func = resolve_function(module_inst, name);

    if (!func) {
        snprintf(buf.ptr, buf.length, "lookup function %s failed.".ptr, name);
        wasm_runtime_set_exception(module_inst, buf.ptr);
        goto fail;
    }

    version (WASM_ENABLE_INTERP) {
        if (module_inst.module_type == Wasm_Module_Bytecode) {
            WASMFunctionInstance* wasm_func = cast(WASMFunctionInstance*) func;
            bool flag = wasm_func.is_import_func;
            static if (WASM_ENABLE_MULTI_MODULE) {
                flag &= !wasm_func.import_func_inst;
            }
            if (flag) {
                //         if (wasm_func.is_import_func
                // #if WASM_ENABLE_MULTI_MODULE != 0
                //             && !wasm_func.import_func_inst
                // #endif
                //         ) {
                snprintf(buf, buf.length, "lookup function %s failed.", name);
                wasm_runtime_set_exception(module_inst, buf);
                goto fail;
            }
            type = wasm_func.u.func.func_type;
            argc1 = wasm_func.param_cell_num;
            cell_num = argc1 > wasm_func.ret_cell_num ? argc1 : wasm_func.ret_cell_num;
        }
    }
    version (WASM_ENABLE_AOT) {
        if (module_inst.module_type == Wasm_Module_AoT) {
            type = (cast(AOTFunctionInstance*) func).func_type;
            argc1 = type.param_cell_num;
            cell_num = argc1 > type.ret_cell_num ? argc1 : type.ret_cell_num;
        }
    }

    if (type.param_count != cast(uint) argc) {
        wasm_runtime_set_exception(module_inst, "invalid input argument count.");
        goto fail;
    }

    total_size = uint.sizeof * cast(ulong)(cell_num > 2 ? cell_num : 2);
    if ((!(argv1 = runtime_malloc(cast(uint) total_size, module_inst, null, 0)))) {
        goto fail;
    }

    /* Clear errno before parsing arguments */
    errno = 0;

    /* Parse arguments */
    for (i = 0, p = 0; i < argc; i++) {
        char* endptr = null;
        bh_assert(argv[i]!is null);
        if (argv[i][0] == '\0') {
            snprintf(buf.ptr, buf.length, "invalid input argument %d.".ptr, i);
            wasm_runtime_set_exception(module_inst, buf.ptr);
            goto fail;
        }
        switch (type.types[i]) {
        case VALUE_TYPE_I32:
            argv1[p++] = cast(uint) strtoul(argv[i], &endptr, 0);
            break;
        case VALUE_TYPE_I64: {
                union U {
                    ulong val;
                    uint[2] parts;
                }

                U u;
                u.val = strtoull(argv[i], &endptr, 0);
                argv1[p++] = u.parts[0];
                argv1[p++] = u.parts[1];
                break;
            }
        case VALUE_TYPE_F32: {
                float f32 = strtof(argv[i], &endptr);
                if (isnan(f32)) {
                    if (argv[i][0] == '-') {
                        ieee754_float u;
                        u.f = f32;
                        if (is_little_endian())
                            u.ieee.ieee_little_endian.negative = 1;
                        else
                            u.ieee.ieee_big_endian.negative = 1;
                        memcpy(&f32, &u.f, float.sizeof);
                    }
                    if (endptr[0] == ':') {
                        uint sig;
                        ieee754_float u;
                        sig = cast(uint) strtoul(endptr + 1, &endptr, 0);
                        u.f = f32;
                        if (is_little_endian())
                            u.ieee.ieee_little_endian.mantissa = sig;
                        else
                            u.ieee.ieee_big_endian.mantissa = sig;
                        memcpy(&f32, &u.f, float.sizeof);
                    }
                }
                memcpy(&argv1[p++], &f32, float.sizeof);
                break;
            }
        case VALUE_TYPE_F64: {
                union U {
                    float64 val;
                    uint[2] parts;
                }

                U u;
                u.val = strtod(argv[i], &endptr);
                if (isnan(u.val)) {
                    if (argv[i][0] == '-') {
                        ieee754_double ud;
                        ud.d = u.val;
                        if (is_little_endian()) {
                            ud.ieee.ieee_little_endian.negative = 1;
                        }
                        else {
                            ud.ieee.ieee_big_endian.negative = 1;
                        }
                        memcpy(&u.val, &ud.d, double.sizeof);
                    }
                    if (endptr[0] == ':') {
                        ulong sig;
                        ieee754_double ud;
                        sig = strtoull(endptr + 1, &endptr, 0);
                        ud.d = u.val;
                        if (is_little_endian()) {
                            ud.ieee.ieee_little_endian.mantissa0 = sig >> 32;
                            ud.ieee.ieee_little_endian.mantissa1 = cast(uint) sig;
                        }
                        else {
                            ud.ieee.ieee_big_endian.mantissa0 = sig >> 32;
                            ud.ieee.ieee_big_endian.mantissa1 = cast(uint) sig;
                        }
                        memcpy(&u.val, &ud.d, double.sizeof);
                    }
                }
                argv1[p++] = u.parts[0];
                argv1[p++] = u.parts[1];
                break;
            }
        }
        if (endptr && *endptr != '\0' && *endptr != '_') {
            snprintf(buf, sizeof(buf), "invalid input argument %d: %s.", i, argv[i]);
            wasm_runtime_set_exception(module_inst, buf);
            goto fail;
        }
        if (errno != 0) {
            snprintf(buf, sizeof(buf), "prepare function argument error, errno: %d.", errno);
            wasm_runtime_set_exception(module_inst, buf);
            goto fail;
        }
    }
    bh_assert(p == cast(int) argc1);

    wasm_runtime_set_exception(module_inst, null);
    if (!wasm_runtime_create_exec_env_and_call_wasm(module_inst, func, argc1, argv1)) {
        goto fail;
    }

    /* print return value */
    for (j = 0; j < type.result_count; j++) {
        switch (type.types[type.param_count + j]) {
        case VALUE_TYPE_I32:
            os_printf("0x%x:i32", argv1[k]);
            k++;
            break;
        case VALUE_TYPE_I64: {
                union U {
                    ulong val;
                    uint[2] parts;
                }

                U u;
                u.parts[0] = argv1[k];
                u.parts[1] = argv1[k + 1];
                k += 2;
                version (PRIx64) {
                    os_printf("0x%" ~ PRIx64 ~ ":i64", u.val);
                }
                else {
                    char[16] buf;
                    static if (long.sizeof == 4) {
                        pragma(msg, "Fixme(cbr) Always false!! in D");
                        snprintf(buf, sizeof(buf), "%s", "0x%llx:i64");
                    }
                    else {
                        snprintf(buf, sizeof(buf), "%s", "0x%lx:i64");
                    }
                    os_printf(buf, u.val);
                }
                break;
            }
        case VALUE_TYPE_F32:
            os_printf("%.7g:f32", *cast(float*)(argv1 + k));
            k++;
            break;
        case VALUE_TYPE_F64: {
                union {
                    float64 val;
                    uint[2] parts;
                }

                u;
                u.parts[0] = argv1[k];
                u.parts[1] = argv1[k + 1];
                k += 2;
                os_printf("%.7g:f64", u.val);
                break;
            }
        }
        if (j < cast(uint)(type.result_count - 1))
            os_printf(",");
    }
    os_printf("\n");

    wasm_runtime_free(argv1);
    return true;

fail:
    if (argv1)
        wasm_runtime_free(argv1);

    exception = wasm_runtime_get_exception(module_inst);
    bh_assert(exception);
    os_printf("%s\n", exception);
    return false;
}

bool wasm_runtime_register_natives(const char* module_name,
        NativeSymbol* native_symbols, uint n_native_symbols) {
    return wasm_native_register_natives(module_name, native_symbols, n_native_symbols);
}

bool wasm_runtime_register_natives_raw(const char* module_name,
        NativeSymbol* native_symbols, uint n_native_symbols) {
    return wasm_native_register_natives_raw(module_name, native_symbols, n_native_symbols);
}

bool wasm_runtime_invoke_native_raw(WASMExecEnv* exec_env, void* func_ptr,
        const WASMType* func_type, const char* signature, void* attachment,
        uint* argv, uint argc, uint* argv_ret) {
    WASMModuleInstanceCommon* wasm_mod = wasm_runtime_get_module_inst(exec_env);
    alias NativeRawFuncPtr = void function(WASMExecEnv*, ulong*);
    NativeRawFuncPtr invokeNativeRaw = cast(NativeRawFuncPtr) func_ptr;
    ulong[16] argv_buf, size;
    ulong* argv1 = argv_buf, argv_dst;
    uint* argv_src = argv, i, argc1, ptr_len;
    int arg_i32;
    bool ret = false;

    argc1 = func_type.param_count;
    if (argc1 > argv_buf.sizeof / ulong.sizeof) {
        size = ulong.sizeof * cast(ulong) argc1;
        if (!(argv1 = runtime_malloc(cast(uint) size, exec_env.module_inst, null, 0))) {
            return false;
        }
    }

    argv_dst = argv1;

    /* Traverse secondly to fill in each argument */
    for (i = 0; i < func_type.param_count; i++, argv_dst++) {
        switch (func_type.types[i]) {
        case VALUE_TYPE_I32: {
                *cast(int*) argv_dst = arg_i32 = cast(int)*argv_src++;
                if (signature) {
                    if (signature[i + 1] == '*') {
                        /* param is a pointer */
                        if (signature[i + 2] == '~') /* pointer with length followed */
                            ptr_len = *argv_src;
                        else /* pointer without length followed */
                            ptr_len = 1;

                        if (!wasm_runtime_validate_app_addr(wasm_mod, arg_i32, ptr_len))
                            goto fail;

                        *cast(uintptr_t*) argv_dst = cast(uintptr_t) wasm_runtime_addr_app_to_native(wasm_mod,
                                arg_i32);
                    }
                    else if (signature[i + 1] == '$') {
                        /* param is a string */
                        if (!wasm_runtime_validate_app_str_addr(wasm_mod, arg_i32))
                            goto fail;

                        *cast(uintptr_t*) argv_dst = cast(uintptr_t) wasm_runtime_addr_app_to_native(wasm_mod,
                                arg_i32);
                    }
                }
                break;
            }
        case VALUE_TYPE_I64:
        case VALUE_TYPE_F64:
            bh_memcpy_s(argv_dst, ulong.sizeof, argv_src, uint.sizeof * 2);
            argv_src += 2;
            break;
        case VALUE_TYPE_F32:
            *cast(float*) argv_dst = *cast(float*) argv_src++;
            break;
        default:
            bh_assert(0);
            break;
        }
    }

    exec_env.attachment = attachment;
    invokeNativeRaw(exec_env, argv1);
    exec_env.attachment = null;

    if (func_type.result_count > 0) {
        switch (func_type.types[func_type.param_count]) {
        case VALUE_TYPE_I32:
            argv_ret[0] = *cast(uint*) argv1;
            break;
        case VALUE_TYPE_F32:
            *cast(float*) argv_ret = *cast(float*) argv1;
            break;
        case VALUE_TYPE_I64:
        case VALUE_TYPE_F64:
            bh_memcpy_s(argv_ret, uint.sizeof * 2, argv1, ulong.sizeof);
            break;
        default:
            bh_assert(0);
            break;
        }
    }

    ret = true;

fail:
    if (argv1 != argv_buf)
        wasm_runtime_free(argv1);
    return ret;
}

/**
 * Implementation of wasm_runtime_invoke_native()
 */

protected void word_copy(uint* dest, uint* src, uint num) {
    for (; num > 0; num--)
        *dest++ = *src++;
}

void PUT_I64_TO_ADDR(long* addr, long value) {
    union {
        int64 val;
        uint[2] parts;
    }

    u;
    u.val = (value);
    (addr)[0] = u.parts[0];
    (addr)[1] = u.parts[1];
}

void PUT_F64_TO_ADDR(float* addr, float value) {
    union {
        float64 val;
        uint[2] parts;
    }

    u;
    u.val = (value);
    (addr)[0] = u.parts[0];
    (addr)[1] = u.parts[1];
}

/* The invoke native implementation on ARM platform with VFP co-processor */
static if (BUILD_TARGET_ARM_VFP || BUILD_TARGET_THUMB_VFP) {
    alias GenericFunctionPointer = void function();
    // int64 invokeNative(GenericFunctionPointer f, uint *args, uint n_stacks);

    alias Float64FuncPtr = double function(GenericFunctionPointer, uint*, uint);
    alias Float32FuncPtr = float function(GenericFunctionPointer, uint*, uint);
    alias Int64FuncPtr = long function(GenericFunctionPointer, uint*, uint);
    alias IntFuncPtr = int function(GenericFunctionPointer, uint*, uint);
    alias VoidFuncPtr = void function(GenericFunctionPointer, uint*, uint);

    protected {
        Float64FuncPtr invokeNative_Float64 = cast(Float64FuncPtr) invokeNative;
        Float32FuncPtr invokeNative_Float32 = cast(Float32FuncPtr) invokeNative;
        Int64FuncPtr invokeNative_Int64 = cast(Int64FuncPtr) invokeNative;
        IntFuncPtr invokeNative_Int = cast(IntFuncPtr) invokeNative;
        VoidFuncPtr invokeNative_Void = cast(VoidFuncPtr) invokeNative;
    }

    enum MAX_REG_INTS = 4;
    enum MAX_REG_FLOATS = 16;

    bool wasm_runtime_invoke_native(WASMExecEnv* exec_env, void* func_ptr, const WASMType* func_type,
            const char* signature, void* attachment, uint* argv, uint argc, uint* argv_ret) {
        WASMModuleInstanceCommon* wasm_mod = wasm_runtime_get_module_inst(exec_env);
        /* argv buf layout: int args(fix cnt) + float args(fix cnt) + stack args */
        uint[32] argv_buf;
        uint size;
        uint* argv1 = argv_buf, fps, ints, stacks;
        uint* argv_src = argv, i, argc1, n_ints = 0, n_fps = 0, n_stacks = 0;
        uint arg_i32, ptr_len;
        uint result_count = func_type.result_count;
        uint ext_ret_count = result_count > 1 ? result_count - 1 : 0;
        bool ret = false;

        n_ints++; /* exec env */

        /* Traverse firstly to calculate stack args count */
        for (i = 0; i < func_type.param_count; i++) {
            switch (func_type.types[i]) {
            case VALUE_TYPE_I32:
                if (n_ints < MAX_REG_INTS)
                    n_ints++;
                else
                    n_stacks++;
                break;
            case VALUE_TYPE_I64:
                if (n_ints < MAX_REG_INTS - 1) {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_ints & 1)
                        n_ints++;
                    n_ints += 2;
                }
                else {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_stacks & 1)
                        n_stacks++;
                    n_stacks += 2;
                }
                break;
            case VALUE_TYPE_F32:
                if (n_fps < MAX_REG_FLOATS)
                    n_fps++;
                else
                    n_stacks++;
                break;
            case VALUE_TYPE_F64:
                if (n_fps < MAX_REG_FLOATS - 1) {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_fps & 1)
                        n_fps++;
                    n_fps += 2;
                }
                else {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_stacks & 1)
                        n_stacks++;
                    n_stacks += 2;
                }
                break;
            default:
                bh_assert(0);
                break;
            }
        }

        for (i = 0; i < ext_ret_count; i++) {
            if (n_ints < MAX_REG_INTS)
                n_ints++;
            else
                n_stacks++;
        }

        argc1 = MAX_REG_INTS + MAX_REG_FLOATS + n_stacks;
        if (argc1 > argv_buf.sizeof / uint.sizeof) {
            size = uint.sizeof * cast(uint) argc1;
            if (!(argv1 = runtime_malloc(cast(uint) size, exec_env.module_inst, null, 0))) {
                return false;
            }
        }

        ints = argv1;
        fps = ints + MAX_REG_INTS;
        stacks = fps + MAX_REG_FLOATS;

        n_ints = 0;
        n_fps = 0;
        n_stacks = 0;
        ints[n_ints++] = cast(uint) cast(uintptr_t) exec_env;

        /* Traverse secondly to fill in each argument */
        for (i = 0; i < func_type.param_count; i++) {
            switch (func_type.types[i]) {
            case VALUE_TYPE_I32: {
                    arg_i32 = *argv_src++;

                    if (signature) {
                        if (signature[i + 1] == '*') {
                            /* param is a pointer */
                            if (signature[i + 2] == '~') {
                                /* pointer with length followed */
                                ptr_len = *argv_src;
                            }
                            else {
                                /* pointer without length followed */
                                ptr_len = 1;
                            }
                            if (!wasm_runtime_validate_app_addr(wasm_mod, arg_i32, ptr_len))
                                goto fail;

                            arg_i32 = cast(uintptr_t) wasm_runtime_addr_app_to_native(wasm_mod,
                                    arg_i32);
                        }
                        else if (signature[i + 1] == '$') {
                            /* param is a string */
                            if (!wasm_runtime_validate_app_str_addr(wasm_mod, arg_i32))
                                goto fail;

                            arg_i32 = cast(uintptr_t) wasm_runtime_addr_app_to_native(wasm_mod,
                                    arg_i32);
                        }
                    }

                    if (n_ints < MAX_REG_INTS)
                        ints[n_ints++] = arg_i32;
                    else
                        stacks[n_stacks++] = arg_i32;
                    break;
                }
            case VALUE_TYPE_I64:
                if (n_ints < MAX_REG_INTS - 1) {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_ints & 1)
                        n_ints++;
                    *cast(ulong*)&ints[n_ints] = *cast(ulong*) argv_src;
                    n_ints += 2;
                }
                else {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_stacks & 1)
                        n_stacks++;
                    *cast(ulong*)&stacks[n_stacks] = *cast(ulong*) argv_src;
                    n_stacks += 2;
                }
                argv_src += 2;
                break;
            case VALUE_TYPE_F32:
                if (n_fps < MAX_REG_FLOATS)
                    *cast(float*)&fps[n_fps++] = *cast(float*) argv_src++;
                else
                    *cast(float*)&stacks[n_stacks++] = *cast(float*) argv_src++;
                break;
            case VALUE_TYPE_F64:
                if (n_fps < MAX_REG_FLOATS - 1) {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_fps & 1)
                        n_fps++;
                    *cast(float64*)&fps[n_fps] = *cast(float64*) argv_src;
                    n_fps += 2;
                }
                else {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_stacks & 1)
                        n_stacks++;
                    *cast(float64*)&stacks[n_stacks] = *cast(float64*) argv_src;
                    n_stacks += 2;
                }
                argv_src += 2;
                break;
            default:
                bh_assert(0);
                break;
            }
        }

        /* Save extra result values' address to argv1 */
        for (i = 0; i < ext_ret_count; i++) {
            if (n_ints < MAX_REG_INTS)
                ints[n_ints++] = *cast(uint*) argv_src++;
            else
                stacks[n_stacks++] = *cast(uint*) argv_src++;
        }

        exec_env.attachment = attachment;
        if (func_type.result_count == 0) {
            invokeNative_Void(func_ptr, argv1, n_stacks);
        }
        else {
            switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
                argv_ret[0] = cast(uint) invokeNative_Int(func_ptr, argv1, n_stacks);
                break;
            case VALUE_TYPE_I64:
                PUT_I64_TO_ADDR(argv_ret, invokeNative_Int64(func_ptr, argv1, n_stacks));
                break;
            case VALUE_TYPE_F32:
                *cast(float*) argv_ret = invokeNative_Float(func_ptr, argv1, n_stacks);
                break;
            case VALUE_TYPE_F64:
                PUT_F64_TO_ADDR(argv_ret, invokeNative_Float64(func_ptr, argv1, n_stacks));
                break;
            default:
                bh_assert(0);
                break;
            }
        }
        exec_env.attachment = null;

        ret = true;

    fail:
        if (argv1 != argv_buf)
            wasm_runtime_free(argv1);
        return ret;
    }
}
/* end of BUILD_TARGET_ARM_VFP || BUILD_TARGET_THUMB_VFP */

static if (BUILD_TARGET_X86_32 || BUILD_TARGET_ARM || BUILD_TARGET_THUMB
        || BUILD_TARGET_MIPS || BUILD_TARGET_XTENSA) {
    alias GenericFunctionPointer = void function();
    int64 invokeNative(GenericFunctionPointer f, uint* args, uint sz);

    alias Float64FuncPtr = float64 function(GenericFunctionPointer f, uint*, uint);
    alias Float32FuncPtr = float32 function(GenericFunctionPointer f, uint*, uint);
    alias Int64FuncPtr = int64 function(GenericFunctionPointer f, uint*, uint);
    alias IntFuncPtr = int function(GenericFunctionPointer f, uint*, uint);
    alias VoidFuncPtr = void function(GenericFunctionPointer f, uint*, uint);

    protected {
        Int64FuncPtr invokeNative_Int64 = cast(Int64FuncPtr) invokeNative;
        IntFuncPtr invokeNative_Int = cast(IntFuncPtr) invokeNative;
        Float64FuncPtr invokeNative_Float64 = cast(Float64FuncPtr) invokeNative;
        Float32FuncPtr invokeNative_Float32 = cast(Float32FuncPtr) invokeNative;
        VoidFuncPtr invokeNative_Void = cast(VoidFuncPtr) invokeNative;

        bool wasm_runtime_invoke_native(WASMExecEnv* exec_env, void* func_ptr, const WASMType* func_type,
                const char* signature, void* attachment, uint* argv, uint argc, uint* argv_ret) {
            WASMModuleInstanceCommon* wasm_mod = wasm_runtime_get_module_inst(exec_env);
            uint[32] argv_buf;
            uint* argv1 = argv_buf;
            uint argc1, i, j = 0;
            uint arg_i32, ptr_len;
            uint result_count = func_type.result_count;
            uint ext_ret_count = result_count > 1 ? result_count - 1 : 0;
            ulong size;
            bool ret = false;

            version (BUILD_TARGET_X86_32) {
                argc1 = argc + ext_ret_count + 2;

            }
            else {
                /* arm/thumb/mips/xtensa, 64-bit data must be 8 bytes aligned,
       so we need to allocate more memory. */
                argc1 = func_type.param_count * 2 + ext_ret_count + 2;
            }

            if (argc1 > argv_buf.sizeof / uint.sizeof) {
                size = uint.sizeof * cast(ulong) argc1;
                if (!(argv1 = runtime_malloc(cast(uint) size, exec_env.module_inst, null, 0))) {
                    return false;
                }
            }

            for (i = 0; i < (WASMExecEnv*).sizeof / uint.sizeof; i++)
                argv1[j++] = (cast(uint*)&exec_env)[i];

            for (i = 0; i < func_type.param_count; i++) {
                switch (func_type.types[i]) {
                case VALUE_TYPE_I32: {
                        arg_i32 = *argv++;

                        if (signature) {
                            if (signature[i + 1] == '*') {
                                /* param is a pointer */
                                if (signature[i + 2] == '~') /* pointer with length followed */
                                    ptr_len = *argv;
                                else /* pointer without length followed */
                                    ptr_len = 1;

                                if (!wasm_runtime_validate_app_addr(wasm_mod, arg_i32, ptr_len))
                                    goto fail;

                                arg_i32 = cast(uintptr_t) wasm_runtime_addr_app_to_native(wasm_mod,
                                        arg_i32);
                            }
                            else if (signature[i + 1] == '$') {
                                /* param is a string */
                                if (!wasm_runtime_validate_app_str_addr(wasm_mod, arg_i32))
                                    goto fail;

                                arg_i32 = cast(uintptr_t) wasm_runtime_addr_app_to_native(wasm_mod,
                                        arg_i32);
                            }
                        }

                        argv1[j++] = arg_i32;
                        break;
                    }
                case VALUE_TYPE_I64:
                case VALUE_TYPE_F64:
                    version (BUILD_TARGET_X86_32) {
                    }
                    else {
                        /* 64-bit data must be 8 bytes aligned in arm, thumb, mips
                   and xtensa */
                        if (j & 1) {
                            j++;
                        }
                    }
                    argv1[j++] = *argv++;
                    argv1[j++] = *argv++;
                    break;
                case VALUE_TYPE_F32:
                    argv1[j++] = *argv++;
                    break;
                default:
                    bh_assert(0);
                    break;
                }
            }

            /* Save extra result values' address to argv1 */
            word_copy(argv1 + j, argv, ext_ret_count);

            argc1 = j + ext_ret_count;
            exec_env.attachment = attachment;
            if (func_type.result_count == 0) {
                invokeNative_Void(func_ptr, argv1, argc1);
            }
            else {
                switch (func_type.types[func_type.param_count]) {
                case VALUE_TYPE_I32:
                    argv_ret[0] = cast(uint) invokeNative_Int(func_ptr, argv1, argc1);
                    break;
                case VALUE_TYPE_I64:
                    PUT_I64_TO_ADDR(argv_ret, invokeNative_Int64(func_ptr, argv1, argc1));
                    break;
                case VALUE_TYPE_F32:
                    *cast(float*) argv_ret = invokeNative_Float32(func_ptr, argv1, argc1);
                    break;
                case VALUE_TYPE_F64:
                    PUT_F64_TO_ADDR(argv_ret, invokeNative_Float64(func_ptr, argv1, argc1));
                    break;
                default:
                    bh_assert(0);
                    break;
                }
            }
            exec_env.attachment = null;

            ret = true;

        fail:
            if (argv1 != argv_buf)
                wasm_runtime_free(argv1);
            return ret;
        }

    } /* end of (BUILD_TARGET_X86_32
     || BUILD_TARGET_ARM
     || BUILD_TARGET_THUMB
     || BUILD_TARGET_MIPS
     || BUILD_TARGET_XTENSA) */

    static if (BUILD_TARGET_X86_64 || BUILD_TARGET_AMD_64 || BUILD_TARGET_AARCH64) {
        alias GenericFunctionPointer = void function();
        int64 invokeNative(GenericFunctionPointer f, ulong* args, ulong n_stacks);

        alias Float64FuncPtr = float64 function(GenericFunctionPointer, ulong*, ulong);
        alias Float32FuncPtr = float32 function(GenericFunctionPointer, ulong*, ulong);
        alias Int64FuncPtr = int64 function(GenericFunctionPointer, ulong*, ulong);
        alias IntFuncPtr = int function(GenericFunctionPointer, ulong*, ulong);
        alias VoidFuncPtr = void function(GenericFunctionPointer, ulong*, ulong);

        protected {
            Float64FuncPtr invokeNative_Float64 = cast(Float64FuncPtr) cast(uintptr_t) invokeNative;
            Float32FuncPtr invokeNative_Float32 = cast(Float32FuncPtr) cast(uintptr_t) invokeNative;
            Int64FuncPtr invokeNative_Int64 = cast(Int64FuncPtr) cast(uintptr_t) invokeNative;
            IntFuncPtr invokeNative_Int = cast(IntFuncPtr) cast(uintptr_t) invokeNative;
            VoidFuncPtr invokeNative_Void = cast(VoidFuncPtr) cast(uintptr_t) invokeNative;
        }

        version (Win32) {
            enum MAX_REG_FLOATS = 4;
            enum MAX_REG_INTS = 4;
        }
        else {
            enum MAX_REG_FLOATS = 8;
            version (AArch64) {
                enum MAX_REG_INTS = 8;
            }
            else {
                enum MAX_REG_INTS = 6;
            } /* end of BUILD_TARGET_AARCH64 */
        } /* end of Win32 */

        bool wasm_runtime_invoke_native(WASMExecEnv* exec_env, void* func_ptr, const WASMType* func_type,
                const char* signature, void* attachment, uint* argv, uint argc, uint* argv_ret) {
            WASMModuleInstanceCommon* wasm_mod = wasm_runtime_get_module_inst(exec_env);
            ulong[32] argv_buf;
            ulong* argv1 = argv_buf, fps, ints, stacks;
            uint size, arg_i64;
            uint* argv_src = argv;
            uint i, argc1, n_ints = 0, n_stacks = 0;
            uint arg_i32, ptr_len;
            uint result_count = func_type.result_count;
            uint ext_ret_count = result_count > 1 ? result_count - 1 : 0;
            bool ret = false;

            version (Win32) {
                /* important difference in calling conventions */
                alias n_fps = n_ints;
            }
            else {
                int n_fps = 0;
            }

            argc1 = 1 + MAX_REG_FLOATS + func_type.param_count + ext_ret_count;
            if (argc1 > argv_buf.sizeof / ulong.sizeof) {
                size = ulong.sizeof * cast(ulong) argc1;
                if (!(argv1 = runtime_malloc(cast(uint) size, exec_env.module_inst, null, 0))) {
                    return false;
                }
            }

            fps = argv1;
            ints = fps + MAX_REG_FLOATS;
            stacks = ints + MAX_REG_INTS;

            ints[n_ints++] = cast(ulong) cast(uintptr_t) exec_env;

            for (i = 0; i < func_type.param_count; i++) {
                switch (func_type.types[i]) {
                case VALUE_TYPE_I32: {
                        arg_i32 = *argv_src++;
                        arg_i64 = arg_i32;
                        if (signature) {
                            if (signature[i + 1] == '*') {
                                /* param is a pointer */
                                if (signature[i + 2] == '~') {
                                    /* pointer with length followed */
                                    ptr_len = *argv_src;
                                }
                                else {
                                    /* pointer without length followed */
                                    ptr_len = 1;
                                }
                                if (!wasm_runtime_validate_app_addr(wasm_mod, arg_i32, ptr_len)) {
                                    goto fail;
                                }
                                arg_i64 = cast(uintptr_t) wasm_runtime_addr_app_to_native(wasm_mod,
                                        arg_i32);
                            }
                            else if (signature[i + 1] == '$') {
                                /* param is a string */
                                if (!wasm_runtime_validate_app_str_addr(wasm_mod, arg_i32))
                                    goto fail;

                                arg_i64 = cast(uintptr_t) wasm_runtime_addr_app_to_native(wasm_mod,
                                        arg_i32);
                            }
                        }
                        if (n_ints < MAX_REG_INTS)
                            ints[n_ints++] = arg_i64;
                        else
                            stacks[n_stacks++] = arg_i64;
                        break;
                    }
                case VALUE_TYPE_I64:
                    if (n_ints < MAX_REG_INTS) {
                        ints[n_ints++] = *cast(ulong*) argv_src;
                    }
                    else {
                        stacks[n_stacks++] = *cast(ulong*) argv_src;
                    }
                    argv_src += 2;
                    break;
                case VALUE_TYPE_F32:
                    if (n_fps < MAX_REG_FLOATS) {
                        *cast(float32*)&fps[n_fps++] = *cast(float*) argv_src++;
                    }
                    else {
                        *cast(float*)&stacks[n_stacks++] = *cast(float*) argv_src++;
                    }
                    break;
                case VALUE_TYPE_F64:
                    if (n_fps < MAX_REG_FLOATS) {
                        *cast(float64*)&fps[n_fps++] = *cast(float64*) argv_src;
                    }
                    else {
                        *cast(float64*)&stacks[n_stacks++] = *cast(float64*) argv_src;
                    }
                    argv_src += 2;
                    break;
                default:
                    bh_assert(0);
                    break;
                }
            }

            /* Save extra result values' address to argv1 */
            for (i = 0; i < ext_ret_count; i++) {
                if (n_ints < MAX_REG_INTS) {
                    ints[n_ints++] = *cast(ulong*) argv_src;
                }
                else {
                    stacks[n_stacks++] = *cast(ulong*) argv_src;
                }
                argv_src += 2;
            }

            exec_env.attachment = attachment;
            if (result_count == 0) {
                invokeNative_Void(func_ptr, argv1, n_stacks);
            }
            else {
                /* Invoke the native function and get the first result value */
                switch (func_type.types[func_type.param_count]) {
                case VALUE_TYPE_I32:
                    argv_ret[0] = cast(uint) invokeNative_Int(func_ptr, argv1, n_stacks);
                    break;
                case VALUE_TYPE_I64:
                    PUT_I64_TO_ADDR(argv_ret, invokeNative_Int64(func_ptr, argv1, n_stacks));
                    break;
                case VALUE_TYPE_F32:
                    *cast(float*) argv_ret = invokeNative_Float32(func_ptr, argv1, n_stacks);
                    break;
                case VALUE_TYPE_F64:
                    PUT_F64_TO_ADDR(argv_ret, invokeNative_Float64(func_ptr, argv1, n_stacks));
                    break;
                default:
                    bh_assert(0);
                    break;
                }
            }
            exec_env.attachment = null;

            ret = true;
        fail:
            if (argv1 != argv_buf)
                wasm_runtime_free(argv1);

            return ret;
        }

    } /* end of (BUILD_TARGET_X86_64
     || BUILD_TARGET_AMD_64
     || BUILD_TARGET_AARCH64) */

    bool wasm_runtime_call_indirect(WASMExecEnv* exec_env, uint element_indices,
            uint argc, uint[] argv) {
        if (!wasm_runtime_exec_env_check(exec_env)) {
            LOG_ERROR("Invalid exec env stack info.");
            return false;
        }

        /* this function is called from native code, so exec_env.handle and
       exec_env.native_stack_boundary must have been set, we don't set
       it again */

        version (WASM_ENABLE_INTERP) {
            if (exec_env.module_inst.module_type == Wasm_Module_Bytecode) {
                return wasm_call_indirect(exec_env, element_indices, argc, argv);
            }
        }
        version (WASM_ENABLE_AOT) {
            if (exec_env.module_inst.module_type == Wasm_Module_AoT) {
                return aot_call_indirect(exec_env, false, 0, element_indices, argc, argv);
            }
        }
        return false;
    }
}
