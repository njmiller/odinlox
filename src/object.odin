package odinlox

import "core:strings"
import "core:fmt"

ObjType :: enum u8 {
    FUNCTION,
    STRING,
}

Obj :: struct {
    type: ObjType,
    next: ^Obj,
}

ObjFunction :: struct {
    using obj: Obj,
    arity: int,
    chunk: Chunk,
    name: ^ObjString,
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
IS_FUNCTION :: proc(value: Value) -> bool { return isObjType(value, ObjType.FUNCTION)}

//Returning pointers to the different Object types from the Value structure
AS_OBJSTRING :: proc(value: Value) -> ^ObjString { return cast(^ObjString) AS_OBJ(value) }
AS_FUNCTION :: proc(value: Value) -> ^ObjFunction { return cast(^ObjFunction) AS_OBJ(value)}

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

newFunction :: proc() -> ^ObjFunction {
    function := allocateObject(ObjFunction, ObjType.FUNCTION)
    function.arity = 0
    function.name = nil
    //initChunk(&function.chunk)
    return function
}

printFunction :: proc(function: ^ObjFunction) {
    if function.name == nil {
        fmt.printf("<script>")
        return
    }
    
    fmt.printf("<fn %s>", function.name.str)
}
printObject :: proc(value: Value) {
    obj := AS_OBJ(value)
    switch obj.type {
        case .FUNCTION:
            printFunction(AS_FUNCTION(value))
        case .STRING:
            fmt.printf("%s", (cast(^ObjString) obj).str)
    }
}

takeString :: proc(str: string) -> ^ObjString {
    hash := hashString(str)
    interned := tableFindString(&vm.strings, str, hash)

    if interned != nil {
        delete(str)
        return interned
    }
    
    return allocateString(str, hash)
}