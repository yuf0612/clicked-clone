//
//  CameraService.swift
//  相机服务 —— 基于 AVFoundation 实现预览、拍照、实时帧捕获
//
//  负责：相机权限、预览层、拍照、实时取景帧（供人脸对齐/场景分析）、切换摄像头。
//

import AVFoundation
import Combine
import UIKit

final class CameraService: NSObject, ObservableObject {

    // 会话：管理相机输入输出
    private let session = AVCaptureSession()
    // 预览层：显示相机画面
    let previewLayer = AVCaptureVideoPreviewLayer()
    // 图片输出
    private let photoOutput = AVCapturePhotoOutput()
    // 视频数据输出：抓实时帧做 AI 分析
    private let videoOutput = AVCaptureVideoDataOutput()
    private let frameQueue = DispatchQueue(label: "com.clickedclone.frame", qos: .userInitiated)
    // 当前摄像头
    private var currentCamera: AVCaptureDevice?
    @Published var isUsingFrontCamera = true

    // 权限状态
    @Published var permissionGranted = false
    @Published var cameraError: String?

    // 回调
    var onPhotoCaptured: ((UIImage) -> Void)?
    // 实时帧回调（每 ~0.5 秒一帧，供人脸对齐/场景分析）
    var onFrameCaptured: ((UIImage) -> Void)?
    private var lastFrameTime: Date = .distantPast

    override init() {
        super.init()
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        checkPermissions()
    }

    // MARK: - 权限检查
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted { self?.setupCamera() }
                }
            }
        case .denied, .restricted:
            cameraError = "相机权限被拒绝，请在 设置 > 隐私 > 相机 中开启。"
        @unknown default:
            break
        }
    }

    // MARK: - 配置相机
    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .medium   // 中等分辨率，取景帧分析够用且省电

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            cameraError = "未找到可用摄像头"
            session.commitConfiguration()
            return
        }
        currentCamera = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

            // 配置实时帧输出
            videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        } catch {
            cameraError = "相机初始化失败：\(error.localizedDescription)"
        }

        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    // MARK: - 切换前后摄像头
    func switchCamera() {
        guard permissionGranted else { return }
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }

        let position: AVCaptureDevice.Position = isUsingFrontCamera ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        if session.canAddInput(input) { session.addInput(input) }
        currentCamera = device
        isUsingFrontCamera.toggle()
        session.commitConfiguration()
    }

    // MARK: - 拍照（单次）
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - 生命周期
    func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onPhotoCaptured?(image.fixedOrientation)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate（实时帧）
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // 节流：每 0.5 秒取一帧，避免分析过于频繁耗电
        let now = Date()
        guard now.timeIntervalSince(lastFrameTime) >= 0.5 else { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let image = UIImage(ciImage: ciImage)
        // 前置摄像头帧需镜像，与预览一致
        let finalImage = isUsingFrontCamera ? mirrorImage(image) : image
        onFrameCaptured?(finalImage)
    }

    private func mirrorImage(_ image: UIImage) -> UIImage {
        UIGraphicsImageRenderer(size: image.size).image { ctx in
            ctx.cgContext.translateBy(x: image.size.width, y: 0)
            ctx.cgContext.scaleBy(x: -1, y: 1)
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
