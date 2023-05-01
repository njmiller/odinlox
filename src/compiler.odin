package odinlox

import "core:fmt"
import "core:os"
import "core:strconv"

DEBUG_PRINT_CODE :: ODIN_DEBUG
U8_MAX :: int(max(u8))

Parser :: struct {
    current: Token,
    previous: Token,
    hadError: bool,
    panicMode: bool,
}

Precedence :: enum u8 {
    NONE,
    ASSIGNMENT,
    OR,
    AND,
    EQUALITY,
    COMPARISON,
    TERM,
    FACTOR,
    UNARY,
    CALL,
    PRIMARY,
}

ParseRule :: struct {
    prefix: ParseFn,
    infix: ParseFn,
    precedence: Precedence,
}

ParseFn :: #type proc()

parser : Parser
compilingChunk : ^Chunk

rules : []ParseRule = {
    TokenType.LEFT_PAREN    = ParseRule{grouping, nil,    Precedence.NONE},
    TokenType.RIGHT_PAREN   = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.LEFT_BRACE    = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.RIGHT_BRACE   = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.COMMA         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.DOT           = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.MINUS         = ParseRule{unary,    binary, Precedence.TERM},
    TokenType.PLUS          = ParseRule{nil,      binary, Precedence.TERM},
    TokenType.SEMICOLON     = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.SLASH         = ParseRule{nil,      binary, Precedence.FACTOR},
    TokenType.STAR          = ParseRule{nil,      binary, Precedence.FACTOR},
    TokenType.BANG          = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.BANG_EQUAL    = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.EQUAL         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.EQUAL_EQUAL   = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.GREATER       = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.GREATER_EQUAL = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.LESS          = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.LESS_EQUAL    = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.IDENTIFIER    = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.STRING        = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.NUMBER        = ParseRule{number,   nil,    Precedence.NONE},
    TokenType.AND           = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.CLASS         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.ELSE          = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.FALSE         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.FOR           = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.FUN           = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.IF            = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.NIL           = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.OR            = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.PRINT         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.RETURN        = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.SUPER         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.THIS          = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.TRUE          = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.VAR           = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.WHILE         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.ERROR         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.EOF           = ParseRule{nil,      nil,    Precedence.NONE},
}

compile :: proc(source: string, chunk: ^Chunk) -> bool {
    initScanner(source)
    compilingChunk = chunk

    parser.hadError = false
    parser.panicMode = false

    advance()
    expression()
    consume(.EOF, "Expect end of expression.")
    endCompiler()
    return !parser.hadError
}

@(private="file")
advance :: proc() {
    parser.previous = parser.current
    for {
        parser.current = scanToken()
        if parser.current.type != .ERROR do break

        errorAtCurrent(parser.current.value)
    }
}

@(private="file")
consume :: proc(type: TokenType, message: string) {
    if parser.current.type == type {
        advance()
        return
    }

    errorAtCurrent(message)
}

@(private="file")
currentChunk :: proc() -> ^Chunk {
    return compilingChunk
}

@(private="file")
emitByte_op :: proc(bite: OpCode) {
    writeChunk(currentChunk(), bite, parser.previous.line)
}

@(private="file")
emitByte_u8 :: proc(bite: u8) {
    writeChunk(currentChunk(), bite, parser.previous.line)
}

@(private="file")
emitByte :: proc{emitByte_u8, emitByte_op}


//NJM : Will need to overload this when I get compile errors with OpCodes
@(private="file")
emitBytes_u8 :: proc(byte1: u8, byte2: u8) {
    emitByte(byte1)
    emitByte(byte2)
}

@(private="file")
emitBytes_op :: proc(byte1: OpCode, byte2: u8) {
    emitByte(byte1)
    emitByte(byte2)
}

@(private="file")
emitBytes :: proc{emitBytes_op, emitBytes_u8}

@(private="file")
emitConstant :: proc(value: Value) {
    emitBytes(OpCode.CONSTANT, makeConstant(value))
}

@(private="file")
emitReturn :: proc() {
    emitByte(OpCode.RETURN)
}

@(private="file")
endCompiler :: proc() {
    emitReturn()

    when DEBUG_PRINT_CODE {
        if !parser.hadError do disassembleChunk(currentChunk(), "code")
    }
}

@(private="file")
error :: proc(message: string) {
    errorAt(&parser.previous, message)
}

@(private="file")
errorAt :: proc(token: ^Token, message: string) {
    if parser.panicMode do return
    parser.panicMode = true
    fmt.fprintf(os.stderr, "[line %d] Error ", token.line)

    if token.type == .EOF {
        fmt.fprintf(os.stderr, " at end")
    } else if token.type == .ERROR {
        // Nothing
    } else {
        fmt.fprintf(os.stderr, "at %s", token.value)
    }

    fmt.fprintf(os.stderr, ": %s\n", message)
    parser.hadError = true
}

@(private="file")
errorAtCurrent :: proc(message: string) {
    errorAt(&parser.current, message)
}

@(private="file")
expression :: proc() {
    parsePrecedence(Precedence.ASSIGNMENT)
}

@(private="file")
getRule :: proc(type: TokenType) -> ^ParseRule {
    return &rules[type]
}

@(private="file")
grouping :: proc() {
    expression()
    consume(.RIGHT_PAREN, "Expect ')' after expression.")
}

@(private="file")
makeConstant :: proc(value: Value) -> u8 {
    constant := addConstant(currentChunk(), value)
    if constant > U8_MAX {
        error("Too many constants in one chunk.")
        return 0
    }

    return u8(constant)
}

@(private="file")
number :: proc() {
    value : Value = auto_cast strconv.atof(parser.previous.value)
    emitConstant(value)
}

@(private="file")
parsePrecedence :: proc(precedence: Precedence) {
    advance()
    prefixRule := getRule(parser.previous.type).prefix
    if prefixRule == nil {
        error("Expect expression.")
        return
    }

    prefixRule()

    for precedence <= getRule(parser.current.type).precedence {
        advance()
        infixRule := getRule(parser.previous.type).infix
        infixRule()
    }
}

@(private="file")
unary :: proc() {
    operatorType := parser.previous.type
    
    // Compile the operand
    parsePrecedence(Precedence.UNARY)

    // Emit the operator instruction.
    #partial switch operatorType {
        case .MINUS: 
            emitByte(OpCode.NEGATE)
    }
}

@(private="file")
binary :: proc() {
    operatorType := parser.previous.type
    rule := getRule(operatorType)
    parsePrecedence(cast(Precedence)(int(rule.precedence)+1))

    #partial switch operatorType {
        case TokenType.PLUS:     emitByte(OpCode.ADD)
        case TokenType.MINUS:    emitByte(OpCode.SUBTRACT)
        case TokenType.STAR:     emitByte(OpCode.MULTIPLY)
        case TokenType.SLASH:    emitByte(OpCode.DIVIDE)
    }
}