module tagion.tvm.TVMLoader;

import tagion.wasm.WasmReader : WasmReader;

import tagion.tvm.TVMBasic : FunctionInstance;
import tagion.wasm.WasmException;
import tagion.basic.Basic : doFront;
import std.bitmanip : binpeek = peek, binwrite = write;
import std.range : lockstep, enumerate, StoppingPolicy;
import std.exception : assumeUnique;
import std.traits : EnumMembers, isBasicType;
import std.algorithm.iteration : map, filter;
import std.range.primitives : walkLength;
import std.array : array;
import std.format;

import LEB128 = tagion.utils.LEB128;
import std.outbuffer;

@safe class TVMBuffer : OutBuffer {
    import tagion.tvm.TVMExtOpcode : InternalIR;
    import tagion.wasm.WasmBase : WasmArg, Types;

    pure nothrow {
        final TVMBuffer opCall(T)(T x) if (isBasicType!T) {
            static if (T.sizeof is byte.sizeof) {
                super.write(cast(byte) x);
            }
            else static if (T.sizeof is short.sizeof) {
                super.write(cast(short) x);
            }
            else static if (T.sizeof is int.sizeof) {
                super.write(cast(int) x);
            }
            else static if (T.sizeof is long.sizeof) {
                super.write(cast(long) x);
            }
            else {
                static assert(0, format!"Type %s is not supported"(T.stringof));
            }
            return this;
        }

        final TVMBuffer opCall(T)(T x) if (!isBasicType!T) {
            super.write(x);
            return this;
        }
    }
    final TVMBuffer opCall(const WasmArg x) pure {
        with (Types) {
            switch (x.type) {
            case I32:
                super.write(x.get!int);
                break;
            case I64:
                super.write(x.get!long);
                break;
            case F32:
                super.write(x.get!float);
                break;
            case F64:
                super.write(x.get!double);
                break;
            default:
                throw new WasmException(format!"%s not supported"(x.type));
            }
        }
        return this;
    }

    final void opCall(Args...)(Args args) pure if (Args.length > 1) {
        foreach (a; args) {
            this.opCall(a);
        }
    }

    //    override
    //    alias reserve = super.reserve;
    version (none) pure nothrow {
        void insert(T)(scope T x, const size_t index) @trusted if (isBasicType)
        in {
            assert(index < offset);
        }
        do {
            reserve(T.sizeof);
            data[index + T.sizeof .. offset + T.sizeof] = data[index .. offset];
            *cast(T*)&data[index] = x;
            offset += T.sizeof;
        }

        void insert(scope const(ubyte[]) x, const size_t index) @safe
        in {
            assert(index < offset);
        }
        do {
            reserve(x.length);
            data[index + x.length .. offset + x.length] = data[index .. offset];
            data[index .. index + x.length] = x;
            offset += T.length;
        }

        void insert(scope const OutBuffer buf) @safe {
            insert(buf.toBytes());
        }

    }

}

@safe struct TVMModules {
    struct Module {
        WasmReader reader;
        ModuleInstance instance;
    }

    private {
        Module*[string] modules;
    }

    bool add(string mod_name, immutable(ubyte[]) wasm) pure nothrow {
        if (mod_name !in modules) {
            auto reader = WasmReader(wasm);
            auto mod = Module(reader);
//        modules.require(mod_name, Module(reader));
            modules[mod_name] = &mod;
            return false;
        }
        return true;
    }

    // @nogc const(WasmReader[string]) modules() const pure nothrow {
    //     return readers;
    // }

    void declare(F)(string symbol, F func) pure nothrow if (isFunctionPointer!F) {

    }

    void declare(alias func)() nothrow if (isCallable!func) {
        declare(func.mangleof, &func);

    }

    RetT call(RetT, Args...)() {
    }

    void build() pure {
    }

    Function lookup(alias F)(string mod_name, string func_name) if (isCallable!F) {
        auto mod = Modules[mod_name];
        alias Params=ParameterTypeTuple!F;
        alias Returns=ReturnType!F;
        string generate_func() {
            static foreach(i, P; Params) {

            }
        }

    }

