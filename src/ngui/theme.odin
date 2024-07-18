package ngui

RED :: Color{255, 0, 0, 255}
MAROON :: Color{128, 0, 0, 140}
BLUE :: Color{0, 0, 255, 255}
DARKBLUE :: Color{0, 0, 128, 255}
SKYBLUE  :: Color{135, 206, 235, 255}
BLACK :: Color{0, 0, 0, 255}
WHITE :: Color(255)

FONT :: 16
TITLE_HEIGHT :: FONT * 2 + 4

title_color :: proc(active: bool) -> Color {
    return RED if active else MAROON
}

button_color :: proc(hover, active, press: bool) -> Color {
    mod: Color = {10, 10, 0, 0} if press else 0
    if active do return DARKBLUE + mod
    if hover  do return BLUE + mod
    return SKYBLUE + mod
}