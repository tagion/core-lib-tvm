module tagion.tvm.warm.WasmLoader;

import std.bitmanip : binpeek = peek, binwrite = write;
import LEB128 = tagion.utils.LEB128;
import std.outbuffer;
// class WasmBuffer : OutBuffer {
//     pure nothrow {
//         void insert(T)(scope T x, const size_t index) @trusted if (isBasicType)
//             in {
//                 assert(index < offset);
//             }
//         do {
//             reserve(T.sizeof);
//             data[index+T.sizeof..offset+T.sizeof] = data[index..offset];
//             *cast(T*)&data[index] = x;
//             offset += T.sizeof;
//         }
//         void insert(scope const(ubyte[]) x, const size_t index) @safe
//             in {
//                 assert(index < offset);
//             }
//         do {
//             reserve(x.length);
//             data[index+x.length..offset+x.length] = data[index..offset];
//             data[index..index+x.length] = x;
//             offset += T.length;
//         }

//         void insert(scope const OutBuffer buf) @safe
//     {
//         insert(buf.toBytes());
//     }

//     }

// }
struct WASMFunctionInstance {
    union {
        struct {
            uint ip;     // Bincode instruction pointer
            ushort local_count;     /// local variable count, 0 for import function
        }

    }
    ushort param_count;     /// parameter count
    /+
    /* cell num of parameters */
    uint16 param_cell_num;
    /* cell num of return type */
    uint16 ret_cell_num;
    /* cell num of local variables, 0 for import function */
    uint16 local_cell_num;
    +/
    /* whether it is import function or WASM function */
    bool is_import_func;     /// whether it is import function or WASM function


    version(none) {
    version(WASM_ENABLE_FAST_INTERP) {
    /* cell num of consts */
    uint16 const_cell_num;
    }
    uint16 *local_offsets;
    /* parameter types */
    uint8 *param_types;
    /* local types, NULL for import function */
    uint8 *local_types;
    union U {
        WASMFunctionImport *func_import;
        WASMFunction *func;
    }
    U u;
    version(WASM_ENABLE_MULTI_MODULE) {
        WASMModuleInstance *import_module_inst;
        WASMFunctionInstance *import_func_inst;
    }
    }
}

@safe struct WasmModule {
    // import std.array : appender, RefAppender;
    // import std.bitmanip;
    alias Sections = WasmReader.Sections;
    alias ImportType = WasmReader.WasmSection.ImportType;
    alias ExportType = WasmReader.WasmSection.ExportType;
    alias FuncType = WasmReader.WasmSection.FuncType;
    immutable(ubyte[]) frame;
    immutable(ImportType*[]) sec_imports;
    immutable(ExportType*[]) sec_exports;
    immutable(FuncType*[]) sec_functions;
    immutable(FunctionInstance[]) funcs_table;
    struct IndirectCallTable {
        ubyte internal_func_offset;
        ImportType* external_func; // If this null the funcion is internal
    }
    immutable(IndirectCallTable[]) indirect_call_tabel; // Only created if the indicrect_call instruction is used
//    const(WasmReader) reader;
    const(Sections) sections;
    this(const(WasmReader) reader) {
//        this.reader = reader;
        static foreach(ref section, ref read_section; lockstep(sections, reader[].enumerate)) {
            section = reader_section;
        }
        // Create fast lookup tables for the some of the sections
        imports_sec = section[Section.IMPORT][]
            .map!((ref a) => &a)
            .array;
        sec_exports_sec = section[Section.EXPORT][]
            .map!((ref a) => &a)
            .array;
        funcs_sec = section[Section.FUNC][]
            .map!((ref a) => &a)
            .array;
        FunctionInstance[] _funcs_table;
        _funcs_table.length = _funcs_table.length;

//        funcs_table.length
        // import std.outbuffer;
//         scope bout = new OutBuffer(reader.serialize.length);

// //    }
//         scope bout = appender!(ubyte[]);
//         appender.reserve = reader.serialize.length;
//        scope LoadReport report;
        // const result = load(reader);
        // frame = result.frame;

        frame = load(_funcs_table);
        funcs_table = assumeUnique(_funcs_table);
    }


    // alias Function = Sections[Section.FUNCTION];
    // protected Function _function;
    // @trusted void function_sec(ref const(Function) _function)
    // {
    //     // Empty
    //     // The functions headers are printed in the code section
    //     this._function = cast(Function) _function;
    // }

    // alias Code = Sections[Section.CODE];
    // @trusted void code_sec(ref const(Code) _code)
    // {
    //     foreach (f, c; lockstep(_function[], _code[], StoppingPolicy.requireSameLength))
    //     {
    //         auto expr = c[];
    //         output.writefln("%s(func (type %d)", indent, f.idx);
    //         const local_indent = indent ~ spacer;
    //         if (!c.locals.empty)
    //         {
    //             output.writef("%s(local", local_indent);
    //             foreach (l; c.locals)
    //             {
    //                 foreach (i; 0 .. l.count)
    //                 {
    //                     output.writef(" %s", typesName(l.type));
    //                 }
    //             }
    //             output.writeln(")");
    //         }

    //         block(expr, local_indent);
    //         output.writefln("%s)", indent);
    //     }
    // }

