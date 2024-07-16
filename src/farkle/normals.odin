package farkle

import "core:fmt"
import glm "core:math/linalg/glsl"
import "../nmath"

@(private="file") D6_NORMALS := [8]glm.vec3{
        {-1,  0, 0},
        { 0, -1, 0},
        { 0,  0, 1},
        { 0,  0, -1},
        { 0,  1, 0},
        { 1,  0, 0},
        0, 0,

}
@(private="file") X :: 0.75 // TODO: re-orient octahedron.obj

NORMALS := [DieType][8]glm.vec3{
    .D4 = {
        {0, 1, 0},
        {-0.471, -0.333, 0.817},
        {-0.471, -0.333, -0.816},
        {0.942, -0.333, 0},
        0,0,0,0,
    },

    .D6 = D6_NORMALS,
    .Even = D6_NORMALS,
    .Odd = D6_NORMALS,

    .D8 = {
        { X, -X,  X},
        {-X,  X,  X},
        {-X, -X,  X},
        { X,  X,  X},
        {-X, -X, -X},
        { X,  X, -X},
        { X, -X, -X},
        {-X,  X, -X},
    },
}

die_facing_up :: proc(type: DieType, orientation: glm.quat) -> int {
    pip: int
    for norm, i in NORMALS[type][:SIDES[type]] {
        dir := glm.quatMulVec3(orientation, norm)
        if glm.dot(dir, nmath.Up) > 0.75 {
            pip = i+1
            break
        }
    }
    if pip == 0 {
        // fmt.eprintln("Unrecognized die pip:", pip, type)
        return 0
    }

    switch type {
        case .D4, .D6, .D8:
            return pip
        case .Even:
            return pip if pip % 2 == 0 else 7 - pip
        case .Odd:
            return pip if pip % 2 != 0 else 7 - pip
    }

    return 0
}


// Rotate die so that given pip is showing.
rotate_show_pip :: proc(die: Die, pip: int) -> glm.quat {
    sides := SIDES[die.type]
    target_pip := pip
         if pip == 0    do target_pip = sides
    else if pip < 0     do target_pip = sides + (pip % sides)
    else if pip > sides do target_pip = pip % sides

    norm := NORMALS[die.type][target_pip - 1]
    return nmath.quat_from_vecs(nmath.Up, norm)
}