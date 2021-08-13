/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.libc_builtin_wrapper;

import tagion.tvm.wamr.bh_common;
import tagion.tvm.wamr.bh_log;
import tagion.tvm.wamr.wasm_export;
import tagion.tvm.wamr.lib_export;
import tagion.tvm.wamr.wasm;

// void
// wasm_runtime_set_exception(wasm_module_inst_t module, const char *exception);

// uint
// wasm_runtime_get_temp_ret(wasm_module_inst_t module);

// void
// wasm_runtime_set_temp_ret(wasm_module_inst_t module, uint temp_ret);

// uint
// wasm_runtime_get_llvm_stack(wasm_module_inst_t module);

// void
// wasm_runtime_set_llvm_stack(wasm_module_inst_t module, uint llvm_stack);

alias get_module_inst(exec_env) = wasm_runtime_get_module_inst(exec_env);

alias validate_app_addr(offset, size) = wasm_runtime_validate_app_addr(module_inst, offset, size);

    alias validate_app_str_addr(offset) = wasm_runtime_validate_app_str_addr(module_inst, offset);

alias validate_native_addr(addr, size) = wasm_runtime_validate_native_addr(module_inst, addr, size);

alias addr_app_to_native(offset) = wasm_runtime_addr_app_to_native(module_inst, offset);

alias addr_native_to_app(ptr) = wasm_runtime_addr_native_to_app(module_inst, ptr);

alias module_malloc(size, p_native_addr) = wasm_runtime_module_malloc(module_inst, size, p_native_addr);

alias module_free(offset) = wasm_runtime_module_free(module_inst, offset);

alias out_func_t = int function(int c, void *ctx);

enum pad_type {
    PAD_NONE,
    PAD_ZERO_BEFORE,
    PAD_SPACE_BEFORE,
    PAD_SPACE_AFTER,
}

alias _va_list = char*;

enum _INTSIZEOF(T) = ((T.sizeof +  T(3)) & ~T(3));


T _va_arg(T, AP)(AP ap) {
    return (*cast(T*)((ap += _INTSIZEOF!T) - _INTSIZEOF!T));
}

bool CHECK_VA_ARG(T, AP)(AP ap) {
    return (cast(uint8*)ap + _INTSIZEOF!T > native_end_addr);
    //     goto fail;
    // }
}

/**
 * @brief Output an unsigned int in hex format
 *
 * Output an unsigned int on output installed by platform at init time. Should
 * be able to handle an unsigned int of any size, 32 or 64 bit.
 * @param num Number to output
 *
 * @return N/A
 */
static void
_printf_hex_uint(out_func_t _out, void* ctx,
                 const ulong num, bool is_u64,
                 pad_type padding,
                 int min_width)
{
    int shift = num.sizeof * 8;
    int found_largest_digit = 0;
    int remaining = 16; /* 16 digits max */
    int digits = 0;
    char nibble;

     while (shift >= 4) {
         shift -= 4;
         nibble = (num >> shift) & 0xf;

        if (nibble || found_largest_digit || shift == 0) {
            found_largest_digit = 1;
            nibble = cast(char)(nibble + (nibble > 9 ? 87 : 48));
            _out(cast(int) nibble, ctx);
            digits++;
            continue;
        }

        if (remaining-- <= min_width) {
            if (padding == PAD_ZERO_BEFORE) {
                _out('0', ctx);
            }
            else if (padding == PAD_SPACE_BEFORE) {
                _out(' ', ctx);
            }
        }
    }

    if (padding == PAD_SPACE_AFTER) {
        remaining = min_width * 2 - digits;
        while (remaining-- > 0) {
            _out(' ', ctx);
        }
    }
}

/**
 * @brief Output an unsigned int in decimal format
 *
 * Output an unsigned int on output installed by platform at init time. Only
 * works with 32-bit values.
 * @param num Number to output
 *
 * @return N/A
 */
