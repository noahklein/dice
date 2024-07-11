package main

import "base:runtime"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:math/rand"

import gl "vendor:OpenGL"
import "vendor:glfw"

import "assets"
import "entity"
import "farkle"
import "nmath"
import "physics"
import "random"
import "render"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

cursor_hidden: bool
debug_draw: bool
physics_paused: bool

screen: glm.vec2
mouse_coords: glm.vec2
mouse_pick: render.MousePicking
hovered_ent_id, floor_ent_id: entity.ID

Input :: enum { Fire, Confirm, Stand }
input: bit_set[Input]

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

    assets.init()

    shader, err := render.shader_load("src/shaders/cube.glsl")
    if err != nil {
        fmt.eprintf("Failed to load cube shader: %v", err)
        return
    }

    cube_obj, cube_err := render.load_obj("assets/cube.obj")
    if cube_err != nil {
        fmt.eprintln("Failed to load cube mesh")
        return
    }

    sphere_obj, sphere_err := render.load_obj("assets/sphere.obj")
    if sphere_err != nil {
        fmt.eprintln("Failed to load sphere mesh")
        return
    }

    tetrahedron_obj, tetrahedron_err := render.load_obj("assets/tetrahedron.obj")
    if tetrahedron_err != nil {
        fmt.eprintln("Failed to load tetrahedron mesh")
        return
    }

    octahedron_obj, octahedron_err := render.load_obj("assets/octahedron.obj")
    if octahedron_err != nil {
        fmt.eprintln("Failed to load octahedron mesh")
        return
    }

    render.renderer_init(.Cube, cube_obj)
    defer render.renderer_deinit(.Cube)

    render.renderer_init(.Sphere, sphere_obj)
    defer render.renderer_deinit(.Sphere)

    render.renderer_init(.Tetrahedron, tetrahedron_obj)
    defer render.renderer_deinit(.Tetrahedron)

    render.renderer_init(.Octahedron, octahedron_obj)
    defer render.renderer_deinit(.Octahedron)


    {
        width, height := glfw.GetWindowSize(window)
        screen = {f32(width), f32(height)}
    }

    // Setup quad renderer.
    quad_shader, quad_shader_err := render.shader_load("src/shaders/quad.glsl")
    if quad_shader_err != nil {
        fmt.eprintln("Failed to load quad shader:", err)
        return
    }
    render.quad_renderer_init(quad_shader)
    if err := render.text_renderer_init(screen); err != nil {
        fmt.eprintln("failed to load text renderer", err)
        return
    }

    render.shapes_init()
    mouse_pick = render.mouse_picking_init(screen) or_else panic("failed to init mouse picking")

    physics.shapes[.Box].vertex_count = len(cube_obj.vertices)
    for v, i in cube_obj.vertices {
        physics.shapes[.Box].vertices[i] = glm.vec3(v)
    }
    physics.shapes[.Tetrahedron].vertex_count = len(tetrahedron_obj.vertices)
    for v, i in tetrahedron_obj.vertices {
        physics.shapes[.Tetrahedron].vertices[i] = glm.vec3(v)
    }
    physics.shapes[.Octahedron].vertex_count = len(octahedron_obj.vertices)
    for v, i in octahedron_obj.vertices {
        physics.shapes[.Octahedron].vertices[i] = glm.vec3(v)
    }

    for i := 0; i < len(octahedron_obj.faces); i += 3 {
        get_vertex :: proc(obj: render.Obj, face_index: int) -> glm.vec3 {
            vi := obj.faces[face_index].vertex_index
            return glm.vec3(obj.vertices[vi - 1])
        }

        a := get_vertex(octahedron_obj, i)
        b := get_vertex(octahedron_obj, i+1)
        c := get_vertex(octahedron_obj, i+2)
        plane := nmath.plane_from_tri(a, b, c)
        fmt.println("oct face normal", plane.normal)
    }

    prev_time := glfw.GetTime()

    init_entities()
    init_camera(1600.0 / 900.0)
    on_mouse_move(&cam, {1600, 900} / 2)

    fps_frames, fps_ms_per_frame: f64
    fps_prev_time := glfw.GetTime()
    for !glfw.WindowShouldClose(window) {
        defer {
            glfw.SwapBuffers(window)
            render.watch(&shader)
            render.watch(&quad_shader)
            render.watch(&render.text_render.shader)
            input = {}
            free_all(context.temp_allocator)
        }

        glfw.PollEvents()
        fps_frames += 1

        now := glfw.GetTime()
        if now - fps_prev_time >= 1 {
            fps_ms_per_frame = 1000.0 / fps_frames
            // fmt.printfln("%.3f ms/frame", 1000 / fps_frames)
            fps_frames = 0
            fps_prev_time = now
        }

        dt := f32(min((now - prev_time), 0.05))
        prev_time = now


        handle_input(window, dt)
        if !physics_paused {
            physics.bodies_update(TIMESCALE * dt)
        }

        hovered_ent_id = entity.ID(render.mouse_picking_read(mouse_pick, mouse_coords))
        if hovered_ent_id <= 0 || hovered_ent_id > 99999 { // @Hack: should clamp to valid IDs.
			hovered_ent_id = -1
		}

        update_farkle(dt)

        // Draw scene to mouse picking framebuffer.
        gl.BindFramebuffer(gl.FRAMEBUFFER, mouse_pick.fbo)
        gl.Enable(gl.CULL_FACE)

        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.Enable(gl.DEPTH_TEST)

        proj, view := projection(cam), look_at(cam)

        gl.UseProgram(shader.id)
        render.setMat4(shader.id, "uView", &view[0, 0])
        render.setMat4(shader.id, "uProjection", &proj[0, 0])
        render.setFloat3(shader.id, "uCamPos", cam.pos)
        render.setIntArray(shader.id, "uTextures", len(assets.texture_units), &assets.texture_units[0])
        render.setStruct(shader.id, "uLight", render.Light, render.Light{
            position = 5, direction = {0, 0, 1},
            ambient = 0.5, diffuse = 0.5, specular = 0.75,
            constant = 1, linear = 0.09, quadratic = 0.032,
            cutoff = 12.5, outer_cutoff = 17.5,
        })

        // Rebind textures to expected slots.
        for tex in assets.textures {
            gl.BindTextureUnit(tex.unit, tex.id)
        }

        render.render_all_meshes()

        // Draw outline around held dice.
        for type in farkle.DieType {
            mesh := render.MeshId.Sphere
            switch type {
                case .D4: mesh = .Tetrahedron
                case .D6: mesh = .Cube
                case .D8: mesh = .Octahedron
            }
            defer render.renderer_flush(mesh)

            for d in farkle.round.dice do if d.held && d.type == type {
                ent := entity.get(d.entity_id)
                ent.scale += 0.05
                defer ent.scale -= 0.05


                render.renderer_draw(mesh, {
                    transform = entity.transform(d.entity_id),
                    texture = 0,
                    color = {1, 1, 1, 0.25},
                    ent_id = d.entity_id,
                })
            }

        }
        render.renderer_flush(.Cube)

        when ODIN_DEBUG {
            // state := fmt.enum_value_to_string(farkle_state) or_else "Error"
            render.draw_textf({1500, 880}, "%.2f ms",  fps_ms_per_frame)
            render.draw_textf({20, 880}, "Lives: %v", farkle.round.turns_remaining)
            render.draw_textf({20, 860}, "Streak Score: %v", farkle.round.score)
            render.draw_textf({20, 840}, "Total  Score: %v", farkle.round.total_score)
            render.draw_textf({20, 820}, "%v", farkle_state)
            render.draw_textf({20, 800}, "Physics Paused: %v", physics_paused)
            #partial switch farkle_state {
            case .HoldingDice:
                render.draw_textf({20, 700}, "Best Hand: %v, %v", farkle.round_score_dice())
                render.draw_textf({20, 680}, "Selected: %v, %v", holding_hand, holding_score)
            case .Rolling:
                render.draw_textf({20, 700}, "Rolling Time: %.0f%%", 100 * dice_rolling_time / DICE_ROLLING_TIME_LIMIT)
            }

            for d in farkle.round.dice do if d.entity_id == hovered_ent_id {
                pip := farkle.die_facing_up(d.type, entity.get(d.entity_id).orientation)
                render.draw_textf({20, 600}, "Hovered die pip: %v", pip)
            }

            // The poor man's crosshair.
            if cursor_hidden do render.draw_text(screen / 2, "o")
        }

        {
            // Draw mousepicking texture to screen.
            gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
			gl.ClearColor(1.0, 1.0, 1.0, 1.0)
			gl.Clear(gl.COLOR_BUFFER_BIT)
			gl.Disable(gl.DEPTH_TEST)
            gl.Disable(gl.CULL_FACE)
			render.draw_quad(mouse_pick.tex)
        }

        if debug_draw {
            render.lines_begin(&proj, &view)
            physics.colliders_update()
            for c in physics.colliders {
                render.draw_lines_aabb(c.aabb.min, c.aabb.max)
            }

            render.lines_flush()
        }
    }
}

