package physics

import glm "core:math/linalg/glsl"
import "../entity"

bodies: [dynamic]Body
body_dt_acc: f32

DT :: 1.0 / 120.0
GRAVITY :: glm.vec3{0, -9.8, 0}

Body :: struct {
    entity_id: entity.ID,
    vel: glm.vec3,
    angular_vel: glm.vec3, 
}

bodies_update :: proc(dt: f32) {
    body_dt_acc += dt
    for body_dt_acc >= DT {
        body_dt_acc -= DT
        bodies_fixed_update()
    }
}

colliders: [dynamic]Collider

bodies_fixed_update :: proc() {
    for &body in bodies {
        ent := entity.get(body.entity_id)

        ent.pos += body.vel*DT
        body.vel += GRAVITY*DT
        
        ent.orientation += ent.orientation * cross(body.angular_vel) * DT

        floor := 0.5 * ent.scale.y
        if ent.pos.y < floor {
            ent.pos.y = floor
            body.vel.y *= -0.8
        }
    }

    // 1. Get list of mesh vertices.
    // 2. Transform vertices with matrix and build colliders.
    // 3. N^2 loop to check collisions with GJK and compile a list.
    // 4. Resolve collisions.
    clear(&colliders)
    for body in bodies {
        // ent := entity.get(body.entity_id)


    }
}

cross :: #force_inline proc(v: glm.vec3) -> glm.mat3 {
    return {
        0, -v.z, v.y,
        v.z, 0, -v.x,
        -v.y, v.x, 0,
    }
}