static void
_printf_dec_uint(out_func_t _out, void *ctx,
                 const uint num,
                 pad_type padding,
                 int min_width)
{
    uint pos = 999999999;
    uint remainder = num;
    int found_largest_digit = 0;
    int remaining = 10; /* 10 digits max */
    int digits = 1;

    /* make sure we don't skip if value is zero */
    if (min_width <= 0) {
        min_width = 1;
    }

    while (pos >= 9) {
        if (found_largest_digit || remainder > pos) {
            found_largest_digit = 1;
            _out(cast(int) ((remainder / (pos + 1)) + 48), ctx);
            digits++;
        } else if (remaining <= min_width && padding < PAD_SPACE_AFTER) {
            _out(cast(int) (padding == PAD_ZERO_BEFORE ? '0' : ' '), ctx);
            digits++;
        }
        remaining--;
        remainder %= (pos + 1);
        pos /= 10;
    }
    _out(cast(int) (remainder + 48), ctx);

    if (padding == PAD_SPACE_AFTER) {
        remaining = min_width - digits;
        while (remaining-- > 0) {
            _out(' ', ctx);
        }
    }
}

static void
print_err(out_func_t _out, void *ctx)
{
    _out('E', ctx);
    _out('R', ctx);
    _out('R', ctx);
}

static bool
_vprintf_wa(out_func_t _out, void *ctx, const char *fmt, _va_list ap,
            wasm_module_inst_t module_inst)
{
    int might_format = 0; /* 1 if encountered a '%' */
    enum pad_type padding = PAD_NONE;
    int min_width = -1;
    int long_ctr = 0;
    uint8 *native_end_addr;

    if (!wasm_runtime_get_native_addr_range(module_inst, cast(uint8*)ap,
                                            NULL, &native_end_addr))
        goto fail;

    /* fmt has already been adjusted if needed */

    while (*fmt) {
        if (!might_format) {
            if (*fmt != '%') {
                _out(cast(int) *fmt, ctx);
            }
            else {
                might_format = 1;
                min_width = -1;
                padding = PAD_NONE;
                long_ctr = 0;
            }
        }
        else {
            switch (*fmt) {
            case '-':
                padding = PAD_SPACE_AFTER;
                goto still_might_format;

            case '0':
                if (min_width < 0 && padding == PAD_NONE) {
                    padding = PAD_ZERO_BEFORE;
                    goto still_might_format;
                }
                /* Fall through */
                static foreach(c; '1'..'9') {
                case c:
                    static if (c < '9') {
                        goto case;
                    }
                }
                if (min_width < 0) {
                    min_width = *fmt - '0';
                } else {
                    min_width = 10 * min_width + *fmt - '0';
                }

                if (padding == PAD_NONE) {
                    padding = PAD_SPACE_BEFORE;
                }
                goto still_might_format;

            case 'l':
                long_ctr++;
                /* Fall through */
            case 'z':
            case 'h':
                /* FIXME: do nothing for these modifiers */
                goto still_might_format;

            case 'd':
            case 'i': {
                int d;

                if (long_ctr < 2) {
                    if (CHECK_VA_ARG!int(ap)) goto fail;
                    d = _va_arg!int(ap);
                }
                else {
                    int64 lld;
                    if (CHECK_VA_ARG!int64(ap)) goto fail;
                    lld = _va_arg(ap, int64);
                    if (lld > INT_MAX || lld < INT_MIN) {
                        print_err(_out, ctx);
                        break;
                    }
                    d = cast(int)lld;
                }

                if (d < 0) {
                    _out(cast(int)'-', ctx);
                    d = -d;
                    min_width--;
                }
                _printf_dec_uint(_out, ctx, cast(uint)d, padding, min_width);
                break;
            }
            case 'u': {
                uint u;

                if (long_ctr < 2) {
                    if (CHECK_VA_ARG!uint(ap)) goto fail;
                    u = _va_arg!uint(ap);
                }
                else {
                    uint64 llu;
                    if (CHECK_VA_ARG!uint64(ap)) goto fail;
                    llu = _va_arg(ap, uint64);
                    if (llu > INT_MAX) {
                        print_err(_out, ctx);
                        break;
                    }
                    u = cast(uint)llu;
                }
                _printf_dec_uint(_out, ctx, u, padding, min_width);
                break;
            }
            case 'p':
                _out('0', ctx);
                _out('x', ctx);
                /* left-pad pointers with zeros */
                padding = PAD_ZERO_BEFORE;
                min_width = 8;
                /* Fall through */
            case 'x':
            case 'X': {
                uint64 x;
                bool is_ptr = (*fmt == 'p') ? true : false;

                if (long_ctr < 2) {
                    if (CHECK_VA_ARG!uint(ap)) goto fail;
                    x = _va_arg!uint(ap);
                } else {
                    if (CHECK_VA_ARG!uint64(ap)) goto fail;
                    x = _va_arg!uint64(ap);
                }
                _printf_hex_uint(_out, ctx, x, !is_ptr, padding, min_width);
                break;
            }

            case 's': {
                char *s;
                char *start;
                int s_offset;

                if (CHECK_VA_ARG!int(ap)) goto fail;
                s_offset = _va_arg!int(ap);

                if (!validate_app_str_addr(s_offset)) {
                    return false;
                }

                s = start = addr_app_to_native(s_offset);

                while (*s)
                    _out(cast(int) (*s++), ctx);

                if (padding == PAD_SPACE_AFTER) {
                    int remaining = min_width - cast(int)(s - start);
                    while (remaining-- > 0) {
                        _out(' ', ctx);
                    }
                }
                break;
            }

            case 'c': {
                int c;
                if (CHECK_VA_ARG!int(ap)) goto fail;
                c = _va_arg!int(ap);
                _out(c, ctx);
                break;
            }

            case '%': {
                _out(cast(int) '%', ctx);
                break;
            }

            default:
                _out(cast(int) '%', ctx);
                _out(cast(int) *fmt, ctx);
                break;
            }

            might_format = 0;
        }

still_might_format:
        ++fmt;
    }
    return true;

fail:
    wasm_runtime_set_exception(module_inst, "out of bounds memory access");
    return false;
}

