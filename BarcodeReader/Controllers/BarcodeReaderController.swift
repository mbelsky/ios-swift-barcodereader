//
//  BarcodeReaderController.swift
//  BarcodeReader
//
//  Created by Maxim Belsky on 12.03.16.
//  Copyright © 2016 Maxim Belsky. All rights reserved.
//

import AVFoundation
import UIKit

class BarcodeReaderController: UIViewController {
    // Define metadata object types that might be detected in a picture
    let metadataObjectTypes: [AVMetadataObject.ObjectType] = [.qr]

    fileprivate let sessionQueue = DispatchQueue(label: "sessionQueue")
    fileprivate var captureSession: AVCaptureSession?

    // MARK: - Lifecycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applicationDidBecomeActiveNotification()

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActiveNotification),
                                               name: .UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActiveNotification),
                                               name: .UIApplicationWillResignActive, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)

        applicationWillResignActiveNotification()
    }

    @objc func applicationDidBecomeActiveNotification(_: AnyObject? = nil) {
        checkCameraAuthorizationStatus()
    }

    @objc func applicationWillResignActiveNotification(_: AnyObject? = nil) {
        stopCaptureSession()
    }
}

// MARK: - Manage captureSession
extension BarcodeReaderController {
    fileprivate func startCaptureSession() {
        prepareCaptureSession()
        sessionQueue.async {
            self.captureSession?.startRunning()
        }
    }

    fileprivate func stopCaptureSession() {
        sessionQueue.async {
            self.captureSession?.stopRunning()
        }
    }

    fileprivate func prepareCaptureSession() {
        if nil != self.captureSession {
            return
        }

        let captureSession = AVCaptureSession()
        captureSession.beginConfiguration()

        let videoDevice: AVCaptureDevice?
        if #available(iOS 10, *) {
            videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        } else {
            videoDevice = AVCaptureDevice.default(for: .video)
        }
        guard let device = videoDevice,
                let sessionInput = try? AVCaptureDeviceInput(device: device),
                captureSession.canAddInput(sessionInput)
        else {
            return
        }

        captureSession.addInput(sessionInput)

        let sessionOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(sessionOutput) else {
            return
        }

        captureSession.addOutput(sessionOutput)

        sessionOutput.metadataObjectTypes = metadataObjectTypes
        sessionOutput.setMetadataObjectsDelegate(self, queue: sessionQueue)

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill

        view.layer.addSublayer(previewLayer)

        captureSession.commitConfiguration()

        self.captureSession = captureSession
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension BarcodeReaderController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let barcode = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }

        stopCaptureSession()

        DispatchQueue.main.async {
            self.barcodeDidFind(barcode)
        }
    }

    func barcodeDidFind(_ barcode: AVMetadataMachineReadableCodeObject) {
        if nil != presentedViewController {
            // A barcode alert already presented
            return
        }

        let alertMessage = "Type: \(barcode.type)\nValue: \(barcode.stringValue!)"
        let alert = UIAlertController(title: nil, message: alertMessage, preferredStyle: .alert)
        let closeAction = UIAlertAction(title: "Close", style: .default) { _ in
            self.startCaptureSession()
        }
        alert.addAction(closeAction)

        present(alert, animated: true, completion: nil)
    }
}

// MARK: - Manage Camera Permission
extension BarcodeReaderController {
    fileprivate func checkCameraAuthorizationStatus() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authorizationStatus {
        case .authorized:
            startCaptureSession()
        case .notDetermined:
            requestCameraPermission()
        default:
            showAppNeedsCameraAlert()
        }
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.checkCameraAuthorizationStatus()
            }
        }
    }

    private func showAppNeedsCameraAlert() {
        if nil != presentedViewController {
            // Alert was presented
            return
        }

        let alert = UIAlertController(title: "Camera is disabled", message: "This app needs access to your device camera. Please turn on Camera in your device settings.", preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: "Go to Settings", style: .default) { _ in
            guard let url = URL(string: UIApplicationOpenSettingsURLString) else { return }
            if #available(iOS 10, *) {
                UIApplication.shared.open(url)
            } else {
                UIApplication.shared.openURL(url)
            }
        }
        alert.addAction(settingsAction)

        present(alert, animated: true, completion: nil)
    }
}
