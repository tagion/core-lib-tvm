/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.wasm_exec_env;

import tagion.tvm.wamr.bh_assert;
import tagion.tvm.wamr.wasm;

// #ifndef _WASM_EXEC_ENV_H
// #define _WASM_EXEC_ENV_H

// #include "bh_assert.h"
// #if WASM_ENABLE_INTERP != 0
// #include "../interpreter/wasm.h"
// #endif

// #ifdef __cplusplus
// extern "C" {
// #endif

// struct WASMModuleInstanceCommon;
// struct WASMInterpFrame;

// version(WASM_ENABLE_THREAD_MGR) {
// typedef struct WASMCluster WASMCluster;
// #endif

version (OS_ENABLE_HW_BOUND_CHECK) {
    struct WASMJmpBuf {
        WASMJmpBuf* prev;
        korp_jmpbuf jmpbuf;
    }
}

/* Execution environment */
struct WASMExecEnv {
    /* Next thread's exec env of a WASM module instance. */
    WASMExecEnv* next;

    /* Previous thread's exec env of a WASM module instance. */
    WASMExecEnv* prev;

    /* Note: field module_inst, argv_buf and native_stack_boundary
             are used by AOTed code, don't change the places of them */

    /* The WASM module instance of current thread */
    WASMModuleInstanceCommon* module_inst;

    version (WASM_ENABLE_AOT) {
        uint* argv_buf;
    }

    /* The boundary of native stack. When runtime detects that native
       frame may overrun this boundary, it throws stack overflow
       exception. */
    uint8* native_stack_boundary;

    version (WASM_ENABLE_THREAD_MGR) {
        /* Used to terminate or suspend the interpreter
        bit 0: need terminate
        bit 1: need suspend
        bit 2: need to go into breakpoint */
        uintptr_t suspend_flags;

        /* Must be provided by thread library */
        void* function(void*) thread_start_routine;
        void* thread_arg;

        /* pointer to the cluster */
        WASMCluster* cluster;

        /* used to support debugger */
        korp_mutex wait_lock;
        korp_cond wait_cond;
    }

    /* Aux stack boundary */
    uint aux_stack_boundary;

    /* attachment for native function */
    void* attachment;

    void* user_data;

    /* Current interpreter frame of current thread */
    WASMInterpFrame* cur_frame;

    /* The native thread handle of current thread */
    korp_tid handle;

    version (WASM_ENABLE_INTERP) {
        BlockAddr[BLOCK_ADDR_CACHE_SIZE][BLOCK_ADDR_CONFLICT_SIZE] block_addr_cache;
    }

    version (OS_ENABLE_HW_BOUND_CHECK) {
        WASMJmpBuf* jmpbuf_stack_top;
    }

    /* The WASM stack size */
    uint wasm_stack_size;

    /* The WASM stack of current thread */
    union WASM_STACK {
        uint64 __make_it_8_byte_aligned_;

        struct S {
            /* The top boundary of the stack. */
            uint8* top_boundary;

            /* Top cell index which is free. */
            uint8* top;

            /* The WASM stack. */
            uint8[1] bottom;
        }

        S s;
    }

    WASM_STACK wasm_stack;
}

// WASMExecEnv*
// wasm_exec_env_create_internal(WASMModuleInstanceCommon* module_inst,
//                               uint stack_size);

// void
// wasm_exec_env_destroy_internal(WASMExecEnv* exec_env);

// WASMExecEnv*
// wasm_exec_env_create(struct WASMModuleInstanceCommon *module_inst,
//                      uint stack_size);

// void
// wasm_exec_env_destroy(WASMExecEnv *exec_env);

/**
 * Allocate a WASM frame from the WASM stack.
 *
 * @param exec_env the current execution environment
 * @param size size of the WASM frame, it must be a multiple of 4
 *
 * @return the WASM frame if there is enough space in the stack area
 * with a protection area, NULL otherwise
 */
