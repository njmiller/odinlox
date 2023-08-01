package odinlox

//NOTE: Array access seems faster than the Odin pointer offset stuff
//in the core library

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

DEBUG_TRACE_EXECUTION :: ODIN_DEBUG
FRAMES_MAX :: 64
STACK_MAX :: FRAMES_MAX * U8_COUNT

//TODO: Check what I need for slots
CallFrame :: struct {
    closure: ^ObjClosure,
    ip: int,
    slots: []Value, // or ^Value
}

VM :: struct {
    frames: [FRAMES_MAX]CallFrame,
    frameCount: int,
    stack: [STACK_MAX]Value,
    stackTop: int,
    globals: Table,
    strings: Table,
    openUpvalues: ^ObjUpvalue,
    bytesAllocated: int,
    nextGC: int,
    objects: ^Obj,
    grayCount: int,
    //grayCapacity: int,
    grayStack: [dynamic]^Obj,
}

InterpretResult :: enum {
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR,
}

vm : VM

resetStack  :: proc() {
    vm.stackTop = 0
    vm.frameCount = 0
    vm.openUpvalues = nil
}

initVM :: proc() {
    resetStack()
    vm.objects = nil

    vm.bytesAllocated = 0
    vm.nextGC = 1024 * 1024

    vm.grayCount = 0
    //vm.grayCapacity = 0
    //vm.grayCapacity = nil

    initTable(&vm.strings)
    initTable(&vm.globals)

    defineNative("clock", clockNative)
}

freeVM :: proc() {
    freeObjects()
    freeTable(&vm.strings)
    freeTable(&vm.globals)
}

@(private="file")
isFalsey :: proc(value: Value) -> bool {
    return IS_NIL(value) || (IS_BOOL(value) && !AS_BOOL(value))
}

@(private="file")
call :: proc(closure: ^ObjClosure, argCount: int) -> bool {
    if argCount != closure.function.arity {
        runtimeError("Expected %d arguments but got %d.", closure.function.arity, argCount)
        return false
    }

    if vm.frameCount == FRAMES_MAX {
        runtimeError("Stack overflow.")
        return false
    }

    frame := &vm.frames[vm.frameCount]
    vm.frameCount += 1
    frame.closure = closure
    frame.ip = 0
    frame.slots = vm.stack[vm.stackTop - argCount - 1:]
    return true
}

@(private="file")
callValue :: proc(callee: Value, argCount: int) -> bool {
    if IS_OBJ(callee) {
        #partial switch (OBJ_TYPE(callee)) {
            case .CLOSURE:
                return call(AS_CLOSURE(callee), argCount)
            //case .FUNCTION:
            //    return call(AS_FUNCTION(callee), argCount)
            case .CLASS:
                klass := AS_CLASS(callee)
                vm.stack[vm.stackTop - argCount - 1] = OBJ_VAL(newInstance(klass))
                return true
            case .NATIVE:
                native := AS_NATIVE(callee)
                result := native(argCount, vm.stack[vm.stackTop-argCount:vm.stackTop])
                vm.stackTop -= argCount + 1
                push(result)
                return true
        }
    }

    runtimeError("Can only call functions and classes.")
    return false
}

@(private="file")
captureUpvalue :: proc(local: ^Value) -> ^ObjUpvalue {
    prevUpvalue : ^ObjUpvalue
    upvalue := vm.openUpvalues
    for upvalue != nil && upvalue.location > local {
        prevUpvalue = upvalue
        upvalue = upvalue.nextUV
    }

    if upvalue != nil && upvalue.location == local {
        return upvalue
    }

    createdUpvalue := newUpvalue(local)
    createdUpvalue.nextUV = upvalue

    if prevUpvalue == nil {
        vm.openUpvalues = createdUpvalue
    } else {
        prevUpvalue.nextUV = createdUpvalue
    }

    return createdUpvalue
}

@(private="file")
clockNative :: proc(argCount: int, args: []Value) -> Value {
    return NUMBER_VAL(f64(time.now()._nsec / 1000000000))
}

@(private="file")
closeUpvalues :: proc(last: ^Value) {
    for vm.openUpvalues != nil && vm.openUpvalues.location >= last {
        upvalue := vm.openUpvalues
        upvalue.closed = upvalue.location^
        upvalue.location = &upvalue.closed
        vm.openUpvalues = upvalue.nextUV
    }
}
@(private="file")
concatenate :: proc() {
    b := AS_STRING(peek(0))
    a := AS_STRING(peek(1))
    
    c := strings.concatenate( {a, b} )

    result := takeString(c)
    pop()
    pop()
    push(OBJ_VAL(result))

    //NJM: Check. I don't think I need to delete a or b since they are part of the
    //objects which will be garbage collected. C is cloned for result so we can delete it
    delete(c)
}

@(private="file")
defineNative :: proc(name: string, function: NativeFn) {
    push(OBJ_VAL(copyString(name)))
    push(OBJ_VAL(newNative(function)))
    tableSet(&vm.globals, AS_OBJSTRING(vm.stack[0]), vm.stack[1])
    pop()
    pop()
}

