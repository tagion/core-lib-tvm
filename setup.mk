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

LIBNAME:=libwavm.a

# DDOC Configuration
#
-include ddoc.mk

BIN:=$(REPOROOT)/bin/
BUILD?=$(REPOROOT)/build

WAYS+=${BIN}
WAYS+=${BUILD}

SOURCE:=tagion/vm/iwasm
PACKAGE:=${subst /,.,$(SOURCE)}
test33:
	echo $(PACKAGE)
	echo $(SOURCE)

# tagion.vm.iwasm
# bar:= $(subst $(space),$(comma),$(foo))
REVISION:=$(REPOROOT)/$(SOURCE)/revision.di

-include dstep.mk

TAGION_CORE:=$(REPOROOT)/../tagion_core/

INC+=$(TAGION_CORE)
INC+=$(REPOROOT)
INC+=$(P2PLIB)
INC+=$(SECP256K1ROOT)/src/
INC+=$(SECP256K1ROOT)/


#External libaries
#openssl
#secp256k1 (elliptic curve signature library)
SECP256K1ROOT:=$(REPOROOT)/../secp256k1
SECP256K1LIB:=$(SECP256K1ROOT)/.libs/libsecp256k1.a

P2PLIB:=$(REPOROOT)/../libp2pDWrapper/
#DCFLAGS+=-I$(P2PLIB)

LDCFLAGS+=$(LINKERFLAG)-lssl
LDCFLAGS+=$(LINKERFLAG)-lgmp
LDCFLAGS+=$(LINKERFLAG)-lcrypto

LDCFLAGS+=$(P2PLIB)bin/libp2p.a
LDCFLAGS+=$(P2PLIB)bin/libp2p_go.a
LDCFLAGS+=$(SECP256K1LIB)


UNITTEST:=bin/uinttest

#DFILES+=$(WAVM_DI)
#TESTDCFLAGS+=$(WAVM_DI)
TESTDCFLAGS+=$(LIBS)
TESTDCFLAGS+=$(TAGION_CORE)/bin/libtagion.a
TESTDCFLAGS+=$(REPOROOT)/tests/unittest.d
TESTDCFLAGS+=-main

TESTDCFLAGS+=$(OUTPUT)$(UNITTEST)
TESTDCFLAGS+=$(LDCFLAGS)

#TESTDCFLAGS+=-L-lunwind -L-L/usr/lib/llvm-6.0/lib -L-lLLVM-6.0 -L-L/home/carsten/work/tagion_main/tagion_wavm/../WAVM/ -L-lWAVM


#MAIN+=unittest
