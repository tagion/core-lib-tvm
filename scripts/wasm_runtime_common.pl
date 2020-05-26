#!/usr/bin/perl -i.bak2
while(<>) {
    s/^(bool\s+wasm_runtime_full_init)/version(none)\n$1/;
    s/^(wasm_module_t\s+wasm_runtime_load\s+)/version(none)\n$1/;
    s/^(void\s+wasm_runtime_destroy\s+\(\);)/version(none)\n$1/;
    s/^(void\s+wasm_runtime_destroy_exec_env\s+)/version(none)\n$1/;
    print;
}
