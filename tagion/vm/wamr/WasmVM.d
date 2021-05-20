module tagion.vm.wamr.WasmVM;

import tagion.basic.Basic : isOneOf;
import tagion.vm.wasm.WasmBase : Types, Section, ExprRange, IR, IRType, instrTable, WasmArg;
import tagion.vm.wasm.WasmReader : WasmReader;

import std.range : lockstep, enumerate, StoppingPolicy;
import std.format;
import std.traits : EnumMembers, isSigned, isUnsigned, isIntegral;
import std.meta : AliasSeq, staticIndexOf;
import std.exception : assumeUnique;

@safe
class WasmVM {
    alias Sections=WasmReader.Sections;
    alias WasmTypes=AliasSeq!(int, long, float, double, uint, ulong, short, ushort, byte, ubyte, WasmType);
    union WasmType {
        @(Types.I32) int i32;
        @(Types.I64) long i64;
        @(Types.F32) float f32;
        @(Types.F64) double f64;
        alias WasmT=typeof(this.tupleof);
        pure nothrow {
            void opAssign(T)(const T x) if(isOneOf!(T, WasmT)) {
                enum index=staticIndexOf!(T, WasmT);
                this.tupleof[index] = x;
            }

            void opAssign(const uint x) {
                i32 = cast(uint)x;
            }
            void opAssign(const ulong x) {
                i64 = cast(long)x;
            }

            void opOpAssign(string op, T)(const T x) if(isOneOf!(T, WasmT)) {
                enum index=staticIndexOf!(T, WasmT);
                enum code=format(q{this.tupleof[index] %s= x;}, op);
                mixin(code);
            }

            void opOpAssign(string op, T)(const T x) if(isIntegral!T && !isOneOf!(T, WasmT)) {
                static if (T.sizeof <= int.sizeof) {
                    alias U=int;
                }
                else {
                    alias U=long;
                }
                enum index=staticIndexOf!(U, WasmT);
                enum code=format(q{this.tupleof[index] %s= cast(U)x;}, op);
                mixin(code);
            }




            // void opOpAssign(T, string op)(const T x) if(is(T==WasmType)) {
            //     pragma(msg, "WasmType ", T.stringof);
            //     // enum index=staticIndexOf!(T, WasmT);
            //     // enum code=format(q{this.tupleof[index] %s= x}, op);
            //     // mixin(code);
            // }


            T get(T)() if (isOneOf!(T, WasmT)) {
                enum index=staticIndexOf!(T, WasmT);
                return this.tupleof[index];
            }

            T get(T)() if (isIntegral!T && !isOneOf!(T, WasmT)) {
                static if (T.sizeof <= int.sizeof) {
                    return cast(T)i32;
                }
                else {
                    return cast(T)i64;
                }
            }
        }
    }

    // struct Context {
    WasmType[] stack;
    WasmType[] globals;
    WasmType[] locals;
    ubyte[] memory;
    uint[] call_stack;
    // }
    // private OpCode* ip_addr;
    // uint ip;
    private uint sp;
//    private uint ip;
    private uint call_sp;
    // Current context
    immutable(ubyte)[] code_mem;
    uint ip;
    uint local_offset;
    immutable(OpFunc[ubyte.max+1]) irmap;
    @trusted
    this() {
        OpFunc[ubyte.max+1] _irmap;
        build_irmap(_irmap);
        irmap=assumeUnique(_irmap);
    }

    struct Context {
        private {
            immutable(ubyte[]) code_mem;
            uint ip;
            uint local_offset;
        }

        this(const WasmVm vm, WasmReader wasmreader) {
            auto range
            wasmreader(this);
        }

        struct ContextRange {
            @disable this();
            OutBuffer buf;
            this(const size_t size) {
                // buf.reserve(size);
            }

        alias Custom=Sections[Section.CUSTOM];
        void custom_sec(ref scope const(Custom) _custom) {
//             output.writef(`%s(custom "%s" "`, indent, _custom.name);
//             enum {
//                 SPACE=32,
//                 DEL=127
//             }
//             foreach(d; _custom.bytes) {
//                 if ((d > SPACE) && (d < DEL)) {
//                     output.writef(`%c`, char(d));
//                 }
//             else {
//                 output.writef(`\x%02X`, d);
//             }
//             }
//             output.writefln(`")`);
// //        auto _custom=mod[Section.CUSTOM];//.custom_sec;
//             //foreach(c; _custom[]) {
// //        writefln("_custom=%s",  _custom);
//             //output.writef("%s(custom (%s %s))", indent, c.name, cast(string)(c.bytes));
//             //}
        }

        alias Type=Sections[Section.TYPE];
        void type_sec(ref const(Type) _type) {
//        auto _type=*mod[Section.TYPE]; //type_sec;
            // foreach(i, t; _type[].enumerate) {
            //     output.writef("%s(type (;%d;) (%s", indent, i, typesName(t.type));
            //     if (t.params.length) {
            //         output.write(" (param");
            //         foreach(p; t.params) {
            //             output.writef(" %s", typesName(p));
            //         }
            //         output.write(")");
            //     }
            //     if (t.results.length) {
            //         output.write(" (result");
            //         foreach(r; t.results) {
            //             output.writef(" %s", typesName(r));
            //         }
            //         output.write(")");
            //     }
            //     output.writeln("))");
            // }
        }

