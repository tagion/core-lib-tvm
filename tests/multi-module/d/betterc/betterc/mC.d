// mC.c
module betterc.mC;

extern(C):
@nogc:

import betterc.mA;
import betterc.mB;
//@attribute((import_module("mA"))) @attribute((import_name("A")))
//extern int A();
//@attribute((import_module("mB"))) @attribute((import_name("B")))
//extern int B();

int C() { return 12; }
int call_A() { return A(); }
int call_B() { return B(); }
