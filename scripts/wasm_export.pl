#!/usr/bin/perl -i.bak2
while(<>) {
    s/^(struct\s+WASMExecEnv)/version(none)\n$1/;
    s/^(struct\s*WASMModuleInstanceCommon;)/version(none)\n$1/;
    print;
}
