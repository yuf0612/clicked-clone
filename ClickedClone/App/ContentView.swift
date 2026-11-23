//
//  ContentView.swift
//  主导航 —— 底部 4 个 Tab：拍照 / 编辑 / 相册 / 我的
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if appState.hasSeenOnboarding {
                TabView(selection: $appState.selectedTab) {
                    CameraView()
                        .tabItem { Label("拍照", systemImage: "camera.fill") }
                        .tag(0)

                    EditorView()
                        .tabItem { Label("编辑", systemImage: "wand.and.stars") }
                        .tag(1)

                    PhotoLibraryView()
                        .tabItem { Label("相册", systemImage: "photo.stack") }
                        .tag(2)

                    ProfileView()
                        .tabItem { Label("我的", systemImage: "person.fill") }
                        .tag(3)
                }
                .accentColor(AppConstants.accentPink)
                .onAppear {
                    // 让 TabBar 背景为深色（配合相机深色主题）
                    let appearance = UITabBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = UIColor(white: 0.08, alpha: 1)
                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
            } else {
                OnboardingView()
            }

            // 全局 Toast 提示
            if appState.showToast {
                VStack {
                    Spacer()
                    Text(appState.toastMessage ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { appState.showToast = false }
                    }
                }
            }
        }
    }
}
