module tagion.tvm.TVMLoader;

import std.stdio;

import tagion.wasm.WasmReader : WasmReader;

import tagion.tvm.TVMBasic : FunctionInstance;
import tagion.wasm.WasmException;
import tagion.basic.Basic : doFront;
import std.bitmanip : binpeek = peek, binwrite = write;
import std.range : lockstep, enumerate, StoppingPolicy;
import std.exception : assumeUnique;
import std.traits : EnumMembers, isBasicType, isCallable, ParameterTypeTuple, ReturnType, FieldNameTuple, isFunctionPointer, ParameterIdentifierTuple;
import std.algorithm.iteration : map, filter;
import std.range.primitives : walkLength;
import std.array : array, join;
import std.format;
//import std.typecons.Tuple : fieldNames;

import LEB128 = tagion.utils.LEB128;
import std.outbuffer;

struct Function {
}
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
    import tagion.wasm.WasmBase : Section, IndexType, toWasmType, Types;
    alias Sections = WasmReader.Sections;
    alias WasmSection = WasmReader.WasmRange.WasmSection;
    alias ImportType = WasmSection.ImportType;
    alias ExportType = WasmSection.ExportType;
    alias Export = WasmSection.Export;
    alias FuncType = WasmSection.FuncType;

    private {
        Module[string] modules;
    }

    Module opCall(string mod_name, immutable(ubyte[]) wasm) pure nothrow {
        Module result;
        if (mod_name !in modules) {
            auto reader = WasmReader(wasm);
            modules[mod_name] = result = new Module(mod_name, reader);
        }
        return result;
    }

    void link() pure {

    }

    void declare(F)(string symbol, F func) pure nothrow if (isFunctionPointer!F) {

    }

    void declare(alias func)() nothrow if (isCallable!func) {
        declare(func.mangleof, &func);
    }

    RetT call(RetT, Args...)() {
    }

    @safe class Module {
        const(WasmReader) reader;
        const(string) mod_name;
        protected Instance _instance;

        const(Instance) instance() @nogc pure const nothrow {
            return _instance;
        }

        protected this(string mod_name, const(WasmReader) reader) pure nothrow {
            this.reader = reader;
            this.mod_name = mod_name;
        }

        template lookup(alias F) if (isCallable!F) {
            import tagion.tvm.TVMContext;

            auto lookup(string func_name) {
//                Module mod;
                alias Params=ParameterTypeTuple!F;
                enum ParamNames = [ParameterIdentifierTuple!F];
                alias Returns=ReturnType!F;
                enum param_prefix ="param_";
                enum context_name ="ctx";
                int func_idx;
                string generate_func() {
                    string[] func_body;
                    string[] params;
                    params ~= format!"ref TVMContext %s"(context_name);
                    static foreach(i, P; Params) {{
                        static if (ParamNames[i].length) {
                            enum param_name = ParamNames[i];
                        }
                        else {
                            enum param_name = format!`%s%d`(param_prefix, i);
                        }
                        params ~= format!`%s %s`(P.stringof, param_name);
                        func_body ~= format!q{
                            //static if (isWasmParam!%1$s) {
                            ctx.push(%2$s);
                            //}
                        }(P.stringof, param_name);
                        }}
                    const result = format!q{
                        %1$s _inner_func(%2$s) {
                            import std.stdio;
                            %3$s
                            writeln("func_idx", func_idx);
                            return ctx.pop!%1$s;
                        }
                    }(
                        Returns.stringof,
                        params.join(", "),
                        func_body.join("\n"),
                        );
                    return result;
                }
                enum code = generate_func;
                pragma(msg, "CODE=", code);
                mixin(code);

                auto export_sec = reader.get!(Section.EXPORT);


//                version(none)
                void check_func_type() {
                    alias TVMFunction = typeof(_inner_func);
                    alias TVMParams = ParameterTypeTuple!TVMFunction;
                    alias TVMReturns = ReturnType!TVMFunction;
                    //auto m = mod;
//                    auto r = mod.reader;
                    // auto export_sec = mod.reader.get!(Section.EXPORT);
//                    version(none)
                    writefln("export_sec.length=%d", export_sec.length);
                    writefln("export_sec.data=%s", export_sec.data);
                    auto e = export_sec[];
                    writefln("e.empty=%s", e.empty);
                    // writefln("e.data=%s", e.data);
                    writefln("e.front=%s", e.front);

                    writefln("EXPORT SEC start");
                    while(!e.empty) {
                        writefln("e.front=%s", e.front);
                        e.popFront;
                    }
                    foreach(export_type; export_sec[]) {
                        writefln("export func %s export_type.name = %s", export_type, export_type.name);
                        if (func_name == export_type.name) {
                            writefln("Found %s", func_name);
                            check(export_type.desc is IndexType.FUNC,
                                format("The export %s is in module %s not a function type but a %s type", func_name, mod_name, export_type.desc));
                            const type_sec = reader.get!(Section.TYPE);
                            pragma(msg, typeof( type_sec));
                            pragma(msg, typeof(export_type));
                            const func_type = type_sec[export_type.idx];
                            static if (is(TMVReturns == void)) {
                                check(func_type.results.length is 0,
                                    format("Function %s in module %s does not specify a return type but expects %s", func_name, mod_name, toDType!TVMReturns, func_type.results[0]));
                            }
                            else {
                                enum WasmReturnType = toWasmType!TVMReturns;

                                check(func_type.results[0] is WasmReturnType,
                                    format("Function %s in module %s has the wrong return type, define was %s but expected type %s", func_name, mod_name, func_type.results[0], WasmReturnType));
                            }
                            check(func_type.params.length != TVMParams.length,
                                format!"Number of arguments in the TVM_%s function in module %s does not match got %d expected %d"(func_name, mod_name, func_type.params.length, TVMParams.length));
                            static assert(is(TVMContext == TVMParams[0]), format!"The first parameter of a wasm interface function must be %s"(TVMContext.stringof));

                            static foreach(i, P; TVMParams[1..$]) {{
                                    enum WasmType = toWasmType!P;
                                    static assert(WasmType !is Types.EMPTY,
                                        format!"Parameter number %d Type %s is not a valid Wasm type"(i, P.stringof));
                                    check(i < func_type.params.length, format!"Too few parameters expected %d but caller tries to access parameter number %d"(func_type.params.length, i));

                                    check(func_type.params[i] is WasmType,
                                        format!"Parameter number %d in func TVM_%s doest not match in module %s got %s expected %s"
                                        (i, func_name, mod_name, func_type.params[i], WasmType));
                            }}
                            return;
                        }

                    }

                    check(0, format("Function %s is not found in module %s",
                            func_name, mod_name));
                }


                check_func_type;
                return &_inner_func;
            }



            auto lookup() {
                pragma(msg, "func_name ", F.mangleof);
                return lookup!F(F.mangleof);
            }
        }
        @safe struct Instance {
            import tagion.wasm.WasmReader;
            import tagion.wasm.WasmBase : Section, ExprRange, IRType, IR,
            instrTable, IndexType, Types;
            import tagion.tvm.TVMExtOpcode : InternalIR, convert;
            immutable(ubyte[]) frame;
            immutable(FunctionInstance[]) funcs_table;

            const(Sections) sections;
            const(string) mod_name;
            this(string mod_name, const(WasmReader) reader) {
                this.mod_name = mod_name;
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
                                    }
                                    else {
                                        bout(InternalIR.EXTERNAL_CALL, LEB128.encode(importidx));
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
                    (() @trusted {
                        foreach (branch_offset; label_offsets) {
                            const labelidx = frame.binpeek!uint(branch_offset);
                            frame.binwrite(labels[labelidx], branch_offset);
                        }
                    })();
                }

                auto frame_buf = new TVMBuffer;
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
                return frame.idup;
            }
        }
    }
    unittest {
        static int simple_int(int x, int y);
        TVMModules mod;
//        mod.lookup!simple_int("env");
    }

    unittest {
        import tests.wasm_samples : simple_alu;

        // static int simple_int(int x, int y);
        TVMModules tvm_mod;
        auto mod=tvm_mod("env", simple_alu);

//        import mod_simple_alu = tests.simple_alu.simple_alu;

        const wasm_func_inc = mod.lookup!(func_inc);
        tvm_mod.link;
//        mod.lookup!simple_int("env");
    }
}

extern (C) int func_inc(int x);
