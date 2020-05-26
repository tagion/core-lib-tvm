REPOROOT?=${shell git rev-parse --show-toplevel}

-include $(REPOROOT)/localsetup.mk

ifndef NOUNITTEST
DCFLAGS+=-unittest
DCFLAGS+=-g
DCFLAGS+=$(DEBUG)
endif

DCFLAGS+=$(DIP1000) # Should support scope c= new C; // is(C == class)
DCFLAGS+=$(DIP25)

SCRIPTROOT:=${REPOROOT}/scripts/


include dstep_setup.mk
IWASM_ROOT:=$(REPOROOT)/../wasm-micro-runtime/
LIBS+=$(IWASM_ROOT)/wamr-compiler/build/libvmlib.a

# DDOC Configuration
#
-include ddoc.mk

BIN:=bin/
#BUILD?=$(REPOROOT)/build

LIBNAME:=libiwavm.a
LIBRARY:=$(BIN)/$(LIBNAME)


WAYS+=${BIN}
#WAYS+=${BUILD}

SOURCE:=tagion/vm/iwasm
PACKAGE:=${subst /,.,$(SOURCE)}
# test33:
# 	echo $(PACKAGE)
# 	echo $(SOURCE)

# tagion.vm.iwasm
# bar:= $(subst $(space),$(comma),$(foo))
REVISION:=$(REPOROOT)/$(SOURCE)/revision.di

-include dstep.mk

TAGION_CORE:=$(REPOROOT)/../tagion_core/

-include core_dfiles.mk
TAGION_DFILES:=${addprefix $(TAGION_CORE), $(TAGION_DFILES)}
INC+=$(TAGION_CORE)
INC+=$(REPOROOT)
#INC+=$(P2PLIB)
#INC+=$(SECP256K1ROOT)/src/
#INC+=$(SECP256K1ROOT)/


#External libaries
#openssl
#secp256k1 (elliptic curve signature library)
#SECP256K1ROOT:=$(REPOROOT)/../secp256k1
#SECP256K1LIB:=$(SECP256K1ROOT)/.libs/libsecp256k1.a

#P2PLIB:=$(REPOROOT)/../libp2pDWrapper/
#DCFLAGS+=-I$(P2PLIB)

#LDCFLAGS+=$(LINKERFLAG)-lssl
#LDCFLAGS+=$(LINKERFLAG)-lgmp
#LDCFLAGS+=$(LINKERFLAG)-lcrypto

#LDCFLAGS+=$(P2PLIB)bin/libp2p.a
#LDCFLAGS+=$(P2PLIB)bin/libp2p_go.a
#LDCFLAGS+=$(SECP256K1LIB)

include unittest_setup.mk
