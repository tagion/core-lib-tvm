#!/usr/bin/rdmd -g
module wasm2data;

import std.getopt;
import std.stdio;
import std.file : fread = read;
import std.range : iota;
import std.algorithm.comparison : min;
import std.algorithm.iteration : each;
import std.format;
import std.array : join;
import std.path : baseName, stripExtension;

void write_buffer(ref File fout, string data_name, immutable(ubyte[]) data) {
    fout.writefln("immutable(ubyte[]) %s = [", data_name);
    enum line_size = 16;
    foreach(p; iota(0, data.length, line_size)) {
        const actual_line_size = min(line_size, data.length-p);
        immutable(ubyte)[] line_data = data[p..p+actual_line_size];

        line_data.each!((a) => fout.writef("0x%02X, ", a));
        fout.writeln;
    }
    fout.writefln("];");
}

int main(string[] args) {
    immutable program=args[0];
    string module_name = "tests.wasm_sample";
    string output_name = "tests/wasm_sample.d";
    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "module|m", format("Module name %s", module_name), &module_name,
        "output|o", format("Module file name %s", output_name), &output_name

/+
        "version",   "display the version",     &version_switch,
        "gitlog:g", format("Git log file %s", git_log_json_file), &git_log_json_file,
        "repo|r", format("Git repo %s", git_repo), &git_repo,
        "date|d", format("Recorde the date in the checkout default %s", set_date), &set_date
+/
        );

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
            [
                format("%s", program),
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>] wasm_files...", program),

                    "<option>:",

                    ].join("\n"),
                main_args.options);
            return 0;
        }

    auto fout=File(output_name, "w");
    scope(exit) {
        fout.close;
    }
    writefln("args = %s", args);

    fout.writefln("module %s;", module_name);
    foreach(file; args[1..$]) {
        fout.writeln;
        fout.writeln("//");
        fout.writefln("// %s", file);
        fout.writeln("//");
        immutable data=cast(immutable(ubyte[]))file.fread;

        write_buffer(fout, file.baseName.stripExtension, data);

    }
    return 0;
}