struct str_context {
    char *str;
    uint max;
    uint count;
};

static int
sprintf_out(int c, str_context* ctx)
{
    if (!ctx.str || ctx.count >= ctx.max) {
        ctx.count++;
        return c;
    }

    if (ctx.count == ctx.max - 1) {
        ctx.str[ctx.count++] = '\0';
    } else {
        ctx.str[ctx.count++] = cast(char)c;
    }

    return c;
}

static int
printf_out(int c, str_context* ctx)
{
    os_printf("%c", c);
    ctx.count++;
    return c;
}

static int
printf_wrapper(wasm_exec_env_t exec_env,
               const char * format, _va_list va_args)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    str_context ctx; // = { NULL, 0, 0 };

    /* format has been checked by runtime */
    if (!validate_native_addr(va_args, int.sizeof)) {
        return 0;
    }

    if (!_vprintf_wa(cast(out_func_t)printf_out, &ctx, format, va_args, module_inst))
        return 0;

    return cast(int)ctx.count;
}

static int
sprintf_wrapper(wasm_exec_env_t exec_env,
                char *str, const char *format, _va_list va_args)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint8 *native_end_offset;
    str_context ctx;

    /* str and format have been checked by runtime */
    if (!validate_native_addr(va_args, uint.sizeof)) {
        return 0;
    }

    if (!wasm_runtime_get_native_addr_range(module_inst, cast(uint8*)str,
                                            NULL, &native_end_offset)) {
        wasm_runtime_set_exception(module_inst, "out of bounds memory access");
        return false;
    }

    ctx.str = str;
    ctx.max = cast(uint)(native_end_offset - cast(uint8*)str);
    ctx.count = 0;

    if (!_vprintf_wa(cast(out_func_t)sprintf_out, &ctx, format, va_args, module_inst))
        return 0;

    if (ctx.count < ctx.max) {
        str[ctx.count] = '\0';
    }

    return cast(int)ctx.count;
}

static int
snprintf_wrapper(wasm_exec_env_t exec_env, char *str, uint size,
                 const char *format, _va_list va_args)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    str_context ctx;

    /* str and format have been checked by runtime */
    if (!validate_native_addr(va_args, uint.sizeof)) {
        return 0;
    }

    ctx.str = str;
    ctx.max = size;
    ctx.count = 0;

    if (!_vprintf_wa(cast(out_func_t)sprintf_out, &ctx, format, va_args, module_inst)) {
        return 0;
    }

    if (ctx.count < ctx.max) {
        str[ctx.count] = '\0';
    }

    return cast(int)ctx.count;
}

static int
puts_wrapper(wasm_exec_env_t exec_env, const char *str)
{
    return os_printf("%s\n", str);
}

static int
putchar_wrapper(wasm_exec_env_t exec_env, int c)
{
    os_printf("%c", c);
    return 1;
}

