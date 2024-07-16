package nmath

import glm "core:math/linalg/glsl"

Up      :: glm.vec3{0, 1, 0}
Right   :: glm.vec3{1, 0, 0}
Forward :: glm.vec3{0, 0, 1}

nearly_eq :: proc{
    nearly_eq_scalar,
    nearly_eq_vector,
}

nearly_eq_scalar :: proc(a, b: f32, precision: f32 = 0.0001) -> bool {
    return abs(a - b) < precision
}

nearly_eq_vector :: proc(a, b: $A/[$N]f32, precision: f32 = 0.0001) -> bool #no_bounds_check {
    for i in 0..<N {
        if !nearly_eq_scalar(a[i], b[i], precision) do return false
    }
    return true
}

// Quaternion representing the smallest rotation from directions a to b.
quat_from_vecs :: proc(a, b: glm.vec3) -> glm.quat {
    a, b := glm.normalize(a), glm.normalize(b)
    dot := glm.dot(a, b)

    if nearly_eq(dot, 1) { // Vectors point in the same direction.
        return glm.quatAxisAngle(Up, 0)
    }
    if nearly_eq(dot, -1) { // Vectors point in opposite directions.
        axis := glm.cross(Right, a)
        if nearly_eq(glm.length(axis), 0) do axis = glm.cross(Up, a)

        axis = glm.normalize(axis)
        return glm.quatAxisAngle(axis, glm.PI)
    }

    axis := glm.cross(a, b)
    q: glm.quat = quaternion(w = -(1 + dot), x = axis.x, y = axis.y, z = axis.z)
    return glm.normalize(q)
}

mat3ToMat4 :: #force_inline proc(m: glm.mat3) -> glm.mat4 {
    return {
        m[0, 0], m[0, 1], m[0, 2], 0,
        m[1, 0], m[1, 1], m[1, 2], 0,
        m[2, 0], m[2, 1], m[2, 2], 0,
        0, 0, 0, 1,
    }
}

mat3FromQuat :: proc(q: glm.quat) -> glm.mat3 {
    w, x, y, z := q.w, q.x, q.y, q.z

    return {
        1 - 2*y*y - 2*z*z, 2*x*y - 2*z*w, 2*x*z + 2*y*w,
        2*x*y + 2*z*w, 1 - 2*x*x - 2*z*z, 2*y*z - 2*x*w,
        2*x*z - 2*y*w, 2*y*z + 2*x*w, 1 - 2*x*x - 2*y*y,
    }
}

Plane :: struct {
    normal: glm.vec3,
    distance: f32,
}

plane_from_tri :: proc(a, b, c: glm.vec3) -> Plane {
    ab := b - a
    ac := c - a

    normal := glm.normalize(glm.cross(ab, ac))
    return Plane{ normal = normal, distance = -glm.dot(ab, normal) }
}

plane_project :: proc(plane: Plane, p: glm.vec3) -> glm.vec3 {
    distance := glm.dot(p, plane.normal) + plane.distance
    return p - (plane.normal * distance)
}