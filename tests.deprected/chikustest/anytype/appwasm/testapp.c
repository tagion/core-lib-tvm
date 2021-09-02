#include <stdio.h>
#include <stdlib.h>

typedef struct S {
    int y;
    int x;
    double f;
} S_t;


S_t* func1() {
    S_t* ret;
    ret=malloc(sizeof(S_t));
    ret->y=43;
    ret->x=47;
    ret->f=0;
    return ret;
}

//void func2(S_t* s) {
    //s->x=12;
//}