static int
strdup_wrapper(wasm_exec_env_t exec_env, const char *str)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char *str_ret;
    uint len;
    int str_ret_offset = 0;

    /* str has been checked by runtime */
    if (str) {
        len = cast(uint)strlen(str) + 1;

        str_ret_offset = module_malloc(len, cast(void**)&str_ret);
        if (str_ret_offset) {
            bh_memcpy_s(str_ret, len, str, len);
        }
    }

    return str_ret_offset;
}

static int
_strdup_wrapper(wasm_exec_env_t exec_env, const char *str)
{
    return strdup_wrapper(exec_env, str);
}

static int
memcmp_wrapper(wasm_exec_env_t exec_env,
               const void *s1, const void *s2, uint size)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    /* s2 has been checked by runtime */
    if (!validate_native_addr(cast(void*)s1, size))
        return 0;

    return memcmp(s1, s2, size);
}

static int
memcpy_wrapper(wasm_exec_env_t exec_env,
               void *dst, const void *src, uint size)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    int dst_offset = addr_native_to_app(dst);

    if (size == 0)
        return dst_offset;

    /* src has been checked by runtime */
    if (!validate_native_addr(dst, size))
        return dst_offset;

    bh_memcpy_s(dst, size, src, size);
    return dst_offset;
}

static int
memmove_wrapper(wasm_exec_env_t exec_env,
                void *dst, void *src, uint size)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    int dst_offset = addr_native_to_app(dst);

    if (size == 0)
        return dst_offset;

    /* src has been checked by runtime */
    if (!validate_native_addr(dst, size))
        return dst_offset;

    memmove(dst, src, size);
    return dst_offset;
}

static int
memset_wrapper(wasm_exec_env_t exec_env,
               void *s, int c, uint size)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    int s_offset = addr_native_to_app(s);

    if (!validate_native_addr(s, size))
        return s_offset;

    memset(s, c, size);
    return s_offset;
}

static int
strchr_wrapper(wasm_exec_env_t exec_env,
               const char *s, int c)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char *ret;

    /* s has been checked by runtime */
    ret = strchr(s, c);
    return ret ? addr_native_to_app(ret) : 0;
}

static int
strcmp_wrapper(wasm_exec_env_t exec_env,
               const char *s1, const char *s2)
{
    /* s1 and s2 have been checked by runtime */
    return strcmp(s1, s2);
}

static int
strncmp_wrapper(wasm_exec_env_t exec_env,
                const char *s1, const char *s2, uint size)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    /* s2 has been checked by runtime */
    if (!validate_native_addr(cast(void*)s1, size))
        return 0;

    return strncmp(s1, s2, size);
}

static int
strcpy_wrapper(wasm_exec_env_t exec_env, char *dst, const char *src)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint len = strlen(src) + 1;

    /* src has been checked by runtime */
    if (!validate_native_addr(dst, len))
        return 0;

    strncpy(dst, src, len);
    return addr_native_to_app(dst);
}

static int
strncpy_wrapper(wasm_exec_env_t exec_env,
                char *dst, const char *src, uint size)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    /* src has been checked by runtime */
    if (!validate_native_addr(dst, size))
        return 0;

    strncpy(dst, src, size);
    return addr_native_to_app(dst);
}

static uint
strlen_wrapper(wasm_exec_env_t exec_env, const char* s)
{
    /* s has been checked by runtime */
    return cast(uint)strlen(s);
}

static int
malloc_wrapper(wasm_exec_env_t exec_env, uint size)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    return module_malloc(size, NULL);
}

static int
calloc_wrapper(wasm_exec_env_t exec_env, uint nmemb, uint size)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint64 total_size = cast(uint64) nmemb * cast(uint64) size;
    int ret_offset = 0;
    uint8 *ret_ptr;

    if (total_size >= UINT_MAX)
        return 0;

    ret_offset = module_malloc(cast(uint)total_size, cast(void**)&ret_ptr);
    if (ret_offset) {
        memset(ret_ptr, 0, cast(uint) total_size);
    }

    return ret_offset;
}

static void
free_wrapper(wasm_exec_env_t exec_env, void *ptr)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    if (!validate_native_addr(ptr, uint.sizeof))
        return;

    return module_free(addr_native_to_app(ptr));
}

static int
atoi_wrapper(wasm_exec_env_t exec_env, const char *s)
{
    /* s has been checked by runtime */
    return atoi(s);
}

