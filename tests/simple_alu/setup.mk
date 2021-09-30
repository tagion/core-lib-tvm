MAIN:=simple_alu
EXPORTS:=func_inc
EXPORTS+=func_loop

${eval ${call WASM_TEST,$(MAIN)}}
