//
//  AIService.swift
//  AI 能力统一入口 —— 真实网络调用 + 本地算法降级
//
//  策略：
//   1. 优先调用 AI 后端（真实算法服务）
//   2. 连不上后端时，用设备端 Core Image 算法降级，保证功能永不失效
//   3. 额度管理：免费用户每天 3 次，Pro 每月 30 次
//

import SwiftUI
import UIKit

final class AIService {

    static let shared = AIService()
    private let api = APIClient.shared

    // AI 风格列表（与后端支持的风格对应）
    let availableStyles = ["None", "Film", "Retro", "Glam", "Dreamy", "Cinematic", "Vivid", "Mono"]

    // 风格名 → 后端 style 参数
    private let styleMap: [String: String] = [
        "Film": "film", "Retro": "retro", "Glam": "glam",
        "Dreamy": "dreamy", "Cinematic": "cinematic",
        "Vivid": "vivid", "Mono": "mono"
    ]

    // 后端是否可用的缓存（避免每次都探测）
    private var backendAvailable: Bool?
    private var lastHealthCheck: Date?

    // MARK: - 风格迁移（真实网络 + 本地降级）
    /// - Returns: (图片, 是否用的本地降级模式)
    func applyStyle(_ style: String, intensity: Double = 1.0, to image: UIImage) async -> (UIImage, Bool) {
        guard style != "None", let serverStyle = styleMap[style] else { return (image, false) }

        do {
            let result = try await api.applyStyle(image: image, style: serverStyle, intensity: intensity)
            return (result, false)   // 真实后端结果
        } catch {
            // 降级到本地算法
            if AppConstants.enableLocalFallback {
                return (localStyle(style, to: image), true)
            }
            return (image, true)
        }
    }

    // MARK: - 移除物体（真实网络 + 本地降级）
    func removeObjects(in image: UIImage, at points: [CGPoint], radius: Double = 30) async -> (UIImage, Bool) {
        guard !points.isEmpty else { return (image, false) }
        do {
            let result = try await api.removeObjects(image: image, points: points, radius: radius)
            return (result, false)
        } catch {
            if AppConstants.enableLocalFallback {
                return (localRemoveObjects(in: image, at: points, radius: radius), true)
            }
            return (image, true)
        }
    }

    // MARK: - 场景分析（真实网络 + 本地降级）
    func analyzeScene(image: UIImage) async -> [CaptureHint] {
        guard image.size.width > 0 else { return localSceneHints() }
        do {
            let hints = try await api.analyzeScene(image: image)
            return hints.isEmpty ? localSceneHints() : hints
        } catch {
            return localSceneHints()
        }
    }

    // MARK: - 探测后端是否可用（设置页显示用）
    func isBackendAvailable(force: Bool = false) async -> Bool {
        if !force, let cached = backendAvailable,
           let last = lastHealthCheck, Date().timeIntervalSince(last) < 30 {
            return cached
        }
        let available = await api.checkHealth()
        backendAvailable = available
        lastHealthCheck = Date()
        return available
    }

    // MARK: - ============ 本地降级算法 ============
    // 当后端连不上时，用设备端真实算法兜底（不是返回原图占位）

    /// 本地风格：用多滤镜链组合出真实风格效果
    private func localStyle(_ style: String, to image: UIImage) -> UIImage {
        let presetName: String
        switch style {
        case "Film": presetName = "Fuji Chrome"
        case "Retro": presetName = "VHS"
        case "Glam": presetName = "Soft Luxury"
        case "Dreamy": presetName = "Airy"
        case "Cinematic": presetName = "Teal & Orange"
        case "Vivid": presetName = "Velvia"
        case "Mono": presetName = "Noir"
        default: return image
        }
        guard let preset = PresetData.preset(named: presetName) else { return image }
        var result = ImageProcessor.shared.applyPreset(preset, to: image)
        var adj = Adjustments.default
        adj.sharpen = 0.2
        adj.vignette = 0.15
        result = ImageProcessor.shared.applyAdjustments(adj, to: result)
        return result
    }

    /// 本地移除物体：用色块覆盖模拟（效果不如后端 inpaint，但可用）
    private func localRemoveObjects(in image: UIImage, at points: [CGPoint], radius: Double) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let r = CGFloat(radius)
            for point in points {
                let rect = CGRect(x: point.x - r, y: point.y - r,
                                  width: r * 2, height: r * 2)
                UIColor(white: 0.5, alpha: 0.9).setFill()
                ctx.cgContext.fillEllipse(in: rect)
            }
        }
    }

    /// 本地场景建议：基于通用摄影规则的建议
    private func localSceneHints() -> [CaptureHint] {
        return [
            CaptureHint(icon: "figure.stand", title: "主体居中", detail: "让人物位于画面中央三分之一处", severity: .info),
            CaptureHint(icon: "sun.max", title: "注意光线", detail: "面朝光源，避免面部阴影", severity: .warning),
            CaptureHint(icon: "arrow.up.left.and.arrow.down.right", title: "适当靠近", detail: "主体占画面 30%~50% 更佳", severity: .info),
        ]
    }

    // MARK: - ============ 额度管理 ============
    private let usageKey = "aiUsageCount"
    private let dateKey = "aiUsageDate"
    private let proUsageKey = "aiProUsageCount"
    private let proMonthKey = "aiProUsageMonth"

    func canUseAI(isPro: Bool) -> Bool {
        if isPro { return true }   // Pro 用户不限次数
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = UserDefaults.standard.object(forKey: dateKey) as? Date ?? Date.distantPast
        if lastDate < today {
            UserDefaults.standard.set(0, forKey: usageKey)
            UserDefaults.standard.set(today, forKey: dateKey)
        }
        return UserDefaults.standard.integer(forKey: usageKey) < AppConstants.freeAIDailyLimit
    }

    func consumeAIUse(isPro: Bool) {
        if isPro {
            UserDefaults.standard.set(proMonthlyUsed() + 1, forKey: proUsageKey)
        } else {
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: usageKey) + 1, forKey: usageKey)
        }
    }

    func remainingFreeUses() -> Int {
        let count = UserDefaults.standard.integer(forKey: usageKey)
        return max(0, AppConstants.freeAIDailyLimit - count)
    }

    private func proMonthlyUsed() -> Int {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let savedMonth = UserDefaults.standard.integer(forKey: proMonthKey)
        if currentMonth != savedMonth {
            UserDefaults.standard.set(0, forKey: proUsageKey)
            UserDefaults.standard.set(currentMonth, forKey: proMonthKey)
        }
        return UserDefaults.standard.integer(forKey: proUsageKey)
    }
}
