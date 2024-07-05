package entity

import glm "core:math/linalg/glsl"

ID :: uint

entities: [dynamic]Entity
deleted:  [dynamic]ID

Entity :: struct {
    pos, scale: glm.vec3,
    orientation: glm.quat,
}

new :: proc(pos: glm.vec3 = 0, orientation: glm.quat = 1, scale: glm.vec3 = 1) -> ID {
    ent := Entity{pos = pos, scale = scale, orientation = orientation}
    if len(deleted) > 0 {
        id := pop(&deleted)
        entities[id] = ent
        return id
    }

    append(&entities, ent)
    return len(entities) - 1
}

delete :: proc(id: ID) {
    for d in deleted do if d == id {
        return
    }

    append(&deleted, id)
}

get :: proc(id: ID) -> ^Entity {
    return &entities[id]
}

transform :: proc(id: ID) -> glm.mat4 {
    e := entities[id]
    m := glm.mat4Translate(e.pos) * glm.mat4FromQuat(e.orientation) * glm.mat4Scale(e.scale)
    return m
}

mat3ToMat4 :: #force_inline proc(m: glm.mat3) -> glm.mat4 {
    return {
        m[0, 0], m[0, 1], m[0, 2], 0,
        m[1, 0], m[1, 1], m[1, 2], 0,
        m[2, 0], m[2, 1], m[2, 2], 0,
        0, 0, 0, 1,
    }
}