static void
exit_wrapper(wasm_exec_env_t exec_env, int status)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char[32] buf;
    snprintf(buf, buf.length, "env.exit(%i)", status);
    wasm_runtime_set_exception(module_inst, buf);
}

static int
strtol_wrapper(wasm_exec_env_t exec_env,
               const char *nptr, char **endptr, int base)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    int num = 0;

    /* nptr has been checked by runtime */
    if (!validate_native_addr(endptr, uint.sizeof)) {
        return 0;
    }

    num = cast(int)strtol(nptr, endptr, base);
    *cast(int*)endptr = addr_native_to_app(*endptr);

    return num;
}

static uint
strtoul_wrapper(wasm_exec_env_t exec_env,
                const char *nptr, char **endptr, int base)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint num = 0;

    /* nptr has been checked by runtime */
    if (!validate_native_addr(endptr, uint.sizeof)) {
        return 0;
    }

    num = cast(uint)strtoul(nptr, endptr, base);
    *cast(int*)endptr = addr_native_to_app(*endptr);

    return num;
}

static int
memchr_wrapper(wasm_exec_env_t exec_env,
               const void *s, int c, uint n)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    void *res;

    if (!validate_native_addr(cast(void*)s, n))
        return 0;

    res = memchr(s, c, n);
    return addr_native_to_app(res);
}

static int
strncasecmp_wrapper(wasm_exec_env_t exec_env,
                    const char *s1, const char *s2, int n)
{
    /* s1 and s2 have been checked by runtime */
    return strncasecmp(s1, s2, n);
}

static uint
strspn_wrapper(wasm_exec_env_t exec_env,
               const char *s, const char *accept)
{
    /* s and accept have been checked by runtime */
    return cast(uint)strspn(s, accept);
}

static uint
strcspn_wrapper(wasm_exec_env_t exec_env,
                const char *s, const char *reject)
{
    /* s and reject have been checked by runtime */
    return cast(uint)strcspn(s, reject);
}

static int
strstr_wrapper(wasm_exec_env_t exec_env,
               const char *s, const char *find)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    /* s and find have been checked by runtime */
    char *res = strstr(s, find);
    return addr_native_to_app(res);
}

static int
isupper_wrapper(wasm_exec_env_t exec_env, int c)
{
    return isupper(c);
}

static int
isalpha_wrapper(wasm_exec_env_t exec_env, int c)
{
    return isalpha(c);
}

static int
isspace_wrapper(wasm_exec_env_t exec_env, int c)
{
    return isspace(c);
}

static int
isgraph_wrapper(wasm_exec_env_t exec_env, int c)
{
    return isgraph(c);
}

static int
isprint_wrapper(wasm_exec_env_t exec_env, int c)
{
    return isprint(c);
}

static int
isdigit_wrapper(wasm_exec_env_t exec_env, int c)
{
    return isdigit(c);
}

static int
isxdigit_wrapper(wasm_exec_env_t exec_env, int c)
{
    return isxdigit(c);
}

static int
tolower_wrapper(wasm_exec_env_t exec_env, int c)
{
    return tolower(c);
}

static int
toupper_wrapper(wasm_exec_env_t exec_env, int c)
{
    return toupper(c);
}

static int
isalnum_wrapper(wasm_exec_env_t exec_env, int c)
{
    return isalnum(c);
}

static void
setTempRet0_wrapper(wasm_exec_env_t exec_env, uint temp_ret)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    wasm_runtime_set_temp_ret(module_inst, temp_ret);
}

static uint
getTempRet0_wrapper(wasm_exec_env_t exec_env)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    return wasm_runtime_get_temp_ret(module_inst);
}

static uint
llvm_bswap_i16_wrapper(wasm_exec_env_t exec_env, uint data)
{
    return (data & 0xFFFF0000)
           | ((data & 0xFF) << 8)
           | ((data & 0xFF00) >> 8);
}

static uint
llvm_bswap_i32_wrapper(wasm_exec_env_t exec_env, uint data)
{
    return ((data & 0xFF) << 24)
           | ((data & 0xFF00) << 8)
           | ((data & 0xFF0000) >> 8)
           | ((data & 0xFF000000) >> 24);
}

