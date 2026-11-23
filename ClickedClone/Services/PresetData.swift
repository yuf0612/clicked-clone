//
//  PresetData.swift
//  50+ 滤镜预设数据 —— 对应 Clicked 的 Signature Filters
//
//  说明：这里用 Core Image 系统内置滤镜做近似效果。真实商业产品可换成 .cube LUT 文件
//  （在 docs/06-第三方SDK接入指南.md 里有说明）。
//

import Foundation

enum PresetData {
    /// 所有预设（55 个，覆盖 5 大类）
    static let all: [FilterPreset] = [
        // ===== 胶片 Film =====
        .init(name: "Fuji Chrome", category: .film, intensity: 0.75, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.5]),
        .init(name: "Kodak Gold", category: .film, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [1300, 0]]),
        .init(name: "Portra 400", category: .film, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.85]),
        .init(name: "CineStill", category: .film, intensity: 0.8, ciFilterName: "CIColorControls", parameters: ["inputContrast": 1.2]),
        .init(name: "Disposable Flash", category: .film, intensity: 0.9, ciFilterName: "CIExposureAdjust", parameters: ["inputEV": 0.6]),
        .init(name: "35mm", category: .film, intensity: 0.65, ciFilterName: "CIGammaAdjust", parameters: ["inputPower": 0.8]),
        .init(name: "Superia", category: .film, intensity: 0.7, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.4]),
        .init(name: "Velvia", category: .film, intensity: 0.85, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 1.4]),
        .init(name: "Tri-X BW", category: .film, intensity: 1.0, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.0]),
        .init(name: "Film Grain", category: .film, intensity: 0.5, ciFilterName: "CINoiseReduction", parameters: ["inputNoiseLevel": 0.1]),
        .init(name: "Polaroid", category: .film, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [800, 10]]),
        .init(name: "Ektar", category: .film, intensity: 0.75, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.6]),

        // ===== 暖调 Warm =====
        .init(name: "Mocha", category: .warm, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [1500, 8]]),
        .init(name: "Golden Hour", category: .warm, intensity: 0.8, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [2500, 0]]),
        .init(name: "Honey", category: .warm, intensity: 0.65, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 1.15]),
        .init(name: "Sunset", category: .warm, intensity: 0.75, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [3000, -5]]),
        .init(name: "Grounded", category: .warm, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputContrast": 1.1]),
        .init(name: "Amber", category: .warm, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [1800, 5]]),
        .init(name: "Peach", category: .warm, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 1.1]),
        .init(name: "Soft Luxury", category: .warm, intensity: 0.5, ciFilterName: "CIGammaAdjust", parameters: ["inputPower": 0.9]),
        .init(name: "Camel", category: .warm, intensity: 0.65, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [1200, 12]]),
        .init(name: "Butter", category: .warm, intensity: 0.55, ciFilterName: "CIExposureAdjust", parameters: ["inputEV": 0.3]),
        .init(name: "Terracotta", category: .warm, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [2000, 15]]),

        // ===== 情绪 Moody =====
        .init(name: "Monochrome", category: .moody, intensity: 1.0, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.0]),
        .init(name: "Noir", category: .moody, intensity: 1.0, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.0, "inputContrast": 1.5]),
        .init(name: "Blue Hour", category: .moody, intensity: 0.75, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [-2000, 0]]),
        .init(name: "Foggy", category: .moody, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputContrast": 0.8]),
        .init(name: "Dramatic", category: .moody, intensity: 0.85, ciFilterName: "CIColorControls", parameters: ["inputContrast": 1.6, "inputBrightness": -0.05]),
        .init(name: "Teal & Orange", category: .moody, intensity: 0.8, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.7]),
        .init(name: "Midnight", category: .moody, intensity: 0.8, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [-1500, -8]]),
        .init(name: "Faded", category: .moody, intensity: 0.5, ciFilterName: "CIColorControls", parameters: ["inputContrast": 0.75, "inputSaturation": 0.8]),
        .init(name: "Shadow", category: .moody, intensity: 0.7, ciFilterName: "CIExposureAdjust", parameters: ["inputEV": -0.4]),
        .init(name: "Storm", category: .moody, intensity: 0.8, ciFilterName: "CIGammaAdjust", parameters: ["inputPower": 0.7]),
        .init(name: "Deep Green", category: .moody, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [-800, -10]]),

        // ===== 干净 Clean =====
        .init(name: "Original", category: .clean, intensity: 0, ciFilterName: "", parameters: nil),
        .init(name: "Crisp", category: .clean, intensity: 0.6, ciFilterName: "CISharpenLuminance", parameters: ["inputSharpness": 0.4]),
        .init(name: "Natural", category: .clean, intensity: 0.5, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.2]),
        .init(name: "Bright", category: .clean, intensity: 0.7, ciFilterName: "CIExposureAdjust", parameters: ["inputEV": 0.5]),
        .init(name: "Airy", category: .clean, intensity: 0.5, ciFilterName: "CIColorControls", parameters: ["inputBrightness": 0.08]),
        .init(name: "Porcelain", category: .clean, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.9, "inputBrightness": 0.05]),
        .init(name: "Fresh", category: .clean, intensity: 0.55, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.3]),
        .init(name: "White Wash", category: .clean, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputContrast": 0.9, "inputBrightness": 0.1]),
        .init(name: "Clinical", category: .clean, intensity: 0.5, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [-500, 0]]),
        .init(name: "Silk", category: .clean, intensity: 0.5, ciFilterName: "CIGammaAdjust", parameters: ["inputPower": 1.1]),
        .init(name: "Pure", category: .clean, intensity: 0.7, ciFilterName: "CINoiseReduction", parameters: ["inputNoiseLevel": 0.05]),
        .init(name: "Daylight", category: .clean, intensity: 0.6, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [600, 0]]),

        // ===== 复古 Retro =====
        .init(name: "VHS", category: .retro, intensity: 0.8, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 1.2, "inputContrast": 1.1]),
        .init(name: "Y2K", category: .retro, intensity: 0.85, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.8]),
        .init(name: "90s", category: .retro, intensity: 0.75, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.9]),
        .init(name: "Sepia", category: .retro, intensity: 1.0, ciFilterName: "CISepiaTone", parameters: ["inputIntensity": 0.8]),
        .init(name: "Vintage", category: .retro, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [1000, 10]]),
        .init(name: "Dusty", category: .retro, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputContrast": 0.85, "inputSaturation": 0.85]),
        .init(name: "Old Film", category: .retro, intensity: 0.8, ciFilterName: "CIGammaAdjust", parameters: ["inputPower": 0.75]),
        .init(name: "Faded Rose", category: .retro, intensity: 0.65, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [700, -5]]),
        .init(name: "Grunge", category: .retro, intensity: 0.9, ciFilterName: "CIColorControls", parameters: ["inputContrast": 1.3, "inputSaturation": 0.7]),
    ]

    /// 按分类筛选
    static func presets(in category: FilterPreset.FilterCategory) -> [FilterPreset] {
        category == .all ? all : all.filter { $0.category == category }
    }

    /// 根据名称找预设
    static func preset(named name: String) -> FilterPreset? {
        all.first { $0.name == name }
    }
}
