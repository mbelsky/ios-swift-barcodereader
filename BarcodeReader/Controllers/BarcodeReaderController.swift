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
    // MARK: - Properties

    fileprivate let sessionOutputMetadataObjectsQueue = DispatchQueue(label: "com.mbelsky.BarcodeReader.BarcodeReaderController.sessionOutputMetadataObjectsQueue", attributes: [])
    fileprivate var captureSession: AVCaptureSession?

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActiveNotification), name: .UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActiveNotification), name: .UIApplicationWillResignActive, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)

        stopCaptureSession()
    }

    func applicationDidBecomeActiveNotification(_: AnyObject) {
        checkCameraAuthorizationStatus()
    }

    func applicationWillResignActiveNotification(_: AnyObject) {
        stopCaptureSession()
    }
}

// MARK: - Manage captureSession
extension BarcodeReaderController {
    fileprivate func startCaptureSession() {
        prepareCaptureSession()
        sessionOutputMetadataObjectsQueue.async {
            self.captureSession?.startRunning()
        }
    }

    fileprivate func stopCaptureSession() {
        sessionOutputMetadataObjectsQueue.async {
            self.captureSession?.stopRunning()
        }
    }

    fileprivate func prepareCaptureSession() {
        if nil != self.captureSession {
            return
        }

        let captureSession = AVCaptureSession();

        let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        guard let sessionInput = try? AVCaptureDeviceInput(device: videoDevice), captureSession.canAddInput(sessionInput) else {
            return
        }
        let sessionOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(sessionOutput) else {
            return
        }

        captureSession.addInput(sessionInput)
        captureSession.addOutput(sessionOutput)

        sessionOutput.metadataObjectTypes = [AVMetadataObjectTypeCode39Code, AVMetadataObjectTypeCode39Mod43Code,
                                             AVMetadataObjectTypeCode93Code, AVMetadataObjectTypeCode128Code,
                                             AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeEAN13Code,
                                             AVMetadataObjectTypeITF14Code, AVMetadataObjectTypeUPCECode]
        sessionOutput.setMetadataObjectsDelegate(self, queue: sessionOutputMetadataObjectsQueue)

        if let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession) {
            previewLayer.frame = self.view.bounds
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            
            self.view.layer.addSublayer(previewLayer)
        }

        self.captureSession = captureSession
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension BarcodeReaderController: AVCaptureMetadataOutputObjectsDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
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

        let alertMessage = "Type: \(barcode.type!)\nValue: \(barcode.stringValue!)"
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
        let authorizationStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
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
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) { granted in
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
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
        }
        alert.addAction(settingsAction)

        present(alert, animated: true, completion: nil)
    }
}
