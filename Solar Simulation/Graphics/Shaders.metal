#include <metal_stdlib>
using namespace metal;

struct SphereVertex {
    float3 position;
    float3 normal;
};

struct BodyInstance {
    float4 positionRadius;
    float4 color;
    float4 material;
};

struct Uniforms {
    float4x4 viewProjectionMatrix;
    float4 lightPosition;
    float4 cameraPosition;
};

struct BodyOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float4 color;
    float emission;
};

vertex BodyOut bodyVertexShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    const device SphereVertex *vertices [[buffer(0)]],
    const device BodyInstance *instances [[buffer(1)]],
    constant Uniforms &uniforms [[buffer(2)]]
) {
    BodyInstance instance = instances[instanceID];
    SphereVertex sphereVertex = vertices[vertexID];
    float radius = instance.positionRadius.w;
    float3 world = instance.positionRadius.xyz + sphereVertex.position * radius;

    BodyOut out;
    out.position = uniforms.viewProjectionMatrix * float4(world, 1.0);
    out.worldPosition = world;
    out.normal = normalize(sphereVertex.normal);
    out.color = instance.color;
    out.emission = instance.material.x;
    return out;
}

fragment float4 bodyFragmentShader(
    BodyOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    if (in.emission > 0.5) {
        return float4(min(in.color.rgb * 1.35, float3(1.0)), in.color.a);
    }

    float3 normal = normalize(in.normal);
    float3 toLight = normalize(uniforms.lightPosition.xyz - in.worldPosition);
    float3 toCamera = normalize(uniforms.cameraPosition.xyz - in.worldPosition);
    float3 halfVector = normalize(toLight + toCamera);

    float diffuse = max(dot(normal, toLight), 0.0);
    float specular = pow(max(dot(normal, halfVector), 0.0), 36.0) * 0.28;
    float rim = pow(1.0 - max(dot(normal, toCamera), 0.0), 2.0) * 0.16;
    float3 litColor = in.color.rgb * (0.20 + diffuse * 0.86 + rim) + float3(specular);

    return float4(litColor, in.color.a);
}

struct PathVertex {
    float4 position;
    float4 color;
};

struct PathOut {
    float4 position [[position]];
    float4 color;
};

vertex PathOut pathVertexShader(
    uint vertexID [[vertex_id]],
    const device PathVertex *vertices [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    PathVertex pathVertex = vertices[vertexID];

    PathOut out;
    out.position = uniforms.viewProjectionMatrix * float4(pathVertex.position.xyz, 1.0);
    out.color = pathVertex.color;
    return out;
}

fragment float4 pathFragmentShader(PathOut in [[stage_in]]) {
    return in.color;
}

struct CometBillboardInstance {
    float4 positionRadius;
    float4 color;
};

struct CometBillboardOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
};

vertex CometBillboardOut cometBillboardVertexShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    const device CometBillboardInstance *instances [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    constexpr float2 corners[6] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0),
        float2(-1.0,  1.0)
    };

    CometBillboardInstance instance = instances[instanceID];
    float3 center = instance.positionRadius.xyz;
    float radius = instance.positionRadius.w;
    float3 toCamera = normalize(uniforms.cameraPosition.xyz - center);
    float3 worldUp = float3(0.0, 0.0, 1.0);
    float3 right = cross(worldUp, toCamera);

    if (length(right) < 0.001) {
        right = float3(1.0, 0.0, 0.0);
    } else {
        right = normalize(right);
    }

    float3 up = normalize(cross(toCamera, right));
    float2 corner = corners[vertexID];
    float3 world = center + (right * corner.x + up * corner.y) * radius;

    CometBillboardOut out;
    out.position = uniforms.viewProjectionMatrix * float4(world, 1.0);
    out.uv = corner;
    out.color = instance.color;
    return out;
}

fragment float4 cometBillboardFragmentShader(CometBillboardOut in [[stage_in]]) {
    float distanceFromCenter = length(in.uv);
    float alpha = smoothstep(1.0, 0.0, distanceFromCenter) * in.color.a;
    return float4(in.color.rgb, alpha);
}
