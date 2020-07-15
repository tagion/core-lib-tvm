REPOROOT?=${shell git rev-parse --show-toplevel}
-include dfiles.mk

BETTERCWASM:=bettec/testapp.wasm

DC?=dmd
SRC:=src
BIN:=bin

OBJS:=${DFILES:.d=.o}
OBJS:=${notdir $(OBJS)}
OBJS:=${addprefix $(BIN)/,$(OBJS)}


IWASM_ROOT:=$(REPOROOT)/../wasm-micro-runtime/
LIBS+=$(REPOROOT)/wamr/build/libvmlib.a

MAIN:=multi-module



DFLAGS+=-I$(REPOROOT)
DFLAGS+=-g



ifndef DFILES
dfiles.mk:
	find src -name "*.d" -printf "DFILES+=%P\n" > $@

all: dfiles.mk
	$(MAKE) $@
else

all: $(MAIN)

run: all $(BETTERCWASM)
	@echo "\n---- WASM C        -----"
	@./$(MAIN) -f ../c/wasm-apps/testapp.wasm
	@echo "\n---- WASM Better-C -----"
	@./$(MAIN) -f betterc/testapp.wasm


ddd: all
	ddd ./$(MAIN) -f ../c/wasm-apps/testapp.wasm
endif

$(MAIN): $(OBJS)
	$(DC) $(DFLAGS) $(LIBS) $(OBJS) -of$@

$(BIN):
	mkdir -p $(BIN)

$(BIN)/%.o: $(SRC)/%.d
	$(DC) $(DFLAGS) -c $< -of$@

info:
	echo $(DFILES)
	echo ${notdir $(DFILES)}
	echo $(OBJS)

$(BETTERCWASM):
	$(MAKE) -C betterc

clean:
	rm -f $(MAIN)
	rm -f $(OBJS)
	$(MAKE) -C betterc clean

proper: clean
	rm -f dfiles.mk
