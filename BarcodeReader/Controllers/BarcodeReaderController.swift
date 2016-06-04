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

    private let sessionOutputMetadataObjectsQueue = dispatch_queue_create("com.mbelsky.BarcodeReader.BarcodeReaderController.sessionOutputMetadataObjectsQueue", DISPATCH_QUEUE_SERIAL)
    private var captureSession: AVCaptureSession?

    // MARK: - Lifecycle

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidBecomeActiveNotification), name: UIApplicationDidBecomeActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationWillResignActiveNotification), name: UIApplicationWillResignActiveNotification, object: nil)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidBecomeActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationWillResignActiveNotification, object: nil)

        stopCaptureSession()
    }

    func applicationDidBecomeActiveNotification(_:AnyObject) {
        checkCameraAuthorizationStatus()
    }

    func applicationWillResignActiveNotification(_:AnyObject) {
        stopCaptureSession()
    }
}

// MARK: - Manage captureSession
extension BarcodeReaderController {
    private func startCaptureSession() {
        prepareCaptureSession()
        dispatch_async(sessionOutputMetadataObjectsQueue) {
            self.captureSession?.startRunning()
        }
    }

    private func stopCaptureSession() {
        dispatch_async(sessionOutputMetadataObjectsQueue) {
            self.captureSession?.stopRunning()
        }
    }

    private func prepareCaptureSession() {
        if nil != self.captureSession {
            return
        }

        let captureSession = AVCaptureSession();

        let videoDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        guard let sessionInput = try? AVCaptureDeviceInput(device: videoDevice) where captureSession.canAddInput(sessionInput) else {
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

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = self.view.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill

        self.view.layer.addSublayer(previewLayer)

        self.captureSession = captureSession
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension BarcodeReaderController: AVCaptureMetadataOutputObjectsDelegate {
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        guard let barcode = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }

        stopCaptureSession()

        dispatch_async(dispatch_get_main_queue()) {
            self.barcodeDidFind(barcode)
        }
    }

    func barcodeDidFind(barcode: AVMetadataMachineReadableCodeObject) {
        if nil != presentedViewController {
            // A barcode alert already presented
            return
        }

        let alertMessage = "Type: \(barcode.type)\nValue: \(barcode.stringValue)"
        let alert = UIAlertController(title: nil, message: alertMessage, preferredStyle: .Alert)
        let closeAction = UIAlertAction(title: "Close", style: .Default) { _ in
            self.startCaptureSession()
        }
        alert.addAction(closeAction)

        presentViewController(alert, animated: true, completion: nil)
    }
}

// MARK: - Manage Camera Permission
extension BarcodeReaderController {
    private func checkCameraAuthorizationStatus() {
        let authorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        switch authorizationStatus {
        case .Authorized:
            startCaptureSession()
        case .NotDetermined:
            requestCameraPermission()
        default:
            showAppNeedsCameraAlert()
        }
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo) { granted in
            dispatch_async(dispatch_get_main_queue()) {
                self.checkCameraAuthorizationStatus()
            }
        }
    }

    private func showAppNeedsCameraAlert() {
        if nil != presentedViewController {
            // Alert was presented
            return
        }

        let alert = UIAlertController(title: "Camera is disabled", message: "This app needs access to your device camera. Please turn on Camera in your device settings.", preferredStyle: .Alert)
        let settingsAction = UIAlertAction(title: "Go to Settings", style: .Default) { _ in
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }
        alert.addAction(settingsAction)

        presentViewController(alert, animated: true, completion: nil)
    }
}
