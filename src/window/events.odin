package window

import "vendor:glfw"

Key :: enum {
    A = glfw.KEY_A,
    B = glfw.KEY_B,
    C = glfw.KEY_C,
    D = glfw.KEY_D,
    E = glfw.KEY_E,
    F = glfw.KEY_F,
    G = glfw.KEY_G,
    H = glfw.KEY_H,
    I = glfw.KEY_I,
    J = glfw.KEY_J,
    K = glfw.KEY_K,
    L = glfw.KEY_L,
    M = glfw.KEY_M,
    N = glfw.KEY_N,
    O = glfw.KEY_O,
    P = glfw.KEY_P,
    Q = glfw.KEY_Q,
    R = glfw.KEY_R,
    S = glfw.KEY_S,
    T = glfw.KEY_T,
    U = glfw.KEY_U,
    V = glfw.KEY_V,
    W = glfw.KEY_W,
    X = glfw.KEY_X,
    Y = glfw.KEY_Y,
    Z = glfw.KEY_Z,
    LeftAlt = glfw.KEY_LEFT_ALT,
    RShift = glfw.KEY_RIGHT_SHIFT,
    RCtrl = glfw.KEY_RIGHT_CONTROL,

    Up = glfw.KEY_UP,
    Down = glfw.KEY_DOWN,
    Left = glfw.KEY_LEFT,
    Right = glfw.KEY_RIGHT,
}

MouseButton :: enum {
    Left = glfw.MOUSE_BUTTON_LEFT,
    Middle = glfw.MOUSE_BUTTON_MIDDLE,
    Right = glfw.MOUSE_BUTTON_RIGHT,
}

key_down :: #force_inline proc(k: Key) -> bool {
    return glfw.GetKey(id, i32(k)) == glfw.PRESS
}

key_up :: #force_inline proc(k: Key) -> bool {
    return glfw.GetKey(id, i32(k)) == glfw.RELEASE
}

mousebtn_down :: #force_inline proc(mb: MouseButton) -> bool {
    return glfw.GetMouseButton(id, i32(mb)) == glfw.PRESS
}

mousebtn_up :: #force_inline proc(mb: MouseButton) -> bool {
    return glfw.GetMouseButton(id, i32(mb)) == glfw.RELEASE
}