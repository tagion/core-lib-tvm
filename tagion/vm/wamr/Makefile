REPOROOT?=${shell git rev-parse --show-toplevel}
DC?=ldc2
DFLAGS+=-I$(REPOROOT)
DFLAGS+=-I$(REPOROOT)/../tagion_basic

OFLAGS+=-DBH_FREE=wasm_runtime_free
OFLAGS+=-DBH_MALLOC=wasm_runtime_malloc
OFLAGS+=-DBH_PLATFORM_LINUX
OFLAGS+=-DBUILD_TARGET_X86_64
OFLAGS+=-DWASM_ENABLE_AOT=0
OFLAGS+=-DWASM_ENABLE_BULK_MEMORY=0
OFLAGS+=-DWASM_ENABLE_FAST_INTERP=0
OFLAGS+=-DWASM_ENABLE_INTERP=1
OFLAGS+=-DWASM_ENABLE_LIBC_BUILTIN=1
OFLAGS+=-DWASM_ENABLE_MINI_LOADER=0
OFLAGS+=-DWASM_ENABLE_LIB_PTHREAD=0
OFLAGS+=-DWASM_ENABLE_MULTI_MODULE=1
OFLAGS+=-DWASM_ENABLE_SHARED_MEMORY=0
OFLAGS+=-DWASM_ENABLE_THREAD_MGR=0

CFLAGS+=-Wall -Wextra -Wformat -Wformat-security -mindirect-branch-register 
CFLAGS+=-std=gnu99 -ffunction-sections -fdata-sections -Wno-unused-parameter -Wno-pedantic -fPIC  

#LIBS+=$(REPOROOT)/bin/libiwavm.a
#LIBS+=$(REPOROOT)/wasm-micro-runtime/samples/multi-module/libvmlib.a
LIBS+=libvm.a
#HEADER+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_runtime_common.h

INC+=-I$(REPOROOT)/wasm-micro-runtime/core/iwasm/include/
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/shared/platform/include/
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/shared/platform/linux/
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/shared/utils/
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/iwasm/interpreter/
#INC+=-I$(REPOROOT)/wasm-micro-runtime/core/iwasm/aot
#INC+=-I$(REPOROOT)/wasm-micro-runtime/core/iwasm/libraries/lib-pthread
#INC+=-I$(REPOROOT)//wasm-micro-runtime/core/iwasm/libraries/thread-mgr

DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/platform/linux/platform_init.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/platform/common/posix/posix_malloc.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/platform/common/posix/posix_memmap.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/platform/common/posix/posix_thread.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/platform/common/posix/posix_time.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/ems/ems_alloc.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/ems/ems_hmu.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/ems/ems_kfc.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/mem_alloc.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_assert.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_common.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_hashmap.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_list.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_log.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_queue.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_vector.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/runtime_timer.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/libraries/libc-builtin/libc_builtin_wrapper.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_c_api.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_exec_env.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_memory.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_native.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_runtime_common.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_shared_memory.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/interpreter/wasm_interp_classic.c.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/interpreter/wasm_interp_fast.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/interpreter/wasm_loader.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/interpreter/wasm_runtime.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/aot/aot_loader.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/aot/aot_runtime.c.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_x86_64.c.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/libraries/lib-pthread/lib_pthread_wrapper.c.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/libraries/thread-mgr/thread_manager.c.o
AMS:=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/arch/invokeNative_em64.c.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/arch/invokeNative_em64.c.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/tlsf/tlsf.o

BIN=bin
OBJS:=$(notdir $(DEPS))
OBJS:=$(addprefix $(BIN)/,$(OBJS))
OBJS+=$(BIN)/invokeNative_em64.c.o

MAIN:=Wamr
UTEST:=-unittest
DFILES?=${shell find . -name "*.d" -printf "%P "}

all:$(MAIN)

$(MAIN): $(LIBS) 
	$(DC) -of$@ $(LIBS)  $(DFLAGS)  $(DFILES)

$(LIBS): $(DEPS) $(AMS)
	ar qc $@  $(OBJS) 
	ranlib $@

$(AMS): $(AMS:.c.o=.s)
	$(AS) $< -o $(BIN)/${notdir $(@)}

$(DEPS):%.c.o: %.c 
	$(CC) -c $(INC) $(OFLAGS) $< -o $(BIN)/${notdir $(@)}

unittest:
	$(DC) $(DFLAGS) $(LIBS) $(MAIN:=.d) $(UTEST)

clean:
	rm *.a bin/*.o