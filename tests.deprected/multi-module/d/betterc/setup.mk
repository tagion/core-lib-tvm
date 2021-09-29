REPOROOT?=${shell git rev-parse --show-toplevel}
DC?=ldc2
LD:=/opt/wasi-sdk/bin/wasm-ld

SRC:=.
BIN:=wasm-apps
#MAIN:=testapp
DFILES+=mA.d
DFILES+=mB.d
DFILES+=mC.d
