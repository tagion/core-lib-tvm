// mB.c
module betterc.mB;

extern(C):
@nogc:

import betterc.mA;

int B() { return 11; }
int call_A() { return A(); }
