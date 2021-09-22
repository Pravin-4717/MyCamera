//
//  Helper.swift
//  MyCamera
//
//  Created by Pravin Palaniappan on 20/09/21.
//

import Foundation
import MetalKit

enum Camera {
	case front, back
}

enum CaptureState {
	case idle, start, capturing, end
}

enum FilterError: Error {
	case device, library, funtion, pipline, pixelBufferAllocation, texture, textureCahe
	case commadeQueue
	case invalidBufferType(FourCharCode)

	var description: String {
		switch self {
		case .device:
			return "Device not found"
		case .library:
			return "Defualt Library not found"
		case .funtion:
			return "couldn't create MTLFuntion"
		case .pipline:
			return "couldn't create  MTLComputePipelineState"
		case .commadeQueue:
			return "couldn't create  command queue"
		case .invalidBufferType(let bufferType):
			return "Invalid input pixel buffer type \(bufferType)"
		case .pixelBufferAllocation:
			return "Couldn't allocate pixel buffer pool"
		case .texture:
			return "couldn't create  metal texture"
		case .textureCahe:
			return "Couldn't allocate TextuerCache"
		}
	}
}

class Preferences {
	static var clearColor: MTLClearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
	static var mainPixelFormat: MTLPixelFormat = .bgra8Unorm
	static var MainDepthPixelFormat: MTLPixelFormat = MTLPixelFormat.depth32Float
}

protocol Sizeable {
}

extension SIMD3: Sizeable {}

extension SIMD4: Sizeable {}

struct Vertex: Sizeable {
	let position: SIMD3<Float>
	let textureCordinate: SIMD2<Float>

	init(position: SIMD3<Float>, textureCordinate: SIMD2<Float>) {
		self.position = position
		self.textureCordinate = textureCordinate
	}
}

extension Sizeable {
	static var size: Int {
		return MemoryLayout<Self>.size
	}

	static var stride: Int {
		return MemoryLayout<Self>.stride
	}

	static func stride(_ count: Int) -> Int {
		return stride * count
	}
}
