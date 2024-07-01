// OBJ files store 3D geometry.
// # List of geometric vertices, with (x, y, z, [w]) coordinates, w is optional and defaults to 1.0.
// v 0.123 0.234 0.345 1.0
// v ...
// ...
// # List of texture coordinates, in (u, [v, w]) coordinates, these will vary between 0 and 1. v, w are optional and default to 0.
// vt 0.500 1 [0]
// vt ...
// ...
// # List of vertex normals in (x,y,z) form; normals might not be unit vectors.
// vn 0.707 0.000 0.707
// vn ...
// ...
// # Parameter space vertices in (u, [v, w]) form; free form geometry statement
// vp 0.310000 3.210000 2.100000
// vp ...
// ...
// # Polygonal face element
// f 1 2 3
// f 3/1 4/2 5/3
// f 6/4/1 3/5/3 7/6/5
// f 7//1 8//2 9//3
// f ...
// ...
// # Line element
// l 5 8 1 2 4 9
package render

import "core:os"
import "core:strings"
import "core:strconv"
import "core:fmt"

ObjParseError :: enum {
    None,
	ReadFile,
	Alloc,
	ParseFloat,
	ParseUnsigned,
	FaceNotEnoughArgs,
	Vec2NotEnoughArgs,
	Vec3NotEnoughArgs,
}

Obj :: struct {
	name:       string,
	vertices:   [dynamic][3]f32,
	tex_coords: [dynamic][2]f32,
	normals:    [dynamic][3]f32,
	faces:      [dynamic]Face,
}

Face :: struct {
	vertex_index:    u32,
	tex_coord_index: u32,
	normal_index:    u32,
}

load_obj :: proc(path: string) -> (obj: Obj, obj_err: ObjParseError) {
	context.allocator = context.temp_allocator
	obj.name = "Name not found"

	text, ok := os.read_entire_file(path)
	if !ok {
		return obj, .ReadFile
	}
	defer delete(text)


	s := string(text)
	for line in strings.split_lines_iterator(&s) {
		tokens, err := strings.split(line, " ")
		if err != nil {
			fmt.eprintln("Alloc error: ", err)
			return obj, .Alloc
		}

		if len(tokens) < 2 {
			continue
		}

		switch tokens[0] {
		case "v":
			vec3 := parse_vec3(tokens) or_return
			append(&obj.vertices, vec3)
		case "vt":
			vec2 := parse_vec2(tokens) or_return
			append(&obj.tex_coords, vec2)
		case "vn":
			vec3 := parse_vec3(tokens) or_return
			append(&obj.normals, vec3)
		case "f":
			parse_face(tokens, &obj.faces) or_return
		case "o":
			obj.name = tokens[1]
		}
	}

	return obj, nil
}

// Can optionally include a w component, but we ignore it:
// v 0.123 0.234 0.345 1.0
@(private)
parse_vec3 :: proc(tokens: []string) -> ([3]f32, ObjParseError) {
	v := [3]f32{}

	if len(tokens) != 4 && len(tokens) != 5 {
		return v, .Vec3NotEnoughArgs
	}

	ok := false
	if v.x, ok = strconv.parse_f32(tokens[1]); !ok {
		return v, .ParseFloat
	}
	if v.y, ok = strconv.parse_f32(tokens[2]); !ok {
		return v, .ParseFloat
	}
	if v.z, ok = strconv.parse_f32(tokens[3]); !ok {
		return v, .ParseFloat
	}

	return v, nil
}

// vt 0.500 1
@(private)
parse_vec2 :: proc(tokens: []string) -> ([2]f32, ObjParseError) {
	v := [2]f32{}

	if len(tokens) != 3 {
		return v, .Vec2NotEnoughArgs
	}

	ok := false
	if v.x, ok = strconv.parse_f32(tokens[1]); !ok {
		return v, .ParseFloat
	}
	if v.y, ok = strconv.parse_f32(tokens[2]); !ok {
		return v, .ParseFloat
	}

	return v, nil
}

// index/tex_coord_index/normal_index
// 2/1/1 3/2/1 4/3/1 ...
@(private)
parse_face :: proc(tokens: []string, faces: ^[dynamic]Face) -> ObjParseError {
	for token in tokens[1:] {
		s := strings.split(token, "/")
		if len(s) != 3 {
			return .FaceNotEnoughArgs
		}

		face: Face
		ok: bool

		if face.vertex_index, ok = parse_u32(s[0]); !ok {
			return .ParseUnsigned
		}
		if face.tex_coord_index, ok = parse_u32(s[1]); !ok {
			return .ParseUnsigned
		}
		if face.normal_index, ok = parse_u32(s[2]); !ok {
			return .ParseUnsigned
		}

		append(faces, face)
	}

	return nil
}

@(private)
parse_u32 :: proc(s: string) -> (u32, bool) {
	u, ok := strconv.parse_uint(s)
	return u32(u), ok
}