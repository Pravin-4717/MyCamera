//
//  RecordButton.swift
//  MyCamera
//
//  Created by Pravin Palaniappan on 20/09/21.
//

import UIKit

class RecordButton: UIButton {
	var isVideoButton = true {
		didSet {
			if self.isVideoButton != oldValue {
				updateUIForMode()
			}
		}
	}
	var isRecording = false  {
		didSet {
			if self.isRecording != oldValue {
				updateUIforRecording()
			}
		}
	}

	private let innerLayer = CALayer()
	private let greyColor = CGColor(gray: 0.7, alpha: 1)

	private lazy var outerBounds: CGRect = {
		return self.bounds.insetBy(dx: 2.5, dy: 2.5)
	}()

	override func didMoveToWindow() {
		super.didMoveToWindow()
		guard self.window != nil else {
			return
		}
		self.setup()
	}
}

private extension RecordButton {
	func setup() {
		self.setupOuterLayer()
		self.setupInnerLayer()
	}
	
	func setupOuterLayer() {
		let outerLayer = CAShapeLayer()
		outerLayer.frame = self.bounds
		let outerPath = UIBezierPath(ovalIn: self.outerBounds).cgPath
		outerLayer.path = outerPath
		outerLayer.lineWidth = 5
		outerLayer.strokeColor = self.greyColor
		
		self.layer.addSublayer(outerLayer)
	}
	
	func setupInnerLayer() {
		innerLayer.frame = self.bounds
		let fillColor = self.isVideoButton ? UIColor.red.cgColor : self.greyColor
		let innerBounds = self.outerBounds.insetBy(dx: 5, dy: 5)
		innerLayer.frame = innerBounds
		self.innerLayer.backgroundColor = fillColor
		self.innerLayer.cornerRadius = innerBounds.width / 2

		self.layer.addSublayer(self.innerLayer)
	}
	
	func updateUIForMode() {
		guard !self.isRecording else {
			assertionFailure()
			return
		}
		let fillColor = self.isVideoButton ? UIColor.red.cgColor : self.greyColor
		self.innerLayer.backgroundColor = fillColor
	}
	
	func updateUIforRecording() {
		guard self.isVideoButton else {
			assertionFailure()
			return
		}
		let transform = isRecording ? CGAffineTransform(scaleX: 0.4, y: 0.4) : .identity
		let width = self.outerBounds.insetBy(dx: 5, dy: 5).width
		let cornerRadius = isRecording ? 5 : width/2
		
		self.innerLayer.setAffineTransform(transform)
		self.innerLayer.cornerRadius = cornerRadius
	}
}
