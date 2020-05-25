module basic.main;
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.vm.iwasm.c.wasm_export;
import tagion.vm.iwasm.c.lib_export;
import tagion.vm.iwasm.revision;

import std.getopt;
import std.format;
import std.array : join;
import std.stdio;
import std.string : fromStringz;
import std.file : fread=read;
import std.outbuffer;

extern(C) {
    int intToStr(int x, char* str, int str_len, int digit);
    int get_pow(int x, int y);
    int calculate_native(int n, int func1, int func2);
}

int main(string[] args) {
    immutable program=args[0];
    string wasm_path;
    bool version_switch;
    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version",   "display the version",  &version_switch,
        "inputfile|f","Parh of wasm file", &wasm_path,
        );

    if (version_switch) {
        writefln("version %s", REVNO);
        writefln("Git handle %s", HASH);
        return 0;
    }

    if ( main_args.helpWanted ) {
        defaultGetoptPrinter(
            [
                format("%s version %s", program, REVNO),
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s -f <in-file>", program),
                ].join("\n"),
            main_args.options);
        return 0;
    }
    int exit_result;

    static char[512 * 1024] global_heap_buf;
    char[128] error_buf;
    uint buf_size, stack_size = 8092, heap_size = 8092;
    char* native_buffer = null;
    int wasm_buffer = 0;

    RuntimeInitArgs init_args;

    static NativeSymbol[] native_symbols =
        [
            {
                "intToStr".ptr,         // the name of WASM function name
                &intToStr,              // the native function pointer
                "(i*~i)i".ptr,		// the function prototype signature, avoid to use i32
                null                    // attachment is null
            },
            {
                "get_pow".ptr,          // the name of WASM function name
                &get_pow,               // the native function pointer
                "(ii)i".ptr,            // the function prototype signature, avoid to use i32
                null                    // attachment is null
            },
            {
                "calculate_native".ptr,
                &calculate_native,
                "(iii)i".ptr,
                null
            }
            ];

    init_args.mem_alloc_type = mem_alloc_type_t.Alloc_With_Pool;
    init_args.mem_alloc_option.pool.heap_buf = global_heap_buf.ptr;
    init_args.mem_alloc_option.pool.heap_size = global_heap_buf.length;

    // Native symbols need below registration phase
    init_args.n_native_symbols = cast(uint)native_symbols.length;
    init_args.native_module_name = "env".ptr;
    init_args.native_symbols = native_symbols.ptr;

    if  (!wasm_runtime_full_init(&init_args)) {
        writeln("Init runtime environment failed.");
        return -1;
    }

    scope(exit) {
        wasm_runtime_destroy();
    }

    auto buffer = cast(ubyte[])wasm_path.fread();

    try {
        if (buffer.length is 0) {
//        writefln("Open wasm app file [%s] failed.", wasm_path);
            throw new Exception(format("Open wasm app file [%s] failed.", wasm_path));
//        goto fail;
        }

        auto wasm_module = wasm_runtime_load(buffer.ptr, cast(uint)buffer.length, error_buf.ptr, cast(uint)error_buf.length);
        if (!wasm_module) {
            throw new Exception(format("Load wasm module failed. error: %s", fromStringz(error_buf.ptr)));
//        goto fail;
        }

        auto module_inst = wasm_runtime_instantiate(
            wasm_module,
            stack_size,
            heap_size,
            error_buf.ptr,
            error_buf.length);

        if (!module_inst) {
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

        //uint[4] argv;
        double arg_d = 0.000101;
        int arg_i=10;
        float arg_f=300.002;
        auto arg_buf=new OutBuffer;
        arg_buf.alignSize(int.sizeof);
        arg_buf.reserve(4/int.sizeof);
        arg_buf.write(arg_i);
        arg_buf.write(arg_d);
        arg_buf.write(arg_f);
//    argv[0] = 10;
        // the second arg will occupy two array elements
//    memcpy(&argv[1], &arg_d, arg_d.sizeof);
//    *cast(float*)(argv+3) = 300.002;
        auto func = cast(void* function())wasm_runtime_lookup_function(module_inst, "generate_float".ptr, null);

        if (!(func)) {
            throw new Exception(format("The generate_float wasm function is not found."));
        }


        auto argv=cast(uint[])arg_buf.toBytes;
        // pass 4 elements for function arguments
        if (!wasm_runtime_call_wasm(exec_env, func, cast(uint)argv.length, argv.ptr) ) {
            throw new Exception(format("call wasm function generate_float failed. %s", fromStringz(wasm_runtime_get_exception(module_inst))));
        }

        float ret_val = *cast(float*)argv;
        writefln("Native finished calling wasm function generate_float(), returned a float value: %s", ret_val);

        // Next we will pass a buffer to the WASM function
        uint[4] argv2;

        // must allocate buffer from wasm instance memory space (never use pointer from host runtime)
        wasm_buffer = wasm_runtime_module_malloc(module_inst, 100, cast(void**)&native_buffer);

        *cast(float*)argv2 = ret_val;   // the first argument
        argv2[1] = wasm_buffer;     // the second argument is the wasm buffer address
        argv2[2] = 100;             //  the third argument is the wasm buffer size
        argv2[3] = 3;               //  the last argument is the digits after decimal point for converting float to string
        auto func2 = cast(void* function())wasm_runtime_lookup_function(module_inst, "float_to_string".ptr, null);

        if(!(func2)){
            throw new Exception("The wasm function float_to_string wasm function is not found.");
        }

        if (wasm_runtime_call_wasm(exec_env, func2, 4, argv2.ptr) ) {
            writefln("Native finished calling wasm function: float_to_string, returned a formatted string: %s", native_buffer);
        }
        else {
            throw new Exception(format("call wasm function float_to_string failed. error: %s", fromStringz(wasm_runtime_get_exception(module_inst))));
        }

        auto func3 = cast(void* function())wasm_runtime_lookup_function(
            module_inst,
            "calculate".ptr,
            null);

        if (!func3) {
            throw new Exception("The wasm function calculate is not found.");
        }

        uint[] argv3 = [3];
        if (wasm_runtime_call_wasm(exec_env, func3, 1, argv3.ptr)) {
            uint result = *cast(uint*)argv3;
            writefln("Native finished calling wasm function: calculate, return: %d", result);
        } else {
            throw new Exception(format("call wasm function calculate failed. error: %s", fromStringz(wasm_runtime_get_exception(module_inst))));
        }

    } catch(Exception e) {
        exit_result=-1;
        writeln(e.msg);
    }
    return exit_result;
}
