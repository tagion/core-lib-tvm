module tagion.tvm.platform.platform;

import core.sys.posix.pthread;

alias korp_tid=pthread_t;

import core.sys.posix.setjmp;

alias korp_jmpbuf=jmp_buf;

enum BLOCK_ADDR_CACHE_SIZE=64;
enum BLOCK_ADDR_CONFLICT_SIZE=2;
