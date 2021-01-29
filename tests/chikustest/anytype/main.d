module main;
import tagion.vm.wamr.c.wasm_export;
import tagion.vm.wamr.c.bh_read_file;
import tagion.vm.wamr.c.wasm_runtime;
import std.stdio;
import std.file;
import std.algorithm;
import std.format;
import std.string;
import std.getopt;
import std.bitmanip;



class WamrEngine {
    private {
        RuntimeInitArgs runtime_args;
        uint heap_size = 8092;
        uint stack_size = 8092;
        uint buf_size = 0;
        char [128]error_buf;
        uint[] global_heap_buf;
        string wasm_path;
        @nogc {
            wasm_module_t wasm_module;
            wasm_module_inst_t module_inst;
            wasm_exec_env_t exec_env;
        }
    }
    void initialize() {
        runtime_args.mem_alloc_type = mem_alloc_type_t.Alloc_With_Pool;
        runtime_args.mem_alloc_option.pool.heap_buf = global_heap_buf.ptr;
        runtime_args.mem_alloc_option.pool.heap_size = cast(uint)global_heap_buf.length;
        const runtime_init_success=wasm_runtime_full_init(&runtime_args);
        auto buffer = bh_read_file_to_buffer(wasm_path.ptr, &buf_size);
        if (buf_size is 0) {
            throw new Exception(format("Open wasm app file [%s] failed.", wasm_path));
        }
        wasm_module = wasm_runtime_load(cast(const(ubyte*))buffer, cast(uint)buf_size, error_buf.ptr, 128);
        if (!wasm_module) {
            throw new Exception(format("Load wasm module failed. error: %s", fromStringz(error_buf.ptr)));
        }
        module_inst = wasm_runtime_instantiate(wasm_module, stack_size, heap_size, error_buf.ptr, 128);
        if (!module_inst){
            throw new Exception(format("Instantiate wasm module failed. error: %s", fromStringz(error_buf.ptr)));
        }
        exec_env = wasm_runtime_create_exec_env(module_inst, stack_size);
        if (!exec_env) {
            throw new Exception("Create wasm execution environment failed.");
        }
    }
    int call_func(string name){
        //uint   num_args = 0, num_results = 0;
        uint arg = 0;
        auto xfunc = cast(void* function())wasm_runtime_lookup_function(module_inst, name.ptr, null);
        //wasm_val_t results = {0,{0}};
        //wasm_val_t argfs = {0,{0}};

        if (wasm_runtime_call_wasm(exec_env, xfunc, 0, &arg)) {
            writefln("Native finished calling wasm function generate_crazy_int(), returned a int value: %d", arg);
        } else {
            throw new Exception(format("call wasm function generate_crazy_int failed. %s", fromStringz(wasm_runtime_get_exception(module_inst))));
        }
        WASMModuleInstance* local_inst = cast(WASMModuleInstance*)module_inst;
        wasm_exec_env_t local_exec = exec_env;
        uint *get_mem = cast(uint*)local_exec;
        uint *invers = cast(uint*)local_inst;
        uint i;
        ubyte first = false;
        for(i = 0; i < 30000; i++){
            uint result_neg = *(invers+i);
            uint result_exe = *(get_mem+i);
            if(result_neg==5128){
                writefln("i found sin endiand %s",i);

                if(first){
                    //writefln("i found sin endiand %s",i);
            
                }
                if(!first){
                    first = true;
                }
               
            }
            if(result_exe==5128){
                writefln("i found in exe %s",i);
            }
            if(result_exe==47){
                writefln("i found in exe 47 %s",i);

            }
//i found sin endiand 5014
//i found sin endiand 5015
//i found sin endiand 5016
//i found sin endiand 5017
//i found sin endiand 5018
            

        //writefln("Printing result %s",*(data_ext-22));    
        }

                //writefln("vamos a ver %s", local_inst.memory_count);
        //auto fields = [ __traits(allMembers,local_inst.tupleof) ];
        foreach ( it; local_inst.tupleof)
        {
            writef("\n %s", it);
        }
        i=842;
        struct Scustom {
            int y;
            int x;
            double f;
        }
        uint size_s = Scustom.sizeof;
        uint addr = arg-size_s;
        Scustom *ret_s = cast(Scustom*)(local_inst+addr);
        writefln("\nimprimiendo resultado %s",ret_s.y);

        uint abe1 = *(get_mem+(i-3));
        uint abe2 = *(get_mem+(i-2));
        ulong value = abe2;
        value = value<<32;
        writefln("Print vale before %x",value);
        value = value | abe1;
        writefln("Print vale after %x",value);
        writefln("Print value %s",*(get_mem+i));
        writefln("Print abe1 %s",abe1);
        writefln("Print abe2 %s",abe2);
        writefln("Print dobule %f",cast(double)value);
        //wasm_runtime_call_wasm(this.exec_env, xfunc, num_results, &arg);
        //writefln("Printing result %s",*(data_ext-22));
        //WASMFunctionInstance *wasm_func = cast(WASMFunctionInstance*)xfunc;
        //wasm_interp_call_wasm(local_inst,exec_env,xfunc,arg,&arg);
        //wasm_call_function(exec_env, wasm_func,arg, &arg);
        //writefln("Return cell number %s",wasm_func.ret_cell_num);

        //writefln("Offsets cell number %s",*(wasm_func.local_offsets));

        //writefln("que fallo? structura %d",arg);


        //static inline void
        //wasm_exec_env_set_cur_frame(WASMExecEnv *exec_env,
                                    //struct WASMInterpFrame *frame)
        //{
            //exec_env->cur_frame = frame;
        //}


        //writefln("Hola me estas imprimiendo %s",local_inst.custom_data);


        //Scustom* custom_data = cast(Scustom*)&arg;
        //foreach ( it; local_inst.custom_data)
        //{
        //    writef("\n %s", it);
        //}

        //writefln("%s", wasm_runtime_get_custom_data(module_inst));
        //auto fields = __traits(allMembers, typeof(local_inst));
        //auto values = local_inst.tupleof;
        //foreach (index, value; values)
        //{
            //writef("\n%-15s %s", fields[index], value);
        //}
        //wasm_get_app_addr_range
        //wasm_runtime_get_custom_data
        //wasm_runtime_get_native_addr_range
        //wasm_runtime_call_wasm(exec_env, xfunc, 0, &arg);
        //wasm_application_execute_func
        //writefln("Print normal func %d",arg);
        //module_inst->export_functions[i].function;
        //WASMFunctionInstance *wasm_func = cast(WASMFunctionInstance*)xfunc;
        //auto type = wasm_func.u.func.func_type;
        //auto argc = wasm_func.param_cell_num;
        //auto cell_num = type.ret_cell_num;
        //wasm_interp_call_wasm
        //auto total_size = (uint).sizeof * cast(ulong)(cell_num > 2 ? cell_num : 2);
        //auto argv = runtime_malloc(cast(uint)total_size, exec_env.module_inst, null, 0);
        //auto ret_num = parse_uint32_array_to_results(type, type.ret_cell_num, argv, results);
        //writefln("Hola vamosa imprimeidno return %s",exec_env.module_inst);
        //parse_uint32_array_to_results(type, type.ret_cell_num, argv, results);
        return 0;
    }

