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
    manifold: CollisionManifold,
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

    // Detect collisions.
    clear(&collisions)
    for a, i in colliders[:len(bodies) - 1] {
        for b in colliders[i+1:] {
            // aabb_vs_aabb(a.aabb, b.aabb) or_continue
            simplex := gjk_is_colliding(a, b) or_continue

            append(&collisions, Collision{
                a_body_id = a.body_id, b_body_id = b.body_id,
                manifold = epa(a, b, simplex),
            })
        }
    }

    // Resolve collisions.
    for hit in collisions {
        a_body, b_body := &bodies[hit.a_body_id], &bodies[hit.b_body_id]
        a_ent, b_ent := entity.get(a_body.entity_id), entity.get(b_body.entity_id)
        fmt.println("contacts", hit.manifold.contactA - a_ent.pos, hit.manifold.contactB - b_ent.pos)

        penetration := hit.manifold.normal * hit.manifold.depth
        // Move objects.
        if a_body.static && b_body.static {
            continue
        } else if a_body.static {
            b_ent.pos += penetration
        } else if b_body.static {
            a_ent.pos -= penetration
        } else {
            a_ent.pos -= penetration/2
            b_ent.pos += penetration/2
        }

        // Bounce off each other, update linear and angular momenta.
        if glm.dot(penetration, penetration) < 1e-18 do continue
        a_inv_mass := 0 if a_body.mass == 0 else 1 / a_body.mass
        b_inv_mass := 0 if b_body.mass == 0 else 1 / b_body.mass

        rel_vel := (b_body.vel + b_body.angular_vel) -
                   (a_body.vel + a_body.angular_vel)
        contact_vel_mag := glm.dot(rel_vel, hit.manifold.normal)
        if contact_vel_mag > 0 {
            continue
        }

        restitution :: f32(1)
        J: glm.vec3 = -(1 + restitution) * contact_vel_mag
        J /= a_inv_mass + b_inv_mass
        J *= hit.manifold.normal

        a_body.vel -= J * a_inv_mass
        b_body.vel += J * b_inv_mass 
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