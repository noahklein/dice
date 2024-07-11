package farkle_test

import "core:testing"
import "core:log"
import farkle "../"


@(test) test_score :: proc(t: ^testing.T) {
    CASES := [?]struct{ want: int, pcs: map[int]int }{
        {100,   {1 = 1}},
        {1000,  {1 = 3}},
        {150,   {1 = 1, 5 = 1}},
        {600,   {3 = 4}},
        {1200,  {3 = 5}},
        {2400,  {3 = 6}},

        {0,     {1 = 1, 2 = 1, 3 = 1, 4 = 1}},
        {1000,  {1 = 1, 2 = 1, 3 = 1, 4 = 1, 5 = 1}},
        {1150,  {1 = 2, 2 = 1, 3 = 1, 4 = 1, 5 = 2}},
        {2000,  {5 = 1, 6 = 1, 7 = 1, 8 = 1, 9 = 1, 10 = 1}},

        {1600,  {1 = 1, 2 = 1, 3 = 5, 4 = 1, 5 = 1}},
        {2000,  {1 = 1, 2 = 1, 3 = 1, 4 = 1, 5 = 1,
                       7 = 1, 8 = 1, 9 = 1, 10 = 1, 11 = 1}},
        {2000,  {1 = 2, 2 = 2, 3 = 2, 4 = 2, 5 = 2}},

        {2500, {1 = 3, 3 = 3, 6 = 4}},

        {0, {1 = 5, 2 = 1}},
    }
    defer for tc in CASES do delete_map(tc.pcs)

    for tc in CASES {
        hands, score := farkle.score_hand(tc.pcs)
        testing.expect_value(t, score, tc.want)
    }
}

@(test) test_hands :: proc(t: ^testing.T) {
    CASES := [?]struct{ want: bit_set[farkle.HandType], pcs: map[int]int }{
        {{.LooseChange},   {1 = 1}},
        {{.LooseChange},   {1 = 1, 5 = 1}},
        {{.ThreeOfAKind},  {1 = 3}},
        {{.FourOfAKind},   {3 = 4}},
        {{.FiveOfAKind},   {3 = 5}},
        {{.SixOfAKind},    {3 = 6}},

        {{.Invalid},  {1 = 1, 2 = 1, 3 = 1, 4 = 1}},
        {{.Straight}, {1 = 1, 2 = 1, 3 = 1, 4 = 1, 5 = 1}},
        {{.Straight}, {5 = 1, 6 = 1, 7 = 1, 8 = 1, 9 = 1, 10 = 1}},

        {{.Straight},  {1 = 1, 2 = 1, 3 = 1, 4 = 1, 5 = 1,
                        7 = 1, 8 = 1, 9 = 1, 10 = 1, 11 = 1}},
        {{.Straight},  {1 = 2, 2 = 2, 3 = 2, 4 = 2, 5 = 2}},

        {{.Straight, .FourOfAKind},  {1 = 1, 2 = 1, 3 = 5, 4 = 1, 5 = 1}},
        {{.Straight, .LooseChange},  {1 = 2, 2 = 1, 3 = 1, 4 = 1, 5 = 2}},

        {{.ThreeOfAKind, .FourOfAKind}, {1 = 3, 3 = 3, 6 = 4}},

        {{.Invalid}, {1 = 5, 2 = 1}},
    }
    defer for tc in CASES do delete_map(tc.pcs)

    for tc in CASES {
        hands, score := farkle.score_hand(tc.pcs)
        testing.expect_value(t, hands, tc.want)
    }
}

