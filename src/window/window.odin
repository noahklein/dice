package window

import "core:fmt"
import "vendor:glfw"

id: glfw.WindowHandle

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
        if fps_ms_per_frame < 9.9 do fmt.eprintfln("Slow: %.3f ms/frame", fps_ms_per_frame)
        fps_frames = 0
        fps_prev_time = now
    }

    return f32(min(now - prev_time, 0.05))
}