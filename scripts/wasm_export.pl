#!/usr/bin/perl -i.bak2
while(<>) {
    s/^(struct\s+WASMExecEnv)/version(none)\n$1/;
    s/^(struct\s*WASMModuleInstanceCommon;)/version(none)\n$1/;
    s/^(struct\s*wasm_val_t)/version(none)\n$1/;
    s/^(enum\s*wasm_valkind_enum)/version(none)\n$1/;
    print;
}