        alias Import=Sections[Section.IMPORT];
        @trusted
        void import_sec(ref const(Import) _import) {
//        auto _import=*mod[Section.IMPORT];//.import_sec;
            // static string importdesc(ref const ImportType imp, const size_t index) {
            //     const desc=imp.importdesc.desc;
            //     with(IndexType) {
            //         final switch(desc) {
            //         case FUNC:
            //             const _funcdesc=imp.importdesc.get!FUNC;
            //             return format("(%s (;%d;) (type %d))", indexName(desc), index, _funcdesc.typeidx);
            //         case TABLE:
            //             const _tabledesc=imp.importdesc.get!TABLE;
            //             return format("(%s (;%d;) %s %s)", indexName(desc), index, limitToString(_tabledesc.limit), typesName(_tabledesc.type));
            //         case MEMORY:
            //             const _memorydesc=imp.importdesc.get!MEMORY;
            //             return format("(%s(;%d;)  %s %s)", indexName(desc), index, limitToString(_memorydesc.limit));
            //         case GLOBAL:
            //             const _globaldesc=imp.importdesc.get!GLOBAL;
            //             return format("(%s (;%d;) %s)", indexName(desc), index, globalToString(_globaldesc));
            //         }
            //     }
            // }
            foreach(i, imp; _import[].enumerate) {
//            output.writefln("imp=%s", imp);
                // output.writefln(`%s(import "%s" "%s" %s)`,
                //     indent, imp.mod, imp.name, importdesc(imp, i));
            }
        }

        alias Function=Sections[Section.FUNCTION];
        protected Function _function;
        @trusted void function_sec(ref const(Function) _function) {
            // Empty
            // The functions headers are printed in the code section
            this._function=cast(Function)_function;
        }

        alias Table=Sections[Section.TABLE];
        private void table_sec(ref const(Table) _table) {
//        auto _table=*mod[Section.TABLE];
            // foreach(i, t; _table[].enumerate) {
            //     output.writefln("%s(table (;%d;) %s %s)", indent, i, limitToString(t.limit), typesName(t.type));
            // }
        }


        alias Memory=Sections[Section.MEMORY];
        private void memory_sec(ref const(Memory) _memory) {
//        auto _memory=*mod[Section.MEMORY];
            // foreach(i, m; _memory[].enumerate) {
            //     output.writefln("%s(memory (;%d;) %s)", indent, i, limitToString(m.limit));
            // }
        }

        alias Global=Sections[Section.GLOBAL];
        private void global_sec(ref const(Global) _global) {
//        auto _global=*mod[Section.GLOBAL];
            // foreach(i, g; _global[].enumerate) {
            //     output.writefln("%s(global (;%d;) %s (", indent, i, globalToString(g.global));
            //     auto expr=g[];
            //     block(expr, indent~spacer);
            //     output.writefln("%s))", indent);
            // }
        }

        alias Export=Sections[Section.EXPORT];
        private void export_sec(ref const(Export) _export) {
//        auto _export=*mod[Section.EXPORT];
            // foreach(exp; _export[]) {
            //     output.writefln(`%s(export "%s" (%s %d))`, indent, exp.name, indexName(exp.desc), exp.idx);
            // }

        }

        alias Start=Sections[Section.START];
        private void start_sec(ref const(Start) _start) {
            // output.writefln("%s(start %d),", indent, _start.idx);
        }

        alias Element=Sections[Section.ELEMENT];
        private void element_sec(ref const(Element) _element) {
//        auto _element=*mod[Section.ELEMENT];
            // foreach(i, e; _element[].enumerate) {
            //     output.writefln("%s(elem (;%d;) (", indent, i);
            //     auto expr=e[];
            //     const local_indent=indent~spacer;
            //     block(expr, local_indent~spacer);
            //     output.writef("%s) func", local_indent);
            //     foreach(f; e.funcs) {
            //         output.writef(" %d", f);
            //     }
            //     output.writeln(")");
            // }
        }

        alias Code=Sections[Section.CODE];
        @trusted
        private void code_sec(ref const(Code) _code) {
            buf.reserve(_code.length*5/4);
            foreach(f, c; lockstep(_function[], _code[], StoppingPolicy.requireSameLength)) {
                auto expr=c[];
                // output.writefln("%s(func (type %d)", indent, f.idx);
                //const local_indent=indent~spacer;
                if (!c.locals.empty) {
                    // output.writef("%s(local", local_indent);
                    foreach(l; c.locals) {
                        foreach(i; 0..l.count) {
                            // output.writef(" %s", typesName(l.type));
                        }
                    }
                    // output.writeln(")");
                }

                block(expr);
                // output.writefln("%s)", indent);
            }
        }

        alias Data=Sections[Section.DATA];
        private void data_sec(ref const(Data) _data) {
//        auto _data=*mod[Section.DATA];
            // foreach(d; _data[]) {
            //     output.writefln("%s(data (", indent);
            //     auto expr=d[];
            //     const local_indent=indent~spacer;
            //     block(expr, local_indent~spacer);
            //     output.writefln(`%s) "%s")`, local_indent, d.base);
            // }
        }

