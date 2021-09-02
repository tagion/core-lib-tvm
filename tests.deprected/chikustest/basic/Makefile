DC?=ldc2
LD:=/opt/wasi-sdk/bin/wasm-ld
BIN?=bin
DC?=dmd
BIN:=bin
MAIN:=chikustest
BETTERCWASM:=testapp.wasm
REPOROOT?=${shell git rev-parse --show-toplevel}
DFILES?=${shell find . -path ./appBetterc -prune -false -o -name "*.d" -printf "%P "}
IWASM_ROOT:=$(REPOROOT)/wasm-micro-runtime/
LIBS+=$(IWASM_ROOT)/wamr-compiler/libvmlib.a

OBJS:=${DFILES:.d=.o}
OBJS:=${notdir $(OBJS)}
OBJS:=${addprefix $(BIN)/,$(OBJS)}
DFLAGS+=-I$(REPOROOT)
DFLAGS+=-g


info:
	@echo "Please select the follow options: "
	@echo "make all"
	@echo "<<all: This command complie all the rules and generate al the output files>>"
	@echo 
	@echo "make run"
	@echo "<<run: This command execute the testapp>>"
	@echo 
	@echo "make ddd"
	@echo "<<ddd: Compiles the ddd files>>"
	@echo 
	@echo "########### Variables ###########"
	@echo OBJ=$(OBJS)
	@echo BIN=$(BIN)
	@echo DFILES=$(DFILES)

all: $(MAIN) 

run: all $(BETTERCWASM)
	@echo "\n---- WASM Better-C -----"
	@./$(MAIN) -f appBetterc/testapp.wasm


ddd: all
	ddd ./$(MAIN) -f ../c/wasm-apps/testapp.wasm

$(MAIN): $(OBJS)
	$(DC) $(DFLAGS) $(LIBS) $(OBJS) -of$@

$(BIN):
	mkdir -p $(BIN)

$(BIN)/%.o: %.d
	$(DC) $(DFLAGS) -c $< -of$@

$(BETTERCWASM):
	$(MAKE) -C appBetterc

clean:
	rm -f $(MAIN)
	rm -f $(OBJS)
	$(MAKE) -C betterc clean

