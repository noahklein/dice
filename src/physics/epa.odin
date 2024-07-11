package physics

import glm "core:math/linalg/glsl"
import "../nmath"

CollisionManifold :: struct {
    normal: glm.vec3,
    depth: f32,
    // Contacts are relative to centers of A and B. Actual contactA = contactA - A.pos. Same for B.
    contactA, contactB: glm.vec3,
}

// Expanding Polytope Algorithm; expands the GJK simplex iteratively
epa :: proc(coll_a, coll_b: Collider, simplex: Simplex) -> Manifold {
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

    loose_edges := make([dynamic][2]SimplexPoint, 0, EPA_MAX_LOOSE_EDGES)

    closest_face: int
    for _ in 0..<EPA_MAX_ITER {
        min_dist := glm.dot(faces[0].points[0].p, faces[0].normal)
        closest_face = 0

        // Find the face that's closest to the origin.
        for f, i in faces {
            dist := glm.dot(f.points[0].p, f.normal)
            if dist < min_dist {
                min_dist = dist
                closest_face = i
            }
        }

        search_dir := faces[closest_face].normal
        sup := support(coll_a, coll_b, search_dir)

        if glm.dot(sup.p, search_dir) - min_dist < EPA_TOLERANCE {
            return collision_manifold(faces[closest_face])
        }

        clear(&loose_edges)
        for face_i := 0; face_i < len(faces); face_i += 1 {
            f := faces[face_i]
            if glm.dot(f.normal, sup.p - f.points[0].p) > 0 { // Triangle faces support point.
                for pa, i in f.points {
                    pb := f.points[(i + 1) % len(f.points)]
                    new_edge := [2]SimplexPoint{pa, pb}
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
            // face := new_face(edge[0], edge[1], sup)
            face := Face{
                points = {edge[0], edge[1], sup},
                normal = glm.normalize(glm.cross(edge[0].p - edge[1].p, edge[0].p - sup.p)),
            }

            BIAS :: 0.000001
            if glm.dot(face.points[0].p, face.normal) + BIAS < 0 {
                face.points[0], face.points[1] = face.points[1], face.points[0]
                face.normal *= -1
            }

            append(&faces, face)
        }
    }

    return collision_manifold(faces[closest_face])
}

Face :: struct{
    points: [3]SimplexPoint,
    normal: glm.vec3,
}

new_face :: proc(a, b, c: SimplexPoint) -> Face {
    return {
        points = {a, b, c},
        normal = glm.normalize(glm.cross(b.p - a.p, c.p - a.p)),
    }
}

collision_manifold :: proc(f: Face) -> Manifold {
    a, b, c := f.points[0], f.points[1], f.points[2]
    // Project origin onto triangle.
    projection_point := nmath.plane_project(nmath.plane_from_tri(a.p, b.p, c.p), 0)
    bary := barycentric(projection_point, a.p, b.p, c.p)

    // Do a linear combination of the barycentric coords and triangle support points.
    localA := bary.x*f.points[0].a + bary.y*f.points[1].a + bary.z*f.points[2].a
    localB := bary.x*f.points[0].b + bary.y*f.points[1].b + bary.z*f.points[2].b

    return {
        depth = glm.length(localA - localB),
        normal = glm.normalize(localA - localB),
        contactA = localA, contactB = localB,
    }
}

// Compute barycentric coordinates for point p with respect to triangle (a, b, c).
barycentric :: proc(p, a, b, c: glm.vec3) -> glm.vec3 {
    v0, v1, v2 := b - a, c - a, p - a
    d00 := glm.dot(v0, v0)
    d01 := glm.dot(v0, v1)
    d11 := glm.dot(v1, v1)
    d20 := glm.dot(v2, v0)
    d21 := glm.dot(v2, v1)
    denom := d00 * d11 - d01 * d01
    v := (d11 * d20 - d01 * d21) / denom
    w := (d00 * d21 - d01 * d20) / denom
    return {1.0 - v - w, v, w}
}