//
//  ImageProcessor.swift
//  图像处理引擎 —— 用 Core Image 实现滤镜、调整、美颜、导出
//
//  这是所有图片效果的"加工厂"：输入原图 + 一堆参数，输出成品图。
//  采用 KVC（setValue:forKey:）写法，兼容所有 iOS 版本，避免属性名差异导致编译失败。
//

import SwiftUI
import CoreImage
import UIKit

final class ImageProcessor {

    static let shared = ImageProcessor()
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - 应用滤镜
    /// 给图片套用一个滤镜预设，intensity 控制强度（0~1）
    func applyPreset(_ preset: FilterPreset, to image: UIImage, intensity: Double = 1.0) -> UIImage {
        guard !preset.ciFilterName.isEmpty,
              let ciImage = CIImage(image: image.fixedOrientation) else { return image }

        guard let filter = CIFilter(name: preset.ciFilterName) else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        // 只设置滤镜实际支持的键，避免 KVC 未定义键崩溃
        let validKeys = filter.inputKeys
        preset.parameters?.forEach { key, value in
            guard validKeys.contains(key) else { return }
            // CITemperatureAndTint 的 inputNeutral 需要 CIVector，若传入数组则转换
            if key == "inputNeutral", let pair = value as? [Int], pair.count >= 2 {
                filter.setValue(CIVector(x: CGFloat(pair[0]), y: CGFloat(pair[1])), forKey: key)
            } else {
                filter.setValue(value, forKey: key)
            }
        }
        guard let output = filter.outputImage else { return image }

        // 强度混合：按 intensity 缩放效果图 alpha，再叠回原图，实现"滑块调强度"
        let finalImage: CIImage
        if intensity < 1.0,
           let matrix = CIFilter(name: "CIColorMatrix"),
           let composite = CIFilter(name: "CISourceOverCompositing") {
            // 用 CIColorMatrix 把效果图的 alpha 乘以 intensity
            matrix.setValue(output, forKey: kCIInputImageKey)
            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity)), forKey: "inputAVector")
            let faded = matrix.outputImage ?? output
            // 用 source-over 把半透明效果图盖在原图上
            composite.setValue(faded, forKey: kCIInputImageKey)
            composite.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
            finalImage = composite.outputImage ?? output
        } else {
            finalImage = output
        }

        return render(ciImage: finalImage, originalSize: image.size)
    }

    // MARK: - 手动调整
    /// 应用亮度/对比度/饱和度/曝光等调整
    func applyAdjustments(_ adj: Adjustments, to image: UIImage) -> UIImage {
        guard var ciImage = CIImage(image: image.fixedOrientation) else { return image }

        // 曝光
        if adj.exposure != 0, let f = CIFilter(name: "CIExposureAdjust") {
            f.setValue(ciImage, forKey: kCIInputImageKey)
            f.setValue(adj.exposure, forKey: "inputEV")
            ciImage = f.outputImage ?? ciImage
        }
        // 亮度 / 对比度 / 饱和度
        if adj.brightness != 0 || adj.contrast != 0 || adj.saturation != 0,
           let f = CIFilter(name: "CIColorControls") {
            f.setValue(ciImage, forKey: kCIInputImageKey)
            f.setValue(adj.brightness, forKey: "inputBrightness")
            f.setValue(1 + adj.contrast, forKey: "inputContrast")
            f.setValue(1 + adj.saturation, forKey: "inputSaturation")
            ciImage = f.outputImage ?? ciImage
        }
        // 色温（用 CITemperatureAndTint 近似）
        if adj.warmth != 0, let f = CIFilter(name: "CITemperatureAndTint") {
            f.setValue(ciImage, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: CGFloat(adj.warmth * 3000), y: 0), forKey: "inputNeutral")
            ciImage = f.outputImage ?? ciImage
        }
        // 锐化
        if adj.sharpen > 0, let f = CIFilter(name: "CISharpenLuminance") {
            f.setValue(ciImage, forKey: kCIInputImageKey)
            f.setValue(adj.sharpen, forKey: "inputSharpness")
            ciImage = f.outputImage ?? ciImage
        }
        // 暗角
        if adj.vignette > 0, let f = CIFilter(name: "CIVignette") {
            f.setValue(ciImage, forKey: kCIInputImageKey)
            f.setValue(adj.vignette, forKey: "inputIntensity")
            f.setValue(1.5, forKey: "inputRadius")
            ciImage = f.outputImage ?? ciImage
        }

        return render(ciImage: ciImage, originalSize: image.size)
    }

    // MARK: - 一键美颜
    /// Beautify：磨皮 + 亮眼 + 光泽（示例实现，真实产品建议接 FaceUnity 等 SDK）
    func applyBeauty(_ beauty: BeautySettings, to image: UIImage) -> UIImage {
        guard var ciImage = CIImage(image: image.fixedOrientation) else { return image }

        // 磨皮：降噪 + 轻微模糊模拟
        if beauty.smoothSkin > 0 {
            if let noise = CIFilter(name: "CINoiseReduction") {
                noise.setValue(ciImage, forKey: kCIInputImageKey)
                noise.setValue(beauty.smoothSkin * 0.08, forKey: "inputNoiseLevel")
                noise.setValue(0.2, forKey: "inputSharpness")
                ciImage = noise.outputImage ?? ciImage
            }
            if let blur = CIFilter(name: "CIGaussianBlur") {
                blur.setValue(ciImage, forKey: kCIInputImageKey)
                blur.setValue(beauty.smoothSkin * 1.2, forKey: "inputRadius")
                ciImage = blur.outputImage ?? ciImage
            }
        }
        // 亮眼/光泽：提亮 + 饱和度微调，营造自然 glow
        if beauty.glow > 0 || beauty.brightEyes > 0, let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(ciImage, forKey: kCIInputImageKey)
            controls.setValue(beauty.glow * 0.06 + beauty.brightEyes * 0.02, forKey: "inputBrightness")
            controls.setValue(1 + beauty.glow * 0.08, forKey: "inputSaturation")
            ciImage = controls.outputImage ?? ciImage
        }

        return render(ciImage: ciImage, originalSize: image.size)
    }

    // MARK: - 完整处理管线
    /// 把一次编辑会话的所有效果按顺序叠加，输出最终图
    /// AI 风格是异步网络结果，已作为 aiProcessedImage 存入会话，这里从底图开始叠加同步效果
    func process(_ session: EditSession) -> UIImage {
        var result = session.baseImage

        if let preset = session.selectedPreset {    // 1. 滤镜预设
            result = applyPreset(preset, to: result, intensity: session.filterIntensity)
        }
        if !session.adjustments.isDefault {         // 2. 手动调整
            result = applyAdjustments(session.adjustments, to: result)
        }
        if session.beauty != .default {             // 3. 美颜
            result = applyBeauty(session.beauty, to: result)
        }
        return result.fixedOrientation
    }

    // MARK: - 渲染工具
    private func render(ciImage: CIImage, originalSize: CGSize) -> UIImage {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - 导出高清图
    func exportHighRes(_ image: UIImage, quality: CGFloat = 0.95) -> Data? {
        image.jpegData(compressionQuality: quality)
    }
}
