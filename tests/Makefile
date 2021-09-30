REPOROOT?=${shell git rev-parse --show-toplevel}

# DC?=ldc2
# LD:=/opt/wasi-sdk/bin/wasm-ld
SRC?=src
BIN?=$(REPOROOT)/bin

include setup.mk

#WOBJS:=${DFILES:.d=.wo}

#WOBJS:=${addprefix $(BIN)/,$(WOBJS)}
#WASM_MOD:=${WOBJS:.wo=.wasm}

WASMFLAGS+=-mtriple=wasm32-unknown-unknown-was
WASMFLAGS+=--betterC
WASMFLAGS+=-O
#LDWFLAGS+=${addprefix --export=, $(EXPORTS)}
LDWFLAGS+=--allow-undefined


#vpath %.d $(SRC)

all: $(BIN) $(WASMFILES)

info:
	@echo BIN=$(BIN)
	@echo SRC=$(SRC)
	@echo WASMFILES=$(WASMFILES)
	@echo WASM_TESTS=$(WASM_TESTS)
	@echo DFILES=$(DFILES)

$(BIN):
	mkdir -p $@

%.wasm: $(WOBJS)
	$(LD) $< $(LDWFLAGS) -o $@

$(BIN)/%.wo: $(SRC)/%.d
	$(DC) $(WASMFLAGS) -c $< -of$@


clean:
	rm -fR $(BIN)
