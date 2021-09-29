REPOROOT?=${shell git rev-parse --show-toplevel}

include cfiles.mk

OBJS:=$(SRC:.c=.wasm)

#CC:=$(REPOROOT)/../wasi-sdk/build/llvm/bin/clang
CLANG:=/opt/wasi-sdk/bin/clang

CFLAGS+=--target=wasm32

LDFLAGS+=-nostdlib
LDFLAGS+=-Wl,--no-entry,--allow-undefined,--export-all

all: $(OBJS)

%.wasm:%.c
	$(CLANG) $(CFLAGS) $(LDFLAGS) $< -o$@

clean:
	rm -f $(OBJS)