init_entities :: proc() {
    FLOOR_SIZE   :: 10
    WALL_HEIGHT :: 30
    floor := entity.new(pos = {0, -5, 0}, scale = {FLOOR_SIZE, 5, FLOOR_SIZE})
    render.create_mesh(.Cube, floor, {0, 0, 1, 1}, .None)
    physics.bodies_create(floor, .Box, restitution = 1)
    floor_ent_id = floor

    roof := entity.new(pos = {0, -5 + WALL_HEIGHT, 0}, scale = {FLOOR_SIZE, 3, FLOOR_SIZE})
    // append(&render.meshes, render.Mesh{entity_id = roof, color = {0, 0, 1, 1}})
    physics.bodies_create(roof, .Box, restitution = 1)

    create_wall :: proc(pos, scale: glm.vec3) {
        w := entity.new(pos = pos, scale = scale)
        // append(&render.meshes, render.Mesh{entity_id = w, color = {0, 0, 1, 0.25}})
        physics.bodies_create(w, .Box, restitution = 1)
    }

    create_wall({0, 0, -FLOOR_SIZE}, {FLOOR_SIZE, WALL_HEIGHT, 1})
    create_wall({0, 0,  FLOOR_SIZE}, {FLOOR_SIZE, WALL_HEIGHT, 1})
    create_wall({-FLOOR_SIZE, 0, 0}, {1, WALL_HEIGHT, FLOOR_SIZE})
    create_wall({ FLOOR_SIZE, 0, 0}, {1, WALL_HEIGHT, FLOOR_SIZE})

    // Create dice.
    for _, i in farkle.round.dice {
        die_type: farkle.DieType = rand.choice_enum(farkle.DieType)
        switch die_type {
        case .D4:
            id := entity.new(scale = 3) // @TODO: scale up tetrahedron model.
            render.create_mesh(.Tetrahedron, id, {0.4, 1, 0.4, 1}, .D4)
            physics.bodies_create(id, .Tetrahedron, mass = 1)
            farkle.round.dice[i] = farkle.Die{ entity_id = id, type = .D4 }
        case .D6:
            id := entity.new()
            render.create_mesh(.Cube, id, {1, 0.4, 0.4, 1}, .D6)
            physics.bodies_create(id, .Box, mass = 1)
            farkle.round.dice[i] = farkle.Die{ entity_id = id, type = .D6 }
        case .D8:
            id := entity.new()
            render.create_mesh(.Octahedron, id, {1, 1, 1, 1}, .D8)
            physics.bodies_create(id, .Octahedron, mass = 1, restitution = 0.6)
            farkle.round.dice[i] = farkle.Die{ entity_id = id, type = .D8 }
        }
    }
}

