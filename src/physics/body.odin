package physics

import "core:fmt"
import glm "core:math/linalg/glsl"
import "../entity"

bodies: [dynamic]Body
body_dt_acc: f32

DT :: 1.0 / 120.0
GRAVITY :: glm.vec3{0, -9.8, 0}

ShapeID :: enum { Box }
shapes: [ShapeID]Shape
colliders: [dynamic]Collider

Body :: struct {
    entity_id: entity.ID,
    vel: glm.vec3,
    angular_vel: glm.vec3, 
    shape: ShapeID,
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
        ent := entity.get(body.entity_id)

        ent.pos += body.vel*DT
        body.vel += GRAVITY*DT
        
        ent.orientation += ent.orientation * cross(body.angular_vel) * DT
    }

    clear(&colliders)
    for body, i in bodies {
        transform := entity.transform(body.entity_id)

        c := Collider{ body_id = i, shape = shapes[body.shape] }
        for i in 0..<c.vertex_count {
            v := c.vertices[i].xyzx
            v.w = 1
            c.vertices[i] = (transform * v).xyz
        }

        append(&colliders, c)
    }

    for a, i in colliders[:len(bodies) - 1] {
        for b in colliders[i+1:] {
            simplex := gjk_is_colliding(a, b) or_continue
            collision := epa_find_collision(a, b, simplex)
            fmt.println(collision)
        }
    }
}

cross :: #force_inline proc(v: glm.vec3) -> glm.mat3 {
    return {
        0, -v.z, v.y,
        v.z, 0, -v.x,
        -v.y, v.x, 0,
    }
}
