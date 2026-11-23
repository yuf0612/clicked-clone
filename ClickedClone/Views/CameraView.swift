//
//  CameraView.swift
//  相机主界面 —— 拍摄引导的核心视图
//
//  结构（从上到下）：
//  1. 顶部工具栏（关闭、定时、连拍、样片叠加）
//  2. 取景预览层（相机画面 + 半透明样片叠加）
//  3. PicScan 提示气泡（AI 告诉你怎么调整）
//  4. 底部控制区（相册、快门、翻转摄像头、Smart Guide）
//

import SwiftUI
import PhotosUI

struct CameraView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = CameraViewModel()

    // 系统相册选样片
    @State private var photoItem: PhotosPickerItem?
    @State private var showCameraErrorAlert = false

    var body: some View {
        ZStack {
            AppConstants.cameraBg.ignoresSafeArea()

            // ===== 相机预览层 =====
            CameraPreviewContainer(viewModel: vm)
                .ignoresSafeArea()

            // ===== 样片叠加（半透明引导）=====
            if let overlay = vm.overlayImage {
                Image(uiImage: overlay)
                    .resizable()
                    .scaledToFill()
                    .opacity(vm.overlayOpacity)
                    .allowsHitTesting(false)   // 不拦截点击
                    .ignoresSafeArea()
            }

            // ===== 顶部工具栏 =====
            VStack {
                topToolbar
                Spacer()
            }
            .padding(.top, 8)

            // ===== PicScan 提示气泡 =====
            VStack {
                Spacer().frame(height: 120)
                if !vm.hints.isEmpty {
                    hintsPanel
                    Spacer()
                }
            }
            .animation(.easeInOut, value: vm.hints.isEmpty)

            // ===== Smart Guide 对齐指示 =====
            if vm.autoShutterEnabled {
                alignmentIndicator
            }

            // ===== 倒计时 =====
            if vm.isCountingDown {
                countdownOverlay
            }

            // ===== 底部控制区 =====
            VStack {
                Spacer()
                bottomControls
            }

            // ===== 拍摄预览确认页（覆盖全屏）=====
            if vm.showPreview, let image = vm.capturedImage {
                CapturePreviewView(
                    image: image,
                    onRetake: { vm.retake() },
                    onUse: { usePhoto(image) }
                )
                .transition(.opacity)
                .zIndex(10)
            }

        }
        .onAppear {
            vm.cameraService.startSession()
            showCameraErrorAlert = vm.cameraService.cameraError != nil
        }
        .onDisappear { vm.cameraService.stopSession() }
        .alert("相机不可用", isPresented: $showCameraErrorAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(vm.cameraService.cameraError ?? "")
        }
    }

    // MARK: - 顶部工具栏
    private var topToolbar: some View {
        HStack(spacing: 16) {
            // 关闭相机（回到拍照首页）
            Button {
                appState.selectedTab = 0
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }

            Spacer()

            // 定时按钮
            Menu {
                ForEach([0, 3, 5, 10], id: \.self) { sec in
                    Button {
                        vm.timerSeconds = sec
                    } label: {
                        Label(sec == 0 ? "关闭定时" : "\(sec) 秒定时",
                              systemImage: sec == 0 ? "timer" : "timer.circle")
                    }
                }
            } label: {
                ToolbarIcon(systemName: "timer", isActive: vm.timerSeconds > 0,
                            badge: vm.timerSeconds > 0 ? "\(vm.timerSeconds)" : nil)
            }

            // 连拍按钮
            Menu {
                ForEach([1, 3, 5], id: \.self) { count in
                    Button {
                        vm.burstCount = count
                    } label: {
                        Label(count == 1 ? "单张" : "连拍 \(count) 张", systemImage: "square.stack.3d.up")
                    }
                }
            } label: {
                ToolbarIcon(systemName: "square.stack.3d.up", isActive: vm.burstCount > 1,
                            badge: vm.burstCount > 1 ? "\(vm.burstCount)" : nil)
            }

            // 样片叠加透明度（有样片时才显示；选样片在底部"样片"按钮）
            // 注意：iOS 的 Menu 里 Slider 无法拖动，故改用档位按钮，交互真实可用
            if vm.overlayImage != nil {
                Menu {
                    ForEach([0.25, 0.45, 0.7, 0.9], id: \.self) { level in
                        Button {
                            vm.overlayOpacity = level
                        } label: {
                            Label("向导强度 \(Int(level * 100))%",
                                  systemImage: abs(vm.overlayOpacity - level) < 0.01 ? "checkmark" : "circle")
                        }
                    }
                    Divider()
                    Button("移除样片", role: .destructive) { vm.clearOverlay() }
                } label: {
                    ToolbarIcon(systemName: "square.on.circle", isActive: true)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - PicScan 提示面板
    private var hintsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("拍摄建议", systemImage: "wand.and.stars")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.yellow)
                Spacer()
                Button("刷新") {
                    Task { await vm.runSceneAnalysis() }
                }
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            }
            ForEach(vm.hints) { hint in
                HStack(spacing: 10) {
                    Image(systemName: hint.icon)
                        .foregroundColor(hint.severity == .warning ? .orange : .cyan)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hint.title).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                        Text(hint.detail).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.55))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    // MARK: - Smart Guide 对齐指示
    private var alignmentIndicator: some View {
        VStack(spacing: 6) {
            // 对齐进度环
            ZStack {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(vm.alignmentScore))
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: vm.alignmentScore)
                Image(systemName: "faceid")
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)

            Text(vm.alignmentScore > 0.85 ? "保持！即将自动拍摄" : "对齐面部，自动拍摄")
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .offset(y: -60)
    }

    // MARK: - 倒计时遮罩
    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            Text(vm.countdownText)
                .font(.system(size: 90, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(radius: 10)
        }
        .transition(.scale)
    }

    // MARK: - 底部控制区
    private var bottomControls: some View {
        VStack(spacing: 18) {
            // 功能标签行
            HStack(spacing: 24) {
                FeatureTag(icon: "doc.text.image", title: "样片跟拍", isOn: vm.overlayImage != nil)
                FeatureTag(icon: "wand.and.rays", title: "场景指导", isOn: !vm.hints.isEmpty)
                FeatureTag(icon: "faceid", title: "自动快门", isOn: vm.autoShutterEnabled)
            }

            // 主控制行
            HStack(spacing: 0) {
                // 左：相册（打开选样片）—— 用一个 Button 直接设置 photoItem
                PhotosPicker(selection: $photoItem, matching: .images) {
                    VStack {
                        if let thumb = vm.overlayImage {
                            Image(uiImage: thumb).resizable().scaledToFill()
                                .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 24)).foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Text("样片").font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                    }
                }
                .onChange(of: photoItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            vm.setOverlay(image)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // 中：快门
                Button { vm.takePhoto() } label: {
                    ZStack {
                        Circle().stroke(Color.white, lineWidth: 4).frame(width: 78, height: 78)
                        Circle().fill(AppConstants.brandGradient).frame(width: 66, height: 66)
                        Image(systemName: "camera.fill").foregroundColor(.white).font(.system(size: 24))
                    }
                }
                .frame(maxWidth: .infinity)

                // 右：翻转摄像头
                Button { vm.cameraService.switchCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 26)).foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)
            }

            // Smart Guide 开关 + 场景分析按钮
            HStack(spacing: 20) {
                Toggle(isOn: $vm.autoShutterEnabled) {
                    Label("智能自动拍摄", systemImage: "faceid")
                        .font(.system(size: 13)).foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))

                Button {
                    Task { await vm.runSceneAnalysis() }
                } label: {
                    if vm.isAnalyzing {
                        Label("分析中…", systemImage: "ellipsis.circle")
                            .font(.system(size: 13)).foregroundColor(.gray)
                    } else {
                        Label("分析场景", systemImage: "wand.and.stars")
                            .font(.system(size: 13)).foregroundColor(.yellow)
                    }
                }
                .disabled(vm.isAnalyzing)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
    }

    // MARK: - 拍完去编辑
    private func usePhoto(_ image: UIImage) {
        appState.imageToEdit = image
        appState.selectedTab = 1   // 跳到编辑 Tab
        vm.retake()
    }
}

