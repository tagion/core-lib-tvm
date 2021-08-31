module tagion.tvm.TVMExtOpcode;

import tagion.basic.Basic : basename;
import WasmBase = tagion.wasm.WasmBase;
import std.algorithm.searching : canFind;
import std.format;
import std.array : join;
import std.traits : EnumMembers;
import std.conv : to;
import std.traits : hasMember;

protected {
    enum ExtraIR : ubyte {
        ERROR = WasmBase.IR.I64_EXTEND32_S + 1, /// Extra jump label to handle errors
        EXTRA_BR, /// This branch jump is used internal buy the interpreter
        EXTERNAL_CALL, /// Call an external function from the import list
        I32_TRUNC_SAT_F32_S,
        I32_TRUNC_SAT_F32_U,
        I32_TRUNC_SAT_F64_S,
        I32_TRUNC_SAT_F64_U,
        I64_TRUNC_SAT_F32_S,
        I64_TRUNC_SAT_F32_U,
        I64_TRUNC_SAT_F64_S,
        I64_TRUNC_SAT_F64_U,
        UNDEFINED,
    }
}

protected string generateInternalIR(string enum_name)() {
    string[] codes;
    codes ~= format!`enum %s : ubyte {`(enum_name);
    import tagion.wasm.WasmBase : IR;

    enum Eliminate = [IR.NOP, IR.IF, IR.ELSE, IR.BLOCK, IR.END, IR.LOOP];
    foreach (E; EnumMembers!(IR)) {
        static if (!Eliminate.canFind(E) && E !is IR.TRUNC_SAT) {
            version (COMPACT_EXTENDED_IR) {
                codes ~= format!q{%s,}(E);
            }

            else {
                codes ~= format!q{%s = %d,}(E, E);
            }
        }
    }
    foreach (E; EnumMembers!(ExtraIR)) {
        version (COMPACT_EXTENDED_IR) {
            codes ~= format!q{%s,}(E);
        }
        else {
            codes ~= format!q{%s = %d,}(E, E);
        }
    }
    codes ~= `};`;
    return codes.join("\n");
}

// pragma(msg, generateInternalIR);
//pragma(msg, generateInternalIR!q{InternalIR});
mixin(generateInternalIR!q{InternalIR});

pragma(msg, [EnumMembers!InternalIR]);

version (COMPACT_EXTENDED_IR) {
    protected ubyte[ubyte.max + 1] generateInternalIRToIR() {
        ubyte[ubyte.max + 1] table = ubyte.max;

        foreach (i, E; [EnumMembers!(WasmBase.IR)]) {
            table[i] = cast(ubyte) E;
        }
        return table;
    }

    protected ubyte[ubyte.max + 1] generateIRToInternalIR() {
        ubyte[ubyte.max + 1] table = ubyte.max;

        foreach (i, E; [EnumMembers!(InternalIR)]) {
            table[i] = cast(ubyte) E;
        }
        return table;
    }

    enum InternalIRToIR = generateInternalIRToIR;
    enum IRToInternalIR = generateIRToInternalIR;
}

bool isPrefixIR(const InternalIR ir) pure nothrow @safe {
    return (ir >= InternalIR.I32_TRUNC_SAT_F32_S && ir <= InternalIR.I64_TRUNC_SAT_F64_U);
}

WasmBase.IR convert(const InternalIR ir) @safe pure nothrow {
    version (COMPACT_EXTENDED_IR) {
        if (isPrefixIR(ir)) {
            return cast(WasmBase.IR) ubyte.max;
        }
        return cast(WasmBase.IR) InternalIRToIR[ir];
    }
    else {
//        pragma(msg, "Array ", [EnumMembers!(InternalIR)]);
        switch (ir) {
            static foreach (E; EnumMembers!(InternalIR)) {
//                pragma(msg, "E ", E, " ", E.to!ubyte);
        case E:
            static if (isWasmIR!E) {
                return cast(WasmBase.IR) ir;
            }
            else {
                goto default;
            }
            }
        default:
            return cast(WasmBase.IR) ubyte.max;
        }
    }

}

@safe
static unittest {
    static assert(InternalIR.BR_IF.convert is WasmBase.IR.BR_IF);
    version(COMPACT_EXTENDED_IR) {
        pragma(msg, "COMPACT_EXTENDED_IR");
    }
    else {
        pragma(msg, "NOT!!! COMPACT_EXTENDED_IR");
    }
    pragma(msg, InternalIR.ERROR.convert);
    static assert(InternalIR.ERROR.convert is cast(WasmBase.IR) ubyte.max);
}

InternalIR convert(const WasmBase.IR ir) @safe pure nothrow {
    version (COMPACT_EXTENDED_IR) {
        if (ir is WasmBase.IR.TRUNC_SAT) {
            return InternalIR.ERROR; // TRUNC_SAT is a IR with prefix
        }
        else {
            return cast(InternalIR) IRToInternalIR[ir];
        }
    }
    else {
        switch (ir) {
            static foreach (E; EnumMembers!(ExtraIR)) {
        case E:
                return cast(InternalIR) ubyte.max;
            }
        default:
            return cast(InternalIR) ir;
        }
    }

}

InternalIR convert(const WasmBase.IR ir, const ubyte suffix_ir) @safe pure nothrow {
    if (ir is WasmBase.IR.TRUNC_SAT) {
        if (suffix_ir < EnumMembers!(WasmBase.IR_TRUNC_SAT).length) {
            return cast(InternalIR)(InternalIR.I32_TRUNC_SAT_F32_S + suffix_ir);
        }
        return InternalIR.ERROR;
    }
    return convert(ir);
}

@safe unittest {
    assert(WasmBase.IR.BR_IF.convert is InternalIR.BR_IF);
    assert(cast(WasmBase.IR)(InternalIR.ERROR).convert is cast(InternalIR)(ubyte.max));
}

alias isWasmIR(InternalIR ir) = hasMember!(WasmBase.IR, basename!(ir));

static unittest {
    static assert(isWasmIR!(InternalIR.BR_IF));
    static assert(!isWasmIR!(InternalIR.ERROR));
}

shared static immutable(WasmBase.Instr[InternalIR]) instrExtTable;

shared static this() {
    foreach (ExtIR; EnumMembers!InternalIR) {
        auto instr = ExtIR.convert in WasmBase.instrTable;
        if (instr) {
            instrExtTable[ExtIR] = *instr;
        }
    }
}
