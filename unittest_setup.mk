
UNITTEST_DFILES+=$(REPOROOT)/lib_tvm/tests/wasm_samples.d
TESTDCFLAGS+=$(UNITTEST_DFILES)

SAMPLES+=sample_alu/sample_alu.d
WASM_SAMPLES_ROOT:=$(REPOROOT)/tests/
WASM_SAMPLES+=
#DFILES+=$(WAVM_DI)
#TESTDCFLAGS+=$(WAVM_DI)
#TESTDCFLAGS+=-I$(REPOROOT)/tests/basic/d/
#TESTDCFLAGS+=$(LIBS)
#TESTDCFLAGS+=$(TAGION_CORE)/bin/libtagion.a
#TESTDCFLAGS+=$(TAGION_DFILES)
#TESTDCFLAGS+=$(REPOROOT)/tests/basic/d/src/native_impl.d
#TESTDCFLAGS+=$(REPOROOT)/tests/unittest.d
#TESTDCFLAGS+=-g
#TESTDCFLAGS+=-main

#vpath %.d tests/basic/d/
