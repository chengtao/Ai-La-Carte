//
//  CameraService.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import AVFoundation
import UIKit

final class CameraService: NSObject, CameraServiceProtocol {
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    var authorizationStatus: CameraAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }

    func requestAuthorization() async -> CameraAuthorizationStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        AppLogger.shared.info("Camera authorization: \(granted)", category: AppLogger.Category.camera)
        return granted ? .authorized : .denied
    }

    func startSession() async throws {
        guard authorizationStatus == .authorized else {
            throw CameraError.accessDenied
        }

        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.notAvailable
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                throw CameraError.captureSessionFailed
            }

            let output = AVCapturePhotoOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                self.photoOutput = output
            } else {
                throw CameraError.captureSessionFailed
            }

            self.captureSession = session

            await MainActor.run {
                session.startRunning()
            }

            AppLogger.shared.info("Camera session started", category: AppLogger.Category.camera)
        } catch {
            AppLogger.shared.error("Failed to start camera session: \(error)", category: AppLogger.Category.camera)
            throw CameraError.captureSessionFailed
        }
    }

    func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
        photoOutput = nil
        AppLogger.shared.info("Camera session stopped", category: AppLogger.Category.camera)
    }

    func capturePhoto() async throws -> UIImage {
        guard let photoOutput = photoOutput else {
            throw CameraError.captureSessionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    var previewLayer: AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            AppLogger.shared.error("Photo capture error: \(error)", category: AppLogger.Category.camera)
            photoContinuation?.resume(throwing: CameraError.captureFailed)
            photoContinuation = nil
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?.resume(throwing: CameraError.captureFailed)
            photoContinuation = nil
            return
        }

        // Fix orientation
        let fixedImage = image.fixedOrientation()

        AppLogger.shared.info("Photo captured successfully", category: AppLogger.Category.camera)
        photoContinuation?.resume(returning: fixedImage)
        photoContinuation = nil
    }
}

// MARK: - UIImage Orientation Fix

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? self
    }
}

// MARK: - Camera Preview View (UIViewRepresentable)

import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if let session = session {
            uiView.updateSession(session)
        }
    }
}

class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    func updateSession(_ session: AVCaptureSession) {
        videoPreviewLayer.session = session
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }
}
