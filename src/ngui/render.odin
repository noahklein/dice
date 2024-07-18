package ngui

import glm "core:math/linalg/glsl"
import "../render"

draw_rect :: proc(rect: Rect, color: Color) {
    render.draw_quad(rect.pos, {rect.w, rect.h}, 0, color)
}

draw_text :: proc(text: string, pos: glm.vec2, color := BLACK) {
    render.draw_text(pos, text)
}