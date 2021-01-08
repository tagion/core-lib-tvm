REPOROOT?=${shell git rev-parse --show-toplevel}

DC?=dmd
SRC:=src
BIN:=bin
DFILES?=${shell find . -path ./app-wasm -prune -false -o -name "*.d" -printf "%P "}

IWASM_ROOT:=$(REPOROOT)/wasm-micro-runtime/
#LIBS+=$(IWASM_ROOT)/samples/multi-module/libvmlib.a
LIBS+=$(REPOROOT)/tagion/vm/wamr/libvm.a
MAIN:=anytype

DFLAGS+=-I$(REPOROOT)
DFLAGS+=-g

all: $(MAIN) 

run: all 
	@echo "\n---- WASM Better-C -----"
	@./$(MAIN) -f app-appwasm/testapp.wasm

$(MAIN):
	#cd $(IWASM_ROOT)/samples/multi-module/ ; cmake -f CMakeLists.txt; $(MAKE) vmlib;
	$(DC) $(DFLAGS) $(LIBS) $(DFILES) -of$@

lsinfo:
	echo $(DFILES)
	echo $(OBJS)

clean:
	rm -f $(MAIN)
	rm -f $(OBJS)
	$(MAKE) -C betterc clean

proper: clean
	rm -f dfiles.mk

