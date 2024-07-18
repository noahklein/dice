package render

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "../window"

import ft "../libs/freetype"

text_render: TextRenderer
characters: map[byte]Character

MAX_TEXT_MODELS :: 200
FONT_SIZE :: 256

TextError :: union #shared_nil { ft.Error, ShaderError }

TextRenderer :: struct {
    vao, vbo, ibo: u32,
    shader: Shader,
    tex: u32,
    characters: map[byte]Character,

    batch: [dynamic]Text,
    instances: [dynamic]TextInstance,
}

Character :: struct {
    c: i32,
    size: glm.vec2,    // Dimensions of glyph.
    bearing: glm.vec2, // Offset from baseline to left/top of glyph.
    advance: uint,     // Offset to advance to next glyph.
}

TextInstance :: struct {
    model: glm.mat4,
    letter: i32,
}

Text :: struct{ text: string, pos: glm.vec2, scale: f32 }

draw_textf :: proc(pos: glm.vec2, strf: string, args: ..any, scale: f32 = 1) {
    draw_text(pos, fmt.tprintf(strf, ..args), scale)
}

draw_text :: proc(pos: glm.vec2, text: string, scale: f32 = 1) {
    append(&text_render.batch, Text{text = text, pos = pos, scale = scale})
}

flush_text :: proc() {
    if len(text_render.batch) == 0 do return

    gl.BindVertexArray(text_render.vao)
    gl.UseProgram(text_render.shader.id)
    // gl.Disable(gl.CULL_FACE)

    gl.BindTexture(gl.TEXTURE_2D_ARRAY, text_render.tex)

    // Bottom and top are flipped, {0, 0} is bottom-left of screen.
    proj := glm.mat4Ortho3d(
        left = 0, right = window.screen.x,
        bottom = 0, top = window.screen.y,
        near = -100, far = 100,
    )
    setMat4(text_render.shader.id, "projection", &proj[0, 0])
    gl.BindBuffer(gl.ARRAY_BUFFER, text_render.ibo)

    defer clear(&text_render.batch)
    for t in text_render.batch {
        clear(&text_render.instances)
        render_text(t)

        gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(text_render.instances) * size_of(TextInstance), &text_render.instances[0])
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, i32(len(text_render.instances)))
    }
}

@(private) render_text :: proc(t: Text) {
    first_x := t.pos.x
    pos := t.pos
    scale := t.scale * 48 / FONT_SIZE

    for c in t.text {
        char, ok := text_render.characters[byte(c)]
        if !ok {
            fmt.eprintfln("Can't draw unrecognized character: '%c'", c)
            pos.x += f32(char.advance >> 6) * scale
        }
        // Don't draw whitespace, just advance the next draw position.
        switch c {
            case '\n':
                pos.x  = first_x
                pos.y -= char.size.y * 1.35 * scale
                continue
            case  ' ':
                pos.x += f32(char.advance >> 6) * scale
                continue
        }
        if len(text_render.instances) + 1 >= MAX_TEXT_MODELS {
            return // TODO: finish in next batch
        }

        x := pos.x + char.bearing.x * scale
        y := pos.y - (FONT_SIZE - char.bearing.y) * scale

        model := glm.mat4Translate({x, y, 0}) *
                 glm.mat4Scale(FONT_SIZE * {scale, scale, 0})
        append(&text_render.instances, TextInstance{ model = model, letter = char.c })

        pos.x += f32(char.advance >> 6) * scale
    }
}

text_renderer_init :: proc() -> TextError {
    text_render.instances = make([dynamic]TextInstance, 0, MAX_TEXT_MODELS)
    text_render.shader = shader_load("src/shaders/text.glsl") or_return
    freetype_load_font() or_return

    QUAD_VERTS := [8]f32 {
        0, 1,
        0, 0,
        1, 1,
        1, 0,
    }

    gl.GenVertexArrays(1, &text_render.vao)
    gl.BindVertexArray(text_render.vao)

    gl.GenBuffers(1, &text_render.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, text_render.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * len(QUAD_VERTS), &QUAD_VERTS[0], gl.STATIC_DRAW)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2*size_of(f32), 0)

    gl.GenBuffers(1, &text_render.ibo)
    gl.BindBuffer(gl.ARRAY_BUFFER, text_render.ibo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(TextInstance) * MAX_TEXT_MODELS, nil, gl.DYNAMIC_DRAW)

    gl.EnableVertexAttribArray(1)
    gl.VertexAttribIPointer(1, 1, gl.INT, size_of(TextInstance), offset_of(TextInstance, letter))
    gl.VertexAttribDivisor(1, 1)

    for i in 0..<4 {
        id := u32(2 + i)
        gl.EnableVertexAttribArray(id)
        offset := offset_of(TextInstance, model) + (uintptr(i * 4) * size_of(f32))
        gl.VertexAttribPointer(id, 4, gl.FLOAT, false, size_of(TextInstance), offset)
        gl.VertexAttribDivisor(id, 1)
    }

    return nil
}

freetype_load_font :: proc() -> ft.Error {
    lib: ft.Library
    ft.init_free_type(&lib) or_return
    defer ft.done_free_type(lib)

    face: ft.Face
    ft.new_face(lib, "assets/fonts/LiberationMono.ttf", 0, &face) or_return
    // ft.new_face(lib, "assets/fonts/Antonio.ttf", 0, &face) or_return
    defer ft.done_face(face)

    ft.set_pixel_sizes(face, FONT_SIZE, FONT_SIZE)

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1) // Disable byte-alignment restriction.
    gl.GenTextures(1, &text_render.tex)
    gl.BindTexture(gl.TEXTURE_2D_ARRAY, text_render.tex)
    defer gl.BindTexture(gl.TEXTURE_2D_ARRAY, 0)
    gl.TexImage3D(gl.TEXTURE_2D_ARRAY, 0, gl.R8, FONT_SIZE, FONT_SIZE, 128, 0, gl.RED, gl.UNSIGNED_BYTE, nil)

    for c in byte(0)..<128 {
        if err := ft.load_char(face, u64(c), {.Render}); err != nil {
            fmt.eprintfln("Failed to load char %v: %v", c, err)
            continue
        }

        bm := face.glyph.bitmap
        gl.TexSubImage3D(
            gl.TEXTURE_2D_ARRAY, 0,
            FONT_SIZE - i32(bm.width), 0, i32(c),
            i32(bm.width), i32(bm.rows), 1,
            gl.RED,
            gl.UNSIGNED_BYTE,
            face.glyph.bitmap.buffer,
        )

        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

        text_render.characters[c] = Character{
            c = i32(c),
            size = {f32(bm.width), f32(bm.rows)},
            bearing = {f32(face.glyph.bitmap_left), f32(face.glyph.bitmap_top)},
            advance = uint(face.glyph.advance.x),
        }
    }

    return nil
}
