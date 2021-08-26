module tagion.tvm.wamr.TVMExtOpcode;

import WasmBase = tagion.wasm.WasmBase;
import std.algorithm.searching : canFind;
import std.format;
import std.array : join;
import std.traits : EnumMembers;

protected {
    enum ExtraIR : ubyte {
        ERROR = WasmBase.IR.F64_REINTERPRET_I64 + 1, /// Extra jump label to handle errors
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

protected string generateExtendedIR(string enum_name)() {
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

// pragma(msg, generateExtendedIR);
//pragma(msg, generateExtendedIR!q{ExtendedIR});
mixin(generateExtendedIR!q{ExtendedIR});

version (COMPACT_EXTENDED_IR) {
    protected ubyte[ubyte.max + 1] generateExtendedIRToIR() {
        ubyte[ubyte.max + 1] table = ubyte.max;

        foreach (i, E; [EnumMembers!(WasmBase.IR)]) {
            table[i] = cast(ubyte) E;
        }
        return table;
    }

    protected ubyte[ubyte.max + 1] generateIRToExtendedIR() {
        ubyte[ubyte.max + 1] table = ubyte.max;

        foreach (i, E; [EnumMembers!(ExtendedIR)]) {
            table[i] = cast(ubyte) E;
        }
        return table;
    }

    enum ExtendedIRToIR = generateExtendedIRToIR;
    enum IRToExtendedIR = generateIRToExtendedIR;
}

bool isPrefixIR(const ExtendedIR ir) pure nothrow @safe {
    return (ir >= ExtendedIR.I32_TRUNC_SAT_F32_S && ir <= ExtendedIR.I64_TRUNC_SAT_F64_U);
}

WasmBase.IR convert(const ExtendedIR ir) @safe pure nothrow {
    version (COMPACT_EXTENDED_IR) {
        if (isPrefixIR(ir)) {
            return cast(WasmBase.IR) ubyte.max;
        }
        return cast(WasmBase.IR) ExtendedIRToIR[ir];
    }
    else {
        switch (ir) {
            static foreach (E; EnumMembers!(ExtendedIR)) {
        case E:
                return cast(WasmBase.IR) ir;
            }
        default:
            return cast(WasmBase.IR) ubyte.max;
        }
    }

}

@safe unittest {
    assert(Extended.IF.convert is WasmBase.IR.IF);
    assert(Extended.ERROR is cast(WasmBase.IR) ubyte.max);
}

ExtendedIR convert(const WasmBase.IR ir) @safe pure nothrow {
    version (COMPACT_EXTENDED_IR) {
        if (ir is WasmBase.IR.TRUNC_SAT) {
            return ExtendedIR.ERROR; // TRUNC_SAT is a IR with prefix
        }
        else {
            return cast(ExtendedIR) IRToExtendedIR[ir];
        }
    }
    else {
        switch (ir) {
            static foreach (E; EnumMembers!(ExtraIR)) {
        case E:
                return cast(WasmBase.IR) ubyte.max;
            }
        default:
            return cast(WasmBase.IR) ir;
        }
    }

}

ExtendedIR convert(const WasmBase.IR ir, const ubyte suffix_ir) @safe pure nothrow {
    if (ir is WasmBase.IR.TRUNC_SAT) {
        if (suffix_ir < EnumMembers!(WasmBase.IR_TRUNC_SAT).length) {
            return cast(ExtendedIR)(ExtendedIR.I32_TRUNC_SAT_F32_S + suffix_ir);
        }
        return ExtendedIR.ERROR;
    }
    return convert(ir);
}

@safe unittest {
    assert(WasmBase.IR.IF.convert is ExtendedIR.IF);
    assert(cast(WasmBase.IR)(ExtendedIR.ERROR).convert is cast(ExtendedIR)(ubyte.max));
}

alias isWasmIR(ExtendedIR ir) = hasMember!(WasmBase.IR, ir.stringof);

static unittest {
    static assert(isWasmIR!(ExtendedIR.IF));
    static assert(!isWasmIR!(ExtendedIR.ERROR));
}

shared static immutable(WasmBase.Instr[ExtendedIR]) instrExtTable;

shared static this() {
    foreach (ExtIR; EnumMembers!ExtendedIR) {
        auto instr = ExtIR.convert in WasmBase.instrTable;
        if (instr) {
            instrExtTable[ExtIR] = *instr;
        }
    }
}
