package assets

textures: [dynamic]Texture
texture_units: [dynamic]i32 // For shaders, just a range of numbers [0..<len(textures)]

TEXTURE_PATHS := []cstring{
    "assets/die.png",
}

init :: proc() {
    tex := texture_init_white(0)
    append(&textures, tex)
    append(&texture_units, i32(tex.unit))

    for path, i in TEXTURE_PATHS {
        tex := texture_load(u32(i + 1), path)
        append(&textures, tex)
        append(&texture_units, i32(tex.unit))
    }
}

