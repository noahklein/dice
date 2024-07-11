package main

import "core:fmt"
import glm "core:math/linalg/glsl"

import "entity"
import "farkle"
import "nmath"
import "physics"
import "random"

farkle_state := FarkleState.RoundStart

holding_hand: farkle.HandType
holding_score: int

dice_rolling_time: f32
DICE_ROLLING_TIME_LIMIT :: 3.5 // seconds

// Y position of a resting die.
RESTING_Y := [farkle.DieType]f32{
    .D6 = 1.00,
    .D4 = 0.562, // Assumes scale = 3
    .D8 = 0.971,
}

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
        holding_hand = nil
        holding_score = 0
        if .Fire in input do throw_dice()
    case .Rolling:
        dice_rolling_time += dt

        is_stable := dice_rolling_time >= DICE_ROLLING_TIME_LIMIT
        if !is_stable do return

        // If physics is taking too long, dice are probably stacked.
        for d in farkle.round.dice do if !d.used {
            // Check if die is in resting position.
            pos := entity.get(d.entity_id).pos
            if nmath.nearly_eq(pos.y, RESTING_Y[d.type], 0.15) do continue

            is_stable = false

            // Push unresting bodies towards center.
            for &b in physics.bodies do if b.entity_id == d.entity_id {
                b.vel += glm.vec3{0, 4, 0} - pos
                break
            }
        }

        // Add more time to allow moved dice to settle.
        if !is_stable {
            dice_rolling_time = 0.6 * DICE_ROLLING_TIME_LIMIT
            return
        }

        // Serenity now, start scoring.
        hand_type, _ := farkle.round_score_dice()
        if hand_type == .Invalid { // Bust
            fmt.println("bust")
            farkle.round.turns_remaining -= 1
            farkle.round.score = 0
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

    case .HoldingDice:
        if .Fire in input do for &d in farkle.round.dice {
            if d.entity_id == hovered_ent_id {
                d.held = !d.held

                holding_hand, holding_score = farkle.round_score_dice(held_only = true)
            }
        }

        if .Stand in input && holding_hand != .Invalid {
            farkle.round.total_score += farkle.round.score + holding_score
            farkle.round.score = 0
            farkle.round.turns_remaining -= 1
            farkle_state = .ReadyToThrow
            for &d in farkle.round.dice {
                d.used = false
                d.held = false
            }
            return
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

    dice_rolling_time = 0
    farkle_state = .Rolling

    SPAWN_POINT :: glm.vec3{0, 10, 8}
    for die in farkle.round.dice {
        ent := entity.get(die.entity_id)
        if die.used {
            ent.pos = -5000 // Hide it somewhere no one will find it.
            continue
        }
        ent.pos = SPAWN_POINT - 4*random.vec3()
        ent.orientation = random.quat()

        for &b in physics.bodies do if b.entity_id == die.entity_id {
            b.vel = {0, 0, -30}
            b.angular_vel = glm.normalize(random.vec3() + 0.01)
        }
    }
}