    private immutable(ubyte[]) load(ref FunctionInstance[] _funcs_table) {
        bool indirect_call_used;
        scope OutBuffer[] bouts;

        void block(ref ExprRange expr, const uint current_offset) {
            scope const(uint)[] labels;
            scope const(uint)[] label_offsets;
            //auto sec_imports = sections[Sections.IMPORTS];
            IRType expand_block(const uint level, const uint frame_offset) {
                scope OutBuffer bout;
                uint global_offset() @safe nothrow pure {
                    return cast(uint)(bout.offset + frame_offset);
                }
                if (level < bouts.length) {
                    bout = bouts[level];
                    bout.clear;
                }
                else {
                    bouts~=bout = new OutBuffer;
                }
                while(!expr.empty) {
                    const elm = expr.front;
                    const instr = instrTable[elm.code];
                    expr.popFront;
                    with (IRType)
                    {
                        final switch (instr.irtype)
                        {
                        case CODE:
                            bout.write(elm.code.convert);
                            break;
                        case BLOCK:
                            labels~=global_offset;
                            const end_elm = expand_block(level + 1, global_offset);
                            if (elm.code is IR.IF) {
                                bout.write(ExtendedIR.BR_IF); // IF instruction
                                //bout.write(cast(uint)(labels.length)); // Labelidx number to else
                                const else_offset = global_offset+uint.sizeof + cast(uint)bouts[level+1].offset;
                                bout.write(else_offset);
                                labels~=global_offset; // Else label
                                assert(global_offset == else_offset);
                                if (end_elm.code is IR.ELSE)
                                {
                                    const endif_elm = expand_block(level + 1, global_offset);
                                    // Branch to endif
                                    bout.write(ExtendedIR.EXT_BR);
                                    const endif_offset = global_offset+uint.sizeof + cast(uint)bouts[level+1].offset;
                                    bout.write(endif_offset);
                                    wout.write(bouts[level+1]);
                                }
                            }
                            else if (elm.code is IR.LOOP) {
                                bout.write(ExtendedIR.BR);
                                bout.write(cast(uint)(label.length-1));
                            }
                            // else Simple End
                            break;
                        case BRANCH:
                            bout.write(elm.code.convert);
                            bout.write(elm.warg.get!uint);
                            break;
                        case BRANCH_TABLE:
                            bout.write(elm.code.convert);
                            bout.write(LEB128.encode(elm.args.length));
                            foreach (a; elm.wargs) {
                                bout.write(a.get!uint);
                            }
                            break;
                        case CALL:
                            const funcidx =  elm.warg.get!uint;
                            uint importidx;
                            auto import_match = sec_imports
                                .filter!((a) => {importidx++; return a.importdesc.desc is IndexType.FUNC;})
                                .filter!((a) => a.importdesc.get!FUNC.funcidx is funcidx)
                                .doFront;
                            if (!import_match) {
                                // Internal function
                                bout.write(elm.code.convert);
                                bout.write(elm.warg.get!uint);
                            }
                            else {
                                bout.write(ExternalIR.EXTERNAL_CALL);
                                // The funcidx is now convert in to index of the import tabel
                                bout.write(LEB128.encode(importidx));
                            }
                            break;
                        case CALL_INDIRECT:
                            indirect_call_used = true;
                            bout.write(elm.code.convert);
                            break;
                        case LOCAL:
                            bout.write(elm.code.convert);
                            const data=elm.data[IR.sizeof..$];
                            bout.write(data[0..LEB128.calc_size!uint(data)]);
                            break;
                        case GLOBAL:
                            bout.write(elm.code.convert);
                            const data=elm.data[IR.sizeof..$];
                            bout.write(data[0..LEB128.calc_size!uint(data)]);
                            break;
                        case MEMORY:
                            bout.write(elm.code.convert);
                            foreach (a; elm.wargs) {
                                bout.write(LEB128.encode(a.get!uint));
                            }
                            break;
                        case MEMOP:
                            bout.write(elm.code.convert);
                            break;
                        case CONST:
                            bout.write(elm.code.convert);
                            with (Types)
                            {
                                switch (elm.warg.type)
                                {
                                case I32:
                                    bout.write(LEB128.encode(elm.warg.get!int));
                                    break;
                                case I64:
                                    bout.write(LEB128.encode(elm.warg.get!long));
                                    break;
                                case F32:
                                    bout.write(elm.warg.get!float);
                                    break;
                                case F64:
                                    bout.write(elm.warg.get!double);
                                    break;
                                default:
                                    assert(0);
                                }
                            }
                            break;
                        case END:
                            return elm;
                        }
                    }

                }

            }
        }
        expand_block(0, current_offset);
        // Insert branch jump pointes of the labels
        auto frame = bout.toBytes;
        foreach(branch_offset; label_offsets) {
            const labelidx = frame.binpeek!uint(branch_offset);
            frame.binwrite(labels[labelidx], branch_offset);
        }


        scope func_indices = new uint[funcs_sec.length];
    // const x = funcs_sec.length;
    // const y = func_indices.length;
//    func_indices.length = funcs_sec.length;
//    OutBuffer[] bouts;
    scope frame_buf = new OutBuffer;
//    bouts ~= frame_buf = new OutBuffer;
    //bouts[0] = frame_buf;
    bouts~=frame_buf;
    frame_buf.reverse = reader.serialize.length;
    foreach (ref func, sec_func, c; lockstep(
            _funcs_table[0..sec_funcs.length],
            sec_funcs,
            sections[Sections.CODE][], StoppingPolicy.requireSameLength).enumerate)
    {
        scope const func_type = sections[Sections.TYPE][sec_func.idx]; // typeidx
        func.local_count = c.locals[].walkLength;
        func.ip = cast(uint)bout.offset;
        // c.locals[].walkLength;
        // func_indices[funcidx] = cast(uint)bout.offset;
        block(func_type.expr, bouts);
    }
    // scope frame = bout.toBytes;

    // foreach(func_offset; func_indices) {
    //     const funcidx = frame.binpeek!uint(branch_offset);
    //     frame.binwrite(func_indices[funcidx], branch_offset);
    // }

    return frame.idup;
}

}
