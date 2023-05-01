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
        case .CONSTANT:
            return constantInstruction("OP_CONSTANT", chunk, offset)
        case .DIVIDE:
            return simpleInstruction("OP_DIVIDE", offset)
        case .MULTIPLY:
            return simpleInstruction("OP_MULTIPLY", offset)
        case .NEGATE:
            return simpleInstruction("OP_NEGATE", offset)
        case .RETURN:
            return simpleInstruction("OP_RETURN", offset)
        case .SUBTRACT:
            return simpleInstruction("OP_SUBTRACT", offset)
        case:
            fmt.printf("Unknown opcode %d\n", instruction)
            return offset + 1
    }
}

constantInstruction :: proc(name: string, chunk: ^Chunk, offset: int) -> int {
    constant := chunk.code[offset+1]
    fmt.printf("%-16s %4d '", name, constant)
    printValue(chunk.constants[constant])
    fmt.printf("'\n")
    return offset + 2
}

simpleInstruction :: proc(name: string, offset: int) -> int {
    fmt.printf("%s\n", name)
    return offset + 1
}

