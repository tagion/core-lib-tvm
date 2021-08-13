/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

module tagion.tvm.wamr.lib_export;

import tagion.tvm.wamr.wasm;

extern (C):
nothrow:
@nogc:

struct NativeSymbol {
    immutable(char)* symbol;
    void* func_ptr;
    immutable(char)* signature;
    /* attachment which can be retrieved in native API by
       calling wasm_runtime_get_function_attachment(exec_env) */
    void* attachment;
}

/**
 * Get the exported APIs of base lib
 *
 * @param p_base_lib_apis return the exported API array of base lib
 *
 * @return the number of the exported API
 */
uint get_base_lib_export_apis (NativeSymbol** p_base_lib_apis);
