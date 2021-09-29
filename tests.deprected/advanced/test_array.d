module advanced.test_array;

extern(C):
@nogc:


int result;
//import core.stdc.stdio : printf;

int char_array(char[] str) {
    enum Hello="Hello";
    str[0..Hello.length]=Hello;
    result=cast(int)str.length;
    return cast(int)str.length;
}

int ref_char_array(ref char[] str) {
    return cast(int)(str.length);
}

int const_char_array(const(char[]) str) {
    result=cast(int)str.length;
    return cast(int)(str.length);
}


int get_result(int x) {
    return result;
}

void _start() {}
