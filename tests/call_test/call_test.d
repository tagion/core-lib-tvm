/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

extern(C):

pragma(inline):

int func_add(int x, int y) {
    return x+y;
}

int func_mul(int x, int y) {
    return x+y;
}

long func_fac(long x) {
    if (x <= 1) {
        return 1;
    }
    else {
        return func_fac(x-1)*x;
    }
}

void _start() {}
