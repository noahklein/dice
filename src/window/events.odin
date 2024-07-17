package window

import "base:runtime"
import "core:fmt"
import "vendor:glfw"

keys_events: [Action]map[Key]bool
mbtn_events: [Action]bit_set[MouseButton]

Action :: enum { Press, Release, Repeat }

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
    Space = glfw.KEY_SPACE,
    LeftAlt = glfw.KEY_LEFT_ALT,
    LShift = glfw.KEY_LEFT_SHIFT,
    RShift = glfw.KEY_RIGHT_SHIFT,
    RCtrl = glfw.KEY_RIGHT_CONTROL,
    Esc  = glfw.KEY_ESCAPE,

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

pressed_key   :: #force_inline proc(k: Key) -> bool { return k in keys_events[.Press] }
released_key  :: #force_inline proc(k: Key) -> bool { return k in keys_events[.Release] }
repeated_key  :: #force_inline proc(k: Key) -> bool { return k in keys_events[.Repeat] }

pressed_mbtn  :: #force_inline proc(mb: MouseButton) -> bool { return mb in mbtn_events[.Press]}
released_mbtn :: #force_inline proc(mb: MouseButton) -> bool { return mb in mbtn_events[.Release]}
repeated_mbtn :: #force_inline proc(mb: MouseButton) -> bool { return mb in mbtn_events[.Repeat]}

key_down :: #force_inline proc(k: Key) -> bool {
    return glfw.GetKey(id, i32(k)) == glfw.PRESS
}
key_up :: #force_inline proc(k: Key) -> bool {
    return glfw.GetKey(id, i32(k)) == glfw.RELEASE
}

mbtn_down :: #force_inline proc(mb: MouseButton) -> bool {
    return glfw.GetMouseButton(id, i32(mb)) == glfw.PRESS
}
mbtn_up   :: #force_inline proc(mb: MouseButton) -> bool {
    return glfw.GetMouseButton(id, i32(mb)) == glfw.RELEASE
}

clear_events :: proc() {
    for action in Action {
        clear(&keys_events[action])
        mbtn_events[action] = {}
    }
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = runtime.default_context()
    k := Key(key)
    switch action {
        case glfw.PRESS:   keys_events[.Press][k] = true
        case glfw.RELEASE: keys_events[.Release][k] = true
        case glfw.REPEAT:  keys_events[.Repeat][k] = true
    }
}