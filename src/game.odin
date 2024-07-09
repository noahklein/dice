package main

import "core:fmt"
import glm "core:math/linalg/glsl"

import "entity"
import "farkle"
import "physics"
import "random"

dice_rolling_timer: f32
rolling_quiet_time: f32
farkle_state := FarkleState.RoundStart

holding_hand: farkle.HandType
holding_score: int

FarkleState :: enum {
    RoundStart,
    ReadyToThrow,
    HoldingDice,
    Rolling,
}

update_farkle :: proc(dt: f32) {
    switch farkle_state {
    case .RoundStart:
        farkle.round.turns_remaining = 3
        farkle_state = .ReadyToThrow
    case .ReadyToThrow:
        physics_paused = false
        if .Fire in input do throw_dice()
    case .Rolling:
        dice_rolling_timer += dt

        // Wait for dice to slow down.
        total_vel: f32
        total_dice: int
        for d in farkle.round.dice do if !d.used {
            for &b in physics.bodies do if b.entity_id == d.entity_id {
                total_vel += glm.dot(b.vel, b.vel)
                total_vel += glm.dot(b.angular_vel, b.angular_vel)
                total_dice += 1

                if dice_rolling_timer > 10 {
                    b.restitution = 0 // Help them slow down.
                }
            }
        }

        // Count period of quietude.
        if total_vel == 0 || total_vel < 0.1 * f32(total_dice) {
            rolling_quiet_time += dt
        } else {
            rolling_quiet_time = 0 // Tranquility broken, start counting again.
        }

        // Serenity now, start scoring.
        if rolling_quiet_time > 2 {
            fmt.println("all quiet")
            rolling_quiet_time = 0

            hand_type, _ := farkle.round_score_dice()
            if hand_type == .Invalid { // Bust
                fmt.println("bust")
                farkle.round.turns_remaining -= 1
                // @TODO: check for loss.
                for &d in farkle.round.dice {
                    d.held = false
                    d.used = false
                }

                farkle_state = .ReadyToThrow
                return
            }

            farkle_state = .HoldingDice
            physics_paused = true
            fmt.println("best hand", farkle.round_score_dice())
        }
    case .HoldingDice:
        if .Fire in input do for &d in farkle.round.dice {
            if d.entity_id == hovered_ent_id {
                d.held = !d.held

                holding_hand, holding_score = farkle.round_score_dice(held_only = true)
                fmt.println("selected", holding_hand, holding_score)
            }
        }

        if .Confirm in input && holding_hand != .Invalid {
            for &d in farkle.round.dice do if d.held {
                d.held = false
                d.used = true
            }

            farkle.round.score += holding_score

            used_count: int
            for d in farkle.round.dice do if d.used { used_count += 1 }

            if used_count == len(farkle.round.dice) {
                // Used all dice, get them all back.
                for &d in farkle.round.dice do d.used = false
            }

            farkle_state = .ReadyToThrow
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
        if die.used {
            ent.pos = -100 // Hide it somewhere no one will find it.
            continue
        }
        ent.pos = SPAWN_POINT - 3*random.vec3()
        ent.orientation = random.quat()

        for &b in physics.bodies do if b.entity_id == die.entity_id {
            b.vel = {0, 0, -30}
            b.angular_vel = random.vec3()
            b.restitution = 0.3
        }
    }
}