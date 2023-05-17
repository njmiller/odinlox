package odinlox

//NOTE: Array access seems faster than the Odin pointer offset stuff
//in the core library

import "core:fmt"
import "core:os"
import "core:strings"

DEBUG_TRACE_EXECUTION :: ODIN_DEBUG
FRAMES_MAX :: 64
STACK_MAX :: FRAMES_MAX * U8_COUNT

//TODO: Check what I need for slots
CallFrame :: struct {
    function: ^ObjFunction,
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
    objects: ^Obj,
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
}

initVM :: proc() {
    resetStack()
    vm.objects = nil
    initTable(&vm.strings)
    initTable(&vm.globals)
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
concatenate :: proc() {
    b := AS_STRING(pop())
    a := AS_STRING(pop())
    
    c := strings.concatenate( {a, b} )

    result := takeString(c)
    push(OBJ_VAL(result))

    //NJM: Check. I don't think I need to delete a or b since they are part of the
    //objects which will be garbage collected. C is cloned for result so we can delete it
    delete(c)
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
            disassembleInstruction(&frame.function.chunk, frame.ip)
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
            case .DEFINE_GLOBAL:
                name := AS_OBJSTRING(read_constant(frame))
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
                // Exit interpreter
                return .OK
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
    frame := &vm.frames[vm.frameCount]
    vm.frameCount += 1
    frame.function = function
    frame.ip = 0
    frame.slots = vm.stack[:]

    return run()
}

@(private="file")
read_byte :: proc(frame: ^CallFrame) -> (val: u8) {
    //frame := &vm.frames[vm.frameCount - 1]
    val = frame.function.chunk.code[frame.ip]
    frame.ip += 1
    return
}

@(private="file")
read_constant :: proc(frame: ^CallFrame) -> Value {
    //frame := &vm.frames[vm.frameCount - 1]
    offset := read_byte(frame)
    return frame.function.chunk.constants[offset]
}

@(private="file")
read_short :: proc(frame: ^CallFrame) -> (val: u16) {
    //frame := &vm.frames[vm.frameCount - 1]
    val = u16(frame.function.chunk.code[frame.ip]) << 8 | u16(frame.function.chunk.code[frame.ip+1])
    frame.ip += 2
    return
}

//NJM: Check with -false
@(private="file")
runtimeError :: proc(format: string, args: ..any) {
    fmt.fprintf(fd=os.stderr, fmt=format, args=args)
    fmt.fprintf(os.stderr, "\n")

    frame := &vm.frames[vm.frameCount - 1]
    inst_index := frame.ip - 1
    line := frame.function.chunk.lines[inst_index]
    fmt.fprintf(os.stderr, "[line %d] in script\n", line)
    resetStack()
}