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
debug_draw: bool

main :: proc() {
    if !glfw.Init() {
        fmt.eprintln("Failed to initialize GLFW")
        return
    }
    defer glfw.Terminate()
    glfw.SetErrorCallback(error_callback)

    window := glfw.CreateWindow(1600, 900, "Dice", nil, nil)
    if window == nil {
        fmt.eprintln("Failed to create window")
        return
    }
    defer glfw.DestroyWindow(window) 
    glfw.MakeContextCurrent(window)

    glfw.SetKeyCallback(window, key_callback)
    glfw.SetMouseButtonCallback(window, mouse_button_callback)
    glfw.SetCursorPosCallback(window, mouse_callback)

    gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)
    gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LESS)
    gl.Enable(gl.CULL_FACE)

    shader, err := render.shader_load("src/shaders/cube.glsl")
    if err != nil {
        fmt.eprintf("Failed to load cube shader: %v", err)
        return
    }

    cube_obj, cube_err := render.load_obj("assets/cube.obj")
    if cube_err != nil {
        fmt.panicf("Failed to load cube mesh")
    }

    mesh := render.renderer_init(cube_obj)
    defer render.renderer_deinit(&mesh)

    render.shapes_init()

    physics.shapes[.Box].vertex_count = len(cube_obj.vertices)
    for v, i in cube_obj.vertices {
        physics.shapes[.Box].vertices[i] = glm.vec3(v)
    }

    prev_time := f32(glfw.GetTime())
    timescale := f32(2)

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
        dt := min(timescale * (now - prev_time), 0.05)
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
        render.setFloat3(shader.id, "uCamPos", cam.pos)
        render.setStruct(shader.id, "uLight", render.Light, render.Light{
            position = 5,
            direction = {0, 0, 1},

            ambient = 0.5,
            diffuse = 0.5,
            specular = 0.75,

            constant = 1,
            linear = 0.09,
            quadratic = 0.032,

            cutoff = 12.5,
            outer_cutoff = 17.5,
        })

        for m in render.meshes {
            color := m.color
            for body in physics.bodies do if body.entity_id == m.entity_id && body.at_rest {
                color = {0.5, 0.5, 0.5, 1}
                break
            }
            render.renderer_draw(&mesh, {
                transform = entity.transform(m.entity_id),
                color = color,
            })
        }

        render.renderer_flush(&mesh)

        if debug_draw {
            render.lines_begin(&proj, &view)
            physics.colliders_update()
            for c in physics.colliders {
                render.draw_lines_aabb(c.aabb.min, c.aabb.max)
            }

            for m in render.meshes {
                p := entity.get(m.entity_id).pos
                render.draw_line(p, p + {0, 10, 0}, color = m.color.rgb)
            }
            render.lines_flush()
        }
    }
}

init_entities :: proc() {
    floor := entity.new(pos = {0, -5, 0}, scale = {30, 3, 30})
    append(&render.meshes, render.Mesh{entity_id = floor, color = {0, 0, 1, 1}})
    physics.bodies_create(floor, .Box)

    box1 := entity.new(pos = {0, 20, 0})
    append(&render.meshes, render.Mesh{entity_id = box1, color = {1, 0, 0, 1}})
    physics.bodies_create(box1, .Box, mass = 1)

    box2 := entity.new(pos = {10, 5, 0}, scale = {3, 2, 3})
    append(&render.meshes, render.Mesh{entity_id = box2, color = {0, 1, 0, 1}})
    physics.bodies_create(box2, .Box, mass = 9, vel = {0, 0, 0}, ang_vel = {1, 0, 0})

    box3 := entity.new(pos = {-6, 0, 0}, scale = {1, 2, 1})
    append(&render.meshes, render.Mesh{entity_id = box3, color = {0, 1, 1, 1}})
    physics.bodies_create(box3, .Box, mass = 20, vel = {0, 10, 0})
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
    if key == glfw.KEY_LEFT_SHIFT && action == glfw.PRESS {
        debug_draw = !debug_draw
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
    forward := int(glfw.GetKey(w, glfw.KEY_W) == glfw.PRESS) -
               int(glfw.GetKey(w, glfw.KEY_S) == glfw.PRESS)
    cam.pos += f32(forward) * cam.forward * cam.speed * dt

    horiz := int(glfw.GetKey(w, glfw.KEY_D) == glfw.PRESS) -
             int(glfw.GetKey(w, glfw.KEY_A) == glfw.PRESS)
    cam.pos += f32(horiz) * cam.right * cam.speed * dt

    vertical := int(glfw.GetKey(w, glfw.KEY_E) == glfw.PRESS) -
                int(glfw.GetKey(w, glfw.KEY_Q) == glfw.PRESS)
    cam.pos.y += f32(vertical) * cam.speed * dt
}