package assets

import "core:fmt"

textures: [dynamic]Texture
texture_units: [dynamic]i32 // For shaders, just a range of numbers [0..<len(textures)]

TEXTURE_PATHS := []cstring{
    "assets/die.png",
}

init :: proc() {
    tex := texture_init_white(0)
    register_texture(tex)

     for path, i in TEXTURE_PATHS {
        tex := texture_load(u32(i + 1), path)
        register_texture(tex)
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