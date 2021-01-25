#include <stdio.h>
#include <stdlib.h>

typedef struct S {
    int x;
    double f;
} S_t;


S_t* func1() {
    S_t* ret;
    ret=malloc(sizeof(S_t));
    ret->x=10;
    ret->f=1;
    return ret;
}

void func2(S_t* s) {
    s->x=12;
}
