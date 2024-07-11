package main

import "core:fmt"
import glm "core:math/linalg/glsl"

import "entity"
import "farkle"
import "nmath"
import "physics"
import "random"
import "tween"

farkle_state := FarkleState.RoundStart

holding_hands, legal_hands: bit_set[farkle.HandType]
holding_score: int

wait_for_animation_time: f32
dice_rolling_time: f32

TIMESCALE :: 2
DICE_ROLLING_TIME_LIMIT :: 2.0 / TIMESCALE // seconds

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
        holding_hands = {}
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
            if nmath.nearly_eq(pos.y, RESTING_Y[d.type], 0.1) do continue

            is_stable = false

            // Push unresting bodies towards center.
            for &b in physics.bodies do if b.entity_id == d.entity_id {
                if !nmath.nearly_eq_vector(b.vel, 0, 0.1) || !nmath.nearly_eq_vector(b.angular_vel, 0, 0.1) {
                    continue // Object is not at rest.
                }
                force := glm.vec3{0, 7, 0} - pos
                b.vel += force if glm.length(force) > 5 else force + 5

                break
            }
        }

        // Add more time to allow moved dice to settle.
        if !is_stable {
            dice_rolling_time = 0.5 * DICE_ROLLING_TIME_LIMIT
            return
        }

        // Serenity now, start scoring.
        hands, legal := farkle.legal_hands(farkle.count_dice_pips(false))
        if !legal { // Bust
            set_floor_color({1, 0, 0, 1})
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

        legal_hands = hands
        set_floor_color({0, 1, 0.4, 1})
        farkle_state = .HoldingDice
        physics_paused = true
        wait_for_animation_time = animate_dice_out()

    case .HoldingDice:
        wait_for_animation_time -= dt
        if wait_for_animation_time > 0 do return
        // Select and deselect dice to hold.
        if .Fire in input do for &d in farkle.round.dice {
            if d.entity_id == hovered_ent_id {
                d.held = !d.held

                holding_hands, holding_score = farkle.score_hand(farkle.count_dice_pips(held_only = true))
            }
        }

        invalid := .Invalid in holding_hands
        // Give some feedback.
        set_floor_color({0.4, 1, 0, 1} if invalid else {0.6, 1, 0, 1})

        if .Stand in input && !invalid {
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

        if .Confirm in input && !invalid {
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
    set_floor_color({0, 0, 1, 1})

    SPAWN_POINT :: glm.vec3{0, 10, 8}
    for &die in farkle.round.dice {
        die.held = false

        ent := entity.get(die.entity_id)
        if die.used {
            ent.pos = -5000 // Hide it somewhere no one will find it.
            continue
        }
        ent.pos = SPAWN_POINT - 4*random.vec3()
        ent.orientation = random.quat()

        for &b in physics.bodies do if b.entity_id == die.entity_id {
            b.vel = {0, 0, -50}
            b.angular_vel = glm.normalize(random.vec3() * 100)
        }
    }
}

animate_dice_out :: proc() -> f32 {
    DUR :: 0.75
    held_count: f32
    for d in farkle.round.dice do if !d.used {
        ent := entity.get(d.entity_id)
        p := ent.pos
        tween.to(d.entity_id, tween.Pos{p + {0, 30, 0}}, DUR, held_count * DUR, .Circular_In)
        tween.to(d.entity_id, tween.Pos{p}, DUR, held_count * DUR + DUR, .Circular_Out)

        held_count += 1
    }

    return DUR + held_count * DUR
}