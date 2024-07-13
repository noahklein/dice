package worldmap

import "core:fmt"
import "core:math/rand"
import glm "core:math/linalg/glsl"
import "../entity"
import "../render"

FLOORS :: 7

floors: [FLOORS][2]NodeType

NodeType :: enum {
    Boss,
    Combat,
    Shop,
    DiceTrader,
    Treasure,
}

NodeTypeChar := [NodeType]rune{
    .Boss = 'B',
    .Combat = 'C',
    .Shop = '$',
    .Treasure = 'T',
    .DiceTrader = 'D',
}

generate :: proc() {
    Y :: 2
    floors[0][0] = .Boss
    floors[0][1] = .Boss
    boss_pos := glm.vec3{0, Y, -8}
    boss_ent := entity.new(boss_pos)
    render.create_mesh(.Octahedron, boss_ent)

    for &floor, z in floors[1:] {
        posA := glm.vec3{-1, Y, -6 + f32(2 * z)}
        floor[0] = rand_node_type()
        node_ent := entity.new(posA, scale = 0.5)
        render.create_mesh(.Cube, node_ent)

        posB := glm.vec3{1, Y, -6 + f32(2*z)}
        floor[1] = rand_node_type()
        node_ent = entity.new(posB, scale = 0.5)
        render.create_mesh(.Cube, node_ent)
    }
}

rand_node_type :: proc() -> NodeType {
    nt := rand.choice_enum(NodeType)
    return nt if nt != .Boss else rand_node_type()
}

print_floors :: proc() {
    LINE_WIDTH :: 40

    fmt.println("====================")
    for floor in floors {
        padding := LINE_WIDTH / (1 + len(floor))
        padding /= 2

        for n in floor {
            for _ in 0..<padding - 1 {
                fmt.print(" ")
            }
            fmt.print(NodeTypeChar[n])
        }

        fmt.println()
    }
}