REPOROOT?=${shell git rev-parse --show-toplevel}

include cfiles.mk

#CC:=clang
CC:=gcc
SRC:=src
BIN=bin

OBJS:=$(CFILES:.c=.o)
CFILES:=${addprefix $(SRC)/,$(CFILES)}
OBJS:=${addprefix $(BIN)/,$(OBJS)}

MAIN=basic

IWASM_ROOT:=$(REPOROOT)/../wasm-micro-runtime/
#LIBS+=$(IWASM_ROOT)/samples/basic/libvmlib.a
LIBS+=$(IWASM_ROOT)/wamr-compiler/build/libvmlib.a
#LIBS+=$(IWASM_ROOT)/wamr-compiler/build/libaotclib.a
CFLAGS+=-fPIC
CFLAGS+=-g
#CFLAGS+=-I$(IWASM_ROOT)/core/iwasm/include
CFLAGS+=-DBH_DEBUG=1
CFLAGS+=-DBH_FREE=wasm_runtime_free
CFLAGS+=-DBH_MALLOC=wasm_runtime_malloc
CFLAGS+=-DBH_PLATFORM_LINUX
CFLAGS+=-DBUILD_TARGET_X86_64
CFLAGS+=-DWASM_ENABLE_AOT=1
CFLAGS+=-DWASM_ENABLE_FAST_INTERP=0
CFLAGS+=-DWASM_ENABLE_INTERP=1
CFLAGS+=-DWASM_ENABLE_LIBC_BUILTIN=1
CFLAGS+=-DWASM_ENABLE_LIBC_WASI=1

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
#CFLAGS+=-I$(IWASM_ROOT)/core/shared/utils/
#CFLAGS+=-I$(IWASM_ROOT)/core/app-framework/base/app
#CFLAGS+=-I$(IWASM_ROOT)//core/shared/utils/uncommon/
#CFLAGS+=-I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/interpreter -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/aot -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/libraries/libc-builtin -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/include -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src -I/home/carsten/work/tagion_main/wasm-micro-runtime/samples/basic/../../core/shared/include -I/home/carsten/work/tagion_main/wasm-micro-runtime/samples/basic/../../core/iwasm/include -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/shared/platform/linux -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/shared/platform/linux/../include -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/shared/mem-alloc -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/common -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/shared/utils -I/home/carsten/work/tagion_main/wasm-micro-runtime/samples/basic/src -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/shared/utils/uncommon


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

all: $(BIN) $(MAIN)

run: all
	./$(MAIN) -f wasm-apps/testapp.wasm

$(MAIN): $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) $(LIBS) -o $@  $(LDFLAGS)

$(BIN):
	mkdir -p $(BIN)

$(BIN)/%.o: $(SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -fR $(BIN)
	rm -f $(MAIN)

#/usr/bin/cc -DBH_DEBUG=1 -DBH_FREE=wasm_runtime_free -DBH_MALLOC=wasm_runtime_malloc -DBH_PLATFORM_LINUX -DBUILD_TARGET_X86_64 -DWASM_ENABLE_AOT=1 -DWASM_ENABLE_FAST_INTERP=0 -DWASM_ENABLE_INTERP=1 -DWASM_ENABLE_LIBC_BUILTIN=1 -DWASM_ENABLE_LIBC_WASI=1 -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/interpreter -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/aot -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/libraries/libc-builtin -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/include -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src -I/home/carsten/work/tagion_main/wasm-micro-runtime/samples/basic/../../core/shared/include -I/home/carsten/work/tagion_main/wasm-micro-runtime/samples/basic/../../core/iwasm/include -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/shared/platform/linux -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/shared/platform/linux/../include -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/shared/mem-alloc -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/iwasm/common -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/shared/utils -I/home/carsten/work/tagion_main/wasm-micro-runtime/samples/basic/src -I/home/carsten/work/tagion_main/wasm-micro-runtime/core/shared/utils/uncommon  -Wall -Wextra -Wformat -Wformat-security -mindirect-branch-register -std=gnu99 -ffunction-sections -fdata-sections                                      -Wall -Wno-unused-parameter -Wno-pedantic -fPIC -g   -o CMakeFiles/basic.dir/src/main.c.o   -c /home/carsten/work/tagion_main/wasm-micro-runtime/samples/basic/src/main.c
