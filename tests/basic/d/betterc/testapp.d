/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

extern(C):

int intToStr(int x, char* str, int str_len, int digit);
int get_pow(int x, int y);
int calculate_native(int n, int func1, int func2);

//
// Primitive parameters functions
//
float generate_float(int iteration, double seed1, float seed2) {
    float ret;

//    printf ("calling into WASM function: %s\n", __FUNCTION__);

    for (int i=0; i<iteration; i++){
        ret += 1.0f/seed1 + seed2;
    }

    return ret;
}

// Converts a floating-point/double number to a string.
// intToStr() is implemented outside wasm app
void float_to_string(float n, char* res, int res_size, int afterpoint) {

//    printf ("calling into WASM function: %s\n", __FUNCTION__);

    // Extract integer part
    int ipart = cast(int)n;

    // Extract floating part
    float fpart = n - cast(float)ipart;

    // convert integer part to string
    int i = intToStr(ipart, res, res_size, 0);

    // check for display option after point
    if (afterpoint != 0) {
        res[i] = '.'; // add dot

        // Get the value of fraction part upto given no.
        // of points after dot. The third parameter
        // is needed to handle cases like 233.007
        fpart = fpart * get_pow(10, afterpoint);

        intToStr(cast(int)fpart, res + i + 1, res_size - i - 1, afterpoint);
    }
}

int mul7(int n) {
//    printf ("calling into WASM function: %s,", __FUNCTION__);
    n = n * 7;
//    printf ("    %s return %d \n", __FUNCTION__, n);
    return n;
}

int mul5(int n) {
//    printf ("calling into WASM function: %s,", __FUNCTION__);
    n = n * 5;
//    printf ("    %s return %d \n", __FUNCTION__, n);
    return n;
}

alias Func=int function(int n);

int calculate(int n) {
//    printf ("calling into WASM function: %s\n", __FUNCTION__);
    Func f1= &mul5;
    Func f2= &mul7;
    return calculate_native(n, cast(uint)f1, cast(uint)f2);
}

void _start() {}
