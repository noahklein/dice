package render

import glm "core:math/linalg/glsl"

Light :: struct {
    position, direction: glm.vec3,

    ambient, diffuse, specular: glm.vec3,
    constant, linear, quadratic: f32,
    cutoff, outer_cutoff: f32,
}

light :: Light{
    position = 5, direction = {0, 0, 1},
    ambient = 0.5, diffuse = 0.5, specular = 0.75,
    constant = 1, linear = 0.09, quadratic = 0.032,
    cutoff = 12.5, outer_cutoff = 17.5,
}
