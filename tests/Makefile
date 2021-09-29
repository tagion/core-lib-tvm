REPOROOT?=${shell git rev-parse --show-toplevel}

# DC?=ldc2
# LD:=/opt/wasi-sdk/bin/wasm-ld
SRC?=src
BIN?=$(REPOROOT)/bin

include setup.mk

WOBJS:=${DFILES:.d=.wo}

WOBJS:=${addprefix $(BIN)/,$(WOBJS)}
WASM_MOD:=${WOBJS:.wo=.wasm}

WASMFLAGS+=-mtriple=wasm32-unknown-unknown-was
WASMFLAGS+=--betterC
WASMFLAGS+=-O
#LDWFLAGS+=${addprefix --export=, $(EXPORTS)}
LDWFLAGS+=--allow-undefined


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


clean:
	rm -f $(WASM_MOD)
	rm -fR $(BIN)
