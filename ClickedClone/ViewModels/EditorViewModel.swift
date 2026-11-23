//
//  EditorViewModel.swift
//  编辑器逻辑 —— 管理滤镜选择、调整参数、美颜、AI、导出
//

import SwiftUI
import Combine
import UIKit

final class EditorViewModel: ObservableObject {

    // 当前编辑会话
    @Published var session: EditSession?
    // 处理后的预览图（每次参数变化重新计算）
    @Published var previewImage: UIImage?
    // 当前选中的分类
    @Published var selectedCategory: FilterPreset.FilterCategory = .all
    // 当前工具标签页
    @Published var activeTool: EditorTool = .filters
    // 是否显示原图（长按对比）
    @Published var showingOriginal = false
    // AI 额度提示
    @Published var showPaywall = false
    // 提示消息（AI 处理完成、降级模式等）
    @Published var statusMessage: String?
    // 移除物体模式（开启后用户在图片上点选）
    @Published var removeObjectMode = false
    // 用户点选的移除点
    @Published var removalPoints: [CGPoint] = []

    private let processor = ImageProcessor.shared
    private let ai = AIService.shared
    private var cancellables = Set<AnyCancellable>()

    enum EditorTool: String, CaseIterable, Identifiable {
        case filters = "滤镜"
        case adjust = "调整"
        case beauty = "美颜"
        case ai = "AI"
        var id: String { rawValue }
    }

    init() {
        // 监听所有编辑参数变化 → 自动重新渲染预览图
        $session
            .compactMap { $0 }
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .map { [weak self] session in
                self?.processor.process(session) ?? UIImage()
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                self?.previewImage = image
            }
            .store(in: &cancellables)
    }

    // MARK: - 加载图片
    func loadImage(_ image: UIImage) {
        session = EditSession(originalImage: image.fixedOrientation)
        removalPoints = []
        removeObjectMode = false
    }

    // MARK: - 选择滤镜
    func selectPreset(_ preset: FilterPreset) {
        guard var s = session else { return }
        if s.selectedPreset?.id == preset.id {
            s.selectedPreset = nil
        } else {
            s.selectedPreset = preset
            s.filterIntensity = preset.intensity
        }
        session = s
    }

    // MARK: - 复制 / 粘贴编辑
    private var copiedSession: EditSession?
    func copyEdits() {
        copiedSession = session
        showStatus("已复制编辑参数")
    }
    func pasteEdits() {
        guard let copied = copiedSession, var current = session else { return }
        current.selectedPreset = copied.selectedPreset
        current.filterIntensity = copied.filterIntensity
        current.adjustments = copied.adjustments
        current.beauty = copied.beauty
        current.aiStyle = copied.aiStyle
        current.aiProcessedImage = copied.aiProcessedImage
        session = current
        showStatus("已粘贴编辑参数")
    }

    // MARK: - 通用参数更新
    func updateAdjustment(_ key: WritableKeyPath<Adjustments, Double>, value: Double) {
        guard var s = session else { return }
        s.adjustments[keyPath: key] = value
        session = s
    }
    func updateBeauty(_ key: WritableKeyPath<BeautySettings, Double>, value: Double) {
        guard var s = session else { return }
        s.beauty[keyPath: key] = value
        session = s
    }
    func updateFilterIntensity(_ value: Double) {
        guard var s = session else { return }
        s.filterIntensity = value
        session = s
    }

    // MARK: - 重置
    func resetAll() {
        guard let s = session else { return }
        session = EditSession(originalImage: s.originalImage)
        removalPoints = []
        showStatus("已重置所有编辑")
    }

    // MARK: - 应用 AI 风格（异步真实调用 + 降级）
    func applyAIStyle(_ style: String, isPro: Bool) async {
        guard AIService.shared.canUseAI(isPro: isPro) else {
            showPaywall = true
            return
        }
        guard var s = session else { return }

        if style == "None" {
            s.aiStyle = nil
            s.aiProcessedImage = nil
            s.isUsingLocalAI = false
            session = s
            return
        }

        // 显示处理中状态
        s.isProcessingAI = true
        s.aiStyle = style
        session = s

        let sourceImage = s.baseImage   // 基于当前底图应用风格
        let (result, usedLocal) = await ai.applyStyle(style, intensity: 1.0, to: sourceImage)

        // 结果写回会话
        guard var final = session else { return }
        final.aiProcessedImage = style == "None" ? nil : result
        final.isProcessingAI = false
        final.isUsingLocalAI = usedLocal
        session = final
        AIService.shared.consumeAIUse(isPro: isPro)

        // 提示用户处理结果
        if usedLocal {
            showStatus("离线模式：已用本地算法处理（连上 AI 服务效果更佳）")
        } else {
            showStatus("AI 风格应用成功")
        }
    }

    // MARK: - 移除物体：切换模式
    func toggleRemoveObjectMode() {
        removeObjectMode.toggle()
        if !removeObjectMode { removalPoints = [] }
        showStatus(removeObjectMode ? "在图片上点选要移除的物体，点完按\"执行移除\"" : "已退出移除模式")
    }

    // MARK: - 添加/撤销移除点
    func addRemovalPoint(_ point: CGPoint) {
        removalPoints.append(point)
    }
    func undoRemovalPoint() {
        if !removalPoints.isEmpty { removalPoints.removeLast() }
    }

    // MARK: - 执行移除物体（异步真实调用 + 降级）
    func executeRemoveObjects(isPro: Bool) async {
        guard !removalPoints.isEmpty else { return }
        guard AIService.shared.canUseAI(isPro: isPro) else {
            showPaywall = true
            return
        }
        guard var s = session else { return }
        s.isProcessingAI = true
        session = s

        let sourceImage = s.baseImage
        let points = removalPoints
        let (result, usedLocal) = await ai.removeObjects(in: sourceImage, at: points, radius: 30)

        guard var final = session else { return }
        final.aiProcessedImage = result
        final.isProcessingAI = false
        final.isUsingLocalAI = usedLocal
        final.aiStyle = nil
        session = final
        removalPoints = []
        removeObjectMode = false
        AIService.shared.consumeAIUse(isPro: isPro)
        showStatus(usedLocal ? "离线模式：已用本地方式处理" : "物体移除成功")
    }

    // MARK: - 状态提示（3 秒后自动消失）
    func showStatus(_ message: String) {
        statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.statusMessage == message { self?.statusMessage = nil }
        }
    }

    // MARK: - 导出并保存
    func savePhoto(presetName: String?) -> UIImage? {
        guard let s = session else { return nil }
        let final = processor.process(s)
        PhotoLibraryService.shared.saveToApp(final, presetName: presetName)
        PhotoLibraryService.shared.saveToSystemPhotoLibrary(final) { success in
            print("保存到系统相册：\(success)")
        }
        return final
    }
}
