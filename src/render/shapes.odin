package render

import "core:fmt"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

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

MAX_LINES :: 100

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
    vao, vbo: u32,
    shader: Shader,
    quad: [6]QuadVertex,
}

QuadVertex :: struct {
    pos, tex_coord: glm.vec2,
}

quad_renderer : QuadRenderer

quad_renderer_init :: proc(shader: Shader) {
    qr : QuadRenderer
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
    gl.BufferData(gl.ARRAY_BUFFER, 6 * size_of(QuadVertex), &qr.quad, gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(QuadVertex), offset_of(QuadVertex, pos))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(QuadVertex), offset_of(QuadVertex, tex_coord))

    quad_renderer = qr
}

draw_quad :: proc(tex: u32) {
    // gl.BindTextureUnit(0, tex)
    gl.BindTexture(gl.TEXTURE_2D, tex)
    gl.UseProgram(quad_renderer.shader.id)
    setInt(quad_renderer.shader.id, "tex", 0)

    gl.BindVertexArray(quad_renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, quad_renderer.vbo)

    // gl.BufferSubData(gl.ARRAY_BUFFER, 0, 6 * size_of(QuadVertex), &quad_renderer.quad[0])

    gl.DrawArrays(gl.TRIANGLES, 0, 6)
}