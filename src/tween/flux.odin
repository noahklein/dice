package tween

import "core:math/ease"
import glm "core:math/linalg/glsl"
import "core:time"

flux_map := ease.flux_init(f32)

flux_to :: proc(val: ^f32, goal: f32, easing: ease.Ease = .Linear, dur: time.Duration = time.Second, delay: f64 = 0) {
    _ = ease.flux_to(&flux_map, val, goal, easing, dur, delay)
}

flux_vec3_to :: proc(val: ^glm.vec3, goal: glm.vec3, easing: ease.Ease = .Linear, dur: time.Duration = time.Second, delay: f64 = 0) {
    for &v, i in val {
        flux_to(&v, goal[i], easing, dur, delay)
    }
}

flux_update :: proc(dt: f32) {
    ease.flux_update(&flux_map, f64(dt))
}