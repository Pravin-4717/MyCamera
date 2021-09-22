//
//  CameraView.swift
//  MyCamera
//
//  Created by Pravin Palaniappan on 20/09/21.
//

import MetalKit

class CameraView: MTKView {
	var texture: MTLTexture? {
		didSet {
			DispatchQueue.main.async {
				self.setNeedsDisplay()
			}
		}
	}
	let engine: Engine

	var vertexBuffer: MTLBuffer!
	var vertices: [Vertex] = []
	
	override func draw(_ rect: CGRect) {
		guard let drawable = self.currentDrawable,
			  let renderPasDescription = self.currentRenderPassDescriptor,
			  let drawEssentials = engine.getDrawEssentials(
				renderDescription: renderPasDescription) else {
			assertionFailure()
			return
		}
		drawEssentials.renderEncoder?.setFragmentTexture(texture, index: 0)
		drawEssentials.renderEncoder?.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
		drawEssentials.renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: self.vertices.count)
		
		drawEssentials.renderEncoder?.endEncoding()
		drawEssentials.commandBuffer?.present(drawable)
		drawEssentials.commandBuffer?.commit()
	}
	
	required init(coder: NSCoder) {
		guard let device = MTLCreateSystemDefaultDevice() else {
			fatalError()
		}
		self.engine = Engine(device: device)
		super.init(coder: coder)
		self.device = device
		self.setupVertices()
		self.setupView()
	}
}

private extension CameraView {
	func setupView() {
		self.enableSetNeedsDisplay = true
		self.clearColor = Preferences.clearColor
		self.colorPixelFormat = Preferences.mainPixelFormat
		self.depthStencilPixelFormat = Preferences.MainDepthPixelFormat
	}

	func setupVertices() {
		let leftTop = Vertex(
			position: SIMD3<Float>(-1, 1, 0),
			textureCordinate: SIMD2<Float>(0, 1))
		let rightTop = Vertex(
			position: SIMD3<Float>(1, 1, 0),
			textureCordinate: SIMD2<Float>(0, 0))
		let leftBottom = Vertex(
			position: SIMD3<Float>(-1, -1, 0),
			textureCordinate: SIMD2<Float>(1, 1))
		let rightBottom = Vertex(
			position: SIMD3<Float>(1, -1, 0),
			textureCordinate: SIMD2<Float>(1, 0))
		self.vertices = [leftBottom, leftTop, rightTop, leftBottom, rightBottom, rightTop]
		self.vertexBuffer =  engine.device.makeBuffer(
					bytes: vertices,
					length: Vertex.stride(vertices.count),
					options: [])
	}
}

