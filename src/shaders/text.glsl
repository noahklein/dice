#type vertex
#version 450 core

layout (location = 0) in vec2 vertex;
layout (location = 1) in int  v_char;
layout (location = 2) in mat4 model;

uniform mat4 projection;

out vec2 tex_coords;
out flat int character;

void main() {
    gl_Position = projection * model * vec4(vertex, 1, 1);

    tex_coords.x = vertex.x;
    tex_coords.y = 1 - vertex.y;
    character = v_char;
}

#type fragment
#version 450 core

in vec2 tex_coords;
in flat int character;

uniform sampler2DArray tex;
uniform vec3 color;

out vec4 finalColor;

void main() {
    vec3 coords  = vec3(tex_coords.xy, character);
    // coords.x -= 0.45;
    vec4 sampled = vec4(1, 1, 1, texture(tex, coords).r);
    finalColor = vec4(color, 1) * sampled;
    finalColor =  sampled;
    // finalColor = vec4(1);

    // finalColor = vec4(coords, 1);
    // finalColor = vec4(float(character)/256.0, 0, 0, 1);
    // finalColor = vec4(1);
}