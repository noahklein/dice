package nmath

import glm "core:math/linalg/glsl"

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

// https://gamedev.stackexchange.com/a/50545
rotate_vector :: proc(v: glm.vec3, q: glm.quat) -> glm.vec3 {
    u := glm.vec3{imag(q), jmag(q), kmag(q)}
    s := real(q)

    return  2 * u * glm.dot(u, v) +
        v * (s*s - glm.dot(u, u)) +
        2 * s * glm.cross(u, v)
}

mat3FromQuat :: proc(q: glm.quat) -> glm.mat3 {
    w, x, y, z := q.w, q.x, q.y, q.z

    return {
        1 - 2*y*y - 2*z*z, 2*x*y - 2*z*w, 2*x*z + 2*y*w,
        2*x*y + 2*z*w, 1 - 2*x*x - 2*z*z, 2*y*z - 2*x*w,
        2*x*z - 2*y*w, 2*y*z + 2*x*w, 1 - 2*x*x - 2*y*y,
    }
}