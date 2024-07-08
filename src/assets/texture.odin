package assets 

import "vendor:stb/image"
import gl "vendor:OpenGL"

Texture :: struct {
	id, unit: u32,
	format: u32,
}

TextureOptions :: struct {
	width, height: i32,
	format: TextureFormat,
	min_filter, mag_filter: TextureFilter,
	wrap_s, wrap_t: TextureWrap,
}

TextureFormat :: enum {
	RGB,
	RGBA,
	RED_INT,
}

TextureFilter :: enum i32 {
	// Color of nearest texel to coordinate.
	NEAREST = gl.NEAREST,
	// Interpolates between coordinate's neighboring texels.
	LINEAR = gl.LINEAR,
}

TextureWrap :: enum i32 {
	REPEAT = gl.REPEAT,
	MIRRORED_REPEAT = gl.MIRRORED_REPEAT,
	CLAMP_TO_EDGE = gl.CLAMP_TO_EDGE,
	CLAMP_TO_BORDER = gl.CLAMP_TO_BORDER,
}

texture_format :: proc(tf: TextureFormat) -> (u32, u32) {
	switch tf {
		case .RGB:
			return gl.RGB8, gl.RGB
		case .RGBA:
			return gl.RGBA8, gl.RGBA
		case .RED_INT:
			return gl.R32I, gl.RED_INTEGER
		case:
			panic("unsupported texture format")
	}
}

texture_init :: proc(unit: u32, opt: TextureOptions) -> Texture {
    tex: Texture
	internal, format := texture_format(opt.format)
	tex.format = format
	tex.unit = unit

	gl.CreateTextures(gl.TEXTURE_2D, 1, &tex.id)
	gl.TextureStorage2D(tex.id, 1, internal, opt.width, opt.height)

	gl.TextureParameteri(tex.id, gl.TEXTURE_MIN_FILTER, i32(opt.min_filter))
	gl.TextureParameteri(tex.id, gl.TEXTURE_MAG_FILTER, i32(opt.mag_filter))
	gl.TextureParameteri(tex.id, gl.TEXTURE_WRAP_S, i32(opt.wrap_s))
	gl.TextureParameteri(tex.id, gl.TEXTURE_WRAP_T, i32(opt.wrap_t))

    gl.BindTextureUnit(tex.unit, tex.id)

    return tex
}

texture_load :: proc(unit: u32, path: cstring) -> Texture {
	image.set_flip_vertically_on_load(1)
	width, height, channels: i32
	img := image.load(path, &width, &height, &channels, 0)
    defer image.image_free(img)

	tex := texture_init(unit, TextureOptions{
		width = width, height = height,
		format = gl_format(channels),
		min_filter = .LINEAR, mag_filter = .NEAREST,
		wrap_s = .REPEAT, wrap_t = .REPEAT,
	})

	gl.TextureSubImage2D(tex.id, 0, 0, 0, width, height, tex.format, gl.UNSIGNED_BYTE, img)

	return tex
}

gl_format :: #force_inline proc(channels: i32) -> TextureFormat{
	switch channels {
		case 3: return .RGB
		case 4: return .RGBA
		case: panic("unsupported channels")
	}
}

texture_init_white :: proc(unit: u32) -> Texture {
    FORMAT :: TextureFormat.RGBA
    tex := texture_init(unit, {
        format = FORMAT,
        height = 1, width = 1,
        min_filter = .LINEAR, mag_filter = .NEAREST,
        wrap_s = .REPEAT, wrap_t = .REPEAT,
    })
    internal, format := texture_format(FORMAT)
    pixels := [?]u32{0xFFFFFFFF}
    gl.TextureSubImage2D(tex.id, 0, 0, 0, 1, 1, format, gl.UNSIGNED_BYTE, &pixels[0])

    return tex
}