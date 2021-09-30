/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

struct Document {
}

int pay(const(Document) input, out Document output);

extern(C):

int run(const(Document) input, out Document output) {
    pay(input, output);
    return 0;
}

//pragma(inline):

// int func_add(int x, int y) {
//     return x+y;
// }

// int func_mul(int x, int y) {
//     return x+y;
// }

// long func_fac(long x) {
//     if (x <= 1) {
//         return 1;
//     }
//     else {
//         return func_fac(x-1)*x;
//     }
// }

void _start() {}
