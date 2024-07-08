package render

import glm "core:math/linalg/glsl"

Light :: struct {
    position, direction: glm.vec3,

    ambient, diffuse, specular: glm.vec3,
    constant, linear, quadratic: f32,
    cutoff, outer_cutoff: f32,
}