        private const(ExprRange.IRElement) block(ref ExprRange expr, const uint level=0) {
//        immutable indent=base_indent~spacer;
            string block_comment;
            uint block_count;
            uint count;
            static string block_result_type() (const Types t) {
                with(Types) {
                    switch(t) {
                    case I32, I64, F32, F64, FUNCREF:
                        return format(" (result %s)", typesName(t));
                    case EMPTY:
                        return null;
                    default:
                        check(0, format("Block Illegal result type %s for a block", t));
                    }
                }
                assert(0);
            }
            while (!expr.empty) {
                const elm=expr.front;
                const instr=instrTable[elm.code];
                expr.popFront;
                with(IRType) {
                    final switch(instr.irtype) {
                    case CODE:
                        buf.write(elm.code);
                        break;
                    case BLOCK:
                        block_comment=format(";; block %d", block_count);
                        block_count++;
                        // output.writefln("%s%s%s %s", indent, instr.name, block_result_type(elm.types[0]), block_comment);
                        const end_elm=block(expr, level+1);
                        const end_instr=instrTable[end_elm.code];
                        // output.writefln("%s%s", indent, end_instr.name);
                        //return end_elm;

                        // const end_elm=block_elm(elm);
                        if (end_elm.code is IR.ELSE) {
                            const endif_elm=block(expr, level+1);
                            const endif_instr=instrTable[endif_elm.code];
                            // output.writefln("%s%s %s count=%d", indent, endif_instr.name, block_comment, count);
                        }
                        break;
                    case BRANCH:
                        // output.writefln("%s%s %s", indent, instr.name, elm.warg.get!uint);
                        break;
                    case BRANCH_TABLE:
                        static string branch_table(const(WasmArg[]) args) {
                            string result;
                            foreach(a; args) {
                                result~=format(" %d", a.get!uint);
                            }
                            return result;
                        }
                        buf.write(elm.code);
                        buf.write(LEB128.encode(cast(uint)elm.wargs.length));

                        // output.writefln("%s%s %s", indent, instr.name, branch_table(elm.wargs));
                        break;
                    case CALL:
                        buf.write(elm.code);
                        buf.write(LEB128.encode(elm.warg.get!uint));
                        break;
                    case CALL_INDIRECT:
                        buf.write(elm.code);
                        break;
                    case LOCAL:
                        // output.writefln("%s%s %d", indent, instr.name, elm.warg.get!uint);
                        break;
                    case GLOBAL:
                        // output.writefln("%s%s %d", indent, instr.name, elm.warg.get!uint);
                        break;
                    case MEMORY:
                        // output.writefln("%s%s%s", indent, instr.name, offsetAlignToString(elm.wargs));
                        break;
                    case MEMOP:
                        // output.writefln("%s%s", indent, instr.name);
                        break;
                    case CONST:
                        buf.write(elm.code);
                        buf.write(LEB128.encode(elm.warg.get!uint));
                        break;
                    case END:
                        return elm;
                    }
                }
            }
            return ExprRange.IRElement(IR.END, level);
        }


    }


    alias OpFunc=void delegate();
    // union OpCode {
    //     const void delegate() op;
    //     WasmType arg;
    //     this(OpCode op) pure nothrow {
    //         this.op=op;
    //     }
    //     this(T)(T x) pure nothrow {
    //         arg = x;
    //     }
    // }

//    class WasmModule {
    // immutable(ubyte[]) wasm;
    // immutable(ubyte[]) frame_ip;
    // private {
//    OpFunc[ubyte.max+1] irmap;
    // }
//        OpFunc[ubyte.max+1]) _irmap;

    nothrow {
        final void push(T)(const T x) if (isOneOf!(T, WasmTypes)) {
            static if (is(T:int)) {
                stack[sp++].i32=x;
            }
            else static if (is(T:long)) {
                stack[sp++].i64=x;
            }
            else static if (is(T:float)) {
                stack[sp++].f32=x;
            }
            else static if (is(T:double)) {
                stack[sp++].f64=x;
            }
            else static if (is(T:WasmType)) {
                stack[sp++]=x;
            }
        }

        final T pop(T)() { //if(isOneOf!(T, WasmTypes)) {
            static if (is(T==int)) {
                return stack[--sp].i32;
            }
            else static if (is(T==long)) {
                return stack[--sp].i64;
            }
            else static if (is(T==float)) {
                return stack[--sp].f32;
            }
            else static if (is(T==double)) {
                return stack[--sp].f64;
            }
            else static if (is(T==uint)) {
                return cast(T)stack[--sp].i32;
            }
            else static if (is(T==ulong)) {
                return cast(T)stack[--sp].i64;
            }
            else static if (is(T==WasmType)) {
                return stack[--sp];
            }
            else {
                static assert(0, format("Type %s is not suppoted", T.stringof));
            }
        }
    }