protected void* wasm_exec_env_alloc_wasm_frame(WASMExecEnv* exec_env, unsigned size) {
    uint8* addr = exec_env.wasm_stack.s.top;

    bh_assert(!(size & 3));

    /* The outs area size cannot be larger than the frame size, so
       multiplying by 2 is enough. */
    if (addr + size * 2 > exec_env.wasm_stack.s.top_boundary) {
        /* WASM stack overflow. */
        /* When throwing SOE, the preserved space must be enough. */
        /* bh_assert(!exec_env.throwing_soe);*/
        return NULL;
    }

    exec_env.wasm_stack.s.top += size;

    return addr;
}

protected void wasm_exec_env_free_wasm_frame(WASMExecEnv* exec_env, void* prev_top) {
    bh_assert(cast(uint8*) prev_top >= exec_env.wasm_stack.s.bottom);
    exec_env.wasm_stack.s.top = cast(uint8*) prev_top;
}

/**
 * Get the current WASM stack top pointer.
 *
 * @param exec_env the current execution environment
 *
 * @return the current WASM stack top pointer
 */
protected void* wasm_exec_env_wasm_stack_top(WASMExecEnv* exec_env) {
    return exec_env.wasm_stack.s.top;
}

/**
 * Set the current frame pointer.
 *
 * @param exec_env the current execution environment
 * @param frame the WASM frame to be set for the current exec env
 */
protected void wasm_exec_env_set_cur_frame(WASMExecEnv* exec_env, WASMInterpFrame* frame) {
    exec_env.cur_frame = frame;
}

/**
 * Get the current frame pointer.
 *
 * @param exec_env the current execution environment
 *
 * @return the current frame pointer
 */
protected WASMInterpFrame* wasm_exec_env_get_cur_frame(WASMExecEnv* exec_env) {
    return exec_env.cur_frame;
}

// WASMModuleInstanceCommon*
// wasm_exec_env_get_module_inst(WASMExecEnv* exec_env);

// void
// wasm_exec_env_set_thread_info(WASMExecEnv *exec_env);

// version(WASM_ENABLE_THREAD_MGR) {
// void*
// wasm_exec_env_get_thread_arg(WASMExecEnv *exec_env);

// void
// wasm_exec_env_set_thread_arg(WASMExecEnv *exec_env, void *thread_arg);
// #endif

// #ifdef OS_ENABLE_HW_BOUND_CHECK
// void
// wasm_exec_env_push_jmpbuf(WASMExecEnv *exec_env, WASMJmpBuf *jmpbuf);

// WASMJmpBuf *
// wasm_exec_env_pop_jmpbuf(WASMExecEnv *exec_env);
// #endif

// #ifdef __cplusplus
// }
// #endif

// #endif /* end of _WASM_EXEC_ENV_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

// #include "wasm_exec_env.h"
import tagion.tvm.wamr.wasm_runtime_common;

// #if WASM_ENABLE_THREAD_MGR != 0
// #include "../libraries/thread-mgr/thread_manager.h"
// #endif

WASMExecEnv* wasm_exec_env_create_internal(WASMModuleInstanceCommon* module_inst, uint stack_size) {
    uint64 total_size = offsetof(WASMExecEnv, wasm_stack.s.bottom) + cast(uint64) stack_size;
    WASMExecEnv* exec_env;

    if (total_size >= UINT_MAX || !(exec_env = wasm_runtime_malloc(cast(uint) total_size)))
        return NULL;

    memset(exec_env, 0, cast(uint) total_size);

    version (WASM_ENABLE_AOT) {
        if (!(exec_env.argv_buf = wasm_runtime_malloc(uint.sizeof * 64))) {
            goto fail1;
        }
    }

    version (WASM_ENABLE_THREAD_MGR) {
        if (os_mutex_init(&exec_env.wait_lock) != 0) {
            goto fail2;
        }
        if (os_cond_init(&exec_env.wait_cond) != 0) {
            goto fail3;
        }

        exec_env.module_inst = module_inst;
        exec_env.wasm_stack_size = stack_size;
        exec_env.wasm_stack.s.top_boundary = exec_env.wasm_stack.s.bottom + stack_size;
        exec_env.wasm_stack.s.top = exec_env.wasm_stack.s.bottom;
        return exec_env;

        version (WASM_ENABLE_THREAD_MGR) {
        fail3:
            os_mutex_destroy(&exec_env.wait_lock);
        fail2:
        }
        version (WASM_ENABLE_AOT) {
            wasm_runtime_free(exec_env.argv_buf);
        fail1:
        }
        wasm_runtime_free(exec_env);
        return NULL;
    }
}

