#!/usr/bin/perl -i.bak
my %dtype = (
    "int8"  => "byte",
    "uint8"  => "ubyte",
    "int16"  => "short",
    "uint16"  => "ushort",
    "int32"  => "int",
    "int64" => "long",
    "uint32"  => "uint",
    "uint64"  => "ulong",
    "float32"  => "float",
    "float64"  => "double",
    );
while(<>) {
    s/(uint|int|float)(32|64|16|8)(\s|\*|\[|\))/$ctype="$1$2"; $newtype=$dtype{$ctype};  "$newtype$3"/eg;
    s/wasm_section_t_/wasm_section_t/g;
    print;
}
