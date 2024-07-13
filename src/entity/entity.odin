package entity

import glm "core:math/linalg/glsl"

ID :: i32

entities := make([dynamic]Entity, 0, 128)
deleted  := make([dynamic]ID, 0, 128)

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
    return i32(len(entities) - 1)
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

transform :: proc{
    transform_id,
    transform_ent,
}

transform_id :: proc(id: ID) -> glm.mat4 { return transform_ent(entities[id]) }

transform_ent :: proc(e: Entity) -> glm.mat4 {
    m := glm.mat4Translate(e.pos) * glm.mat4FromQuat(e.orientation) * glm.mat4Scale(e.scale)
    return m
}