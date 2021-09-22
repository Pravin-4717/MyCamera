//
//  MetalEngine.swift
//  MyCamera
//
//  Created by Pravin Palaniappan on 21/09/21.
//

import MetalKit

class Engine {
	let device: MTLDevice
	let commandQueue: MTLCommandQueue!
	let library: MTLLibrary?
	var renderPipelineState: MTLRenderPipelineState?
	var sampleState: MTLSamplerState!
	var depthStencilState: MTLDepthStencilState!

	var textureLoader: MTKTextureLoader { return MTKTextureLoader(device: device) }

	init(device: MTLDevice) {
		self.device = device
		self.commandQueue = device.makeCommandQueue()
		self.library = device.makeDefaultLibrary()
		createPipeline()
		prepareDepthStencilState()
		prepareSampleState()
	}

	private func createPipeline() {
		let vertex = library?.makeFunction(name: "basic_Vertex_Shader")
		let fragment = library?.makeFunction(name: "basic_Fragment_Shader")

		let vertexDescriptor = MTLVertexDescriptor()
		//		position
		vertexDescriptor.attributes[0].format = .float3
		vertexDescriptor.attributes[0].offset = 0
		vertexDescriptor.attributes[0].bufferIndex = 0
		//		texture
		vertexDescriptor.attributes[1].format = .float2
		vertexDescriptor.attributes[1].offset = SIMD3<Float>.size
		vertexDescriptor.attributes[1].bufferIndex = 0

		vertexDescriptor.layouts[0].stride = Vertex.stride

		let renderPipelineDescriptor = MTLRenderPipelineDescriptor()

		renderPipelineDescriptor.colorAttachments[0].pixelFormat = Preferences.mainPixelFormat	

		renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
		renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
		renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
		renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

		renderPipelineDescriptor.depthAttachmentPixelFormat = Preferences.MainDepthPixelFormat
		renderPipelineDescriptor.vertexFunction = vertex
		renderPipelineDescriptor.fragmentFunction = fragment
		renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
		do {
			self.renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
		} catch {
			print(error)
		}
	}

	func getDrawEssentials(renderDescription: MTLRenderPassDescriptor) -> DrawEssentials? {
		guard let renderPipelineState = self.renderPipelineState else {
			return nil
		}
		let commandBuffer = self.commandQueue.makeCommandBuffer()
		let renderEndcoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderDescription)
		renderEndcoder?.setDepthStencilState(depthStencilState)

		renderEndcoder?.setRenderPipelineState(renderPipelineState)
		renderEndcoder?.setFragmentSamplerState(sampleState, index: 0)
		return DrawEssentials(renderEncoder: renderEndcoder, commandBuffer: commandBuffer)
	}

	func prepareSampleState() {
		let sampleDiscriptor = MTLSamplerDescriptor()
		sampleDiscriptor.minFilter = .nearest
		sampleDiscriptor.magFilter = .nearest
		sampleDiscriptor.normalizedCoordinates = true
		self.sampleState = device.makeSamplerState(descriptor: sampleDiscriptor)
	}

	func prepareDepthStencilState() {
		let depthDescriptor = MTLDepthStencilDescriptor()
		depthDescriptor.isDepthWriteEnabled = true
		depthDescriptor.depthCompareFunction = .less
		self.depthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)
	}
}

struct DrawEssentials {
	let renderEncoder:  MTLRenderCommandEncoder?
	let commandBuffer: MTLCommandBuffer?
}

