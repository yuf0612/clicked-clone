//
//  AIService.swift
//  AI 能力统一入口 —— 真实网络调用 + 本地算法降级
//
//  策略：
//   1. 优先调用 AI 后端（真实算法服务）
//   2. 连不上后端时，用设备端 Core Image 算法降级，保证功能永不失效
//   3. 额度管理：全功能免费解锁版，AI 功能无限次使用
//

import SwiftUI
import UIKit

final class AIService {

    static let shared = AIService()
    private let api = APIClient.shared

    // AI 风格列表（中文显示名，与后端支持的风格一一对应）
    let availableStyles = ["原图", "胶片", "复古", "美颜", "梦幻", "电影", "鲜艳", "黑白"]
    static let noneStyle = "原图"

    // 中文显示名 → 内部英文 key（用于本地预设查询）
    private let displayToKey: [String: String] = [
        "胶片": "Film", "复古": "Retro", "美颜": "Glam",
        "梦幻": "Dreamy", "电影": "Cinematic",
        "鲜艳": "Vivid", "黑白": "Mono"
    ]

    // 内部英文 key → 后端 style 参数
    private let styleMap: [String: String] = [
        "Film": "film", "Retro": "retro", "Glam": "glam",
        "Dreamy": "dreamy", "Cinematic": "cinematic",
        "Vivid": "vivid", "Mono": "mono"
    ]

    /// 把内部风格 key 转成中文显示名（供会话高亮比较用）
    func displayName(forKey key: String) -> String {
        displayToKey.first { $0.value == key }?.key ?? key
    }

    // 后端是否可用的缓存（避免每次都探测）
    private var backendAvailable: Bool?
    private var lastHealthCheck: Date?

    /// 已知后端不可用时，60 秒内直接走本地，避免每次操作都等超时
    private func isBackendKnownUnavailable() -> Bool {
        guard let available = backendAvailable, !available,
              let last = lastHealthCheck,
              Date().timeIntervalSince(last) < 60 else { return false }
        return true
    }

    private func markBackendUnavailable() {
        backendAvailable = false
        lastHealthCheck = Date()
    }

    // MARK: - 风格迁移（真实网络 + 本地降级）
    /// - Returns: (图片, 是否用的本地降级模式)
    func applyStyle(_ displayName: String, intensity: Double = 1.0, to image: UIImage) async -> (UIImage, Bool) {
        guard displayName != AIService.noneStyle,
              let key = displayToKey[displayName],
              let serverStyle = styleMap[key] else { return (image, false) }

        if !AppConstants.enableLocalFallback || isBackendKnownUnavailable() {
            return AppConstants.enableLocalFallback ? (localStyle(key, to: image), true) : (image, true)
        }
        do {
            let result = try await api.applyStyle(image: image, style: serverStyle, intensity: intensity)
            backendAvailable = true
            return (result, false)   // 真实后端结果
        } catch {
            markBackendUnavailable()
            if AppConstants.enableLocalFallback {
                return (localStyle(key, to: image), true)
            }
            return (image, true)
        }
    }

    // MARK: - 移除物体（真实网络 + 本地降级）
    func removeObjects(in image: UIImage, at points: [CGPoint], radius: Double = 30) async -> (UIImage, Bool) {
        guard !points.isEmpty else { return (image, false) }
        if !AppConstants.enableLocalFallback || isBackendKnownUnavailable() {
            return AppConstants.enableLocalFallback ? (localRemoveObjects(in: image, at: points, radius: radius), true) : (image, true)
        }
        do {
            let result = try await api.removeObjects(image: image, points: points, radius: radius)
            backendAvailable = true
            return (result, false)
        } catch {
            markBackendUnavailable()
            if AppConstants.enableLocalFallback {
                return (localRemoveObjects(in: image, at: points, radius: radius), true)
            }
            return (image, true)
        }
    }

    // MARK: - 场景分析（真实网络 + 本地降级）
    func analyzeScene(image: UIImage) async -> [CaptureHint] {
        guard image.size.width > 0 else { return localSceneHints() }
        if isBackendKnownUnavailable() { return localSceneHints() }
        do {
            let hints = try await api.analyzeScene(image: image)
            backendAvailable = true
            return hints.isEmpty ? localSceneHints() : hints
        } catch {
            markBackendUnavailable()
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
        case "Film": presetName = "富士鲜艳"
        case "Retro": presetName = "录像带"
        case "Glam": presetName = "柔和奢华"
        case "Dreamy": presetName = "轻盈"
        case "Cinematic": presetName = "青橙电影"
        case "Vivid": presetName = "浓郁反转"
        case "Mono": presetName = "黑白经典"
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

    /// 本地场景修复：内容感知填充（无后端时用设备端算法剔除物体、自动修复背景）
    ///
    /// 原理：把用户点选位置画成圆形蒙版，对整图做大半径高斯模糊得到"周围场景颜色场"，
    /// 再用 CIBlendWithMask 只把蒙版区域替换为模糊后的周围像素，实现物体被抹除、
    /// 背景由四周纹理自然填充的效果。连上后端时会改用更精确的 OpenCV Telea inpaint。
    private func localRemoveObjects(in image: UIImage, at points: [CGPoint], radius: Double) -> UIImage {
        guard let ciSource = CIImage(image: image.fixedOrientation) else { return image }
        let extent = ciSource.extent
        let imgW = extent.width, imgH = extent.height
        let scaleX = imgW / image.size.width
        let scaleY = imgH / image.size.height
        let r = CGFloat(radius) * min(scaleX, scaleY) * 1.15   // 略放大，覆盖物体边缘

        // 1) 画蒙版：黑底 + 白色实心圆（Core Image 坐标系原点在左下，需翻转 y）
        let maskRenderer = UIGraphicsImageRenderer(size: CGSize(width: imgW, height: imgH))
        let maskUIImage = maskRenderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: imgW, height: imgH))
            UIColor.white.setFill()
            for p in points {
                let cx = p.x * scaleX
                let cy = imgH - p.y * scaleY     // UIKit y 向下 → CI y 向上
                ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            }
        }
        guard let mask = CIImage(image: maskUIImage) else { return image }

        // 2) 周围场景颜色场：大半径模糊（半径约为标记半径的 2.2 倍，保证纹理来自物体四周）
        let blurRadius = max(18, r * 2.2)
        let blurred = ciSource.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])
            .cropped(to: extent)

        // 3) 蒙版区域用模糊场填充，其余保留原图；再做一次羽化过渡让边界自然
        let softMask = mask.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(2, r * 0.18)])
        let filled = blurred.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputImageKey: blurred,
            kCIInputBackgroundImageKey: ciSource,
            kCIInputMaskImageKey: softMask
        ])

        // 4) 渲染输出
        let context = CIContext(options: nil)
        guard let cg = context.createCGImage(filled, from: extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
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

    // 全功能免费解锁：AI 永远可用，无次数限制
    func canUseAI(isPro: Bool) -> Bool { true }

    func consumeAIUse(isPro: Bool) {
        // 无需计数，保留方法仅为兼容调用签名
    }

    func remainingFreeUses() -> Int { Int.max }

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
