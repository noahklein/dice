package tween

import "core:math/ease"
import glm "core:math/linalg/glsl"
import "../entity"

tweens: [dynamic]Tween

Tween :: struct {
    ent_id: entity.ID,
    initial, target: Value,

    delay, dur: f32,
    curr_time: f32,

    ease: ease.Ease,
}

Value :: union {Pos, Scale, Orientation}

Pos :: struct{ v: glm.vec3 }
Scale :: struct { v: glm.vec3 }
Orientation :: struct { v: glm.quat }

to :: proc(ent_id: entity.ID, target: Value, dur: f32, delay: f32 = 0, ease: ease.Ease = .Linear) {
    ent := entity.get(ent_id)

    tween := Tween{
        ent_id = ent_id, target = target, ease = ease,
        dur = dur, delay = delay,
    }

    switch _ in target {
        case Pos: tween.initial = Pos{ ent.pos }
        case Scale: tween.initial = Scale{ ent.scale }
        case Orientation: tween.initial = Orientation{ ent.orientation }
    }

    append(&tweens, tween)
}

update :: proc(dt: f32) {
    for i := 0; i < len(tweens); i += 1 {
        tween := &tweens[i]
        defer if tween.curr_time > tween.dur {
            unordered_remove(&tweens, i)
            i -= 1
        }

        if tween.delay > 0 {
            tween.delay -= dt
            continue
        }

        tween.curr_time -= tween.delay
        tween.delay = 0
        tween.curr_time += dt

        t := ease.ease(tween.ease, tween.curr_time / tween.dur)
        ent := entity.get(tween.ent_id)
        switch initial in tween.initial {
        case Pos:
            ent.pos =   glm.lerp(initial.v, tween.target.(Pos).v, t)
        case Scale:
            ent.scale = glm.lerp(initial.v, tween.target.(Scale).v, t)
        case Orientation:
            ent.orientation = glm.slerp(initial.v, tween.target.(Orientation).v, t)
        }
    }
}