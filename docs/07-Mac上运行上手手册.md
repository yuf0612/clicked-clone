# 上手手册：如何把工程跑起来（给不会写代码的你）

这份手册手把手教你在 Mac 上把 ClickedClone 跑起来。**照着一步步做就行**，遇到看不懂的术语不用管，照做即可。

---

## 第 0 步：先搞清楚三个现实问题

在动手之前，请先接受三个事实（这决定了你能做到哪一步）：

1. **必须有 Mac 电脑**。iOS _APP 只能在苹果电脑上的 Xcode 里编译。Windows / 普通 PC 做不了。如果你没有 Mac，可以考虑：租一台云 Mac（如 MacinCloud）、找有 Mac 的朋友帮忙、或者先做网页版原型（我可以另做）。
2. **想装到手机 / 上架 App Store，需要苹果开发者账号**，年费 688 元/年。只是想在电脑模拟器上看效果，则**不需要**付费账号，用免费 Apple ID 即可。
3. **AI 功能要完整体验，需启动配套的 Python 后端**（零成本、无需 API Key，见 `server/README.md`）；订阅收费需在 App Store Connect 里创建产品并审核。**首次跑起来不需要它们**：后端连不上时 App 会自动用本地算法降级，核心流程照常可用。

---

## 第 1 步：安装必备软件

1. **安装 Xcode**（苹果官方开发工具）
   - 打开 Mac 上的「App Store」，搜索 `Xcode`，点击安装。
   - 体积很大（约 7GB+），耐心等。
   - 装好后打开一次 Xcode，同意许可协议。

2. **安装 XcodeGen**（生成工程文件的工具，省得手动配置）
   - 先装 Homebrew（如果没装过）。打开「终端」，粘贴下面这行并回车：
     ```
     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
     ```
   - 装好 Homebrew 后，在终端粘贴：
     ```
     brew install xcodegen
     ```

---

## 第 2 步：生成 Xcode 工程

1. 把整个 `ClickedClone` 文件夹拷贝到你的 Mac 上（比如放到桌面）。
2. 打开「终端」，进入这个文件夹。假设你放在桌面，命令是：
   ```
   cd ~/Desktop/ClickedClone
   ```
3. 生成工程文件：
   ```
   xcodegen generate
   ```
4. 看到 `Generated project ClickedClone.xcodeproj` 之类的提示就成功了。此时文件夹里会多出一个 **ClickedClone.xcodeproj**（蓝色图标）。

> 如果报 `command not found: xcodegen`，说明第 1 步的 Homebrew 没装好，回去重做。

---

## 第 3 步：在模拟器里运行

1. 双击打开 `ClickedClone.xcodeproj`，Xcode 会启动。
2. 在 Xcode 顶部工具栏，找到设备选择框（类似 `ClickedClone > iPhone 16 Pro`），点开选一个 **iPhone 模拟器**（比如 iPhone 16 Pro）。不用真机。
3. 点击左上角的 **▶（运行）** 按钮，或者按 `Command + R`。
4. 等它编译完（第一次要几分钟），模拟器会弹出来，你就能看到 App 了！

**能体验到的功能：**
- 新手引导页
- 相机界面（模拟器里相机是黑的/测试画面，真机上才是真实相机）
- 编辑器：选滤镜、调参数、美颜、AI 风格（后端连不上时用本地算法降级）
- 相册、个人中心、订阅页（UI 可看，购买需配置）

> ⚠️ **相机、人脸自动快门必须用真机才能体验**。模拟器没有真实摄像头。AI 三大功能在模拟器里也能用（走后端或本地降级）。

---

## 第 4 步（可选）：装到自己的 iPhone 上

1. 用数据线把 iPhone 连到 Mac，解锁手机，点「信任此电脑」。
2. Xcode 顶部设备选择框里选你的 iPhone（真机名字）。
3. 首次需要**签名**：点左侧目录树最上面的蓝色 `ClickedClone` 项目图标 → 选 `Signing & Capabilities` 标签 → 勾选 `Automatically manage signing` → Team 选你的 Apple ID（没有就点 Add Account 用免费 Apple ID 登录）。
4. 改一下 Bundle Identifier（因为 `com.yourcompany...` 可能被占用）：把它改成唯一的，比如 `com.你的名字.clickedclone`。
5. 再点 ▶ 运行，App 就装到你手机上了。免费 Apple ID 签名的 App **7 天后会过期**，需要重新运行一次。

---

## 第 5 步（可选，进阶）：启动 AI 后端与订阅

### 5.1 启动真实 AI 后端（零成本，无需 API Key）
AI 三大功能已内置真实算法，按下面步骤即可端到端体验：

1. 在 Mac（或任意电脑）上进入 `server/` 目录，运行 `pip install -r requirements.txt`。
2. 运行 `python app.py`，看到 `Uvicorn running on http://0.0.0.0:8000` 即启动成功。
3. 打开 `ClickedClone/Utilities/Constants.swift`，把 `apiBaseURL` 改成这台电脑的局域网 IP（如 `http://192.168.1.10:8000`），真机和电脑需在同一 Wi-Fi。
4. 在 App 里点「分析场景」「AI 风格」「移除物体」，走的就是后端真实算法。

> 后端没启动时 App 不会崩，会自动用本地算法降级，只是效果弱一些。详见 `server/README.md`。

### 5.2 升级到更强 AI / 接入订阅（可选）
- 想要深度学习级风格迁移（比 OpenCV 更惊艳），按 `docs/06-第三方SDK接入指南.md` 在服务端替换算法，App 端无需改动。
- 订阅需在 App Store Connect 创建产品并通过审核，见 `docs/06`。
- ⚠️ 不要把付费 API Key 写在 App 里（会被人提取盗用），应放服务端。

### 5.2 启用订阅收费
- 需要 688 元/年的苹果开发者账号。
- 去 Apple Developer / App Store Connect 创建订阅产品，产品 ID 必须和 `Utilities/Constants.swift` 里的一致。
- 详细步骤见 `docs/05-成本估算与商业化.md` 和 `docs/06-第三方SDK接入指南.md`。

---

## 常见问题（踩坑指南）

| 现象 | 原因 / 解决 |
|------|------------|
| `xcodegen: command not found` | Homebrew 没装好，重做第 1 步 |
| 编译时报 `Signing requires a development team` | 第 4 步的签名没配置，按第 4 步做 |
| 模拟器里相机是黑的 | 正常，模拟器没有真摄像头，用真机测试 |
| `No such module` 之类报错 | 确认用 Xcode 打开的是 `.xcodeproj` 不是文件夹 |
| Bundle ID 冲突 | 第 4.4 步改成唯一 ID |
| 改了代码没生效 | 清理构建：`Command + Shift + K`，再运行 |

---

## 我改不动代码怎么办？

这个工程的代码都已经写好并做了编译检查。你只需要：
1. 按上面步骤跑起来。
2. 想改文案、颜色，告诉我，我帮你改。
3. 想加功能、接 AI、接订阅，也告诉我，我帮你写。

你负责"跑"和"提需求"，我负责"写和改"。
