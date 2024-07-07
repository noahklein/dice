package physics

import glm "core:math/linalg/glsl"

COLLIDER_MAX_VERTICES :: 8

ShapeID :: enum { Box }
shapes: [ShapeID]Shape

Shape :: struct {
    vertices: [COLLIDER_MAX_VERTICES]glm.vec3,
    vertex_count: int,
}

Manifold :: struct {
    normal: glm.vec3,
    depth: f32,
    // Contacts are relative to centers of A and B. Actual contactA = contactA - A.pos. Same for B.
    contactA, contactB: glm.vec3, 
}

Collider :: struct {
    using shape: Shape,
    body_id: int,
    aabb: AABB,
}

AABB :: struct {
    min, max: glm.vec3,
}

compute_aabb :: proc(c: ^Collider) {
    c.aabb.min, c.aabb.max = c.vertices[0], c.vertices[0]
    for i in 1..<c.vertex_count {
        c.aabb.min = glm.min(c.aabb.min, c.vertices[i])
        c.aabb.max = glm.max(c.aabb.max, c.vertices[i])
    }
}

aabb_vs_aabb :: proc(a, b: AABB) -> bool {
    return (a.max.x >= b.min.x && b.max.x >= a.min.x) &&
           (a.max.y >= b.min.y && b.max.y >= a.min.y) &&
           (a.max.z >= b.min.z && b.max.z >= a.min.z)
}