//
//  PresetData.swift
//  55 个滤镜预设数据 —— 对应 Clicked 的标志性滤镜（全中文名称）
//
//  说明：这里用 Core Image 系统内置滤镜做近似效果。真实商业产品可换成 .cube LUT 文件
//  （在 docs/06-第三方SDK接入指南.md 里有说明）。
//

import Foundation

enum PresetData {
    /// 所有预设（55 个，覆盖 5 大类）
    static let all: [FilterPreset] = [
        // ===== 胶片 =====
        .init(name: "富士鲜艳", category: .film, intensity: 0.75, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.5]),
        .init(name: "柯达金", category: .film, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [1300, 0]]),
        .init(name: "柔和人像", category: .film, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.85]),
        .init(name: "电影胶片", category: .film, intensity: 0.8, ciFilterName: "CIColorControls", parameters: ["inputContrast": 1.2]),
        .init(name: "闪光灯", category: .film, intensity: 0.9, ciFilterName: "CIExposureAdjust", parameters: ["inputEV": 0.6]),
        .init(name: "35毫米", category: .film, intensity: 0.65, ciFilterName: "CIGammaAdjust", parameters: ["inputPower": 0.8]),
        .init(name: "超级胶片", category: .film, intensity: 0.7, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.4]),
        .init(name: "浓郁反转", category: .film, intensity: 0.85, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 1.4]),
        .init(name: "黑白胶卷", category: .film, intensity: 1.0, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.0]),
        .init(name: "胶片颗粒", category: .film, intensity: 0.5, ciFilterName: "CINoiseReduction", parameters: ["inputNoiseLevel": 0.1]),
        .init(name: "拍立得", category: .film, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [800, 10]]),
        .init(name: "埃克塔", category: .film, intensity: 0.75, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.6]),

        // ===== 暖调 =====
        .init(name: "摩卡", category: .warm, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [1500, 8]]),
        .init(name: "黄金时刻", category: .warm, intensity: 0.8, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [2500, 0]]),
        .init(name: "蜜糖", category: .warm, intensity: 0.65, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 1.15]),
        .init(name: "日落", category: .warm, intensity: 0.75, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [3000, -5]]),
        .init(name: "沉稳", category: .warm, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputContrast": 1.1]),
        .init(name: "琥珀", category: .warm, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [1800, 5]]),
        .init(name: "蜜桃", category: .warm, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 1.1]),
        .init(name: "柔和奢华", category: .warm, intensity: 0.5, ciFilterName: "CIGammaAdjust", parameters: ["inputPower": 0.9]),
        .init(name: "驼色", category: .warm, intensity: 0.65, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [1200, 12]]),
        .init(name: "奶油", category: .warm, intensity: 0.55, ciFilterName: "CIExposureAdjust", parameters: ["inputEV": 0.3]),
        .init(name: "陶土", category: .warm, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [2000, 15]]),

        // ===== 情绪 =====
        .init(name: "单色", category: .moody, intensity: 1.0, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.0]),
        .init(name: "黑白经典", category: .moody, intensity: 1.0, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.0, "inputContrast": 1.5]),
        .init(name: "蓝调时刻", category: .moody, intensity: 0.75, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [-2000, 0]]),
        .init(name: "雾蒙蒙", category: .moody, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputContrast": 0.8]),
        .init(name: "戏剧感", category: .moody, intensity: 0.85, ciFilterName: "CIColorControls", parameters: ["inputContrast": 1.6, "inputBrightness": -0.05]),
        .init(name: "青橙电影", category: .moody, intensity: 0.8, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.7]),
        .init(name: "午夜", category: .moody, intensity: 0.8, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [-1500, -8]]),
        .init(name: "褪色", category: .moody, intensity: 0.5, ciFilterName: "CIColorControls", parameters: ["inputContrast": 0.75, "inputSaturation": 0.8]),
        .init(name: "阴影", category: .moody, intensity: 0.7, ciFilterName: "CIExposureAdjust", parameters: ["inputEV": -0.4]),
        .init(name: "风暴", category: .moody, intensity: 0.8, ciFilterName: "CIGammaAdjust", parameters: ["inputPower": 0.7]),
        .init(name: "深绿", category: .moody, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [-800, -10]]),

        // ===== 干净 =====
        .init(name: "原图", category: .clean, intensity: 0, ciFilterName: "", parameters: nil),
        .init(name: "清透", category: .clean, intensity: 0.6, ciFilterName: "CISharpenLuminance", parameters: ["inputSharpness": 0.4]),
        .init(name: "自然", category: .clean, intensity: 0.5, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.2]),
        .init(name: "明亮", category: .clean, intensity: 0.7, ciFilterName: "CIExposureAdjust", parameters: ["inputEV": 0.5]),
        .init(name: "轻盈", category: .clean, intensity: 0.5, ciFilterName: "CIColorControls", parameters: ["inputBrightness": 0.08]),
        .init(name: "瓷白", category: .clean, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.9, "inputBrightness": 0.05]),
        .init(name: "清新", category: .clean, intensity: 0.55, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.3]),
        .init(name: "白洗", category: .clean, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputContrast": 0.9, "inputBrightness": 0.1]),
        .init(name: "冷白", category: .clean, intensity: 0.5, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [-500, 0]]),
        .init(name: "丝滑", category: .clean, intensity: 0.5, ciFilterName: "CIGammaAdjust", parameters: ["inputPower": 1.1]),
        .init(name: "纯净", category: .clean, intensity: 0.7, ciFilterName: "CINoiseReduction", parameters: ["inputNoiseLevel": 0.05]),
        .init(name: "日光", category: .clean, intensity: 0.6, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [600, 0]]),

        // ===== 复古 =====
        .init(name: "录像带", category: .retro, intensity: 0.8, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 1.2, "inputContrast": 1.1]),
        .init(name: "千禧风", category: .retro, intensity: 0.85, ciFilterName: "CIVibrance", parameters: ["inputAmount": 0.8]),
        .init(name: "九十年代", category: .retro, intensity: 0.75, ciFilterName: "CIColorControls", parameters: ["inputSaturation": 0.9]),
        .init(name: "怀旧棕", category: .retro, intensity: 1.0, ciFilterName: "CISepiaTone", parameters: ["inputIntensity": 0.8]),
        .init(name: "复古", category: .retro, intensity: 0.7, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [1000, 10]]),
        .init(name: "灰尘感", category: .retro, intensity: 0.6, ciFilterName: "CIColorControls", parameters: ["inputContrast": 0.85, "inputSaturation": 0.85]),
        .init(name: "老胶片", category: .retro, intensity: 0.8, ciFilterName: "CIGammaAdjust", parameters: ["inputPower": 0.75]),
        .init(name: "褪色玫瑰", category: .retro, intensity: 0.65, ciFilterName: "CITemperatureAndTint", parameters: ["inputNeutral": [700, -5]]),
        .init(name: "摇滚", category: .retro, intensity: 0.9, ciFilterName: "CIColorControls", parameters: ["inputContrast": 1.3, "inputSaturation": 0.7]),
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
