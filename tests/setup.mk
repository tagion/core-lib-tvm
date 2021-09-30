#MAIN:=simple_alu

DC?=ldc2
LD:=/opt/wasi-sdk/bin/wasm-ld

WASM_TESTS+=simple_alu
WASM_TESTS+=call_test
WASM_TESTS+=simple_pay

WASMFLAGS+=-mtriple=wasm32-unknown-unknown-was
WASMFLAGS+=--betterC
#WASMFLAGS+=-O
WASMFLAGS+=--Oz

LDWFLAGS+=--allow-undefined

define WASM_TEST
WASMFILES+=$(BIN)/$1.wasm
WASMSRC+=$(WASM_TEST_SRC)

$(BIN)/$1.wasm: $(BIN)/$1.wo
	$(LD) $(BIN)/$1.wo ${addprefix --export=, $(EXPORTS)} $(LDWFLAGS) -o $(BIN)/$1.wasm

$(BIN)/$1.wo: $1/$1.d
	$(DC) $(WASMFLAGS) $(EXPRAFLAGS) -c $1/$1.d -of$(BIN)/$1.wo


endef

include ${addsuffix /setup.mk,$(WASM_TESTS)}
