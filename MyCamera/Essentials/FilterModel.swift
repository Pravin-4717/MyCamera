//
//  FilterModel.swift
//  MyCamera
//
//  Created by Pravin Palaniappan on 20/09/21.
//

import AVFoundation
import CoreVideo
import Metal

enum Filter: String {
	case none = ""
	case invertColor = "invertColor"
	case complementaryColor = "complementaryColor"
	case sepia = "sepia"
	case greyScale = "greyScale"
	
	init(tag: Int) {
		switch tag {
		case 1:
			self = .sepia
		case 2:
			self = .greyScale
		case 3:
			self = .invertColor
		case 4:
			self = .complementaryColor
		default:
			self = .none
		}
	}
}

class FilterModel {
	var filter = Filter.none {
		willSet {
			self.isInitialised = false
		}
	}
	
	private let device = MTLCreateSystemDefaultDevice()
	private var pipeline: MTLComputePipelineState!
	
	private var metalTextureCache: CVMetalTextureCache?
	private var bufferPool: CVPixelBufferPool!
	private var isInitialised = false

	init() {
		self.initialize()
	}
	
	func render(
		buffer: CVPixelBuffer,
		newPixelBuffer: inout CVPixelBuffer?,
		formatDescription: CMFormatDescription) throws -> MTLTexture {
		if !isInitialised {
			self.initialize()
		}
		return try self.renderFilteredBuffer(buffer, &newPixelBuffer, formatDescription)
	}
}

private extension FilterModel {
	func initialize() {
		do {
			try self.setup()
			self.isInitialised = true
		} catch {
			if let errorString = (error as? FilterError)?.description {
				assertionFailure(errorString)
			} else {
				assertionFailure(error.localizedDescription)
			}
		}
	}
	func setup() throws {
		guard self.filter != .none else {
			return
		}
		guard let library = device?.makeDefaultLibrary() else {
			throw FilterError.library
		}
		guard let kernelFunction = library.makeFunction(name: filter.rawValue) else {
			throw FilterError.funtion
		}
		guard let pipeline = try device?.makeComputePipelineState(
				function: kernelFunction) else {
			throw FilterError.pipline
		}
		self.pipeline = pipeline
	}
	
	func renderFilteredBuffer(
		_ buffer: CVPixelBuffer,
		_ newPixelBuffer: inout CVPixelBuffer?,
		_ formatDescription: CMFormatDescription) throws -> MTLTexture {
		if self.bufferPool == nil {
			self.bufferPool = try allocateOutputBufferPool(formatDescription, 3)
		}

		CVPixelBufferPoolCreatePixelBuffer(
			kCFAllocatorDefault,
			bufferPool,
			&newPixelBuffer)
		
		guard let pixelBuffer = newPixelBuffer else {
			assertionFailure()
			throw FilterError.pixelBufferAllocation
		}
		let inputTexture = try createMetalTexure(buffer, .bgra8Unorm)
	
		guard filter != .none else {
			newPixelBuffer = buffer
			return inputTexture
		}
	
		let  outputTexture = try createMetalTexure(pixelBuffer, .bgra8Unorm)
		
		guard let cmdQueue = self.device?.makeCommandQueue(),
			  let cmdBuffer = cmdQueue.makeCommandBuffer(),
			  let encoder = cmdBuffer.makeComputeCommandEncoder() else {
			throw FilterError.commadeQueue
		}
		
		encoder.setComputePipelineState(pipeline)
		encoder.setTexture(inputTexture, index: 0)
		encoder.setTexture(outputTexture, index: 1)
		
		let width = pipeline.threadExecutionWidth
		let height = pipeline.maxTotalThreadsPerThreadgroup / width
		let threadsPerThreadgroup = MTLSizeMake(width, height, 1)
		let threadgroupsPerGrid = MTLSize(width: (inputTexture.width + width - 1) / width,
										  height: (inputTexture.height + height - 1) / height,
										  depth: 1)
		encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
		
		encoder.endEncoding()
		cmdBuffer.commit()
		return outputTexture
	}
	
	func createMetalTexure(
		_ buffer: CVPixelBuffer,
		_ format: MTLPixelFormat) throws -> MTLTexture {
		guard let device = self.device else {
			throw FilterError.device
		}
		let width = CVPixelBufferGetWidth(buffer)
		let height = CVPixelBufferGetHeight(buffer)
		
		var cvTextureOut: CVMetalTexture?
		if metalTextureCache == nil {
			CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &metalTextureCache)
		}
		guard let textureCache = metalTextureCache else {
			throw FilterError.textureCahe
		}
		CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, buffer, nil, format, width, height, 0, &cvTextureOut)
		
		guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
			throw FilterError.texture
		}
		return texture
	}
	
	func allocateOutputBufferPool(
		_ inputFormatDescription: CMFormatDescription,
		_ outputRetainedBufferCountHint: Int) throws -> CVPixelBufferPool? {
		
		let inputMediaSubType = CMFormatDescriptionGetMediaSubType(inputFormatDescription)
		guard inputMediaSubType == kCVPixelFormatType_32BGRA else {
			throw FilterError.invalidBufferType(inputMediaSubType)
		}
		
		let inputDimensions = CMVideoFormatDescriptionGetDimensions(inputFormatDescription)
		let pixelBufferAttributes: [String: Any] = [
			kCVPixelBufferPixelFormatTypeKey as String: UInt(inputMediaSubType),
			kCVPixelBufferWidthKey as String: Int(inputDimensions.width),
			kCVPixelBufferHeightKey as String: Int(inputDimensions.height),
			kCVPixelBufferIOSurfacePropertiesKey as String: [:]
		]
		
		let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey as String: outputRetainedBufferCountHint]
		var cvPixelBufferPool: CVPixelBufferPool?
		CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes as NSDictionary?, pixelBufferAttributes as NSDictionary?, &cvPixelBufferPool)
	
		return cvPixelBufferPool
	}
}
