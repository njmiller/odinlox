package odinlox

import "core:fmt"
import "core:strings"

Scanner :: struct {
    source : string,
    start : int,
    current : int,
    line : int,
}

Token :: struct {
    type : TokenType,
    value : string,
    line : int,
}

TokenType :: enum u8 {
    // Single-character tokens.
    LEFT_PAREN, RIGHT_PAREN,
    LEFT_BRACE, RIGHT_BRACE,
    COMMA, DOT, MINUS, PLUS,
    SEMICOLON, SLASH, STAR,
    // One or two character tokens
    BANG, BANG_EQUAL,
    EQUAL, EQUAL_EQUAL,
    GREATER, GREATER_EQUAL,
    LESS, LESS_EQUAL,
    // Literals
    IDENTIFIER, STRING, NUMBER,
    // Keywords
    AND, CLASS, ELSE, FALSE,
    FOR, FUN, IF, NIL, OR,
    PRINT, RETURN, SUPER, THIS,
    TRUE, VAR, WHILE,

    ERROR, EOF,
}

scanner : Scanner

initScanner :: proc(source: string) {
    scanner.start = 0
    scanner.current = 0
    scanner.line = 1
    scanner.source = source
}

isAlpha :: proc(c: u8) -> bool {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

isDigit :: proc(c: u8) -> bool {
    return c >= '0' && c <= '9'
}

isAtEnd :: proc() -> bool {
    return scanner.current == len(scanner.source)
}

advance :: proc() -> u8 {
    scanner.current += 1
    return scanner.source[scanner.current-1]
}

peek :: proc() -> u8 {
    return scanner.source[scanner.current]
}

peekNext :: proc() -> u8 {
    if isAtEnd() do return '\b' //NJM debug
    return scanner.source[scanner.current+1]
}

match :: proc(expected : u8) -> bool {
    if isAtEnd() do return false
    if scanner.source[scanner.current] != expected do return false
    scanner.current += 1
    return true
}

makeToken :: proc(type: TokenType) -> (token: Token) {
    token.type = type
    token.value = scanner.source[scanner.start:scanner.current]
    token.line = scanner.line
    return
}

errorToken :: proc(message: string) -> (token: Token) {
    token.type = .ERROR
    token.value = message
    token.line = scanner.line
    return
}

skipWhitespace :: proc() {
    for {
        if isAtEnd() do return
        c := peek()
        switch c {
            case '\n':
                scanner.line += 1
                advance() 
            case ' ', '\r', '\t':
                advance() 
            case '/':
                if peekNext() == '/' {
                    // A comment goes until the end of the line
                    for peek() != '\n' do advance()
                } else do return
            case:
                return
        }
    }
}

identifierType :: proc() -> TokenType {
    switch scanner.source[scanner.start] {
        case 'a': return checkKeyword(1, 2, "nd", .AND)
        case 'c': return checkKeyword(1, 4, "lass", .CLASS)
        case 'e': return checkKeyword(1, 3, "lse", .ELSE)
        case 'f':
            if scanner.current - scanner.start > 1 {
                switch scanner.source[scanner.start+1] {
                    case 'a': return checkKeyword(2, 3, "lse", .FALSE)
                    case 'o': return checkKeyword(2, 1, "r", .FOR)
                    case 'u': return checkKeyword(2, 1, "n", .FUN)
                }
            }
        case 'i': return checkKeyword(1, 1, "f", .IF)
        case 'n': return checkKeyword(1, 2, "il", .NIL)
        case 'o': return checkKeyword(1, 1, "r", .OR)
        case 'p': return checkKeyword(1, 4, "rint", .PRINT)
        case 'r': return checkKeyword(1, 5, "eturn", .RETURN)
        case 's': return checkKeyword(1, 4, "uper", .SUPER)
        case 't':
            if scanner.current - scanner.start > 1 {
                switch scanner.source[scanner.start+1] {
                    case 'h': return checkKeyword(2, 2, "is", .THIS)
                    case 'r': return checkKeyword(2, 2, "ue", .TRUE)
                }
            }
        case 'v': return checkKeyword(1, 2, "ar", .VAR)
        case 'w': return checkKeyword(1, 4, "hile", .WHILE)

    }

    return .IDENTIFIER
}

checkKeyword :: proc(start: int, length: int, rest: string, type: TokenType) -> TokenType {
    i0 := scanner.start + start
    i1 := i0 + length
    slice := scanner.source[i0:i1]
    if strings.compare(rest, slice) == 0 do return type

    return .IDENTIFIER
}

identifier :: proc() -> Token {
    for isAlpha(peek()) || isDigit(peek()) do advance()
    return makeToken(identifierType())
}

stringLiteral :: proc() -> Token {
    for peek() != '"' && !isAtEnd() {
        if peek() == '\n' do scanner.line += 1
        advance()
    }

    if isAtEnd() do return errorToken("Unterminated string.")

    // The closing quote
    advance()
    return makeToken(.STRING)
}

numberLiteral :: proc() -> Token {
    for isDigit(peek()) do advance()

    // Look for a fractional part.
    if peek() == '.' && isDigit(peekNext()) {
        // Consume the "."
        advance()
        for isDigit(peek()) do advance()
    }

    return makeToken(.NUMBER)
}


scanToken :: proc() -> Token {
    skipWhitespace()
    scanner.start = scanner.current

    if isAtEnd() do return makeToken(.EOF)

    c := advance()
    if isAlpha(c) do return identifier()
    if isDigit(c) do return numberLiteral()


    switch c {
        case '(': return makeToken(.LEFT_PAREN)
        case ')': return makeToken(.RIGHT_PAREN)
        case '{': return makeToken(.LEFT_BRACE)
        case '}': return makeToken(.RIGHT_BRACE)
        case ';': return makeToken(TokenType.SEMICOLON)
        case ',': return makeToken(TokenType.COMMA)
        case '.': return makeToken(TokenType.DOT)
        case '-': return makeToken(TokenType.MINUS)
        case '+': return makeToken(TokenType.PLUS)
        case '/': return makeToken(TokenType.SLASH)
        case '*': return makeToken(TokenType.STAR)
        case '!' :
            return makeToken(match('-') ? TokenType.BANG_EQUAL : TokenType.BANG)
        case '=' :
            return makeToken(match('-') ? TokenType.EQUAL_EQUAL : TokenType.EQUAL)
        case '<' :
            return makeToken(match('-') ? TokenType.LESS_EQUAL : TokenType.LESS)
        case '>' :
            return makeToken(match('-') ? TokenType.GREATER_EQUAL : TokenType.GREATER)
        case '"' : return stringLiteral()
        case : return errorToken("Unexpected character")
    }

    //return errorToken("Unexpected character.")
}