package odinlox

import "core:fmt"

ValueType :: enum u8 {
    BOOL,
    NIL,
    NUMBER,
}

//Value :: distinct f64

Value :: struct {
    type : ValueType,
    data : union {
        bool,
        f64,
    },
}

//Boxing functions
BOOL_VAL :: proc(value: bool) -> Value { return Value{ValueType.BOOL, value} }
NIL_VAL :: proc() -> Value { return Value{ValueType.NIL, 0} }
NUMBER_VAL :: proc(value: f64) -> Value { return Value{ValueType.NUMBER, value} }

//Unboxing functions
AS_BOOL :: proc(value: Value) -> bool { return value.data.(bool) }
AS_NUMBER :: proc(value: Value) -> f64 { return value.data.(f64) }

//Check functions 
IS_BOOL :: proc(value: Value) -> bool { return value.type == ValueType.BOOL }
IS_NIL :: proc(value: Value) -> bool { return value.type == ValueType.NIL }
IS_NUMBER :: proc(value: Value) -> bool { return value.type == ValueType.NUMBER }

printValue :: proc(value: Value) {
    switch value.type {
        case .BOOL:
            fmt.printf(AS_BOOL(value) ? "true" : "false")
        case .NIL:
            fmt.printf("nil")
        case .NUMBER:
            fmt.printf("%g", AS_NUMBER(value))
    }
    
}
