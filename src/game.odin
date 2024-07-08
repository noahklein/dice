package main

import "core:fmt"
import glm "core:math/linalg/glsl"

import "entity"
import "farkle"
import "physics"
import "random"

dice_rolling_timer: f32
rolling_quiet_frames: int
farkle_state := FarkleState.ReadyToThrow

FarkleState :: enum {
    ReadyToThrow,
    HoldingDice,
    Rolling,
}

Input :: enum { Fire }

update_farkle :: proc(dt: f32) {

    switch farkle_state {
    case .HoldingDice:
        fmt.println("holding")
        physics_paused = true
    case .ReadyToThrow:
        physics_paused = false
    case .Rolling:
        dice_rolling_timer += dt

        // Wait for dice to slow down.
        total_vel: f32
        total_dice: int
        for d in farkle.round.dice do if !d.held {
            for &b in physics.bodies do if b.entity_id == d.entity_id {
                total_vel += glm.dot(b.vel, b.vel)
                total_vel += glm.dot(b.angular_vel, b.angular_vel)
                total_dice += 1

                if dice_rolling_timer > 10 {
                    b.restitution = 0 // Help them slow down.
                }
            }
        }

        if total_vel == 0 || total_vel < 0.1e-22 * f32(total_dice) {
            rolling_quiet_frames += 1
        } else {
            rolling_quiet_frames = 0
        }
        if rolling_quiet_frames > 400 {
            rolling_quiet_frames = 0
            farkle_state = .HoldingDice
        }
    }
}

throw_dice :: proc() {
    if farkle_state != .ReadyToThrow do return

    dice_rolling_timer = 0
    farkle_state = .Rolling

    SPAWN_POINT :: glm.vec3{0, 10, 10}
    for die in farkle.round.dice {
        ent := entity.get(die.entity_id)
        ent.pos = SPAWN_POINT - 3*random.vec3()
        ent.orientation = random.quat()

        for &b in physics.bodies do if b.entity_id == die.entity_id {
            b.vel = {0, 0, -30}
            b.angular_vel = random.vec3()
            b.restitution = 0.3
        }
    }
}