@(private="file")
peek :: proc(distance: int) -> Value {
    return vm.stack[vm.stackTop - 1 - distance]
}

push :: proc(value: Value) {
    vm.stack[vm.stackTop] = value
    vm.stackTop += 1
}

pop :: proc() -> Value {
    vm.stackTop -= 1
    return vm.stack[vm.stackTop]
}

run :: proc() -> InterpretResult {
    instruction : OpCode

    frame := &vm.frames[vm.frameCount - 1]

    for {
        when DEBUG_TRACE_EXECUTION {
            fmt.printf("       ")
            for slot := 0; slot < vm.stackTop; slot += 1 {
                fmt.printf("[ ")
                printValue(vm.stack[slot])
                fmt.printf(" ]")
            }
            fmt.printf("\n")
            disassembleInstruction(&frame.closure.function.chunk, frame.ip)
        }
        instruction = auto_cast read_byte(frame)
        switch instruction {
            case .ADD:
                if IS_STRING(peek(0)) && IS_STRING(peek(1)) {
                    concatenate()
                } else if IS_NUMBER(peek(0)) && IS_NUMBER(peek(0)) {
                    b := AS_NUMBER(pop())
                    a := AS_NUMBER(pop())
                    push(NUMBER_VAL(a + b))
                } else {
                    runtimeError("Operands must be two numbers or two strings.")
                    return InterpretResult.RUNTIME_ERROR
                }
            case .CALL:
                argCount := int(read_byte(frame))
                if !callValue(peek(argCount), argCount) do return InterpretResult.RUNTIME_ERROR
                frame = &vm.frames[vm.frameCount - 1]
            case .CLASS:
                push(OBJ_VAL(newClass(read_string(frame))))
            case .CLOSE_UPVALUE:
                closeUpvalues(&vm.stack[vm.stackTop - 1])
                pop()
            case .CLOSURE:
                function := AS_FUNCTION(read_constant(frame))
                closure := newClosure(function)
                push(OBJ_VAL(closure))
                for i := 0; i < len(closure.upvalues); i += 1 {
                    isLocal := read_byte(frame)
                    index := read_byte(frame)
                    if isLocal > 0 {
                        closure.upvalues[i] = captureUpvalue(&frame.slots[index])
                    } else {
                        closure.upvalues[i] = frame.closure.upvalues[index]
                    }
                }
            case .DEFINE_GLOBAL:
                name := read_string(frame)
                tableSet(&vm.globals, name, peek(0))
                pop()
            case .DIVIDE:
                if !IS_NUMBER(peek(0)) || !IS_NUMBER(peek(1)) {
                    runtimeError("Operands must be numbers.")
                    return InterpretResult.RUNTIME_ERROR
                }
                b := AS_NUMBER(pop())
                a := AS_NUMBER(pop())
                push(NUMBER_VAL(a / b))
            case .EQUAL:
                b := pop()
                a := pop()
                push(BOOL_VAL(valuesEqual(a, b)))
            case .GET_GLOBAL:
                name := AS_OBJSTRING(read_constant(frame))
                value: Value
                if !tableGet(&vm.globals, name, &value) {
                    runtimeError("Undefined variable '%s'.", name.str)
                    return InterpretResult.RUNTIME_ERROR
                }
                push(value)
            case .GET_LOCAL:
                slot := read_byte(frame)
                push(frame.slots[slot])
            case .GET_PROPERTY:
                if !IS_INSTANCE(peek(0)) {
                    runtimeError("Only instances have properties.")
                    return InterpretResult.RUNTIME_ERROR
                }
                instance := AS_INSTANCE(peek(0))
                name := read_string(frame)

                value: Value
                if tableGet(&instance.fields, name, &value) {
                    pop()
                    push(value)
                    break
                }
                
                runtimeError("Undefined property '%s'.", name.str)
                return InterpretResult.RUNTIME_ERROR
            case .GET_UPVALUE:
                slot := read_byte(frame)
                push(frame.closure.upvalues[slot].location^)
            case .GREATER:
                if !IS_NUMBER(peek(0)) || !IS_NUMBER(peek(1)) {
                    runtimeError("Operands must be numbers.")
                    return InterpretResult.RUNTIME_ERROR
                }
                b := AS_NUMBER(pop())
                a := AS_NUMBER(pop())
                push(BOOL_VAL(a > b))
            case .FALSE:
                push(BOOL_VAL(false))
            case .JUMP:
                offset := read_short(frame)
                frame.ip += int(offset)
            case .JUMP_IF_FALSE:
                offset := read_short(frame)
                if isFalsey(peek(0)) do frame.ip += int(offset)
            case .LESS:
                if !IS_NUMBER(peek(0)) || !IS_NUMBER(peek(1)) {
                    runtimeError("Operands must be numbers.")
                    return InterpretResult.RUNTIME_ERROR
                }
                b := AS_NUMBER(pop())
                a := AS_NUMBER(pop())
                push(BOOL_VAL(a < b))
            case .LOOP:
                offset := read_short(frame)
                frame.ip -= int(offset)
            case .MULTIPLY:
                if !IS_NUMBER(peek(0)) || !IS_NUMBER(peek(1)) {
                    runtimeError("Operands must be numbers.")
                    return InterpretResult.RUNTIME_ERROR
                }
                b := AS_NUMBER(pop())
                a := AS_NUMBER(pop())
                push(NUMBER_VAL(a * b))
            case .NEGATE:
                if !IS_NUMBER(peek(0)) {
                    runtimeError("Operand must be a number.")
                    return InterpretResult.RUNTIME_ERROR
                } 
                push(NUMBER_VAL(-AS_NUMBER(pop())))
            case .NIL:
                push(NIL_VAL())
            case .NOT:
                push(BOOL_VAL(isFalsey(pop())))
            case .POP:
                pop()
            case .PRINT:
                printValue(pop())
                fmt.printf("\n")
            case .RETURN:
                result := pop()
                closeUpvalues(&frame.slots[0])
                vm.frameCount -= 1
                if vm.frameCount == 0 {
                    pop()
                    return InterpretResult.OK
                }

                //NJM: Check. Need to figure our what stackTop is right now
                //and what it should be after the return
                vm.stackTop -= frame.closure.function.arity + 1
                push(result)
                frame = &vm.frames[vm.frameCount - 1]
            case .SET_GLOBAL:
                name := AS_OBJSTRING(read_constant(frame))
                if tableSet(&vm.globals, name, peek(0)) {
                    tableDelete(&vm.globals, name)
                    runtimeError("Undefined variable '%s'.", name.str)
                    return InterpretResult.RUNTIME_ERROR
                }
            case .SET_LOCAL:
                slot := read_byte(frame)
                frame.slots[slot] = peek(0)
            case .SET_PROPERTY:
                if !IS_INSTANCE(peek(1)) {
                    runtimeError("Only instances have fields.")
                    return InterpretResult.RUNTIME_ERROR
                }
                instance := AS_INSTANCE(peek(1))
                tableSet(&instance.fields, read_string(frame), peek(0))
                value := pop()
                pop()
                push(value)
            case .SET_UPVALUE:
                slot := read_byte(frame)
                frame.closure.upvalues[slot].location^ = peek(0)
            case .SUBTRACT:
                if !IS_NUMBER(peek(0)) || !IS_NUMBER(peek(1)) {
                    runtimeError("Operands must be numbers.")
                    return InterpretResult.RUNTIME_ERROR
                }
                b := AS_NUMBER(pop())
                a := AS_NUMBER(pop())
                push(NUMBER_VAL(a - b))
            case.TRUE:
                push(BOOL_VAL(true))
            case .CONSTANT:
                constant := read_constant(frame)
                push(constant)
        }
    }
}

