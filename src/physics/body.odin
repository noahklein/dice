package physics

import "core:fmt"
import glm "core:math/linalg/glsl"
import "../entity"
import "../nmath"

bodies := make([dynamic]Body, 0, 128)
body_dt_acc: f32

DT :: 1.0 / 1000.0
GRAVITY :: glm.vec3{0, -9.8, 0}
MAX_SPEED :: 64
MAX_ANG_SPEED :: 10
SLOP_PENETRATION :: 0.05 // m
SLOP_RESTITUTION ::  0.5 // m/s

colliders: [dynamic]Collider
collisions: [dynamic]Collision

Body :: struct {
    entity_id: entity.ID,
    inv_mass: f32,
    vel, force: glm.vec3,
    angular_vel, torque: glm.vec3,

    restitution: f32,

    inv_inertia: glm.vec3,
    inv_inertia_tensor: glm.mat3,
    shape: ShapeID,
}

Collision :: struct{
    a_body_id, b_body_id: int,
    manifold: Manifold,
}

bodies_create :: proc(id: entity.ID, shape: ShapeID = .Box, mass: f32 = 0,
                      vel: glm.vec3 = 0, ang_vel: glm.vec3 = 0) {
    inv_mass := 0 if mass == 0 else 1.0 / mass
    append(&bodies, Body{
        entity_id = id, shape = shape,
        inv_mass = inv_mass,
        vel = vel, angular_vel = ang_vel,
        inv_inertia = body_inertia(id, inv_mass, shape),
        restitution = 0.3,
    })
    body_update_inertia(&bodies[len(bodies) - 1])

}

bodies_update :: proc(dt: f32) {
    body_dt_acc += dt
    for body_dt_acc >= DT {
        body_dt_acc -= DT
        bodies_fixed_update()
    }
}

bodies_fixed_update :: proc() {
    for &body in bodies do if body.inv_mass != 0 {
        // Integrate acceleration.
        body.force += GRAVITY / body.inv_mass
        accel := body.force * body.inv_mass
        body.vel += accel * DT
        body.force = 0

        if glm.length(body.vel) > MAX_SPEED {
            body.vel = glm.normalize(body.vel) * MAX_SPEED
        }

        // Integrate angular acceleration.
        body_update_inertia(&body)
        body.angular_vel += body.inv_inertia_tensor * body.torque * DT

        if mag := glm.length(body.angular_vel); mag > MAX_ANG_SPEED {
            body.angular_vel *= MAX_ANG_SPEED / mag
        }
    }

    for body in bodies do if body.inv_mass != 0 {
        ent := entity.get(body.entity_id)
        // Integrate velocity.
        ent.pos += body.vel * DT

        {
            // Integrate angular velocity.
            a := body.angular_vel * (DT / 2)
            omega: glm.quat = quaternion(real = 0, imag = a.x, jmag = a.y, kmag = a.z)
            ent.orientation += omega * ent.orientation
            // Without normalization orientation's magnitude will keep growing and start to skew the object.
            ent.orientation = glm.normalize_quat(ent.orientation)
        }
    }

    colliders_update()

    // Detect collisions.
    clear(&collisions)
    for a, i in colliders[:len(bodies) - 1] {
        for b in colliders[i+1:] {
            aabb_vs_aabb(a.aabb, b.aabb) or_continue
            simplex := gjk_is_colliding(a, b) or_continue
            manifold := epa(a, b, simplex)

            append(&collisions, Collision{
                a_body_id = a.body_id, b_body_id = b.body_id,
                manifold = manifold,
            })
        }
    }

    // Resolve collisions.
    for hit in collisions {
        resolve_collision(hit)
    }
}

