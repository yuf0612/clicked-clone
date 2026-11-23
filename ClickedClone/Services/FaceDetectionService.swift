//
//  FaceDetectionService.swift
//  人脸检测服务 —— 基于 Vision 框架的真实人脸关键点与对齐分析
//
//  能力：
//   - 人脸检测 + 5 个关键点（双眼、鼻、嘴）
//   - 真实对齐评分：居中度 + 大小 + 正面度（双眼连线水平）
//   - 用于 Smart Guide 自动快门、Beautify 定位
//
//  说明：Vision 是苹果系统自带框架，免费、离线、无需联网。
//  如需电影级精准身体姿态，可在此基础上替换 FaceUnity（见文档 06）。
//

import Vision
import UIKit

final class FaceDetectionService {

    static let shared = FaceDetectionService()

    // 人脸分析结果
    struct FaceResult {
        let boundingBox: CGRect        // 归一化坐标（0~1）
        let leftEye: CGPoint?
        let rightEye: CGPoint?
        let nose: CGPoint?
        let mouth: CGPoint?
        let rollAngle: Double          // 头部倾斜角（弧度），0 表示水平

        /// 正面度评分：眼睛越水平、越对称分越高
        var frontalScore: Float {
            guard let left = leftEye, let right = rightEye else { return 0.5 }
            let eyeDist = hypot(right.x - left.x, right.y - left.y)
            let distScore = Float(min(1.0, max(0, (eyeDist - 0.03) / 0.08)))
            let angleScore = Float(max(0, 1 - abs(rollAngle) / 0.26))
            return (distScore + angleScore) / 2
        }
    }

    // MARK: - 检测人脸（含关键点，异步）
    func detectFaces(in image: UIImage, completion: @escaping ([FaceResult]) -> Void) {
        guard let cgImage = image.fixedOrientation.cgImage else {
            completion([])
            return
        }
        let request = VNDetectFaceLandmarksRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNFaceObservation] else {
                completion([])
                return
            }
            completion(observations.map { self.makeResult(from: $0) })
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    // MARK: - 同步版本（用于相机实时帧分析）
    func detectFacesSync(in image: UIImage) -> [FaceResult] {
        guard let cgImage = image.fixedOrientation.cgImage else { return [] }
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let observations = request.results as? [VNFaceObservation] else { return [] }
        return observations.map { makeResult(from: $0) }
    }

    // MARK: - VNFaceObservation → FaceResult
    private func makeResult(from obs: VNFaceObservation) -> FaceResult {
        let leftEye = obs.landmarks?.leftEye?.normalizedPoints.first
        let rightEye = obs.landmarks?.rightEye?.normalizedPoints.first
        var roll: Double = 0
        if let left = leftEye, let right = rightEye {
            roll = atan2(Double(right.y - left.y), Double(right.x - left.x))
        }
        return FaceResult(
            boundingBox: obs.boundingBox,
            leftEye: left.map { CGPoint(x: $0.x, y: $0.y) },
            rightEye: right.map { CGPoint(x: $0.x, y: $0.y) },
            nose: obs.landmarks?.nose?.normalizedPoints.first.map { CGPoint(x: $0.x, y: $0.y) },
            mouth: obs.landmarks?.outerLips?.normalizedPoints.first.map { CGPoint(x: $0.x, y: $0.y) },
            rollAngle: roll
        )
    }

    // MARK: - 对齐评分（Smart Guide 自动快门核心）
    /// 综合：人脸居中 + 大小合适 + 正面 → 0~1 分数
    func alignmentScore(face: FaceResult?, imageSize: CGSize) -> Float {
        guard let face = face else { return 0 }

        // 1. 居中度
        let cx = face.boundingBox.midX
        let cy = face.boundingBox.midY
        let centerOffset = hypot(CGFloat(cx - 0.5), CGFloat(cy - 0.55))
        let centerScore = Float(max(0, 1 - centerOffset / 0.35))

        // 2. 大小：脸占画面高度 25%~45% 最佳
        let faceHeight = face.boundingBox.height
        let sizeScore: Float = (faceHeight >= 0.25 && faceHeight <= 0.45)
            ? 1.0 : Float(max(0, 1 - abs(faceHeight - 0.35) * 4))

        // 3. 正面度
        let frontal = face.frontalScore

        // 加权：居中 35% + 大小 30% + 正面 35%
        return centerScore * 0.35 + sizeScore * 0.30 + frontal * 0.35
    }

    // MARK: - 兼容旧接口
    func alignmentScore(faceBox: CGRect?, imageSize: CGSize) -> Float {
        guard let box = faceBox else { return 0 }
        let fake = FaceResult(boundingBox: box, leftEye: nil, rightEye: nil,
                              nose: nil, mouth: nil, rollAngle: 0)
        return alignmentScore(face: fake, imageSize: imageSize)
    }
}
