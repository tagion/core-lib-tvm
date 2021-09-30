MAIN:=simple_pay
EXPORTS:=run


#EXPRAFLAGS:=-inline
#TEST:=CALL_TEST

${eval ${call WASM_TEST,$(MAIN)}}
