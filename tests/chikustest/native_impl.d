import native_impl;
import tagion.vm.wamr.c.wasm_export;
import tagion.vm.wamr.c.wasm_runtime_common;

extern(C):

int negNum(wasm_exec_env_t exec_env, int x){
	return ~x;
}
