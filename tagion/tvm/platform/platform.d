module tagion.tvm.platform.platform;

import core.sys.posix.pthread;

alias korp_tid=pthread_t;

import core.sys.posix.setjmp;

alias korp_jmpbuf=jmp_buf;

import core.sys.posix.pthread;

alias korp_mutex=pthread_mutex_t;
enum BLOCK_ADDR_CACHE_SIZE=64;
enum BLOCK_ADDR_CONFLICT_SIZE=2;

version(BUILD_TARGET_ARM_VFP) {
    enum BUILD_TARGET_ARM_VFP=true;
}
else {
    enum BUILD_TARGET_ARM_VFP=false;
}

version(BUILD_TARGET_X86_32) {
    enum BUILD_TARGET_X86_32=true;
}
else {
    enum BUILD_TARGET_X86_32=false;
}

version(BUILD_TARGET_ARM) {
    enum BUILD_TARGET_ARM = true;
}
else {
    enum BUILD_TARGET_ARM = false;
}

version(BUILD_TARGET_THUMB_VFP) {
    enum BUILD_TARGET_THUMB_VFP=true;
}
else {
    enum BUILD_TARGET_THUMB_VFP=false;
}

version(BUILD_TARGET_THUMB) {
    enum BUILD_TARGET_THUMB = true;
}
else {
    enum BUILD_TARGET_THUMB = false;
}

version(BUILD_TARGET_MIPS) {
    enum BUILD_TARGET_MIPS = true;
}
else {
    enum BUILD_TARGET_MIPS = false;
}

version(BUILD_TARGET_XTENSA) {
    enum BUILD_TARGET_XTENSA = true;
}
else {
    enum BUILD_TARGET_XTENSA = false;
}
