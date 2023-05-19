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
        case .FUNCTION:
            objfunction := cast(^ObjFunction) object
            freeChunk(&objfunction.chunk)
            free(objfunction)
        case .NATIVE:
            objnative := cast(^ObjNative) object
            free(objnative)
        case .STRING:
            objstr := cast(^ObjString) object
            delete(objstr.str)
            free(objstr)
    }
}