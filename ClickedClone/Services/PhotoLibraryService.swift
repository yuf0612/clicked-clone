//
//  PhotoLibraryService.swift
//  相册服务 —— 保存作品到 App 沙盒 / 系统相册
//

import SwiftUI
import Photos
import UIKit

final class PhotoLibraryService {

    static let shared = PhotoLibraryService()

    // 作品元数据存放路径
    private let metadataURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("savedPhotos.json")
    }()

    // 图片存放目录
    private let photosDir: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent(AppConstants.photosDirectory, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    // MARK: - 保存作品到 App 内部（供"相册"Tab 展示）
    @discardableResult
    func saveToApp(_ image: UIImage, presetName: String? = nil) -> SavedPhoto? {
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = photosDir.appendingPathComponent(fileName)
        guard let data = ImageProcessor.shared.exportHighRes(image) else { return nil }
        try? data.write(to: fileURL)

        var photos = loadAll()
        let record = SavedPhoto(fileName: fileName, presetName: presetName)
        photos.insert(record, at: 0)
        saveMetadata(photos)
        return record
    }

    // MARK: - 读取所有作品
    func loadAll() -> [SavedPhoto] {
        guard let data = try? Data(contentsOf: metadataURL),
              let photos = try? JSONDecoder().decode([SavedPhoto].self, from: data) else {
            return []
        }
        return photos
    }

    // MARK: - 取回某张作品图片
    func image(for photo: SavedPhoto) -> UIImage? {
        let url = photosDir.appendingPathComponent(photo.fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - 删除作品
    func delete(_ photo: SavedPhoto) {
        var photos = loadAll()
        photos.removeAll { $0.id == photo.id }
        saveMetadata(photos)
        let url = photosDir.appendingPathComponent(photo.fileName)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 保存到系统相册（需要权限）
    func saveToSystemPhotoLibrary(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                completion(false)
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                DispatchQueue.main.async { completion(success) }
            }
        }
    }

    private func saveMetadata(_ photos: [SavedPhoto]) {
        guard let data = try? JSONEncoder().encode(photos) else { return }
        try? data.write(to: metadataURL)
    }
}
