#type vertex
#version 450 core

layout (location = 0) in vec3 vPos;
layout (location = 1) in vec3 vNormal;
layout (location = 2) in vec2 vTexCoord;
layout (location = 3) in int  vTexUnit;

layout (location = 4) in vec4 vColor;
layout (location = 5) in int vEntityId;
layout (location = 6) in mat4 vTransform;

uniform mat4 uView;
uniform mat4 uProjection;

out vec3 pos;
out vec2 texCoord;
flat out int texUnit;
out vec3 normal;
flat out vec4 color;
flat out int entityId;

void main() {
    pos = (vTransform * vec4(vPos, 1)).xyz;
    texCoord = vTexCoord;
    texUnit = vTexUnit;
    normal = mat3(transpose(inverse(vTransform))) * vNormal;
    color = vColor;
    entityId = vEntityId;
    gl_Position = uProjection * uView * vec4(pos, 1);
}

#type fragment
#version 450 core

struct Light {
    vec3 position;
    vec3 direction;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    float constant;
    float linear;
    float quadratic;

    float cutoff;
    float outerCutoff;
};

struct DirLight {
    vec3 direction;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

in vec3 pos;
in vec2 texCoord;
flat in int  texUnit;
in vec3 normal;
flat in vec4 color;
flat in int entityId;

uniform DirLight uDirLight;
uniform Light uLight;
uniform vec3 uCamPos;
uniform sampler2D[10] uTextures;

layout (location = 0) out vec4 outColor;
layout (location = 1) out int outEntityId;

const float shininess = 1; // @TODO: make configurable.

vec3 calcDirLight(DirLight light, vec3 normal, vec3 viewDir) {
    vec3 lightDir = normalize(-light.direction);
    // diffuse shading
    float diff = max(dot(normal, lightDir), 0.0);
    // specular shading
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), shininess);

    // @TODO: multiply by diffuse map and specular maps.
    vec3 ambient  = light.ambient;
    vec3 diffuse  = light.diffuse  * diff;
    vec3 specular = light.specular * spec;
    return (ambient + diffuse + specular);
}

vec3 calcPointLight(Light light, vec3 normal, vec3 viewDir) {
    vec3 lightDir = normalize(light.position - pos);

    // Diffuse
    float diff = max(dot(normal, lightDir), 0);
    vec3 diffuse = light.diffuse * diff;

    // Specular
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0), shininess);
    vec3 specular = light.specular * spec;

     // Spotlight (soft edges)
    float theta = dot(lightDir, normalize(-light.direction));
    float epsilon  = (light.cutoff - light.outerCutoff);
    float intensity = clamp((theta - light.outerCutoff) / epsilon, 0.0, 1.0);
    diffuse  *= intensity;
    specular *= intensity;

    // Attenuation
    float distance    = length(light.position - pos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));

    return attenuation * (light.ambient + diffuse + specular);
}

void main() {
    // const Light light2 = Light(
    //     vec3(2),
    //     vec3(0, -1, 1),

    //     vec3(0.8),
    //     vec3(0.75),
    //     vec3(0.9),

    //     1, 0.09, 0.022,

    //     12.5, 17.5
    // );

    const DirLight dirLight = DirLight(
        vec3(-0.2, -1, -0.3),
        vec3(0.05), vec3(0.4), vec3(0.5)
    );

    vec3 norm = normalize(normal);
    vec3 viewDir = normalize(uCamPos - pos);
    vec3 result = calcDirLight(dirLight, norm, viewDir);
    result += calcPointLight(uLight, norm, viewDir);

    outColor = color * vec4(result, 1);
    outColor *= texture(uTextures[texUnit], texCoord);

    outEntityId = entityId;
}