//
//  Models.swift
//  数据模型 —— 定义 App 里所有的数据结构
//

import Foundation
import SwiftUI
import UIKit

// MARK: - 滤镜预设
/// 一个滤镜预设（对应 Clicked 里的 Mocha / Fuji Chrome 等）
struct FilterPreset: Identifiable, Hashable {
    let id = UUID()
    let name: String           // 显示名称，如 "Mocha"
    let category: FilterCategory
    let intensity: Double       // 默认强度 0~1
    let ciFilterName: String    // Core Image 滤镜名（系统内置）
    let parameters: [String: Any]?  // 滤镜参数

    // Hashable 需要手动实现（因为 parameters 是字典）
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: FilterPreset, rhs: FilterPreset) -> Bool { lhs.id == rhs.id }

    enum FilterCategory: String, CaseIterable, Identifiable {
        case all = "全部"
        case film = "胶片"
        case warm = "暖调"
        case moody = "情绪"
        case clean = "干净"
        case retro = "复古"
        var id: String { rawValue }
    }
}

// MARK: - 调整参数
/// 图片手动调整的所有参数
struct Adjustments: Equatable {
    var brightness: Double = 0     // 亮度 -1~1
    var contrast: Double = 0       // 对比度 -1~1
    var saturation: Double = 0     // 饱和度 -1~1
    var exposure: Double = 0       // 曝光 -1~1
    var warmth: Double = 0         // 色温 -1~1
    var vignette: Double = 0       // 暗角 0~1
    var sharpen: Double = 0        // 锐化 0~1

    static let `default` = Adjustments()

    // 判断是否有调整（用于"重置"按钮）
    var isDefault: Bool { self == .default }
}

// MARK: - 美颜参数
/// Beautify 一键美颜的参数
struct BeautySettings: Equatable {
    var smoothSkin: Double = 0.5   // 磨皮 0~1
    var brightEyes: Double = 0.3   // 亮眼 0~1
    var glow: Double = 0.3         // 光泽 0~1

    static let `default` = BeautySettings()
}

// MARK: - 编辑会话
/// 记录一张照片当前的所有编辑状态
struct EditSession {
    let originalImage: UIImage
    // AI 处理后的底图（异步网络结果）；nil 表示未应用 AI，process 从 originalImage 开始
    var aiProcessedImage: UIImage?
    var selectedPreset: FilterPreset?
    var filterIntensity: Double = 1.0
    var adjustments = Adjustments()
    var beauty = BeautySettings()
    var aiStyle: String?           // 当前 AI 风格名（用于 UI 高亮）
    var isUsingLocalAI = false     // 是否处于本地降级模式（提示用户）
    var isProcessingAI = false     // AI 处理中（显示 loading）

    // 当前作为滤镜/调整输入的底图
    var baseImage: UIImage { aiProcessedImage ?? originalImage }

    var hasEdits: Bool {
        selectedPreset != nil || !adjustments.isDefault || aiStyle != nil || beauty != .default
    }
}

// MARK: - 作品（相册里的照片）
/// 保存到本地的作品记录
struct SavedPhoto: Identifiable, Codable {
    let id: UUID
    let fileName: String       // 存在 App 沙盒里的文件名
    let createdAt: Date
    let presetName: String?

    init(id: UUID = UUID(), fileName: String, createdAt: Date = Date(), presetName: String? = nil) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.presetName = presetName
    }
}

// MARK: - 拍摄引导提示（PicScan 用）
/// AI 场景分析给出的建议
struct CaptureHint: Identifiable {
    let id = UUID()
    let icon: String       // SF Symbol 名
    let title: String      // "走近一点"
    let detail: String     // "让主体占据更多画面"
    let severity: HintSeverity

    enum HintSeverity: Equatable { case info, warning, good }
}

// MARK: - 订阅方案
struct SubscriptionPlan: Identifiable {
    let id: String         // App Store 产品 ID
    let title: String      // "年度 Pro"
    let price: String      // "¥198/年"
    let unitPrice: String  // "约 ¥16.5/月"
    let badge: String?     // "最划算"
    let productID: String  // 与 id 相同，方便 StoreKit 使用
}

// MARK: - ============ AI 后端通信模型 ============

// 风格迁移请求
struct StyleTransferRequest: Codable {
    let image: String      // base64 图片（不含 data:image 前缀）
    let style: String      // 风格名，如 "film" / "retro"
    let intensity: Double  // 强度 0~1
}

// 风格迁移响应
struct StyleTransferResponse: Codable {
    let image: String      // base64 结果图
    let style: String
    let processingTime: Double?

    enum CodingKeys: String, CodingKey {
        case image, style
        case processingTime = "processing_time"
    }
}

// 移除物体请求
struct RemoveObjectRequest: Codable {
    let image: String
    let points: [CGPointCodable]   // 用户点选的坐标（像素）
    let radius: Double             // 每点的笔刷半径（像素）
}

// 坐标（Codable 版，CGPoint 不遵循 Codable）
struct CGPointCodable: Codable, Hashable {
    let x: Double
    let y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

// 通用图片处理响应（移除物体等返回单张图）
struct ImageProcessResponse: Codable {
    let image: String
    let processingTime: Double?
    enum CodingKeys: String, CodingKey {
        case image
        case processingTime = "processing_time"
    }
}

// 场景分析请求
struct SceneAnalysisRequest: Codable {
    let image: String
}

// 场景分析响应
struct SceneAnalysisResponse: Codable {
    let hints: [SceneHintCodable]
    let qualityScore: Double?
    enum CodingKeys: String, CodingKey {
        case hints
        case qualityScore = "quality_score"
    }
}

// 服务端返回的单条场景建议
struct SceneHintCodable: Codable {
    let icon: String
    let title: String
    let detail: String
    let severity: String    // "info" / "warning" / "good"

    // 转成 UI 里的 CaptureHint
    func toCaptureHint() -> CaptureHint {
        let level: CaptureHint.HintSeverity
        switch severity {
        case "warning": level = .warning
        case "good": level = .good
        default: level = .info
        }
        return CaptureHint(icon: icon, title: title, detail: detail, severity: level)
    }
}

// 后端健康检查响应
struct HealthResponse: Codable {
    let status: String
    let version: String?
}

// MARK: - API 错误类型
enum APIError: LocalizedError {
    case invalidURL
    case noData
    case httpStatus(Int)
    case decodingFailed(String)
    case serverMessage(String)
    case offline
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "服务地址无效，请检查配置"
        case .noData: return "服务器没有返回数据"
        case .httpStatus(let code): return "服务器错误（\(code)）"
        case .decodingFailed(let msg): return "数据解析失败：\(msg)"
        case .serverMessage(let msg): return msg
        case .offline: return "无法连接 AI 服务，已切换到本地模式"
        case .timeout: return "请求超时，请重试"
        }
    }
}