error_callback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()
	fmt.eprintln(desc, code)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	context = runtime.default_context()
    if action == glfw.PRESS do switch key {
        case glfw.KEY_ESCAPE:
            glfw.SetWindowShouldClose(window, glfw.TRUE)
        case glfw.KEY_LEFT_SHIFT:
            debug_draw = !debug_draw
        case glfw.KEY_SPACE:
            physics_paused = !physics_paused
        case glfw.KEY_T:
            physics_paused = false
            farkle_state = .ReadyToThrow
            throw_dice()

        case glfw.KEY_R: input += {.Confirm}
        case glfw.KEY_F: input += {.Stand}
    }
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	context = runtime.default_context()

    if cursor_hidden {
        on_mouse_move(&cam, {f32(xpos), f32(ypos)})
        return
    }

    mouse_coords.x = f32(xpos)
    mouse_coords.y = screen.y - f32(ypos)
}

mouse_button_callback :: proc "c" (w: glfw.WindowHandle, button, action, mods: i32) {
    context = runtime.default_context()

    if button == glfw.MOUSE_BUTTON_RIGHT && action == glfw.PRESS {
        cursor_hidden = !cursor_hidden
        if cursor_hidden do mouse_coords = screen / 2 // Set crosshair to center.
        init_mouse = false

        cursor_status: i32 = glfw.CURSOR_DISABLED if cursor_hidden else glfw.CURSOR_NORMAL
        glfw.SetInputMode(w, glfw.CURSOR, cursor_status)
        glfw.SetCursorPos(w, f64(0.5 * screen.x), f64(0.5 * screen.y))
    }

    if glfw.GetMouseButton(w, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS {
        input += {.Fire}
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

shoot_random_box :: proc(cursor, window_size: glm.vec2) {
    // Camera position will be cube spawn point. Move it forward temporarily to
    // make it look better.
    cam.pos += 2*cam.forward
    defer cam.pos -= 2*cam.forward

    ray := mouse_to_ray(cam, cursor, window_size)

    if p, ok := project_ray_plane(cam.pos, ray, {0, -1, 0}, {0, -2, 0}); ok {
        scale := glm.vec3(1)
        mass := scale.x * scale.y * scale.z

        color := 0.5 + 0.5*random.vec3().rgbr
        color.a = 1

        box := entity.new(pos = cam.pos, scale = scale, orientation = random.quat())
        append(&render.meshes, render.Mesh{entity_id = box, color = color, tex_unit = 1})
        physics.bodies_create(box, .Box, mass = mass, vel = p * ray)
    }
}

project_ray_plane :: proc(r_origin, r_dir, p_norm, p_center: glm.vec3) -> (glm.vec3, bool) {
    denom := glm.dot(r_dir, p_norm)
    if denom <= 1e-4 {
        return 0, false
    }

    t := glm.dot(p_center - r_origin, p_norm) / denom
    return t, t > 0
}

set_floor_color :: proc(color: [4]f32) {
    for &m in render.meshes do if m.entity_id == floor_ent_id {
        m.color = color
    }
}