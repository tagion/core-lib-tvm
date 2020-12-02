extern(C):

int negNum(int x);

int generate_crazy_int(int x) {
    return negNum(x);
}

void _start() {}
