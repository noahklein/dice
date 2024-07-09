package farkle

import "core:fmt"
import glm "core:math/linalg/glsl"
import "../entity"
import "../nmath"

round: Round

Round :: struct {
    turns_remaining: int,
    score, total_score: int,
    dice: [6]Die,
}

DieType :: enum { D6 }
Die :: struct {
    entity_id: entity.ID,
    type: DieType,
    held: bool, // Die chosen for this hand.
    used: bool, // Die already used for a previous hand.
}

HandType :: enum {
    Invalid,
    LooseChange, // Only 1s and 5s scored.
    ThreeOfAKind,
    FourOfAKind,
    FiveOfAKind,
    SixOfAKind,
    SmallStraight,
    LargeStraight,
}

// Checks all unused dice for bust when held_only = false. When held_only = true,
// all held dice must contribute to the score or the hand is illegal.
round_score_dice :: proc(held_only := false) -> (HandType, int) {
    context.allocator = context.temp_allocator

    pip_counts: map[int]int // pip => count
    max_pip: int
    for die in round.dice do if !die.used && (!held_only || die.held) {
        pip_value := die_facing_up(entity.get(die.entity_id).orientation)
        pip_counts[pip_value] = pip_counts[pip_value] + 1
        max_pip = max(max_pip, pip_value)

        if pip_value == 0 { // @TODO: handle bad dice, apply impulse.
            fmt.eprintfln("Bad die in round_score_dice(held_only=%v)", held_only)
        }
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

    if held_only && max_streak >= 5 {
        // No duplicates allowed in straight.
        for pip, count in pip_counts {
            if pip == 1 || pip == 5 do continue
            if count > 2 do return .Invalid, 0
        }
    }

    // Straight uses special loose change check. This assumes dice are in 1-6 range, thus
    // 1s and 5s always contribute to the straight.
    loose_change: int
    if pip_counts[1] > 1 do loose_change += 100 * (pip_counts[1] - 1)
    if pip_counts[5] > 1 do loose_change += 50 * (pip_counts[1] - 1)

    switch max_streak {
        case 5: return .SmallStraight, 1000 + loose_change
        case 6: return .LargeStraight, 2000 + loose_change
    }

    // Check for X of a kind.
    kind_pip, max_count: int
    for pip, count in pip_counts do if count > max_count {
        kind_pip, max_count = pip, count
    }

    // Non-straight loose change.
    loose_change = 0
    if kind_pip != 1 || max_count < 3 do loose_change += 100 * (pip_counts[1] or_else 0)
    if kind_pip != 5 || max_count < 3 do loose_change +=  50 * (pip_counts[5] or_else 0)

    if held_only && max_count >= 3 {
        for pip, count in pip_counts {
            if pip == kind_pip || pip == 1 || pip == 5 do continue
            if count != 0 do return .Invalid, 0
        }
    }

    switch max_count {
        case 6: return .SixOfAKind , 3000 + loose_change
        case 5: return .FiveOfAKind, 2000 + loose_change
        case 4: return .FourOfAKind, 1000 + loose_change
        case 3: return .ThreeOfAKind, 100*kind_pip + loose_change
    }

    if loose_change > 0 {
        if held_only do for pip in pip_counts {
            if pip == 1 || pip == 5 do continue
            return .Invalid, 0
        }
        return .LooseChange, loose_change
    }

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