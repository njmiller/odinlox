package odinlox

import "core:fmt"
import "core:os"
import "core:strings"

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
            //This should be just "\r\n" as input
            fmt.printf("\n")
            break
        }

        line = string(buf[:n])

        interpret(line)
    }
}

runFile :: proc(path: string) {
    source, success := os.read_entire_file_from_filename(path)
    if !success do os.exit(65)

    //Adding a newline character to the end so we can see the end of the last token without crashing
    source2 := strings.concatenate({string(source), "\r\n"})

    //result := interpret(string(source))
    result := interpret(source2)

    if result == InterpretResult.COMPILE_ERROR do os.exit(65)
    if result == InterpretResult.OK do os.exit(70)
}
