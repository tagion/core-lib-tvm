#MAIN:=simple_alu

DCWASM?=ldc2
LDWASM:=/opt/wasi-sdk/bin/wasm-ld

WASM_TESTS+=simple_alu
WASM_TESTS+=call_test
WASM_TESTS+=simple_pay

WASM_SAMPLES:=$(REPOROOT)/tagion/tvm/test/wasm_samples.d
WASM_SAMPLES_MODULE:=tagion.tvm.test.wasm_samples


WASMFLAGS+=-mtriple=wasm32-unknown-unknown-was
WASMFLAGS+=--betterC
#WASMFLAGS+=-O
WASMFLAGS+=--Oz

LDWFLAGS+=--allow-undefined

WASM2DATA:=$(REPOROOT)/scripts/wasm2data.d

define WASM_TEST
WASMFILES+=$(BIN)/$1.wasm
WASMSRC+=$(WASM_TEST_SRC)

$(BIN)/$1.wasm: $(BIN)/$1.wo
	$(LDWASM) $(BIN)/$1.wo ${addprefix --export=, $(EXPORTS)} $(LDWFLAGS) -o $(BIN)/$1.wasm

$(BIN)/$1.wo: $1/$1.d
	$(DCWASM) $(WASMFLAGS) $(EXPRAFLAGS) -c $1/$1.d -of$(BIN)/$1.wo


endef

include ${addsuffix /setup.mk,$(WASM_TESTS)}
