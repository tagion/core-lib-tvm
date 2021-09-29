REPOROOT?=${shell git rev-parse --show-toplevel}

include cfiles.mk

WASMAPPROOT:=wasm-apps

CC:=clang-10
#CC:=gcc
SRC:=src
BIN:=bin

OBJS:=$(CFILES:.c=.o)
CFILES:=${addprefix $(SRC)/,$(CFILES)}
OBJS:=${addprefix $(BIN)/,$(OBJS)}

MAIN?=basic

IWASM_ROOT:=$(REPOROOT)/wasm-micro-runtime/
LIBS+=$(IWASM_ROOT)/samples/multi-module/libvmlib.a

#LIBS+=$(IWASM_ROOT)/wamr-compiler/build/libaotclib.a
CFLAGS+=-fPIC
CFLAGS+=-g
#CFLAGS+=-I$(IWASM_ROOT)/core/iwasm/include
CFLAGS+=-DBH_DEBUG=1
CFLAGS+=-DBH_FREE=wasm_runtime_free
CFLAGS+=-DBH_MALLOC=wasm_runtime_malloc
CFLAGS+=-DBH_PLATFORM_LINUX
CFLAGS+=-DBUILD_TARGET_X86_64
CFLAGS+=-DWASM_ENABLE_BULK_MEMORY=0
CFLAGS+=-DWASM_ENABLE_FAST_INTERP=0
CFLAGS+=-DWASM_ENABLE_INTERP=1
CFLAGS+=-DWASM_ENABLE_LIBC_BUILTIN=1
CFLAGS+=-DWASM_ENABLE_LIBC_WASI=1
CFLAGS+=-DWASM_ENABLE_MINI_LOADER=0
CFLAGS+=-DWASM_ENABLE_MULTI_MODULE=1
CFLAGS+=-DWASM_ENABLE_SHARED_MEMORY=0

CFLAGS+=-Wall
CFLAGS+=-Wextra
CFLAGS+=-Wformat
CFLAGS+=-Wformat-security
CFLAGS+=-mindirect-branch-register
CFLAGS+=-std=gnu99
CFLAGS+=-ffunction-sections
CFLAGS+=-fdata-sections
CFLAGS+=-Wno-unused-parameter
CFLAGS+=-Wno-pedantic

IWASM_INCS+=core/iwasm/interpreter
IWASM_INCS+=core/iwasm/aot core/iwasm/libraries/libc-builtin
IWASM_INCS+=core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/include
IWASM_INCS+=core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src
IWASM_INCS+=samples/basic/../../core/shared/include
IWASM_INCS+=samples/basic/../../core/iwasm/include
IWASM_INCS+=core/shared/platform/linux core/shared/platform/linux/../include
IWASM_INCS+=core/shared/mem-alloc core/iwasm/common
IWASM_INCS+=core/shared/utils samples/basic/src
IWASM_INCS+=core/shared/utils/uncommon

CFLAGS+=${addprefix -I$(IWASM_ROOT)/,$(IWASM_INCS)}

LDFLAGS+=-lpthread
LDFLAGS+=-lm
#LDFLAGS+=$(REPOROOT)/wasm-micro-runtime/samples/basic/cmake_build/CMakeFiles/basic.dir/home/Abe/documents/tagion_regression/tagion_wamr/wasm-micro-runtime/core/shared/utils/uncommon/bh_read_file.c.o

all: $(BIN) $(MAIN) wasm

run: all
	./$(MAIN) -f wasm-apps/testapp.wasm

$(MAIN): $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) $(LIBS) -o $@  $(LDFLAGS)

$(BIN):
	mkdir -p $(BIN)

$(BIN)/%.o: $(SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

wasm:
	$(MAKE) -C $(WASMAPPROOT)

clean:
	rm -fR $(BIN)
	rm -f $(MAIN)
	$(MAKE) -C $(WASMAPPROOT) $@