    Function lookup(alias Func)(string mod_name) if (isCallable!Func) {
        return lookup!Func(mod_name, Func.mangleof);
    }


    @safe struct ModuleInstance {
        import tagion.wasm.WasmReader;
        import tagion.wasm.WasmBase : Section, ExprRange, IRType, IR,
            instrTable, IndexType, Types;
        import tagion.tvm.TVMExtOpcode : InternalIR, convert;

        // import std.array : appender, RefAppender;
        // import std.bitmanip;
        alias Sections = WasmReader.Sections;
        alias WasmSection = WasmReader.WasmRange.WasmSection;
        alias ImportType = WasmSection.ImportType;
        alias ExportType = WasmSection.ExportType;
        alias FuncType = WasmSection.FuncType;
        immutable(ubyte[]) frame;
        const(string) name;

        // immutable(ImportType[]) imports_sec;
        // immutable(ExportType[]) exports_sec;
        //    immutable(FuncType[]) funcs_sec;
        immutable(FunctionInstance[]) funcs_table;

        /+
    struct IndirectCallTable {
        ubyte internal_func_offset;
        ImportType* external_func; // If this null the funcion is internal
    }

    immutable(IndirectCallTable[]) indirect_call_tabel; // Only created if the indicrect_call instruction is used
    +/
        //    const(WasmReader) reader;
        const(Sections) sections;
        this(const(WasmReader) reader, string mod_name) {
            this.name = name;
            //this.reader = reader;
            // pragma(msg, EnumMembers!Section[]);
            // pragma(msg, Sections);
            (() @trusted {
                foreach (sec, read_section; lockstep([EnumMembers!Section], reader[])) {
                SectionSwitch:
                    final switch (sec) {
                        static foreach (E; EnumMembers!Section) {
                    case E:
                            sections[E] = read_section.sec!E;
                            break SectionSwitch;
                        }
                    }
                }
            })();
            FunctionInstance[] _funcs_table;
            _funcs_table.length = _funcs_table.length;

            frame = load(reader, _funcs_table);

            funcs_table = (() @trusted { return assumeUnique(_funcs_table); })();
        }

