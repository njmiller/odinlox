package odinlox

import "core:strings"
import "core:fmt"

ObjType :: enum u8 {
    STRING,
}

Obj :: struct {
    type: ObjType,
    next: ^Obj,
}

ObjString :: struct {
    using obj: Obj,
    str: string,
    hash: u32,
}

//NJM: C code did this is macros which is why IS_STRING calls a separate function.
//Maybe refactor??

//OBJ_TYPE :: proc(value: Value) -> ObjType { return AS_OBJ(value).type}
IS_STRING:: proc(value: Value) -> bool { return isObjType(value, ObjType.STRING)}

//Returning pointers to the different Object types from the Value structure
AS_OBJSTRING :: proc(value: Value) -> ^ObjString { return cast(^ObjString) AS_OBJ(value) }

//Unboxing object data
AS_STRING :: proc(value: Value) -> string { return AS_OBJSTRING(value).str }

allocateObject :: proc($T: typeid, type: ObjType) -> ^T {
    obj := new(T)
    obj.type = type
    obj.next = vm.objects
    vm.objects = obj

    return obj
}

allocateString :: proc(chars: string, hash: u32) -> ^ObjString {
    str := strings.clone(chars)
    obj := allocateObject(ObjString, ObjType.STRING)
    obj.str = str
    obj.hash = hash

    tableSet(&vm.strings, obj, NIL_VAL())

    return obj
}

copyString :: proc(str: string) -> ^ObjString {
    hash := hashString(str)
    interned := tableFindString(&vm.strings, str, hash)
    if interned != nil do return interned

    return allocateString(str, hash)
    
}

//TODO: Replace with standard library hash function???
//Do some timing tests
hashString :: proc(str: string) -> u32 {
    hash : u32 = 2166136261
    for char in str {
        hash ~= u32(char)
        hash *= 16777619
    }
    return hash
}

isObjType :: proc(value: Value, type: ObjType) -> bool {
    return IS_OBJ(value) && (AS_OBJ(value).type == type)
}

printObject :: proc(value: Value) {
    obj := AS_OBJ(value)
    switch obj.type {
        case .STRING:
            fmt.printf("%s", (cast(^ObjString) obj).str)
    }
}

//NJM: Why do I need this???
takeString :: proc(str: string) -> ^ObjString {
    hash := hashString(str)
    interned := tableFindString(&vm.strings, str, hash)

    if interned != nil {
        delete(str)
        return interned
    }
    
    return allocateString(str, hash)
}