package physics

import glm "core:math/linalg/glsl"

bodies: [dynamic]Body
body_dt_acc: f32

DT :: 1.0 / 120.0
GRAVITY :: glm.vec3{0, -9.8, 0}

init_bodies :: proc() {
    append(&bodies,
        Body{ pos = {0, 20, 0}, scale = 1, orientation = 1 },
        Body{ pos = {7, 21, 3}, scale = 2, angular_vel = {0, 1, 0}, orientation = 1 },
    )
}
deinit_bodies :: proc() { delete(bodies) }

Body :: struct {
    pos, vel, scale: glm.vec3,
    orientation: glm.mat3,
    angular_vel: glm.vec3,
}

bodies_update :: proc(dt: f32) {
    body_dt_acc += dt
    for body_dt_acc >= DT {
        body_dt_acc -= DT
        bodies_fixed_update()
    }
}


bodies_fixed_update :: proc() {
    for &body in bodies {
        body.pos += body.vel*DT
        body.vel += GRAVITY*DT
        
        body.orientation += body.orientation * cross(body.angular_vel) * DT

        floor := 0.5 * body.scale.y
        if body.pos.y < floor {
            body.pos.y = floor
            body.vel.y *= -0.8
        }
    }
}

body_matrix :: proc(b: Body) -> (m: glm.mat4) {
    m = glm.mat4Scale(b.scale)
    m *= glm.mat4Translate(b.pos)
    m *= mat3ToMat4(b.orientation)
    return
}

cross :: #force_inline proc(v: glm.vec3) -> glm.mat3 {
    return {
        0, -v.z, v.y,
        v.z, 0, -v.x,
        -v.y, v.x, 0,
    }
}

mat3ToMat4 :: #force_inline proc(m: glm.mat3) -> glm.mat4 {
    return {
        m[0, 0], m[0, 1], m[0, 2], 0,
        m[1, 0], m[1, 1], m[1, 2], 0,
        m[2, 0], m[2, 1], m[2, 2], 0,
        0, 0, 0, 1,
    }
}