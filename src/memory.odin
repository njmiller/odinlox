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
        case.STRING:
            objstr := cast(^ObjString) object
            delete(objstr.str)
            free(objstr)
    }
}