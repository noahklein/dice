package main

import "base:runtime"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:mem"

import gl "vendor:OpenGL"
import "vendor:glfw"

import "physics"
import "render"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

main :: proc() {
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }
    defer free_all(context.temp_allocator)

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
    gl.Enable(gl.LINE_SMOOTH)
    gl.LineWidth(3)

    shader, err := render.shader_load("src/shaders/cube.glsl")
    if err != nil {
        fmt.panicf("Failed to load cube shader: %v", err)
    }

    cube_obj, cube_err := render.load_obj("assets/cube.obj")
    if cube_err != nil {
        fmt.panicf("Failed to load cube mesh")
    }

    mesh := render.mesh_init(cube_obj)
    defer render.mesh_deinit(&mesh)

    view := glm.mat4LookAt({0, 0, -30}, 0, {0, 1, 0})
    projection := glm.mat4Perspective(70, 1600.0/900.0, 0.1, 1000)

    physics.init_bodies()
    defer physics.deinit_bodies()

    prev_time := f32(glfw.GetTime())

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

        // gl.BindVertexArray(mesh.vao)
        // gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vbo)

        gl.UseProgram(shader.id)
        render.setMat4(shader.id, "uView", &view[0, 0])
        render.setMat4(shader.id, "uProjection", &projection[0, 0])


        for body in physics.bodies {
            instance := render.Instance{ transform = physics.body_matrix(body) }
            render.mesh_draw(&mesh, instance)
        }
        render.mesh_flush(&mesh)
    }
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