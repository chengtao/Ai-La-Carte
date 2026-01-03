//
//  CameraService.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
@preconcurrency import AVFoundation
import UIKit

// MARK: - Thread-safe Continuation Manager

private actor CameraContinuationManager {
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    func setContinuation(_ continuation: CheckedContinuation<UIImage, Error>) {
        photoContinuation = continuation
    }

    func resumeWithSuccess(_ image: UIImage) {
        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }

    func resumeWithError(_ error: Error) {
        photoContinuation?.resume(throwing: error)
        photoContinuation = nil
    }

    func clear() {
        photoContinuation = nil
    }
}

// MARK: - Camera Service

final class CameraService: NSObject, CameraServiceProtocol, @unchecked Sendable {
    // Note: @unchecked Sendable because we manage thread safety manually via actor and sessionQueue

    // Use nonisolated(unsafe) for AVFoundation types accessed on sessionQueue
    nonisolated(unsafe) private var _captureSession: AVCaptureSession?
    nonisolated(unsafe) private var photoOutput: AVCapturePhotoOutput?

    private let continuationManager = CameraContinuationManager()

    /// Dedicated queue for camera session operations
    private let sessionQueue = DispatchQueue(label: "com.ailacarte.camera.session")

    /// Expose the capture session for the preview layer
    var session: AVCaptureSession? {
        _captureSession
    }

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

            self._captureSession = session

            // Start session on background queue (Apple recommends not blocking main thread)
            nonisolated(unsafe) let capturedSession = session
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                sessionQueue.async {
                    capturedSession.startRunning()
                    continuation.resume()
                }
            }

            AppLogger.shared.info("Camera session started, isRunning: \(session.isRunning)", category: AppLogger.Category.camera)
        } catch {
            AppLogger.shared.error("Failed to start camera session: \(error)", category: AppLogger.Category.camera)
            throw CameraError.captureSessionFailed
        }
    }

    func stopSession() {
        let session = _captureSession
        _captureSession = nil
        photoOutput = nil

        sessionQueue.async {
            session?.stopRunning()
        }
        AppLogger.shared.info("Camera session stopped", category: AppLogger.Category.camera)
    }

    func capturePhoto() async throws -> UIImage {
        guard let photoOutput = photoOutput else {
            throw CameraError.captureSessionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Store continuation in actor for thread-safe access
            Task {
                await self.continuationManager.setContinuation(continuation)
            }

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    var previewLayer: AVCaptureVideoPreviewLayer? {
        guard let session = _captureSession else { return nil }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Use Task to safely access the actor-isolated continuation
        Task {
            if let error = error {
                AppLogger.shared.error("Photo capture error: \(error)", category: AppLogger.Category.camera)
                await continuationManager.resumeWithError(CameraError.captureFailed)
                return
            }

            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                await continuationManager.resumeWithError(CameraError.captureFailed)
                return
            }

            // Fix orientation
            let fixedImage = image.fixedOrientation()

            AppLogger.shared.info("Photo captured successfully", category: AppLogger.Category.camera)
            await continuationManager.resumeWithSuccess(fixedImage)
        }
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
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    func updateSession(_ session: AVCaptureSession) {
        guard videoPreviewLayer.session !== session else {
            AppLogger.shared.debug("Preview: Session already set", category: AppLogger.Category.camera)
            return
        }

        AppLogger.shared.info("Preview: Setting session, isRunning: \(session.isRunning)", category: AppLogger.Category.camera)
        videoPreviewLayer.session = session
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        AppLogger.shared.debug("Preview: layoutSubviews, bounds: \(bounds), session: \(videoPreviewLayer.session != nil)", category: AppLogger.Category.camera)
    }
}
