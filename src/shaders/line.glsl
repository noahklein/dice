#type vertex
#version 450 core

layout (location = 0) in vec3 vPos;
layout (location = 1) in vec3 vColor;

uniform mat4 uProjection;
uniform mat4 uView;

out vec3 color;

void main() {
    gl_Position = uProjection * uView * vec4(vPos, 1.0);
    color = vColor;
}  

#type fragment
#version 450 core

in vec3 color;

out vec4 finalColor;

void main() {
    finalColor = vec4(color, 1);
}