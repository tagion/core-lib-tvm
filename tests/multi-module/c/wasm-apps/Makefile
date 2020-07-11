REPOROOT?=${shell git rev-parse --show-toplevel}

include cfiles.mk

OBJS:=$(SRC:.c=.wasm)

CC:=$(REPOROOT)/../wasi-sdk/build/llvm/bin/clang

CFLAGS+=--target=wasm32

LDFLAGS+=-nostdlib
LDFLAGS+=-Wl,--no-entry,--allow-undefined,--export-all

all: $(OBJS)

%.wasm:%.c
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o$@

clean:
	rm -f $(OBJS)
