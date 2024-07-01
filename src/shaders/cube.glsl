#type vertex
#version 450 core


layout (location = 0) in vec3 vPos;
layout (location = 1) in vec3 vNormal;
layout (location = 2) in vec2 vTexCoord;

layout (location = 4) in mat4 vTransform;

uniform mat4 uView;
uniform mat4 uProjection;

out vec2 texCoord;
out vec3 normal;

void main() {
    texCoord = vTexCoord;
    normal = vNormal;
    gl_Position = uProjection * uView * vTransform * vec4(vPos, 1.0);
}

#type fragment
#version 450 core

in vec2 texCoord;
in vec3 normal;

out vec4 color;

void main() {
    color = vec4(1, 1, 1, 1);
}