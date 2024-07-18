package ngui

import "core:fmt"
import glm "core:math/linalg/glsl"
import "../window"

Color :: [4]u8

state: struct {
    panels: map[string]Panel,
    panel: string,
    panel_row: int,

    dragging: string,
    drag_offset: glm.vec2,

    button_pressed: string,
}

mouse: glm.vec2
want_mouse: bool


update :: proc(cursor: glm.vec2) {
    want_mouse = false
    mouse = glm.clamp(cursor, 0, window.screen)

    if state.dragging != "" && window.released_mbtn(.Left) {
        state.dragging = ""
    }

    if p, ok := &state.panels[state.dragging]; ok {
        p.rect.pos = mouse + state.drag_offset
    }

    assert(len(state.panels) <= 32, "Using more than 32 panels, is this intentional?")
    // assert(len(state.text_inputs) <= 32, "Using more than 32 text inputs, is this intentional?")
}

Panel :: struct {
    rect: Rect,
    minimized: bool,
}

@(deferred_none=end)
begin :: proc(title: string, rect: Rect) -> bool {
    if title not_in state.panels {
        state.panels[title] = { rect = rect }
    }
    state.panel = title
    state.panel_row = 0

    panel := &state.panels[title]
    rect  := panel.rect

    if contains(rect, mouse) do want_mouse = true

    title_rect := rect
    title_rect.h = TITLE_HEIGHT

    minimize_button_rect := Rect{
        {title_rect.x + title_rect.w - TITLE_HEIGHT, title_rect.y},
        TITLE_HEIGHT, TITLE_HEIGHT,
    }
    hover_minimize := contains(minimize_button_rect, mouse)
    hover_title := !hover_minimize && contains(title_rect, mouse)
    if window.pressed_mbtn(.Left) && hover_title {
        state.dragging = title
        state.drag_offset = title_rect.pos - mouse
    }

    // Right click title bar to print panel rectangle to console.
    if window.pressed_mbtn(.Right) && hover_title {
        fmt.println(int(rect.x), int(rect.y), int(rect.w), int(rect.h), sep = ", ")
    }
    draw_rect(title_rect, title_color(state.dragging == title))
    draw_text(title, title_rect.pos + FONT + 5, WHITE)

    if button_rect(minimize_button_rect, "+" if panel.minimized else "-") {
        panel.minimized = !panel.minimized
    }

    if button_rect({{100, 100}, 100, 100}, "hello") {
        fmt.println("hello")
    }

    if panel.minimized {
        return false
    }

    return true
}

end :: proc() {
    state.panel_row += 1
}

button_rect :: proc(rect: Rect, label: string) -> bool {
    hover := contains(rect, mouse)
    key := fmt.tprintf("%s#button#s", state.panel, label)
    active := state.button_pressed == key
    if hover && window.pressed_mbtn(.Left) {
        state.button_pressed = key
        active = true
    }

    color := button_color(hover, active, hover && window.mbtn_down(.Left))
    draw_rect(rect, color)
    text_rect(rect, label)

    release := active && window.released_mbtn(.Left)
    if release do state.button_pressed = ""

    return release && hover
}

TextAlign :: enum u8 { Left, Center, Right }

text_rect :: proc(rect: Rect, text: string, color := BLACK, align := TextAlign.Left) {
    y := rect.y + (0.5 * rect.h) - f32(0.5 * FONT)
    x: f32
    switch align {
    case .Left:   x = rect.x
    case .Center: x = rect.x + (0.5 * rect.w) - measure_text(text) / 2
    case .Right:  x = (rect.x + rect.w) - measure_text(text)
    }

    draw_text(text, {x, y})
}

measure_text :: proc(text: string, font_size := FONT) -> f32 {
    // TODO
    return f32(len(text)) * FONT
}