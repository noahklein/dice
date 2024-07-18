package window

import "core:fmt"
import "vendor:glfw"
import glm "core:math/linalg/glsl"

id: glfw.WindowHandle
screen: glm.vec2

prev_time, fps_prev_time: f64
fps_frames, fps_ms_per_frame: f64

init :: proc() {
    prev_time = glfw.GetTime()
    fps_prev_time = prev_time
}

delta_time :: proc() -> f32 {
    now := glfw.GetTime()
    defer prev_time = now

    fps_frames += 1
    if now - fps_prev_time >= 1 {
        fps_ms_per_frame = 1000.0 / fps_frames
        if fps_ms_per_frame > 10 do fmt.eprintfln("Slow: %.3f ms/frame", fps_ms_per_frame)
        fps_frames = 0
        fps_prev_time = now
    }

    return f32(min(now - prev_time, 0.05))
}