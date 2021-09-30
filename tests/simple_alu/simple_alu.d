/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

extern(C):

int func_inc(int x) {
    return x+1;
}

int func_loop(int x, int y) {
    int result;
    if (x < y) {
    foreach(i; 0..x) {
        result+=i;
    }
    if (result > 10) {
        return result;
    }
    else {
        result +=3;
    }
    }
    foreach(i; 1..y) {
        result*=i;
    }
    return result;
}

void _start() {}
