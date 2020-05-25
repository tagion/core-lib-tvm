REPOROOT?=${shell git rev-parse --show-toplevel}
-include dfiles.mk

DC?=dmd
BIN:=bin
SRC:=src

IWASM_ROOT:=$(REPOROOT)/../wasm-micro-runtime/

OBJS:=${DFILES:.d=.o}
OBJS:=${notdir $(OBJS)}
OBJS:=${addprefix $(BIN)/,$(OBJS)}


LIBS+=$(IWASM_ROOT)/wamr-compiler/build/libvmlib.a

MAIN:=basic



DFLAGS+=-I$(REPOROOT)
DFLAGS+=-g


ifndef DFILES
dfiles.mk:
	find . -name "*.d" -printf "DFILES+=%P\n" > $@

all: dfiles.mk
	$(MAKE) $@
else

all: $(MAIN)

run: all
	./$(MAIN) -f ../c/wasm-apps/testapp.wasm

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

clean:
	rm -f $(MAIN)
	rm -f $(OBJS)

proper: clean
	rm -f dfiles.mk
