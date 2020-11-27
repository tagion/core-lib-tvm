REPOROOT?=${shell git rev-parse --show-toplevel}

include cfiles.mk

CC:=gcc
SRC:=src
BIN=bin

OBJS:=$(CFILES:.c=.o)
CFILES:=${addprefix $(SRC)/,$(CFILES)}
OBJS:=${addprefix $(BIN)/,$(OBJS)}

MAIN=basic

IWASM_ROOT:=$(REPOROOT)/wasm-micro-runtime/
LIBS+=$(IWASM_ROOT)/wamr-compiler/libvmlib.a

IWASM_INCS+=samples/basic/../../core/iwasm/include
IWASM_INCS+=core/shared/platform/linux core/shared/platform/linux/../include
IWASM_INCS+=core/shared/utils samples/basic/src
IWASM_INCS+=core/shared/utils/uncommon
CFLAGS+=${addprefix -I$(IWASM_ROOT)/,$(IWASM_INCS)}

LDFLAGS+=-lpthread
LDFLAGS+=-lm
APP:= testapp.wasm
APPDIR:=wasm-apps

all: $(BIN) $(MAIN) $(APP)

run: all
	./$(MAIN) -f wasm-apps/testapp.wasm

$(MAIN): $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) $(LIBS) -o $@  $(LDFLAGS)

$(BIN):
	mkdir -p $@

$(BIN)/%.o: $(SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

$(APP):  $(APPDIR) $(APP)
	/opt/wasi-sdk/bin/clang --target=wasm32 -O0 -z stack-size=4096 -Wl,--initial-memory=65536 --sysroot=${IWASM_ROOT}/wamr-sdk/app/libc-builtin-sysroot -Wl,--allow-undefined-file=${IWASM_ROOT}/wamr-sdk/app/libc-builtin-sysroot/share/defined-symbols.txt -Wl,--no-threads,--strip-all,--no-entry -nostdlib -Wl,--export=generate_float -Wl,--export=float_to_string -Wl,--export=calculate -Wl,--allow-undefined -o $</$@ $</$(@:.wasm=.c)

clean:
	rm -fR $(BIN)
	rm -f $(MAIN)
	rm ./wasm-apps/*.wasm

lib:
	cd $(IWASM_ROOT)/wamr-compiler; cmake CMakeLists.txt; make
