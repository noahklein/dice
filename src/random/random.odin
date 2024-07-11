package random

import glm "core:math/linalg/glsl"
import "core:math/rand"

unit_vec2 :: proc() -> glm.vec2 {
    theta := rand.float32() * glm.TAU
    return {glm.cos(theta), glm.sin(theta)}
}

// https://math.stackexchange.com/a/44691
unit_vec3 :: proc() -> glm.vec3 {
    theta := rand.float32() * glm.TAU
    z := rand.float32() * 2 - 1

    return {
        glm.sqrt(1 - z*z) * glm.cos(theta),
        glm.sqrt(1 - z*z) * glm.sin(theta),
        z,
    }
}

vec3 :: proc() -> glm.vec3 {
    return {rand.float32(), rand.float32(), rand.float32()}
}

quat :: proc() -> glm.quat {
    v := vec3()
    return quaternion(
        real = glm.sqrt(1-v.x) * glm.sin(v.y*glm.TAU),
        imag = glm.sqrt(1-v.x) * glm.cos(v.y*glm.TAU),
        jmag = glm.sqrt(v.x)   * glm.sin(v.z*glm.TAU),
        kmag = glm.sqrt(v.x)   * glm.cos(v.z*glm.TAU),
    )
}
