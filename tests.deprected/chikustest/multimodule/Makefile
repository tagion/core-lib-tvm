REPOROOT?=${shell git rev-parse --show-toplevel}

DC?=dmd
SRC:=src
BIN:=bin
DFILES?=${shell find . -path ./app-wasm -prune -false -o -name "*.d" -printf "%P "}

IWASM_ROOT:=$(REPOROOT)/wasm-micro-runtime/
LIBS=$(REPOROOT)/bin/libwarm.a
MAIN:=multimodule

DFLAGS+=-I$(REPOROOT)
DFLAGS+=-g

all: $(MAIN) 

run: all 
	@echo "\n---- WASM Better-C -----"
	@./$(MAIN) -f app-wasm/mC.wasm

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
