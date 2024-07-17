#type vertex
#version 450

layout (location = 0) in vec2 pos;
layout (location = 1) in vec2 texCoords;

out vec2 vTexCoord;

void main() {
    gl_Position = vec4(pos.x, pos.y, 0, 1.0);
    vTexCoord = texCoords;
}

#type fragment
#version 450

in vec2 vTexCoord;

uniform sampler2D tex;

out vec4 FragColor;

void main() {
    vec4 texColor = texture(tex, vTexCoord);
    FragColor = texColor;
}