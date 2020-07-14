module tagion.vm.wamr.platform.platform;

import core.sys.posix.pthread;

alias korp_tid=pthread_t;

import core.sys.posix.setjmp;

alias korp_jmpbuf=jmp_buf;
