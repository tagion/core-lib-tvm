REPOROOT?=${shell git rev-parse --show-toplevel}

# DC?=ldc2
# LD:=/opt/wasi-sdk/bin/wasm-ld
SRC?=src
BIN?=$(REPOROOT)/bin

include setup.mk

#WASMFLAGS+=-mtriple=wasm32-unknown-unknown-was
#WASMFLAGS+=--betterC
#WASMFLAGS+=-O
#LDWFLAGS+=--allow-undefined



#all: $(BIN) $(WASMFILES)

all: $(BIN) $(WASM_SAMPLES)

info:
	@echo BIN=$(BIN)
	@echo SRC=$(SRC)
	@echo WASMFILES=$(WASMFILES)
	@echo WASM_TESTS=$(WASM_TESTS)
	@echo DFILES=$(DFILES)

$(BIN):
	mkdir -p $@

%.wasm: $(WOBJS)
	$(LDWASM) $< $(LDWFLAGS) -o $@

$(BIN)/%.wo: $(SRC)/%.d
	$(DCWASM) $(WASMFLAGS) -c $< -of$@

$(WASM_SAMPLES): $(WASMFILES)
	$(WASM2DATA) $(WASMFILES)

clean:
	rm -fR $(BIN)
