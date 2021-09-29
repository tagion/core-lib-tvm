REPOROOT?=${shell git rev-parse --show-toplevel}
DC?=ldc2
LD:=/opt/wasi-sdk/bin/wasm-ld

BIN:=bin
MAIN:=testapp
DFILES:=$(MAIN).d
WOBJS:=${DFILES:.d=.wo}
WOBJS:=${addprefix $(BIN)/,$(WOBJS)}
WASM_MOD:=${addsuffix .wasm,$(MAIN)}

WASMFLAGS+=-mtriple=wasm32-unknown-unknown-was
WASMFLAGS+=--betterC
LDWFLAGS+=--export=generate_crazy_int
LDWFLAGS+=--allow-undefined

all: $(BIN) $(WASM_MOD)

info:
	@echo BIN=$(BIN)
	@echo WOBJS=$(WOBJS)
	@echo WASM_MOD=$(WASM_MOD)
	@echo DFILES=$(DFILES)

$(BIN):
	mkdir -p $@

%.wasm: $(WOBJS)
	$(LD) $< $(LDWFLAGS) -o $@

$(BIN)/%.wo: %.d
	$(DC) $(WASMFLAGS) -c $< -of$@

clean:
	rm -f $(WASM_MOD)
	rm -fR $(BIN)


