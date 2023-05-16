package odinlox

import "core:fmt"

OpCode :: enum u8 {
    ADD,
    CONSTANT,
    DEFINE_GLOBAL,
    DIVIDE,
    EQUAL,
    FALSE,
    GET_GLOBAL,
    GET_LOCAL,
    GREATER,
    JUMP,
    JUMP_IF_FALSE,
    LESS,
    LOOP,
    MULTIPLY,
    NEGATE,
    NIL,
    NOT,
    POP,
    PRINT,
    SET_GLOBAL,
    SET_LOCAL,
    RETURN,
    TRUE,
    SUBTRACT,
}

Chunk :: struct {
    code : [dynamic]u8,
    constants : [dynamic]Value,
    lines : [dynamic]int,
}

@(private="file")
writeChunk_u8 :: proc(chunk: ^Chunk, bite: u8, line: int) {
    append(&chunk.code, bite)
    append(&chunk.lines, line)
}

@(private="file")
writeChunk_op :: proc(chunk: ^Chunk, bite: OpCode, line: int) {
    writeChunk_u8(chunk, u8(bite), line)
}

@(private="file")
writeChunk_int :: proc(chunk: ^Chunk, bite: int, line: int) {
    writeChunk_u8(chunk, u8(bite), line)
}

writeChunk :: proc{
    writeChunk_u8,
    writeChunk_op,
    writeChunk_int,
}

addConstant :: proc(chunk: ^Chunk, value: Value) -> int {
    append(&chunk.constants, value)
    return len(chunk.constants) - 1
}

freeChunk :: proc(chunk: ^Chunk) {
    delete(chunk.code)
    delete(chunk.constants)
    delete(chunk.lines)
}