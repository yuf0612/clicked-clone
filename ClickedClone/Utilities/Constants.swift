//
//  Constants.swift
//  常量集中管理 —— 颜色、文案、订阅 ID 等
//

import SwiftUI

enum AppConstants {
    // App 信息
    static let appName = "ClickedClone"
    static let appTagline = "Your Photos, But Cooler"

    // 主题色（ pink/purple 渐变，呼应 Clicked 的年轻潮流感）
    static let accentPink = Color(red: 0.98, green: 0.36, blue: 0.55)
    static let accentPurple = Color(red: 0.55, green: 0.35, blue: 0.95)
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [accentPink, accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // 相机界面深色背景
    static let cameraBg = Color(red: 0.07, green: 0.07, blue: 0.09)

    // 订阅产品 ID（需要在 App Store Connect 里创建对应的产品）
    // 命名规则：年份.月份.功能.周期，避免与别的 App 冲突
    static let productMonthly = "com.yourcompany.clickedclone.pro.monthly"
    static let productAnnual  = "com.yourcompany.clickedclone.pro.annual"
    static let productWeekly  = "com.yourcompany.clickedclone.pro.weekly"
    static let productLifetime = "com.yourcompany.clickedclone.pro.lifetime"

    // AI 免费额度（未订阅时每天/每周可用次数）
    static let freeAIDailyLimit = 3
    static let proAIMonthlyQuota = 30

    // 相册存储目录名
    static let photosDirectory = "ClickedClonePhotos"

    // MARK: - AI 后端配置
    /// AI 服务地址。当前填的是部署后端那台电脑的 WLAN 局域网 IP（已实测）。
    /// 手机和电脑需在同一 WiFi；WiFi 变化后 IP 可能变，用 start_server.bat 查看新 IP 并更新这里。
    /// 模拟器调试可改成 http://localhost:8000。上线时换成正式域名（必须 HTTPS）。
    static let apiBaseURL = "http://192.168.0.103:8000"
    /// 网络请求超时（秒）——连不上后端时快速失败，避免界面长期卡在"正在处理"
    static let apiTimeout: TimeInterval = 8
    /// 硬超时（秒）——墙钟保护，URLSession 挂起时也强制结束并走本地降级
    static let apiHardTimeout: TimeInterval = 10
    /// 失败重试次数——本地降级已足够可靠，不重试以免拖慢体验
    static let apiRetryCount = 0
    /// 是否启用本地降级（后端连不上时用设备端算法兜底，保证功能可用）
    static let enableLocalFallback = true
}
