package physics

import glm "core:math/linalg/glsl"

COLLIDER_MAX_VERTICES :: 12

Simplex :: [4]glm.vec3

Collider :: struct {
    vertices: [COLLIDER_MAX_VERTICES]glm.vec3,
    vertex_count: int,
}

gjk_is_colliding :: proc(a, b: Collider) -> bool {
    a_center, b_center := average_point(a), average_point(b)
    dir := a_center - b_center // Initial direction to check.

    if dir == 0 do dir.x = 1 // Set to any arbitrary axis.


    simplex: Simplex
    simplex[0] = support(a, b, dir)
    dir = -simplex[0] // New direction is towards the origin.

    i: int
    for {
        i += 1

        sup := support(a, b, dir)
        if glm.dot(sup, dir) <= 0 {
            return false
        }

        simplex[i] = sup

        switch i {
        case 2: // Line
            a, b := simplex[0], simplex[1]
            ab := b - a
            ao := 0 - a

            if same_direction(ab, ao) {
                dir = triple_cross(ab, ao, ab)
            } else {
                i -= 1
                dir = ao
            }
        case 3: // Triangle
            a, b, c := simplex[0], simplex[1], simplex[2]
            ab := b - a
            ac := c - a
            ao := 0 - a

            abc := glm.cross(ab, ac)
            if same_direction(ao, glm.cross(abc, ac)) {
                if same_direction(ac, ao) {
                    i -= 1
                    dir = triple_cross(ac, ao, ac)
                    continue
                } else {

                }
            }
            
        case 4: // Tetrahedron

        case: panic("GJK too many iterations")
        }
    }
}

same_direction :: proc(a, b: glm.vec3) -> bool {
    return glm.dot(a, b) > 0
}

// Minkowski sum support function for GJK.
support :: proc(a, b: Collider, dir: glm.vec3) -> glm.vec3 {
    p := furthest_point(a,  dir)
    q := furthest_point(b, -dir)
    return p - q
}

// Get the furthest point on a collider in a given direction.
furthest_point :: proc(c: Collider, dir: glm.vec3) -> glm.vec3 {
    max_product := glm.dot(dir, c.vertices[0])
    furthest := c.vertices[0]

    for i in 1..<c.vertex_count {
        v := c.vertices[i]
        if product := glm.dot(dir, v); product > max_product {
            max_product = product
            furthest = v
        }
    }

    return furthest
}

// Average point is a good approximation of a shape's center.
average_point :: proc(c: Collider) -> (avg: glm.vec3) {
    for i in 0..<c.vertex_count do avg += c.vertices[i]
    return avg / f32(c.vertex_count)
}

triple_cross :: proc(a, b, c: glm.vec3) -> glm.vec3 {
    return glm.cross(glm.cross(a, b), c)
}