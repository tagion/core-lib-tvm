REPOROOT?=${shell git rev-parse --show-toplevel}

DC?=ldc2
SRC:=src
BIN:=bin
DFILES?=${shell find . -path ./app-wasm -prune -false -o -name "*.d" -printf "%P "}
#INC+=-I$(REPOROOT)/tagion/vm/wamr/c/
IWASM_ROOT:=$(REPOROOT)/wasm-micro-runtime/
#LIBS+=$(IWASM_ROOT)/samples/multi-module/libvmlib.a
LIBS+=$(REPOROOT)/bin/libwarm.a
MAIN:=anytype

DFLAGS+=-I$(REPOROOT)
DFLAGS+=-g

all: $(MAIN) 

run: all 
	@echo "\n---- WASM Better-C -----"
	@./$(MAIN) -f app-appwasm/testapp.wasm

$(MAIN):
	$(DC) $(DFILES)  $(DFLAGS) $(INC) $(LIBS)  -of$@

lsinfo:
	echo $(DFILES)
	echo $(OBJS)

clean:
	rm -f $(MAIN)
	rm -f $(OBJS)
	$(MAKE) -C betterc clean

proper: clean
	rm -f dfiles.mk

