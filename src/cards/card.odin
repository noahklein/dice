package cards

import glm "core:math/linalg/glsl"

import "../entity"
import "../nmath"
import "../render"
import "../tween"

SCALE :: glm.vec3{1, 0.05, 1.64285}
MAX_DRAWN_CARDS :: 3

deck: [dynamic]CardType = {
    .Inc, .Dec, .Flip, .Inc, .Dec,
}
draw_pile, discard_pile, drawn_cards: [dynamic]Card

DECK_POS    :: glm.vec3{-14, -2, -8}
DISCARD_POS := DECK_POS + 4*3*nmath.Forward

Card :: struct {
    ent_id: entity.ID,
    type: CardType,
}

CardType :: enum {
    None,
    Inc, Dec, Flip,
}

// TODO: make card textures and delete this.
COLORS := [CardType]nmath.Color{
    .None = 0,
    .Inc = nmath.Blue,
    .Dec = nmath.Red,
    .Flip = nmath.Green,
}

init :: proc() {
    for c in draw_pile    do entity.delete(c.ent_id)
    for c in discard_pile do entity.delete(c.ent_id)

    clear(&draw_pile)
    clear(&discard_pile)

    for card_type, i in deck {
        spawn := DECK_POS + f32(i) * SCALE.y * nmath.Up
        rot := glm.quatAxisAngle(nmath.Up, glm.TAU / 4)
        id := entity.new(pos = spawn, scale = SCALE, orientation = rot)

        append(&draw_pile, Card{ id, card_type })
        render.create_mesh(.Cube, id, COLORS[card_type])
    }
}

draw :: proc() -> f32 {
    if len(drawn_cards) + 1 > MAX_DRAWN_CARDS do return 0
    if len(draw_pile) == 0 do return 0

    for card in drawn_cards {
        ent := entity.get(card.ent_id)
        tween.to(card.ent_id, tween.Pos{ent.pos + 3*nmath.Forward}, DUR / 2)
    }

    card := pop(&draw_pile)

    append(&drawn_cards, card)

    DUR :: 0.6
    ent := entity.get(card.ent_id)
    rot := ent.orientation * glm.quatAxisAngle(nmath.Forward, -glm.PI)
    tween.to(card.ent_id, tween.Orientation{rot}, DUR)
    tween.to(card.ent_id, tween.Pos{ent.pos + {0, 2, 3}}, DUR / 2)
    tween.to(card.ent_id, tween.Pos{ent.pos + {0, 0, 3}}, DUR / 2, DUR / 2)

    return DUR
}

discard :: proc(id: entity.ID) -> f32 {
    DUR :: 0.6
    index: int
    for card, i in drawn_cards do if id == card.ent_id {
        index = i
        append(&discard_pile, card)
        ordered_remove(&drawn_cards, i)
    }

    discarded := entity.get(id)
    rot := discarded.orientation * glm.quatAxisAngle(nmath.Forward, -glm.PI)
    tween.to(id, tween.Orientation{rot}, DUR / 2)

    tween.to(id, tween.Pos{discarded.pos + {0, 2, 3}}, DUR / 2)

    y_offset := f32(len(discard_pile) + 1) * SCALE.y
    tween.to(id, tween.Pos{DISCARD_POS + y_offset*nmath.Up}, DUR / 2, DUR / 2)

    for card in drawn_cards {
        ent := entity.get(card.ent_id)
        if ent.pos.z > discarded.pos.z do tween.to(card.ent_id, tween.Pos{ent.pos - {0, 0, 3}}, DUR / 2)
    }

    return DUR
}

use :: proc(id: entity.ID) {
    type: CardType
    for card in drawn_cards do if id == card.ent_id {
        type = card.type
        break
    }
    switch type {
        case .None: return
        case .Dec, .Inc, .Flip:
            select_die(type)
    }
}

select_die :: proc(type: CardType) {
    // TODO: wait for player to selct a die and apply card effect.
}
