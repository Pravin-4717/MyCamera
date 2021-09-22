//
//  ViewController.swift
//  MyCamera
//
//  Created by Pravin Palaniappan on 18/09/21.
//

import AVFoundation
import UIKit

protocol ModelProtocol {
	func showAlert(alert: UIAlertController)
	func gotCameraAccess()
}
class ViewController: UIViewController {
	let model = CameraModel()

	private let processingQueue = DispatchQueue(label: "processing queue", attributes: [], autoreleaseFrequency: .workItem)
	@IBOutlet private weak var cameraView: CameraView!
	@IBOutlet private var filterMenuContainer: UIView!
	@IBOutlet private weak var recordButton: RecordButton!
	
	private var selectedFilterButton: UIButton?

	override func viewDidLoad() {
		super.viewDidLoad()
		self.model.delegate = self
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		self.model.checkAuthorization()
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(self.appBecameActive),
			name: UIApplication.didBecomeActiveNotification,
			object: nil)
	}
}
extension ViewController: ModelProtocol {
	func gotCameraAccess() {
		self.model.setupCameraSession()
	}
	
	func showAlert(alert: UIAlertController) {
		self.present(alert, animated: true, completion: nil)
	}
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
	func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		autoreleasepool {
			let texure = self.model.addFilter(buffer: sampleBuffer)
			self.cameraView.texture = texure
		}
	}
}

private extension ViewController {
	@objc
	func appBecameActive() {
		self.model.checkAuthorization()
	}
	@IBAction func changeCamerButtonPressed(_ sender: UIButton) {
		self.model.changeCamera()
	}
	
	@IBAction func recordButtonPressed(_ sender: RecordButton) {
		sender.isRecording.toggle()
		self.model.updateRecordingState()
	}
	
	@IBAction func showFilterOption(_ sender: Any) {
		if selectedFilterButton == nil {
			guard let button = filterMenuContainer.subviews.first as? UIButton else {
				assertionFailure()
				return
			}
			updateSelectedButtonUI(button)
		}
		filterMenuContainer.isHidden = false
	}
	@IBAction func filterButtonPresses(_ sender: UIButton) {
		defer {
			filterMenuContainer.isHidden = true
		}
		guard sender != selectedFilterButton else {
			return
		}
		updateUnSelectedButtonUI()
		updateSelectedButtonUI(sender)
		let filter = Filter(tag: sender.tag)
		self.model.changeFilter(filter: filter)
	}
	
	func updateSelectedButtonUI(_ button: UIButton) {
		let color = UIColor(
			displayP3Red: 73 / 255,
			green: 165 / 255,
			blue: 238 / 255, alpha: 1)
		button.backgroundColor = color
		button.tintColor = .white
		self.selectedFilterButton = button
	}
	
	func updateUnSelectedButtonUI() {
		self.selectedFilterButton?.backgroundColor = .clear
		self.selectedFilterButton?.tintColor = .systemBlue
	}
}


