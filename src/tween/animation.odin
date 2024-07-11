package tween

import "core:fmt"
import "core:math/ease"
import glm "core:math/linalg/glsl"
import "../entity"

tweens: [dynamic]Tween

Tween :: struct {
    ent_id: entity.ID,
    initial, target: Value,

    delay, dur: f32,
    curr_time: f32,
    started: bool,

    ease: ease.Ease,
}

Value :: union {Pos, Scale, Orientation}

Pos :: struct{ v: glm.vec3 }
Scale :: struct { v: glm.vec3 }
Orientation :: struct { v: glm.quat }

to :: proc(ent_id: entity.ID, target: Value, dur: f32, delay: f32 = 0, ease: ease.Ease = .Linear) {
    tween := Tween{
        ent_id = ent_id, target = target, ease = ease,
        dur = dur, delay = delay,
    }
    append(&tweens, tween)
}

update :: proc(dt: f32) {
    for i := 0; i < len(tweens); i += 1 {
        tween := &tweens[i]
        defer if tween.curr_time >= tween.dur {
            unordered_remove(&tweens, i)
            i -= 1
        }

        if !tween.started {
            if tween.delay > 0 {
                tween.delay -= dt
                continue
            }
            tween.started = true
            tween.curr_time -= tween.delay
            tween.delay = 0

            ent := entity.get(tween.ent_id)
            switch _ in tween.target {
                case Pos: tween.initial = Pos{ent.pos}
                case Scale: tween.initial = Scale{ent.scale}
                case Orientation: tween.initial = Orientation{ent.orientation}
            }
        }

        tween.curr_time += dt
        tween.curr_time = clamp(tween.curr_time, 0, tween.dur)

        t := ease.ease(tween.ease, tween.curr_time / tween.dur)
        ent := entity.get(tween.ent_id)
        switch initial in tween.initial {
        case Pos:
            ent.pos = glm.lerp(initial.v, tween.target.(Pos).v, t)
        case Scale:
            ent.scale = glm.lerp(initial.v, tween.target.(Scale).v, t)
        case Orientation:
            ent.orientation = glm.slerp(initial.v, tween.target.(Orientation).v, t)
        }
    }
}