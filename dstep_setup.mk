IWASMROOT:=${REPOROOT}/../wasm-micro-runtime/

#IWASM_HFILES:=aot_export.h  lib_export.h  wasm_export.h

#No correcting script is performed when DSTEP_CORRECT is true
DSTEP_CORRECT:=true
# IWASM C-header file
IWASM_OS:=linux
IWASM_HFILES_INCLUDE:=aot_export.h  wasm_export.h lib_export.h
IWASM_DIFILES:=${IWASM_HFILES_INCLUDE:.h=.di}
IWASM_INC_INCLUDE:=$(IWASMROOT)/core/iwasm/include/
IWASM_HFILES_INCLUDE:=${addprefix $(IWASM_INC_INCLUDE)/,$(IWASM_HFILES_INCLUDE)}

IWASM_HFILES_COMMON:=wasm_runtime_common.h wasm_native.h
IWASM_DIFILES+=${IWASM_HFILES_COMMON:.h=.di}
IWASM_INC_COMMON:=$(IWASMROOT)/core/iwasm/common/
IWASM_HFILES_COMMON:=${addprefix $(IWASM_INC_COMMON)/,$(IWASM_HFILES_COMMON)}

IWASM_HFILES_INTERPRETER:=wasm.h
IWASM_DIFILES+=${IWASM_HFILES_INTERPRETER:.h=.di}
IWASM_INC_INTERPRETER:=$(IWASMROOT)/core/iwasm/interpreter
IWASM_HFILES_INTERPRETER:=${addprefix $(IWASM_INC_INTERPRETER)/,$(IWASM_HFILES_INTERPRETER)}


IWASM_HFILES:=$(IWASM_HFILES_INCLUDE) $(IWASM_HFILES_COMMON) $(IWASM_HFILES_INTERPRETER)
IWASM_INC+=$(IWASM_INC_INCLUDE) $(IWASM_INC_COMMON) $(IWASM_INC_INTERPRETER)
IWASM_INC+=$(IWASMROOT)/core/shared/utils
IWASM_INC+=$(IWASMROOT)/core/shared/platform/$(IWASM_OS)/

#IWASM_H:=${IWASMROOT}/Include/IWASM/wavm-c/wavm-c.h
IWASM_DI_ROOT:=$(REPOROOT)/tagion/vm/iwasm/c/
IWASM_DIFILES:=${addprefix $(IWASM_DI_ROOT)/,$(IWASM_DIFILES)}
IWASM_PACKAGE:=tagion.vm.iwasm.c
IWASM_FLAGS+=${addprefix -I,$(IWASM_INC)}
IWASM_FLAGS+=--package $(IWASM_PACKAGE)
#IWASM_FLAGS+=--global-import $(IWASM_PACKAGE).wasm_native

$(IWASM_DI_ROOT)/wasm_export.di:IWASM_FLAGS+=--global-import $(IWASM_PACKAGE).wasm_native
$(IWASM_DI_ROOT)/wasm_export.di:IWASM_FLAGS+=--global-import $(IWASM_PACKAGE).lib_export

$(IWASM_DI_ROOT)/wasm_native.di:IWASM_FLAGS+=--global-import $(IWASM_PACKAGE).lib_export
$(IWASM_DI_ROOT)/wasm_native.di:IWASM_FLAGS+=--global-import $(IWASM_PACKAGE).wasm

$(IWASM_DI_ROOT)/lib_export.di:IWASM_FLAGS+=--global-import $(IWASM_PACKAGE).wasm

$(IWASM_DI_ROOT)/wasm_runtime_common.di:IWASM_FLAGS+=--global-import $(IWASM_PACKAGE).wasm_export
$(IWASM_DI_ROOT)/wasm_runtime_common.di:IWASM_FLAGS+=--global-import $(IWASM_PACKAGE).lib_export
$(IWASM_DI_ROOT)/wasm_runtime_common.di:IWASM_FLAGS+=--global-import $(IWASM_PACKAGE).wasm


$(IWASM_DI_ROOT)/wasm.di:DSTEP_CORRECT:=$(SCRIPTROOT)/dtype_stdint.pl
$(IWASM_DI_ROOT)/wasm_native.di:DSTEP_CORRECT:=$(SCRIPTROOT)/dtype_stdint.pl
$(IWASM_DI_ROOT)/wasm_runtime_common.di:DSTEP_CORRECT:=$(SCRIPTROOT)/dtype_stdint.pl
#IWASM_FLAGS+=--global-import $(IWASM_PACKAGE).wasm

# Change c-array to pointer
#IWASMa2p:=${SCRIPTROOT}/wasm_array2pointer.pl
#IWASMa2p:=echo ${SCRIPTROOT}/wasm_array2pointer.pl

WAYS+=$(IWASM_DI_ROOT)