static uint
bitshift64Lshr_wrapper(wasm_exec_env_t exec_env,
                       uint uint64_part0, uint uint64_part1,
                       uint bits)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    union {
        uint64 value;
        uint[2] parts;
    } u;

    u.parts[0] = uint64_part0;
    u.parts[1] = uint64_part1;

    u.value >>= bits;
    /* return low 32bit and save high 32bit to temp ret */
    wasm_runtime_set_temp_ret(module_inst, cast(uint) (u.value >> 32));
    return cast(uint) u.value;
}

static uint
bitshift64Shl_wrapper(wasm_exec_env_t exec_env,
                      uint int64_part0, uint int64_part1,
                      uint bits)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    union {
        int64 value;
        uint[2] parts;
    } u;

    u.parts[0] = int64_part0;
    u.parts[1] = int64_part1;

    u.value <<= bits;
    /* return low 32bit and save high 32bit to temp ret */
    wasm_runtime_set_temp_ret(module_inst, cast(uint) (u.value >> 32));
    return cast(uint) u.value;
}

static void
llvm_stackrestore_wrapper(wasm_exec_env_t exec_env, uint llvm_stack)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    os_printf("_llvm_stackrestore called!\n");
    wasm_runtime_set_llvm_stack(module_inst, llvm_stack);
}

static uint
llvm_stacksave_wrapper(wasm_exec_env_t exec_env)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    os_printf("_llvm_stacksave called!\n");
    return wasm_runtime_get_llvm_stack(module_inst);
}

static int
emscripten_memcpy_big_wrapper(wasm_exec_env_t exec_env,
                              void *dst, const void *src, uint size)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    int dst_offset = addr_native_to_app(dst);

    /* src has been checked by runtime */
    if (!validate_native_addr(dst, size))
        return dst_offset;

    bh_memcpy_s(dst, size, src, size);
    return dst_offset;
}

static void
abort_wrapper(wasm_exec_env_t exec_env, int code)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char[32] buf;
    snprintf(buf, buf.length, "env.abort(%i)", code);
    wasm_runtime_set_exception(module_inst, buf);
}

static void
abortStackOverflow_wrapper(wasm_exec_env_t exec_env, int code)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char[32] buf;
    snprintf(buf, sizeof(buf), "env.abortStackOverflow(%i)", code);
    wasm_runtime_set_exception(module_inst, buf);
}

static void
nullFunc_X_wrapper(wasm_exec_env_t exec_env, int code)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char[32] buf;
    snprintf(buf, buf.length, "env.nullFunc_X(%i)", code);
    wasm_runtime_set_exception(module_inst, buf);
}

static int
__cxa_allocate_exception_wrapper(wasm_exec_env_t exec_env,
                                 uint thrown_size)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    int exception = module_malloc(thrown_size, NULL);
    if (!exception)
        return 0;

    return exception;
}

static void
__cxa_begin_catch_wrapper(wasm_exec_env_t exec_env,
                          void *exception_object)
{
}

static void
__cxa_throw_wrapper(wasm_exec_env_t exec_env,
                    void *thrown_exception,
                    void *tinfo,
                    uint table_elem_idx)
{
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char[32] buf;

    snprintf(buf, buf.length, "%s", "exception thrown by stdc++");
    wasm_runtime_set_exception(module_inst, buf);
}

version(WASM_ENABLE_SPEC_TEST) {
static void
print_wrapper(wasm_exec_env_t exec_env)
{
    os_printf("in specttest.print()\n");

}

static void
print_i32_wrapper(wasm_exec_env_t exec_env, int i32)
{
    os_printf("in specttest.print_i32(%d)\n", i32);
}

static void
print_i32_f32_wrapper(wasm_exec_env_t exec_env, int i32, float f32)
{
    os_printf("in specttest.print_i32_f32(%d, %f)\n", i32, f32);
}

static void
print_f64_f64_wrapper(wasm_exec_env_t exec_env, double f64_1, double f64_2)
{
    os_printf("in specttest.print_f64_f64(%f, %f)\n", f64_1, f64_2);
}

static void
print_f32_wrapper(wasm_exec_env_t exec_env, float f32)
{
    os_printf("in specttest.print_f32(%f)\n", f32);
}

static void
print_f64_wrapper(wasm_exec_env_t exec_env, double f64)
{
    os_printf("in specttest.print_f64(%f)\n", f64);
}
}

NativeSymbol test(string native_func, string signature) {
    import std.format;
    auto z=&printf_wrapper;
    pragma(msg, typeof(z));
    return cast(void*)z;
}


