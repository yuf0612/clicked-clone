# 06 · AI 后端联调 / 服务升级指南

当前工程的 AI 三大能力（风格迁移、移除物体、场景分析）**已经用真实算法实现**，默认走配套的 Python 后端（`server/app.py`），断网自动降级到本地算法。本文档讲：①如何让 App 连上后端；②如何把算法升级成更强的深度学习模型；③订阅配置。

---

## 一、端到端联调（让 App 连上 AI 后端）

### 1.1 启动后端
```bash
cd server
pip install -r requirements.txt
python app.py
# 看到 Uvicorn running on http://0.0.0.0:8000 即成功
```
自检：`浏览器打开 http://<电脑IP>:8000/health`，返回 `{"status":"ok"}` 即正常。详见 `server/README.md`。

### 1.2 配置 App 连接地址
打开 `ClickedClone/Utilities/Constants.swift`，修改 `apiBaseURL`：

```swift
// 模拟器访问本机：localhost 即可
static let apiBaseURL = "http://localhost:8000"
// 真机访问电脑：改成电脑在局域网的 IP（真机与电脑需同一 Wi-Fi）
// static let apiBaseURL = "http://192.168.1.10:8000"
```

> Info.plist 已配置 `NSAllowsArbitraryLoads = true` 允许 HTTP 局域网访问。正式上架应改用 HTTPS 并移除该配置。

### 1.3 验证三大功能
| 功能 | 入口 | 预期 |
|------|------|------|
| 风格迁移 | 编辑器 → AI 风格 → 选胶片/复古等 | 返回处理后图片，状态提示"AI 风格应用成功" |
| 移除物体 | 编辑器 → 移除物体 → 点选 → 执行移除 | 点选处被周围像素填充 |
| 场景分析 | 相机 → 分析场景 | 返回"光线/构图/清晰度"真实建议 |

看到状态提示带"离线模式"字样，说明后端没连上、走了本地降级——检查 IP 和后端是否启动。

### 1.4 调用链（改哪不影响谁）
```
View → ViewModel → AIService → APIClient → 后端 /api/* → OpenCV 算法
                            └→ 失败时：AIService 本地降级（Core Image / 几何算法）
```
- `APIClient.swift`：只负责网络（超时、重试、缓存、错误）
- `AIService.swift`：编排"先网络、后降级"，并管理免费额度
- 两者职责分离，升级算法只需改后端，App 端零改动

---

## 二、升级到更强的 AI 算法（可选）

> ⚠️ 服务商、价格、API 会变化，接入前请查官网最新文档。以下是选型思路和接入范式。

### 2.1 风格迁移 / 移除物体（图像生成类）
- **候选**：Replicate、fal.ai、Stability AI、腾讯云/阿里云图像 API，或自建 Stable Diffusion + inpainting
- **做法**：只改后端 `server/app.py` 里的 `apply_style()` / `remove_object()` 函数，替换成调用外部 API 或加载深度学习模型。App 端完全不用改（请求/响应格式保持一致即可）。
- **注意**：付费 Key 只放服务端，绝不写进 App。

### 2.2 场景分析（多模态类）
- 当前是 Haar 人脸检测 + 亮度/构图/清晰度的结构化分析，稳定但"不那么智能"。
- 升级：把 `server/app.py` 的 `analyze_scene()` 改成调用视觉大模型，提示词要求输出与当前相同的 JSON 结构（`hints[]` + `quality_score`），App 端无需改动。

### 2.3 精准姿态对齐（最大技术门槛）
- 当前：Vision 人脸关键点 + 大小/居中度评分（免费，精度一般）。
- 升级：接入 FaceUnity / ARKit（仅真机）/ 自研人体关键点模型，改 `Services/FaceDetectionService.swift` 的 `alignmentScore`。
- 这是对标 Clicked "照着样片摆姿势 + 身体对齐自动快门"最难还原的一环。

### 2.4 高级 LUT 滤镜（提升画质）
Clicked 的滤镜很可能是 `.cube` LUT 文件，效果比系统 CIFilter 更专业：

```swift
func applyLUT(_ lutName: String, to image: UIImage) -> UIImage {
    guard let lutURL = Bundle.main.url(forResource: lutName, withExtension: "cube"),
          let lutData = try? Data(contentsOf: lutURL),
          let ciImage = CIImage(image: image),
          let filter = CIFilter(name: "CIColorCubeWithColorSpace") else { return image }
    let cubeData = parseCube(lutData)          // 需自行实现或用现成库解析 .cube
    filter.setValue(cubeData, forKey: "inputCubeData")
    filter.setValue(64, forKey: "inputCubeDimension")
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    let context = CIContext()
    guard let out = filter.outputImage,
          let cg = context.createCGImage(out, from: out.extent) else { return image }
    return UIImage(cgImage: cg)
}
```
把 `.cube` 文件放进 `Resources/` 即可。

---

## 三、接入订阅（StoreKit 2）

框架代码已完整写好，你只需配置：

### 3.1 注册与配置
1. 加入 **Apple Developer Program**（¥688/年）
2. 登录 [App Store Connect](https://appstoreconnect.apple.com)
3. 创建 App（Bundle ID 要和 `project.yml` / 代码里一致）
4. 在「App 内购买项目」创建 4 个产品，Product ID 必须与 `Utilities/Constants.swift` 完全一致：
   - `com.yourcompany.clickedclone.pro.weekly`
   - `com.yourcompany.clickedclone.pro.monthly`
   - `com.yourcompany.clickedclone.pro.annual`
   - `com.yourcompany.clickedclone.pro.lifetime`

### 3.2 测试
- 在 App Store Connect 创建「沙盒测试账号」
- 真机设置 → App Store → 沙盒账号登录，测试购买/恢复（不扣真钱）

### 3.3 提交审核准备
- 隐私政策 URL（必需）、App 截图、描述、关键词、订阅条款链接

---

## 四、安全提醒（重要）

1. **付费 API Key 绝不写进 App**：会被反编译提取盗刷，放服务端。
2. **图片上传要告知用户**：在隐私政策里说明，按需获取同意。
3. **设置消费上限**：在 AI 服务商后台设置预算告警。
4. **订阅服务端校验**（进阶）：重要产品应把购买凭证发服务端校验，防越狱破解。
5. **正式上架改 HTTPS**：移除 Info.plist 的 `NSAllowsArbitraryLoads`，后端部署到 cloud-service 等提供 HTTPS 的托管服务。

---

## 五、升级优先级建议

1. 先跑通**现有后端**（零成本，已完成算法）
2. 想要更惊艳效果 → 升级 **AI 风格**（最容易，效果提升明显）
3. 想要更智能建议 → 升级 **场景分析**（多模态模型）
4. 想要对标 Clicked 核心体验 → 升级 **姿态对齐**（技术门槛最高）
