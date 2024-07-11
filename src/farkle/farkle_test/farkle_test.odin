package farkle_test

import "core:testing"
import "core:log"
import farkle "../"


@(test)
test_score :: proc(t: ^testing.T) {
    CASES := [?]struct{
        pcs: map[int]int,
        want: int,
    }{
        {want = 100,   pcs = {1 = 1}},
        {want = 1000,  pcs = {1 = 3}},
        {want = 150,   pcs = {1 = 1, 5 = 1}},
        {want = 600,   pcs = {3 = 4}},
        {want = 1200,  pcs = {3 = 5}},
        {want = 2400,  pcs = {3 = 6}},

        {want = 0,     pcs = {1 = 1, 2 = 1, 3 = 1, 4 = 1}},
        {want = 1000,  pcs = {1 = 1, 2 = 1, 3 = 1, 4 = 1, 5 = 1}},
        {want = 1150,  pcs = {1 = 2, 2 = 1, 3 = 1, 4 = 1, 5 = 2}},
        {want = 2000,  pcs = {5 = 1, 6 = 1, 7 = 1, 8 = 1, 9 = 1, 10 = 1}},

        {want = 1600,  pcs = {1 = 1, 2 = 1, 3 = 5, 4 = 1, 5 = 1}},
        {want = 2000,  pcs = {1 = 1, 2 = 1, 3 = 1, 4 = 1, 5 = 1,
                              7 = 1, 8 = 1, 9 = 1, 10 = 1, 11 = 1}},
        {want = 2000,  pcs = {1 = 2, 2 = 2, 3 = 2, 4 = 2, 5 = 2}},

        {want = 0, pcs = {1 = 5, 2 = 1}},
    }
    defer for tc in CASES do delete_map(tc.pcs)

    for tc in CASES {
        hands, score := farkle.score_hand(tc.pcs)
        testing.expect_value(t, score, tc.want)
    }
}

@(test)
test_hands :: proc(t: ^testing.T) {
    CASES := [?]struct{
        pcs: map[int]int,
        want: bit_set[farkle.HandType],
    }{
        {want = {.LooseChange},   pcs = {1 = 1}},
        {want = {.ThreeOfAKind},  pcs = {1 = 3}},
        {want = {.LooseChange},   pcs = {1 = 1, 5 = 1}},
        {want = {.FourOfAKind},   pcs = {3 = 4}},
        {want = {.FiveOfAKind},   pcs = {3 = 5}},
        {want = {.SixOfAKind},    pcs = {3 = 6}},

        {want = {.Invalid},  pcs = {1 = 1, 2 = 1, 3 = 1, 4 = 1}},
        {want = {.Straight}, pcs = {1 = 1, 2 = 1, 3 = 1, 4 = 1, 5 = 1}},
        {want = {.Straight}, pcs = {5 = 1, 6 = 1, 7 = 1, 8 = 1, 9 = 1, 10 = 1}},

        {want = {.Straight},  pcs = {1 = 1, 2 = 1, 3 = 1, 4 = 1, 5 = 1,
                              7 = 1, 8 = 1, 9 = 1, 10 = 1, 11 = 1}},
        {want = {.Straight},  pcs = {1 = 2, 2 = 2, 3 = 2, 4 = 2, 5 = 2}},

        {want = {.Straight, .FourOfAKind},  pcs = {1 = 1, 2 = 1, 3 = 5, 4 = 1, 5 = 1}},
        {want = {.Straight, .LooseChange},  pcs = {1 = 2, 2 = 1, 3 = 1, 4 = 1, 5 = 2}},

        {want = {.Invalid}, pcs = {1 = 5, 2 = 1}},
    }
    defer for tc in CASES do delete_map(tc.pcs)

    for tc in CASES {
        hands, score := farkle.score_hand(tc.pcs)
        testing.expect_value(t, hands, tc.want)
    }
}