interpret :: proc(source: string) -> InterpretResult {
    function := compile(source)
    if function == nil do return InterpretResult.COMPILE_ERROR

    push(OBJ_VAL(function))
    closure := newClosure(function)
    pop()
    push(OBJ_VAL(closure))
    call(closure, 0)

    return run()
}

@(private="file")
read_byte :: proc(frame: ^CallFrame) -> (val: u8) {
    //frame := &vm.frames[vm.frameCount - 1]
    val = frame.closure.function.chunk.code[frame.ip]
    frame.ip += 1
    return
}

@(private="file")
read_constant :: proc(frame: ^CallFrame) -> Value {
    //frame := &vm.frames[vm.frameCount - 1]
    offset := read_byte(frame)
    return frame.closure.function.chunk.constants[offset]
}

@(private="file")
read_string :: proc(frame: ^CallFrame) -> ^ObjString {
    return AS_OBJSTRING(read_constant(frame))
}

@(private="file")
read_short :: proc(frame: ^CallFrame) -> (val: u16) {
    //frame := &vm.frames[vm.frameCount - 1]
    val = u16(frame.closure.function.chunk.code[frame.ip]) << 8 | u16(frame.closure.function.chunk.code[frame.ip+1])
    frame.ip += 2
    return
}

//NJM: Check with -false
@(private="file")
runtimeError :: proc(format: string, args: ..any) {
    fmt.fprintf(fd=os.stderr, fmt=format, args=args)
    fmt.fprintf(os.stderr, "\n")

    /*
    frame := &vm.frames[vm.frameCount - 1]
    inst_index := frame.ip - 1
    line := frame.function.chunk.lines[inst_index]
    fmt.fprintf(os.stderr, "[line %d] in script\n", line)
    */

    for i := vm.frameCount - 1; i >= 0; i = i-1 {
        frame := &vm.frames[i]
        function := frame.closure.function
        inst_index := frame.ip - i
        fmt.fprintf(os.stderr, "[line %d] in ", function.chunk.lines[inst_index])
        if function.name == nil {
            fmt.fprintf(os.stderr, "script\n")
        } else {
            fmt.fprintf(os.stderr, "%s()\n", function.name.str)
        }
    }

    resetStack()
}