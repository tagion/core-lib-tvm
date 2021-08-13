/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/**
 * @file   bh_log.h
 * @date   Tue Nov  8 18:19:10 2011
 *
 * @brief This log system supports wrapping multiple outputs into one
 * log message.  This is useful for outputting variable-length logs
 * without additional memory overhead (the buffer for concatenating
 * the message), e.g. exception stack trace, which cannot be printed
 * by a single log calling without the help of an additional buffer.
 * Avoiding additional memory buffer is useful for resource-constraint
 * systems.  It can minimize the impact of log system on applications
 * and logs can be printed even when no enough memory is available.
 * Functions with prefix "_" are private functions.  Only macros that
 * are not start with "_" are exposed and can be used.
 */
module tagion.tvm.wamr.bh_log;

// #ifndef _BH_LOG_H
// #define _BH_LOG_H

// #include "bh_platform.h"

// #ifdef __cplusplus
// extern "C" {
// #endif

enum {
    BH_LOG_LEVEL_FATAL = 0,
    BH_LOG_LEVEL_ERROR = 1,
    BH_LOG_LEVEL_WARNING = 2,
    BH_LOG_LEVEL_DEBUG = 3,
    BH_LOG_LEVEL_VERBOSE = 4
}

// void
// bh_log_set_verbose_level(uint level);

// void
// bh_log(LogLevel log_level, const char *file, int line, const char *fmt, ...);

version(BH_DEBUG) {

    void LOG_FATAL(Args...)(Args args) {
        bh_log(BH_LOG_LEVEL_FATAL, __FILE__, __LINE__, args);
    }
}
else {
    void LOG_FATAL(Args...)(Args args) {
        bh_log(BH_LOG_LEVEL_FATAL, __FUNCTION__, __LINE__, args);
    }
}

void LOG_ERROR(Args...)(Args args) {
    bh_log(BH_LOG_LEVEL_ERROR, NULL, 0, args);
}

void LOG_WARNING(Args...)(Args args) {
    bh_log(BH_LOG_LEVEL_WARNING, NULL, 0, args);
}

void LOG_VERBOSE(Args...)(Args args) {
    bh_log(BH_LOG_LEVEL_VERBOSE, NULL, 0, args);
}

version(BH_DEBUG) {
    void LOG_DEBUG(Args...)(Args args) {
        bh_log(BH_LOG_LEVEL_DEBUG, __FILE__, __LINE__, args);
    }
}
else {
    void LOG_DEBUG(Args...)(Args args) {
        /* do nothing */
    }
}

// void
// bh_print_time(const char *prompt);

// #ifdef __cplusplus
// }
// #endif

// #endif  /* _BH_LOG_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

//#include "bh_log.h"

/**
 * The verbose level of the log system.  Only those verbose logs whose
 * levels are less than or equal to this value are outputed.
 */
protected uint log_verbose_level = BH_LOG_LEVEL_WARNING;

void
bh_log_set_verbose_level(uint level)
{
    log_verbose_level = level;
}

void
bh_log(Args...)(LogLevel log_level, const char* file, int line, const char* fmt, Args args) {
    va_list ap;
    korp_tid self;
    char[32] buf;
    uint64 usec;
    uint t, h, m, s, mills;

    if (log_level > log_verbose_level)
        return;

    self = os_self_thread();

    usec = os_time_get_boot_microsecond();
    t = cast(uint)(usec / 1000000) % (24 * 60 * 60);
    h = t / (60 * 60);
    t = t % (60 * 60);
    m = t / 60;
    s = t % 60;
    mills = cast(uint)(usec % 1000);

    snprintf(buf, buf.length, "%02u:%02u:%02u:%03u", h, m, s, mills);

    os_printf("[%s - %X]: ", buf, cast(uint)self);

    if (file)
        os_printf("%s, line %d, ", file, line);

    va_start(ap, fmt);
    os_vprintf(fmt, ap);
    va_end(ap);

    os_printf("\n");
}

protected uint last_time_ms = 0;
protected uint total_time_ms = 0;

void
bh_print_time(const char* prompt)
{
    uint curr_time_ms;

    if (log_verbose_level < 3) {
        return;
    }
    curr_time_ms = cast(uint)bh_get_tick_ms();

    if (last_time_ms == 0) {
        last_time_ms = curr_time_ms;
    }
    total_time_ms += curr_time_ms - last_time_ms;

    os_printf("%-48s time of last stage: %u ms, total time: %u ms\n",
              prompt, curr_time_ms - last_time_ms, total_time_ms);

    last_time_ms = curr_time_ms;
}
