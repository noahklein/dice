package physics

import glm "core:math/linalg/glsl"

bodies: [dynamic]Body
body_dt_acc: f32

DT :: 1.0 / 120.0
GRAVITY :: glm.vec3{0, -9.8, 0}

init_bodies :: proc() {
    append(&bodies,
        Body{ pos = {0, 20, 0}, scale = 1 },
        Body{ pos = {7, 21, 3}, scale = 2 },
    )
}
deinit_bodies :: proc() { delete(bodies) }

Body :: struct {
    pos, vel, scale: glm.vec3,
    rot, rot_vel: glm.quat,
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


        floor := 0.5 * body.scale.y
        if body.pos.y < floor {
            body.pos.y = floor
            body.vel.y *= -0.8
        }
    }
}

body_matrix :: proc(b: Body) -> (m: glm.mat4) {
    m = glm.mat4Scale(b.scale)
    m *= glm.mat4FromQuat(b.rot)
    m *= glm.mat4Translate(b.pos)
    return
}