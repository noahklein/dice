package render

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

import ft "../lib/freetype"

text_render: TextRenderer

TextError :: union #shared_nil { ft.Error, ShaderError }

TextRenderer :: struct {
    vao, vbo: u32,
    shader: Shader,
    screen: glm.vec2,
    characters: map[byte]Character,
}

Character :: struct {
    tex_id: u32,
    size: glm.vec2,    // Dimensions of glyph.
    bearing: glm.vec2, // Offset from baseline to left/top of glyph.
    advance: uint,     // Offset to advance to next glyph.
}

characters: map[byte]Character

draw_textf :: proc(pos: glm.vec2, strf: string, args: ..any, scale: f32 = 1) {
    draw_text(pos, fmt.tprintf(strf, ..args), scale)
}

draw_text :: proc(pos: glm.vec2, text: string, scale: f32 = 1) {
    gl.BindVertexArray(text_render.vao)
    gl.UseProgram(text_render.shader.id)

    // Bottom and top are flipped, {0, 0} is bottom-left of screen.
    proj := glm.mat4Ortho3d(
        left = 0, right = text_render.screen.x,
        bottom = 0, top = text_render.screen.y,
        near = -1000, far = 1000,
    )
    setMat4(text_render.shader.id, "projection", &proj[0, 0])

    pos := pos
    for c in text {
        char := text_render.characters[byte(c)]

        p := pos
        p.x += scale * char.bearing.x
        p.y -= scale * (char.size.y - char.bearing.y)

        a, b := p, p + char.size*scale // Min and max corners of AABB.
        verts := [6]glm.vec4{
            {a.x, b.y, 0, 0},
            {a.x, a.y, 0, 1},
            {b.x, a.y, 1, 1},

            {a.x, b.y, 0, 0},
            {b.x, a.y, 1, 1},
            {b.x, b.y, 1, 0},
        }

        gl.BindTexture(gl.TEXTURE_2D, char.tex_id)

        gl.BindBuffer(gl.ARRAY_BUFFER, text_render.vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(verts) * size_of(glm.vec4), &verts[0])

        gl.DrawArrays(gl.TRIANGLES, 0, 6)

        pos.x += f32(char.advance >> 6) * scale
    }
}

text_renderer_init :: proc(screen: glm.vec2) -> TextError {
    text_render.screen = screen
    text_render.shader = shader_load("src/shaders/text.glsl") or_return
    freetype_load_font() or_return

    gl.GenVertexArrays(1, &text_render.vao)
    gl.BindVertexArray(text_render.vao)

    gl.GenBuffers(1, &text_render.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, text_render.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, 6 * size_of(glm.vec4), nil, gl.DYNAMIC_DRAW)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, size_of(glm.vec4), 0)

    return nil
}

freetype_load_font :: proc() -> ft.Error {
    lib: ft.Library
    ft.init_free_type(&lib) or_return
    defer ft.done_free_type(lib)

    face: ft.Face
    ft.new_face(lib, "assets/fonts/LiberationMono.ttf", 0, &face) or_return
    defer ft.done_face(face)

    ft.set_pixel_sizes(face, 0, 16)

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1) // Disable byte-alignment restriction.

    for c in byte(0)..<128 {
        if err := ft.load_char(face, u64(c), {.Render}); err != nil {
            fmt.eprintfln("Failed to load char %v: %v", c, err)
            continue
        }

        tex: u32
        gl.GenTextures(1, &tex)
        gl.BindTexture(gl.TEXTURE_2D, tex)

        bm := face.glyph.bitmap
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, i32(bm.width), i32(bm.rows),
                      0, gl.RED, gl.UNSIGNED_BYTE, bm.buffer)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

        text_render.characters[c] = Character{
            tex_id = tex,
            size = {f32(bm.width), f32(bm.rows)},
            bearing = {f32(face.glyph.bitmap_left), f32(face.glyph.bitmap_top)},
            advance = uint(face.glyph.advance.x),
        }
    }

    return nil
}
