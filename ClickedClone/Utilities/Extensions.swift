//
//  Extensions.swift
//  通用扩展 —— 给系统类型加便捷方法
//

import SwiftUI
import UIKit

// MARK: - UIColor 转 SwiftUI Color
extension UIColor {
    var swiftUIColor: Color { Color(self) }
}

// MARK: - UIImage 便捷方法
extension UIImage {
    /// 按比例缩放到指定最大边长（导出高清图时避免过大内存）
    func resized(toMax maxSide: CGFloat) -> UIImage {
        let ratio = min(maxSide / size.width, maxSide / size.height)
        if ratio >= 1 { return self }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// 固定方向（拍照后有时方向是 0，需要修正再处理）
    var fixedOrientation: UIImage {
        if imageOrientation == .up { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}

// MARK: - 视图修饰符
extension View {
    /// 毛玻璃卡片背景
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    /// 品牌渐变按钮样式
    func brandButton() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppConstants.brandGradient)
            .cornerRadius(30)
    }

    /// 轻点击反馈
    func hapticTap() -> some View {
        self.onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
}

// MARK: - Date 格式化
extension Date {
    var displayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }
}
