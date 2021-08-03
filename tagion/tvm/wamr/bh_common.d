/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.bh_common;

import tagion.tvm.wamr.bh_platform;
// #ifndef _BH_COMMON_H
// #define _BH_COMMON_H

// #include "bh_platform.h"

// #ifdef __cplusplus
// extern "C" {
// #endif

void bh_memcpy_s(void* dest, size_t dlen, void* src, size_t slen) {
    int _ret = slen == 0 ? 0 : b_memcpy_s (dest, dlen, src, slen);
    // (void)_ret;
    bh_assert (_ret == 0);
}

void bh_memmove_s(void* dest, size_t dlen, void* src, size_t slen) {             int _ret = slen == 0 ? 0 : b_memmove_s (dest, dlen, src, slen);
    // (void)_ret;
    bh_assert (_ret == 0);
}

void bh_strcat_s(void* dest, size_t dlen, void* src) {
    int _ret = b_strcat_s (dest, dlen, src);
//    (void)_ret;                                                       \
    bh_assert (_ret == 0);
}

void bh_strcpy_s(void* dest, size_t dlen, void* src) {                           int _ret = b_strcpy_s (dest, dlen, src);
//    (void)_ret;                                                       \
    bh_assert (_ret == 0);
}

// int b_memcpy_s(void * s1, unsigned int s1max, const void * s2, unsigned int n);
// int b_memmove_s(void * s1, unsigned int s1max, const void * s2, unsigned int n);
// int b_strcat_s(char * s1, unsigned int s1max, const char * s2);
// int b_strcpy_s(char * s1, unsigned int s1max, const char * s2);

// /* strdup with string allocated by BH_MALLOC */
// char *bh_strdup(const char *s);

// /* strdup with string allocated by WA_MALLOC */
// char *wa_strdup(const char *s);

// #ifdef __cplusplus
// }
// #endif

// #endif
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

// #include "bh_common.h"

// #ifdef RSIZE_MAX
// #undef RSIZE_MAX
// #endif

enum RSIZE_MAX = 0x7FFFFFFF;

int
b_memcpy_s(void* s1, uint s1max,
           const void* s2, uint n)
{
  char *dest = cast(char*)s1;
  char *src = cast(char*)s2;
  if (n == 0) {
    return 0;
  }

  if (s1 == NULL || s1max > RSIZE_MAX) {
    return -1;
  }
  if (s2 == NULL || n > s1max) {
    memset(dest, 0, s1max);
    return -1;
  }
  memcpy(dest, src, n);
  return 0;
}

int b_memmove_s(void * s1, uint s1max,
                const void * s2, uint n)
{
  char *dest = cast(char*)s1;
  char *src = cast(char*)s2;
  if (n == 0) {
    return 0;
  }

  if (s1 == NULL || s1max > RSIZE_MAX) {
    return -1;
  }
  if (s2 == NULL || n > s1max) {
    memset(dest, 0, s1max);
    return -1;
  }
  memmove(dest, src, n);
  return 0;
}

int
b_strcat_s(char * s1, uint s1max, const char * s2)
{
  if (NULL == s1 || NULL == s2
      || s1max < (strlen(s1) + strlen(s2) + 1)
      || s1max > RSIZE_MAX) {
    return -1;
  }

  memcpy(s1 + strlen(s1), s2, strlen(s2) + 1);
  return 0;
}

int
b_strcpy_s(char * s1, uint s1max, const char * s2)
{
  if (NULL == s1 || NULL == s2
      || s1max < (strlen(s2) + 1)
      || s1max > RSIZE_MAX) {
    return -1;
  }

  memcpy(s1, s2, strlen(s2) + 1);
  return 0;
}


char *
bh_strdup(const char *s)
{
    uint size;
    char *s1 = NULL;

    if (s) {
        size = cast(uint)(strlen(s) + 1);
        if ((s1 = BH_MALLOC(size)))
            bh_memcpy_s(s1, size, s, size);
    }
    return s1;
}

char *
wa_strdup(const char *s)
{
    uint size;
    char *s1 = NULL;

    if (s) {
        size = cast(uint)(strlen(s) + 1);
        if ((s1 = WA_MALLOC(size)))
            bh_memcpy_s(s1, size, s, size);
    }
    return s1;
}
