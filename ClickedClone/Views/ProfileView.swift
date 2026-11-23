//
//  ProfileView.swift
//  个人中心 Tab —— 会员状态、设置、订阅入口
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscription: SubscriptionManager
    @State private var showSubscription = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 头像 + 会员标识
                        VStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 70))
                                .foregroundStyle(AppConstants.brandGradient)
                            Text("全功能已解锁")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text("所有功能免费使用，无次数限制")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 30)

                        // 全解锁说明卡片
                        Button {
                            showSubscription = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("全部功能已免费解锁", systemImage: "checkmark.seal.fill")
                                        .font(.system(size: 17, weight: .bold))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                Text("无限引导拍摄 · 全部滤镜 · 无限美颜 · 智能风格")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(AppConstants.brandGradient)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)

                        // 设置列表
                        VStack(spacing: 0) {
                            SettingRow(icon: "moon.fill", title: "深色模式") {
                                Toggle("", isOn: $appState.forceDark)
                                    .toggleStyle(SwitchToggleStyle(tint: .pink))
                                    .labelsHidden()
                            }
                            Divider().background(Color.white.opacity(0.1))
                            SettingRow(icon: "checkmark.seal", title: "会员状态") {
                                Text("全功能免费版").foregroundColor(.gray).font(.system(size: 12))
                            }
                        }
                        .background(Color(white: 0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // 关于
                        Text("点拍 · 版本 1.0 · 演示工程")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(white: 0.06), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
        }
    }
}

private struct SettingRow<Content: View>: View {
    let icon: String
    let title: String
    let content: Content

    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.pink).frame(width: 28)
            Text(title).foregroundColor(.white).font(.system(size: 15))
            Spacer()
            content
        }
        .padding()
    }
}
