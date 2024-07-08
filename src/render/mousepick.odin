package render

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

import "../assets"

// Texture for mouse-picking. Each pixel is an entity ID.
MousePicking :: struct {
	fbo, rbo: u32,
	tex, entity_id_tex: u32,
}

// TODO: Resize framebuffer components on window resize.
mouse_picking_init :: proc(screen: glm.vec2) -> (mp: MousePicking, ok: bool) {
	size := glm.ivec2{i32(screen.x), i32(screen.y)}

	gl.GenFramebuffers(1, &mp.fbo)
	gl.BindFramebuffer(gl.FRAMEBUFFER, mp.fbo)
	defer gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

	// Depth and stencil render buffer
	gl.GenRenderbuffers(1, &mp.rbo)
	gl.BindRenderbuffer(gl.RENDERBUFFER, mp.rbo)

	mouse_picking_init_textures(&mp, size)

	gl.ReadBuffer(gl.NONE)
	attachments := [?]u32{gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1}
	gl.DrawBuffers(2, &attachments[0])

	if status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER); status != gl.FRAMEBUFFER_COMPLETE {
		fmt.eprintln("Mouse picking framebuffer error: status =", status)
		return mp, false
	}

	return mp, true
}

mouse_picking_read :: proc(mp: MousePicking, coord: glm.vec2) -> int {
	x, y := i32(coord.x), i32(coord.y)

	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, mp.fbo)
	defer gl.BindFramebuffer(gl.READ_FRAMEBUFFER, 0)

	gl.ReadBuffer(gl.COLOR_ATTACHMENT1)
	defer gl.ReadBuffer(gl.NONE)

	id : int
	gl.ReadPixels(x, y, 1, 1, gl.RED_INTEGER, gl.INT, &id)

	return id
}

mouse_picking_init_textures :: proc(mp: ^MousePicking, size: glm.ivec2) {
	gl.NamedRenderbufferStorage(mp.rbo, gl.DEPTH24_STENCIL8, size.x, size.y)
	gl.NamedFramebufferRenderbuffer(mp.fbo, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, mp.rbo)

	mp.tex = assets.texture_init(0, {
		width = size.x, height = size.y,
		format = .RGB,
		min_filter = .LINEAR, mag_filter = .LINEAR,
		wrap_s = .REPEAT, wrap_t = .REPEAT,
	}).id
	gl.NamedFramebufferTexture(mp.fbo, gl.COLOR_ATTACHMENT0, mp.tex, 0)

	mp.entity_id_tex = assets.texture_init(0, {
		width = size.x, height = size.y,
		format = .RED_INT,
		min_filter = .LINEAR, mag_filter = .LINEAR,
		wrap_s = .REPEAT, wrap_t = .REPEAT,
	}).id
	gl.NamedFramebufferTexture(mp.fbo, gl.COLOR_ATTACHMENT1, mp.entity_id_tex, 0)
}

mouse_picking_resize :: proc(mp: ^MousePicking, size: glm.ivec2) {
	textures := [?]u32{mp.tex, mp.entity_id_tex}
	gl.DeleteTextures(2, &textures[0])

	mouse_picking_init_textures(mp, size)
}