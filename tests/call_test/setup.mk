MAIN:=call_test
EXPORTS:=func_fac


#EXPRAFLAGS:=-inline
#TEST:=CALL_TEST

${eval ${call WASM_TEST,$(MAIN)}}