        private immutable(ubyte[]) load(const(WasmReader) reader, ref FunctionInstance[] _funcs_table) {
            bool indirect_call_used;
            TVMBuffer[] bouts;

            void block(ExprRange expr, const uint current_offset) @safe {
                scope const(uint)[] labels;
                scope const(uint)[] label_offsets;
                //auto sec_imports = sections[Sections.IMPORTS];
                const(ExprRange.IRElement) expand_block(const uint level, const uint frame_offset) @safe {
                    TVMBuffer bout;
                    uint global_offset() @safe nothrow pure {
                        return cast(uint)(bout.offset + frame_offset);
                    }

                    if (level < bouts.length) {
                        bout = bouts[level];
                        bout.clear;
                    }
                    else {
                        bouts ~= bout = new TVMBuffer;
                    }
                    while (!expr.empty) {
                        const elm = expr.front;
                        const instr = instrTable[elm.code];
                        expr.popFront;
                        with (IRType) {
                            final switch (instr.irtype) {
                            case CODE:
                                bout(elm.code.convert);
                                break;
                            case BLOCK:
                                labels ~= global_offset;
                                const end_elm = expand_block(level + 1, global_offset);
                                if (elm.code is IR.IF) {
                                    bout(InternalIR.BR_IF); // IF instruction

                                    //bout.write(cast(uint)(labels.length)); // Labelidx number to else
                                    const else_offset = global_offset + uint.sizeof + cast(
                                            uint) bouts[level + 1].offset;
                                    bout.write(else_offset);
                                    labels ~= global_offset; // Else label
                                    assert(global_offset == else_offset);
                                    pragma(msg, "end_elm.code ", typeof(end_elm));
                                    if (end_elm.code is IR.ELSE) {
                                        const endif_elm = expand_block(level + 1, global_offset);
                                        // Branch to endif
                                        bout(InternalIR.EXTRA_BR);
                                        const endif_offset = global_offset + uint.sizeof + cast(
                                                uint) bouts[level + 1].offset;
                                        bout(endif_offset);
                                        bout(bouts[level + 1]);
                                    }
                                }
                                else if (elm.code is IR.LOOP) {
                                    bout(InternalIR.BR, cast(uint)(labels.length - 1));
                                }
                                // else Simple End
                                break;
                            case PREFIX:
                                break;
                            case BRANCH:
                                bout(elm.code.convert, elm.warg.get!uint);
                                //bout(elm.warg.get!uint);
                                break;
                            case BRANCH_TABLE:
                                bout(elm.code.convert, LEB128.encode(elm.wargs.length));
                                //bout.write(LEB128.encode(elm.wargs.length));
                                foreach (a; elm.wargs) {
                                    bout.write(a.get!uint);
                                }
                                break;
                            case CALL:
                                const funcidx = elm.warg.get!uint;
                                uint importidx;
                                auto import_match = sections[Section.IMPORT][].filter!((a) => {
                                    importidx++;
                                    return a.importdesc.desc is IndexType.FUNC;
                                })
                                    .filter!((a) => a.importdesc.get!(IndexType.FUNC)
                                            .funcidx is funcidx)
                                    .doFront;
                                pragma(msg, typeof(import_match));
                                if (import_match !is import_match.init) {
                                    // Internal function
                                    bout(elm.code.convert, elm.warg.get!uint);
                                    //bout.write(elm.warg.get!uint);
                                }
                                else {
                                    bout(InternalIR.EXTERNAL_CALL, LEB128.encode(importidx));
                                    // The funcidx is now convert in to index of the import tabel
                                    //bout.write(LEB128.encode(importidx));
                                }
                                break;
                            case CALL_INDIRECT:
                                indirect_call_used = true;
                                bout(elm.code.convert);
                                break;
                            case LOCAL:
                            case GLOBAL:
                                bout(elm.code.convert, elm.warg);
                                //bout.write(elm.warg);
                                break;
                            case MEMORY:
                                bout(elm.code.convert);
                                foreach (a; elm.wargs) {
                                    bout(LEB128.encode(a.get!uint));
                                }
                                break;
                            case MEMOP:
                                bout(elm.code.convert);
                                break;
                            case CONST:
                                bout(elm.code.convert);
                                with (Types) {
                                    switch (elm.warg.type) {
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
                    return ExprRange.IRElement.unreachable;
                }

                expand_block(0, current_offset);
                // Insert branch jump pointes of the labels
                auto frame = bouts[0].toBytes;
                foreach (branch_offset; label_offsets) {
                    const labelidx = frame.binpeek!uint(branch_offset);
                    frame.binwrite(labels[labelidx], branch_offset);
                }
            }

            //scope func_indices = new uint[sections[Section.FUNCTION][].walkLength];
            // const x = funcs_sec.length;
            // const y = func_indices.length;
            //    func_indices.length = funcs_sec.length;
            //    OutBuffer[] bouts;
            auto frame_buf = new TVMBuffer;
            //    bouts ~= frame_buf = new OutBuffer;
            //bouts[0] = frame_buf;
            bouts ~= frame_buf;
            frame_buf.reserve = reader.serialize.length;
            (() @trusted {
                foreach (ref func, sec_func, c; lockstep(_funcs_table, sections[Section.FUNCTION][],
                    //sec_funcs,
                    sections[Section.CODE][], StoppingPolicy.requireSameLength)) {
                    pragma(msg, typeof(sections[Section.TYPE][]));
                    scope const func_type = sections[Section.TYPE][][sec_func.idx]; // typeidx
                    pragma(msg, typeof(c.locals));
                    func.local_size = cast(ushort) c.locals.walkLength;
                    func.ip = cast(uint) frame_buf.offset;
                    // c.locals[].walkLength;
                    // func_indices[funcidx] = cast(uint)bout.offset;
                    pragma(msg, typeof(c[]));
                    block(c[], func.ip);
                }
            })();
            // scope frame = bout.toBytes;

            // foreach(func_offset; func_indices) {
            //     const funcidx = frame.binpeek!uint(branch_offset);
            //     frame.binwrite(func_indices[funcidx], branch_offset);
            // }

            return frame.idup;
        }

    }

}