    @trusted
    this (const uint heap=8092, const uint stack=8092, uint[] global_buf = null, string wasm=null){
        wasm_path = wasm;
        heap_size = heap;
        stack_size = stack;
        global_heap_buf = global_buf;
        initialize();
    }
    @trusted
    this (string wasm=null){
        global_heap_buf = new uint[512*1024];
        wasm_path = wasm;
        initialize();
    }
    @trusted
    this (){
        auto dFiles = dirEntries("", SpanMode.depth).filter!(f => f.name.endsWith(".wasm"));
        foreach (d; dFiles) {
            wasm_path = d.name;
        }         
        global_heap_buf = new uint[512*1024];
        initialize();
    }

    @trusted
    ~this() {
        if (exec_env) {
            wasm_runtime_destroy_exec_env(exec_env);
        }
        wasm_runtime_deinstantiate(module_inst);
        wasm_runtime_destroy();
    }
}
int main(string[] args) {
    //string wasm_path;
    //getopt(args, std.getopt.config.caseSensitive,
        //std.getopt.config.bundling,
        //std.getopt.config.required,
        //"inputfile|f|", "Path of wasm file", &wasm_path);
    //auto wasm_engine= new WamrEngine(wasm_path);
    auto wasm_engine= new WamrEngine("appwasm/testapp.wasm");
    auto was_module = wasm_engine.call_func("func1");
    return 0;
}