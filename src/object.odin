package odinlox

import "core:strings"
import "core:fmt"

ObjType :: enum u8 {
    CLOSURE,
    FUNCTION,
    NATIVE,
    STRING,
    UPVALUE,
}

Obj :: struct {
    type: ObjType,
    isMarked: bool,
    next: ^Obj,
}

ObjClosure :: struct {
    using obj: Obj,
    function: ^ObjFunction,
    upvalues: []^ObjUpvalue,
}

ObjFunction :: struct {
    using obj: Obj,
    arity: int,
    upvalueCount: int,
    chunk: Chunk,
    name: ^ObjString,
}

ObjString :: struct {
    using obj: Obj,
    str: string,
    hash: u32,
}

NativeFn :: #type proc(argCount: int, args: []Value) -> Value

ObjNative :: struct {
    using obj: Obj,
    function: NativeFn,
}

ObjUpvalue :: struct {
    using obj: Obj,
    location: ^Value,
    closed: Value,
    nextUV: ^ObjUpvalue,
}

//NJM: C code did this is macros which is why IS_STRING calls a separate function.
//Maybe refactor??

OBJ_TYPE :: proc(value: Value) -> ObjType { return AS_OBJ(value).type}
IS_STRING:: proc(value: Value) -> bool { return isObjType(value, ObjType.STRING)}
IS_FUNCTION :: proc(value: Value) -> bool { return isObjType(value, ObjType.FUNCTION)}
IS_NATIVE :: proc(value: Value) -> bool { return isObjType(value, ObjType.NATIVE)}
IS_CLOSURE :: proc(value: Value) -> bool { return isObjType(value, ObjType.CLOSURE)}

//Returning pointers to the different Object types from the Value structure
AS_OBJSTRING :: proc(value: Value) -> ^ObjString { return cast(^ObjString) AS_OBJ(value) }
AS_FUNCTION :: proc(value: Value) -> ^ObjFunction { return cast(^ObjFunction) AS_OBJ(value)}
AS_NATIVE :: proc(value: Value) -> NativeFn { return (cast(^ObjNative) AS_OBJ(value)).function}
AS_CLOSURE :: proc(value: Value) -> ^ObjClosure { return cast(^ObjClosure) AS_OBJ(value) }

//Unboxing object data
AS_STRING :: proc(value: Value) -> string { return AS_OBJSTRING(value).str }

allocateObject :: proc($T: typeid, type: ObjType) -> ^T {
    obj := new(T)

    vm.bytesAllocated += size_of(T)
    if vm.bytesAllocated > vm.nextGC {
        collectGarbage()
    }
    
    obj.type = type
    obj.isMarked = false
    obj.next = vm.objects
    vm.objects = obj

    when DEBUG_LOG_GC {
        fmt.printf("%p allocate %v for %v\n", obj, size_of(T), type)
    }

    return obj
}

allocateString :: proc(chars: string, hash: u32) -> ^ObjString {
    str := strings.clone(chars)
    obj := allocateObject(ObjString, ObjType.STRING)
    obj.str = str
    obj.hash = hash

    push(OBJ_VAL(obj))
    tableSet(&vm.strings, obj, NIL_VAL())
    pop()
    
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

newClosure :: proc(function: ^ObjFunction) -> ^ObjClosure {
    upvalues := make([]^ObjUpvalue, function.upvalueCount)

    closure := allocateObject(ObjClosure, ObjType.CLOSURE)
    closure.function = function
    closure.upvalues = upvalues

    return closure
}

newFunction :: proc() -> ^ObjFunction {
    function := allocateObject(ObjFunction, ObjType.FUNCTION)
    function.arity = 0
    function.upvalueCount = 0
    function.name = nil
    //initChunk(&function.chunk)
    return function
}

newNative :: proc(function: NativeFn) -> ^ObjNative {
    native := allocateObject(ObjNative, ObjType.NATIVE)
    native.function = function
    return native
}

newUpvalue :: proc(slot: ^Value) -> ^ObjUpvalue {
    upvalue := allocateObject(ObjUpvalue, ObjType.UPVALUE)
    upvalue.closed = NIL_VAL()
    upvalue.location = slot
    upvalue.nextUV = nil
    return upvalue
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
        case .CLOSURE:
            printFunction(AS_CLOSURE(value).function)
        case .FUNCTION:
            printFunction(AS_FUNCTION(value))
        case .NATIVE:
            fmt.printf("<native fn>")
        case .STRING:
            fmt.printf("%s", (cast(^ObjString) obj).str)
        case .UPVALUE:
            fmt.printf("upvalue")
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