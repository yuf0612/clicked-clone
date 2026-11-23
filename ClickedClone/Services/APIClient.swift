//
//  APIClient.swift
//  网络层 —— 与 AI 后端通信（生产级实现）
//
//  特性：
//   - async/await 现代并发
//   - 自动重试（指数退避）
//   - 超时控制
//   - 图片压缩（控制上传体积）
//   - 统一错误处理
//   - 结果缓存（相同图片+参数命中缓存，省流量省钱）
//   - 网络状态检测
//

import Foundation
import UIKit

final class APIClient {

    static let shared = APIClient()

    private let baseURL = AppConstants.apiBaseURL
    private let session: URLSession
    private let cache = NSCache<NSString, NSData>()   // 内存缓存
    private let cacheQueue = DispatchQueue(label: "com.clickedclone.apicache")

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConstants.apiTimeout
        config.timeoutIntervalForResource = AppConstants.apiTimeout * 2
        // 关键：连不上主机时立即失败，而不是无限挂起等待网络恢复
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
        cache.countLimit = 30   // 最多缓存 30 张结果图
    }

    // MARK: - 通用 POST 请求（带重试）
    private func post<T: Decodable>(path: String, body: Encodable, retry: Int = AppConstants.apiRetryCount) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        // 墙钟超时：无论底层 URLSession 是否挂起，硬上限到点立即抛错，
        // 让 AIService 走本地降级，避免界面永久停在"正在处理"。
        let urlSession = self.session
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                // ===== 真实请求（含有限重试）=====
                var lastError: Error?
                for attempt in 0...retry {
                    do {
                        let (data, response) = try await urlSession.data(for: request)
                        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
                        guard (200...299).contains(http.statusCode) else {
                            if let errResp = try? JSONDecoder().decode([String: String].self, from: data),
                               let msg = errResp["detail"] ?? errResp["error"] {
                                throw APIError.serverMessage(msg)
                            }
                            throw APIError.httpStatus(http.statusCode)
                        }
                        do {
                            return try JSONDecoder().decode(T.self, from: data)
                        } catch let decodeError {
                            throw APIError.decodingFailed(decodeError.localizedDescription)
                        }
                    } catch let error as APIError {
                        if case .httpStatus(let code) = error, code < 500, code != 429 { throw error }
                        if case .serverMessage = error { throw error }
                        lastError = error
                    } catch {
                        lastError = error
                    }

                    if attempt < retry {
                        let delay = UInt64(pow(2.0, Double(attempt)) * 500_000_000)
                        try? await Task.sleep(nanoseconds: delay)
                    }
                }

                if let urlError = lastError as? URLError {
                    switch urlError.code {
                    case .timedOut: throw APIError.timeout
                    case .notConnectedToInternet, .cannotConnectToHost, .networkConnectionLost:
                        throw APIError.offline
                    default: throw urlError
                    }
                }
                throw lastError ?? APIError.noData
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(AppConstants.apiHardTimeout * 1_000_000_000))
                throw APIError.timeout
            }

            guard let result = try await group.next() else { throw APIError.noData }
            group.cancelAll()
            return result
        }
    }

    // MARK: - 健康检查
    func checkHealth() async -> Bool {
        guard let url = URL(string: baseURL + "/health") else { return false }
        do {
            let (data, _) = try await session.data(from: url)
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            return health.status == "ok"
        } catch {
            return false
        }
    }

    // MARK: - 风格迁移
    func applyStyle(image: UIImage, style: String, intensity: Double) async throws -> UIImage {
        // 先查缓存
        let cacheKey = "style_\(style)_\(Int(intensity * 100))_\(image.hash)" as NSString
        if let cached = cacheQueue.sync(execute: { cache.object(forKey: cacheKey) }),
           let cachedImage = UIImage(data: cached as Data) {
            return cachedImage
        }

        let request = StyleTransferRequest(
            image: encodeImage(image),
            style: style,
            intensity: intensity
        )
        let response: StyleTransferResponse = try await post(path: "/api/style", body: request)
        guard let data = Data(base64Encoded: response.image),
              let result = UIImage(data: data) else { throw APIError.noData }

        cacheQueue.async { self.cache.setObject(data as NSData, forKey: cacheKey) }
        return result
    }

    // MARK: - 移除物体
    func removeObjects(image: UIImage, points: [CGPoint], radius: Double) async throws -> UIImage {
        let codablePoints = points.map { CGPointCodable(Double($0.x), Double($0.y)) }
        let request = RemoveObjectRequest(
            image: encodeImage(image),
            points: codablePoints,
            radius: radius
        )
        let response: ImageProcessResponse = try await post(path: "/api/remove-object", body: request)
        guard let data = Data(base64Encoded: response.image),
              let result = UIImage(data: data) else { throw APIError.noData }
        return result
    }

    // MARK: - 场景分析
    func analyzeScene(image: UIImage) async throws -> [CaptureHint] {
        let request = SceneAnalysisRequest(image: encodeImage(image))
        let response: SceneAnalysisResponse = try await post(path: "/api/analyze-scene", body: request)
        return response.hints.map { $0.toCaptureHint() }
    }

    // MARK: - 图片编码（压缩到合理体积，base64）
    private func encodeImage(_ image: UIImage) -> String {
        // 最长边限制 1280，JPEG 0.8，避免上传过大
        let resized = image.fixedOrientation.resized(toMax: 1280)
        let data = resized.jpegData(compressionQuality: 0.8) ?? Data()
        return data.base64EncodedString()
    }
}
