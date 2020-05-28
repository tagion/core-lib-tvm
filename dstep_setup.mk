WAMRROOT:=${REPOROOT}/../wasm-micro-runtime/

#WAMR_HFILES:=aot_export.h  lib_export.h  wasm_export.h

#No correcting script is performed when DSTEP_CORRECT is true
DSTEP_CORRECT:=true
DSTEP_CORRECT_2:=true
# WAMR C-header file
WAMR_OS:=linux
WAMR_HFILES_INCLUDE:=aot_export.h  wasm_export.h lib_export.h
WAMR_DIFILES:=${WAMR_HFILES_INCLUDE:.h=.di}
WAMR_INC_INCLUDE:=$(WAMRROOT)/core/iwasm/include/
WAMR_HFILES_INCLUDE:=${addprefix $(WAMR_INC_INCLUDE)/,$(WAMR_HFILES_INCLUDE)}

WAMR_HFILES_COMMON:=wasm_runtime_common.h wasm_native.h
WAMR_DIFILES+=${WAMR_HFILES_COMMON:.h=.di}
WAMR_INC_COMMON:=$(WAMRROOT)/core/iwasm/common/
WAMR_HFILES_COMMON:=${addprefix $(WAMR_INC_COMMON)/,$(WAMR_HFILES_COMMON)}

WAMR_HFILES_INTERPRETER:=wasm.h
WAMR_DIFILES+=${WAMR_HFILES_INTERPRETER:.h=.di}
WAMR_INC_INTERPRETER:=$(WAMRROOT)/core/iwasm/interpreter
WAMR_HFILES_INTERPRETER:=${addprefix $(WAMR_INC_INTERPRETER)/,$(WAMR_HFILES_INTERPRETER)}


WAMR_HFILES:=$(WAMR_HFILES_INCLUDE) $(WAMR_HFILES_COMMON) $(WAMR_HFILES_INTERPRETER)
WAMR_INC+=$(WAMR_INC_INCLUDE) $(WAMR_INC_COMMON) $(WAMR_INC_INTERPRETER)
WAMR_INC+=$(WAMRROOT)/core/shared/utils
WAMR_INC+=$(WAMRROOT)/core/shared/platform/$(WAMR_OS)/

#WAMR_H:=${WAMRROOT}/Include/WAMR/wavm-c/wavm-c.h
WAMR_DI_ROOT:=$(REPOROOT)/tagion/vm/wamr/c/
WAMR_DIFILES:=${addprefix $(WAMR_DI_ROOT)/,$(WAMR_DIFILES)}
WAMR_PACKAGE:=tagion.vm.wamr.c
WAMR_FLAGS+=${addprefix -I,$(WAMR_INC)}
WAMR_FLAGS+=--package $(WAMR_PACKAGE)
#WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm_native

$(WAMR_DI_ROOT)/wasm_export.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm_native
$(WAMR_DI_ROOT)/wasm_export.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).lib_export

$(WAMR_DI_ROOT)/wasm_native.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).lib_export
$(WAMR_DI_ROOT)/wasm_native.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm

$(WAMR_DI_ROOT)/lib_export.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm

$(WAMR_DI_ROOT)/wasm_runtime_common.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm_export
$(WAMR_DI_ROOT)/wasm_runtime_common.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).lib_export
$(WAMR_DI_ROOT)/wasm_runtime_common.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm


$(WAMR_DI_ROOT)/wasm.di:DSTEP_CORRECT:=$(SCRIPTROOT)/dtype_stdint.pl
$(WAMR_DI_ROOT)/wasm_native.di:DSTEP_CORRECT:=$(SCRIPTROOT)/dtype_stdint.pl
$(WAMR_DI_ROOT)/wasm_runtime_common.di:DSTEP_CORRECT:=$(SCRIPTROOT)/dtype_stdint.pl
$(WAMR_DI_ROOT)/wasm_runtime_common.di:DSTEP_CORRECT_2:=$(SCRIPTROOT)/wasm_runtime_common.pl
#WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm

# Change c-array to pointer
#WAMRa2p:=${SCRIPTROOT}/wasm_array2pointer.pl
#WAMRa2p:=echo ${SCRIPTROOT}/wasm_array2pointer.pl

WAYS+=$(WAMR_DI_ROOT)
