package physics

import "core:math"
import glm "core:math/linalg/glsl"

epa :: proc(coll_a, coll_b: Collider, simplex: Simplex) -> glm.vec3 {
    context.allocator = context.temp_allocator

    EPA_MAX_FACES :: 64
    EPA_MAX_ITER  :: EPA_MAX_FACES
    EPA_MAX_LOOSE_EDGES :: EPA_MAX_FACES / 2
    EPA_TOLERANCE :: 0.0001

    faces := make([dynamic]Face, 0, EPA_MAX_FACES)
    {
        // Get initial simplex faces.
        a, b, c, d := simplex.points[0], simplex.points[1], simplex.points[2], simplex.points[3] 
        append(&faces, new_face(a, b, c))
        append(&faces, new_face(a, c, d))
        append(&faces, new_face(a, d, b))
        append(&faces, new_face(b, d, c))
    }

    closest_face: int
    for _ in 0..<EPA_MAX_ITER {
        min_dist := glm.dot(faces[0].points[0], faces[0].normal)
        closest_face = 0

        // Find the face that's closest to the origin.
        for f, i in faces {
            dist := glm.dot(f.points[0], f.normal)
            if dist < min_dist {
                min_dist = dist
                closest_face = i
            }
        }

        search_dir := faces[closest_face].normal
        sup := support(coll_a, coll_b, search_dir)

        if glm.dot(sup, search_dir) - min_dist < EPA_TOLERANCE {
            return faces[closest_face].normal * glm.dot(sup, search_dir)
        }

        loose_edges := make([dynamic][2]glm.vec3, 0, EPA_MAX_LOOSE_EDGES)
        for face_i := 0; face_i < len(faces); face_i += 1 {
            f := faces[face_i]
            if glm.dot(f.normal, sup - f.points[0]) > 0 { // Triangle faces support point.
                for pa, i in f.points {
                    pb := f.points[(i + 1) % len(f.points)]
                    new_edge := [2]glm.vec3{pa, pb}
                    found_edge: bool

                    // Remove edge from list if it already exists.
                    for edge, edge_i in loose_edges {
                        if edge.yx == new_edge {
                            unordered_remove(&loose_edges, edge_i)
                            found_edge = true
                            break
                        }
                    }

                    if !found_edge {
                        if len(loose_edges) > EPA_MAX_LOOSE_EDGES do break
                        append(&loose_edges, new_edge)
                    }
                }

                unordered_remove(&faces, face_i)
                face_i -= 1
            }
        } // End face loop.

        // Reconstruct polytope with support point added.
        for edge in loose_edges {
            if len(faces) >= EPA_MAX_FACES do break
            face := new_face(edge[0], edge[1], sup)

            BIAS :: 0.000001
            if glm.dot(face.points[0], face.normal) + BIAS < 0 {
                face.points[0], face.points[1] = face.points[1], face.points[0]
                face.normal *= -1
            }

            append(&faces, face)
        }
    }

    closest := faces[closest_face]
    return closest.normal * glm.dot(closest.points[0], closest.normal)
}

Face :: struct{
    points: [3]glm.vec3,
    normal: glm.vec3,
}

new_face :: proc(a, b, c: glm.vec3) -> Face {
    return {
        points = {a, b, c},
        normal = glm.normalize(glm.cross(b - a, c - a)),
    }
}