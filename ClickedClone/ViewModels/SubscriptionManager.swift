//
//  SubscriptionManager.swift
//  会员状态 —— 本版本为【全功能免费解锁版】
//
//  所有功能（全部滤镜、无限美颜、AI 风格、移除物体、高清导出）对所有用户开放。
//  不再发起任何 StoreKit 内购请求，不需要 App Store 配置，也不会弹出付费墙。
//

import Foundation
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    /// 永久全解锁
    @Published var isPro: Bool = true
    @Published var activePlan: String = "全功能免费版"
    @Published var purchaseError: String?

    /// 兼容旧调用：不再监听交易，直接保持解锁
    func listenForTransactions() {
        isPro = true
    }

    /// 兼容旧调用：无需恢复购买
    func restorePurchases() async {
        isPro = true
    }
}
