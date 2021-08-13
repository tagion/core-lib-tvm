module tagion.tvm.wamr.TVMBasic;

import tagion.wasm.WasmBase : Types; //, Section, ExprRange, IR, IRType, instrTable, WasmArg;

alias WasmTypes=AliasSeq!(int, long, float, double, uint, ulong, short, ushort, byte, ubyte, WasmType);


@safe @nogc
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
