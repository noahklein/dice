package nmath

import glm "core:math/linalg/glsl"

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