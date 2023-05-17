package odinlox

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

DEBUG_PRINT_CODE :: ODIN_DEBUG
U8_MAX :: int(max(u8))
U16_MAX :: int(max(u16))
U8_COUNT :: U8_MAX + 1

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

Local :: struct {
    name: Token,
    depth: int,
}

FunctionType :: enum u8 {
    FUNCTION,
    SCRIPT,
}

Compiler :: struct {
    function: ^ObjFunction,
    type: FunctionType,
    locals: [U8_COUNT]Local,
    localCount: int,
    scopeDepth: int,
}

ParseFn :: #type proc(canAssign: bool)

parser : Parser
current : ^Compiler = nil
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
    TokenType.BANG          = ParseRule{unary,    nil,    Precedence.NONE},
    TokenType.BANG_EQUAL    = ParseRule{nil,      binary, Precedence.EQUALITY},
    TokenType.EQUAL         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.EQUAL_EQUAL   = ParseRule{nil,      binary, Precedence.EQUALITY},
    TokenType.GREATER       = ParseRule{nil,      binary, Precedence.COMPARISON},
    TokenType.GREATER_EQUAL = ParseRule{nil,      binary, Precedence.COMPARISON},
    TokenType.LESS          = ParseRule{nil,      binary, Precedence.COMPARISON},
    TokenType.LESS_EQUAL    = ParseRule{nil,      binary, Precedence.COMPARISON},
    TokenType.IDENTIFIER    = ParseRule{variable, nil,    Precedence.NONE},
    TokenType.STRING        = ParseRule{stringf,  nil,    Precedence.NONE},
    TokenType.NUMBER        = ParseRule{number,   nil,    Precedence.NONE},
    TokenType.AND           = ParseRule{nil,      and_,   Precedence.AND},
    TokenType.CLASS         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.ELSE          = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.FALSE         = ParseRule{literal,  nil,    Precedence.NONE},
    TokenType.FOR           = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.FUN           = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.IF            = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.NIL           = ParseRule{literal,  nil,    Precedence.NONE},
    TokenType.OR            = ParseRule{nil,      or_,    Precedence.OR},
    TokenType.PRINT         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.RETURN        = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.SUPER         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.THIS          = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.TRUE          = ParseRule{literal,  nil,    Precedence.NONE},
    TokenType.VAR           = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.WHILE         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.ERROR         = ParseRule{nil,      nil,    Precedence.NONE},
    TokenType.EOF           = ParseRule{nil,      nil,    Precedence.NONE},
}

compile :: proc(source: string) -> ^ObjFunction {
    initScanner(source)
    compiler : Compiler
    initCompiler(&compiler, FunctionType.SCRIPT)

    parser.hadError = false
    parser.panicMode = false

    advance()
    for !match(TokenType.EOF) do declaration()
    //expression()
    //consume(.EOF, "Expect end of expression.")
    function := endCompiler()
    return parser.hadError ? nil : function
}

@(private="file")
initCompiler :: proc(compiler: ^Compiler, type: FunctionType) {
    compiler.function = nil
    compiler.type = type
    compiler.localCount = 0
    compiler.scopeDepth = 0
    compiler.function = newFunction()
    current = compiler

    local := &current.locals[current.localCount]
    current.localCount += 1
    local.depth = 0
    local.name.value = ""
}

