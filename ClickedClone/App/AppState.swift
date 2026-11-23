//
//  AppState.swift
//  全局应用状态 —— 用 @EnvironmentObject 在任意界面读取
//

import SwiftUI
import Combine

final class AppState: ObservableObject {
    // 是否已经看过新手引导（UserDefaults 持久化，下次打开不再显示）
    @Published var hasSeenOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenOnboarding") }
    }

    // 是否强制深色模式（设置页可切换）
    @Published var forceDark: Bool = UserDefaults.standard.bool(forKey: "forceDark") {
        didSet { UserDefaults.standard.set(forceDark, forKey: "forceDark") }
    }

    // 当前选中的 Tab（0=拍照 1=编辑 2=相册 3=我的）
    @Published var selectedTab: Int = 0

    // 从相机拍摄后要传给编辑器的图片（跨 Tab 传递）
    @Published var imageToEdit: UIImage? {
        didSet { if imageToEdit != nil { imageToEditToken = UUID() } }
    }
    // 图片不适合直接观察（UIImage 不遵循 Equatable），用这个 token 触发监听
    @Published var imageToEditToken: UUID = UUID()

    // 提示弹窗文案
    @Published var toastMessage: String?
    @Published var showToast: Bool = false

    func showToast(_ message: String) {
        toastMessage = message
        showToast = true
    }
}
