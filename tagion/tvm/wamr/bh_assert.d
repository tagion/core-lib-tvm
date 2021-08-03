/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.bh_assert;

import tagion.tvm.wamr.bh_platform;
@nogc:
nothrow:
// #ifndef _BH_ASSERT_H
// #define _BH_ASSERT_H

// #include "bh_platform.h"

// #ifdef __cplusplus
// extern "C" {
// #endif

version(BH_DEBUG) {
    void bh_assert(const bool expr,
        const char* file_name=__FILE__.ptr,
        const int line = __LINE__.ptr) {

        bh_assert_internal(cast(int)(expr), file_name, line, null);
    }
}
else {
    void bh_assert(const bool) {
        // empty
    }
}

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
