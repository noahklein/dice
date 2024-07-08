package farkle

import glm "core:math/linalg/glsl"
import "../entity"
import "../nmath"

round: Round

Round :: struct {
    turns_remaining: int,
    score: int,
    dice: [6]Die,
}

DieType :: enum { D6 }
Die :: struct {
    entity_id: entity.ID,
    type: DieType,
    held: bool,
}

HandType :: enum {
    Invalid,
    SmallStraight,
    LargeStraight,
    SixOfAKind,
    FiveOfAKind,
    FourOfAKind,
    ThreeOfAKind,
    LooseChange, // Only 1s and 5s scored.
}

// @TODO: Check for hand legality.
round_score_held_dice :: proc() -> (HandType, int) {
    context.allocator = context.temp_allocator

    pip_counts: map[int]int // pip => count
    max_pip: int
    for die in round.dice do if die.held {
        pip_value := die_facing_up(entity.get(die.entity_id).orientation)

        if pip_value not_in pip_counts do pip_counts[pip_value] = 0
        pip_counts[pip_value] += 1

        if pip_value == 0 {
            // @TODO: handle bad dice, apply impulse.
        }

        max_pip = max(max_pip, pip_value)
    }

    // Check for straights.
    max_streak: int
    for start in pip_counts {
        end := start
        for end <= max_pip && (end in pip_counts) {
            end += 1
        }
        max_streak = max(max_streak, end - start)
    }
    switch max_streak {
        case 5: return .SmallStraight, 1000
        case 6: return .LargeStraight, 2000
    }

    // Check for X of a kind.
    kind_pip, max_count: int
    for pip, count in pip_counts do if count > max_count {
        kind_pip, max_count = pip, count
    }

    loose_change: int
    if kind_pip != 1 do loose_change += 100 * (pip_counts[1] or_else 0)
    if kind_pip != 5 do loose_change +=  50 * (pip_counts[5] or_else 0)

    switch max_count {
        case 6: return .SixOfAKind , 3000
        case 5: return .FiveOfAKind, 2000 + loose_change
        case 4: return .FourOfAKind, 1000 + loose_change
        case 3: 
            score := kind_pip * 100 if kind_pip != 1 else 300
            return .ThreeOfAKind, score + loose_change
    }

    if loose_change > 0 do return .LooseChange, loose_change

    return .Invalid, 0
}

die_facing_up :: proc(orientation: glm.quat) -> int {
    UP :: glm.vec3{0, 1, 0}
    T  :: 0.75 // Threshold for cosine similarity.

    dir := nmath.rotate_vector({0, 1, 0}, orientation)
    if glm.dot( dir, UP) > T do return 5
    if glm.dot(-dir, UP) > T do return 2

    dir = nmath.rotate_vector({1, 0, 0}, orientation)
    if glm.dot( dir, UP) > T do return 6
    if glm.dot(-dir, UP) > T do return 1

    dir = nmath.rotate_vector({0, 0, 1}, orientation)
    if glm.dot( dir, UP) > T do return 3
    if glm.dot(-dir, UP) > T do return 4

    return 0 // No valid side.
}