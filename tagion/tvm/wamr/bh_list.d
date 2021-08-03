/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.bh_list;


// #ifndef _BH_LIST_H
// #define _BH_LIST_H

// #ifdef __cplusplus
// extern "C" {
// #endif

// #include "bh_platform.h"
import tagion.tvm.wamr.bh_platform;

/* List user should embedded bh_list_link into list elem data structure
 * definition. And bh_list_link data field should be the first field.
 * For example, if we would like to use bh_list for our own data type A,
 * A must be defined as a structure like below:
 *     struct A {
 *         bh_list_link l;
 *         ...
 *     };
 *
 * bh_list_link is defined as a structure (not typedef void*).
 * It will make extend list into bi-direction easy.
 */
struct bh_list_link {
    bh_list_link* next;
}

struct bh_list {
    bh_list_link head;
    uint len;
}

/* list operation return value */
enum bh_list_status {
    BH_LIST_SUCCESS = 0,
    BH_LIST_ERROR = -1
}

/**
 * Initialize a list.
 *
 * @param list    pointer to list.
 * @return        <code>BH_LIST_ERROR</code> if OK;
 *                <code>BH_LIST_ERROR</code> if list pointer is NULL.
 */
// bh_list_status bh_list_init(bh_list *list);

/**
 * Insert an elem pointer into list. The list node memory is maintained by list while
 * elem memory is the responsibility of list user.
 *
 * @param list    pointer to list.
 * @param elem    pointer to elem that will be inserted into list.
 * @return        <code>BH_LIST_ERROR</code> if OK;
 *                <code>BH_LIST_ERROR</code> if input is invalid or no memory available.
 */
extern bh_list_status bh_list_insert(bh_list *list, void *elem);

/**
 * Remove an elem pointer from list. The list node memory is maintained by list while
 * elem memory is the responsibility of list user.
 *
 * @param list    pointer to list.
 * @param elem    pointer to elem that will be inserted into list.
 * @return        <code>BH_LIST_ERROR</code> if OK;
 *                <code>BH_LIST_ERROR</code> if element does not exist in given list.
 */
// bh_list_status bh_list_remove(bh_list *list, void *elem);

/**
 * Get the list length.
 *
 * @param list    pointer to list.
 * @return        the length of the list.
 */
// uint bh_list_length(bh_list *list);

/**
 * Get the first elem in the list.
 *
 * @param list    pointer to list.
 * @return        pointer to the first node.
 */
// void* bh_list_first_elem(bh_list *list);

/**
 * Get the next elem of given list input elem.
 *
 * @param node    pointer to list node.
 * @return        pointer to next list node.
 */
// void* bh_list_elem_next(void *node);

// #ifdef __cplusplus
// }
// #endif

// #endif /* #ifndef _BH_LIST_H */

/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

// #include "bh_list.h"

version(BH_DEBUG) {
/**
 * Test whehter a pointer value has exist in given list.
 *
 * @param list    pointer to list.
 * @param elem    pointer to elem that will be inserted into list.
 * @return        <code>true</code> if the pointer has been in the list;
 *                <code>false</code> otherwise.
 */
static bool bh_list_is_elem_exist(bh_list *list, void *elem);
}

bh_list_status bh_list_init(bh_list *list)
{
    if (!list)
        return BH_LIST_ERROR;

    (list.head).next = NULL;
    list.len = 0;
    return BH_LIST_SUCCESS;
}

bh_list_status bh_list_insert(bh_list *list, void *elem)
{
    bh_list_link *p = NULL;

    if (!list || !elem)
        return BH_LIST_ERROR;
    version(BH_DEBUG) {
        bh_assert (!bh_list_is_elem_exist(list, elem));
    }
    p = cast(bh_list_link *) elem;
    p.next = (list.head).next;
    (list.head).next = p;
    list.len++;
    return BH_LIST_SUCCESS;
}

bh_list_status bh_list_remove(bh_list *list, void *elem)
{
    bh_list_link *cur = NULL;
    bh_list_link *prev = NULL;

    if (!list || !elem)
        return BH_LIST_ERROR;

    cur = (list.head).next;

    while (cur) {
        if (cur == elem) {
            if (prev)
                prev.next = cur.next;
            else
                (list.head).next = cur.next;

            list.len--;
            return BH_LIST_SUCCESS;
        }

        prev = cur;
        cur = cur.next;
    }

    return BH_LIST_ERROR;
}

uint bh_list_length(bh_list *list)
{
    return (list ? list.len : 0);
}

void* bh_list_first_elem(bh_list *list)
{
    return (list ? (list.head).next : NULL);
}

void* bh_list_elem_next(void *node)
{
    return (node ? (cast(bh_list_link *) node).next : NULL);
}

version(BH_DEBUG) {
static bool bh_list_is_elem_exist(bh_list *list, void *elem)
{
    bh_list_link *p = NULL;

    if (!list || !elem) return false;

    p = (list.head).next;
    while (p && p != elem) p = p.next;

    return (p != NULL);
}
}
