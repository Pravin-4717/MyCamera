//
//  Filter.metal
//  MyCamera
//
//  Created by Pravin Palaniappan on 20/09/21.
//

#include <metal_stdlib>
using namespace metal;
kernel void invertColor(texture2d<half, access::read>  inputTexture  [[ texture(0) ]],
					   texture2d<half, access::write> outputTexture [[ texture(1) ]],
					   uint2 gid [[thread_position_in_grid]]) {
	if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) {
		return;
	}
	
	half4 inputColor = inputTexture.read(gid);
	half4 outputColor = half4(1 - inputColor.r, 1 - inputColor.g, 1 - inputColor.b, 1.0);
	outputTexture.write(outputColor, gid);
}

kernel void complementaryColor(texture2d<half, access::read>  inputTexture  [[ texture(0) ]],
					   texture2d<half, access::write> outputTexture [[ texture(1) ]],
					   uint2 gid [[thread_position_in_grid]]) {
	if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) {
		return;
	}
	
	half4 inputColor = inputTexture.read(gid);
	half4 outputColor = half4(inputColor.b, inputColor.g, inputColor.r, 1.0);
	outputTexture.write(outputColor, gid);
}

kernel void sepia(texture2d<half, access::read>  inputTexture  [[ texture(0) ]],
					   texture2d<half, access::write> outputTexture [[ texture(1) ]],
					   uint2 gid [[thread_position_in_grid]]) {
	if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) {
		return;
	}
	half4 inputColor = inputTexture.read(gid);
	float outputRed = (inputColor.r * .393) + (inputColor.g * .769) + (inputColor.b * .189);
	float outputGreen = (inputColor.r * .349) + (inputColor.g * .686) + (inputColor.b * .168);
	float outputBlue = (inputColor.r * .272) + (inputColor.g * .534) + (inputColor.b * .131);
	
	half4 outputColor = half4(outputRed, outputGreen, outputBlue, 1.0);
	outputTexture.write(outputColor, gid);
}

kernel void greyScale(texture2d<half, access::read>  inputTexture  [[ texture(0) ]],
					   texture2d<half, access::write> outputTexture [[ texture(1) ]],
					   uint2 gid [[thread_position_in_grid]]) {
	if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) {
		return;
	}
	half4 inputColor = inputTexture.read(gid);
	float outputRed = (inputColor.r * 0.5) + (inputColor.g * 0.5) + (inputColor.b * 0.5);
	float outputGreen = (inputColor.r * 0.5) + (inputColor.g * 0.5) + (inputColor.b * 0.5);
	float outputBlue = (inputColor.r * 0.5) + (inputColor.g * 0.5) + (inputColor.b * 0.5);
	
	half4 outputColor = half4(outputRed, outputGreen, outputBlue, 1.0);;
	outputTexture.write(outputColor, gid);
}

