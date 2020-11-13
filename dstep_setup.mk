#WAMR_ROOT:=${REPOROOT}/../wasm-micro-runtime/

DSTEP_FLAGS+=-DBH_FREE=wasm_runtime_free
DSTEP_FLAGS+=-DBH_MALLOC=wasm_runtime_malloc
DSTEP_FLAGS+=-DBH_PLATFORM_LINUX
DSTEP_FLAGS+=-DBUILD_TARGET_X86_64
DSTEP_FLAGS+=-DWASM_ENABLE_BULK_MEMORY=0
DSTEP_FLAGS+=-DWASM_ENABLE_FAST_INTERP=0
DSTEP_FLAGS+=-DWASM_ENABLE_INTERP=1
DSTEP_FLAGS+=-DWASM_ENABLE_LIBC_BUILTIN=1
#DSTEP_FLAGS+=-DWASM_ENABLE_LIBC_WASI=1
DSTEP_FLAGS+=-DWASM_ENABLE_MINI_LOADER=0
DSTEP_FLAGS+=-DWASM_ENABLE_MULTI_MODULE=1
DSTEP_FLAGS+=-DWASM_ENABLE_SHARED_MEMORY=0

#WAMR_HFILES:=aot_export.h  lib_export.h  wasm_export.h

#No correcting script is performed when DSTEP_CORRECT is true
DSTEP_CORRECT:=true
DSTEP_CORRECT_2:=true
# WAMR C-header file
WAMR_OS:=linux
WAMR_HFILES_INCLUDE:=aot_export.h  wasm_export.h lib_export.h
WAMR_DIFILES:=${WAMR_HFILES_INCLUDE:.h=.di}
WAMR_INC_INCLUDE:=$(WAMR_ROOT)/core/iwasm/include/
WAMR_HFILES_INCLUDE:=${addprefix $(WAMR_INC_INCLUDE)/,$(WAMR_HFILES_INCLUDE)}

WAMR_HFILES_COMMON:=wasm_runtime_common.h wasm_native.h wasm_exec_env.h
WAMR_DIFILES+=${WAMR_HFILES_COMMON:.h=.di}
WAMR_INC_COMMON:=$(WAMR_ROOT)/core/iwasm/common/
WAMR_HFILES_COMMON:=${addprefix $(WAMR_INC_COMMON)/,$(WAMR_HFILES_COMMON)}

WAMR_HFILES_INTERPRETER:=wasm.h
WAMR_DIFILES+=${WAMR_HFILES_INTERPRETER:.h=.di}
WAMR_INC_INTERPRETER:=$(WAMR_ROOT)/core/iwasm/interpreter
WAMR_HFILES_INTERPRETER:=${addprefix $(WAMR_INC_INTERPRETER)/,$(WAMR_HFILES_INTERPRETER)}

WARM_HFILES_UTILS:=bh_list.h
WAMR_DIFILES+=${WARM_HFILES_UTILS:.h=.di}
WAMR_INC_UTILS:=$(WAMR_ROOT)/core/shared/utils
WAMR_HFILES_UTILS:=${addprefix $(WAMR_INC_UTILS)/,$(WARM_HFILES_UTILS)}



WAMR_HFILES:=$(WAMR_HFILES_INCLUDE) $(WAMR_HFILES_COMMON) $(WAMR_HFILES_INTERPRETER) $(WAMR_HFILES_UTILS)
WAMR_INC+=$(WAMR_INC_INCLUDE) $(WAMR_INC_COMMON) $(WAMR_INC_INTERPRETER)
WAMR_INC+=$(WAMR_INC_UTILS)
WAMR_INC+=$(WAMR_ROOT)/core/shared/platform/$(WAMR_OS)/

#WAMR_H:=${WAMR_ROOT}/Include/WAMR/wavm-c/wavm-c.h
WAMR_DI_ROOT:=$(REPOROOT)/tagion/vm/wamr/c/
WAMR_DIFILES:=${addprefix $(WAMR_DI_ROOT)/,$(WAMR_DIFILES)}
WAMR_PACKAGE:=tagion.vm.wamr.c
WAMR_FLAGS+=${addprefix -I,$(WAMR_INC)}
WAMR_FLAGS+=--package $(WAMR_PACKAGE)
#WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm_native

#$(WAMR_DI_ROOT)/bh_list.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm_native

$(WAMR_DI_ROOT)/wasm_export.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm_native
$(WAMR_DI_ROOT)/wasm_export.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm_exec_env
$(WAMR_DI_ROOT)/wasm_export.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).lib_export

$(WAMR_DI_ROOT)/wasm_native.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).lib_export
$(WAMR_DI_ROOT)/wasm_native.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm

$(WAMR_DI_ROOT)/lib_export.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm

$(WAMR_DI_ROOT)/wasm_exec_env.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm
$(WAMR_DI_ROOT)/wasm_exec_env.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm_runtime_common
$(WAMR_DI_ROOT)/wasm_exec_env.di:WAMR_FLAGS+=--global-import tagion.vm.wamr.platform.platform


$(WAMR_DI_ROOT)/wasm_runtime_common.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm_export
$(WAMR_DI_ROOT)/wasm_runtime_common.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).lib_export
$(WAMR_DI_ROOT)/wasm_runtime_common.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm
$(WAMR_DI_ROOT)/wasm_runtime_common.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).wasm_exec_env
$(WAMR_DI_ROOT)/wasm_runtime_common.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).bh_list

$(WAMR_DI_ROOT)/wasm.di:WAMR_FLAGS+=--global-import $(WAMR_PACKAGE).bh_list

$(WAMR_DI_ROOT)/bh_list.di:DSTEP_CORRECT:=$(SCRIPTROOT)/dtype_stdint.pl
$(WAMR_DI_ROOT)/wasm.di:DSTEP_CORRECT:=$(SCRIPTROOT)/dtype_stdint.pl
$(WAMR_DI_ROOT)/wasm_native.di:DSTEP_CORRECT:=$(SCRIPTROOT)/dtype_stdint.pl
$(WAMR_DI_ROOT)/wasm_exec_env.di:DSTEP_CORRECT:=$(SCRIPTROOT)/dtype_stdint.pl
$(WAMR_DI_ROOT)/wasm_runtime_common.di:DSTEP_CORRECT:=$(SCRIPTROOT)/dtype_stdint.pl

$(WAMR_DI_ROOT)/wasm_runtime_common.di:DSTEP_CORRECT_2:=$(SCRIPTROOT)/wasm_runtime_common.pl
$(WAMR_DI_ROOT)/wasm_export.di:DSTEP_CORRECT_2:=$(SCRIPTROOT)/wasm_export.pl

WAYS+=$(WAMR_DI_ROOT)
