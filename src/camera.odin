package main

import glm "core:math/linalg/glsl"

CAM_SPEED :: 15.0

init_mouse : bool

Camera :: struct {
    fov, aspect, near, far: f32,
    pos, target, forward, right: glm.vec3,

    pitch, yaw: f32, // horizontal, vertical
    sensitivity, mouse_pos: glm.vec2,
    speed: f32,
}

cam : Camera

init_camera :: proc(aspect: f32) {
    cam = {
        fov = 70,
        aspect = aspect,
        near = 0.1, far = 1000,

        pos = {0, 2, 30},
        forward = {0, 0, 1}, right = {1, 0, 0},
        yaw = -90, pitch = 0,
        sensitivity = {0.05, 0.05},
        speed = CAM_SPEED,
    }
}

projection :: proc(c: Camera) -> glm.mat4 {
    return glm.mat4Perspective(c.fov, c.aspect, c.near, c.far)
}

look_at :: proc(c: Camera) -> glm.mat4 {
    up := glm.normalize(glm.cross(c.right, c.forward))
    return glm.mat4LookAt(c.pos, c.pos + c.forward, up)
}

on_mouse_move :: proc(c: ^Camera, mouse: glm.vec2) {
    if !init_mouse {
        c.mouse_pos = mouse
        init_mouse = true
    }

    diff := c.sensitivity * glm.vec2{
        mouse.x - c.mouse_pos.x,
        c.mouse_pos.y - mouse.y,
    }
    c.mouse_pos = mouse

    c.yaw += diff.x
    c.pitch = clamp(c.pitch + diff.y, -89, 89)

    yaw, pitch := glm.radians(c.yaw), glm.radians(c.pitch)
    c.forward = glm.normalize_vec3({
        glm.cos(yaw) * glm.cos(pitch),
        glm.sin(pitch),
        glm.sin(yaw) * glm.cos(pitch),
    })
    c.right = glm.normalize(glm.cross(c.forward, glm.vec3{0, 1, 0}))
}

mouse_to_ray :: proc(c: Camera, mouse: glm.vec2, screen_size: glm.vec2) -> glm.vec3 {
    // Put in range -1..=1
    norm_device_coords := glm.vec4{
        (2 * mouse.x) / screen_size.x - 1,
        1 - (2 * mouse.y) / screen_size.y,
        -1, // Point forwards
        1,
    }

    proj, view := projection(c), look_at(c)

    ray_eye := glm.inverse(proj) * norm_device_coords
    ray_eye.z = -1
    ray_eye.w = 0

    ray_world := glm.inverse(view) * ray_eye
    return glm.normalize_vec3(ray_world.xyz)
}