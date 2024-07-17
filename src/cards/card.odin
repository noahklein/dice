package cards

import glm "core:math/linalg/glsl"

import "../entity"
import "../nmath"
import "../render"
import "../tween"

SCALE :: glm.vec3{1, 0.05, 1.64285}
PILE_BASE_SCALE := SCALE * {1.2, 0.2, 1.2} // Draw and discard outlines on desk.
MAX_DRAWN_CARDS :: 3

deck: [dynamic]CardType = {
    .Inc, .Dec, .Flip, .Inc, .Dec,
}
draw_pile, discard_pile, drawn_cards: [dynamic]Card

active: Card
actions: int // Number of cards you can play.

DECK_POS    :: glm.vec3{-14, -2, -8}
DISCARD_POS := DECK_POS + 4*3*nmath.Forward
FACE_DOWN := glm.quatAxisAngle(nmath.Up, glm.TAU / 4)
FACE_UP   := FACE_DOWN * glm.quatAxisAngle(nmath.Forward, -glm.PI)

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

    draw_ent    := entity.new(DECK_POS,    orientation = FACE_DOWN, scale = SCALE * 1.2)
    discard_ent := entity.new(DISCARD_POS, orientation = FACE_DOWN, scale = SCALE * 1.2)
    render.create_mesh(.Cube, draw_ent,    nmath.Black)
    render.create_mesh(.Cube, discard_ent, nmath.Black)

    for card_type, i in deck {
        spawn := DECK_POS + f32(i)*SCALE.y*nmath.Up + {0, 2*PILE_BASE_SCALE.y, 0}
        id := entity.new(pos = spawn, scale = SCALE, orientation = FACE_DOWN)

        append(&draw_pile, Card{ id, card_type })
        render.create_mesh(.Cube, id, COLORS[card_type])
    }
}

draw :: proc() -> f32 {
    if len(drawn_cards) + 1 > MAX_DRAWN_CARDS do return 0
    if len(draw_pile) == 0 do return 0

    DUR :: 0.3

    card := pop(&draw_pile)
    append(&drawn_cards, card)

    for c in drawn_cards do if c.ent_id != card.ent_id {
        pos := drawn_card_pos(c.ent_id)
        tween.to(card.ent_id, tween.Pos{pos}, DUR / 2)
    }


    tween.to(card.ent_id, tween.Orientation{FACE_UP}, DUR)

    pos := drawn_card_pos(card.ent_id)
    tween.to(card.ent_id, tween.Pos{pos + {0, 2, 0}}, DUR / 2)
    tween.to(card.ent_id, tween.Pos{pos}, DUR / 2, DUR / 2)

    return DUR
}

discard :: proc(id: entity.ID) -> f32 {
    DUR :: 0.3
    index: int
    for card, i in drawn_cards do if id == card.ent_id {
        index = i
        append(&discard_pile, card)
        ordered_remove(&drawn_cards, i)
    }

    discarded := entity.get(id)
    tween.to(id, tween.Orientation{FACE_DOWN}, DUR / 2)

    tween.to(id, tween.Pos{discarded.pos + {0, 2, 3}}, DUR / 2)

    y_offset := f32(len(discard_pile) + 1) * SCALE.y + 2*PILE_BASE_SCALE.y
    tween.to(id, tween.Pos{DISCARD_POS + y_offset*nmath.Up}, DUR / 2, DUR / 2)

    for card in drawn_cards {
        tween.to(card.ent_id, tween.Pos{drawn_card_pos(card.ent_id)}, DUR / 2)
    }

    return DUR
}

use :: proc(card: Card) {
    if actions <= 0 do return

    active = card

    switch card.type {
        case .None: return
        case .Dec, .Inc, .Flip:
            animate_card_using(card.ent_id)
    }
}

cancel :: proc() {
    animate_card_cancel(active.ent_id)
    active = {}
}

CARD_USING_TRANSLATION :: glm.vec3{0, 1, 0}
CARD_USING_ROTATION := glm.quatAxisAngle(nmath.Forward, glm.TAU / 20)

animate_card_using :: proc(id: entity.ID) {
    DUR :: 0.2
    tween.to(id, tween.Pos{drawn_card_pos(id) + CARD_USING_TRANSLATION}, DUR)
    tween.to(id, tween.Orientation{FACE_UP * CARD_USING_ROTATION}, DUR)
}

animate_card_cancel :: proc(id: entity.ID) {
    DUR :: 0.2
    tween.to(id, tween.Pos{drawn_card_pos(id)}, DUR)
    tween.to(id, tween.Orientation{FACE_UP}, DUR)
}

drawn_card_pos :: proc(id: entity.ID) -> glm.vec3 {
    for c, i in drawn_cards do if c.ent_id == id {
        z := 3 * f32(i + 1)
        return DECK_POS + {0, 0, z}
    }

    return 0
}