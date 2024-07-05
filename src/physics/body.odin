package physics

import "core:fmt"
import glm "core:math/linalg/glsl"
import "../entity"

bodies: [dynamic]Body
body_dt_acc: f32

DT :: 1.0 / 120.0
GRAVITY :: glm.vec3{0, -9.8, 0}
MAX_SPEED :: 64

ShapeID :: enum { Box }
shapes: [ShapeID]Shape
colliders: [dynamic]Collider
collisions: [dynamic]Collision

Body :: struct {
    entity_id: entity.ID,
    mass: f32,
    vel, force: glm.vec3,
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
    for &body in bodies do if !body.static  {
        ent := entity.get(body.entity_id)

        body.force += GRAVITY * body.mass
        accel := body.force / body.mass
        body.vel += accel * DT
        body.force = 0

        if glm.length(body.vel) > MAX_SPEED {
            body.vel = glm.normalize(body.vel) * MAX_SPEED
        }

        ent.pos += body.vel * DT

        {
            // Apply angular velocity.
            a := body.angular_vel
            omega: glm.quat = quaternion(real = 0, imag = a.x, jmag = a.y, kmag = a.z)
            ent.orientation += omega * ent.orientation * (DT / 2)
            // Without normalization orientation's magnitude will keep growing and start to skew the object.
            // This doesn't need to happen every tick, but it's pretty cheap so who gives a quat.
            ent.orientation = glm.normalize_quat(ent.orientation)
        }
    }

    colliders_update()

    clear(&collisions)
    for a, i in colliders[:len(bodies) - 1] {
        for b in colliders[i+1:] {
            aabb_vs_aabb(a.aabb, b.aabb) or_continue
            simplex := gjk_is_colliding(a, b) or_continue
            collision := epa(a, b, simplex)

            append(&collisions, Collision{
                a_body_id = a.body_id, b_body_id = b.body_id,
                normal = collision,
            })
        }
    }

    for col in collisions {
        a_body, b_body := &bodies[col.a_body_id], &bodies[col.b_body_id]
        a_ent, b_ent := entity.get(a_body.entity_id), entity.get(b_body.entity_id)

        if a_body.static && b_body.static {
            continue
        } else if a_body.static {
            b_ent.pos += col.normal
        } else if b_body.static {
            a_ent.pos -= col.normal
        } else {
            a_ent.pos -= col.normal/2
            b_ent.pos += col.normal/2
        }
    }
}

colliders_update :: proc() {
    clear(&colliders)
    for body, i in bodies {
        transform := entity.transform(body.entity_id)

        c := Collider{ body_id = i, shape = shapes[body.shape] }
        for i in 0..<c.vertex_count {
            v := c.vertices[i].xyzx
            v.w = 1
            c.vertices[i] = (transform * v).xyz
        }

        compute_aabb(&c)

        append(&colliders, c)
    }
}