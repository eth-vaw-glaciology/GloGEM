FUNCTION roundto025075, p
compile_opt idl2
; Round to the nearest 0.25 or 0.75
    ; Separate sign and work with absolute value
    sign = (p GE 0) ? 1.0 : -1.0
    val = ABS(p)
    ; Split into integer and fractional parts
    base = FLOOR(val)  ; integer part
    frac = val - base  ; fractional part
    ; Round fraction to 0.25 or 0.75
    IF frac LT 0.5 THEN result = base + 0.25 ELSE result = base + 0.75
    RETURN, result * sign
 END