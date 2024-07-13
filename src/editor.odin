package main

import "core:fmt"
import glm "core:math/linalg/glsl"
import "vendor:glfw"

import "entity"
import "nmath"
import "render"

UP_ENT_ID      :: 1e6
RIGHT_ENT_ID   :: UP_ENT_ID + 1
FORWARD_ENT_ID :: UP_ENT_ID + 2

editor_selected_id: entity.ID
editor_dragging: glm.vec3
editor_prev_mouse: glm.vec2

editor_update :: proc() {
    when !ODIN_DEBUG do return

    damp_enabled := glfw.GetKey(window, glfw.KEY_LEFT_ALT) == glfw.PRESS

    if .EditorSelect in input {
        editor_selected_id = -1
        if hovered_ent_id >= 0 && int(hovered_ent_id) < len(entity.entities) {
            editor_selected_id = hovered_ent_id
        }
    }

    if editor_selected_id < 0 do return
    ent := entity.get(editor_selected_id)

    left_mouse_btn := glfw.GetMouseButton(window, glfw.MOUSE_BUTTON_LEFT)
    if editor_dragging != 0 && left_mouse_btn == glfw.RELEASE {
        editor_dragging = 0
    }
    if editor_dragging == 0 && left_mouse_btn == glfw.PRESS {
        editor_prev_mouse = mouse_coords
        switch hovered_ent_id {
            case UP_ENT_ID:      editor_dragging = nmath.Up
            case RIGHT_ENT_ID:   editor_dragging = nmath.Right
            case FORWARD_ENT_ID: editor_dragging = nmath.Forward
        }
    }

    if editor_dragging != 0 {
        diff := mouse_coords.x - editor_prev_mouse.x

        editor_prev_mouse = mouse_coords
        drag_damping: f32 = 0.01 if damp_enabled else 0.0625
        ent.pos += diff * editor_dragging * drag_damping
    }

    SCALE :: 0.25

    draw_arrow(ent.pos, ent.pos + {0, ent.scale.y, 0}, nmath.Green, UP_ENT_ID)
    draw_arrow(ent.pos, ent.pos + {ent.scale.x, 0, 0}, nmath.Red, RIGHT_ENT_ID)
    draw_arrow(ent.pos, ent.pos + {0, 0, ent.scale.z}, nmath.Blue, FORWARD_ENT_ID)
}

quat_look_at :: proc(a, b: glm.vec3) -> glm.quat {
    cross := glm.cross(a, b)
    lenA, lenB := glm.length(a), glm.length(b)
    w := glm.sqrt(lenA*lenA * lenB*lenB) + glm.dot(a, b)
    return quaternion(w = w, x = cross.x, y = cross.y, z = cross.z)
}

draw_arrow :: proc(a, b: glm.vec3, color: [4]f32, id: entity.ID) {
    color := color
    if hovered_ent_id == id {
        color = nmath.color_brightness(color, 0.6)
    }
    q := quat_look_at({0, 1, 0}, b - a)
    q = glm.normalize(q)

    pos := (b + a) / 2
    norm := glm.normalize(b - a)
    height := glm.length(b - a)

    render.draw_mesh(.Cylinder, ent_id = id, color = color, pos = pos,  scale = {0.1, height, 0.1}, orientation = q)
    render.draw_mesh(.Cone,     ent_id = id, color = color, pos = pos + norm*(height + SCALE/2), scale = SCALE, orientation = q)
}