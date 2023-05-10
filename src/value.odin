package odinlox

import "core:fmt"
import "core:strings"

ValueType :: enum u8 {
    BOOL,
    NIL,
    NUMBER,
    OBJ,
}

Value :: struct {
    type : ValueType,
    data : union {
        bool,
        f64,
        ^Obj,
    },
}

//Boxing functions
BOOL_VAL :: proc(value: bool) -> Value { return Value{ValueType.BOOL, value} }
NIL_VAL :: proc() -> Value { return Value{ValueType.NIL, 0} }
NUMBER_VAL :: proc(value: f64) -> Value { return Value{ValueType.NUMBER, value} }
OBJ_VAL :: proc(value: ^Obj) -> Value { return Value{ValueType.OBJ, value} }

//Unboxing functions
AS_BOOL :: proc(value: Value) -> bool { return value.data.(bool) }
AS_NUMBER :: proc(value: Value) -> f64 { return value.data.(f64) }
AS_OBJ :: proc(value: Value) -> ^Obj { return value.data.(^Obj) }

//Check functions 
IS_BOOL :: proc(value: Value) -> bool { return value.type == ValueType.BOOL }
IS_NIL :: proc(value: Value) -> bool { return value.type == ValueType.NIL }
IS_NUMBER :: proc(value: Value) -> bool { return value.type == ValueType.NUMBER }
IS_OBJ :: proc(value: Value) -> bool { return value.type == ValueType.OBJ }

printValue :: proc(value: Value) {
    switch value.type {
        case .BOOL:
            fmt.printf(AS_BOOL(value) ? "true" : "false")
        case .NIL:
            fmt.printf("nil")
        case .NUMBER:
            fmt.printf("%g", AS_NUMBER(value))
        case .OBJ:
            printObject(value)
    } 
}

valuesEqual :: proc(a: Value, b: Value) -> bool {
    if a.type != b.type do return false
    switch a.type {
        case .BOOL: return AS_BOOL(a) == AS_BOOL(b)
        case .NIL: return true
        case .NUMBER: return AS_NUMBER(a) == AS_NUMBER(b)
        case .OBJ: return AS_OBJ(a) == AS_OBJ(b)
    }
    return false //Unreachable
}
