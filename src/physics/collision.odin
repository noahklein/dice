package physics

import glm "core:math/linalg/glsl"

SimplexPoint :: struct {
    a, b: glm.vec3, // Support points on colliders A and B, retained for finding contact points.
    p: glm.vec3,    // p = a - b
}

Simplex :: struct {
    points: [4]SimplexPoint,
    size: int,
}

simplex_set :: proc(s: ^Simplex, points: ..SimplexPoint) {
    s.size = len(points)
    for p, i in points do s.points[i] = p
}

simplex_push_front :: proc(s: ^Simplex, point: SimplexPoint) {
    s.points = {point, s.points[0], s.points[1], s.points[2]}
    s.size = min(s.size + 1, 4)
}

gjk_is_colliding :: proc(a, b: Collider) -> (Simplex, bool) {
    MAX_ITER :: 64

    simplex: Simplex
    simplex_push_front(&simplex, support(a, b, {1, 0, 0}))
    dir := -simplex.points[0].p

    for _ in 0..<MAX_ITER {
        sup := support(a, b, dir)
        if glm.dot(sup.p, dir) < 0 {
            return {}, false
        }
        simplex_push_front(&simplex, sup)

        if do_simplex(&simplex, &dir) {
            return simplex, true
        }
    }

    return {}, false
}

do_simplex :: proc(simplex: ^Simplex, dir: ^glm.vec3) -> bool {
    switch simplex.size {
        case 2: return gjk_line       (simplex, dir)
        case 3: return gjk_triangle   (simplex, dir)
        case 4: return gjk_tetrahedron(simplex, dir)
    }

    panic("Unexpected number of simplex points")
}

gjk_line :: proc(simplex: ^Simplex, dir: ^glm.vec3) -> bool {
    a, b := simplex.points[0], simplex.points[1]
    ab := b.p - a.p
    ao :=     - a.p

    if same_direction(ab, ao) {
        dir^ = glm.vectorTripleProduct(ab, ao, ab)
    } else {
        simplex_set(simplex, a)
        dir^ = ao
    }

    return false
}

gjk_triangle :: proc(simplex: ^Simplex, dir: ^glm.vec3) -> bool {
    a, b, c := simplex.points[0], simplex.points[1], simplex.points[2]
    ab := b.p - a.p
    ac := c.p - a.p
    ao :=     - a.p

    abc := glm.cross(ab, ac)

    if same_direction(glm.cross(abc, ac), ao) {
        if same_direction(ac, ao) {
            simplex_set(simplex, a, c)
            dir^ = glm.vectorTripleProduct(ac, ao, ac)
        } else {
            simplex_set(simplex, a, b)
            return gjk_line(simplex, dir)
        }
    } else {
        if same_direction(glm.cross(ab, abc), ao) {
            simplex_set(simplex, a, b)
            return gjk_line(simplex, dir)
        } else if same_direction(abc, ao) {
            dir^ = abc
        } else {
            simplex_set(simplex, a, c, b)
            dir^ = -abc
        }
    }

    return false
}

gjk_tetrahedron :: proc(simplex: ^Simplex, dir: ^glm.vec3) -> bool {
    a, b, c, d := simplex.points[0], simplex.points[1], simplex.points[2], simplex.points[3]
    ab := b.p - a.p
    ac := c.p - a.p
    ad := d.p - a.p
    ao :=     - a.p

    abc := glm.cross(ab, ac)
    acd := glm.cross(ac, ad)
    adb := glm.cross(ad, ab)

    if same_direction(abc, ao) {
        simplex_set(simplex, a, b, c)
        return gjk_triangle(simplex, dir)
    }
    if same_direction(acd, ao) {
        simplex_set(simplex, a, c, d)
        return gjk_triangle(simplex, dir)
    }
    if same_direction(adb, ao) {
        simplex_set(simplex, a, d, b)
        return gjk_triangle(simplex, dir)
    }

    return true
}

same_direction :: proc(a, b: glm.vec3) -> bool {
    return glm.dot(a, b) > 0
}

// Minkowski sum support function for GJK.
support :: proc(a, b: Collider, dir: glm.vec3) -> (sp: SimplexPoint) {
    sp.a = furthest_point(a,  dir)
    sp.b = furthest_point(b, -dir)
    sp.p = sp.a - sp.b
    return
}

// Get the furthest point on a collider in a given direction.
furthest_point :: proc(c: Collider, dir: glm.vec3) -> glm.vec3 {
    max_dist := glm.dot(dir, c.vertices[0])
    furthest := c.vertices[0]

    for i in 1..<c.vertex_count {
        v := c.vertices[i]
        if dist := glm.dot(dir, v); dist > max_dist {
            max_dist = dist
            furthest = v
        }
    }

    return furthest
}