package odinlox

import "core:fmt"
import "core:strings"

NAN_BOXING :: #config(NAN_BOXING, false)

when NAN_BOXING {
    Value :: distinct u64
    QNAN : Value : 0x7ffc000000000000
    SIGN_BIT : Value : 0x8000000000000000

    TAG_NIL : Value : 1
    TAG_FALSE : Value : 2
    TAG_TRUE : Value : 3

    FALSE_VAL :: QNAN | TAG_FALSE
    TRUE_VAL :: QNAN | TAG_TRUE
    
    NUMBER_VAL :: proc(num: f64) -> Value { return transmute(Value) num }
    BOOL_VAL :: proc(b: bool) -> Value { return b ? TRUE_VAL : FALSE_VAL }
    NIL_VAL :: proc() -> Value {return QNAN | TAG_NIL}
    OBJ_VAL :: proc(obj: ^Obj) -> Value { return SIGN_BIT | QNAN | cast(Value) uintptr(obj)}

    AS_NUMBER :: proc(value: Value) -> f64 { return transmute(f64) value }
    AS_BOOL :: proc(value: Value) -> bool { return value == TRUE_VAL }
    AS_OBJ :: proc(value: Value) -> ^Obj { return cast(^Obj) uintptr(value & ~(SIGN_BIT | QNAN)) }

    IS_BOOL :: proc(value: Value) -> bool { return (value | 1) == TRUE_VAL}
    IS_NUMBER :: proc(value: Value) -> bool { return (value & QNAN) != QNAN }
    IS_NIL :: proc(value: Value) -> bool { return value == NIL_VAL() }
    IS_OBJ :: proc(value: Value) -> bool { return (value & (QNAN | SIGN_BIT)) == (QNAN | SIGN_BIT) }

    printValue :: proc(value: Value) {
        if IS_BOOL(value) {
            fmt.printf(AS_BOOL(value) ? "true" : "false")
        } else if IS_NIL(value) {
            fmt.printf("nil")
        } else if IS_NUMBER(value) {
            fmt.printf("%g", AS_NUMBER(value))
        } else if IS_OBJ(value) {
            printObject(value)
        }
    }

    valuesEqual :: proc(a: Value, b: Value) -> bool { 
        if IS_NUMBER(a) && IS_NUMBER(b) {
            return AS_NUMBER(a) == AS_NUMBER(b)
        }
        return a == b
    }
} else {
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
}