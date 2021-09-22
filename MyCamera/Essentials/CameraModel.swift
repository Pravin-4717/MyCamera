//
//  CameraModel.swift
//  MyCamera
//
//  Created by Pravin Palaniappan on 20/09/21.
//

import AVFoundation
import UIKit

class CameraModel {
	private let sessionQueue = DispatchQueue(label: "SessionQueue", attributes: [], autoreleaseFrequency: .workItem)
	
	private var isSetupComplete = false
	var delegate: ModelProtocol?
	var outputDelegate: AVCaptureVideoDataOutputSampleBufferDelegate? {
		delegate as? AVCaptureVideoDataOutputSampleBufferDelegate
	}

	private let filterModel = FilterModel()
	private let recorder = VideoRecoder()
	private let captureSession = AVCaptureSession()
	private let videoOutput = AVCaptureVideoDataOutput()
	private var currentInput: AVCaptureInput?

	private var activeCamera = Camera.back

	private lazy var backCamera: AVCaptureDevice? = {
		self.getCameraDevice(.back)
	}()
	
	private lazy var frontCamera: AVCaptureDevice? = {
		self.getCameraDevice(.front)
	}()
	
	func checkAuthorization() {
		let cameraAuthStatus =  AVCaptureDevice.authorizationStatus(
			for: AVMediaType.video)
		switch cameraAuthStatus {
		case .notDetermined:
			requestCameraAccess()
		case .restricted, .denied:
			showNoCameraAccessDialog()
		case .authorized:
			delegate?.gotCameraAccess()
			recorder.saveVideoIfNeeded()
		@unknown default:
			assertionFailure("Authorization Error: Unkown authorization error")
			showNoCameraAccessDialog()
		}
	}
	
	func setupCameraSession() {
		guard !self.isSetupComplete else {
			return
		}
		sessionQueue.async {
			self.setupCaptureSession()
			self.isSetupComplete = true
		}
		self.recorder.delegate = self
	}
	
	func changeCamera() {
		switch activeCamera {
		case .front:
			self.activeCamera = .back
		case .back:
			self.activeCamera = .front
		}
		addinput()
	}
	
	func updateRecordingState() {
		self.recorder.updateToNextState()
	}
	
	func changeFilter(filter: Filter) {
		filterModel.filter = filter
	}

	func addFilter(buffer: CMSampleBuffer) -> MTLTexture? {
		guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer),
			  let formatDescription = CMSampleBufferGetFormatDescription(buffer) else {
			assertionFailure()
			return nil
		}
		do {
			var newPixelBuffer: CVPixelBuffer?
			let texture = try filterModel.render(
				buffer: imageBuffer,
				newPixelBuffer: &newPixelBuffer,
				formatDescription: formatDescription)
			
			guard let pixelBuffer = newPixelBuffer else {
				assertionFailure()
				return nil
			}
			let time = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
			recorder.update(videoOutput: self.videoOutput, with: pixelBuffer, time: time)
			return texture
		} catch {
			if let errorString = (error as? FilterError)?.description {
				assertionFailure(errorString)
			} else {
				assertionFailure(error.localizedDescription)
			}
		}
		return nil
	}
}

extension CameraModel: VideoRecorderProtocol {
	func showNoCameraRollAccessDialog() {
		let alert = UIAlertController(title: "Alert", message: "Couldn't acces your camera Roll. App needs access to the camera Roll to save video.", preferredStyle: .alert)
		let setting = UIAlertAction(title: "Go to Setting", style: .default) { _ in
			guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
				return
			}
			
			if UIApplication.shared.canOpenURL(settingsUrl) {
				UIApplication.shared.open(settingsUrl) {
					print("Settings opened: \($0)")
				}
			}
		}
		let cancel = UIAlertAction(title: "Delete Video", style: .default) { [weak self] _ in
			self?.recorder.deleteVideo()
		}
		alert.addAction(setting)
		alert.addAction(cancel)
		DispatchQueue.main.async { [weak self] in
			self?.delegate?.showAlert(alert: alert)
		}
	}
}
private extension CameraModel {
	func setupCaptureSession() {
		self.captureSession.beginConfiguration()
		if self.captureSession.canSetSessionPreset(.photo) {
			self.captureSession.sessionPreset = .photo
		}
		self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
		self.addinput()
		self.addOutput()
		self.captureSession.commitConfiguration()
		self.captureSession.startRunning()
	}

	func addinput() {
		self.removeInput()
		let activeDevice = activeCamera == .back ? backCamera : frontCamera
		guard let camera = activeDevice else {
			fatalError("Couldn't create AVCaptureDevice")
		}
		guard let input = try? AVCaptureDeviceInput(device: camera) else {
			fatalError("Couldn't create input device from camera")
		}
		self.currentInput = input
		guard self.captureSession.canAddInput(input) else {
			fatalError("Couldn't add input to camera session")
		}
		self.captureSession.addInput(input)
	}

	func removeInput() {
		if let input = self.currentInput {
			self.captureSession.removeInput(input)
			self.currentInput = nil
		}
	}
	
	func addOutput(){
		guard self.captureSession.canAddOutput(videoOutput),
			  let outputDelegate = self.outputDelegate else {
			assertionFailure()
			return
		}
		let outputQueue = DispatchQueue(
			label: "VideoOutPutQueue",
			qos: .userInitiated,
			attributes: [],
			autoreleaseFrequency: .workItem)
		captureSession.addOutput(videoOutput)
		videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
		videoOutput.setSampleBufferDelegate(outputDelegate, queue: outputQueue)
	}
	
	func showNoCameraAccessDialog() {
		let alert = UIAlertController(title: "Alert", message: "Couldn't acces your camera. App needs access to the camera to proceed.", preferredStyle: .alert)
		let setting = UIAlertAction(title: "Go to Setting", style: .default) { _ in
			guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
				return
			}
			
			if UIApplication.shared.canOpenURL(settingsUrl) {
				UIApplication.shared.open(settingsUrl) {
					print("Settings opened: \($0)")
				}
			}
		}
		let quit = UIAlertAction(title: "Quit", style: .default) { _ in
			UIControl().sendAction(#selector(NSXPCConnection.suspend),
								   to: UIApplication.shared, for: nil)

		}
		alert.addAction(setting)
		alert.addAction(quit)
		delegate?.showAlert(alert: alert)
	}

	func requestCameraAccess() {
		AVCaptureDevice.requestAccess(for: AVMediaType.video) { [weak self] in
			if !$0 {
				self?.showNoCameraAccessDialog()
			}
		}
	}
	
	func getCameraDevice(_ postion: AVCaptureDevice.Position) -> AVCaptureDevice? {
		if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: postion) {
			return device
		} else if let device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: postion) {
			return device
		} else if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: postion) {
			return device
		} else {
			assertionFailure()
			return nil
		}
	}
}
