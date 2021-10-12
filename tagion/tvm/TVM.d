module tagion.tvm.TVM;

import std.stdio;

import tagion.wasm.WasmReader : WasmReader;

import tagion.tvm.TVMBasic : FunctionInstance;
import tagion.tvm.TVMContext : TVMContext;
import tagion.wasm.WasmException;
import tagion.basic.Basic : doFront;
import std.bitmanip : binpeek = peek, binwrite = write;
import std.range : lockstep, enumerate, StoppingPolicy;
import std.exception : assumeUnique;
import std.traits : EnumMembers, isBasicType, isCallable, isIntegral, isFloatingPoint, ParameterTypeTuple, ReturnType, FieldNameTuple, isFunctionPointer, ParameterIdentifierTuple;
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
    import tagion.tvm.TVMContext : TVMError, TVMContext;
    import tagion.tvm.TVMBasic : WasmType;
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

    void link() {
        foreach(mod_name, mod; modules) {
            mod.init;
        }
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
        private Instance _instance;

        const(Instance) instance() @nogc pure const nothrow {
            return _instance;
        }

        protected this(string mod_name, const(WasmReader) reader) pure nothrow {
            this.reader = reader;
            this.mod_name = mod_name;
        }

        protected void init()
            in {
                assert(_instance is null);
            }
        do {
            _instance = new Instance;
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
                int funcidx;
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
                            _instance.bytecode_call(ctx, function_instance);
                            writeln("funcidx", funcidx);
                            return ctx.pop!%1$s;
                        }
                    }(
                        Returns.stringof,
                        params.join(", "),
                        func_body.join("\n"),
                        );
                    return result;
                }
                FunctionInstance function_instance;
                enum code = generate_func;
                //pragma(msg, "CODE=", code);
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
                            const func_sec = reader.get!(Section.FUNCTION);
                            funcidx = export_type.idx;
                            const typeidx = func_sec[funcidx].idx;
                            version(none)
                            function_instance = _instance.funcs_table[export_type.idx];
                            //const typeidx = func_index.idx;
                            //const code_sec = reader.get!(Section.CODE);

                            const type_sec = reader.get!(Section.TYPE);
                            pragma(msg, typeof( type_sec));
                            pragma(msg, typeof(export_type));
                            const func_type = type_sec[typeidx];
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


        @safe class Instance {
            import core.exception : RangeError;
            import tagion.wasm.WasmReader;
            import tagion.wasm.WasmBase : Section, ExprRange, IRType, IR,
            instrTable, IndexType, Types;
            import tagion.tvm.TVMExtOpcode : InternalIR, convert;
            immutable(ubyte[]) all_frames;
            immutable(FunctionInstance[]) funcs_table;

            const(Sections) sections;
//            const(string) mod_name;
            this() {
                auto range = reader[];
                static foreach(E; EnumMembers!Section) {
                    if (!range.empty && (range.front.section is E)) {
                        sections[E] = range.front.sec!E;
                        range.popFront;
                    }

                }
                FunctionInstance[] _funcs_table;


                all_frames = load(reader, _funcs_table);

                funcs_table = (() @trusted { return assumeUnique(_funcs_table); })();
            }

            private void bytecode_call(ref TVMContext ctx, ref const FunctionInstance wasm_func) {
                bool unwined;
                scope (exit) {
                    if (unwined) {
                        // Do some unwineding
                    }
                }
                void bytecode_func(ref const FunctionInstance wasm_func) @trusted {
                    auto locals = ctx.get_locals(wasm_func);
                    scope(exit) {
                        ctx.pop_return(wasm_func);
                    }
                    //locals=ctx.stack
                    // scope locals=new WasmType[wasm_func.local_size];
                    // ctx.pop(locals, wasm_func.param_count);
                    //locals = ctx.get_locals
                    immutable frame=wasm_func.frame;
                    size_t ip; // = wasm_func.ip;
                    try {
                        scope (exit) {
                            if (unwined) {
                                // Do some unwineding
                            }
                        }
                        //auto locals = ctx.locals[local_offset .. local_offset + local_size];
                        writefln("frame.length = %d", frame.length);
                    FETCH_LOOP: while (ip < frame.length) {
                            const opcode = frame[ip++];
                            writefln(" %d %s", ip-1, opcode);
                            @safe void read_leb(T)(ref T x) nothrow if (isIntegral!T) {
                                const result = LEB128.decode!T(frame[ip .. $]);
                                ip += cast(uint) result.size;
                                x = result.value;
                            }

                            void op_const(T)() @trusted nothrow {
                                static if (isIntegral!T) {
                                    T x;
                                    read_leb(x);
                                    ctx.push(x);
                                }
                                else static if (isFloatingPoint!T) {
                                    T x = *cast(T*)&frame[ip];
                                    ip += T.sizeof;
                                    ctx.push(x);
                                }
                                else {
                                    static assert(0, format!"%s is not supported"(T.stringof));
                                }
                            }

                            @safe bool load(DST, SRC)() nothrow {
                                uint offset, alignment;
                                read_leb!uint(alignment);
                                assert(alignment <= 3, "Max value for aligment is 3");
                                read_leb!uint(offset);
                                return ctx.op_load!(DST, SRC)(offset << alignment, ip);
                            }

                            @safe bool store(DST, SRC)() nothrow {
                                uint offset, alignment;
                                read_leb!uint(alignment);
                                assert(alignment <= 3, "Max value for aligment is 3");
                                read_leb!uint(offset);
                                return ctx.op_store!(DST, SRC)(offset << alignment, ip);
                            }

                            version (none) @safe void op_trunc(DST, SRC, bool saturating)() nothrow
                                if (isNumeric!DST && isNumeric!SRC) {
                                    const src_value = ctx.pop!SRC;
                                    static if (isFloatingPoint!SRC && !saturating) {
                                        if (isnan(src_value)) {
                                            wasm_set_exception(wasm_module, "invalid conversion to integer");
                                            return true;
                                        }
                                        else if (src_value <= src.value || src_value >= src_max) {
                                            wasm_set_exception(wasm_module, "integer overflow");
                                            return true;
                                        }
                                    }
                                    const res = trunc!DST(x);
                                    ctx.push(res);
                                    return false;

                                }

                            import std.math;

                            with (InternalIR) {
                                final switch (opcode) {
                                case UNREACHABLE:
                                    ctx.set_exception(ip, "unreachable");
                                    goto case ERROR;
                                case BR_IF:
                                    const cond = ctx.pop!int;
                                    const branch_else = frame[ip .. $].binpeek!uint(&ip);
                                    //ip+=uint.sizeof;
                                    /* condition of the if branch is false, else condition is met */
                                    if (cond == 0) {
                                        ip = branch_else;
                                    }
                                    continue;
                                case BR_TABLE:
                                    uint lN;
                                    read_leb(lN);
                                    const L = (cast(uint*)&frame[ip])[0 .. lN + 1];
                                    const didx = ctx.pop!uint;
                                    if (didx < lN) {
                                        ip = L[didx];
                                    }
                                    else {
                                        ip = L[$ - 1];
                                    }
                                    continue;
                                case RETURN:
                                    return;
                                case CALL:
                                    uint fidx;
                                    read_leb(fidx);
                                    const func = funcs_table[fidx];
                                    bytecode_call(ctx, func);
                                    continue;
                                case EXTERNAL_CALL:
                                    uint fidx;
                                    read_leb(fidx);
                                    const func = funcs_table[fidx];
                                    //if (func.isLocalFunc) {
                                    assert(0, "Imported function is not supported yet");
                                    //bytecode_func(func.ip, local_offset+local_size, func.local_size);
                                    continue;
                                case CALL_INDIRECT:
                                    const fidx = ctx.pop!uint;
                                    const func = funcs_table[fidx];
                                    if (func.isLocalFunc) {
                                        bytecode_func(func);
                                    }
                                    else {
                                        assert(0, "Imported function is not supported yet");
                                    }
                                    continue;
                                    /* parametric instructions */
                                case DROP:
                                    ctx.op_drop;
                                    continue;
                                case SELECT:
                                    ctx.op_select;
                                    continue;
                                case LOCAL_GET:
                                    uint local_index;
                                    read_leb(local_index);
                                    ctx.push(locals[local_index]);
                                    continue;
                                case LOCAL_SET:
                                    uint local_index;
                                    read_leb(local_index);
                                    locals[local_index] = ctx.pop!long;
                                    continue;
                                case LOCAL_TEE:
                                    uint local_index;
                                    read_leb(local_index);
                                    locals[local_index] = ctx.peek!long;
                                    continue;
                                case GLOBAL_GET:
                                    uint global_index;
                                    read_leb(global_index);
                                    ctx.push(ctx.globals[global_index]);
                                    continue;
                                case GLOBAL_SET:
                                    uint global_index;
                                    read_leb(global_index);
                                    ctx.globals[global_index] = ctx.pop!long;
                                    continue;
                                    /* memory load instructions */
                                case I32_LOAD:
                                case F32_LOAD:
                                    if (load!(int, int))
                                        goto case ERROR;
                                    continue;
                                case I64_LOAD:
                                case F64_LOAD:
                                    if (load!(long, long))
                                        goto case ERROR;
                                    continue;
                                case I32_LOAD8_S:
                                    if (load!(int, byte))
                                        goto case ERROR;
                                    continue;
                                case I32_LOAD8_U:
                                    if (load!(int, ubyte))
                                        goto case ERROR;
                                    continue;
                                case I32_LOAD16_S:
                                    if (load!(int, short))
                                        goto case ERROR;
                                    continue;
                                case I32_LOAD16_U:
                                    if (load!(int, ushort))
                                        goto case ERROR;
                                    continue;
                                case I64_LOAD8_S:
                                    if (load!(long, byte))
                                        goto case ERROR;
                                    continue;
                                case I64_LOAD8_U:
                                    if (load!(long, ubyte))
                                        goto case ERROR;
                                    continue;
                                case I64_LOAD16_S:
                                    if (load!(long, short))
                                        goto case ERROR;
                                    continue;
                                case I64_LOAD16_U:
                                    if (load!(long, ushort))
                                        goto case ERROR;
                                    continue;
                                case I64_LOAD32_S:
                                    if (load!(long, int))
                                        goto case ERROR;
                                    continue;
                                case I64_LOAD32_U:
                                    if (load!(long, uint))
                                        goto case ERROR;
                                    continue;
                                    /* memory store instructions */
                                case I32_STORE:
                                case F32_STORE:
                                    store!(int, int);
                                    continue;
                                case I64_STORE:
                                case F64_STORE:
                                    store!(long, long);
                                    continue;
                                case I32_STORE8:
                                    store!(byte, int);
                                    continue;

                                case I32_STORE16:
                                    store!(short, int);
                                    continue;
                                case I64_STORE8:
                                    store!(byte, long);
                                    continue;

                                case I64_STORE16:
                                    store!(short, long);
                                    continue;
                                case I64_STORE32:
                                    store!(int, long);
                                    continue;
                                    /* memory size and memory grow instructions */
                                case MEMORY_SIZE:
                                    ctx.op_memory_size;
                                    continue;

                                case MEMORY_GROW:
                                    ctx.op_memory_grow;
                                    continue;
                                    continue;
                                case I32_CONST:
                                    op_const!int;
                                    continue;
                                case I64_CONST:
                                    op_const!long;
                                    continue;
                                case F32_CONST:
                                    op_const!float;
                                    continue;
                                case F64_CONST:
                                    op_const!double;
                                    continue;
                                    /* comparison instructions of i32 */
                                case I32_EQZ:
                                    ctx.op_eqz!int;
                                    continue;
                                case I32_EQ:
                                    ctx.op_cmp!(int, "==");
                                    continue;
                                case I32_NE:
                                    ctx.op_cmp!(int, "!=");
                                    continue;
                                case I32_LT_S:
                                    ctx.op_cmp!(int, "<");
                                    continue;
                                case I32_LT_U:
                                    ctx.op_cmp!(uint, "<");
                                    continue;
                                case I32_GT_S:
                                    ctx.op_cmp!(int, ">");
                                    continue;
                                case I32_GT_U:
                                    ctx.op_cmp!(uint, ">");
                                    continue;
                                case I32_LE_S:
                                    ctx.op_cmp!(int, "<=");
                                    continue;
                                case I32_LE_U:
                                    ctx.op_cmp!(uint, "<=");
                                    continue;
                                case I32_GE_S:
                                    ctx.op_cmp!(int, ">=");
                                    continue;
                                case I32_GE_U:
                                    ctx.op_cmp!(uint, ">=");
                                    continue;
                                    /* comparison instructions of i64 */
                                case I64_EQZ:
                                    ctx.op_eqz!long;
                                    continue;
                                case I64_EQ:
                                    ctx.op_cmp!(ulong, "==");
                                    continue;
                                case I64_NE:
                                    ctx.op_cmp!(ulong, "!=");
                                    continue;
                                case I64_LT_S:
                                    ctx.op_cmp!(long, "<");
                                    continue;
                                case I64_LT_U:
                                    ctx.op_cmp!(ulong, "<");
                                    continue;
                                case I64_GT_S:
                                    ctx.op_cmp!(long, ">");
                                    continue;
                                case I64_GT_U:
                                    ctx.op_cmp!(ulong, ">");
                                    continue;
                                case I64_LE_S:
                                    ctx.op_cmp!(long, "<=");
                                    continue;
                                case I64_LE_U:
                                    ctx.op_cmp!(ulong, "<=");
                                    continue;
                                case I64_GE_S:
                                    ctx.op_cmp!(ulong, ">=");
                                    continue;
                                case I64_GE_U:
                                    ctx.op_cmp!(long, ">=");
                                    continue;
                                    /* comparison instructions of f32 */
                                case F32_EQ:
                                    ctx.op_cmp!(float, "==");
                                    continue;
                                case F32_NE:
                                    ctx.op_cmp!(float, "!=");
                                    continue;
                                case F32_LT:
                                    ctx.op_cmp!(float, "<");
                                    continue;
                                case F32_GT:
                                    ctx.op_cmp!(float, ">");
                                    continue;
                                case F32_LE:
                                    ctx.op_cmp!(float, "<=");
                                    continue;
                                case F32_GE:
                                    ctx.op_cmp!(float, ">=");
                                    continue;
                                    /* comparison instructions of f64 */
                                case F64_EQ:
                                    ctx.op_cmp!(double, "==");
                                    continue;
                                case F64_NE:
                                    ctx.op_cmp!(double, "!=");
                                    continue;
                                case F64_LT:
                                    ctx.op_cmp!(double, "<");
                                    continue;
                                case F64_GT:
                                    ctx.op_cmp!(double, ">");
                                    continue;
                                case F64_LE:
                                    ctx.op_cmp!(double, "<=");
                                    continue;
                                case F64_GE:
                                    ctx.op_cmp!(double, ">=");
                                    continue;
                                    /* numberic instructions of i32 */
                                case I32_CLZ:
                                    ctx.op_clz!int;
                                    continue;
                                case I32_CTZ:
                                    ctx.op_ctz!int;
                                    continue;
                                case I32_POPCNT:
                                    ctx.op_popcount!int;
                                    continue;
                                case I32_ADD:
                                    ctx.op_cat!(uint, "+");
                                    continue;
                                case I32_SUB:
                                    ctx.op_cat!(uint, "-");
                                    continue;
                                case I32_MUL:
                                    ctx.op_cat!(uint, "*");
                                    continue;
                                case I32_DIV_S:
                                    if (ctx.op_div!int(ip)) {
                                        goto case ERROR;
                                    }
                                    continue;
                                case I32_DIV_U:
                                    if (ctx.op_div!uint(ip)) {
                                        goto case ERROR;
                                    }
                                    continue;
                                case I32_REM_S:
                                    if (ctx.op_rem!int) {
                                        goto case ERROR;
                                    }
                                    continue;
                                case I32_REM_U:
                                    if (ctx.op_rem!uint) {
                                        goto case ERROR;
                                    }
                                    continue;
                                case I32_AND:
                                    ctx.op_cat!(uint, "&");
                                    continue;
                                case I32_OR:
                                    ctx.op_cat!(uint, "|");
                                    continue;
                                case I32_XOR:
                                    ctx.op_cat!(uint, "^");
                                    continue;
                                case I32_SHL:
                                    ctx.op_cat!(uint, "<<");
                                    continue;
                                case I32_SHR_S:
                                    ctx.op_cat!(int, ">>");
                                    continue;
                                case I32_SHR_U:
                                    ctx.op_cat!(uint, ">>");
                                    continue;
                                case I32_ROTL:
                                    ctx.op_rotl!int;
                                    continue;
                                case I32_ROTR:
                                    ctx.op_rotr!int;
                                    continue;
                                    /* numberic instructions of i64 */
                                case I64_CLZ:
                                    ctx.op_clz!int;
                                    continue;
                                case I64_CTZ:
                                    ctx.op_ctz!int;
                                    continue;
                                case I64_POPCNT:
                                    ctx.op_popcount!int;
                                    continue;
                                case I64_ADD:
                                    ctx.op_cat!(ulong, "+");
                                    continue;
                                case I64_SUB:
                                    ctx.op_cat!(ulong, "-");
                                    continue;
                                case I64_MUL:
                                    ctx.op_cat!(ulong, "*");
                                    continue;
                                case I64_DIV_S:
                                    if (ctx.op_div!long(ip)) {
                                        goto case ERROR;
                                    }
                                    continue;
                                case I64_DIV_U:
                                    if (ctx.op_div!ulong(ip)) {
                                        goto case ERROR;
                                    }
                                    continue;
                                case I64_REM_S:
                                    if (ctx.op_rem!long) {
                                        goto case ERROR;
                                    }
                                    continue;
                                case I64_REM_U:
                                    if (ctx.op_rem!ulong) {
                                        goto case ERROR;
                                    }
                                    continue;
                                case I64_AND:
                                    ctx.op_cat!(ulong, "&");
                                    continue;
                                case I64_OR:
                                    ctx.op_cat!(ulong, "|");
                                    continue;
                                case I64_XOR:
                                    ctx.op_cat!(ulong, "^");
                                    continue;
                                case I64_SHL:
                                    ctx.op_cat!(ulong, "<<");
                                    continue;
                                case I64_SHR_S:
                                    ctx.op_cat!(long, ">>");
                                    continue;
                                case I64_SHR_U:
                                    ctx.op_cat!(ulong, ">>");
                                    continue;
                                case I64_ROTL:
                                    ctx.op_rotl!long;
                                    continue;
                                case I64_ROTR:
                                    ctx.op_rotr!long;
                                    continue;
                                    /* numberic instructions of f32 */
                                case F32_ABS:
                                    const x = fabs(float(-1));
                                    ctx.op_math!(float, "fabs");
                                    continue;
                                case F32_NEG:
                                    ctx.op_unary!(float, "-");
                                    continue;
                                case F32_CEIL:
                                    ctx.op_math!(float, "ceil");
                                    continue;
                                case F32_FLOOR:
                                    ctx.op_math!(float, "floor");
                                    continue;
                                case F32_TRUNC:
                                    ctx.op_math!(float, "trunc");
                                    continue;
                                case F32_NEAREST:
                                    ctx.op_math!(float, "rint");
                                    continue;
                                case F32_SQRT:
                                    ctx.op_math!(float, "sqrt");
                                    continue;
                                case F32_ADD:
                                    ctx.op_cat!(float, "+");
                                    continue;
                                case F32_SUB:
                                    ctx.op_cat!(float, "-");
                                    continue;
                                case F32_MUL:
                                    ctx.op_cat!(float, "*");
                                    continue;
                                case F32_DIV:
                                    ctx.op_cat!(float, "/");
                                    continue;
                                case F32_MIN:
                                    ctx.op_min!float;
                                    continue;
                                case F32_MAX:
                                    ctx.op_max!float;
                                    continue;
                                case F32_COPYSIGN:
                                    ctx.op_copysign!float;
                                    continue;
                                case F64_ABS:
                                    ctx.op_math!(float, "fabs");
                                    continue;
                                case F64_NEG:
                                    ctx.op_unary!(double, "-");
                                    continue;
                                case F64_CEIL:
                                    ctx.op_math!(double, "ceil");
                                    continue;
                                case F64_FLOOR:
                                    ctx.op_math!(double, "floor");
                                    continue;
                                case F64_TRUNC:
                                    ctx.op_math!(double, "trunc");
                                    continue;
                                case F64_NEAREST:
                                    ctx.op_math!(double, "rint");
                                    continue;
                                case F64_SQRT:
                                    ctx.op_math!(double, "sqrt");
                                    continue;
                                case F64_ADD:
                                    ctx.op_cat!(double, "/");
                                    continue;
                                case F64_SUB:
                                    ctx.op_cat!(double, "-");
                                    continue;
                                case F64_MUL:
                                    ctx.op_cat!(double, "*");
                                    continue;
                                case F64_DIV:
                                    ctx.op_cat!(double, "/");
                                    continue;
                                case F64_MIN:
                                    ctx.op_min!double;
                                    continue;
                                case F64_MAX:
                                    ctx.op_max!double;
                                    continue;
                                case F64_COPYSIGN:
                                    ctx.op_copysign!double;
                                    continue;
                                    /* conversions of i32 */
                                case I32_WRAP_I64:
                                    ctx.op_wrap!(int, long);
                                    // const value = ctx.pop!int; //(int)(PI64() & 0xFFFFFFFFLL);
                                    // ctx.push(value);
                                    continue;
                                case I32_TRUNC_F32_S:
                                    /* We don't use INT_MIN/INT_MAX/UINT_MIN/UINT_MAX,
                                       since float/double values of ieee754 cannot precisely represent
                                       all int/uint/int64/uint64 values, e.g.:
                                       UINT_MAX is 4294967295, but (float32)4294967295 is 4294967296.0f,
                                       but not 4294967295.0f. */
                                    if (ctx.op_trunc!(int, float))
                                        goto case ERROR;
                                    continue;
                                case I32_TRUNC_F32_U:
                                    if (ctx.op_trunc!(uint, float))
                                        goto case ERROR;
                                    continue;
                                case I32_TRUNC_F64_S:
                                    if (ctx.op_trunc!(int, double))
                                        goto case ERROR;
                                    continue;
                                case I32_TRUNC_F64_U:
                                    if (ctx.op_trunc!(int, double))
                                        goto case ERROR;
                                    continue;
                                    /* conversions of i64 */
                                case I64_EXTEND_I32_S:
                                    ctx.op_convert!(long, int);
                                    continue;
                                case I64_EXTEND_I32_U:
                                    ctx.op_convert!(long, uint);
                                    continue;
                                case I64_TRUNC_F32_S:
                                    if (ctx.op_trunc!(long, float))
                                        goto case ERROR;
                                    continue;
                                case I64_TRUNC_F32_U:
                                    if (ctx.op_trunc!(ulong, float))
                                        goto case ERROR;
                                    continue;
                                case I64_TRUNC_F64_S:
                                    if (ctx.op_trunc!(long, double))
                                        goto case ERROR;
                                    continue;
                                case I64_TRUNC_F64_U:
                                    if (ctx.op_trunc!(ulong, double))
                                        goto case ERROR;
                                    continue;
                                    /* conversions of f32 */
                                case F32_CONVERT_I32_S:
                                    ctx.op_convert!(float, int);
                                    continue;
                                case F32_CONVERT_I32_U:
                                    ctx.op_convert!(float, uint);
                                    continue;
                                case F32_CONVERT_I64_S:
                                    ctx.op_convert!(float, long);
                                    continue;
                                case F32_CONVERT_I64_U:
                                    ctx.op_convert!(float, ulong);
                                    continue;
                                case F32_DEMOTE_F64:
                                    ctx.op_convert!(float, double);
                                    continue;
                                    /* conversions of f64 */
                                case F64_CONVERT_I32_S:
                                    ctx.op_convert!(double, int);
                                    continue;
                                case F64_CONVERT_I32_U:
                                    ctx.op_convert!(double, uint);
                                    continue;
                                case F64_CONVERT_I64_S:
                                    ctx.op_convert!(double, long);
                                    continue;
                                case F64_CONVERT_I64_U:
                                    ctx.op_convert!(double, ulong);
                                    continue;
                                case F64_PROMOTE_F32:
                                    ctx.op_convert!(double, float);
                                    continue;
                                    /* reinterpretations */
                                case I32_REINTERPRET_F32:
                                case I64_REINTERPRET_F64:
                                case F32_REINTERPRET_I32:
                                case F64_REINTERPRET_I64:
                                    continue;
                                case I32_EXTEND8_S:
                                    ctx.op_convert!(int, byte);
                                    continue;
                                case I32_EXTEND16_S:
                                    ctx.op_convert!(int, short);
                                    continue;
                                case I64_EXTEND8_S:
                                    ctx.op_convert!(long, byte);
                                    continue;
                                case I64_EXTEND16_S:
                                    ctx.op_convert!(long, short);
                                    continue;
                                case I64_EXTEND32_S:
                                    ctx.op_convert!(long, int);
                                    continue;
                                case I32_TRUNC_SAT_F32_S:
                                    ctx.op_trunc_sat!(int, float);
                                    continue;
                                case I32_TRUNC_SAT_F32_U:
                                    ctx.op_trunc_sat!(uint, float);
                                    continue;
                                case I32_TRUNC_SAT_F64_S:
                                    ctx.op_trunc_sat!(int, double);
                                    continue;
                                case I32_TRUNC_SAT_F64_U:
                                    ctx.op_trunc_sat!(uint, double);
                                    continue;
                                case I64_TRUNC_SAT_F32_S:
                                    ctx.op_trunc_sat!(long, float);
                                    continue;
                                case I64_TRUNC_SAT_F32_U:
                                    ctx.op_trunc_sat!(ulong, float);
                                    continue;
                                case I64_TRUNC_SAT_F64_S:
                                    ctx.op_trunc_sat!(long, double);
                                    continue;
                                case I64_TRUNC_SAT_F64_U:
                                    ctx.op_trunc_sat!(ulong, double);
                                    continue;
                                case ERROR:
                                    unwined = true;
                                }
                            }
                        }
                    }
                    catch (RangeError err) {
                        ///
                        if (ctx.sp <= 2) {
                            ctx.error = TVMError.STACK_EMPTY;
                        }
                        else {
                            //                ctx.error = TVMError.STACK_OVERFLOW;
                            // }
                            // else {
                            ctx.error = TVMError.STACK_OVERFLOW;
                        }
                        unwined = true;
                    }
                }
                bytecode_func(wasm_func);
            }

            final private immutable(ubyte[]) load(const(WasmReader) reader, ref FunctionInstance[] _funcs_table)  {
                version(none) {
                bool indirect_call_used;
                //TVMBuffer[] bouts;

                void block(ref TVMBuffer bout, ExprRange expr, ref FunctionInstance.FuncBody func_body) @safe pure {
                    // scope const(uint)[] labels;
                    // scope const(uint)[] label_offsets;
                    //auto sec_imports = sections[Sections.IMPORTS];
                    const(ExprRange.IRElement) expand_block(const uint level, const uint frame_offset) @safe {
                        //TVMBuffer bout;
                        FunctionInstance.FuncBody.BlockSegment block_segment = FunctionInstance.FuncBody.BlockSegment(bout.offset);
                        scope(exit) {
                            block_segment.end_index = bout.offset;
                            func_body.block_segments ~= block_segment;
                        }
                        uint global_offset() @safe nothrow pure {
                            return cast(uint)(bout.offset + frame_offset);
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
                                    bout(elm.code.convert, elm.warg.get!uint.u32);
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
                    // auto frame = bouts[0].toBytes;
                    // (() @trusted {
                    //     foreach (branch_offset; label_offsets) {
                    //         const labelidx = frame.binpeek!uint(branch_offset);
                    //         frame.binwrite(labels[labelidx], branch_offset);
                    //     }
                    // })();
                }

                auto frame_buf = new TVMBuffer;
                // bouts ~= frame_buf;
                frame_buf.reserve = reader.serialize.length;
                auto func_table = new FunctionInstance[sections[Section.CODE].length];
//                _funcs_table.length = sections[Section.CODE].length;
                auto func_range = (() @trusted => lockstep(sections[Section.FUNCTION][],
                        sections[Section.CODE][], StoppingPolicy.requireSameLength))();
//                alias FuncRange = typeof(func_range);
                immutable(ubyte)[] all_frames;
                // version(none)
                // uint expand_functions(const size_t index=0) @trusted {
                //     if (func_range.empty) {
                //         all_frame = frame_buf.toBytes.idup;
                //         return cast(uint) frame_buf.offset;
                //     }
                //     const start_ip = cast(uint) frame_buf.offset;
                //     auto c = range.front[0];
                //     const local_size = c.locals.walkLength;
                //     block(c[]);
                //     func_range.popFront;
                //     const end_ip = expand_functions(index+1);
                //     func_table[index]=FunctionInstance(all_frames[start_ip..end_ip], local_size);
                //     return start_ip;

                //     // scope const func_type = sections[Section.TYPE][][sec_func.idx]; // typeidx
                //     // func.local_size = cast(ushort) c.locals.walkLength;
                //     // range.popFront;
                immutable(FunctionInstance[]) expand_functions() @trusted {
                    const number_of_functions = sections[Section.CODE].length;
//                    sections[Section.CODE].length];
                    scope func_bodies =  new FunctionInstance.FuncBody[number_of_functions]; // List of all block segements in each function

                    foreach (ref func_body, sec_func, c;
                        lockstep(func_bodies, sections[Section.FUNCTION][],
                            sections[Section.CODE][], StoppingPolicy.requireSameLength)) {
                        const func_type = sections[Section.TYPE][sec_func.idx]; // typeidx
                        func_body.local_count = cast(ushort) (c.locals.walkLength);
                        func_body.param_count = cast(ushort) (func_type.params.length);
                        func_body.return_count = cast(ushort) (func_type.results.length);

                        func_body.block_segments~=FunctionInstance.FuncBody.BlockSegment(frame_buf.offset);
                        pragma(msg, typeof(c[]));
                        block(c[], func_body);
                        func_body.block_segements[0].end_index = frame_buf.offset;
                    }

                    immutable full_frame = frame_buf.toBytes.idup;
                    auto result = func_bodies.map!((func_body) => FunctionInstance(func_body, full_frame)).array;
                    return assumeUnique(result);
                    // auto func_table = new FunctionInstance[number_of_functions];
                    // foreach (ref func, block_segemnts; lockstep(func_table, func_bodies)) {


//                    }

                }
                expand_functions;
                }
                    //return (() @trusted => assumeUnique(func_table))();
                return null;
            }

        }
    }
    unittest {
        static int simple_int(int x, int y);
        TVMModules mod;
//        mod.lookup!simple_int("env");
    }

    unittest {
        import tagion.tvm.test.wasm_samples : simple_alu;
        import tagion.tvm.TVMContext;
        // static int simple_int(int x, int y);
        TVMModules tvm_mod;
        auto mod=tvm_mod("env", simple_alu);

//        import mod_simple_alu = tests.simple_alu.simple_alu;

        tvm_mod.link;
        {
            TVMContext ctx;
            ctx.stack.length = 10;
            const wasm_func_inc = mod.lookup!(func_inc);

            const result = wasm_func_inc(ctx, 17);
            writefln("result=%s", result);
            writefln("ctx.sp=%s", ctx.sp);
        }
//        mod.lookup!simple_int("env");
    }
}

extern (C) int func_inc(int x);
