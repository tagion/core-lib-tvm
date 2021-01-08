REPOROOT?=${shell git rev-parse --show-toplevel}
DC?=ldc2
DFLAGS+=-I$(REPOROOT)
DFLAGS+=-I$(REPOROOT)/../tagion_basic
#DFLAGS+=-D__cplusplus
#LIBS+=$(REPOROOT)/bin/libiwavm.a
#LIBS+=$(REPOROOT)/wasm-micro-runtime/samples/multi-module/libvmlib.a
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/shared/utils/
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/shared/platform/linux/
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/shared/platform/include/
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/iwasm/include/
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/
INC+=-I$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/
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
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/wasm_shared_memory.c.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/arch/invokeNative_em64.c.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/interpreter/wasm_interp_classic.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/interpreter/wasm_loader.c.o
DEPS+=$(REPOROOT)/wasm-micro-runtime/core/iwasm/interpreter/wasm_runtime.c.o
AMS:=$(REPOROOT)/wasm-micro-runtime/core/iwasm/common/arch/invokeNative_em64.c.o
#DEPS+=$(REPOROOT)/wasm-micro-runtime/core/shared/mem-alloc/tlsf/tlsf.o

LIBVM:=libvm.a
OBJ := $(patsubst %.c.o, %.c, $(DEPS))
HFILES:=$(patsubst %.c.o, %.h, $(DEPS))
MAIN:=Wamr
UTEST:=-unittest
DFILES?=${shell find . -name "*.d" -printf "%P "}


all:$(MAIN)

$(MAIN): $(LIBVM) 
	$(DC) $(DFLAGS) $(LIBS) $(DFILES) -of$@

$(LIBVM): $(DEPS) $(AMS)
	ar qc $@ $(AMS) $(DEPS)
	ranlib $@

$(AMS): $(AMS:.c.o=.s)
	$(AS) $< -o $@

$(DEPS):%.c.o: %.c
	$(CC) -c $(INC) $< -o $@ 

unittest:
	$(DC) $(DFLAGS) $(LIBS) $(MAIN:=.d) $(UTEST)

prt:
	@echo $(AMS)
	@echo $(AMS:.o=.s)

clean:
	rm *.a *.o