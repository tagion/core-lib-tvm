include setup.mk
#WAMR_DIR?:=../wasm-micro-runtime/

WOBJS:=${DFILES:.d=.wo}

#WOBJS:=testapp.wo
WOBJS:=${addprefix $(BIN)/,$(WOBJS)}
WASM_MOD:=${addsuffix .wasm,$(MAIN)}

WASMFLAGS+=-mtriple=wasm32-unknown-unknown-was
WASMFLAGS+=--betterC
#LDWFLAGS+=-z stack-size=4096
#LDWFLAGS+=--initial-memory=65536
#LDWFLAGS+=--sysroot=${WAMR_DIR}/wamr-sdk/app/libc-builtin-sysroot
#LDWFLAGS+=--allow-undefined-file=${WAMR_DIR}/wamr-sdk/app/libc-builtin-sysroot/share/defined-symbols.txt
#LDWFLAGS+=--no-threads,--strip-all,--no-entry -nostdlib
LDWFLAGS+=${addprefix --export=,$(SYMBOLS)}

SRC?=src
BIN?=bin

vpath %.d $(SRC)

all: $(BIN) $(WASM_MOD)

info:
	@echo BIN=$(BIN)
	@echo SRC=$(SRC)
	@echo WOBJS=$(WOBJS)
	@echo WASM_MOD=$(WASM_MOD)
	@echo DFILES=$(DFILES)

$(BIN):
	mkdir -p $@

%.wasm: $(WOBJS)
	$(LD) $< $(LDWFLAGS) -o $@

$(BIN)/%.wo: $(SRC)/%.d
	$(DC) $(WASMFLAGS) -c $< -of$@

dump: bin/test_array.wo
	../../../wabt/bin/wasm2wat bin/test_array.wo --enable-bulk-memory

clean:
	rm -f $(WASM_MOD)
	rm -fR $(BIN)

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
