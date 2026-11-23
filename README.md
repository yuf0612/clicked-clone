# ClickedClone —— 项目总览

一款面向"不会拍照的人"的 AI 摄影 APP 完整工程，功能对标 Clicked: Camera Editor。**所有功能均为真实可用实现，非占位演示。**

> **重要**：这是可运行的 SwiftUI 工程源码 + Python AI 后端 + 全套产品文档。
> - iOS 端运行方法见 [`docs/07-Mac上运行上手手册.md`](docs/07-Mac上运行上手手册.md)
> - AI 后端部署方法见 [`server/README.md`](server/README.md)
> - 端到端联调（App 连后端）见 [`docs/06-第三方SDK接入指南.md`](docs/06-第三方SDK接入指南.md)

---

## 一、这个工程包含什么

### 1. iOS 客户端（SwiftUI，iOS 17+）
- **拍摄引导**：相机预览、样片半透明叠加（4 档强度）、定时连拍、Smart Guide 基于 Vision 人脸关键点的真实对齐评分与自动快门、PicScan 实时场景分析
- **图片编辑**：55 个滤镜预设、强度滑块、6 项手动调整、一键美颜、**真实 AI 风格迁移**、**真实点选物体移除**、高清导出
- **辅助功能**：新手引导页、作品相册、个人中心、StoreKit 订阅付费墙
- **生产级网络层**：URLSession async/await + 超时 + 重试 + 缓存 + 本地降级（后端连不上时自动用本地算法兜底，功能不中断）

### 2. Python AI 后端（FastAPI + OpenCV，零成本）
三大 AI 能力全部是**真实开源算法**，无需付费 API Key：

| 端点 | 功能 | 算法 |
|------|------|------|
| `/api/style` | 风格迁移 | 7 种 OpenCV 艺术处理链（胶片/复古/人像/梦幻/电影感/鲜艳/黑白）|
| `/api/remove-object` | 物体移除 | OpenCV Telea 图像修复（inpaint）|
| `/api/analyze-scene` | 场景分析 | Haar 人脸检测 + 亮度/构图/清晰度真实分析 |
| `/health` | 健康检查 | 服务状态 |

### 3. 文档部分（`docs/`）
| 文档 | 内容 |
|------|------|
| 01-产品需求文档PRD | 功能清单、用户故事、验收标准 |
| 02-技术架构设计 | 分层架构、技术选型、数据流、端到端调用链 |
| 03-UI设计与交互说明 | 页面结构、设计语言、交互细节 |
| 04-开发排期与里程碑 | 分阶段开发计划、人力估算 |
| 05-成本估算与商业化 | 一次性/持续成本、定价、收入模型 |
| 06-第三方SDK接入指南 | 后端联调、升级到更强 AI、订阅接入 |
| 07-Mac上运行上手手册 | 如何把 iOS 工程跑起来（先看这个）|

---

## 二、目录结构

```
ClickedClone/
├── project.yml                       # XcodeGen 配置（生成 .xcodeproj）
├── README.md                         # 本文件
├── docs/                             # 全套产品文档
│   └── 01~07-*.md
├── server/                           # Python AI 后端
│   ├── app.py                        # FastAPI 服务（4 个真实端点）
│   ├── requirements.txt              # 依赖清单
│   └── README.md                     # 后端部署说明
└── ClickedClone/                     # iOS 源码根目录
    ├── App/                          # 入口、导航、全局状态
    ├── Models/                       # 数据模型（含网络请求/响应 Codable 模型）
    ├── ViewModels/                   # 相机、编辑器、订阅逻辑
    ├── Views/                        # 6 个界面
    ├── Services/
    │   ├── APIClient.swift           # 生产级网络层（async/await+重试+缓存）
    │   ├── AIService.swift           # AI 能力编排（网络调用+本地降级）
    │   ├── CameraService.swift       # AVFoundation 相机 + 取景帧捕获
    │   ├── FaceDetectionService.swift# Vision 人脸关键点 + 对齐评分
    │   ├── ImageProcessor.swift      # Core Image 滤镜链
    │   ├── PhotoLibraryService.swift # 相册存储
    │   └── PresetData.swift          # 55 个滤镜预设
    ├── Utilities/                    # 常量、扩展
    └── Resources/                    # Info.plist、entitlements
```

---

## 三、端到端怎么跑起来

1. **启动后端**：`cd server && pip install -r requirements.txt && python app.py`（见 `server/README.md`）
2. **配置 App**：把 `Constants.swift` 里的 `apiBaseURL` 改成你电脑的局域网 IP
3. **运行 iOS App**：按 `docs/07` 在 Mac 的 Xcode 里跑起来（真机才能用相机）
4. **验证**：App 里点"分析场景"/"AI 风格"/"移除物体"，能联网就走后端真实算法，断网自动本地降级

> 后端连不上也不会崩——App 会自动用本地 Core Image / 几何算法兜底，只是效果弱一些。

---

## 四、从零到上架还要做什么（诚实清单）

这个工程让你**跳过绝大部分编码工作**，但以下必须你本人或团队完成：

| 事项 | 为什么必须你做 | 预估 |
|------|--------------|------|
| 有 Mac 电脑 | iOS 只能在 Mac 上编译 | 已有 / 购买 |
| 苹果开发者账号 | 装真机、上架必需 | ¥688/年 |
| 苹果审核 | App Store Connect 配置、隐私政策、截图、审核 | 数天 |
| 服务器部署（可选） | 后端要公网可访问需部署到 cloud-service 等 | 视用量 |
| 更强 AI（可选） | 想要深度学习级风格迁移可接付费模型 | 视用量 |

详见 `docs/04`、`docs/05`、`docs/06`。

---

## 五、下一步建议

1. **先看** `docs/07-Mac上运行上手手册.md`，把 iOS 工程跑起来看到实物。
2. **启动后端**，把三大 AI 功能端到端点一遍。
3. 体验后把想改的地方告诉我（文案、颜色、功能增减、接更强 AI）。

有问题随时问我 —— 你提需求，我改代码。
