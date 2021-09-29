#!/usr/bin/perl -i.bak2
while(<>) {
    s/^(struct\s+WASMInterpFrame)/version(none)\n$1/;
    print;
}