package odinlox

//NOTE: Array access seems faster than the Odin pointer offset stuff
//in the core library

import "core:fmt"

DEBUG_TRACE_EXECUTION :: ODIN_DEBUG
STACK_MAX :: 256

VM :: struct {
    chunk: ^Chunk,
    ip: int,
    stack: [STACK_MAX]Value,
    stackTop: int,
}

InterpretResult :: enum {
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR,
}

vm : VM

resetStack  :: proc() {
    vm.stackTop = 0
}

initVM :: proc() {
    resetStack()
}

freeVM :: proc() {

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

    for {
        when DEBUG_TRACE_EXECUTION {
            fmt.printf("       ")
            for slot := 0; slot < vm.stackTop; slot += 1 {
                fmt.printf("[ ")
                printValue(vm.stack[slot])
                fmt.printf(" ]")
            }
            fmt.printf("\n")
            disassembleInstruction(vm.chunk, vm.ip)
        }
        instruction = auto_cast read_byte()
        switch instruction {
            case .ADD:
                b := pop()
                a := pop()
                push(a + b)
            case .DIVIDE:
                b := pop()
                a := pop()
                push(a / b)
            case .MULTIPLY:
                b := pop()
                a := pop()
                push(a * b)
            case .NEGATE: 
                push(-pop())
            case .RETURN:
                printValue(pop())
                fmt.printf("\n")
                return .OK
            case .SUBTRACT:
                b := pop()
                a := pop()
                push(a - b)
            case .CONSTANT:
                constant := read_constant()
                push(constant)
        }
    }
}

interpret :: proc(source: string) -> InterpretResult {
    chunk : Chunk

    if !compile(source, &chunk) {
        freeChunk(&chunk)
        return .COMPILE_ERROR
    }

    vm.chunk = &chunk
    vm.ip = 0

    result := run()

    freeChunk(&chunk)
    return result
}

read_byte :: proc() -> (val: u8) {
    val = vm.chunk.code[vm.ip]
    vm.ip += 1
    return
}

read_constant :: proc() -> Value {
    offset := read_byte()
    return vm.chunk.constants[offset]
}