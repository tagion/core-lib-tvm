REPOROOT?=${shell git rev-parse --show-toplevel}
include $(REPOROOT)/git.mk
REVNO?=$(GIT_REVNO)
HASH?=$(GIT_HASH)


ifndef $(VERBOSE)
PRECMD?=@
endif

DC?=dmd
AR?=ar
include $(REPOROOT)/command.mk

include setup.mk

-include $(REPOROOT)/dfiles.mk

#BIN:=$(REPOROOT)/bin/
LDCFLAGS+=$(LINKERFLAG)-L$(BIN)
ARFLAGS:=rcs
BUILD:=$(REPOROOT)/build
#SRC?=$(REPOROOT)
OBJS=${DFILES:.d=.o}
#OBJS=${addprefix $(BIN)/,$(OBJS)}

LIBOBJ:=$(BIN)/libiwavm.o

.SECONDARY: $(TOUCHHOOK)
.PHONY: ddoc makeway


INCFLAGS=${addprefix -I,${INC}}

.PHONY: $(REVISION)
.SECONDARY: .touch

ifdef COV
RUNFLAGS+=--DRT-covopt="merge:1 dstpath:reports"
DCFLAGS+=-cov
endif

HELPER:=help-main

help-master: help-main
	@echo "make lib       : Builds $(LIBNAME) library"
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
	@echo "DFILES  =$(DFILES)"
	@echo "OBJS    =$(OBJS)"
	@echo "LDCFLAGS=$(LDCFLAGS)"
	@echo "DCFLAGS =$(DCFLAGS)"
	@echo "INCFLAGS=$(INCFLAGS)"

include revsion.mk

include $(REPOROOT)/source.mk

ifndef DFILES
lib: dfiles.mk
	@echo "call lib"
	$(MAKE) lib

test: lib
	$(MAKE) test
else
lib: $(REVISION) $(LIBRARY)

test: $(UNITTEST)
	export LD_LIBRARY_PATH=$(LIBBRARY_PATH); $(UNITTEST)

$(UNITTEST):
	$(PRECMD)$(DC) $(DCFLAGS) $(INCFLAGS) $(DFILES) $(TESTDCFLAGS) $(OUTPUT)$@
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

ddoc: $(DDOCMODULES)
	@echo "########################################################################################"
	@echo "## Creating DDOC"
	${PRECMD}ln -fs ../candydoc ddoc
	$(PRECMD)$(DC) ${INCFLAGS} $(DDOCFLAGS) $(DDOCFILES) $(DFILES) $(DD)$(DDOCROOT)

%.o: %.c
	@echo "########################################################################################"
	@echo "## compile "$(notdir $<)
	$(PRECMD)gcc  -m64 $(CFLAGS) -c $< -o $@

%.o: %.d
	@echo "########################################################################################"
	@echo "## compile "$(notdir $<)
	${PRECMD}$(DC) ${INCFLAGS} $(DCFLAGS) $< -c $(OUTPUT)$@

test33:$(OBJS)


$(LIBRARY): ${DFILES}
	@echo "########################################################################################"
	@echo "## Library $@"
	@echo "########################################################################################"
	${PRECMD}$(DC) ${INCFLAGS} $(DCFLAGS) $(DFILES) -c -lib -of$(LIBRARY)

CLEANER+=clean

clean:
	rm -f $(LIBRARY)
	rm -f ${OBJS}
	rm -f $(UNITTEST) $(UNITTEST).o

proper: $(CLEANER)
	rm -fR ${WAYS}

$(PROGRAMS):
	$(DC) $(DCFLAGS) $(LDCFLAGS) $(OUTPUT) $@
