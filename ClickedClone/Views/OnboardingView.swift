//
//  OnboardingView.swift
//  新手引导页 —— 首次打开显示，介绍三大核心功能
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0

    // 引导页数据
    private let pages: [OnboardingPage] = [
        .init(icon: "square.on.circle", title: "照着样片拍",
              desc: "从相册选一张喜欢的照片，它会变成相机里的半透明向导，照着摆姿势就行。"),
        .init(icon: "sparkles.rectangle.stack", title: "拍照时有指导",
              desc: "拍摄前告诉你「走近点、转向光、往左移」，对齐好了还能自动按快门。"),
        .init(icon: "wand.and.stars", title: "一键变精致",
              desc: "50+ 潮流滤镜、一键美颜、AI 风格——从拍摄到发布，一个 App 搞定。"),
    ]

    var body: some View {
        ZStack {
            AppConstants.brandGradient.ignoresSafeArea()

            VStack {
                Spacer()

                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageView(pages[index]).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 420)

                // 页面指示点
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.top, 10)

                Spacer()

                // 按钮
                VStack(spacing: 16) {
                    Button {
                        withAnimation {
                            appState.hasSeenOnboarding = true
                        }
                    } label: {
                        Text(currentPage == pages.count - 1 ? "开始使用" : "跳过引导")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppConstants.accentPink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(30)
                    }
                    .padding(.horizontal, 32)

                    if currentPage < pages.count - 1 {
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            Text("下一步").foregroundColor(.white).font(.system(size: 14))
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Color.white.opacity(0.2)).frame(width: 180, height: 180)
                Image(systemName: page.icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)
            }
            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            Text(page.desc)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .lineSpacing(6)
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let desc: String
}