@(private="file")
addLocal :: proc(name: Token) {
    if current.localCount == U8_COUNT {
        error("Too many local variables in function.")
        return
    }

    local := &current.locals[current.localCount]
    current.localCount += 1
    local.name = name
    local.depth = -1
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
and_ :: proc(canAssign: bool) {
    endJump := emitJump(OpCode.JUMP_IF_FALSE)

    emitByte(OpCode.POP)
    parsePrecedence(Precedence.AND)

    patchJump(endJump)
}

@(private="file")
beginScope :: proc() {
    current.scopeDepth += 1
}

@(private="file")
block :: proc() {
    for !check(TokenType.RIGHT_BRACE) && !check(TokenType.EOF) {
        declaration()
    }

    consume(TokenType.RIGHT_BRACE, "Expect '}' after block.")
}

@(private="file")
check :: proc(type: TokenType) -> bool {
    return parser.current.type == type
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
    return &current.function.chunk
}

@(private="file")
declaration :: proc() {
    if match(TokenType.VAR) {
        varDeclaration()
    } else {
        statement()
    }

    if parser.panicMode do synchronize()
}

@(private="file")
declareVariable :: proc() {
    if current.scopeDepth == 0 do return

    name := &parser.previous
    for i := current.localCount - 1; i >= 0; i -= 1 {
        local := &current.locals[i]
        if local.depth != -1 && local.depth < current.scopeDepth do break

        if identifiersEqual(name, &local.name) {
            error("Alread a variable with this name in this scope.")
        }
    }

    addLocal(name^)
}

@(private="file")
defineVariable :: proc(global: u8) {
    if current.scopeDepth > 0 {
        markInitialized()
        return
    }

    emitBytes(OpCode.DEFINE_GLOBAL, global)
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
emitBytes_opop :: proc(byte1: OpCode, byte2: OpCode) {
    emitByte(byte1)
    emitByte(byte2)
}

@(private="file")
emitBytes :: proc{emitBytes_opop, emitBytes_op, emitBytes_u8}

@(private="file")
emitConstant :: proc(value: Value) {
    emitBytes(OpCode.CONSTANT, makeConstant(value))
}

@(private="file")
emitJump :: proc(instruction: OpCode) -> int {
    emitByte(instruction)
    emitByte(0xff)
    emitByte(0xff)
    return len(currentChunk().code) - 2
}

@(private="file")
emitLoop :: proc(loopStart: int) {
    emitByte(OpCode.LOOP)

    offset := len(currentChunk().code) - loopStart + 2
    if offset > U16_MAX do error("Loop body too large.")

    emitByte(u8((offset >> 8)) & 0xff)
    emitByte(u8(offset & 0xff))
}

@(private="file")
emitReturn :: proc() {
    emitByte(OpCode.RETURN)
}

@(private="file")
endCompiler :: proc() -> ^ObjFunction {
    emitReturn()
    function := current.function

    when DEBUG_PRINT_CODE {
        name := function.name != nil ? function.name.str : "<script>"
        if !parser.hadError do disassembleChunk(currentChunk(), name)
    }

    return function
}

@(private="file")
endScope :: proc() {
    current.scopeDepth -= 1

    for current.localCount > 0 && current.locals[current.localCount - 1].depth > current.scopeDepth {
        emitByte(OpCode.POP)
        current.localCount -= 1
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
expressionStatement :: proc() {
    expression()
    consume(TokenType.SEMICOLON, "Exprec ';' after expression.")
    emitByte(OpCode.POP)
}

@(private="file")
forStatement :: proc() {
    beginScope()
    consume(TokenType.LEFT_PAREN, "Expect '(' after 'for'.")
    if match(TokenType.SEMICOLON) {
        // No initializer
    } else if match(TokenType.VAR) {
        varDeclaration()
    } else {
        expressionStatement()
    }

    loopStart := len(currentChunk().code)
    exitJump := -1
    if !match(TokenType.SEMICOLON) {
        expression()
        consume(TokenType.SEMICOLON, "Expect ';' after loop condition.")

        // Jump out of the loop if the condition is false
        exitJump = emitJump(OpCode.JUMP_IF_FALSE)
        emitByte(OpCode.POP)
    }

    if !match(TokenType.RIGHT_PAREN) {
        bodyJump := emitJump(OpCode.JUMP)
        incrementStart := len(currentChunk().code)
        expression()
        emitByte(OpCode.POP)
        consume(TokenType.RIGHT_PAREN, "Expect ')' after for clauses.")

        emitLoop(loopStart)
        loopStart = incrementStart
        patchJump(bodyJump)
    }

    statement()
    emitLoop(loopStart)

    if exitJump != -1 {
        patchJump(exitJump)
        emitByte(OpCode.POP)
    }

    endScope()
}

@(private="file")
getRule :: proc(type: TokenType) -> ^ParseRule {
    return &rules[type]
}

@(private="file")
grouping :: proc(canAssign: bool) {
    expression()
    consume(.RIGHT_PAREN, "Expect ')' after expression.")
}

@(private="file")
identifierConstant :: proc(name: ^Token) -> u8 {
    return makeConstant(OBJ_VAL(copyString(name.value)))
}

@(private="file")
identifiersEqual :: proc(a: ^Token, b: ^Token) -> bool {
    if len(a.value) != len(b.value) do return false
    return strings.compare(a.value, b.value) == 0
}

@(private="file")
ifStatement :: proc() {
    consume(TokenType.LEFT_PAREN, "Expect '(' after 'if'.")
    expression()
    consume(TokenType.RIGHT_PAREN, "Expext ')' after condition.")

    thenJump := emitJump(OpCode.JUMP_IF_FALSE)
    emitByte(OpCode.POP)
    statement()

    elseJump := emitJump(OpCode.JUMP)

    patchJump(thenJump)
    emitByte(OpCode.POP)

    if match(TokenType.ELSE) do statement()

    patchJump(elseJump)
}

@(private="file")
literal :: proc(canAssign: bool) {
    #partial switch parser.previous.type {
        case .FALSE:
            emitByte(OpCode.FALSE)
        case .NIL:
            emitByte(OpCode.NIL)
        case .TRUE:
            emitByte(OpCode.TRUE)
    }
    return //unreachable
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
markInitialized :: proc() {
    current.locals[current.localCount - 1].depth = current.scopeDepth
}

@(private="file")
match :: proc(type: TokenType) -> bool {
    if !check(type) do return false
    advance()
    return true
}

@(private="file")
namedVariable :: proc(name: Token, canAssign: bool) {
    name := name //NJM, TODO: See if this works so we can take pointer to name
    getOp, setOp : OpCode

    arg := resolveLocal(current, &name)
    if arg != -1 {
        getOp = OpCode.GET_LOCAL
        setOp = OpCode.SET_LOCAL
    } else {
        arg = int(identifierConstant(&name))
        getOp = OpCode.GET_GLOBAL
        setOp = OpCode.SET_GLOBAL
    }

    if canAssign && match(TokenType.EQUAL) {
        expression()
        emitBytes(setOp, u8(arg))
    } else {
        emitBytes(getOp, u8(arg))
    }
}

@(private="file")
number :: proc(canAssign: bool) {
    value := strconv.atof(parser.previous.value)
    emitConstant(NUMBER_VAL(value))
}

@(private="file")
or_ :: proc(canAssign: bool) {
    elseJump := emitJump(OpCode.JUMP_IF_FALSE)
    endJump := emitJump(OpCode.JUMP)

    patchJump(elseJump)
    emitByte(OpCode.POP)

    parsePrecedence(Precedence.OR)
    patchJump(endJump)
}

@(private="file")
patchJump :: proc(offset: int) {
    // -2 to adjust for the bytecode for the jump offset itself
    jump := len(currentChunk().code) - offset - 2

    if jump > U8_MAX {
        error("Too much code to jump over.")
    }

    currentChunk().code[offset] = (u8(jump) >> 8) & 0xff
    currentChunk().code[offset+1] = u8(jump) & 0xff
}

@(private="file")
parsePrecedence :: proc(precedence: Precedence) {
    advance()
    prefixRule := getRule(parser.previous.type).prefix
    if prefixRule == nil {
        error("Expect expression.")
        return
    }

    canAssign := precedence <= Precedence.ASSIGNMENT
    prefixRule(canAssign)

    for precedence <= getRule(parser.current.type).precedence {
        advance()
        infixRule := getRule(parser.previous.type).infix
        infixRule(canAssign)
    }
}

@(private="file")
parseVariable :: proc(errorMessage: string) -> u8 {
    consume(TokenType.IDENTIFIER, errorMessage)

    declareVariable()
    if current.scopeDepth > 0 do return 0

    return identifierConstant(&parser.previous)
}

@(private="file")
printStatement :: proc() {
    expression()
    consume(TokenType.SEMICOLON, "Expect ';' after value.")
    emitByte(OpCode.PRINT)
}

@(private="file")
resolveLocal :: proc(compiler: ^Compiler, name: ^Token) -> int {
    for i := compiler.localCount - 1 ; i >= 0 ; i -= 1 {
        local := &compiler.locals[i]
        if identifiersEqual(name, &local.name) {
            if local.depth == -1 {
                error("Can't read local variables in its initializer.")
            }
            return i
        }
    }

    return -1
}

@(private="file")
statement :: proc() {
    if match(TokenType.PRINT) {
        printStatement()
    } else if match(TokenType.FOR) {
        forStatement()
    } else if match(TokenType.IF) {
        ifStatement()
    } else if match(TokenType.LEFT_BRACE) {
        beginScope()
        block()
        endScope()
    } else if match(TokenType.WHILE) {
        whileStatement()
    } else {
        expressionStatement()
    }
}

@(private="file")
stringf :: proc(canAssign: bool) {
    str := parser.previous.value[1:(len(parser.previous.value)-1)]
    emitConstant(OBJ_VAL(copyString(str)))
}

@(private="file")
synchronize :: proc() {
    parser.panicMode = false

    for parser.current.type != TokenType.EOF {
        if parser.previous.type == TokenType.SEMICOLON do return
        #partial switch parser.current.type {
            case .CLASS, .FUN, .VAR, .FOR, .IF, .WHILE, .PRINT, .RETURN:
                return
        }

        advance()
    }
}

@(private="file")
unary :: proc(canAssign: bool) {
    operatorType := parser.previous.type
    
    // Compile the operand
    parsePrecedence(Precedence.UNARY)

    // Emit the operator instruction.
    #partial switch operatorType {
        case .BANG:
            emitByte(OpCode.NOT)
        case .MINUS: 
            emitByte(OpCode.NEGATE)
    }
    return //Unreachable
}

@(private="file")
varDeclaration :: proc() {
    global := parseVariable("Expect variable name.")

    if match(TokenType.EQUAL) {
        expression()
    } else {
        emitByte(OpCode.NIL)
    }
    consume(TokenType.SEMICOLON, "Expect ';' after variable declaration.")

    defineVariable(global)
}

@(private="file")
variable :: proc(canAssign: bool) {
    namedVariable(parser.previous, canAssign)
}

@(private="file")
whileStatement :: proc() {
    loopStart := len(currentChunk().code)
    consume(TokenType.LEFT_PAREN, "Expect '(' after 'while'.")
    expression()
    consume(TokenType.RIGHT_PAREN, "Expect ')' after condition.")

    exitJump := emitJump(OpCode.JUMP_IF_FALSE)
    emitByte(OpCode.POP)
    statement()
    emitLoop(loopStart)

    patchJump(exitJump)
    emitByte(OpCode.POP)
}

@(private="file")
binary :: proc(canAssign: bool) {
    operatorType := parser.previous.type
    rule := getRule(operatorType)
    parsePrecedence(cast(Precedence)(int(rule.precedence)+1))

    #partial switch operatorType {
        case .BANG_EQUAL: emitBytes(OpCode.EQUAL, OpCode.NOT)
        case .EQUAL_EQUAL: emitByte(OpCode.EQUAL)
        case .GREATER : emitByte(OpCode.GREATER)
        case .GREATER_EQUAL : emitBytes(OpCode.LESS, OpCode.NOT)
        case .LESS : emitByte(OpCode.LESS)
        case .LESS_EQUAL : emitBytes(OpCode.GREATER, OpCode.NOT)
        case .PLUS:     emitByte(OpCode.ADD)
        case .MINUS:    emitByte(OpCode.SUBTRACT)
        case .STAR:     emitByte(OpCode.MULTIPLY)
        case .SLASH:    emitByte(OpCode.DIVIDE)
    }
}