REPOROOT?=${shell git rev-parse --show-toplevel}
DC?=ldc2
DFLAGS+=-I$(REPOROOT)
DFLAGS+=-I$(REPOROOT)/../tagion_basic
#LIBS+=$(REPOROOT)/bin/libiwavm.a
LIBS+=$(REPOROOT)/wasm-micro-runtime/samples/multi-module/libvmlib.a
#INC+=-I$(REPOROOT)/wasm-micro-runtime/core/shared/utils/
#INC+=-I$(REPOROOT)/wasm-micro-runtime/core/shared/platform/linux/
#INC+=-I$(REPOROOT)/wasm-micro-runtime/core/shared/platform/include/
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/platform/linux/platform_init.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/platform/common/posix/posix_malloc.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/platform/common/posix/posix_memmap.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/platform/common/posix/posix_thread.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/platform/common/posix/posix_time.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/ems/ems_alloc.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/ems/ems_hmu.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/ems/ems_kfc.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/mem_alloc.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/tlsf/tlsf.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_assert.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_common.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_hashmap.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_list.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_log.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_queue.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/bh_vector.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/utils/runtime_timer.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/libraries/libc-builtin/libc_builtin_wrapper.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_exec_env.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_memory.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_native.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_runtime_common.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_shared_memory.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/interpreter/wasm_interp_classic.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/interpreter/wasm_loader.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/interpreter/wasm_runtime.o
#AMS:=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/arch/invokeNative_em64.o

LIBVM:=libvm.a
OBJ := $(patsubst %.o, %.c, $(DEPS))
MAIN:=wamr
DFILES?=${shell find . -name "*.d" -printf "%P "}


all:$(MAIN)

$(MAIN): $(LIBVM) 
	$(DC) $(DFLAGS) $(LIBS) $(DFILES) -of$@

$(LIBVM): $(DEPS) $(AMS)
	ar rcs $@ $(AMS) $(DEPS) 

$(AMS): $(AMS:.o=.s)
	$(AS) $< -o $@

$(DEPS): $(OBJ)
	$(CC) -M $(INC) -c $<  -o $@

unittest:
	$(DC) unittest

prt:
	@echo $(AMS)
	@echo $(AMS:.o=.s)

clean:
	rm *.a *.o