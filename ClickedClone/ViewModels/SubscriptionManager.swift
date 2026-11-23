//
//  SubscriptionManager.swift
//  订阅管理 —— 封装 StoreKit 应用内购买
//
//  ⚠️ 说明：这里是完整的 StoreKit 2 实现框架。
//  真正能用需要：1) 在 App Store Connect 创建订阅产品  2) 填入真实产品 ID  3) 提交审核通过。
//  未配置时，购买会失败但不影响 App 其他功能演示。
//

import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    @Published var isPro = UserDefaults.standard.bool(forKey: "isPro")
    @Published var activePlan: String = UserDefaults.standard.string(forKey: "activePlan") ?? ""
    @Published var products: [Product] = []
    @Published var purchaseError: String?

    private var updateListenerTask: Task<Void, Error>?

    // 所有产品 ID
    private let allProductIDs = [
        AppConstants.productMonthly,
        AppConstants.productAnnual,
        AppConstants.productWeekly,
        AppConstants.productLifetime
    ]

    // MARK: - 监听交易（App 启动时调用）
    func listenForTransactions() {
        updateListenerTask = listenForTransactionsLoop()

        Task {
            // 加载产品信息
            do {
                let storeProducts = try await Product.products(for: allProductIDs)
                self.products = storeProducts.sorted { $0.price < $1.price }
            } catch {
                purchaseError = "加载订阅产品失败：\(error.localizedDescription)"
            }
            // 检查当前是否已订阅
            await checkEntitlement()
        }
    }

    // MARK: - 持续监听交易状态更新（续费、退款等）
    private func listenForTransactionsLoop() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                await self.handle(transaction: result)
            }
        }
    }

    // MARK: - 购买
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(transaction: verification)
            case .userCancelled:
                break
            case .pending:
                purchaseError = "购买待处理（可能需要家长批准）"
            @unknown default:
                break
            }
        } catch {
            purchaseError = "购买失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 恢复购买
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkEntitlement()
        } catch {
            purchaseError = "恢复失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 检查订阅权益
    private func checkEntitlement() async {
        var pro = false
        var plan = ""
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // 检查是否有效期内（订阅）或永久购买
                if transaction.revocationDate == nil {
                    pro = true
                    plan = transaction.productID
                }
            }
        }
        self.isPro = pro
        self.activePlan = plan
        UserDefaults.standard.set(pro, forKey: "isPro")
        UserDefaults.standard.set(plan, forKey: "activePlan")
    }

    // MARK: - 处理交易结果
    private func handle(transaction result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await checkEntitlement()
        await transaction.finish()
    }

    deinit {
        updateListenerTask?.cancel()
    }
}
