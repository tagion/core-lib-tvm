module src.main;

import tagion.tvm.c.wasm_export;
import tagion.tvm.c.lib_export;
//import tagion.vm.wamr.c.wasm_runtime_common;

import tagion.tvm.revision;

import std.getopt;
import std.format;
import std.array : join;
import std.stdio;
import std.path;
import std.file : fread=read;
import std.string : fromStringz;
// #include <stdio.h>
// #include <stdlib.h>
// #include <string.h>


// #include "bh_read_file.h"
// #include "platform_common.h"
// #include "wasm_export.h"

// string build_module_path(string module_name) {
//     auto path=buildPath("wasm-apps", module_name);
//     path.setExtension("wasm");
//     return path.toString;
// }

string wasm_path="wasm-apps";

extern(C)
bool module_reader_cb(const(char)* module_name, ubyte** p_buffer, uint* p_size) {
    const _module_name=fromStringz(module_name);
    auto path=buildPath(wasm_path, _module_name).setExtension("wasm");
    // writefln("Before %s", path);
    //path=path.setExtension("wasm");
    // writefln("After %s", path);
    //immutable wasm_file_path = build_module_path(module_name);
    bool ok;
    try {
        auto buffer=cast(ubyte[])fread(path);
        *p_buffer=buffer.ptr;
        *p_size=cast(uint)buffer.length;
        ok=true;
        writefln("- bh_read_file_to_buffer %s", path);

    }
    catch (Exception e) {
        writefln("- bh_read_file_to_buffer %s FAILED!!", path);
        ok=false;
    }
    return ok;
}

extern(C)
void module_destroyer_cb(ubyte* buffer, uint size) {
    printf("- release the read file buffer\n");
    // GC cleans this
    buffer=null;
    // if (!buffer) {
    //     return;
    // }

    // BH_FREE(buffer);
    // buffer = NULL;
}

int main(string[] args) {
    immutable program=args[0];

    bool ret = false;
    bool version_switch;
    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version",   "display the version",  &version_switch,
        "inputfile|f","Path of wasm path", &wasm_path,
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
    // wasm_module_t wasm_module;
    // wasm_module_inst_t module_inst;

    /* all malloc() only from the given buffer */
    init_args.mem_alloc_type = mem_alloc_type_t.Alloc_With_Pool;
    init_args.mem_alloc_option.pool.heap_buf = sandbox_memory_space.ptr;
    init_args.mem_alloc_option.pool.heap_size = sandbox_memory_space.length;

    writeln("- wasm_runtime_full_init");
    /* initialize runtime environment */
    if (!wasm_runtime_full_init(&init_args)) {
        writeln("Init runtime environment failed.");
        return -1;
    }

//#if WASM_ENABLE_MULTI_MODULE != 0
    writeln("- wasm_runtime_set_module_reader");
    /* set module reader and destroyer */

//    version(none)
    wasm_runtime_set_module_reader(&module_reader_cb, &module_destroyer_cb);
//#endif

    /* load WASM byte buffer from WASM bin file */
    scope(exit) {
        writeln("- wasm_runtime_destroy");
        wasm_runtime_destroy();
    }
    scope ubyte* _file_buf;
    scope uint _file_buf_size;

    if (!module_reader_cb("mC", &_file_buf, &_file_buf_size)) {
        writeln("- wasm module_reader_cb");
        return 1;
//        goto RELEASE_RUNTIME;
    }
    file_buf=_file_buf[0.._file_buf_size];

    /* load mC and let WAMR load mA and mB */
    writeln("- wasm_runtime_load");
    scope(exit) {
        module_destroyer_cb(_file_buf, _file_buf_size);
    }
    wasm_module_t wasm_module = wasm_runtime_load(_file_buf, _file_buf_size,
        error_buf.ptr, error_buf.length);

    if (wasm_module is null) {
        writefln("%s", error_buf);
        return 2;
    }

    /* instantiate the module */
    writeln("- wasm_runtime_instantiate");
    scope(exit) {
        writeln("- wasm_runtime_unload");
        wasm_runtime_unload(wasm_module);
    }

    wasm_module_inst_t module_inst=wasm_runtime_instantiate(wasm_module, stack_size, heap_size,
        error_buf.ptr, error_buf.length);


    if (module_inst is null) {
        writefln("%s", error_buf);
        return 3;
    }

    /* call some functions of mC */
    writeln("\n----------------------------------------");
    write(`call "C", it will return 0xc:i32, ===> `);
    wasm_application_execute_func(module_inst, "C", 0, &wasm_args[0]);
    write(`call "call_B", it will return 0xb:i32, ===> `);
    wasm_application_execute_func(module_inst, "call_B", 0, &wasm_args[0]);
    write(`call "call_A", it will return 0xa:i32, ===> `);
    wasm_application_execute_func(module_inst, "call_A", 0, &wasm_args[0]);

    /* call some functions of mB */
    write(`call "mB.B", it will return 0xb:i32, ===> `);
    wasm_application_execute_func(module_inst, "$mB$B", 0, &wasm_args[0]);
    write(`call "mB.call_A", it will return 0xa:i32, ===> `);
    wasm_application_execute_func(module_inst, "$mB$call_A", 0, &wasm_args[0]);

    /* call some functions of mA */
    write(`call "mA.A", it will return 0xa:i32, ===> `);
    wasm_application_execute_func(module_inst, "$mA$A", 0, &wasm_args[0]);
    writeln("----------------------------------------");

    writeln("- wasm_runtime_deinstantiate");
    wasm_runtime_deinstantiate(module_inst);
    return 0;
}
