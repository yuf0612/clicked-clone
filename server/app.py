# -*- coding: utf-8 -*-
"""
ClickedClone AI 后端服务
========================
提供三个真实 AI 能力（全部基于开源算法，无需付费 API Key）：
  1. /api/style          风格迁移（OpenCV 真实艺术算法）
  2. /api/remove-object  物体移除（OpenCV Telea 图像修复 inpaint）
  3. /api/analyze-scene  场景分析（人脸检测 + 亮度/构图真实分析）
  4. /health             健康检查

运行：
  pip install -r requirements.txt
  uvicorn app:app --host 0.0.0.0 --port 8000
"""

import base64
import io
import math
import time
from typing import List

import cv2
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="ClickedClone AI Server", version="1.0.0")

# 允许跨域（iOS App 通过局域网 IP 访问）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------- 数据模型
class StyleRequest(BaseModel):
    image: str                 # base64
    style: str                 # film/retro/glam/dreamy/cinematic/vivid/mono
    intensity: float = 1.0

class RemoveObjectRequest(BaseModel):
    image: str
    points: List[dict]         # [{"x":..., "y":...}, ...] 像素坐标
    radius: float = 30.0

class SceneRequest(BaseModel):
    image: str

# ---------------------------------------------------------------- 工具函数
def decode_image(b64: str) -> np.ndarray:
    """base64 → OpenCV BGR 图像"""
    try:
        raw = base64.b64decode(b64)
        arr = np.frombuffer(raw, np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("无法解码图片")
        return img
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"图片解码失败: {e}")

def encode_image(img: np.ndarray) -> str:
    """OpenCV BGR 图像 → base64 JPEG"""
    ok, buf = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), 90])
    if not ok:
        raise HTTPException(status_code=500, detail="图片编码失败")
    return base64.b64encode(buf.tobytes()).decode("utf-8")

def blend(original: np.ndarray, styled: np.ndarray, intensity: float) -> np.ndarray:
    """按强度混合原图和效果图"""
    intensity = max(0.0, min(1.0, intensity))
    return cv2.addWeighted(original, 1 - intensity, styled, intensity, 0)

# ---------------------------------------------------------------- 风格算法
def apply_style(img: np.ndarray, style: str, intensity: float) -> np.ndarray:
    """真实风格算法（每种风格用不同的 OpenCV 处理链）"""
    original = img.copy()
    out = img.copy()

    if style == "film":          # 胶片：暖色调 + 轻微褪色 + 颗粒
        out = cv2.convertScaleAbs(out, alpha=1.05, beta=5)
        out[:, :, 2] = np.clip(out[:, :, 2].astype(np.float32) * 1.06, 0, 255).astype(np.uint8)  # 增强红
        out[:, :, 0] = np.clip(out[:, :, 0].astype(np.float32) * 0.94, 0, 255).astype(np.uint8)  # 减弱蓝
        noise = np.random.normal(0, 3, out.shape)
        out = np.clip(out.astype(np.float32) + noise, 0, 255).astype(np.uint8)

    elif style == "retro":       # 复古：棕褐色 + 降饱和 + 暗角
        gray = cv2.cvtColor(out, cv2.COLOR_BGR2GRAY)
        sepia = cv2.applyColorMap(gray, cv2.COLORMAP_SEPIA)
        out = sepia

    elif style == "glam":        # 人像：双边滤波磨皮 + 提亮
        out = cv2.bilateralFilter(out, 9, 40, 40)
        out = cv2.convertScaleAbs(out, alpha=1.03, beta=8)

    elif style == "dreamy":      # 梦幻：柔光模糊叠加 + 高亮
        blur = cv2.GaussianBlur(out, (0, 0), 8)
        out = cv2.addWeighted(out, 0.6, blur, 0.4, 0)
        out = cv2.convertScaleAbs(out, alpha=1.02, beta=10)

    elif style == "cinematic":   # 电影感：青橙调色
        lab = cv2.cvtColor(out, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        l = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(l)
        out = cv2.cvtColor(cv2.merge([l, a, b]), cv2.COLOR_LAB2BGR)
        out[:, :, 0] = np.clip(out[:, :, 0].astype(np.float32) * 1.08, 0, 255).astype(np.uint8)  # 青
        out[:, :, 2] = np.clip(out[:, :, 2].astype(np.float32) * 1.05, 0, 255).astype(np.uint8)  # 橙

    elif style == "vivid":       # 鲜艳：提饱和 + 对比
        hsv = cv2.cvtColor(out, cv2.COLOR_BGR2HSV)
        hsv[:, :, 1] = np.clip(hsv[:, :, 1].astype(np.float32) * 1.4, 0, 255).astype(np.uint8)
        out = cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)
        out = cv2.convertScaleAbs(out, alpha=1.1, beta=0)

    elif style == "mono":        # 黑白：高对比灰度
        gray = cv2.cvtColor(out, cv2.COLOR_BGR2GRAY)
        gray = cv2.equalizeHist(gray)
        out = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

    else:
        raise HTTPException(status_code=400, detail=f"不支持的风格: {style}")

    # 统一暗角（vignette）
    if style not in ("glam",):
        rows, cols = out.shape[:2]
        xx = np.linspace(-1, 1, cols)
        yy = np.linspace(-1, 1, rows)
        X, Y = np.meshgrid(xx, yy)
        mask = np.clip(1 - (X**2 + Y**2) * 0.25, 0.6, 1.0)
        mask = (mask * 255).astype(np.uint8)
        out = (out.astype(np.float32) * (mask[:, :, None].astype(np.float32) / 255.0)).astype(np.uint8)

    return blend(original, out, intensity)

