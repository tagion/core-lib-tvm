/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
module tagion.tvm.wamr.bh_hashmap;

import tagion.tvm.wamr.bh_platform;
import tagion.tvm.platform.platform;

// #ifndef WASM_HASHMAP_H
// #define WASM_HASHMAP_H

// #include "bh_platform.h"

// #ifdef __cplusplus
// extern "C" {
// #endif

/* Maximum initial size of hash map */
enum HASH_MAP_MAX_SIZE = 65536;

// struct HashMap;
// typedef struct HashMap HashMap;

// /* Hash function: to get the hash value of key. */
alias HashFunc = uint function(const void *key);

// /* Key equal function: to check whether two keys are equal. */
alias KeyEqualFunc = bool function(void *key1, void *key2);

// /* Key destroy function: to destroy the key, auto called
//    when an hash element is removed. */
alias KeyDestroyFunc = void function(void *key);

// /* Value destroy function: to destroy the value, auto called
//    when an hash element is removed. */
alias ValueDestroyFunc  = void function(void *key);

/**
 * Create a hash map.
 *
 * @param size: the initial size of the hash map
 * @param use_lock whether to lock the hash map when operating on it
 * @param hash_func hash function of the key, must be specified
 * @param key_equal_func key equal function, check whether two keys
 *                       are equal, must be specified
 * @param key_destroy_func key destroy function, called when an hash element
 *                         is removed if it is not NULL
 * @param value_destroy_func value destroy function, called when an hash
 *                           element is removed if it is not NULL
 *
 * @return the hash map created, NULL if failed
 */
// HashMap*
// bh_hash_map_create(uint size, bool use_lock,
//                    HashFunc hash_func,
//                    KeyEqualFunc key_equal_func,
//                    KeyDestroyFunc key_destroy_func,
//                    ValueDestroyFunc value_destroy_func);

/**
 * Insert an element to the hash map
 *
 * @param map the hash map to insert element
 * @key the key of the element
 * @value the value of the element
 *
 * @return true if success, false otherwise
 * Note: fail if key is NULL or duplicated key exists in the hash map,
 */
// bool
// bh_hash_map_insert(HashMap *map, void *key, void *value);

/**
 * Find an element in the hash map
 *
 * @param map the hash map to find element
 * @key the key of the element
 *
 * @return the value of the found element if success, NULL otherwise
 */
// void*
// bh_hash_map_find(HashMap *map, void *key);

/**
 * Update an element in the hash map with new value
 *
 * @param map the hash map to update element
 * @key the key of the element
 * @value the new value of the element
 * @p_old_value if not NULL, copies the old value to it
 *
 * @return true if success, false otherwise
 * Note: the old value won't be destroyed by value destroy function,
 *       it will be copied to p_old_value for user to process.
 */
// bool
// bh_hash_map_update(HashMap *map, void *key, void *value,
//                   void **p_old_value);

/**
 * Remove an element from the hash map
 *
 * @param map the hash map to remove element
 * @key the key of the element
 * @p_old_key if not NULL, copies the old key to it
 * @p_old_value if not NULL, copies the old value to it
 *
 * @return true if success, false otherwise
 * Note: the old key and old value won't be destroyed by key destroy
 *       function and value destroy function, they will be copied to
 *       p_old_key and p_old_value for user to process.
 */
// bool
// bh_hash_map_remove(HashMap *map, void *key,
//                    void **p_old_key, void **p_old_value);

/**
 * Destroy the hashmap
 *
 * @param map the hash map to destroy
 *
 * @return true if success, false otherwise
 * Note: the key destroy function and value destroy function will be
 *       called to destroy each element's key and value if they are
 *       not NULL.
 */
// bool
// bh_hash_map_destroy(HashMap *map);

// #ifdef __cplusplus
// }
// #endif

// #endif /* endof WASM_HASHMAP_H */

/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

// #include "bh_hashmap.h"

struct HashMapElem {
    void* key;
    void* value;
    HashMapElem *next;
}

struct HashMap {
    /* size of element array */
    uint size;
    /* lock for elements */
    korp_mutex* lock;
    /* hash function of key */
    HashFunc hash_func;
    /* key equal function */
    KeyEqualFunc key_equal_func;
    KeyDestroyFunc key_destroy_func;
    ValueDestroyFunc value_destroy_func;
    HashMapElem*[1] elements;
};

HashMap*
bh_hash_map_create(uint size, bool use_lock,
                   HashFunc hash_func,
                   KeyEqualFunc key_equal_func,
                   KeyDestroyFunc key_destroy_func,
                   ValueDestroyFunc value_destroy_func)
{
    HashMap* map;
    uint64 total_size;

    if (size > HASH_MAP_MAX_SIZE) {
        LOG_ERROR("HashMap create failed: size is too large.\n");
        return NULL;
    }

    if (!hash_func || !key_equal_func) {
        LOG_ERROR("HashMap create failed: hash function or key equal function " ~
                " is NULL.\n");
        return NULL;
    }

    total_size = offsetof(HashMap, elements) +
                 HashMapElem.sizeof * cast(uint64)size +
                 (use_lock ? korp_mutex.sizeof : 0);

    if (total_size >= UINT_MAX
        || !(map = BH_MALLOC(cast(uint)total_size))) {
        LOG_ERROR("HashMap create failed: alloc memory failed.\n");
        return NULL;
    }

    memset(map, 0, cast(uint)total_size);

    if (use_lock) {
        map.lock = cast(korp_mutex*)
                    (cast(uint8*)map + offsetof(HashMap, elements)
                     + HashMapElem.sizeof * size);
        if (os_mutex_init(map.lock)) {
            LOG_ERROR("HashMap create failed: init map lock failed.\n");
            BH_FREE(map);
            return NULL;
        }
    }

    map.size = size;
    map.hash_func = hash_func;
    map.key_equal_func = key_equal_func;
    map.key_destroy_func = key_destroy_func;
    map.value_destroy_func = value_destroy_func;
    return map;
}

