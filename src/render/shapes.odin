package render

import "core:fmt"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

MAX_LINES :: 128
MAX_QUADS :: 128

line_renderer: LineRenderer

LineRenderer :: struct {
    vao, vbo: u32,
    shader: Shader,
    lines: [dynamic]LineVertex,
}

LineVertex :: struct {
    point: glm.vec3,
    color: glm.vec3,
}

shapes_init :: proc()  {
    shader, err := shader_load("src/shaders/line.glsl")
    if err != nil {
        fmt.panicf("Failed to load line shader: %v", err)
    }
    line_renderer.shader = shader
    line_renderer.lines = make([dynamic]LineVertex, 0, MAX_LINES)

    gl.CreateVertexArrays(1, &line_renderer.vao)
    gl.BindVertexArray(line_renderer.vao)

    gl.CreateBuffers(1, &line_renderer.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, line_renderer.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, MAX_LINES * size_of(LineVertex), nil, gl.DYNAMIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(LineVertex), offset_of(LineVertex, point))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, false, size_of(LineVertex), offset_of(LineVertex, color))
}

lines_begin :: proc(proj, view: ^glm.mat4) {
    gl.UseProgram(line_renderer.shader.id)
    setMat4(line_renderer.shader.id, "uProjection", &proj[0, 0])
    setMat4(line_renderer.shader.id, "uView", &view[0, 0])
}

draw_line :: proc(start, end: glm.vec3, color: glm.vec3 = 1) {
    if len(line_renderer.lines) >= MAX_LINES do lines_flush()
    append(&line_renderer.lines, LineVertex{ start, color }, LineVertex{ end, color })
}

draw_lines_aabb :: proc(min, max: glm.vec3) {
    draw_line(min, {max.x, min.y, min.z})
    draw_line(min, {min.x, max.y, min.z})
    draw_line(min, {min.x, min.y, max.z})

    draw_line(max, {min.x, max.y, max.z})
    draw_line(max, {max.x, min.y, max.z})
    draw_line(max, {max.x, max.y, min.z})

    draw_line({min.x, min.y, max.z}, {min.x, max.y, max.z})
    draw_line({min.x, min.y, max.z}, {max.x, min.y, max.z})
    draw_line({min.x, max.y, max.z}, {min.x, max.y, min.z})

    draw_line({max.x, min.y, min.z}, {max.x, max.y, min.z})
    draw_line({max.x, min.y, min.z}, {max.x, min.y, max.z})
    draw_line({max.x, max.y, min.z}, {min.x, max.y, min.z})
}

lines_flush :: proc() {
    if len(line_renderer.lines) == 0 do return

    gl.BindVertexArray(line_renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, line_renderer.vbo)

    gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(line_renderer.lines) * size_of(LineVertex), &line_renderer.lines[0])
    gl.DrawArrays(gl.LINES, 0, i32(len(line_renderer.lines)))

    clear(&line_renderer.lines)
}

QuadRenderer :: struct {
    vao, vbo, ibo: u32,
    shader: Shader,
    quad: [6]QuadVertex,
    instances: [dynamic]QuadInstance,
}
quad_renderer: QuadRenderer

QuadVertex :: struct {
    pos, tex_coord: glm.vec2,
}

QuadInstance :: struct {
    color: [4]u8,
    model: glm.mat4,
}

quad_renderer_init :: proc(shader: Shader) {
    qr: QuadRenderer
    gl.CreateVertexArrays(1, &qr.vao)
    gl.BindVertexArray(qr.vao)

    qr.shader = shader
    qr.quad = {
        {pos = { 1, -1}, tex_coord = {1, 0}},
        {pos = {-1, -1}, tex_coord = {0, 0}},
        {pos = {-1,  1}, tex_coord = {0, 1}},

        {pos = { 1,  1}, tex_coord = {1, 1}},
        {pos = { 1, -1}, tex_coord = {1, 0}},
        {pos = {-1,  1}, tex_coord = {0, 1}},
    }
    qr.instances = make([dynamic]QuadInstance, 0, MAX_QUADS)

    gl.CreateBuffers(1, &qr.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, qr.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, 6 * size_of(QuadVertex), &qr.quad, gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(QuadVertex), offset_of(QuadVertex, pos))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(QuadVertex), offset_of(QuadVertex, tex_coord))

    gl.CreateBuffers(1, &qr.ibo)
    gl.BindBuffer(gl.ARRAY_BUFFER, qr.ibo)
    gl.BufferData(gl.ARRAY_BUFFER, MAX_QUADS * size_of(QuadInstance), nil, gl.DYNAMIC_DRAW)

    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 4, gl.UNSIGNED_BYTE, true, size_of(QuadInstance), offset_of(QuadInstance, color))
    gl.VertexAttribDivisor(2, 1)

    for i in 0..<4 {
        id := u32(3 + i)
        gl.EnableVertexAttribArray(id)
        offset := offset_of(QuadInstance, model) + (uintptr(i * 4) * size_of(f32))
        gl.VertexAttribPointer(id, 4, gl.FLOAT, false, size_of(QuadInstance), offset)
        gl.VertexAttribDivisor(id, 1)
    }

    quad_renderer = qr
}

