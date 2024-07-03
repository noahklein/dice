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
collisions: [dynamic]Collision

Body :: struct {
    entity_id: entity.ID,
    vel: glm.vec3,
    angular_vel: glm.vec3, 
    static: bool,
    shape: ShapeID,
}

Collision :: struct{
    a_body_id, b_body_id: int,
    normal: glm.vec3,
}

bodies_update :: proc(dt: f32) {
    body_dt_acc += dt
    for body_dt_acc >= DT {
        body_dt_acc -= DT
        bodies_fixed_update()
    }
}

bodies_fixed_update :: proc() {
    for &body in bodies  {
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

    clear(&collisions)
    for a, i in colliders[:len(bodies) - 1] {
        for b in colliders[i+1:] {
            simplex := gjk_is_colliding(a, b) or_continue
            collision := epa(a, b, simplex)
            fmt.println(collision)

            append(&collisions, Collision{
                a_body_id = a.body_id, b_body_id = b.body_id,
                normal = collision,
            })
        }
    }

    for col in collisions {
        a_body, b_body := &bodies[col.a_body_id], &bodies[col.b_body_id]

        a_ent, b_ent := entity.get(a_body.entity_id), entity.get(b_body.entity_id)


        // a_body.vel = 0
        // b_body.vel = 0
        // if a_body.static && b_body.static {
        //     continue
        // } else if a_body.static {
        //     b_ent.pos += col.normal
        // } else if b_body.static {
        //     a_ent.pos -= col.normal
        // } else {
        //     a_ent.pos -= col.normal/2
        //     b_ent.pos += col.normal/2
        // }
    }
}

cross :: #force_inline proc(v: glm.vec3) -> glm.mat3 {
    return {
        0, -v.z, v.y,
        v.z, 0, -v.x,
        -v.y, v.x, 0,
    }
}
