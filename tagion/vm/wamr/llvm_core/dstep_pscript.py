#!/usr/bin/python

import subprocess
import os
os.system('mkdir ./bin')
REPOROOT=subprocess.check_output('git rev-parse --show-toplevel', shell=True).strip()
#DSTEP:=dstep
#DFLAGS+=-I$(REPOROOT)
#DFLAGS+=-I$(REPOROOT)/../tagion_basic
#
OFLAGS='-DBH_FREE=wasm_runtime_free '
OFLAGS+='-DBH_MALLOC=wasm_runtime_malloc '
OFLAGS+='-DBH_PLATFORM_LINUX '
OFLAGS+='-DBUILD_TARGET_X86_64 '
OFLAGS+='-DWASM_ENABLE_AOT=0 '
OFLAGS+='-DWASM_ENABLE_BULK_MEMORY=0 '
OFLAGS+='-DWASM_ENABLE_FAST_INTERP=0 '
OFLAGS+='-DWASM_ENABLE_INTERP=1 '
OFLAGS+='-DWASM_ENABLE_LIBC_BUILTIN=1 '
OFLAGS+='-DWASM_ENABLE_MINI_LOADER=0 '
OFLAGS+='-DWASM_ENABLE_LIB_PTHREAD=0 '
OFLAGS+='-DWASM_ENABLE_MULTI_MODULE=1 '
OFLAGS+='-DWASM_ENABLE_SHARED_MEMORY=0 '
OFLAGS+='-DWASM_ENABLE_THREAD_MGR=0 '


#
#CFLAGS+=-Wall -Wextra -Wformat -Wformat-security -mindirect-branch-register 
#CFLAGS+=-std=gnu99 -ffunction-sections -fdata-sections -Wno-unused-parameter -Wno-pedantic -fPIC  
#
#BIN=bin
#LIBS+=$(BIN)/libwarm.a
#
##HEADER+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_runtime_common.h
#
INC='-I'+REPOROOT+'/wasm-micro-runtime/core/iwasm/include/ '
INC+='-I'+REPOROOT+'/wasm-micro-runtime/core/shared/platform/include/ '
INC+='-I'+REPOROOT+'/wasm-micro-runtime/core/shared/platform/linux/ '
INC+='-I'+REPOROOT+'/wasm-micro-runtime/core/shared/utils/ '
INC+='-I'+REPOROOT+'/wasm-micro-runtime/core/iwasm/common/ '
INC+='-I'+REPOROOT+'/wasm-micro-runtime/core/shared/mem-alloc/ '
INC+='-I'+REPOROOT+'/wasm-micro-runtime/core/iwasm/interpreter/ '

##INC+=-I$(REPOROOT)/wasm-micro-runtime/core/iwasm/aot
##INC+=-I$(REPOROOT)/wasm-micro-runtime/core/iwasm/libraries/lib-pthread
##INC+=-I$(REPOROOT)//wasm-micro-runtime/core/iwasm/libraries/thread-mgr
#
DEPS=REPOROOT+'/wasm-micro-runtime/core/shared/platform/linux/platform_init.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/platform/common/posix/posix_malloc.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/platform/common/posix/posix_memmap.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/platform/common/posix/posix_thread.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/platform/common/posix/posix_time.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/mem-alloc/ems/ems_alloc.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/mem-alloc/ems/ems_hmu.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/mem-alloc/ems/ems_kfc.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/mem-alloc/mem_alloc.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/utils/bh_assert.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/utils/bh_common.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/utils/bh_list.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/utils/bh_log.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/shared/utils/runtime_timer.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/iwasm/libraries/libc-builtin/libc_builtin_wrapper.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/iwasm/common/wasm_exec_env.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/iwasm/common/wasm_memory.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/iwasm/common/wasm_native.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/iwasm/common/wasm_runtime_common.c '
#DEPS+=REPOROOT+'/wasm-micro-runtime/core/iwasm/common/wasm_shared_memory.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/iwasm/interpreter/wasm_interp_classic.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/iwasm/interpreter/wasm_loader.c '
DEPS+=REPOROOT+'/wasm-micro-runtime/core/iwasm/interpreter/wasm_runtime.c '

DEPS=DEPS.split()
for x in DEPS:
	name = x.split('/')
	name=name[-1]
	name='./bin/'+name[:-1]+'d'
	os.system('dstep '+INC+' '+OFLAGS+' '+x+' -o'+name)
	
#DEPS+eval$(REPOROOT)/wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_x86_64.c.o '
#DEPS+eval$(REPOROOT)/wasm-micro-runtime/core/iwasm/libraries/lib-pthread/lib_pthread_wrapper.c.o
#DEPS+eval$(REPOROOT)/wasm-micro-runtime/core/iwasm/libraries/thread-mgr/thread_manager.c.o
#AMS:=$evalREPOROOT)/wasm-micro-runtime/core/iwasm/common/arch/invokeNative_em64.s
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/arch/invokeNative_em64.c.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/tlsf/tlsf.o
#
#OBJS:=invokeNative_em64.c.o
#OBJS+=$(notdir $(DEPS))
#OBJS:=$(addprefix $(BIN)/,$(OBJS))
#
#
#
#all:$(LIBS)
#
#$(LIBS): $(DEPS) $(AMS)
	#ar qc $@  $(OBJS) 
	#ranlib $@
#
#$(AMS): $(AMS:.c.o=.s)
	#$(AS) $< -o $(BIN)/${notdir $(@)}
#
#$(DEPS):%.c 
	#$(DSTEP) -c $(INC) $(OFLAGS) $< -o $(BIN)/${notdir $(@)}
