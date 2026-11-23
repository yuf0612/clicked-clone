//
//  SubscriptionView.swift
//  订阅付费墙 —— 展示方案、购买、恢复
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject var subscription: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    @State private var purchasing: String?

    // 展示用的方案（价格从 StoreKit 产品信息读取，这里给默认值兜底）
    private let planInfo = [
        (id: AppConstants.productWeekly, title: "每周", defaultPrice: "¥12/周", unit: "", badge: nil),
        (id: AppConstants.productMonthly, title: "每月", defaultPrice: "¥48/月", unit: "", badge: nil),
        (id: AppConstants.productAnnual, title: "每年", defaultPrice: "¥198/年", unit: "约 ¥16.5/月", badge: "最划算"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 头部
                        VStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(AppConstants.brandGradient)
                            Text("解锁 Clicked Pro")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text("拍得更好，修得更美，无限次使用")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)

                        // 权益列表
                        VStack(alignment: .leading, spacing: 12) {
                            BenefitRow(icon: "camera.fill", text: "无限次智能引导拍摄")
                            BenefitRow(icon: "square.grid.3x3.fill", text: "全部 50+ 滤镜与预设")
                            BenefitRow(icon: "sparkles", text: "无限次 Beautify 美颜")
                            BenefitRow(icon: "wand.and.stars", text: "AI 风格与物体移除（每月 30 次）")
                            BenefitRow(icon: "square.and.arrow.up", text: "高清无水印导出")
                        }
                        .padding()
                        .background(Color(white: 0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // 方案卡片
                        VStack(spacing: 12) {
                            ForEach(planInfo, id: \.id) { plan in
                                planCard(plan)
                            }
                        }
                        .padding(.horizontal)

                        // 购买按钮区
                        VStack(spacing: 12) {
                            if let error = subscription.purchaseError {
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                            Button {
                                Task {
                                    if let annual = subscription.products.first(where: { $0.id == AppConstants.productAnnual }) {
                                        purchasing = annual.id
                                        await subscription.purchase(annual)
                                        purchasing = nil
                                    } else {
                                        subscription.purchaseError = "订阅产品尚未在 App Store 配置，详见文档。"
                                    }
                                }
                            } label: {
                                if purchasing != nil {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("免费试用 7 天，然后 \(priceFor(AppConstants.productAnnual))")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppConstants.brandGradient)
                            .cornerRadius(30)
                            .disabled(purchasing != nil)
                            .padding(.horizontal)

                            Button("恢复购买") {
                                Task { await subscription.restorePurchases() }
                            }
                            .foregroundColor(.gray)
                            .font(.system(size: 14))

                            Text("订阅自动续费，除非在周期结束前 24 小时取消。可在 App Store 账户设置中管理。")
                                .font(.system(size: 11))
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
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

    // MARK: - 方案卡片
    private func planCard(_ plan: (id: String, title: String, defaultPrice: String, unit: String, badge: String?)) -> some View {
        let isSelected = plan.id == AppConstants.productAnnual
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(plan.title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    if let badge = plan.badge {
                        Text(badge).font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black).padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.yellow).cornerRadius(8)
                    }
                }
                if !plan.unit.isEmpty {
                    Text(plan.unit).font(.system(size: 11)).foregroundColor(.gray)
                }
            }
            Spacer()
            Text(priceFor(plan.id)).font(.system(size: 15, weight: .medium)).foregroundColor(.white)
        }
        .padding()
        .background(isSelected ? AppConstants.accentPurple.opacity(0.3) : Color(white: 0.1))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? AppConstants.accentPink : Color.clear, lineWidth: 2)
        )
    }

    // 从 StoreKit 产品取价格，取不到用默认值
    private func priceFor(_ id: String) -> String {
        if let product = subscription.products.first(where: { $0.id == id }) {
            return product.displayPrice
        }
        switch id {
        case AppConstants.productWeekly: return "¥12/周"
        case AppConstants.productMonthly: return "¥48/月"
        case AppConstants.productAnnual: return "¥198/年"
        default: return "一次性购买"
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
