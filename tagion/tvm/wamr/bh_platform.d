/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.bh_platform;

// #ifndef DEPS_IWASM_APP_LIBS_BASE_BH_PLATFORM_H_
// #define DEPS_IWASM_APP_LIBS_BASE_BH_PLATFORM_H_

// #include <stdbool.h>

// typedef unsigned char uint8;
// typedef char int8;
// typedef unsigned short uint16;
// typedef short int16;
// typedef unsigned int uint32;
// typedef int int32;

// #ifndef NULL
// #  define NULL ((void*) 0)
// #endif

// #ifndef __cplusplus
// #define true 1
// #define false 0
// #define inline __inline
// #endif

// all wasm-app<->native shared source files should use WA_MALLOC/WA_FREE.
// they will be mapped to different implementations in each side
alias WA_MALLOC = malloc;

alias WA_FREE = free;



uint htonl(uint value);
uint ntohl(uint value);
ushort htons(ushort value);
ushort ntohs(ushort value);


// We are not worried for the WASM world since the sandbox will catch it.
void bh_memcpy_s(void* dst, size_t dst_len, void* src, size_t src_len) {
    memcpy(dst, src, src_len);
}
