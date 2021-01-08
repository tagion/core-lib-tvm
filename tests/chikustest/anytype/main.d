module main;

import tagion.vm.wamr.c.wasm_runtime_common;
import tagion.vm.wamr.c.lib_export;
import tagion.vm.wamr.c.wasm_export;
import tagion.vm.wamr.c.wasm_c_api;
import tagion.vm.wamr.revision;
import std.getopt;
import std.stdio;
import std.format;
import std.string : fromStringz;
import std.file : fread=read;

int main(string[] args) {
    immutable program = args[0];
    bool ret = false;
    string wasm_path;
    wasm_exec_env_t exec_env;

    bool version_switch;
    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        std.getopt.config.required,
        "inputfile|f|", "Path of wasm file", &wasm_path);
    if (version_switch) {
        writefln("version %s", REVNO);
        writefln("Git handle %s", HASH);
        return 0;
    }

    /* 10M */
    static char[10 * 1024 * 1024] sandbox_memory_space;

    /* 16K */
    enum stack_size = 16 * 1024;
    enum heap_size = 16 * 1024;

    RuntimeInitArgs init_args;
    char[128] error_buf;

    /* parameters and return values */
    char*[1] wasm_args;
    ubyte[] file_buf;
    init_args.mem_alloc_type = mem_alloc_type_t.Alloc_With_Pool;
    init_args.mem_alloc_option.pool.heap_buf = sandbox_memory_space.ptr;
    init_args.mem_alloc_option.pool.heap_size = sandbox_memory_space.length;
    writeln("- wasm_runtime_full_init");

    if (!wasm_runtime_full_init(&init_args)) {
        writeln("Init runtime environment failed.");
        return -1;
    }

    // read the module wasm
    auto buffer = cast(ubyte[])wasm_path.fread();

    // loading the module
    auto wasm_module = wasm_runtime_load(buffer.ptr, cast(uint)buffer.length, error_buf.ptr, cast(uint)error_buf.length);

    // instantiate the module
    wasm_module_inst_t module_inst=wasm_runtime_instantiate(wasm_module, stack_size, heap_size,
        error_buf.ptr, error_buf.length);


    // execute functions
    //wasm_application_execute_func(module_inst, "abefenix", 0, &wasm_args[0]);
    //wasm_application_execute_func(module_inst, "abevoladora", 0, &wasm_args[0]);
    
    auto xfunc = cast(void* function())wasm_runtime_lookup_function(module_inst, "abefenix".ptr, null);

    exec_env = wasm_runtime_create_exec_env(module_inst, stack_size);



    uint num_args = 1, num_results = 1;
    wasm_val_t [1]argfs;
    wasm_val_t [1]results;

    argfs[0].kind = wasm_valkind_enum.WASM_I32;
    argfs[0].of.i32 = 8;
    
    //wasm_runtime_call_wasm_a(exec_env, xfunc, num_results, results, num_args, argfs);
    
    writeln("fib function return: %d\n", results[0].of.i32);


   //wasm_runtime_call_wasm(exec_env, xfunc, 1, &wasm_args[0]);

    wasm_runtime_deinstantiate(module_inst);

    return ret;
}