    this(WasmReader wasmstream) pure {
        wasmstream(this);
        // foreach(a; wasmstream[]) {
        //         if (a.section == Section.CODE) {

        //         }
        //     }
        // }
    }

//    class WasmModule {
    private final nothrow {
        @trusted
            T decode(T)() if (isUnsigned!T) {
            T result;
            uint shift;
            foreach(d; code_mem.ptr[ip..ip+T.sizeof+1]) {
                result |= (d & T(0x7F)) << shift;
                ip++;
                if ((d & 0x80) == 0) {
                    return result;
                }
                shift+=7;
            }
            assert(0);
        }

        @trusted
            T decode(T)() if (isSigned!T) {
            T result;
            uint shift;
            foreach(d; code_mem.ptr[ip..ip+T.sizeof+1]) {
                ip++;
                result |= (d & T(0x7F)) << shift;
                shift+=7;
                if ((d & 0x80) == 0 ) {
                    if ((shift < long.sizeof*8) && ((d & 0x40) != 0)) {
                        result |= (~T(0) << shift);
                    }
                    return result;
                }
            }
            assert(0);
        }

        void set_exception(string msg) {
            assert(0, msg);
        }

        void binop(T, string op)() {
            enum code=format(q{stack[sp] %s= pop!T;}, op);
            pragma(msg, "binop ", code, " : ", T.stringof, " : ", typeof(pop!T));
//            pragma(msg, "binop ", code, " : ", T.stringof, " : ", typeof(pop!T));
            //stack[sp] = stack[sp].get!T + pop!T;
//            stack[sp] += 10L;
//            stack[sp].get!T + pop!T;
            mixin(code);
            ip++;
        }

        void unop(T, string op)() {
            enum code=format(q{stack[sp] = %s stack[sp].get!T;}, op);
            mixin(code);
            ip++;
        }

        void funcop(T, string func)() {
            enum code=format(q{stack[sp] =%s(stack[sp].get!T);}, func);
            mixin(code);
            ip++;
        }

        void binop2(T1, T2, string op)() {
            const a=pop!T2;
            enum code=format(q{stack[sp] = stack[sp].get!T1 %s a;}, op);
            mixin(code);
            ip++;
        }

        void rotl(T)() {
            import core.bitop : rol;
            const a=pop!uint;
            stack[sp] = rol(stack[sp].get!T, a);
            ip++;
        }

        void rotr(T)() {
            import core.bitop : ror;
            const a=pop!uint;
            stack[sp] = ror(stack[sp].get!T, a);
            ip++;
        }

        void comp(T, string cond)() {
            enum code=format(q{stack[sp]= int(stack[sp].get!T %s pop!T);}, cond);
            mixin(code);
            ip++;
        }

        void comp_eqz(T)() {
            stack[sp]= int(stack[sp].get!T == T(0));
            ip++;
        }

        void select() {
            const flag=pop!int;
            const b=stack[sp--];
            if (!flag) {
                stack[sp] = b;
            }
            ip++;
        }

        void br_if() {
            const jump_false_ip = decode!uint;
            const flag=pop!int;
            if (flag != 0) {
                ip = jump_false_ip;
                return;
            }
            ip++;
        }

        void br() {
            ip = decode!uint;
        }

        @trusted
            void br_table() {
            const lN=decode!uint;
            auto index=pop!uint;
            index=(index < lN)?index:lN;
            ip = *cast(uint*)(code_mem.ptr+ip+index*uint.sizeof);
        }

        void if_then() {
            const flag = pop!int;
            const false_ip = decode!uint;
            ip = (flag)?ip+1:false_ip;
        }

        @trusted
            void push_const(T)() {
            static if(isIntegral!T) {
                push(decode!T);
            }
            else {
                const x=cast(T*)&code_mem.ptr[ip];
                pragma(msg, typeof(*x));
                push(*x);
                ip+=T.sizeof;
            }
        }

        void func_return() {
            ip = call_stack[call_sp--];
        }

        void func_call() {
            const funcidx = decode!uint;
            call_stack[++call_sp] = ip;
            // ip = func_

            // ip = call_stack[call_sp--];
        }

        void func_call_indirect() {
            const funcidx = pop!uint;
            call_stack[++call_sp] = ip;
            // ip = func_

            // ip = call_stack[call_sp--];
        }

        void local_get() {
            ip++;
            const index=decode!uint;
            push(locals[index+local_offset]);
        }

        void local_set() {
            ip++;
            const index=decode!uint;
            locals[index+local_offset] = pop!WasmType;
        }

        void local_tee() {
            ip++;
            const index=decode!uint;
            locals[index+local_offset] = stack[sp];
        }

        void global_get() {
            ip++;
            const index=decode!uint;
            push(globals[index+local_offset]);
        }

        void global_set() {
            ip++;
            const index=decode!uint;
            globals[index+local_offset] = pop!WasmType;
        }

// const(OpCode*) (T, string cond)() {
        //     enum code=format(q{stack[sp]= int(stack[sp].get!T %s pop!T);}, cond);
        //     mixin(code);
        //     return ++ip_addr;
        // }

        void math_func(T, string func)() {
            import std.math;
            enum code=format(q{stack[sp]= %s(stack[sp].get!T);}, func);
            ip++;
        }

        alias load(T)=load!(T, T);

        @trusted
            void load(T, U)() if (isOneOf!(T, WasmTypes) && isOneOf!(U, WasmTypes)) {
            static assert(T.sizeof >= U.sizeof);
            const _align = decode!uint;
            const _offset = decode!uint;
            const _index = _offset + pop!uint << _align;
            T x;
            if (memory.length < _index+U.sizeof) {
                set_exception("out of memory");
                return;
            }
            static if (is(T == U)) {
                //const y=memory[_index.._index+T.sizeof];
                x=*cast(T*)&memory[_index];
            }
            else static if (isIntegral!U) {
                static if (isSigned!U) {
                    const U u=*cast(U*)&memory[_index];
                    enum ubits=U.sizeof*8;
                    x=(u & 1 << (ubits -1))?((T(-1) & ~(1 << ubits -1))|u):u;
                }
                else {
                    x=*cast(T*)&memory[_index];
                }
            }
            else {
                static assert(is(T == S));

            }
            push(x);
            ip++;
        }

        @trusted void store(T, U=T)() if (isOneOf!(T, WasmTypes) && isOneOf!(U, WasmTypes)) {
            static assert(T.sizeof >= U.sizeof);
            const _align = decode!uint;
            const _offset = decode!uint;
            const _index = _offset + pop!uint << _align;
            if (memory.length < _index+U.sizeof) {
                set_exception("out of memory");
                return;
            }
//            static if (is(T == U)) {
            T* x=cast(T*)(memory.ptr+_index);
            *x=stack[--sp].get!T;
            // }
            // else static if (isIntegral!U) {
            //     memory[_index.._index+U.sizeof]=(cast(ubyte*)&stack[--sp].get!T)[0..U.sizeof];
            // }
            // else {
            //     static assert(0);
            // }
            ip++;
        }

        void drop() {
            sp--;
            ip++;
        }

        void popcount(T)() {
            static uint count_ones(size_t BITS=T.sizeof*8)(const T x) pure nothrow {
                static if ( BITS == 1 ) {
                    return x & 0x1;
                }
                else if ( x == 0 ) {
                    return 0;
                }
                else {
                    enum HALF_BITS=BITS/2;
                    enum MASK=T(1UL << (HALF_BITS))-1;
                    return count_ones!(HALF_BITS)(x & MASK) + count_ones!(HALF_BITS)(x >> HALF_BITS);
                }
            }
            stack[sp]=count_ones(stack[sp].get!T);
            ip++;
        }

        void clz(T)() {
            static uint count_leading_zeros(size_t BITS=T.sizeof*8)(const T x) pure nothrow {
                static if (BITS == 0) {
                    return 0;
                }
                else if (x == 0) {
                    return BITS;
                }
                else {
                    enum HALF_BITS=BITS/2;
                    enum MASK=T(T(1) << (HALF_BITS))-1;
                    const count=count_leading_zeros!HALF_BITS(x & MASK);
                    if (count == HALF_BITS) {
                        return count + count_leading_zeros!HALF_BITS(x >> HALF_BITS);
                    }
                    return count;
                }
                assert(0);
            }
            stack[sp] = count_leading_zeros(stack[sp].get!T);
            ip++;
        }

        void ctz(T)() {
            static uint count_trailing_zeros(size_t BITS=T.sizeof*8)(const T x) pure nothrow {
                static if (BITS == 0) {
                    return 0;
                }
                else if (x == 0) {
                    return BITS;
                }
                else {
                    enum HALF_BITS=BITS/2;
                    enum MASK=T(T(1) << (HALF_BITS))-1;
                    const count=count_trailing_zeros!HALF_BITS(x >> HALF_BITS);
                    if (count == HALF_BITS) {
                        return count + count_trailing_zeros!HALF_BITS(x & MASK);
                    }
                    return count;
                }
                assert(0);
            }
            stack[sp] = count_trailing_zeros(stack[sp].get!T);
            ip++;
        }

        void min(T)() {
            const a=pop!T;
            const b=stack[sp].get!T;
            stack[sp] = (a<b)?a:b;
            ip++;
        }

        void max(T)() {
            const a=pop!T;
            const b=stack[sp].get!T;
            stack[sp] = (a>b)?a:b;
            ip++;
        }

        void convert(DST, SRC)() {
            stack[sp] = cast(DST)stack[sp].get!SRC;
            ip++;
        }

        void wrap() {
            stack[sp] = cast(uint)(stack[sp].get!ulong);
            ip++;
        }

        void trunc(DST, SRC, bool saturation=false)() {
            import std.math : isNaN;
            const x=stack[sp].get!SRC;
            if (x.isNaN) {
                static if (saturation) {
                    set_exception("invalid conversion to integer");
                    return;
                }
                else {
                    stack[sp] = DST(0);
                }
            }
            else if (x <= DST.min) {
                static if (saturation) {
                    set_exception("integer overflow");
                    return;
                }
                else {
                    stack[sp] = DST.min;
                }
            }
            else if (x >= DST.max) {
                static if (saturation) {
                    set_exception("integer overflow");
                    return;
                }
                else {
                    stack[ip] = DST.max;
                }
            }
            else {
                stack[ip] = cast(DST)x;
            }
            ip++;
        }

        void copysign(T)() {
            import std.math : fabs;
            const b=pop!T;
            const a=fabs(stack[sp].get!T);
            stack[sp] = (b<0.0)?-a:a;
        }

//             #define TRUNC_FUNCTION(func_name, src_type, dst_type, signed_type)  \
// static dst_type                                                     \
// func_name(src_type src_value, src_type src_min, src_type src_max,   \
//           dst_type dst_min, dst_type dst_max, bool is_sign)         \
// {                                                                   \
//   dst_type dst_value = 0;                                           \
//   if (!isnan(src_value)) {                                          \
//       if (src_value <= src_min)                                     \
//           dst_value = dst_min;                                      \
//       else if (src_value >= src_max)                                \
//           dst_value = dst_max;                                      \
//       else {                                                        \
//           if (is_sign)                                              \
//               dst_value = (dst_type)(signed_type)src_value;         \
//           else                                                      \
//               dst_value = (dst_type)src_value;                      \
//       }                                                             \
//   }                                                                 \
//   return dst_value;                                                 \
// }
// static bool
// trunc_f32_to_int(WASMModuleInstance *module,
//                  uint8 *frame_ip, uint32 *frame_lp,
//                  float32 src_min, float32 src_max,
//                  bool saturating, bool is_i32, bool is_sign)
// {
//     float32 src_value = GET_OPERAND(float32, 0);
//     uint64 dst_value_i64;
//     uint32 dst_value_i32;

//     if (!saturating) {
//         if (isnan(src_value)) {
//             wasm_set_exception(module, "invalid conversion to integer");
//             return true;
//         }
//         else if (src_value <= src_min || src_value >= src_max) {
//             wasm_set_exception(module, "integer overflow");
//             return true;
//         }
//     }

//     if (is_i32) {
//         uint32 dst_min = is_sign ? INT32_MIN : 0;
//         uint32 dst_max = is_sign ? INT32_MAX : UINT32_MAX;
//         dst_value_i32 = trunc_f32_to_i32(src_value, src_min, src_max,
//                                          dst_min, dst_max, is_sign);
//         SET_OPERAND(uint32, 2, dst_value_i32);
//     }
//     else {
//         uint64 dst_min = is_sign ? INT64_MIN : 0;
//         uint64 dst_max = is_sign ? INT64_MAX : UINT64_MAX;
//         dst_value_i64 = trunc_f32_to_i64(src_value, src_min, src_max,
//                                          dst_min, dst_max, is_sign);
//         SET_OPERAND(uint64, 2, dst_value_i64);
//     }
//     return false;
// }

//             #define DEF_OP_TRUNC_F32(min, max, is_i32, is_sign) do {            \
//     if (trunc_f32_to_int(module, frame_ip, frame_lp, min, max,      \
//                          false, is_i32, is_sign))                   \
//         goto got_exception;                                         \
//     frame_ip += 4;                                                  \
//   } while (0)

        final void illegal_op() {
            assert(0);
        }
//         }
    }

