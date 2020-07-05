include git.mk
-include $(REPOROOT)/localsetup.mk

ifndef NOUNITTEST
DCFLAGS+=-I$(REPOROOT)/tests/basic/d/
DCFLAGS+=-unittest
DCFLAGS+=-g
DCFLAGS+=$(DEBUG)
endif

DCFLAGS+=$(DIP1000) # Should support scope c= new C; // is(C == class)
DCFLAGS+=$(DIP25)

SCRIPTROOT:=${REPOROOT}/scripts/


include dstep_setup.mk
WAMR_ROOT:=$(REPOROOT)/../wasm-micro-runtime/
LIBS+=$(WAMR_ROOT)/wamr-compiler/build/libvmlib.a

# DDOC Configuration
#
-include ddoc.mk

BIN:=bin

LIBNAME:=libiwavm.a
LIBRARY:=$(BIN)/$(LIBNAME)

WAYS+=${BIN}

SOURCE:=tagion/vm/wamr
PACKAGE:=${subst /,.,$(SOURCE)}
REVISION:=$(REPOROOT)/$(SOURCE)/revision.di

-include dstep.mk

TAGION_BASIC:=$(REPOROOT)/../tagion_basic/
TAGION_UTILS:=$(REPOROOT)/../tagion_utils/
TAGION_CORE:=$(REPOROOT)/../tagion_core/

include tagion_dfiles.mk

INC+=$(TAGION_BASIC)
INC+=$(TAGION_UTILS)
#INC+=$(TAGION_CORE)
INC+=$(REPOROOT)

include unittest_setup.mk
