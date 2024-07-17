#type vertex
#version 450

layout (location = 0) in vec2 pos;
layout (location = 1) in vec2 texCoords;
layout (location = 2) in vec4 color;
layout (location = 3) in mat4 model;

uniform mat4 projection;

out vec2 vTexCoord;
out vec4 vColor;

void main() {
    gl_Position = projection * model * vec4(pos, 0, 1.0);
    vTexCoord = texCoords;
    vColor = color;
}

#type fragment
#version 450

in vec2 vTexCoord;
in vec4 vColor;

uniform sampler2D tex;

out vec4 FragColor;

void main() {
    vec4 texColor = texture(tex, vTexCoord);
    FragColor = vColor * texColor;
}