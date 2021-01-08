#!/usr/bin/perl -i.bak2
while(<>) {
    s/^(struct\s*WASMModuleCommon;)/version(none)\n$1/;
    s/^(alias\s*wasm_module_t)/version(none)\n$1/;
    s/^(enum\s*wasm_name)/version(none)\n$1/;
    print;
}