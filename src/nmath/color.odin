package nmath

Color :: [4]f32

Red :: Color{1, 0, 0, 1}
Green :: Color{0, 1, 0, 1}
Blue :: Color{0, 0, 1, 1}
Brown :: Color{0.588, 0.294, 0, 1}

color_brightness :: proc(color: Color, factor: f32) -> (out: Color) {
    factor := clamp(factor, -1, 1)

    if factor < 0 {
        factor = 1 + factor
        out.rgb = color.rgb * factor
    } else {
        out.rgb = (1 - color.rgb) * factor + color.rgb
    }

    out.a = color.a

    return
}