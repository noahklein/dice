package assets

import "core:fmt"

textures: [dynamic]Texture
texture_units: [dynamic]i32 // For shaders, just a range of numbers [0..<len(textures)]

TextureId :: enum u8 { None, D6, D4, D8 }
TEXTURE_PATHS := [TextureId]cstring{
    .None = "",
    .D6 = "assets/die.png",
    .D4 = "assets/tetrahedron.png",
    .D8 = "assets/octahedron.png",
}

texture_ids: [TextureId]Texture

init :: proc() {
    tex := texture_init_white(0)
    register_texture(tex)

    for id, i in TextureId do if id != .None {
        path := TEXTURE_PATHS[id]
        tex := texture_load(u32(i), path)
        register_texture(tex)
        texture_ids[id] = tex
    }
}

register_texture :: proc(tex: Texture) {
    for existing in textures {
        if existing.unit == tex.unit {
            fmt.eprintln("Texture unit already exists:", tex.unit)
        }
    }
    append(&textures, tex)
    append(&texture_units, i32(tex.unit))
}

tex_unit :: #force_inline proc(id: TextureId) -> u32 {
    return texture_ids[id].unit
}