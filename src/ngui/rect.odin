package ngui

import glm "core:math/linalg/glsl"

Rect :: struct{
    using pos: glm.vec2,
    w, h: f32,
}

contains :: proc(rect: Rect, point: glm.vec2) -> bool {
    return (point.x >= rect.x && point.x <= rect.x + rect.w) &&
           (point.y >= rect.y && point.y <= rect.y + rect.h)
}