# ---------------------------------------------------------------- 接口
@app.get("/health")
def health():
    return {"status": "ok", "version": "1.0.0"}

@app.post("/api/style")
def style_transfer(req: StyleRequest):
    t0 = time.time()
    img = decode_image(req.image)
    result = apply_style(img, req.style, req.intensity)
    return {
        "image": encode_image(result),
        "style": req.style,
        "processing_time": round(time.time() - t0, 3),
    }

@app.post("/api/remove-object")
def remove_object(req: RemoveObjectRequest):
    """
    基于 OpenCV Telea 图像修复的物体移除。
    用户在图片上点选若干位置，算法用周围像素填充这些区域。
    """
    t0 = time.time()
    img = decode_image(req.image)
    mask = np.zeros(img.shape[:2], np.uint8)
    radius = int(max(5, min(120, req.radius)))
    for p in req.points:
        x, y = int(p.get("x", 0)), int(p.get("y", 0))
        cv2.circle(mask, (x, y), radius, 255, -1)
    # inpaint：半径 3，Telea 算法，边缘平滑过渡
    result = cv2.inpaint(img, mask, 3, cv2.INPAINT_TELEA)
    return {
        "image": encode_image(result),
        "processing_time": round(time.time() - t0, 3),
    }

@app.post("/api/analyze-scene")
def analyze_scene(req: SceneRequest):
    """
    真实场景分析：
     - 人脸检测（OpenCV Haar 级联，随 opencv 自带）
     - 亮度分析（判断过暗/过曝）
     - 主体构图（人脸占比、位置）
    返回结构化拍摄建议。
    """
    img = decode_image(req.image)
    hints = []

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape

    # 1. 亮度分析
    mean_brightness = float(np.mean(gray))
    if mean_brightness < 70:
        hints.append({"icon": "sun.max", "title": "光线偏暗", "detail": "找更亮的地方，或面向光源", "severity": "warning"})
    elif mean_brightness > 200:
        hints.append({"icon": "sun.max.fill", "title": "光线过曝", "detail": "避开强光直射，稍微侧身", "severity": "warning"})
    else:
        hints.append({"icon": "checkmark.circle", "title": "光线不错", "detail": "当前亮度适合拍摄", "severity": "good"})

    # 2. 人脸检测（用 opencv 自带的 Haar 级联文件）
    try:
        cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        face_cascade = cv2.CascadeClassifier(cascade_path)
        faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))
        if len(faces) > 0:
            fx, fy, fw, fh = faces[0]
            ratio = fh / h
            cx = (fx + fw / 2) / w
            if ratio < 0.2:
                hints.append({"icon": "figure.stand", "title": "走近一点", "detail": "让人物占据更多画面", "severity": "info"})
            elif ratio > 0.6:
                hints.append({"icon": "arrow.up.left.and.arrow.down.right", "title": "稍微退后", "detail": "人脸占比略大，留点空间", "severity": "info"})
            else:
                hints.append({"icon": "checkmark.circle", "title": "构图合适", "detail": "人物大小刚刚好", "severity": "good"})
            if abs(cx - 0.5) > 0.12:
                direction = "左" if cx > 0.5 else "右"
                hints.append({"icon": "arrow.left" if cx > 0.5 else "arrow.right", "title": f"向{direction}调整", "detail": "主体偏离中心，微调位置", "severity": "info"})
        else:
            hints.append({"icon": "figure.stand", "title": "未检测到人脸", "detail": "面向镜头，让脸完整入镜", "severity": "warning"})
    except Exception:
        hints.append({"icon": "figure.stand", "title": "主体居中", "detail": "让人物位于画面中央", "severity": "info"})

    # 3. 清晰度（拉普拉斯方差，判断模糊）
    laplace_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    if laplace_var < 50:
        hints.append({"icon": "camera.aperture", "title": "画面有点模糊", "detail": "拿稳手机，对焦后拍摄", "severity": "warning"})

    quality = max(0.0, min(1.0, laplace_var / 500))
    return {"hints": hints[:4], "quality_score": round(quality, 2)}

# ---------------------------------------------------------------- 启动入口
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
