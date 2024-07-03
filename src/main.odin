package main

import "base:runtime"
import "core:fmt"
import glm "core:math/linalg/glsl"

import gl "vendor:OpenGL"
import "vendor:glfw"

import "entity"
import "physics"
import "render"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

cursor_hidden: bool

main :: proc() {
    if !glfw.Init() {
        fmt.panicf("Failed to initialize GLFW")
    }
    defer glfw.Terminate()
    glfw.SetErrorCallback(error_callback)

    window := glfw.CreateWindow(1600, 900, "Dice", nil, nil)
    if window == nil {
        fmt.panicf("Failed to create window")
    }
    defer glfw.DestroyWindow(window) 
    glfw.MakeContextCurrent(window)

    glfw.SetKeyCallback(window, key_callback)
    glfw.SetMouseButtonCallback(window, mouse_button_callback)
    glfw.SetCursorPosCallback(window, mouse_callback)
    glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)

    gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)
    gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LESS)
    gl.Enable(gl.CULL_FACE)

    shader, err := render.shader_load("src/shaders/cube.glsl")
    if err != nil {
        fmt.panicf("Failed to load cube shader: %v", err)
    }

    cube_obj, cube_err := render.load_obj("assets/cube.obj")
    if cube_err != nil {
        fmt.panicf("Failed to load cube mesh")
    }

    mesh := render.renderer_init(cube_obj)
    defer render.renderer_deinit(&mesh)

    physics.shapes[.Box].vertex_count = len(cube_obj.vertices)
    for v, i in cube_obj.vertices {
        physics.shapes[.Box].vertices[i] = glm.vec3(v)
    }

    prev_time := f32(glfw.GetTime())

    init_entities()
    init_camera(1600.0 / 900.0)

    for !glfw.WindowShouldClose(window) {
        defer {
            glfw.SwapBuffers(window)
            render.watch(&shader)
            free_all(context.temp_allocator)
        }

        glfw.PollEvents()

        now := f32(glfw.GetTime())
        dt := now - prev_time
        prev_time = now

        handle_input(window, dt)
        physics.bodies_update(dt)

        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.Enable(gl.DEPTH_TEST)

        proj, view := projection(cam), look_at(cam)

        gl.UseProgram(shader.id)
        render.setMat4(shader.id, "uView", &view[0, 0])
        render.setMat4(shader.id, "uProjection", &proj[0, 0])

        for m in render.meshes {
            render.renderer_draw(&mesh, {
                transform = entity.transform(m.entity_id),
                color = m.color,
            })
        }

        render.renderer_flush(&mesh)
    }
}

init_entities :: proc() {
    floor := entity.new(pos = {0, -5, 0}, scale = {100, 10, 100})
    append(&render.meshes, render.Mesh{entity_id = floor, color = {0, 0, 1, 1}})
    append(&physics.bodies, physics.Body{ entity_id = floor, shape = .Box, static = true })

    box1 := entity.new(pos = {0, 20, 0})
    append(&render.meshes, render.Mesh{entity_id = box1, color = {1, 0, 0, 1}})
    append(&physics.bodies, physics.Body{entity_id = box1, shape = .Box, mass = 1 })

    box2 := entity.new(pos = {5, 20, 0},  scale = {2, 1, 2})
    append(&render.meshes, render.Mesh{entity_id = box2, color = {0, 1, 0, 1}})
    append(&physics.bodies, physics.Body{entity_id = box2, shape = .Box, mass = 2, vel = {-1, 0, 0}, angular_vel = {0, 0, 0} })
}

error_callback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()
	fmt.eprintln(desc, code)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	context = runtime.default_context()
	if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
		glfw.SetWindowShouldClose(window, glfw.TRUE)
	}
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	context = runtime.default_context()

    if cursor_hidden {
        on_mouse_move(&cam, {f32(xpos), f32(ypos)})
        return
    }
}

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
    if button == glfw.MOUSE_BUTTON_RIGHT && action == glfw.PRESS {
        cursor_hidden = !cursor_hidden
        init_mouse = false

        cursor_status: i32 = glfw.CURSOR_DISABLED if cursor_hidden else glfw.CURSOR_NORMAL
        glfw.SetInputMode(window, glfw.CURSOR, cursor_status)
    }
}

handle_input :: proc(w: glfw.WindowHandle, dt: f32) {
    if glfw.GetKey(w, glfw.KEY_W) == glfw.PRESS {
        cam.pos += cam.forward * cam.speed * dt
    } else if glfw.GetKey(w, glfw.KEY_S) == glfw.PRESS {
        cam.pos -= cam.forward * cam.speed * dt
    }

    if glfw.GetKey(w, glfw.KEY_D) == glfw.PRESS {
        cam.pos += cam.right * cam.speed * dt
    } else if glfw.GetKey(w, glfw.KEY_A) == glfw.PRESS {
        cam.pos -= cam.right * cam.speed * dt
    }
}