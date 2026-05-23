#include <metal_stdlib>
using namespace metal;

struct Vertex2D {
    float2 position;
};

struct BodyInstance {
    float4 positionRadius;
    float4 color;
};

struct Uniforms {
    float4x4 viewProjectionMatrix;
};

struct BodyOut {
    float4 position [[position]];
    float4 color;
};

vertex BodyOut bodyVertexShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    const device Vertex2D *vertices [[buffer(0)]],
    const device BodyInstance *instances [[buffer(1)]],
    constant Uniforms &uniforms [[buffer(2)]]
) {
    BodyInstance instance = instances[instanceID];
    float2 local = vertices[vertexID].position * instance.positionRadius.w;
    float3 world = float3(instance.positionRadius.xy + local, instance.positionRadius.z);

    BodyOut out;
    out.position = uniforms.viewProjectionMatrix * float4(world, 1.0);
    out.color = instance.color;
    return out;
}

fragment float4 bodyFragmentShader(BodyOut in [[stage_in]]) {
    return in.color;
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