quads_begin :: proc(screen: glm.vec2) {
    gl.UseProgram(quad_renderer.shader.id)

    proj := glm.mat4Ortho3d(0, screen.x, screen.y, 0, -1, 1)
    setMat4(quad_renderer.shader.id, "projection", &proj[0, 0])
}

draw_quad :: proc(pos, size: glm.vec2, radians: f32 = 0, color: [4]u8 = 255) {
    if len(quad_renderer.instances) + 1 >= MAX_QUADS {
        quads_flush()
    }

    model := glm.mat4Translate({pos.x, pos.y, 0})
    model *= glm.mat4Translate({0.5 * size.x, 0.5 * size.y, 0})
    model *= glm.mat4Rotate({0, 0, 1}, radians)
    model *= glm.mat4Translate({-0.5 * size.x, -0.5 * size.y, 0})
    model *= glm.mat4Scale({size.x, size.y, 1})

    append(&quad_renderer.instances, QuadInstance{
        color = color,
        model = model,
    })
}

quads_flush :: proc() {
    if len(quad_renderer.instances) == 0 {
        return
    }

    gl.BindVertexArray(quad_renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, quad_renderer.ibo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(quad_renderer.instances) * size_of(QuadInstance), &quad_renderer.instances[0])
    gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, i32(len(quad_renderer.instances)))

    clear(&quad_renderer.instances)
}

FullscreenQuadRenderer :: struct {
    vao, vbo: u32,
    shader: Shader,
    quad: [6]FullscreenQuadVertex,
}

FullscreenQuadVertex :: QuadVertex

fullscreen_quad_renderer : FullscreenQuadRenderer

fullscreen_quad_renderer_init :: proc(shader: Shader) {
    qr : FullscreenQuadRenderer
    gl.CreateVertexArrays(1, &qr.vao)
    gl.BindVertexArray(qr.vao)
    defer gl.BindVertexArray(0)

    qr.shader = shader
    qr.quad = {
        {pos = { 1, -1}, tex_coord = {1, 0}},
        {pos = {-1, -1}, tex_coord = {0, 0}},
        {pos = {-1,  1}, tex_coord = {0, 1}},

        {pos = { 1,  1}, tex_coord = {1, 1}},
        {pos = { 1, -1}, tex_coord = {1, 0}},
        {pos = {-1,  1}, tex_coord = {0, 1}},
    }

    gl.CreateBuffers(1, &qr.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, qr.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, 6 * size_of(FullscreenQuadVertex), &qr.quad, gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(FullscreenQuadVertex), offset_of(FullscreenQuadVertex, pos))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(FullscreenQuadVertex), offset_of(FullscreenQuadVertex, tex_coord))

    fullscreen_quad_renderer = qr
}

draw_fullscreen_quad :: proc(tex: u32) {
    // gl.BindTextureUnit(0, tex)
    gl.BindTexture(gl.TEXTURE_2D, tex)
    gl.UseProgram(fullscreen_quad_renderer.shader.id)
    setInt(fullscreen_quad_renderer.shader.id, "tex", 0)

    gl.BindVertexArray(fullscreen_quad_renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, fullscreen_quad_renderer.vbo)

    // gl.BufferSubData(gl.ARRAY_BUFFER, 0, 6 * size_of(QuadVertex), &fullscreen_quad_renderer.quad[0])

    gl.DrawArrays(gl.TRIANGLES, 0, 6)
}