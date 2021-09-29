#MAIN:=simple_alu

#DC?=ldc2
#LD:=/opt/wasi-sdk/bin/wasm-ld

#SRC:=.
#BIN:=bin
#DFILES:=$(MAIN).d

#EXPORTS+=generate_float
#EXPORTS+=float_to_string
#EXPORTS+=calculate
EXPORTS+=func_inc_1
