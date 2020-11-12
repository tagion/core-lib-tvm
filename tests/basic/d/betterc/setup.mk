REPOROOT?=${shell git rev-parse --show-toplevel}
#DC:=$(REPOROOT)/../tagion_betterc/ldc2-1.20.1-linux-x86_64/bin/ldc2
DC?=ldc2
LD:=/opt/wasi-sdk/bin/wasm-ld
#LD:=$(REPOROOT)/../tools/wasi-sdk/bin/wasm-ld

SRC:=.
BIN:=bin
MAIN:=testapp
DFILES:=$(MAIN).d
