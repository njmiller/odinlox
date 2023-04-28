package odinlox

import "core:fmt"
import "core:os"

main :: proc() {
    chunk : Chunk

    initVM()

    if len(os.args) == 1 {
        repl()
    } else if len(os.args) == 2 {
        runFile(os.args[1])
    } else {
        fmt.eprintln("Usage: odinlox [path]")
        os.exit(64)
    }

    freeVM()
}

repl :: proc() {
    buf : [1024]u8
    line : string
    for {
        fmt.printf("> ")

        n, err := os.read(os.stdin, buf[:])
        if (n == 2) {
            //I assume this means just '\n' as input
            fmt.printf("\n")
            break
        }

        // Remove the newline bytes at the end of the string
        line = string(buf[:(n-2)])
        interpret(line)
    }
}

runFile :: proc(path: string) {
    source, success := os.read_entire_file_from_filename(path)
    if !success do os.exit(65)
    result := interpret(string(source))
    
    if result == InterpretResult.COMPILE_ERROR do os.exit(65)
    if result == InterpretResult.OK do os.exit(70)
}