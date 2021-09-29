ifdef WASM_TEST
SOURCE_FIND_EXCLUDE += "*/tagion/vm/wamr/*"
else
SOURCE_FIND_EXCLUDE += "*/tests/*"
endif

libtagiontvm.ctx: 
	@