// MARK: - 相机预览容器（用 UIViewRepresentable 桥接 AVFoundation）
struct CameraPreviewContainer: UIViewRepresentable {
    let viewModel: CameraViewModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let preview = viewModel.cameraService.previewLayer
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        viewModel.cameraService.previewLayer.frame = uiView.bounds
    }
}

// MARK: - 顶部工具图标
private struct ToolbarIcon: View {
    let systemName: String
    let isActive: Bool
    var badge: String? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isActive ? .black : .white)
                .frame(width: 38, height: 38)
                .background(isActive ? Color.yellow : Color.black.opacity(0.45))
                .clipShape(Circle())
            if let badge = badge {
                Text(badge).font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white).padding(3)
                    .background(Color.red).clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }
}

// MARK: - 底部功能标签
private struct FeatureTag: View {
    let icon: String
    let title: String
    let isOn: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 14))
            Text(title).font(.system(size: 10))
        }
        .foregroundColor(isOn ? .yellow : .white.opacity(0.5))
    }
}

// MARK: - 拍摄后确认页
struct CapturePreviewView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onUse: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image).resizable().scaledToFit().ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: onRetake) {
                        Label("重拍", systemImage: "arrow.left")
                            .foregroundColor(.white).font(.system(size: 15))
                    }
                    Spacer()
                }
                .padding()

                Spacer()

                HStack(spacing: 30) {
                    Button(action: onRetake) {
                        Text("重拍").foregroundColor(.white)
                            .padding(.horizontal, 30).padding(.vertical, 12)
                            .background(Color.white.opacity(0.2)).cornerRadius(25)
                    }
                    Button(action: onUse) {
                        Text("使用照片").foregroundColor(.white)
                            .padding(.horizontal, 30).padding(.vertical, 12)
                            .background(AppConstants.brandGradient).cornerRadius(25)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}