void wasm_exec_env_destroy_internal(WASMExecEnv* exec_env) {
    version (OS_ENABLE_HW_BOUND_CHECK) {
        WASMJmpBuf* jmpbuf = exec_env.jmpbuf_stack_top;
        WASMJmpBuf* jmpbuf_prev;
        while (jmpbuf) {
            jmpbuf_prev = jmpbuf.prev;
            wasm_runtime_free(jmpbuf);
            jmpbuf = jmpbuf_prev;
        }
    }
    version (WASM_ENABLE_THREAD_MGR) {
        os_mutex_destroy(&exec_env.wait_lock);
        os_cond_destroy(&exec_env.wait_cond);
    }
    version (WASM_ENABLE_AOT) {
        wasm_runtime_free(exec_env.argv_buf);
    }
    wasm_runtime_free(exec_env);
}

WASMExecEnv* wasm_exec_env_create(WASMModuleInstanceCommon* module_inst, uint stack_size) {
    WASMExecEnv* exec_env = wasm_exec_env_create_internal(module_inst, stack_size);
    /* Set the aux_stack_boundary to 0 */
    exec_env.aux_stack_boundary = 0;
    version (WASM_ENABLE_THREAD_MGR) {
        WASMCluster* cluster;

        if (!exec_env)
            return NULL;

        /* Create a new cluster for this exec_env */
        cluster = wasm_cluster_create(exec_env);
        if (!cluster) {
            wasm_exec_env_destroy_internal(exec_env);
            return NULL;
        }
    }
    return exec_env;
}

void wasm_exec_env_destroy(WASMExecEnv* exec_env) {
    version (WASM_ENABLE_THREAD_MGR) {
        /* Terminate all sub-threads */
        WASMCluster* cluster = wasm_exec_env_get_cluster(exec_env);
        if (cluster) {
            wasm_cluster_terminate_all_except_self(cluster, exec_env);
            wasm_cluster_del_exec_env(cluster, exec_env);
        }
    }
    wasm_exec_env_destroy_internal(exec_env);
}

WASMModuleInstanceCommon* wasm_exec_env_get_module_inst(WASMExecEnv* exec_env) {
    return exec_env.module_inst;
}

void wasm_exec_env_set_thread_info(WASMExecEnv* exec_env) {
    exec_env.handle = os_self_thread();
    exec_env.native_stack_boundary = os_thread_get_stack_boundary()
        + RESERVED_BYTES_TO_NATIVE_STACK_BOUNDARY;
}

version (WASM_ENABLE_THREAD_MGR) {
    void* wasm_exec_env_get_thread_arg(WASMExecEnv* exec_env) {
        return exec_env.thread_arg;
    }

    void wasm_exec_env_set_thread_arg(WASMExecEnv* exec_env, void* thread_arg) {
        exec_env.thread_arg = thread_arg;
    }
}

version (OS_ENABLE_HW_BOUND_CHECK) {
    void wasm_exec_env_push_jmpbuf(WASMExecEnv* exec_env, WASMJmpBuf* jmpbuf) {
        jmpbuf.prev = exec_env.jmpbuf_stack_top;
        exec_env.jmpbuf_stack_top = jmpbuf;
    }

    WASMJmpBuf* wasm_exec_env_pop_jmpbuf(WASMExecEnv* exec_env) {
        WASMJmpBuf* stack_top = exec_env.jmpbuf_stack_top;

        if (stack_top) {
            exec_env.jmpbuf_stack_top = stack_top.prev;
            return stack_top;
        }

        return NULL;
    }
}
