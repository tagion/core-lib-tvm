module tagion.tvm.wamr.TVMExtOpcode;

import WasmBase=tagion.wasm.WasmBase;
import std.algorithm.searching : canFind;


protected {
    enum ExtraIR : ubyte {
        ERROR                = EnumMembers!(WasmBase.IR).length, /// Extra jump label to handle errors
            EXT_BR, /// This branch jump is used internal buy the interpreter
            UNDEFINED,
            }
}

protected string generateExtendedIR(string enum_name)() {
    string[] codes;
    codes~=format!`enum %s : ubyte {`(enum_name);
    with(WasmBase) {
        enum Eliminate = [NOP, IF, ELSE, BLOCK, END, LOOP];
    }
    foreach(E; EnumMembers!(WasmBase.IR)) {
        static if (!Eliminate.canFind(E)) {
            version(COMPACT_EXTENDED_IR) {
                codes~=format!q{%s,}(E);
            }
            else {
                codes~=format!q{%s = %02X,}(E, E);
            }
        }
    }
    foreach(E; EnumMembers!(ExtraIR)) {
        version(COMPACT_EXTENDED_IR) {
            codes~=format!q{%s,}(E);
        }
        else {
            codes~=format!q{%s = %02X,}(E, E);
        }
    }
    codes~=`};`;
    return codes.join("\n");
}

// pragma(msg, generateExtendedIR);
mixin(generateExtendedIR!q{ExtendedIR});

version(COMPACT_EXTENDED_IR) {
protected ubyte[ubyte.sizeof+1] generateExtendedIRToIR() {
    ubyte[ubyte.max+1] table = ubyte.max;

    foreach(i, E; EnumMembers!(WasmBase.IR).enumerate) {
        table[i] = cast(ubyte)E;
    }
    return table;
}
enum ExtendedIRToIR= ExtendedIRToIR;
}

WasmBase.IR convert(const ExtendedIR ir) pure nothrow {
    version(COMPACT_EXTENDED_IR) {
        return cast(IR)ExtendedIRToIR[ir];
    }
    else {
        switch(ir) {
            static foreach(E; EnumMembers!(ExtraIR)) {
            case E:
                return cast(IR)ubyte.max;
            default:
                return cast(IR)ir;
            }
        }
    }

}


alias isWasmIR(ExtendedIR ir) = hasMember!(WasmBase.IR, ir.stringof);

static unittest {
    static assert(isWasmIR!(ExtendedIR.IF));
    static assert(!isWasmIR!(ExtendedIR.ERROR));
}

shared static immutable(WasmBase.Instr[ExtendedIR]) instrExtTable;

shared static this()
{
    foreach(ExtIR; EnumMembers!ExtendedIR) {
        auto instr = ExtIR.convert in WasmBase.instrTable;
        if (instr) {
            instrExtTable[ExtIR] = *instr;
        }
    }
}
