package odinlox

import "core:fmt"

OpCode :: enum u8 {
    ADD,
    CALL,
    CLASS,
    CLOSE_UPVALUE,
    CLOSURE,
    CONSTANT,
    DEFINE_GLOBAL,
    DIVIDE,
    EQUAL,
    FALSE,
    GET_GLOBAL,
    GET_LOCAL,
    GET_PROPERTY,
    GET_SUPER,
    GET_UPVALUE,
    GREATER,
    INHERIT,
    INVOKE,
    JUMP,
    JUMP_IF_FALSE,
    LESS,
    LOOP,
    METHOD,
    MULTIPLY,
    NEGATE,
    NIL,
    NOT,
    POP,
    PRINT,
    RETURN,
    SET_GLOBAL,
    SET_LOCAL,
    SET_PROPERTY,
    SET_UPVALUE,
    SUBTRACT,
    SUPER_INVOKE,
    TRUE,
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

initChunk :: proc(chunk: ^Chunk) {
    // Do nothing since everything is a dynamic array
    return
}

freeChunk :: proc(chunk: ^Chunk) {
    delete(chunk.code)
    delete(chunk.constants)
    delete(chunk.lines)
}