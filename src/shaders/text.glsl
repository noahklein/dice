#type vertex
#version 450 core

layout (location = 0) in vec4 vertex; // <vec2 pos, vec2 texCoords>

uniform mat4 projection;

out vec2 texCoords;

void main() {
    gl_Position = projection * vec4(vertex.xy, 0, 1.0);
    texCoords = vertex.zw;
}

#type fragment
#version 450 core

in vec2 texCoords;

uniform sampler2D tex;

out vec4 finalColor;

void main() {
    vec4 sampled = vec4(1, 1, 1, texture(tex, texCoords).r);
    finalColor = sampled;
}