package odinlox

import "core:fmt"

freeObjects :: proc() {
    object := vm.objects
    for object != nil {
        next := object.next
        freeObject(object)
        object = next
    }
}

freeObject :: proc(object: ^Obj) {
    switch object.type {
        case .CLOSURE:
            objClosure := cast(^ObjClosure) object
            delete(objClosure.upvalues)
            free(objClosure)
        case .FUNCTION:
            objFunction := cast(^ObjFunction) object
            freeChunk(&objFunction.chunk)
            free(objFunction)
        case .NATIVE:
            objNative := cast(^ObjNative) object
            free(objNative)
        case .STRING:
            objStr := cast(^ObjString) object
            delete(objStr.str)
            free(objStr)
        case .UPVALUE:
            objUp := cast(^ObjUpvalue) object
            free(objUp)
    }
}