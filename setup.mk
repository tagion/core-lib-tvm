include git.mk
-include $(REPOROOT)/localsetup.mk

INSTALL+=install-llvm

ifndef NOUNITTEST
#DCFLAGS+=-I$(REPOROOT)/tests/basic/d/
DCFLAGS+=-unittest
DCFLAGS+=-g
DCFLAGS+=$(DEBUG)
endif

DCFLAGS+=$(DIP1000) # Should support scope c= new C; // is(C == class)
DCFLAGS+=$(DIP25)

SCRIPTROOT:=${REPOROOT}/scripts/
WAMR_ROOT:=$(REPOROOT)/wasm-micro-runtime/


include dstep_setup.mk
#LIBS+=$(WAMR_ROOT)/wamr-sdk/out/default/runtime-sdk/lib/libvmlib.a
#LIBS+=$(BIN)/libwarm.a

# DDOC Configuration
#
-include ddoc.mk

BIN:=bin

LIBNAME:=libiwavm.a
LIBRARY:=$(BIN)/$(LIBNAME)

WAYS+=${BIN}

SOURCE:=tagion/tvm
PACKAGE:=${subst /,.,$(SOURCE)}
REVISION:=$(REPOROOT)/$(SOURCE)/revision.di

-include dstep.mk

TAGION_BASIC:=$(MAINROOT)/tagion_basic/
TAGION_UTILS:=$(MAINROOT)/tagion_utils/
TAGION_HIBON:=$(MAINROOT)/tagion_hibon/
# TAGION_CORE:=$(REPOROOT)/../tagion_core/
#include $(TAGION_BASIC)/dfiles.mk
#include $(TAGION_UTILS)/dfiles.mk

#include tagion_dfiles.mk

# INC+=$(TAGION_BASIC)
# INC+=$(TAGION_UTILS)
#INC+=$(TAGION_CORE)
INC+=$(REPOROOT)

include unittest_setup.mk
