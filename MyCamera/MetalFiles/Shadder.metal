//
//  Shadder.metal
//  MyCamera
//
//  Created by Pravin Palaniappan on 20/09/21.
//

#include <metal_stdlib>
using namespace metal;



#include <metal_stdlib>
using namespace metal;

struct VertexIn {
	float3 position[[attribute(0)]];
	float2 textureCordinate[[attribute(1)]];
};

struct RasterData {
	float4 position[[position]];
	float2 textureCordinate;
};

vertex RasterData basic_Vertex_Shader(const VertexIn vIn [[stage_in]]) {
	RasterData rd;
	rd.position = float4(vIn.position, 1);
	rd.textureCordinate = vIn.textureCordinate;
	return rd;
}

fragment half4 basic_Fragment_Shader(const RasterData rd [[stage_in]],
									 texture2d<float> texture [[texture(0)]],
									 sampler textureSampler[[sampler(0)]]) {
	float4 color = texture.sample(textureSampler, rd.textureCordinate);
	if (color.a < 0.1)
	discard_fragment();
	return  half4(color.x, color.y, color.z, color.w);
}
