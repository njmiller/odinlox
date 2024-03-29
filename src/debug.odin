package odinlox

import "core:fmt"

disassembleChunk :: proc(chunk: ^Chunk, name: string) {
    fmt.printf("== %s ==\n", name)

    for offset := 0; offset < len(chunk.code); {
        offset = disassembleInstruction(chunk, offset)
    }
}

disassembleInstruction :: proc(chunk: ^Chunk, offset: int) -> int {
    fmt.printf("%04d ", offset)
    if (offset > 0 && chunk.lines[offset] == chunk.lines[offset-1]) {
        fmt.printf("   | ")
    } else {
        fmt.printf("%4d ", chunk.lines[offset])
    }

    instruction : OpCode = auto_cast chunk.code[offset]
    switch instruction {
        case .ADD:
            return simpleInstruction("OP_ADD", offset)
        case .CALL:
            return byteInstruction("OP_CALL", chunk, offset)
        case .CLASS:
            return constantInstruction("OP_CLASS", chunk, offset)
        case .CLOSE_UPVALUE:
            return simpleInstruction("OP_CLOSE_UPVALUE", offset)
        case .CLOSURE:
            offset := offset + 1
            constant := chunk.code[offset]
            offset += 1
            fmt.printf("%-16s %4d ", "OP_CLOSURE", constant)
            printValue(chunk.constants[constant])
            fmt.printf("\n")

            function_ := AS_FUNCTION(chunk.constants[constant])
            for j := 0; j < function_.upvalueCount; j += 1 {
                isLocal := chunk.code[offset]
                offset += 1
                index := chunk.code[offset]
                offset += 1
                fmt.printf("%04d      |                     %s %d\n", offset-2, isLocal > 0 ? "local" : "upvalue", index)
            }
            return offset
        case .CONSTANT:
            return constantInstruction("OP_CONSTANT", chunk, offset)
        case .DEFINE_GLOBAL:
            return constantInstruction("OP_DEFINE_GLOBAL", chunk, offset)
        case .DIVIDE:
            return simpleInstruction("OP_DIVIDE", offset)
        case .EQUAL:
            return simpleInstruction("OP_EQUAL", offset)
        case .FALSE:
            return simpleInstruction("OP_FALSE", offset)
        case .GET_GLOBAL:
            return constantInstruction("OP_GET_GLOBAL", chunk, offset)
        case .GET_LOCAL:
            return byteInstruction("OP_GET_LOCAL", chunk, offset)
        case .GET_PROPERTY:
            return constantInstruction("OP_GET_PROPERTY", chunk, offset)
        case .GET_SUPER:
            return constantInstruction("OP_GET_SUPER", chunk, offset)
        case .GET_UPVALUE:
            return byteInstruction("OP_GET_UPVALUE", chunk, offset)
        case .GREATER:
            return simpleInstruction("OP_GREATER", offset)
        case .INHERIT:
            return simpleInstruction("OP_INHERIT", offset)
        case .INVOKE:
            return invokeInstruction("OP_INVOKE", chunk, offset)
        case .JUMP:
            return jumpInstruction("OP_JUMP", 1, chunk, offset)
        case .JUMP_IF_FALSE:
            return jumpInstruction("OP_JUMP_IF_FALSE", 1, chunk, offset)
        case .LESS:
            return simpleInstruction("OP_LESS", offset)
        case .LOOP:
            return jumpInstruction("OP_LOOP", -1, chunk, offset)
        case .METHOD:
            return constantInstruction("OP_METHOD", chunk, offset)
        case .MULTIPLY:
            return simpleInstruction("OP_MULTIPLY", offset)
        case .NEGATE:
            return simpleInstruction("OP_NEGATE", offset)
        case .NIL:
            return simpleInstruction("OP_NIL", offset)
        case .NOT:
            return simpleInstruction("OP_NOT", offset)
        case .POP:
            return simpleInstruction("OP_POP", offset)
        case .PRINT:
            return simpleInstruction("OP_PRINT", offset)
        case .RETURN:
            return simpleInstruction("OP_RETURN", offset)
        case .SET_GLOBAL:
            return constantInstruction("OP_SET_GLOBAL", chunk, offset)
        case .SET_LOCAL:
            return byteInstruction("OP_SET_LOCAL", chunk, offset)
        case .SET_PROPERTY:
            return constantInstruction("OP_SET_PROPERTY", chunk, offset)
        case .SET_UPVALUE:
            return byteInstruction("OP_SET_UPVALUE", chunk, offset)
        case .SUBTRACT:
            return simpleInstruction("OP_SUBTRACT", offset)
        case .SUPER_INVOKE:
            return invokeInstruction("OP_SUPER_INVOKE", chunk, offset)
        case .TRUE:
            return simpleInstruction("OP_TRUE", offset)
        case:
            fmt.printf("Unknown opcode %d\n", instruction)
            return offset + 1
    }
}

@(private="file")
byteInstruction :: proc(name: string, chunk: ^Chunk, offset: int) -> int {
    slot := chunk.code[offset + 1]
    fmt.printf("%-16s %4d\n", name, slot)
    return offset + 2
}

@(private="file")
constantInstruction :: proc(name: string, chunk: ^Chunk, offset: int) -> int {
    constant := chunk.code[offset+1]
    fmt.printf("%-16s %4d '", name, constant)
    printValue(chunk.constants[constant])
    fmt.printf("'\n")
    return offset + 2
}

@(private="file")
invokeInstruction :: proc(name: string, chunk: ^Chunk, offset: int) -> int {
    constant := chunk.code[offset+1]
    argCount := chunk.code[offset+2]
    fmt.printf("%-16s (%d args) %4d'", name, argCount, constant)
    printValue(chunk.constants[constant])
    fmt.printf("\n")
    return offset + 3
}

@(private="file")
jumpInstruction :: proc(name: string, sign: int, chunk: ^Chunk, offset: int) -> int {
    jump := u16(chunk.code[offset + 1]) << 8
    jump |= u16(chunk.code[offset + 2])
    fmt.printf("%-16s %4d -> %d\n", name, offset, offset + 3 + sign + int(jump))
    return offset + 3
}

@(private="file")
simpleInstruction :: proc(name: string, offset: int) -> int {
    fmt.printf("%s\n", name)
    return offset + 1
}

