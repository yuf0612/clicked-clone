//
//  EditorView.swift
//  图片编辑器 —— 滤镜 / 调整 / 美颜 / AI 工具（真实交互版）
//

import SwiftUI

struct EditorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscription: SubscriptionManager
    @StateObject private var vm = EditorViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if vm.session != nil {
                    VStack(spacing: 0) {
                        editorTopBar
                        imagePreviewArea
                        toolPanel
                    }
                } else {
                    emptyState
                }

                // AI 处理中遮罩
                if vm.session?.isProcessingAI == true {
                    aiProcessingOverlay
                }

                // 状态提示
                if let msg = vm.statusMessage {
                    VStack {
                        Spacer().frame(height: 100)
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(12)
                        Spacer()
                    }
                    .transition(.move(edge: .top))
                }
            }
            .navigationBarHidden(true)
            .animation(.easeInOut, value: vm.statusMessage)
            .onChange(of: appState.imageToEditToken) { _ in
                if let image = appState.imageToEdit {
                    vm.loadImage(image)
                    appState.imageToEdit = nil
                }
            }
            .sheet(isPresented: $vm.showPaywall) {
                SubscriptionView()
            }
        }
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 60)).foregroundColor(.gray)
            Text("还没有要编辑的照片").foregroundColor(.white).font(.title3)
            Text("去相机拍一张，或从相册选一张").foregroundColor(.gray).font(.subheadline)
            Button { appState.selectedTab = 0 } label: { Text("去拍照").brandButton() }
        }
    }

    // MARK: - AI 处理遮罩
    private var aiProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().tint(.yellow).scaleEffect(1.4)
                Text("AI 正在处理…").foregroundColor(.white).font(.system(size: 15))
                Text("首次连接服务可能需要几秒").foregroundColor(.gray).font(.system(size: 12))
            }
            .padding(30)
            .background(Color(white: 0.15))
            .cornerRadius(20)
        }
    }

    // MARK: - 顶部工具栏
    private var editorTopBar: some View {
        HStack {
            Button { appState.selectedTab = 0 } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("编辑").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                if vm.session?.isUsingLocalAI == true {
                    Text("离线模式").font(.system(size: 10)).foregroundColor(.orange)
                }
            }
            Spacer()
            HStack(spacing: 16) {
                Button { vm.copyEdits() } label: {
                    Image(systemName: "doc.on.doc").foregroundColor(.white).font(.system(size: 16))
                }
                Button { vm.pasteEdits() } label: {
                    Image(systemName: "clipboard").foregroundColor(.white).font(.system(size: 16))
                }
                Button { vm.resetAll() } label: {
                    Image(systemName: "arrow.counterclockwise").foregroundColor(.white).font(.system(size: 16))
                }
            }
        }
        .padding()
    }

    // MARK: - 图片预览（支持点选移除物体 + 长按看原图）
    private var imagePreviewArea: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // 图片
                Image(uiImage: vm.showingOriginal
                        ? (vm.session?.originalImage ?? UIImage())
                        : (vm.previewImage ?? vm.session?.originalImage ?? UIImage()))
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    // 移除物体模式：点选位置
                    .onTapGesture { location in
                        if vm.removeObjectMode {
                            vm.addRemovalPoint(location)
                        }
                    }
                    // 长按看原图（仅在非移除模式）
                    .gesture(
                        LongPressGesture(minimumDuration: 0.3)
                            .onEnded { _ in
                                if !vm.removeObjectMode { vm.showingOriginal = true }
                            }
                    )
                    .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
                        if !pressing { vm.showingOriginal = false }
                    }) {}

                // 显示用户点选的移除标记
                if vm.removeObjectMode {
                    ForEach(Array(vm.removalPoints.enumerated()), id: \.offset) { index, point in
                        ZStack {
                            Circle().fill(Color.red.opacity(0.35))
                            Circle().stroke(Color.red, lineWidth: 2)
                            Text("\(index + 1)").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        }
                        .frame(width: 50, height: 50)
                        .position(point)
                    }

                    VStack {
                        Text("点选要移除的物体（已选 \(vm.removalPoints.count) 处）")
                            .font(.system(size: 12)).foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.red.opacity(0.8)).cornerRadius(12)
                        Spacer()
                    }
                    .padding(.top, 8)
                } else {
                    Text(vm.showingOriginal ? "原图" : "长按查看原图")
                        .font(.system(size: 12)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.black.opacity(0.5)).cornerRadius(12)
                        .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - 工具面板
    private var toolPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(EditorViewModel.EditorTool.allCases) { tool in
                    Button { vm.activeTool = tool } label: {
                        VStack(spacing: 4) {
                            Text(tool.rawValue)
                                .font(.system(size: 14, weight: vm.activeTool == tool ? .semibold : .regular))
                                .foregroundColor(vm.activeTool == tool ? .white : .gray)
                            Rectangle()
                                .fill(vm.activeTool == tool ? Color.yellow : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 10)

            Divider().background(Color.white.opacity(0.1))

            ScrollView(.horizontal, showsIndicators: false) {
                Group {
                    switch vm.activeTool {
                    case .filters: filtersView
                    case .adjust: adjustView
                    case .beauty: beautyView
                    case .ai: aiView
                    }
                }
                .frame(height: 150)
                .padding(.horizontal)
            }

            Button {
                if vm.savePhoto(presetName: vm.session?.selectedPreset?.name) != nil {
                    appState.showToast("已保存到相册")
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("保存照片")
                }
                .brandButton().frame(maxWidth: .infinity)
            }
            .padding()
        }
        .background(Color(white: 0.08))
    }

    // MARK: - 滤镜列表
    private var filtersView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FilterPreset.FilterCategory.allCases) { cat in
                        Button { vm.selectedCategory = cat } label: {
                            Text(cat.rawValue)
                                .font(.system(size: 13))
                                .foregroundColor(vm.selectedCategory == cat ? .black : .gray)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(vm.selectedCategory == cat ? Color.yellow : Color.white.opacity(0.1))
                                .cornerRadius(14)
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                ForEach(PresetData.presets(in: vm.selectedCategory)) { preset in
                    Button { vm.selectPreset(preset) } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(presetGradient(preset)).frame(width: 56, height: 56)
                                if vm.session?.selectedPreset?.id == preset.id {
                                    RoundedRectangle(cornerRadius: 8).stroke(Color.yellow, lineWidth: 2).frame(width: 56, height: 56)
                                }
                            }
                            Text(preset.name).font(.system(size: 9)).foregroundColor(.white).lineLimit(1).frame(width: 56)
                        }
                    }
                }
            }
            if vm.session?.selectedPreset != nil {
                HStack {
                    Text("强度").foregroundColor(.gray).font(.system(size: 12))
                    Slider(value: Binding(
                        get: { vm.session?.filterIntensity ?? 1 },
                        set: { vm.updateFilterIntensity($0) }
                    ), in: 0...1).tint(.yellow)
                    Text("\(Int((vm.session?.filterIntensity ?? 1) * 100))%")
                        .foregroundColor(.white).font(.system(size: 12)).frame(width: 38)
                }
            }
        }
    }

    private func presetGradient(_ preset: FilterPreset) -> LinearGradient {
        let colors: [Color]
        switch preset.category {
        case .film: colors = [.orange, .brown]
        case .warm: colors = [.yellow, .orange]
        case .moody: colors = [.blue, .purple]
        case .clean: colors = [.white, .gray]
        case .retro: colors = [.pink, .purple]
        case .all: colors = [.gray, .black]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - 调整参数
    private var adjustView: some View {
        VStack(spacing: 8) {
            AdjustSlider(title: "亮度", value: vm.session?.adjustments.brightness ?? 0, range: -1...1) { vm.updateAdjustment(\.brightness, value: $0) }
            AdjustSlider(title: "对比度", value: vm.session?.adjustments.contrast ?? 0, range: -1...1) { vm.updateAdjustment(\.contrast, value: $0) }
            AdjustSlider(title: "饱和度", value: vm.session?.adjustments.saturation ?? 0, range: -1...1) { vm.updateAdjustment(\.saturation, value: $0) }
            AdjustSlider(title: "曝光", value: vm.session?.adjustments.exposure ?? 0, range: -1...1) { vm.updateAdjustment(\.exposure, value: $0) }
            AdjustSlider(title: "色温", value: vm.session?.adjustments.warmth ?? 0, range: -1...1) { vm.updateAdjustment(\.warmth, value: $0) }
        }
    }

    // MARK: - 美颜
    private var beautyView: some View {
        VStack(spacing: 10) {
            Label("Beautify · 自然美颜", systemImage: "sparkles")
                .foregroundColor(.pink).font(.system(size: 13, weight: .semibold))
            AdjustSlider(title: "磨皮", value: vm.session?.beauty.smoothSkin ?? 0, range: 0...1) { vm.updateBeauty(\.smoothSkin, value: $0) }
            AdjustSlider(title: "亮眼", value: vm.session?.beauty.brightEyes ?? 0, range: 0...1) { vm.updateBeauty(\.brightEyes, value: $0) }
            AdjustSlider(title: "光泽", value: vm.session?.beauty.glow ?? 0, range: 0...1) { vm.updateBeauty(\.glow, value: $0) }
        }
    }

    // MARK: - AI 工具
    private var aiView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AI 风格", systemImage: "wand.and.stars")
                    .foregroundColor(.purple).font(.system(size: 13, weight: .semibold))
                Spacer()
                if !subscription.isPro {
                    Text("今日剩余 \(AIService.shared.remainingFreeUses()) 次")
                        .font(.system(size: 11)).foregroundColor(.gray)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AIService.shared.availableStyles, id: \.self) { style in
                        Button {
                            Task { await vm.applyAIStyle(style, isPro: subscription.isPro) }
                        } label: {
                            Text(style)
                                .font(.system(size: 12))
                                .foregroundColor(vm.session?.aiStyle == style ? .black : .white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(vm.session?.aiStyle == style ? Color.purple : Color.white.opacity(0.1))
                                .cornerRadius(16)
                        }
                    }
                }
            }

            // 移除物体：真实交互
            HStack(spacing: 12) {
                Button {
                    vm.toggleRemoveObjectMode()
                } label: {
                    Label(vm.removeObjectMode ? "取消选点" : "移除物体", systemImage: "eraser")
                        .font(.system(size: 12))
                        .foregroundColor(vm.removeObjectMode ? .red : .cyan)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white.opacity(0.1)).cornerRadius(12)
                }
                if vm.removalPoints.count > 0 {
                    Button { vm.undoRemovalPoint() } label: {
                        Image(systemName: "arrow.uturn.backward").foregroundColor(.white).font(.system(size: 14))
                    }
                    Button {
                        Task { await vm.executeRemoveObjects(isPro: subscription.isPro) }
                    } label: {
                        Label("执行移除 (\(vm.removalPoints.count))", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12)).foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(AppConstants.brandGradient).cornerRadius(12)
                    }
                }
            }
        }
    }
}

// MARK: - 调整滑块组件
private struct AdjustSlider: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title).foregroundColor(.gray).font(.system(size: 12)).frame(width: 50, alignment: .leading)
            Slider(value: Binding(get: { value }, set: { onChange($0) }), in: range).tint(.yellow)
            Text("\(Int(value * 100))").foregroundColor(.white).font(.system(size: 11)).frame(width: 32)
        }
    }
}
