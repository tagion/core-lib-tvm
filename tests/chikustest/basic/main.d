module main;

import tagion.vm.wamr.c.wasm_export;
import tagion.vm.wamr.c.lib_export;
import tagion.vm.wamr.revision;
import std.getopt;
import std.stdio;
import std.format;
import native_impl;
import std.string : fromStringz;
import std.file : fread=read;

int main(string[] args) {
    immutable program = args[0];
    string wasm_path;
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

    int exit_result;
    static char[512 * 1024] global_heap_buf;
    char[128] error_buf;
    uint buf_size, stack_size = 8092, heap_size = 8092;
    char* native_buffer = null;
    int  wasm_buffer = 0;
    

    RuntimeInitArgs init_args;
    init_args.mem_alloc_type = mem_alloc_type_t.Alloc_With_Pool;
    init_args.mem_alloc_option.pool.heap_buf = global_heap_buf.ptr;
    init_args.mem_alloc_option.pool.heap_size = global_heap_buf.length;

    static NativeSymbol[] native_symbols =
        [
            {
                "negNum".ptr,         // the name of WASM function name
                &negNum,              // the native function pointer
                "(i)i".ptr,		// the function prototype signature, avoid to use i32
                null                    // attachment is null
            }
        ];

    // Native symbols need below registration phase
    init_args.n_native_symbols = cast(uint)native_symbols.length;
    init_args.native_module_name = "env".ptr;
    init_args.native_symbols = native_symbols.ptr;


    // this test lacks of memory allocation in run time TODO
    try {
        if  (!wasm_runtime_full_init(&init_args)) {
            throw new Exception(format("Init runtime environment  [%s] failed.", wasm_path));
            return -1;
        }

        scope(exit) {
            wasm_runtime_destroy();
        }

        auto buffer = cast(ubyte[])wasm_path.fread();

        if (buffer.length is 0) {
            throw new Exception(format("Open wasm app file [%s] failed.", wasm_path));
        }

        auto wasm_module = wasm_runtime_load(buffer.ptr, cast(uint)buffer.length, error_buf.ptr, cast(uint)error_buf.length);

        if (!wasm_module) {
            throw new Exception(format("Load wasm module failed. error: %s", fromStringz(error_buf.ptr)));
        }

        auto module_inst = wasm_runtime_instantiate(
            wasm_module,
            stack_size,
            heap_size,
            error_buf.ptr,
            error_buf.length);

        if (!module_inst){
            throw new Exception(format("Instantiate wasm module failed. error: %s", fromStringz(error_buf.ptr)));
        }

        scope(exit) {
            wasm_runtime_deinstantiate(module_inst);
        }

                auto exec_env = wasm_runtime_create_exec_env(module_inst, stack_size);
        if (!exec_env) {
            throw new Exception("Create wasm execution environment failed.");
        }

        scope(exit) {
            if(wasm_buffer) wasm_runtime_module_free(module_inst, wasm_buffer);
            wasm_runtime_destroy_exec_env(exec_env);
        }

        uint arg=10;

        auto xfunc = cast(void* function())wasm_runtime_lookup_function(module_inst, "generate_crazy_int".ptr, null);

        if (!(xfunc)) {
            throw new Exception(format("The generate_float wasm function is not found."));
        }

        if (wasm_runtime_call_wasm(exec_env, xfunc, 1, &arg)) {
            writefln("Native finished calling wasm function generate_crazy_int(), returned a int value: %d", arg);
        } else {
            throw new Exception(format("call wasm function generate_crazy_int failed. %s", fromStringz(wasm_runtime_get_exception(module_inst))));
        }
    }
    catch (Exception e) {
        exit_result =- 1;
        writeln(e.msg);
    }

    return exit_result;
}
