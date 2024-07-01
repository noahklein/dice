package render

import "core:os"
import "core:strings"
import "core:fmt"
import "core:time"
import "core:reflect"

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

Shader :: struct {
	id:          u32,
	path:        string,
	last_reload: i64,
}

ShaderError :: enum {
	None,
	ReadFile,
	CompileFailed,
	LinkFailed,
	NeedTwoShaders,
	InvalidVert,
	InvalidFrag,
	WatchFailed,
}

shader_load :: proc(path: string) -> (s: Shader, err: ShaderError) {
	text, ok := os.read_entire_file_from_filename(path, context.temp_allocator)
	if !ok {
		return Shader{}, .ReadFile
	}

	pre := preprocess(string(text)) or_return
	shader_id := compile_and_link(pre.vert, pre.frag) or_return

	return Shader{
		id = shader_id,
		path = path,
		last_reload = time.now()._nsec,
	}, .None
}

@(private="file")
Preprocess :: struct {
	vert: string,
	frag: string,
}

// Vertex and fragment shaders are combined into a single file.
// Each must begin with one of (including new-line):
// #type vertex
// #type fragment
@(private="file")
preprocess :: proc(s: string) -> (Preprocess, ShaderError) {
	splits := strings.split(s, "#type ", context.temp_allocator)
	if len(splits) != 3 {
		return Preprocess{}, .NeedTwoShaders
	}

	vert, frag := splits[1], splits[2]
	if !strings.has_prefix(vert, "vertex") {
		return Preprocess{}, .InvalidVert
	}
	if !strings.has_prefix(frag, "fragment") {
		return Preprocess{}, .InvalidFrag
	}

	return Preprocess{
		vert = vert[len("vertex\n"):],
		frag = frag[len("fragment\n"):],
	}, nil
}

@(private="file")
compile_and_link :: proc(vert_src: string, frag_src: string) -> (program: u32, err: ShaderError) {
	vert := gl.CreateShader(gl.VERTEX_SHADER)
	defer gl.DeleteShader(vert)
	compile(vert, vert_src) or_return

	frag := gl.CreateShader(gl.FRAGMENT_SHADER)
	defer gl.DeleteShader(frag)
	compile(frag, frag_src) or_return

	program = gl.CreateProgram()
	gl.AttachShader(program, vert)
	gl.AttachShader(program, frag)
	link(program) or_return

	return program, nil
}

@(private="file")
compile :: proc(id: u32, src: string) -> ShaderError {
	s := strings.clone_to_cstring(src, context.temp_allocator)
	size := i32(len(src))

	gl.ShaderSource(id, 1, &s, &size)
	gl.CompileShader(id)

	// Check error
	success := i32(0)
	gl.GetShaderiv(id, gl.COMPILE_STATUS, &success)
	if success != 1 {
		info_log : [512]byte = ---
		gl.GetShaderInfoLog(id, 512, nil, raw_data(info_log[:]))
		fmt.eprintln("Failed to compile shader:", string(info_log[:]))
		return .CompileFailed
	}

	return nil
}

@(private="file")
link :: proc(program: u32) -> ShaderError {
	gl.LinkProgram(program)

	// Check error
	success := i32(0)
	gl.GetProgramiv(program, gl.LINK_STATUS, &success)
	if success != 1 {
		info_log : [1024]byte = ---
		gl.GetProgramInfoLog(program, 1024, nil, raw_data(info_log[:]))
		fmt.eprintln("Failed to link shader:", string(info_log[:]))
		return .LinkFailed
	}

	return nil
}

watch :: proc(s: ^Shader) -> ShaderError {
	now := time.now()._nsec
	defer s.last_reload = now

	stat, err := os.stat(s.path, context.temp_allocator)
	if err != os.ERROR_NONE {
		fmt.eprintln("os.stat error:", err)
		return .WatchFailed
	}

	if stat.modification_time._nsec >= s.last_reload {
		new_shader, err := shader_load(s.path)
		if err != nil {
			fmt.eprintln("Failed to reload shader:", err)
			return err
		}

		fmt.println("✅ Shader reload", s.path)

		gl.DeleteProgram(s.id)
		s^ = new_shader
	}

	return nil
}

setInt :: proc (id: u32, name: cstring, i: i32) {
	gl.Uniform1i(loc(id, name), i)
}
setFloat ::  proc (id: u32, name: cstring, f: f32) {
	gl.Uniform1f(loc(id, name), f)
}
setFloat3 ::  proc (id: u32, name: cstring, f: glm.vec3) {
    gl.Uniform3f(loc(id, name), f.x, f.y, f.z)
}
setFloat4 :: proc (id: u32, name: cstring, f: [4]f32) {
    gl.Uniform4f(loc(id, name), f.x, f.y, f.z, f.w)
}
setMat4 :: proc(id: u32, name: cstring, mat: [^]f32) {
    gl.UniformMatrix4fv(loc(id, name), 1, false, mat)
}
setIntArray :: proc(id: u32, name: cstring, count: i32, vals: [^]i32) {
    gl.Uniform1iv(loc(id, name), count, vals)
}


setStruct :: proc(id: u32, name: string, $T: typeid, obj: T) {
	context.allocator = context.temp_allocator

	for field_name in reflect.struct_field_names(T) {
		field := reflect.struct_field_by_name(T, field_name)
		val := reflect.struct_field_value(obj, field)

		name_parts := [?]string{name, ".", field_name}
		full_name := strings.clone_to_cstring(strings.concatenate(name_parts[:]))
		switch v in val {
			case i32:
				setInt(id, full_name, v)
			case f32:
				setFloat(id, full_name, v)
			case glm.vec3:
				setFloat3(id, full_name, v)
			case:
				fmt.eprintln("Unsupported field type in setStruct", full_name, v)
		}

	}

}

@(private="file")
loc :: proc(id: u32, name: cstring) -> i32 {
    return gl.GetUniformLocation(id, name)
}