    private void build_irmap(ref OpFunc[ubyte.max+1] _irmap) {
//        scope(exit) {
        //      }
        foreach(ref op; _irmap) {
            op=&illegal_op;
        }
        static foreach(op; EnumMembers!IR) {
            with(IR) {
                final switch(op) {
                case UNREACHABLE:
                    break;
                case NOP:
                    break;
                case BLOCK:
                    break;
                case LOOP:
                    break;
                case IF:
                    _irmap[op] = &if_then;
                    break;
                case ELSE:
                    _irmap[op] = &br;
                    break;
                case END:
                    _irmap[op] = &br;
                    break;
                case BR:
                    _irmap[op] = &br;
                    break;
                case BR_IF:
                    _irmap[op] = &br_if;
                    break;
                case BR_TABLE:
                    _irmap[op] = &br_table;
                    break;
                case RETURN:
                    _irmap[op] = &func_return;
                    break;
                case CALL:
                    _irmap[op] = &func_call;
                    break;
                case CALL_INDIRECT:
                    _irmap[op] = &func_call_indirect;
                    break;
                case DROP:
                    _irmap[op] = &drop;
                    break;
                case SELECT:
                    _irmap[op] = &select;
                    break;

                case LOCAL_GET:
                    _irmap[op] = &local_get;
                    break;
                case LOCAL_SET:
                    _irmap[op] = &local_set;
                    break;
                case LOCAL_TEE:
                    _irmap[op] = &local_tee;
                    break;
                case GLOBAL_GET:
                    _irmap[op] = &global_get;
                    break;
                case GLOBAL_SET:
                    _irmap[op] = &global_set;
                    break;

                case I32_LOAD:
                    _irmap[op] = &load!int;
                    break;
                case I64_LOAD:
                    _irmap[op] = &load!long;
                    break;
                case F32_LOAD:
                    _irmap[op] = &load!float;
                    break;
                case F64_LOAD:
                    _irmap[op] = &load!double;
                    break;
                case I32_LOAD8_S:
                    _irmap[op] = &load!(int, byte);
                    break;
                case I32_LOAD8_U:
                    _irmap[op] = &load!(int, ubyte);
                    break;
                case I32_LOAD16_S:
                    _irmap[op] = &load!(int, short);
                    break;
                case I32_LOAD16_U:
                    _irmap[op] = &load!(int, ushort);
                    break;
                case I64_LOAD8_S:
                    _irmap[op] = &load!(long, byte);
                    break;
                case I64_LOAD8_U:
                    _irmap[op] = &load!(long, ubyte);
                    break;
                case I64_LOAD16_S:
                    _irmap[op] = &load!(long, short);
                    break;
                case I64_LOAD16_U:
                    _irmap[op] = &load!(long, ushort);
                    break;
                case I64_LOAD32_S:
                    _irmap[op] = &load!(long, int);
                    break;
                case I64_LOAD32_U:
                    _irmap[op] = &load!(long, uint);
                    break;

                case I32_STORE:
                    _irmap[op] = &store!int;
                    break;
                case I64_STORE:
                    _irmap[op] = &store!long;
                    break;
                case F32_STORE:
                    _irmap[op] = &store!float;
                    break;
                case F64_STORE:
                    _irmap[op] = &store!double;
                    break;
                case I32_STORE8:
                    _irmap[op] = &store!(int, byte);
                    break;
                case I32_STORE16:
                    _irmap[op] = &store!(int, short);
                    break;
                case I64_STORE8:
                    _irmap[op] = &store!(long, byte);
                    break;
                case I64_STORE16:
                    _irmap[op] = &store!(long, short);
                    break;
                case I64_STORE32:
                    _irmap[op] = &store!(long, int);
                    break;
                case MEMORY_SIZE:
                    break;
                case MEMORY_GROW:
                    break;

                case I32_CONST:
                    _irmap[op] = &push_const!int;
                    break;
                case I64_CONST:
                    _irmap[op] = &push_const!long;
                    break;
                case F32_CONST:
                    _irmap[op] = &push_const!float;
                    break;
                case F64_CONST:
                    _irmap[op] = &push_const!double;
                    break;

                case I32_EQZ:
                    _irmap[op] = &comp_eqz!int;
                    break;
                case I32_EQ:
                    _irmap[op] = &comp!(int, `==`);
                    break;
                case I32_NE:
                    _irmap[op] = &comp!(int, `!=`);
                    break;
                case I32_LT_S:
                    _irmap[op] = &comp!(int, `<`);
                    break;
                case I32_LT_U:
                    _irmap[op] = &comp!(uint, `<`);
                    break;
                case I32_GT_S:
                    _irmap[op] = &comp!(int, `>`);
                    break;
                case I32_GT_U:
                    _irmap[op] = &comp!(uint, `>`);
                    break;
                case I32_LE_S:
                    _irmap[op] = &comp!(int, `<=`);
                    break;
                case I32_LE_U:
                    _irmap[op] = &comp!(uint, `<=`);
                    break;
                case I32_GE_S:
                    _irmap[op] = &comp!(int, `>=`);
                    break;
                case I32_GE_U:
                    _irmap[op] = &comp!(uint, `>=`);
                    break;

                case I64_EQZ:
                    _irmap[op] = &comp_eqz!long;
                    break;
                case I64_EQ:
                    _irmap[op] = &comp!(long, `==`);
                    break;
                case I64_NE:
                    _irmap[op] = &comp!(long, `!=`);
                    break;
                case I64_LT_S:
                    _irmap[op] = &comp!(long, `<`);

                    break;
                case I64_LT_U:
                    _irmap[op] = &comp!(ulong, `<`);
                    break;
                case I64_GT_S:
                    _irmap[op] = &comp!(long, `>`);
                    break;
                case I64_GT_U:
                    _irmap[op] = &comp!(ulong, `>`);
                    break;
                case I64_LE_S:
                    _irmap[op] = &comp!(long, `<=`);
                    break;
                case I64_LE_U:
                    _irmap[op] = &comp!(ulong, `<=`);
                    break;
                case I64_GE_S:
                    _irmap[op] = &comp!(long, `>=`);
                    break;
                case I64_GE_U:
                    _irmap[op] = &comp!(ulong, `>=`);
                    break;

                case F32_EQ:
                    _irmap[op] = &comp!(float, `==`);
                    break;
                case F32_NE:
                    _irmap[op] = &comp!(float, `!=`);
                    break;
                case F32_LT:
                    _irmap[op] = &comp!(float, `<`);
                    break;
                case F32_GT:
                    _irmap[op] = &comp!(float, `>`);
                    break;
                case F32_LE:
                    _irmap[op] = &comp!(float, `<=`);
                    break;
                case F32_GE:
                    _irmap[op] = &comp!(float, `>=`);
                    break;

                case F64_EQ:
                    _irmap[op] = &comp!(double, `==`);
                    break;
                case F64_NE:
                    _irmap[op] = &comp!(double, `!=`);
                    break;
                case F64_LT:
                    _irmap[op] = &comp!(double, `<`);
                    break;
                case F64_GT:
                    _irmap[op] = &comp!(double, `>`);
                    break;
                case F64_LE:
                    _irmap[op] = &comp!(double, `<=`);
                    break;
                case F64_GE:
                    _irmap[op] = &comp!(double, `>=`);
                    break;

                case I32_CLZ:
                    _irmap[op] = &clz!int;
                    break;
                case I32_CTZ:
                    _irmap[op] = &ctz!int;
                    break;
                case I32_POPCNT:
                    _irmap[op] = &popcount!int;
                    break;
                case I32_ADD:
                    _irmap[op] = &binop!(int, `+`);
                    break;
                case I32_SUB:
                    _irmap[op] = &binop!(int, `-`);
                    break;
                case I32_MUL:
                    _irmap[op] = &binop!(int, `*`);
                    break;
                case I32_DIV_S:
                    _irmap[op] = &binop!(int, `/`);
                    break;
                case I32_DIV_U:
                    _irmap[op] = &binop!(uint, `/`);
                    break;
                case I32_REM_S:
                    _irmap[op] = &binop!(int, `%`);
                    break;
                case I32_REM_U:
                    _irmap[op] = &binop!(uint, `%`);
                    break;
                case I32_AND:
                    _irmap[op] = &binop!(int, `&`);
                    break;
                case I32_OR:
                    _irmap[op] = &binop!(int, `|`);
                    break;
                case I32_XOR:
                    _irmap[op] = &binop!(int, `^`);
                    break;
                case I32_SHL:
                    _irmap[op] = &binop!(uint, `<<`);
                    break;
                case I32_SHR_S:
                    _irmap[op] = &binop2!(int, uint, `>>`);
                    break;
                case I32_SHR_U:
                    _irmap[op] = &binop!(uint, `>>`);
                    break;
                case I32_ROTL:
                    _irmap[op] = &rotl!uint;
                    break;
                case I32_ROTR:
                    _irmap[op] = &rotr!uint;
                    break;

                case I64_CLZ:
                    _irmap[op] = &clz!long;
                    break;
                case I64_CTZ:
                    _irmap[op] = &clz!int;
                    break;
                case I64_POPCNT:
                    _irmap[op] = &popcount!long;
                    break;
                case I64_ADD:
                    _irmap[op] = &binop!(long, `+`);
                    break;
                case I64_SUB:
                    _irmap[op] = &binop!(long, `-`);
                    break;
                case I64_MUL:
                    _irmap[op] = &binop!(long, `*`);
                    break;
                case I64_DIV_S:
                    _irmap[op] = &binop!(long, `/`);
                    break;
                case I64_DIV_U:
                    _irmap[op] = &binop!(ulong, `/`);
                    break;
                case I64_REM_S:
                    _irmap[op] = &binop!(long, `%`);
                    break;
                case I64_REM_U:
                    _irmap[op] = &binop!(ulong, `%`);
                    break;
                case I64_AND:
                    _irmap[op] = &binop!(ulong, `&`);
                    break;
                case I64_OR:
                    _irmap[op] = &binop!(ulong, `|`);
                    break;
                case I64_XOR:
                    _irmap[op] = &binop!(ulong, `^`);
                    break;

                case I64_SHL:
                    _irmap[op] = &binop!(ulong, `<<`);
                    break;
                case I64_SHR_S:
                    _irmap[op] = &binop2!(long, uint, `>>`);
                    break;
                case I64_SHR_U:
                    _irmap[op] = &binop!(ulong, `>>`);
                    break;
                case I64_ROTL:
                    _irmap[op] = &rotl!ulong;
                    break;
                case I64_ROTR:
                    _irmap[op] = &rotr!ulong;
                    break;

                case F32_ABS:
                    _irmap[op] =&math_func!(float, `fabs`);
                    break;
                case F32_NEG:
                    _irmap[op] = &unop!(float, `-`);
                    break;
                case F32_CEIL:
                    _irmap[op] =&math_func!(float, `ceil`);
                    break;
                case F32_FLOOR:
                    _irmap[op] =&math_func!(float, `floor`);
                    break;
                case F32_TRUNC:
                    _irmap[op] =&math_func!(float, `trunc`);
                    break;
                case F32_NEAREST:
                    _irmap[op] =&math_func!(float, `round`);
                    break;
                case F32_SQRT:
                    _irmap[op] =&math_func!(float, `sqrt`);
                    break;
                case F32_ADD:
                    _irmap[op] = &binop!(float, `+`);
                    break;
                case F32_SUB:
                    _irmap[op] = &binop!(float, `-`);
                    break;
                case F32_MUL:
                    _irmap[op] = &binop!(float, `*`);
                    break;
                case F32_DIV:
                    _irmap[op] = &binop!(float, `/`);
                    break;
                case F32_MIN:
                    _irmap[op] = &min!float;
                    break;
                case F32_MAX:
                    _irmap[op] = &max!float;
                    break;
                case F32_COPYSIGN:
                    _irmap[op] = &copysign!float;
                    break;

                case F64_ABS:
                    _irmap[op] = &math_func!(double, `abs`);
                    break;
                case F64_NEG:
                    _irmap[op] = &unop!(double, `-`);
                    break;
                case F64_CEIL:
                    _irmap[op] = &math_func!(double, `ceil`);
                    break;
                case F64_FLOOR:
                    _irmap[op] = &math_func!(double, `floor`);
                    break;
                case F64_TRUNC:
                    _irmap[op] = &math_func!(double, `truct`);
                    break;
                case F64_NEAREST:
                    _irmap[op] = &math_func!(double, `round`);
                    break;
                case F64_SQRT:
                    _irmap[op] = &math_func!(double, `sqrt`);
                    break;
                case F64_ADD:
                    _irmap[op] = &binop!(double, `+`);
                    break;
                case F64_SUB:
                    _irmap[op] = &binop!(double, `-`);
                    break;
                case F64_MUL:
                    _irmap[op] = &binop!(double, `*`);
                    break;
                case F64_DIV:
                    _irmap[op] = &binop!(double, `/`);
                    break;
                case F64_MIN:
                    _irmap[op] = &min!double;
                    break;
                case F64_MAX:
                    _irmap[op] = &max!double;
                    break;
                case F64_COPYSIGN:
                    _irmap[op] = &copysign!double;
                    break;

                case I32_WRAP_I64:
                    _irmap[op] = &wrap;
                    break;
                case I32_TRUNC_F32_S:
                    _irmap[op] = &trunc!(int, float);
                    break;
                case I32_TRUNC_F32_U:
                    _irmap[op] = &trunc!(uint, float);
                    break;
                case I32_TRUNC_F64_S:
                    _irmap[op] = &trunc!(int, double);
                    break;
                case I32_TRUNC_F64_U:
                    _irmap[op] = &trunc!(uint, double);
                    break;
                case I64_EXTEND_I32_S:
                    break;
                case I64_EXTEND_I32_U:
                    break;
                case I64_TRUNC_F32_S:
                    _irmap[op] = &trunc!(long, float);
                    break;
                case I64_TRUNC_F32_U:
                    _irmap[op] = &trunc!(ulong, float);
                    break;
                case I64_TRUNC_F64_S:
                    _irmap[op] = &trunc!(long, double);
                    break;
                case I64_TRUNC_F64_U:
                    _irmap[op] = &trunc!(ulong, double);
                    break;
                case F32_CONVERT_I32_S:
                    _irmap[op] = &convert!(float, int);
                    break;
                case F32_CONVERT_I32_U:
                    _irmap[op] = &convert!(float, uint);
                    break;
                case F32_CONVERT_I64_S:
                    _irmap[op] = &convert!(float, long);
                    break;
                case F32_CONVERT_I64_U:
                    _irmap[op] = &convert!(float, ulong);
                    break;
                case F32_DEMOTE_F64:
                    _irmap[op] = &convert!(double, float);
                    break;
                case F64_CONVERT_I32_S:
                    _irmap[op] = &convert!(double, int);
                    break;
                case F64_CONVERT_I32_U:
                    _irmap[op] = &convert!(double, uint);
                    break;
                case F64_CONVERT_I64_S:
                    _irmap[op] = &convert!(double, long);
                    break;
                case F64_CONVERT_I64_U:
                    _irmap[op] = &convert!(double, ulong);
                    break;
                case F64_PROMOTE_F32:
                    _irmap[op] = &convert!(float, double);
                    break;
                case I32_REINTERPRET_F32:
                    break;
                case I64_REINTERPRET_F64:
                    break;
                case F32_REINTERPRET_I32:
                    break;
                case F64_REINTERPRET_I64:
                    break;
                }
            }
        }
    }
}
