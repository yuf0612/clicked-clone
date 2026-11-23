//
//  PhotoLibraryView.swift
//  相册 Tab —— 展示作品、重新编辑、删除、导出
//

import SwiftUI

struct PhotoLibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var photos: [SavedPhoto] = []
    @State private var selectedPhoto: SavedPhoto?
    @State private var showDetail = false

    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if photos.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photos) { photo in
                                if let image = PhotoLibraryService.shared.image(for: photo) {
                                    Button {
                                        selectedPhoto = photo
                                        showDetail = true
                                    } label: {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                                            .clipped()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("我的作品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(white: 0.08), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { photos = PhotoLibraryService.shared.loadAll() }
            .sheet(isPresented: $showDetail) {
                if let photo = selectedPhoto {
                    PhotoDetailView(photo: photo) {
                        photos = PhotoLibraryService.shared.loadAll() // 删除后刷新
                    }
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 56))
                .foregroundColor(.gray)
            Text("相册还是空的")
                .foregroundColor(.white)
                .font(.title3)
            Text("编辑并保存的照片会出现在这里")
                .foregroundColor(.gray)
                .font(.subheadline)
        }
    }
}

// MARK: - 照片详情
struct PhotoDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    let photo: SavedPhoto
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image = PhotoLibraryService.shared.image(for: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                }

                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        // 重新编辑
                        Button {
                            if let image = PhotoLibraryService.shared.image(for: photo) {
                                appState.imageToEdit = image
                                dismiss()
                                appState.selectedTab = 1
                            }
                        } label: {
                            VStack {
                                Image(systemName: "wand.and.stars").font(.system(size: 22))
                                Text("重新编辑").font(.system(size: 11))
                            }.foregroundColor(.white)
                        }

                        // 保存到系统相册
                        Button {
                            if let image = PhotoLibraryService.shared.image(for: photo) {
                                PhotoLibraryService.shared.saveToSystemPhotoLibrary(image) { _ in
                                    appState.showToast("已保存到系统相册")
                                }
                            }
                        } label: {
                            VStack {
                                Image(systemName: "square.and.arrow.down").font(.system(size: 22))
                                Text("导出").font(.system(size: 11))
                            }.foregroundColor(.white)
                        }

                        // 删除
                        Button {
                            PhotoLibraryService.shared.delete(photo)
                            onDelete()
                            dismiss()
                        } label: {
                            VStack {
                                Image(systemName: "trash").font(.system(size: 22))
                                Text("删除").font(.system(size: 11))
                            }.foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(16)
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundColor(.white)
                }
            }
        }
    }
}
