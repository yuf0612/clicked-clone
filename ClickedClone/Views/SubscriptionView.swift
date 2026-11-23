//
//  SubscriptionView.swift
//  会员说明页 —— 本版本为【全功能免费解锁版】
//
//  所有功能已对所有用户开放，此页面仅作说明，不含任何购买入口。
//

import SwiftUI

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(AppConstants.brandGradient)
                            Text("全部功能已免费解锁")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                            Text("无需订阅、无需付费，所有功能敞开使用")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 30)

                        VStack(alignment: .leading, spacing: 12) {
                            BenefitRow(icon: "camera.fill", text: "无限次智能引导拍摄")
                            BenefitRow(icon: "square.grid.3x3.fill", text: "全部滤镜与预设")
                            BenefitRow(icon: "sparkles", text: "无限次 Beautify 美颜")
                            BenefitRow(icon: "wand.and.stars", text: "无限次 AI 风格与物体移除")
                            BenefitRow(icon: "square.and.arrow.up", text: "高清无水印导出")
                        }
                        .padding()
                        .background(Color(white: 0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        Text("尽情使用，没有次数限制，也不会有任何收费。")
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundColor(.white)
                }
            }
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.yellow).frame(width: 24)
            Text(text).foregroundColor(.white).font(.system(size: 14))
        }
    }
}
