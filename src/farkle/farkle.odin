package farkle

import "core:fmt"
import glm "core:math/linalg/glsl"
import "../entity"
import "../nmath"

round: Round

Round :: struct {
    turns_remaining: int,
    score, total_score: int,
    dice: [15]Die,
}

DieType :: enum { D4, D6, Even, Odd, D8 }
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
    Straight,
    TooManyOfAKind,
}

hand_type_of_a_kind :: #force_inline proc(count: int) -> HandType {
    switch count {
        case 3: return .ThreeOfAKind
        case 4: return .FourOfAKind
        case 5: return .FiveOfAKind
        case 6: return .SixOfAKind
        case 7..<20: return .TooManyOfAKind
    }

    return .Invalid
}

count_dice_pips :: proc(held_only: bool) -> map[int]int {
    pip_counts := make(map[int]int, 32, context.temp_allocator)
    for die in round.dice {
        if die.used || (held_only && !die.held) do continue
        pip := die_facing_up(die.type, entity.get(die.entity_id).orientation)
        if pip == 0 do fmt.eprintfln("Bad die in is_legal_hand()")

        pip_counts[pip] = pip_counts[pip] + 1
    }

    return pip_counts
}

legal_hands :: proc(pip_counts: map[int]int) -> (bit_set[HandType], bool) {
    max_pip: int
    for pip in pip_counts do  max_pip = max(max_pip, pip)

    hands: bit_set[HandType]

    // Loose change
    if 1 in pip_counts || 5 in pip_counts do hands += {.LooseChange}

    // X of a kind
    for _, count in pip_counts do if count >= 3 {
        hands += {hand_type_of_a_kind(count)}
    }

    // Straights
    for start in pip_counts {
        end := start
        for end <= max_pip && (end in pip_counts) {
            end += 1
        }

        if end - start >= 5 do hands += {.Straight}
    }

    return hands, hands != {}
}

// All held dice must contribute to the score or the hand is illegal.
score_hand :: proc(pip_counts: map[int]int) -> (hands: bit_set[HandType], score: int) {
    pip_counts := pip_counts // Shadow parameter for mutation.

    longest_straight :: proc(pip_counts: map[int]int) -> (int, int) {
        max_pip: int
        for pip in pip_counts do  max_pip = max(max_pip, pip)

        best_start, max_streak: int
        for start in pip_counts {
            end := start
            for end <= max_pip && (end in pip_counts) {
                end += 1
            }
            if end - start > max_streak {
                max_streak = end - start
                best_start = start
            }
        }


        return best_start, max_streak
    }

    // Loop until we find all straights. Any participating dice get deducted from pip_counts.
    for {
        start, length := longest_straight(pip_counts)
        if length < 5 do break

        score += 1000 * (length - 4)
        hands += {.Straight}

        // Remove straight participants from pip_counts.
        for pip in start..<start+length {
            pip_counts[pip] = pip_counts[pip] - 1
            if pip_counts[pip] <= 0 do delete_key(&pip_counts, pip)
        }
    }

    // All dice must contribute to the score for the hand to be legal.
    for len(pip_counts) > 0 {
        most_frequent_pip, max_count: int
        for pip, count in pip_counts do if count > max_count {
            max_count = count
            most_frequent_pip = pip
        }
        defer delete_key(&pip_counts, most_frequent_pip)

        // Check loose change and legality.
        if max_count < 3 {
            switch most_frequent_pip {
                case 1:
                    score += 100 * max_count
                    hands += {.LooseChange}
                case 5:
                    score +=  50 * max_count
                    hands += {.LooseChange}
                case: return {.Invalid}, 0 // Invalid hand.
            }

            continue
        }

        // X of a Kind
        kind_base := 100 * (most_frequent_pip if most_frequent_pip != 1 else 10)
        score += kind_base * (1 << u32(max_count - 3))

        hands += {hand_type_of_a_kind(max_count)}
    }

    return
}

best_hand :: proc() -> (string, string) {
    return "TO", "DO"
}

die_facing_up :: proc(type: DieType, orientation: glm.quat) -> int {
    switch type {
        case .D4: return die_facing_up_d4(orientation)
        case .D6: return die_facing_up_d6(orientation)
        case .D8: return die_facing_up_d8(orientation)
        case .Even:
            p := die_facing_up_d6(orientation)
            return p if p % 2 == 0 else 7 - p
        case .Odd:
            p := die_facing_up_d6(orientation)
            return p if p % 2 != 0 else 7 - p
    }

    fmt.eprintln("Unrecognized die type:", type)
    return 0
}

die_facing_up_d4 :: proc(orientation: glm.quat) -> int {
    UP :: glm.vec3{0, 1, 0}
    T  :: 0.75 // Threshold for cosine similarity.

    dir := nmath.rotate_vector({0, 1, 0}, orientation)
    if glm.dot(dir, UP) > T do return 1

    dir = nmath.rotate_vector({-0.471, -0.333, 0.817}, orientation)
    if glm.dot(dir, UP) > T do return 2

    dir = nmath.rotate_vector({-0.471, -0.333, -0.816}, orientation)
    if glm.dot(dir, UP) > T do return 3

    dir = nmath.rotate_vector({0.942, -0.333, 0}, orientation)
    if glm.dot(dir, UP) > T do return 4

    return 0
}

die_facing_up_d6 :: proc(orientation: glm.quat) -> int {
    UP :: glm.vec3{0, 1, 0}
    T  :: 0.75 // Threshold for cosine similarity.

    FACE_NORMALS :: [?]glm.vec3{
        {-1,  0, 0},
        { 0, -1, 0},
        { 0,  0, 1},
    }

    for n, pip in FACE_NORMALS {
        dir := nmath.rotate_vector(n, orientation)
        if glm.dot( dir, UP) > T do return pip + 1
        if glm.dot(-dir, UP) > T do return 7 - (pip+1)
    }

    return 0 // No valid side.
}

die_facing_up_d8 :: proc(orientation: glm.quat) -> int {
    UP :: glm.vec3{0, 1, 0}
    T :: 0.75

    X :: glm.SQRT_THREE / 3
    FACE_NORMALS :: [?]glm.vec3{
        { X, -X,  X},
        {-X,  X,  X},
        {-X, -X,  X},
        { X,  X,  X},
    }

    for n, pip in FACE_NORMALS {
        dir := nmath.rotate_vector(n, orientation)
        if glm.dot( dir, UP) > T do return pip + 1
        if glm.dot(-dir, UP) > T do return 9 - (pip+1)
    }

    return 0
}