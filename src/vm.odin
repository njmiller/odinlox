package odinlox

//NOTE: Array access seems faster than the Odin pointer offset stuff
//in the core library

import "core:fmt"
import "core:os"

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

@(private="file")
isFalsey :: proc(value: Value) -> bool {
    return IS_NIL(value) || (IS_BOOL(value) && !AS_BOOL(value))
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
                if !IS_NUMBER(peek(0)) || !IS_NUMBER(peek(1)) {
                    runtimeError("Operands must be numbers.")
                    return InterpretResult.RUNTIME_ERROR
                }
                b := AS_NUMBER(pop())
                a := AS_NUMBER(pop())
                push(NUMBER_VAL(a + b))
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
            case .LESS:
                if !IS_NUMBER(peek(0)) || !IS_NUMBER(peek(1)) {
                    runtimeError("Operands must be numbers.")
                    return InterpretResult.RUNTIME_ERROR
                }
                b := AS_NUMBER(pop())
                a := AS_NUMBER(pop())
                push(BOOL_VAL(a < b))
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
            case .RETURN:
                printValue(pop())
                fmt.printf("\n")
                return .OK
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

valuesEqual :: proc(a: Value, b: Value) -> bool {
    if a.type != b.type do return false
    switch a.type {
        case .BOOL: return AS_BOOL(a) == AS_BOOL(b)
        case .NIL: return true
        case .NUMBER: return AS_NUMBER(a) == AS_NUMBER(b)
    }
    return false //Unreachable
}
//NJM: Check with -false
@(private="file")
runtimeError :: proc(format: string, args: ..any) {
    fmt.fprintf(fd=os.stderr, fmt=format, args=args)
    fmt.fprintf(os.stderr, "\n")

    inst_index := vm.ip - 1
    line := vm.chunk.lines[inst_index]
    fmt.fprintf(os.stderr, "[line %d] in script\n", line)
    resetStack()
}