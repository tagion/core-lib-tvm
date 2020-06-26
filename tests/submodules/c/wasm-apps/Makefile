REPOROOT?=${shell git rev-parse --show-toplevel}

include cfiles.mk

OBJS:=$(SRC:.c=.wo)

CC:=$(REPOROOT)/../wasi-sdk/build/llvm/bin/clang

CFLAGS+=--target=wasm32

LDFLAGS+=-nostdlib
LDFLAGS+=-Wl,--no-entry,--allow-undefined,--export-all

all: $(OBJS)

%.wo:%.c
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o$@

clean:
	rm -f $(OBJS)

#/opt/wasi-sdk/bin/clang     \
        --target=wasm32 -O0 -z stack-size=4096 -Wl,--initial-memory=65536 \
        --sysroot=${WAMR_DIR}/wamr-sdk/app/libc-builtin-sysroot  \
        -Wl,--allow-undefined-file=${WAMR_DIR}/wamr-sdk/app/libc-builtin-sysroot/share/defined-symbols.txt \
        -Wl,--no-threads,--strip-all,--no-entry -nostdlib \
        -Wl,--export=generate_float \
        -Wl,--export=float_to_string \
        -Wl,--export=calculate\
        -Wl,--allow-undefined \
        -o ${OUT_DIR}/wasm-apps/${OUT_FILE} ${APP_SRC}