NativeSymbol REG_NATIVE_FUNC(string native_func, string signature) {
    import std.format;
    //  pragma(msg, "REG_NATIVE_FUNC ",native_func.mangleof);
    //enum code=format!("auto func = &%s_wrapper;")(native_func.mangleof);

//    pragma(msg, typeof(printf_wrapper));
    auto z=&printf_wrapper;
//    pragma(msg, code);
    // mixin(code);
    // const y=func;

//    pragma(msg, func);
    // const x=NativeSymbol(native_func.mangleof.ptr, func, signature.ptr);
    return NativeSymbol(native_func.ptr, null, signature.ptr);
}

import core.stdc.stdio;
import core.stdc.string;
// enum x=strncmp.mangleof;
// pragma(msg, strncmp.mangleof);
NativeSymbol[] native_symbols_libc_builtin = [

//    REG_NATIVE_FUNC(printf.mangleof, "($*)i"),
//    REG_NATIVE_FUNC!(sprintf, "($$*)i")(),
    /+
    REG_NATIVE_FUNC(snprintf.mangleof, "(*~$*)i"),
    REG_NATIVE_FUNC(puts.mangleof, "($)i"),
    REG_NATIVE_FUNC(putchar.mangleof, "(i)i"),
    REG_NATIVE_FUNC(memcmp.mangleof, "(**~)i"),
    REG_NATIVE_FUNC(memcpy.mangleof, "(**~)i"),
    REG_NATIVE_FUNC(memmove.mangleof, "(**~)i"),
    REG_NATIVE_FUNC(memset.mangleof, "(*ii)i"),
    REG_NATIVE_FUNC(strchr.mangleof, "($i)i"),
    REG_NATIVE_FUNC(strcmp.mangleof, "($$)i"),
    REG_NATIVE_FUNC(strcpy.mangleof, "(*$)i"),
    REG_NATIVE_FUNC(strlen.mangleof, "($)i"),
    REG_NATIVE_FUNC(strncmp.mangleof, "(**~)i"),
    REG_NATIVE_FUNC(strncpy.mangleof, "(**~)i"),
    REG_NATIVE_FUNC(malloc.mangleof, "(i)i"),
    REG_NATIVE_FUNC(calloc.mangleof, "(ii)i"),
    REG_NATIVE_FUNC(strdup.mangleof, "($)i"),
    /* clang may introduce __strdup */
    REG_NATIVE_FUNC(_strdup.mangleof, "($)i"),
    REG_NATIVE_FUNC(free.mangleof, "(*)"),
    REG_NATIVE_FUNC(atoi.mangleof, "($)i"),
    REG_NATIVE_FUNC(exit.mangleof, "(i)"),
    REG_NATIVE_FUNC(strtol.mangleof, "($*i)i"),
    REG_NATIVE_FUNC(strtoul.mangleof, "($*i)i"),
    REG_NATIVE_FUNC(memchr.mangleof, "(*ii)i"),
    REG_NATIVE_FUNC(strncasecmp.mangleof, "($$i)"),
    REG_NATIVE_FUNC(strspn.mangleof, "($$)i"),
    REG_NATIVE_FUNC(strcspn.mangleof, "($$)i"),
    REG_NATIVE_FUNC(strstr.mangleof, "($$)i"),
    REG_NATIVE_FUNC(isupper.mangleof, "(i)i"),
    REG_NATIVE_FUNC(isalpha.mangleof, "(i)i"),
    REG_NATIVE_FUNC(isspace.mangleof, "(i)i"),
    REG_NATIVE_FUNC(isgraph.mangleof, "(i)i"),
    REG_NATIVE_FUNC(isprint.mangleof, "(i)i"),
    REG_NATIVE_FUNC(isdigit.mangleof, "(i)i"),
    REG_NATIVE_FUNC(isxdigit.mangleof, "(i)i"),
    REG_NATIVE_FUNC(tolower.mangleof, "(i)i"),
    REG_NATIVE_FUNC(toupper.mangleof, "(i)i"),
    REG_NATIVE_FUNC(isalnum.mangleof, "(i)i"),
    REG_NATIVE_FUNC(setTempRet0.mangleof, "(i)"),
    REG_NATIVE_FUNC(getTempRet0.mangleof, "()i"),
    REG_NATIVE_FUNC(llvm_bswap_i16.mangleof, "(i)i"),
    REG_NATIVE_FUNC(llvm_bswap_i32.mangleof, "(i)i"),
    REG_NATIVE_FUNC(bitshift64Lshr.mangleof, "(iii)i"),
    REG_NATIVE_FUNC(bitshift64Shl.mangleof, "(iii)i"),
    REG_NATIVE_FUNC(llvm_stackrestore.mangleof, "(i)"),
    REG_NATIVE_FUNC(llvm_stacksave.mangleof, "()i"),
    REG_NATIVE_FUNC(emscripten_memcpy_big.mangleof, "(**~)i"),
    REG_NATIVE_FUNC(abort.mangleof, "(i)"),
    REG_NATIVE_FUNC(abortStackOverflow.mangleof, "(i)"),
    REG_NATIVE_FUNC(nullFunc_X.mangleof, "(i)"),
    REG_NATIVE_FUNC(__cxa_allocate_exception.mangleof, "(i)i"),
    REG_NATIVE_FUNC(__cxa_begin_catch.mangleof, "(*)"),
    REG_NATIVE_FUNC(__cxa_throw.mangleof, "(**i)")
+/
    ];

