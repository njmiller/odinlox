package odinlox

import "core:fmt"

compile :: proc(source: string) {
    initScanner(source)
    line := -1

    for {
        token := scanToken()
        if token.line != line {
            fmt.printf("%4d ", token.line)
            line = token.line
        } else {
            fmt.printf("   | ")
        }
        fmt.printf("%2d '%s'\n", token.type, source[token.start:(token.start+token.length)])
        if token.type == .EOF do break
    }
}