resolve_collision :: proc(collision_info: Collision) {
    hit := collision_info.manifold
    bodyA, bodyB := &bodies[collision_info.a_body_id], &bodies[collision_info.b_body_id]
    entA, entB := entity.get(bodyA.entity_id), entity.get(bodyB.entity_id)

    total_mass := bodyA.inv_mass + bodyB.inv_mass
    if total_mass == 0 do return // Two static bodies.

    // Move objects.
    pen := hit.normal * max(hit.depth - SLOP_PENETRATION, 0)
    entA.pos -= pen * (bodyA.inv_mass / total_mass)
    entB.pos += pen * (bodyB.inv_mass / total_mass)

    if glm.dot(pen, pen) < 1e-18 do return

    cpA := hit.contactA - entA.pos
    cpB := hit.contactB - entB.pos

    rel_vel := (bodyB.vel + glm.cross(bodyB.angular_vel, cpB)) -
               (bodyA.vel + glm.cross(bodyA.angular_vel, cpA))
    impulse := glm.dot(rel_vel, hit.normal) // Magnitude of the force.
    if impulse > 0 {
        return
    }

    inertiaA := glm.cross(bodyA.inv_inertia_tensor * glm.cross(cpA, hit.normal), cpA)
    inertiaB := glm.cross(bodyB.inv_inertia_tensor * glm.cross(cpB, hit.normal), cpB)
    ang_effect := glm.dot(inertiaA + inertiaB, hit.normal)

    // Restitution is the percentage of energy that gets conserved on collision.
    restitution := min(bodyA.restitution, bodyB.restitution)
    // J: glm.vec3 = -(1 + restitution) * max(impulse - SLOP_RESTITUTION, 0) * hit.normal
    J: glm.vec3 = -(1 + restitution) * impulse * hit.normal
    J /= (total_mass + ang_effect)

    bodyA.vel -= J * bodyA.inv_mass
    bodyB.vel += J * bodyB.inv_mass

    bodyA.angular_vel += bodyA.inv_inertia_tensor * glm.cross(cpA, -J)
    bodyB.angular_vel += bodyB.inv_inertia_tensor * glm.cross(cpB,  J)

    {
        // Apply friction. The friction impulse vector points in the collision tangent's direction.
        rel_vel = (bodyB.vel + glm.cross(bodyB.angular_vel, cpB)) -
                  (bodyA.vel + glm.cross(bodyA.angular_vel, cpA))

        tangent := rel_vel - glm.dot(rel_vel, hit.normal) * hit.normal
        if glm.length(tangent) < 1e-18 do return
        tangent = glm.normalize(tangent)

        friction_impulse_mag := -glm.dot(rel_vel, tangent) / (total_mass + glm.dot(inertiaA + inertiaB, tangent))
        friction_impulse := friction_impulse_mag * tangent

        STATIC_FRICTION :: 1
        DYNAMIC_FRICTION :: 1
        // Coulomb's law.
        if j_mag := glm.length(J); abs(friction_impulse_mag) > j_mag * STATIC_FRICTION {
            friction_impulse = -j_mag * tangent * DYNAMIC_FRICTION
        }

        // Apply friction impulse
        bodyA.vel -= friction_impulse * bodyA.inv_mass
        bodyB.vel += friction_impulse * bodyB.inv_mass

        bodyA.angular_vel += bodyA.inv_inertia_tensor * glm.cross(cpA, -friction_impulse)
        bodyB.angular_vel += bodyB.inv_inertia_tensor * glm.cross(cpB, friction_impulse)
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

// See https://en.wikipedia.org/wiki/List_of_moments_of_inertia
@(private="file")
body_inertia :: proc(ent_id: entity.ID, inv_mass: f32, shape: ShapeID) -> glm.vec3 {
    switch shape {
        case .Box:
            s := 2 * entity.get(ent_id).scale
            s *= s // Square it

            return {
                (12 * inv_mass) / (s.y + s.z),
                (12 * inv_mass) / (s.x + s.z),
                (12 * inv_mass) / (s.z + s.y),
            }
    }

    fmt.eprintln("Unsupported shape: can't generate inertia tensor.")
    return 1
}

body_update_inertia :: proc(b: ^Body) {
    mat3_scale :: proc(v: glm.vec3) -> (m: glm.mat3) {
        m[0, 0] = v.x
        m[1, 1] = v.y
        m[2, 2] = v.z
        return
    }

    q := entity.get(b.entity_id).orientation
    b.inv_inertia_tensor = nmath.mat3FromQuat(q) * mat3_scale(b.inv_inertia) * nmath.mat3FromQuat(conj(q))
}