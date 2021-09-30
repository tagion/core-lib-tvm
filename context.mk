ifdef WASM_TEST
SOURCE_FIND_EXCLUDE += "*/tagion/vm/wamr/*"
else
SOURCE_FIND_EXCLUDE += "*/scripts/*"
SOURCE_FIND_EXCLUDE += "*/tvm/platform/*"
SOURCE_FIND_EXCLUDE += "*/tests/*"
SOURCE_FIND_EXCLUDE += "*/tests.deprected/*"
endif

libtagiontvm.ctx: libtagionbasic.o libtagionwasm.o
	@
