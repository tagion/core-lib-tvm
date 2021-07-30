/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.bh_assert;

import tagion.tvm.wamr.bh_platform;
// #ifndef _BH_ASSERT_H
// #define _BH_ASSERT_H

// #include "bh_platform.h"

// #ifdef __cplusplus
// extern "C" {
// #endif

// #if BH_DEBUG != 0
//     debig
// void bh_assert_internal(int v, const char *file_name, int line_number,
//                         const char *expr_string);
// #define bh_assert(expr) bh_assert_internal((int)(uintptr_t)(expr), \
//                                             __FILE__, __LINE__, #expr)
// #else
// #define bh_assert(expr) (void)0
// #endif /* end of BH_DEBUG */

// #ifdef __cplusplus
// }
// #endif

// #endif /* end of _BH_ASSERT_H */

/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

//#include "bh_assert.h"

void bh_assert_internal(int v, const char* file_name, int line_number,
                        const char* expr_string) {
    int i;

    if (v) {
        return;
    }

    if (!file_name) {
        file_name = "NULL FILENAME";
    }

    if (!expr_string) {
        expr_string = "NULL EXPR_STRING";
    }

    os_printf("\nASSERTION FAILED: %s, at file %s, line %d\n",
              expr_string, file_name, line_number);

    i = os_printf(" ");

    /* divived by 0 to make it abort */
    assert(0);
    // os_printf("%d\n", i / (i - 1));
    // while (1);
}
