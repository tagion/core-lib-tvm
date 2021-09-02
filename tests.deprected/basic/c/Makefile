APP:= testapp.wasm
APPDIR:=wasm-apps

$(APP):  $(APPDIR) $(APP)
	/opt/wasi-sdk/bin/clang --target=wasm32 -O0 -z stack-size=4096 -Wl,--initial-memory=65536 --sysroot=${IWASM_ROOT}/wamr-sdk/app/libc-builtin-sysroot -Wl,--allow-undefined-file=${IWASM_ROOT}/wamr-sdk/app/libc-builtin-sysroot/share/defined-symbols.txt -Wl,--no-threads,--strip-all,--no-entry -nostdlib -Wl,--export=func1 -Wl,--export=func2 -Wl, --allow-undefined -o ./$@ ./$(@:.wasm=.c)

clean:
	rm -fR $(BIN)
	rm -f $(MAIN)
	rm ./wasm-apps/*.wasm
