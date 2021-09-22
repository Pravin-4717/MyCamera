//
//  VideoRecorder.swift
//  MyCamera
//
//  Created by Pravin Palaniappan on 22/09/21.
//

import AVFoundation
import Photos

protocol VideoRecorderProtocol {
	func showNoCameraRollAccessDialog()
}
private class VideoData {
	var assetWriter: AVAssetWriter
	var assetWriterInput: AVAssetWriterInput
	var adapter: AVAssetWriterInputPixelBufferAdaptor
	var filename = ""
	let time: Double
	let url: URL
	var isVideoSaved = false
	var showAllert = false
	
	init?(videoOutput: AVCaptureVideoDataOutput, time: Double) {
		self.filename = UUID().uuidString
		let videoPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
		guard var path = videoPath else {
			assertionFailure()
			return nil
		}
		path.appendPathComponent("\(filename).mov")
		self.url = path
		guard let assetWriter = try? AVAssetWriter(outputURL: path, fileType: .mov) else {
			assertionFailure()
			return nil
		}
		self.assetWriter = assetWriter
		let setting = videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov)
		let input = AVAssetWriterInput(mediaType: .video, outputSettings: setting)
		input.mediaTimeScale = CMTimeScale(bitPattern: 600)
		input.expectsMediaDataInRealTime = true
		input.transform = CGAffineTransform(rotationAngle: .pi/2)
		
		self.assetWriterInput = input
		
		let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
		self.adapter = adapter
		if assetWriter.canAdd(input) {
			assetWriter.add(input)
		}
		assetWriter.startWriting()
		assetWriter.startSession(atSourceTime: .zero)
		
		self.time =  time
	}
	
	func append(buffer: CVImageBuffer, at currentTime: Double) {
		guard assetWriterInput.isReadyForMoreMediaData else {
			return
		}
		let time = CMTime(seconds: currentTime - self.time, preferredTimescale: CMTimeScale(600))
		self.adapter.append(buffer, withPresentationTime: time)
	}
	
	func endRecording( completion: @escaping (() -> Void)) {
		guard self.assetWriterInput.isReadyForMoreMediaData,
			  assetWriter.status != .failed else {
			self.showAllert = true
			return
		}
		self.addVideoToCameraRoll()
		self.assetWriterInput.markAsFinished()
		self.assetWriter.finishWriting {
			completion()
		}
	}
	
	func addVideoToCameraRoll() {
		requestAuthorization { [weak self] in
			self?.showAllert = false
			PHPhotoLibrary.shared().performChanges { [weak self] in
				guard let self = self else {
					assertionFailure()
					return
				}
				PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.url)
				
			} completionHandler: { [weak self] saved, error in
				guard saved, error == nil else {
					assertionFailure("video not saved")
					return
				}
				self?.isVideoSaved = true
			}
		}
	}
	
	func requestAuthorization(completion: @escaping ()->Void) {
		if PHPhotoLibrary.authorizationStatus() == .notDetermined {
			PHPhotoLibrary.requestAuthorization { status in
				if status == .authorized {
					completion()
				} else {
					self.showAllert = true
				}
			}
		} else if PHPhotoLibrary.authorizationStatus() == .authorized {
			completion()
		} else {
			self.showAllert = true
		}
	}
	
	func deleteVideo() {
		let fileManager = FileManager.default
		guard fileManager.fileExists(atPath: url.relativePath) else {
			assertionFailure()
			return
		}
		do {
			try fileManager.removeItem(at: url)
			print("Video \(filename) is deleted")
		} catch {
			assertionFailure(error.localizedDescription)
		}
	}
}

class VideoRecoder {
	private var state: CaptureState = .idle
	private var currentSessionData: VideoData?
	var delegate: VideoRecorderProtocol?
	
	func updateToNextState() {
		switch state {
		case .idle:
			state = .start
		case .capturing:
			state = .end
		default:
			break
		}
	}
	
	func update(videoOutput: AVCaptureVideoDataOutput, with buffer: CVImageBuffer, time: Double) {
		switch state {
		case .idle:
			return
		case .start:
			self.deleteVideo()
			self.currentSessionData = VideoData(videoOutput: videoOutput, time: time)
			self.state = .capturing
		case .capturing:
			record(buffer, time: time)
		case .end:
			self.currentSessionData?.endRecording { [weak self] in
				if self?.currentSessionData?.isVideoSaved ?? false {
					self?.currentSessionData = nil
				}
				if self?.currentSessionData?.showAllert ?? false {
					self?.delegate?.showNoCameraRollAccessDialog()
				}
				self?.state = .idle
			}
		}
	}
	
	func saveVideoIfNeeded() {
		if self.currentSessionData != nil {
			self.saveVideo()
		}
	}
	
	func saveVideo() {
		guard let data = self.currentSessionData else {
			assertionFailure()
			return
		}
		if PHPhotoLibrary.authorizationStatus() == .authorized  {
			data.addVideoToCameraRoll()
		} else {
			self.delegate?.showNoCameraRollAccessDialog()
		}
	}

	func deleteVideo() {
		self.currentSessionData?.deleteVideo()
		self.currentSessionData = nil
	}

	private func record(_ buffer: CVImageBuffer, time: Double) {
		guard let data = currentSessionData else {
			assertionFailure()
			return
		}
		data.append(buffer: buffer, at: time)
	}
}