version(WASM_ENABLE_SPEC_TEST) {
static NativeSymbol[] native_symbols_spectest = [
    REG_NATIVE_FUNC(print, "()"),
    REG_NATIVE_FUNC(print_i32, "(i)"),
    REG_NATIVE_FUNC(print_i32_f32, "(if)"),
    REG_NATIVE_FUNC(print_f64_f64, "(FF)"),
    REG_NATIVE_FUNC(print_f32, "(f)"),
    REG_NATIVE_FUNC(print_f64, "(F)")
];
}

uint
get_libc_builtin_export_apis(NativeSymbol **p_libc_builtin_apis)
{
    *p_libc_builtin_apis = native_symbols_libc_builtin;
    return sizeof(native_symbols_libc_builtin) / sizeof(NativeSymbol);
}

version(WASM_ENABLE_SPEC_TEST) {
uint
get_spectest_export_apis(NativeSymbol **p_libc_builtin_apis)
{
    *p_libc_builtin_apis = native_symbols_spectest;
    return sizeof(native_symbols_spectest) / sizeof(NativeSymbol);
}
}

/*************************************
 * Global Variables                  *
 *************************************/

struct WASMNativeGlobalDef {
    const char* module_name;
    const char* global_name;
    WASMValue global_data;
}

static WASMNativeGlobalDef[] native_global_defs = [
    {"spectest",  "global_i32", global_data : {i32 : 666} },
    {"spectest", "global_f32", global_data : {f32 : 666.6} },
    {"spectest", "global_f64", global_data : {f64 : 666.6} },
    {"test", "global-i32", global_data : {i32 : 0} },
    {"test", "global-f32", global_data : {f32 : 0} },
    {"env", "STACKTOP", global_data : {u32 : 0} },
    {"env", "STACK_MAX", global_data : {u32 : 0} },
    {"env", "ABORT", global_data : {u32 : 0} },
    {"env", "memoryBase", global_data : {u32 : 0} },
    {"env", "__memory_base", global_data : {u32 : 0} },
    {"env", "tableBase", global_data : {u32 : 0} },
    {"env", "__table_base", global_data : {u32 : 0} },
    {"env", "DYNAMICTOP_PTR", global_data : {addr : 0} },
    {"env", "tempDoublePtr", global_data : {addr : 0} },
    {"global", "NaN", global_data : {u64 : 0x7FF8000000000000UL} },
    {"global", "Infinity", global_data : {u64 : 0x7FF0000000000000UL} }
    ];

bool
wasm_native_lookup_libc_builtin_global(const char *module_name,
                                       const char *global_name,
                                       WASMGlobalImport *global)
{
    uint size = sizeof(native_global_defs) / sizeof(WASMNativeGlobalDef);
    WASMNativeGlobalDef *global_def = native_global_defs;
    WASMNativeGlobalDef *global_def_end = global_def + size;

    if (!module_name || !global_name || !global)
        return false;

    /* Lookup constant globals which can be defined by table */
    while (global_def < global_def_end) {
        if (!strcmp(global_def.module_name, module_name)
            && !strcmp(global_def.global_name, global_name)) {
            global.global_data_linked = global_def.global_data;
            return true;
        }
        global_def++;
    }

    return false;
}
