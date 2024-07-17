package render

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "../entity"
import "../assets"

meshes: map[entity.ID]Mesh
immediate_meshes := make([dynamic]IMesh, 0, 128) // Cleared on every frame.

MeshId ::  enum { Cube, Sphere, Tetrahedron, Octahedron, Cone, Cylinder }
mesh_renderers: [MeshId]Renderer

Mesh :: struct {
    mesh_id: MeshId,
    color: [4]u8,
    tex_unit: u32,

    hidden: bool,
}

// Immediate mesh, draws for one frame only.
IMesh :: struct {
    using mesh: Mesh,
    transform: entity.Entity,
    ent_id: entity.ID, // For use in mouse-picking.
}

create_mesh :: proc(id: MeshId, ent_id: entity.ID, color: [4]u8 = 255, tex: assets.TextureId = .None) {
    meshes[ent_id] = Mesh{
        mesh_id = id,
        color = color, tex_unit = assets.tex_unit(tex),
    }
}

// Immediate-mode, draws once and then forgets.
draw_mesh :: proc(id: MeshId, ent_id: entity.ID = 0, color: [4]u8 = 255, tex: assets.TextureId = .None, pos: glm.vec3 = 0, orientation: glm.quat = 1, scale: glm.vec3 = 1) {
    append(&immediate_meshes, IMesh{
        mesh_id = id,
        color = color, tex_unit = assets.tex_unit(tex),
        transform = { pos = pos, orientation = orientation, scale = scale },
        ent_id = ent_id,
    })
}

Renderer :: struct {
    name: cstring,
    vao, vbo, ibo: u32,
    verts: []Vertex,
    instances: [dynamic]Instance,
}

Vertex :: struct {
    pos:  glm.vec3,
    norm: glm.vec3,
    uv:   glm.vec2,
}

Instance :: struct {
    texture: u32,
    color: [4]u8,
    ent_id:  i32, // For mouse picking
    transform: matrix[4, 4]f32,
}

MAX_INSTANCES :: 30

renderer_init :: proc(id: MeshId, obj: Obj) {
    m := Renderer{
        instances = make([dynamic]Instance, 0, MAX_INSTANCES),
        verts = make([]Vertex, len(obj.faces)),
    }
    defer mesh_renderers[id] = m

    for face, i in obj.faces {
        m.verts[i] = Vertex{
            pos = obj.vertices[face.vertex_index - 1],
            norm = obj.normals[face.normal_index - 1],
            uv = obj.tex_coords[face.tex_coord_index - 1],
        }
    }

    gl.CreateVertexArrays(1, &m.vao)
    gl.BindVertexArray(m.vao)

    // Vertex buffer, loaded into VRAM.
    gl.CreateBuffers(1, &m.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, m.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(m.verts) * size_of(Vertex), &m.verts[0], gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, norm))
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))

    // Instance buffer
    gl.CreateBuffers(1, &m.ibo)
    gl.BindBuffer(gl.ARRAY_BUFFER, m.ibo)
    gl.BufferData(gl.ARRAY_BUFFER, MAX_INSTANCES * size_of(Instance), nil, gl.DYNAMIC_DRAW)

    gl.EnableVertexAttribArray(3)
    gl.VertexAttribIPointer(3, 1, gl.UNSIGNED_INT, size_of(Instance), offset_of(Instance, texture))
    gl.VertexAttribDivisor(3, 1)
    gl.EnableVertexAttribArray(4)
    gl.VertexAttribPointer(4, 4, gl.UNSIGNED_BYTE, true, size_of(Instance), offset_of(Instance, color))
    gl.VertexAttribDivisor(4, 1)

    gl.EnableVertexAttribArray(5)
    gl.VertexAttribIPointer(5, 1, gl.INT, size_of(Instance), offset_of(Instance, ent_id))
    gl.VertexAttribDivisor(5, 1)

    for i in 0..<4 {
        id := u32(6 + i)
        gl.EnableVertexAttribArray(id)
        offset := offset_of(Instance, transform) + (uintptr(i * 4) * size_of(f32))
        gl.VertexAttribPointer(id, 4, gl.FLOAT, false, size_of(Instance), offset)
        gl.VertexAttribDivisor(id, 1)
    }
}

renderer_deinit :: proc(id: MeshId) {
    m := &mesh_renderers[id]
    gl.DeleteVertexArrays(1, &m.vao)
    gl.DeleteBuffers(1, &m.vbo)
    gl.DeleteBuffers(1, &m.ibo)
    delete(m.instances)
    delete(m.verts)
}

renderer_draw :: proc(id: MeshId, instance: Instance) {
    m := &mesh_renderers[id]
    if len(m.instances) + 1 >= MAX_INSTANCES {
        renderer_flush(id)
    }

    append(&m.instances, instance)
}

renderer_flush :: proc(id: MeshId) {
    m := &mesh_renderers[id]
    if len(m.instances) == 0 {
        return
    }

    gl.BindVertexArray(m.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, m.ibo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(m.instances) * size_of(Instance), &m.instances[0])

    gl.DrawArraysInstanced(gl.TRIANGLES, 0, i32(len(m.verts)), i32(len(m.instances)))

    clear(&m.instances)
}

render_all_meshes :: proc() {
    defer clear(&immediate_meshes)

    for id in MeshId {
        for ent_id, m in meshes do if !m.hidden && m.mesh_id == id {
            renderer_draw(id, Instance{
                transform = entity.transform(ent_id),
                color = m.color,
                ent_id = ent_id,
                texture = m.tex_unit,
            })
        }

        for m in immediate_meshes do if m.mesh_id == id {
            renderer_draw(id, Instance{
                transform = entity.transform(m.transform),
                color = m.color,
                texture = m.tex_unit,
                ent_id = m.ent_id,
            })
        }

        renderer_flush(id)
    }
}
