package main

import "base:runtime"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:mem"

import gl "vendor:OpenGL"
import "vendor:glfw"

import "entity"
import "physics"
import "render"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

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

    view := glm.mat4LookAt({-10, 15, -30}, 0, {0, 1, 0})
    projection := glm.mat4Perspective(70, 1600.0/900.0, 0.1, 1000)

    prev_time := f32(glfw.GetTime())

    init_entities()

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

        physics.bodies_update(dt)

        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.Enable(gl.DEPTH_TEST)

        

        gl.UseProgram(shader.id)
        render.setMat4(shader.id, "uView", &view[0, 0])
        render.setMat4(shader.id, "uProjection", &projection[0, 0])

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
    floor := entity.new(scale = {100, 0, 100})
    append(&render.meshes, render.Mesh{entity_id = floor, color = {0, 0, 1, 1}})
    append(&physics.bodies, physics.Body{ entity_id = floor})

    box1 := entity.new(pos = {0, 20, 0})
    append(&render.meshes, render.Mesh{entity_id = box1, color = {1, 0, 0, 0.25}})
    append(&physics.bodies, physics.Body{entity_id = box1 })

    box2 := entity.new(pos = {5, 30, 0},  scale = {2, 1, 2})
    append(&render.meshes, render.Mesh{entity_id = box2, color = {0, 1, 0, 1}})
    append(&physics.bodies, physics.Body{entity_id = box2, angular_vel = {0, 1, 0} })
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