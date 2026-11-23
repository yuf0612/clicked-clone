//
//  CameraViewModel.swift
//  相机界面逻辑 —— 管理拍照流程、定时器、连拍、样片叠加、真实人脸自动快门、场景分析
//

import SwiftUI
import Combine
import UIKit

final class CameraViewModel: ObservableObject {

    let cameraService = CameraService()
    private let faceService = FaceDetectionService.shared
    private let ai = AIService.shared

    // 样片叠加
    @Published var overlayImage: UIImage?
    @Published var overlayOpacity: Double = 0.45
    @Published var showOverlayOnlyPerson = true

    // 定时连拍
    @Published var timerSeconds: Int = 0
    @Published var burstCount: Int = 1

    // 状态
    @Published var isCountingDown = false
    @Published var countdownText: String = ""
    @Published var capturedImage: UIImage?
    @Published var showPreview = false
    @Published var hints: [CaptureHint] = []
    @Published var isAnalyzing = false

    // 自动快门
    @Published var autoShutterEnabled = false
    @Published var alignmentScore: Float = 0
    @Published var faceDetected = false
    private var autoShutterFired = false
    private var isProcessingFrame = false   // 防止帧分析重入

    // 场景指导开关（开启后周期性自动分析取景画面并给出建议）
    @Published var sceneGuideEnabled = false
    private var sceneGuideTimer: Timer?

    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?
    private var lastSceneAnalysis: Date = .distantPast

    init() {
        // 拍照完成 → 预览确认页
        cameraService.onPhotoCaptured = { [weak self] image in
            self?.capturedImage = image
            self?.showPreview = true
        }
        // 实时帧 → 人脸对齐分析（Smart Guide） + 缓存最新帧（场景分析用）
        cameraService.onFrameCaptured = { [weak self] image in
            self?.handleFrame(image)
        }
    }

    // MARK: - 处理实时取景帧
    /// 注意：相机回调来自后台队列，所有 @Published 读写必须收拢到主线程，
    /// 否则会触发 SwiftUI "Publishing changes from background threads" 警告甚至 UI 异常。
    private func handleFrame(_ image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 缓存最新帧，供场景分析按钮使用
            self.latestFrame = image

            // 自动快门开启时，做真实人脸检测 + 对齐评分；防重入避免堆积检测任务
            guard self.autoShutterEnabled && !self.showPreview && !self.isProcessingFrame else { return }
            self.isProcessingFrame = true

            let faces = self.faceService.detectFacesSync(in: image)
            let score = self.faceService.alignmentScore(face: faces.first, imageSize: image.size)

            self.alignmentScore = score
            self.faceDetected = !faces.isEmpty
            self.isProcessingFrame = false

            // 对齐度达标且稳定 → 自动拍照
            if score > 0.85 && !self.autoShutterFired {
                self.autoShutterFired = true
                self.cameraService.capturePhoto()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.autoShutterFired = false
                }
            }
        }
    }

    private var latestFrame: UIImage?

    // MARK: - 用户点快门
    func takePhoto() {
        guard !isCountingDown else { return }
        if timerSeconds > 0 { startCountdown() } else { captureBurst() }
    }

    private func captureBurst() {
        var remaining = burstCount
        func shootOnce() {
            guard remaining > 0 else { return }
            cameraService.capturePhoto()
            remaining -= 1
            if remaining > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { shootOnce() }
            }
        }
        shootOnce()
    }

    private func startCountdown() {
        isCountingDown = true
        var remaining = timerSeconds
        countdownText = "\(remaining)"
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            remaining -= 1
            if remaining <= 0 {
                timer.invalidate()
                self.isCountingDown = false
                self.countdownText = ""
                self.captureBurst()
            } else {
                self.countdownText = "\(remaining)"
            }
        }
    }

    // MARK: - 场景指导开关
    /// 开启后立即分析一次，并每 6 秒自动刷新建议；关闭时清空提示并停止定时器
    func toggleSceneGuide() {
        sceneGuideEnabled.toggle()
        if sceneGuideEnabled {
            Task { await self.runSceneAnalysis() }
            sceneGuideTimer?.invalidate()
            sceneGuideTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
                guard let self = self, self.sceneGuideEnabled else { return }
                Task { await self.runSceneAnalysis() }
            }
        } else {
            sceneGuideTimer?.invalidate()
            sceneGuideTimer = nil
            hints = []
            isAnalyzing = false
        }
    }

    // MARK: - PicScan 场景分析（用真实取景帧）
    func runSceneAnalysis() async {
        guard let frame = latestFrame else {
            // 还没有取景帧时给个提示，而不是静默无响应
            await MainActor.run {
                if self.hints.isEmpty {
                    self.hints = [CaptureHint(
                        icon: "camera.viewfinder",
                        title: "正在准备相机",
                        detail: "请稍等一秒，相机画面出现后即可给出建议",
                        severity: .info
                    )]
                }
            }
            return
        }
        await MainActor.run { isAnalyzing = true }

        // 用真实 AI 后端分析当前取景帧（失败自动降级到本地分析）
        let result = await ai.analyzeScene(image: frame)

        let analysisTime = Date()
        await MainActor.run {
            self.hints = result
            self.isAnalyzing = false
            self.lastSceneAnalysis = analysisTime
        }
        // 手动分析：8 秒后自动隐藏；场景指导开关开启时保持常显（由 toggleSceneGuide 负责清空）
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self = self else { return }
            if self.lastSceneAnalysis == analysisTime && !self.sceneGuideEnabled {
                self.hints = []
            }
        }
    }

    // MARK: - 样片
    func setOverlay(_ image: UIImage) { overlayImage = image }
    func clearOverlay() { overlayImage = nil }

    // MARK: - 重拍
    func retake() {
        capturedImage = nil
        showPreview = false
        autoShutterFired = false
    }

    deinit {
        countdownTimer?.invalidate()
        sceneGuideTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }
}
