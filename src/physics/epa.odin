package physics

import "core:math"
import glm "core:math/linalg/glsl"

CollisionPoints :: struct {
    normal: glm.vec3,
    depth: f32,
    colliding: bool,
}

// Expanding Polytope Algorithm, finds the collision normal.
epa_find_collision :: proc(a, b: Collider, simplex: Simplex) -> CollisionPoints {
    context.allocator = context.temp_allocator

    polytope := make([dynamic]glm.vec3, 0, simplex.size)
    for p in simplex.points do append(&polytope, p)

    faces: [dynamic][3]int = {
        {0, 1, 2},
        {0, 3, 1},
        {0, 2, 3},
        {1, 3, 2},
    }

    normals, min_face := face_normals(polytope, faces)

    min_normal: glm.vec3
    min_dist: f32 = math.F32_MAX

    for min_dist == math.F32_MAX {
        min_normal = normals[min_face].normal
        min_dist   = normals[min_face].distance

        sup := support(a, b, min_normal)
        s_dist := glm.dot(min_normal, sup)

        if abs(s_dist - min_dist) <= 0.001 {
            continue
        }

        min_dist = math.F32_MAX

        // Build list of unique edges.
        unique_edges: [dynamic][2]int
        for i := 0; i < len(normals); i += 1 {
            if !same_direction(normals[i].normal, sup) {
                continue
            }

            f := faces[i]
            add_if_unique_edge(&unique_edges, f.xy)
            add_if_unique_edge(&unique_edges, f.yz)
            add_if_unique_edge(&unique_edges, f.zx)

            faces[i] = pop(&faces)
            normals[i] = pop(&normals)
            i -= 1
        }

        new_faces: [dynamic][3]int
        for edge in unique_edges {
            append(&new_faces, [3]int{edge.x, edge.y, len(polytope)})
        }
        append(&polytope, sup)

        new_normals, new_min_face := face_normals(polytope, new_faces)

        old_min_dist: f32 = math.F32_MAX
        for norm, i in normals {
            if norm.distance < old_min_dist {
                old_min_dist = norm.distance
                min_face = i
            }
        }

        if new_normals[new_min_face].distance < old_min_dist {
            min_face = new_min_face + len(normals)
        }

        append(&faces,   ..new_faces[:])
        append(&normals, ..new_normals[:])
    }

    points := CollisionPoints{
        normal = min_normal,
        depth  = min_dist + 0.001,
        colliding = true,
    }

    return points
}

face_normals :: proc(polytope: [dynamic]glm.vec3, faces: [dynamic][3]int) -> (normals: [dynamic]CollisionNormal, min_triangle: int) {
    min_dist: f32 = math.F32_MAX

    for face, i in faces {
        a, b, c := polytope[face.x], polytope[face.y], polytope[face.z]

        normal := glm.normalize(glm.cross(b-a, c-a))
        dist := glm.dot(normal, a)

        if dist < 0 {
            normal *= -1
            dist   *= -1
        }

        append(&normals, CollisionNormal{ normal = normal, distance = dist})
        if dist < min_dist {
            min_dist = dist
            min_triangle = i
        }
    }

    return
}

add_if_unique_edge :: proc(edges: ^[dynamic][2]int, edge: [2]int) {
    found_index := -1
    for edge, i in edges do if edge == edge.yx {
        found_index = i
        break
    }

    if found_index == -1 {
        append(edges, edge)
    } else {
        unordered_remove(edges, found_index)
    }
}

CollisionNormal :: struct {
    normal: glm.vec3,
    distance: f32,
}