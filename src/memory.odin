package odinlox

import "core:fmt"
import "core:os"

DEBUG_STRESS_GC :: ODIN_DEBUG
DEBUG_LOG_GC :: ODIN_DEBUG
GC_HEAP_GROW_FACTOR :: 2

collectGarbage :: proc() {
    when DEBUG_LOG_GC {
        fmt.printf("-- gc begin\n")
        before := vm.bytesAllocated
    }

    markRoots()
    traceReferences()
    tableRemoveWhite(&vm.strings)
    sweep()

    vm.nextGC = vm.bytesAllocated * GC_HEAP_GROW_FACTOR

    when DEBUG_LOG_GC {
        fmt.printf("-- gc end\n")
        fmt.printf("   collected %zu bytes (from %zu to %zu) next at %zu\n",
                   before - vm.bytesAllocated, before, vm.bytesAllocated, vm.nextGC)
    }
}

freeObjects :: proc() {
    object := vm.objects
    for object != nil {
        next := object.next
        freeObject(object)
        object = next
    }

    delete(vm.grayStack)
}

freeObject :: proc(object: ^Obj) {
    when DEBUG_LOG_GC {
        fmt.printf("%p free type %v\n", object, object.type)
    }

    switch object.type {
        case .BOUND_METHOD:
            bound := cast(^ObjBoundMethod) object
            vm.bytesAllocated -= size_of(bound)
            free(bound)
        case .CLASS:
            klass := cast(^ObjClass) object
            freeTable(&klass.methods)
            vm.bytesAllocated -= size_of(klass)
            free(klass)
        case .CLOSURE:
            objClosure := cast(^ObjClosure) object
            vm.bytesAllocated -= size_of(objClosure.upvalues)
            delete(objClosure.upvalues)
            vm.bytesAllocated -= size_of(objClosure)
            free(objClosure)
        case .FUNCTION:
            objFunction := cast(^ObjFunction) object
            freeChunk(&objFunction.chunk)
            vm.bytesAllocated -= size_of(objFunction)
            free(objFunction)
        case .INSTANCE:
            instance := cast(^ObjInstance) object
            freeTable(&instance.fields)
            vm.bytesAllocated -= size_of(instance)
            free(instance)
        case .NATIVE:
            objNative := cast(^ObjNative) object
            vm.bytesAllocated -= size_of(objNative)
            free(objNative)
        case .STRING:
            objStr := cast(^ObjString) object
            vm.bytesAllocated -= size_of(objStr.str)
            delete(objStr.str)
            vm.bytesAllocated -= size_of(objStr)
            free(objStr)
        case .UPVALUE:
            objUp := cast(^ObjUpvalue) object
            vm.bytesAllocated -= size_of(objUp)
            free(objUp)
    }
}

@(private="file")
markArray :: proc(array: [dynamic]Value) {
    for i := 0; i < len(array); i += 1 {
        markValue(array[i])
    }
}

markObject :: proc(object: ^Obj) {
    if object == nil do return
    if object.isMarked do return

    when DEBUG_LOG_GC {
        fmt.printf("%p mark ", object)
        printValue(OBJ_VAL(object))
        fmt.printf("\n")
    }
    object.isMarked = true

    //if vm.grayCapacity < vm.grayCount + 1 {
    //    vm.grayCapacity = vm.grayCapacity < 8 ? 8 : vm.grayCapacity*2
    //    vm.grayStack = AAA
    //}

    //vm.grayStack[vm.grayCount] = object
    append(&vm.grayStack, object)
    vm.grayCount += 1

    // Not sure I need this since append would probably already cause the program to exit
    // if it failed
    if vm.grayStack == nil do os.exit(1)
}

@(private="file")
markRoots :: proc() {
    for slot := 0; slot < vm.stackTop; slot += 1 {
        markValue(vm.stack[slot])
    }

    for i := 0; i < vm.frameCount; i += 1 {
        markObject(vm.frames[i].closure)
    }

    for upvalue := vm.openUpvalues; upvalue != nil; upvalue = upvalue.nextUV {
        markObject(upvalue)
    }

    markTable(&vm.globals)
    markCompilerRoots()
    markObject(vm.initString)
}

markValue :: proc(value: Value) {
    if IS_OBJ(value) do markObject(AS_OBJ(value))
}

@(private="file")
blackenObject :: proc(object: ^Obj) {
    when DEBUG_LOG_GC {
        fmt.printf("%p blacken ", object)
        printValue(OBJ_VAL(object))
        fmt.printf("\n")
    }

    switch object.type {
        case .BOUND_METHOD:
            bound := cast(^ObjBoundMethod) object
            markValue(bound.receiver)
            markObject(bound.method)
        case .CLASS:
            klass := cast(^ObjClass) object
            markObject(klass.name)
            markTable(&klass.methods)
        case .CLOSURE:
            closure := cast(^ObjClosure) object
            markObject(closure.function)
            for i := 0; i < len(closure.upvalues); i += 1 {
                markObject(closure.upvalues[i])
            }
        case .FUNCTION:
            function := cast(^ObjFunction) object
            markObject(function.name)
            markArray(function.chunk.constants)
        case .INSTANCE:
            instance := cast(^ObjInstance) object
            markObject(instance.klass)
            markTable(&instance.fields)
        case .UPVALUE:
            markValue( (cast(^ObjUpvalue) object).closed )
        case .NATIVE, .STRING:
            // nothing
    }
}

@(private="file")
traceReferences :: proc() {
    for vm.grayCount > 0 {
        vm.grayCount -= 1
        object := vm.grayStack[vm.grayCount]
        blackenObject(object)
    }
}

@(private="file")
sweep :: proc() {
    previous : ^Obj = nil
    object := vm.objects

    for object != nil {
        if object.isMarked {
            object.isMarked = false
            previous = object
            object = object.next
        } else {
            unreached := object
            object = object.next
            if previous != nil {
                previous.next = object
            } else {
                vm.objects = object
            }

            freeObject(unreached)
        }
    }
}