APP:= testapp.wasm
APPDIR:=wasm-apps
REPOROOT?=${shell git rev-parse --show-toplevel}
IWASM_ROOT:=$(REPOROOT)/wasm-micro-runtime/

$(APP): 
	/opt/wasi-sdk/bin/clang --target=wasm32 -O0 -z stack-size=4096 -Wl,--initial-memory=65536 --sysroot=${IWASM_ROOT}/wamr-sdk/app/libc-builtin-sysroot -Wl,--allow-undefined-file=${IWASM_ROOT}/wamr-sdk/app/libc-builtin-sysroot/share/defined-symbols.txt -Wl,--no-threads,--strip-all,--no-entry -nostdlib -Wl,--export-all -o ./$@ ./$(@:.wasm=.c)
clean:
	rm ./*.wasm