package main

import "base:runtime"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:math/rand"
import "core:strings"

import gl "vendor:OpenGL"
import "vendor:glfw"

import "assets"
import "audio"
import "cards"
import "entity"
import "farkle"
import "physics"
import "nmath"
import "nmath/random"
import "render"
import "tween"
import "window"
import "worldmap"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

cursor_hidden: bool
debug_draw: bool
physics_paused: bool

screen: glm.vec2
mouse_coords, prev_mouse_coords, mouse_diff: glm.vec2
mouse_pick: render.MousePicking
hovered_ent_id, floor_ent_id, draggable_die_id: entity.ID

Input :: enum { Fire, Confirm, Cancel, Stand, EditorSelect }
input: bit_set[Input]

game_state: GameState
GameState :: enum u8 { WorldMap, Farkle }

main :: proc() {
    if !glfw.Init() {
        fmt.eprintln("Failed to initialize GLFW")
        return
    }
    defer glfw.Terminate()
    glfw.SetErrorCallback(error_callback)

    window.id = glfw.CreateWindow(1600, 900, "Dice", nil, nil)
    if window.id == nil {
        fmt.eprintln("Failed to create window")
        return
    }
    defer glfw.DestroyWindow(window.id)
    glfw.MakeContextCurrent(window.id)

    glfw.SetKeyCallback(window.id, window.key_callback)
    glfw.SetMouseButtonCallback(window.id, window.mouse_button_callback)
    glfw.SetCursorPosCallback(window.id, mouse_callback)

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

    // Load models for rendering and physics.
    paths := [render.MeshId]string{
        .Cube = "assets/cube.obj",
        .Tetrahedron = "assets/tetrahedron.obj",
        .Octahedron = "assets/octahedron.obj",
        .Cone = "assets/cone.obj",
        .Cylinder = "assets/cylinder.obj",
        .Sphere = "assets/sphere.obj",
        .Quad = "assets/quad.obj",
    }

    for id in render.MeshId {
        path := paths[id]
        obj, err := render.load_obj(path)
        if err != nil {
            fmt.eprintfln("Failed to load mesh %q: %v", path, err)
        }

        render.renderer_init(id, obj)

        // Set up collider shapes using model vertices.
        #partial switch id {
        case .Cube:        physics.collider_vertices(.Box, obj.vertices[:])
        case .Tetrahedron: physics.collider_vertices(.Tetrahedron, obj.vertices[:])
        case .Octahedron:  physics.collider_vertices(.Octahedron, obj.vertices[:])
        }
    }
    defer for id in render.MeshId do render.renderer_deinit(id)


    {
        width, height := glfw.GetWindowSize(window.id)
        screen = {f32(width), f32(height)} // @TODO: Window resizing.
    }

    // Setup quad renderer.
    fullscreen_quad_shader, fullscreen_quad_shader_err := render.shader_load("src/shaders/fullscreen-quad.glsl")
    if fullscreen_quad_shader_err != nil {
        fmt.eprintln("Failed to load fullscreen quad shader:", err)
        return
    }
    render.fullscreen_quad_renderer_init(fullscreen_quad_shader)
    if err := render.text_renderer_init(screen); err != nil {
        fmt.eprintln("failed to load text renderer", err)
        return
    }

    quad_shader, quad_shader_err := render.shader_load("src/shaders/quad.glsl")
    if quad_shader_err != nil {
        fmt.eprintln("Failed to load quad shader:", quad_shader_err)
        return
    }
    render.quad_renderer_init(quad_shader)

    render.shapes_init()
    mouse_pick = render.mouse_picking_init(screen) or_else panic("failed to init mouse picking")

    init_entities()
    init_camera(screen.x / screen.y)
    on_mouse_move(&cam, screen / 2)

    audio.init()
    defer audio.deinit()
    // worldmap.generate()

    window.init()
    for !glfw.WindowShouldClose(window.id) {
        defer {
            glfw.SwapBuffers(window.id)
            render.watch(&shader)
            render.watch(&quad_shader)
            render.watch(&render.text_render.shader)
            input = {}
            window.clear_events()
            free_all(context.temp_allocator)
        }

        glfw.PollEvents()
        dt := window.delta_time()

        if window.pressed_mbtn(.Left)  do input += {.Fire}
        if window.pressed_mbtn(.Right) do input += {.Cancel}

        handle_input(window.id, dt)
        if !physics_paused {
            physics.bodies_update(TIMESCALE * dt)
        }

        hovered_ent_id = entity.ID(render.mouse_picking_read(mouse_pick, mouse_coords))
        if hovered_ent_id < 0 {
			hovered_ent_id = -1
		}

        drag_die :: proc() {
            @(static) dragging_die: bool
            die := entity.get(draggable_die_id)

            if die.pos.y < -10 {
                die.pos = {0, 3, 12}
            }

            DIST :: 10


            if dragging_die && window.mbtn_up(.Left) {
                dragging_die = false
                for &b in physics.bodies do if b.entity_id == draggable_die_id {
                    target := cam.pos + DIST*mouse_to_ray(cam, mouse_coords, screen)
                    b.vel = target - entity.get(draggable_die_id).pos
                    b.vel *= 5
                }
                return
            }

            if hovered_ent_id == draggable_die_id && .Fire in input {
                dragging_die = true
                input -= {.Fire}
            }
            if dragging_die {
                target := cam.pos + DIST*mouse_to_ray(cam, mouse_coords, screen)
                die.pos = glm.lerp(die.pos, target, 0.2)
            }
        }

        @(static) wait_for_card_animation: f32
        if wait_for_card_animation > 0 {
            wait_for_card_animation -= dt
        }

        if wait_for_card_animation <= 0 {
            if .Confirm in input {
                wait_for_card_animation = cards.draw()
            }
        }

        drag_die()
        update_farkle(dt)
        tween.update(dt)
        tween.flux_update(dt)
        camera_update()

        editor_update()

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
        render.setStruct(shader.id, "uLight", render.Light, render.light)

        // Rebind textures to expected slots.
        for tex in assets.textures {
            gl.BindTextureUnit(tex.unit, tex.id)
        }

        render.render_all_meshes()

        // Draw outline around held dice.
        for type in farkle.DieType {
            mesh := render.MeshId.Sphere
            switch type {
                case .D6, .Even, .Odd: mesh = .Cube
                case .D4: mesh = .Tetrahedron
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
                    color = {255, 255, 255, 122},
                    ent_id = d.entity_id,
                })
            }
        }
        render.renderer_flush(.Cube)

        render.quads_begin(screen)
        render.draw_quad({200, 200}, {50, 50})
        render.draw_quad({600, 70}, {50, 50}, color = nmath.Red)
        render.draw_quad({1500, 700}, {50, 50}, glm.TAU / 8, color = {100, 78, 19, 190})
        render.quads_flush()

        when ODIN_DEBUG {
            // state := fmt.enum_value_to_string(farkle_state) or_else "Error"
            render.draw_textf({1500, 880}, "%.2f ms",  window.fps_ms_per_frame)
            render.draw_textf({20, 880}, "Lives: %v", farkle.round.turns_remaining)
            render.draw_textf({20, 860}, "Streak Score: %v", farkle.round.score)
            render.draw_textf({20, 840}, "Total  Score: %v", farkle.round.total_score)
            render.draw_textf({20, 820}, "%v", farkle_state)
            render.draw_textf({20, 800}, "Physics Paused: %v", physics_paused)
            #partial switch farkle_state {
            case .HoldingDice:
                render.draw_textf({20, 700}, "Legal Hands: %v", bit_set_to_string(legal_hands))
                render.draw_textf({20, 680}, "Selected: %v, %v", bit_set_to_string(holding_hands), holding_score)

                score_str := fmt.tprint(holding_score)
                score_width := len(score_str) * 5 * 2
                render.draw_textf(screen / 2 - {f32(score_width), screen.y / 5}, "%v", holding_score, scale = 2)
            case .Rolling:
                render.draw_textf({20, 700}, "Rolling Time: %.0f%%", 100 * dice_rolling_time / DICE_ROLLING_TIME_LIMIT)
            }

            for d in farkle.round.dice do if d.entity_id == hovered_ent_id {
                pip := farkle.die_facing_up(d.type, entity.get(d.entity_id).orientation)
                render.draw_textf({20, 600}, "Hovered die pip: %v, %v", d.type, pip)
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
			render.draw_fullscreen_quad(mouse_pick.tex)
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
    entity.new(pos = 1e6) // Reserve 0th index so that EntityID zero value is useful.

    FLOOR_SIZE   :: 10
    WALL_HEIGHT :: 50
    floor := entity.new(pos = {0, -5, 0}, scale = {FLOOR_SIZE, 5, FLOOR_SIZE})
    render.create_mesh(.Cube, floor, nmath.Blue, .None)
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

    HALF_HEIGHT :: WALL_HEIGHT / 2
    create_wall({0, HALF_HEIGHT, -FLOOR_SIZE}, {FLOOR_SIZE, WALL_HEIGHT / 2, 1})
    create_wall({0, HALF_HEIGHT,  FLOOR_SIZE}, {FLOOR_SIZE, WALL_HEIGHT / 2, 1})
    create_wall({-FLOOR_SIZE, HALF_HEIGHT, 0}, {1, HALF_HEIGHT, FLOOR_SIZE})
    create_wall({ FLOOR_SIZE, HALF_HEIGHT, 0}, {1, HALF_HEIGHT, FLOOR_SIZE})

    floor_ent := entity.get(floor_ent_id)
    desk := entity.new(pos = floor_ent.pos - {0, 2, 0}, scale = floor_ent.scale + {16, 0, 9}) // @TODO: hardcoded for 16:9 ratio
    render.create_mesh(.Cube, desk, nmath.Brown)
    physics.bodies_create(desk, .Box)

    desk_ent := entity.get(desk)
    draggable_orientation := farkle.rotate_show_pip(.D6, 6)
    draggable_die_id = entity.new(desk_ent.pos + desk_ent.scale * {0.6, 1, 0}, orientation = draggable_orientation)
    render.create_mesh(.Cube, draggable_die_id, nmath.White, .D6)
    physics.bodies_create(draggable_die_id, .Box, mass = 1)

    // Create dice.
    for _, i in farkle.round.dice {
        die_type: farkle.DieType = rand.choice_enum(farkle.DieType)
        switch die_type {
        case .D4:
            id := entity.new()
            render.create_mesh(.Tetrahedron, id, nmath.LightGreen, .D4)
            physics.bodies_create(id, .Tetrahedron, mass = 1)
            farkle.round.dice[i] = farkle.Die{ entity_id = id, type = die_type }
        case .D6:
            id := entity.new()
            render.create_mesh(.Cube, id, nmath.LightRed, .D6)
            physics.bodies_create(id, .Box, mass = 1)
            farkle.round.dice[i] = farkle.Die{ entity_id = id, type = die_type }
        case .Even:
            id := entity.new()
            render.create_mesh(.Cube, id, nmath.LightBlue, .Even)
            physics.bodies_create(id, .Box, mass = 1)
            farkle.round.dice[i] = farkle.Die{ entity_id = id, type = die_type }
        case .Odd:
            id := entity.new()
            render.create_mesh(.Cube, id, nmath.LightGreen, .Odd)
            physics.bodies_create(id, .Box, mass = 1)
            farkle.round.dice[i] = farkle.Die{ entity_id = id, type = die_type }
        case .D8:
            id := entity.new()
            render.create_mesh(.Octahedron, id, nmath.White, .D8)
            physics.bodies_create(id, .Octahedron, mass = 1)
            farkle.round.dice[i] = farkle.Die{ entity_id = id, type = die_type }
        }
    }

    cards.init()
}

