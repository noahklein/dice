package random

import glm "core:math/linalg/glsl"
import "core:math/rand"

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
