# ClickedClone AI 后端（server/）

这是让 App 三大 AI 功能**真实可用**的服务端。基于 Python + OpenCV 开源算法实现，**不需要任何付费 API Key**。

## 它提供什么

| 接口 | 功能 | 真实算法 |
|------|------|---------|
| `/health` | 健康检查 | - |
| `/api/style` | 风格迁移 | 7 种 OpenCV 艺术算法（胶片/复古/人像/梦幻/电影/鲜艳/黑白），含暗角+强度混合 |
| `/api/remove-object` | 物体移除 | OpenCV Telea 图像修复（inpaint），点选区域用周围像素智能填充 |
| `/api/analyze-scene` | 场景分析 | Haar 人脸检测 + 亮度分析 + 清晰度(拉普拉斯方差) + 构图分析，返回真实建议 |

> 这些是**真实算法**，不是占位。风格迁移是传统图像处理（效果不如深度学习风格迁移惊艳，但完全可用、零成本、离线可跑）。想要更强效果，可在 `app.py` 的 `apply_style` 里替换成深度学习模型（见文末升级路径）。

## 快速启动（本机已部署并实测通过 ✅）

> 部署环境：Windows + Python 3.13.14，实测版本 fastapi 0.165 / opencv 5.1 / numpy 2.5.5。
> 三个 AI 端点均已用真实图片端到端验证通过。

### 方式一：一键启动（推荐）
**双击本目录下的 `start_server.bat`** 即可。它会自动检查依赖、缺则安装、打印本机 IP、然后启动服务。看到 `Uvicorn running on http://0.0.0.0:8000` 就成功了。按 `Ctrl+C` 停止。

### 方式二：命令行启动
在本目录（`server/`）打开终端：
```bash
# 首次安装依赖（阿里云源最快）
python -m pip install -i https://mirrors.aliyun.com/pypi/simple/ -r requirements.txt
# 启动服务
python -m uvicorn app:app --host 0.0.0.0 --port 8000
```

### 验证
浏览器打开 `http://localhost:8000/health`，看到 `{"status":"ok","version":"1.0.0"}` 即正常。

## 让 iPhone 连上后端

1. 确保 **运行后端的电脑和 iPhone 在同一个 WiFi**。
2. 本机当前 WLAN 的局域网 IP 是 **`192.168.0.103`**（可能随 WiFi 变化，重连后可用 `start_server.bat` 查看或 `ipconfig` 查 IPv4）。
3. 把 IP 填进 iOS 工程的 `Utilities/Constants.swift`：
   ```swift
   static let apiBaseURL = "http://192.168.0.103:8000"   // 真机连电脑；模拟器用 localhost
   ```
4. 用数据线把 App 跑到你手机上（手册第 4 步），AI 功能就会调用这个后端。

> ⚠️ iPhone 默认不允许访问明文 HTTP（ATS 限制）。真机调试需要在 Info.plist 加一段允许任意域名（见下方）。

### iPhone 访问 HTTP 的配置（开发调试用）
在 `Info.plist` 的 `<dict>` 内加入：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```
> 仅供开发调试。正式上架应改用 HTTPS 域名，并移除这段配置。

## 升级到更强的 AI（可选）

当前用 OpenCV 传统算法。要更惊艳的效果，可替换 `apply_style` 函数：

- **深度学习风格迁移**：接 Stable Diffusion / 云 API，把请求转发给模型，返回结果图
- **更精准物体移除**：接 LaMa / inpainting 大模型，mask 由用户点选生成（代码已生成 mask，直接喂给模型即可）
- **更强场景理解**：接多模态大模型，把图片和提示词发过去，让它返回结构化建议

接口格式不用改（请求/响应结构已固定），只换 `app.py` 里对应函数的实现即可。iOS 端无需改动。

## 目录结构
```
server/
├── app.py               # 完整服务（4 个接口 + 全部算法）
├── requirements.txt     # 依赖
├── start_server.bat     # Windows 一键启动脚本（双击即可）
└── README.md            # 本说明
```