bool
bh_hash_map_insert(HashMap* map, void* key, void* value)
{
    uint index;
    HashMapElem* elem;

    if (!map || !key) {
        LOG_ERROR("HashMap insert elem failed: map or key is NULL.\n");
        return false;
    }

    if (map.lock) {
        os_mutex_lock(map.lock);
    }

    index = map.hash_func(key) % map.size;
    elem = map.elements[index];
    while (elem) {
        if (map.key_equal_func(elem.key, key)) {
            LOG_ERROR("HashMap insert elem failed: duplicated key found.\n");
            goto fail;
        }
        elem = elem.next;
    }

    if (!(elem = BH_MALLOC(sizeof(HashMapElem)))) {
        LOG_ERROR("HashMap insert elem failed: alloc memory failed.\n");
        goto fail;
    }

    elem.key = key;
    elem.value = value;
    elem.next = map.elements[index];
    map.elements[index] = elem;

    if (map.lock) {
        os_mutex_unlock(map.lock);
    }
    return true;

fail:
    if (map.lock) {
        os_mutex_unlock(map.lock);
    }
    return false;
}

void*
bh_hash_map_find(HashMap* map, void* key)
{
    uint index;
    HashMapElem* elem;
    void* value;

    if (!map || !key) {
        LOG_ERROR("HashMap find elem failed: map or key is NULL.\n");
        return NULL;
    }

    if (map.lock) {
        os_mutex_lock(map.lock);
    }

    index = map.hash_func(key) % map.size;
    elem = map.elements[index];

    while (elem) {
        if (map.key_equal_func(elem.key, key)) {
            value = elem.value;
            if (map.lock) {
                os_mutex_unlock(map.lock);
            }
            return value;
        }
        elem = elem.next;
    }

    if (map.lock) {
        os_mutex_unlock(map.lock);
    }
    return NULL;
}

bool
bh_hash_map_update(HashMap* map, void* key, void* value,
                   void** p_old_value)
{
    uint index;
    HashMapElem* elem;

    if (!map || !key) {
        LOG_ERROR("HashMap update elem failed: map or key is NULL.\n");
        return false;
    }

    if (map.lock) {
        os_mutex_lock(map.lock);
    }

    index = map.hash_func(key) % map.size;
    elem = map.elements[index];

    while (elem) {
        if (map.key_equal_func(elem.key, key)) {
            if (p_old_value)
                *p_old_value = elem.value;
            elem.value = value;
            if (map.lock) {
                os_mutex_unlock(map.lock);
            }
            return true;
    }
    elem = elem.next;
    }

    if (map.lock) {
        os_mutex_unlock(map.lock);
    }
    return false;
}

bool
bh_hash_map_remove(HashMap* map, void* key,
                   void* *p_old_key, void* *p_old_value)
{
    uint index;
    HashMapElem* elem, prev;

    if (!map || !key) {
        LOG_ERROR("HashMap remove elem failed: map or key is NULL.\n");
        return false;
    }

    if (map.lock) {
        os_mutex_lock(map.lock);
    }

    index = map.hash_func(key) % map.size;
    prev = elem = map.elements[index];

    while (elem) {
        if (map.key_equal_func(elem.key, key)) {
            if (p_old_key)
                *p_old_key = elem.key;
            if (p_old_value)
                *p_old_value = elem.value;

            if (elem == map.elements[index])
                map.elements[index] = elem.next;
            else
                prev.next = elem.next;

            BH_FREE(elem);

            if (map.lock) {
                os_mutex_unlock(map.lock);
            }
            return true;
        }

        prev = elem;
        elem = elem.next;
    }

    if (map.lock) {
        os_mutex_unlock(map.lock);
    }
    return false;
}

bool
bh_hash_map_destroy(HashMap* map)
{
    uint index;
    HashMapElem* elem, next;

    if (!map) {
        LOG_ERROR("HashMap destroy failed: map is NULL.\n");
        return false;
    }

    if (map.lock) {
        os_mutex_lock(map.lock);
    }

    for (index = 0; index < map.size; index++) {
        elem = map.elements[index];
        while (elem) {
            next = elem.next;

            if (map.key_destroy_func) {
                map.key_destroy_func(elem.key);
            }
            if (map.value_destroy_func) {
                map.value_destroy_func(elem.value);
            }
            BH_FREE(elem);

            elem = next;
        }
    }

    if (map.lock) {
        os_mutex_unlock(map.lock);
        os_mutex_destroy(map.lock);
    }
    BH_FREE(map);
    return true;
}
