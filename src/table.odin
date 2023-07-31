package odinlox

import "core:strings"

TABLE_MAX_LOAD :: 0.75

//TODO: Implement this hashtable structure
//Would require moving hash to Entry structure
//instead of being stored in Key object
/*
Table :: struct($Key, $Value: typeid) {
    count: int,
    capacity: int,
    allocator: mem.Allocator,
    entries: []Entry(Key, Value)
}

Entry :: struct($Key, $Value: typeid) {
    key: $Key,
    value: $Value
}
*/

Table :: struct {
    count: int,
    capacity: int,
    entries: []Entry,
}

Entry :: struct {
    key: ^ObjString,
    value: Value,
}

initTable :: proc(table: ^Table) {
    table.count = 0
    table.capacity = 0
}

freeTable :: proc(table: ^Table) {
    delete(table.entries)
    initTable(table)
}

markTable :: proc(table: ^Table) {
    for i := 0; i < table.capacity; i += 1 {
        entry := &table.entries[i]
        markObject(entry.key) // I think this is the few implicit type conversions
        markValue(entry.value)
    }
}

tableSet :: proc(table: ^Table, key: ^ObjString, value: Value) -> bool {
    if f32(table.count + 1) > f32(table.capacity) * TABLE_MAX_LOAD {
        capacity := table.capacity < 8 ? 8 : table.capacity*2
        adjustCapacity(table, capacity)
    }

    entry := findEntry(table.entries, table.capacity, key)
    isNewKey := entry.key == nil
    
    if isNewKey && IS_NIL(entry.value) do table.count += 1
    
    
    entry.key = key
    entry.value = value
    
    return isNewKey
}

tableRemoveWhite :: proc(table: ^Table) {
    for i := 0; i < table.capacity; i += 1 {
        entry := &table.entries[i]
        if entry.key != nil && !entry.key.obj.isMarked {
            tableDelete(table, entry.key)
        }
    }
}

@(private="file")
adjustCapacity :: proc(table: ^Table, capacity: int) {
    entries := make([]Entry, capacity)
    for i := 0; i < capacity; i += 1 {
        entries[i].key = nil
        entries[i].value = NIL_VAL()
    }

    table.count = 0
    for i:=0; i < table.capacity; i += 1 {
        entry := &table.entries[i]
        if entry.key == nil do continue
        
        dest := findEntry(entries, capacity, entry.key)
        dest.key = entry.key
        dest.value = entry.value
        table.count += 1
    }

    delete(table.entries)

    table.entries = entries
    table.capacity = capacity
}

findEntry :: proc(entries: []Entry, capacity: int, key: ^ObjString) -> ^Entry {
    index := key.hash % u32(capacity)
    tombstone : ^Entry = nil

    for {
        entry := &entries[index]
        if entry.key == nil {
            if IS_NIL(entry.value) { 
                // Empty entry
                return tombstone != nil ? tombstone : entry
            } else {
                // We found a tombstone.key
                if tombstone == nil do tombstone = entry
            }
        } else if entry.key == key do return entry

        index = (index + 1) % u32(capacity)
    }
}

tableAddAll :: proc(from: ^Table, to: ^Table) {
    for i := 0; i < from.capacity; i += 1 {
        entry := &from.entries[i]
        if entry.key != nil do tableSet(to, entry.key, entry.value)
    }
}

//TODO: Maybe change to multi return values based on how the code is written
tableGet :: proc(table: ^Table, key: ^ObjString, value: ^Value) -> bool {
    if table.count == 0 do return false
    
    entry := findEntry(table.entries, table.capacity, key)
    if entry.key == nil do return false

    value^ = entry.value

    return true
}

tableDelete :: proc(table: ^Table, key: ^ObjString) -> bool {
    if table.count == 0 do return false
    
    // Find the entry
    entry := findEntry(table.entries, table.capacity, key)
    if entry.key == nil do return false
    
    // Place a tombstone in the entry
    entry.key = nil
    entry.value = BOOL_VAL(true)
    return true
}

tableFindString :: proc(table: ^Table, str: string, hash: u32) -> ^ObjString {
    if table.count == 0 do return nil

    index := hash % u32(table.capacity)

    for {
        entry := &table.entries[index]
        if entry.key == nil {
            // Stop if we find an empty non-tombstone entry
            if IS_NIL(entry.value) do return nil
        } else if  len(entry.key.str) == len(str) && entry.key.hash == hash && strings.compare(entry.key.str, str) == 0 {
        //} else if strings.compare(entry.key.str, str) == 0 && entry.key.hash == hash {
            // We found it
            return entry.key
        }

        index = (index + 1) % u32(table.capacity)
    }
}
//GROW_CAPACITY :: proc(capacity)