#type vertex
#version 450 core


layout (location = 0) in vec3 vPos;
layout (location = 1) in vec3 vNormal;
layout (location = 2) in vec2 vTexCoord;

layout (location = 4) in vec4 vColor;
layout (location = 5) in mat4 vTransform;

uniform mat4 uView;
uniform mat4 uProjection;

out vec2 texCoord;
out vec3 normal;
out vec4 color;

void main() {
    texCoord = vTexCoord;
    normal = vNormal;
    color = vColor;
    gl_Position = uProjection * uView * vTransform * vec4(vPos, 1.0);
}

#type fragment
#version 450 core

in vec2 texCoord;
in vec3 normal;
in vec4 color;

out vec4 finalColor;

void main() {
    finalColor = color;
    // finalColor = vec4(normal, 1);
}