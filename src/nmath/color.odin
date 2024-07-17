package nmath

import glm "core:math/linalg/glsl"

Color :: [4]u8

Red        :: Color{255, 0, 0, 255}
LightRed   :: Color{255, 100, 100, 255}
Green      :: Color{0, 255, 0, 255}
LightGreen :: Color{100, 255, 100, 255}
Blue       :: Color{0, 0, 255, 255}
LightBlue  :: Color{100, 100, 255, 255}

Brown :: Color{140, 70, 19, 255}

Black :: Color{0, 0, 0, 255}
White :: Color{255, 255, 255, 255}

color_to_vec4 :: proc(c: Color) -> glm.vec4 {
    return {f32(c.r), f32(c.g), f32(c.b), f32(c.a)} / 255
}

vec4_to_color :: proc(v: glm.vec4) -> Color {
    v := 255 * v
    return {u8(v.r), u8(v.g), u8(v.b), u8(v.a)}
}


color_brightness :: proc(color: Color, factor: f32) -> Color {
    factor := clamp(factor, -1, 1)
    vec := color_to_vec4(color)

    if factor < 0 {
        factor = 1 + factor
        vec.rgb *= factor
    } else {
        vec.rgb = (1 - vec.rgb) * factor + vec.rgb
    }

    out  := vec4_to_color(vec)
    out.a = color.a
    return out
}