error_callback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()
	fmt.eprintln(desc, code)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	context = runtime.default_context()
    if action == glfw.PRESS do switch key {
        case glfw.KEY_SPACE:
        case glfw.KEY_T:

        case glfw.KEY_C:

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

    prev_mouse_coords = mouse_coords
    mouse_coords.x = f32(xpos)
    mouse_coords.y = screen.y - f32(ypos)
    mouse_diff = mouse_coords - prev_mouse_coords
}


handle_input :: proc(w: glfw.WindowHandle, dt: f32) {
    forward := int(window.key_down(.W) || window.key_down(.Up)) -
               int(window.key_down(.S) || window.key_down(.Down))
    strafe :=  int(window.key_down(.D) || window.key_down(.Right)) -
               int(window.key_down(.A) || window.key_down(.Left))
    fly    :=  int(window.key_down(.E) || window.key_down(.RCtrl)) -
               int(window.key_down(.Q) || window.key_down(.RShift))

    up := glm.cross(cam.forward, cam.right)
    vel: glm.vec3
    vel += f32(forward) * cam.forward
    vel += f32(strafe)  * cam.right
    vel += f32(fly)     * up

    if vel != 0 {
        cam.pos += glm.normalize(vel) * cam.speed * dt
    }
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

        color: glm.vec4 = 0.5 + 0.5*random.vec3().rgbr
        color.a = 1

        box := entity.new(pos = cam.pos, scale = scale, orientation = random.quat())
        render.create_mesh(.Cube, box, nmath.vec4_to_color(color), tex = .D6)
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

set_floor_color :: proc(color: nmath.Color) {
    m, ok := &render.meshes[floor_ent_id]
    if ok do m.color = color
}

bit_set_to_string :: proc(bs: bit_set[$T]) -> string {
    strs := make([dynamic]string, context.temp_allocator)
    for b in bs do append(&strs, fmt.tprint(b))
    return strings.join(strs[:], " ")
}