//
//  ClickedCloneApp.swift
//  App 入口 —— 整个应用的启动点
//
//  说明：@main 表示这是程序入口。AppState 是全局状态，SubscriptionManager 管理订阅。
//

import SwiftUI

@main
struct ClickedCloneApp: App {
    // 全局状态（引导页是否看过、用户设置等）
    @StateObject private var appState = AppState()
    // 订阅管理器（管理 Pro 会员状态）
    @StateObject private var subscription = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(subscription)
                // 强制浅色/深色跟随系统；本 App 相机界面用深色更有质感
                .preferredColorScheme(appState.forceDark ? .dark : nil)
                .onAppear {
                    // App 启动时加载已购买的订阅状态
                    subscription.listenForTransactions()
                }
        }
    }
}
