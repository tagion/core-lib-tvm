HELP+=help-main

help: $(HELP)
	@echo "make install     : Compile the main LLVM"
	@echo
	@echo "make lib       : Builds $(LIBNAME) library"
	@echo
	@echo "make unittest      : Run the unittests"
	@echo
	@echo "make subdate   : If the repo been clone with out --recursive then run the"
	@echo
	@echo "make spull     : All the submodules can be pull by"
	@echo

help-main:
	@echo "Usage "
	@echo
	@echo "make info      : Prints the Link and Compile setting"
	@echo
	@echo "make proper    : Clean all"
	@echo
	@echo "make ddoc      : Creates source documentation"
	@echo
	@echo "make PRECMD=   : Verbose mode"
	@echo "                 make PRECMD= <tag> # Prints the command while executing"
	@echo

info:
	@echo "WAYS    =$(WAYS)"
	@echo "DFILES  =$(DFILES)"
	@echo "OBJS    =$(OBJS)"
	@echo "LDCFLAGS =$(LDCFLAGS)"
	@echo "DCFLAGS  =$(DCFLAGS)"
	@echo "INCFLAGS =$(INCFLAGS)"
	@echo "GIT_REVNO=$(GIT_REVNO)"
	@echo "GIT_HASH =$(GIT_HASH)"


include git.mk

ifndef $(VERBOSE)
PRECMD?=@
endif


DC?=dmd
AR?=ar
include $(REPOROOT)/command.mk


DCFLAGS+=$(addprefix -I$(MAINROOT)/,$(DINC))

include setup.mk

-include $(REPOROOT)/dfiles.mk

#BIN:=bin/
#LDCFLAGS+=$(LINKERFLAG)-L$(BINDIR)
ARFLAGS:=rcs
BUILD?=$(REPOROOT)/build
#SRC?=$(REPOROOT)
OBJS=${DFILES:.d=.o}
#OBJS=${addprefix $(BIN)/,$(OBJS)}

LIBOBJ:=$(BIN)/libwamr.o

.SECONDARY: $(TOUCHHOOK)
.PHONY: ddoc makeway


INCFLAGS=${addprefix -I,${INC}}

#LIBRARY:=$(BIN)/$(LIBNAME)
#LIBOBJ:=${LIBRARY:.a=.o};

REVISION:=$(REPOROOT)/$(SOURCE)/revision.di
.PHONY: $(REVISION)
.SECONDARY: .touch

ifdef COV
RUNFLAGS+=--DRT-covopt="merge:1 dstpath:reports"
DCFLAGS+=-cov
endif


ifndef DFILES
include $(REPOROOT)/source.mk
endif



include $(REPOROOT)/revision.mk

ifndef DFILES
lib: dodi dfiles.mk
	$(MAKE) lib
	$(MAKE) -f wasm_lib.mk

unittest: dfiles.mk
	$(MAKE) unittest
else
lib: $(REVISION) $(LIBRARY)

unittest: dodi $(UNITTEST)
	export LD_LIBRARY_PATH=$(LIBBRARY_PATH); $(UNITTEST)

debug: $(UNITTEST)
	export LD_LIBRARY_PATH=$(LIBBRARY_PATH); ddd $(UNITTEST)

$(UNITTEST): $(LIBS) $(WAYS)
	$(PRECMD)$(DC) $(DCFLAGS) $(INCFLAGS) $(DFILES) $(TESTDCFLAGS) $(LDCFLAGS) $(OUTPUT)$@
#$(LDCFLAGS)

endif

define LINK
$(1): $(1).d $(LIBRARY)
	@echo "########################################################################################"
	@echo "## Linking $(1)"
#	@echo "########################################################################################"
	$(PRECMD)$(DC) $(DCFLAGS) $(INCFLAGS) $(1).d $(OUTPUT)$(BIN)/$(1) $(LDCFLAGS)
endef

$(eval $(foreach main,$(MAIN),$(call LINK,$(main))))

makeway: ${WAYS}

include $(REPOROOT)/makeway.mk
$(eval $(foreach dir,$(WAYS),$(call MAKEWAY,$(dir))))

%.touch:
	@echo "########################################################################################"
	@echo "## Create dir $(@D)"
	$(PRECMD)mkdir -p $(@D)
	$(PRECMD)touch $@

$(DDOCMODULES): $(DFILES)
	$(PRECMD)echo $(DFILES) | scripts/ddocmodule.pl > $@

#include $(DDOCBUILDER)

$(LIBRARY): ${DFILES}
	@echo "########################################################################################"
	@echo "## Library $@"
	@echo "########################################################################################"
	${PRECMD}$(DC) ${INCFLAGS} $(DCFLAGS) $(DFILES) -c $(OUTPUT)$(LIBRARY)

install: $(INSTALL)

CLEANER+=clean

subdate:
	git submodule update --init --recursive

spull:
	git pull --recurse-submodules

clean:
	rm -f $(LIBRARY)
	rm -f $(BIN)/*.o
	rm -f $(UNITTEST) $(UNITTEST).o

proper: $(CLEANER)
	rm -fR $(WAYS)
	rm -f dfiles.mk

$(PROGRAMS):
	$(DC) $(DCFLAGS) $(LDCFLAGS) $(OUTPUT) $@

install-llvm:
	cd $(REPOROOT)/wasm-micro-runtime/wamr-compiler/; ./build_llvm.sh
