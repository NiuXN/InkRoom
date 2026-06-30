# 墨斋 · InkRoom

一款基于 SwiftUI 原生开发的、专注于本地书源的高质感私人书房阅读器。

---

## ✨ 特色

- **纯原生体验**：100% SwiftUI 打造，流畅顺滑，系统级响应
- **多端适配**：支持 iPhone / iPad / Mac，布局随屏幕尺寸智能变化
- **横竖屏切换**：完美支持横竖屏切换，阅读、书架布局自动优化
- **Wi-Fi 传书**：局域网内浏览器上传，快速导入 EPUB / TXT
- **沉浸阅读**：像素级排版控制，字号、行距、字距自由调节
- **听书功能**：系统 TTS 语音朗读，后台播放、锁屏控制、朗读高亮
- **书内搜索**：全文关键词搜索，一键跳转到对应页面
- **阅读统计**：自动记录阅读时长，今日/本周/总时长、连续天数一目了然
- **桌面小组件**：主屏幕 / 通知中心快速继续阅读，支持多种尺寸
- **书签管理**：阅读中随手添加书签，目录侧栏切换查看
- **主题跟随**：支持浅色 / 深色 / 跟随系统三种外观模式
- **隐私至上**：零数据收集，零后台服务，书籍全部本地存储

---

## 📱 平台支持

| 平台 | 版本要求 | 状态 |
|------|---------|------|
| iOS | 17.0+ | ✅ 支持 |
| iPadOS | 17.0+ | ✅ 支持 |
| macOS | 14.0+ | ✅ 支持 |

---

## 🚀 快速开始

### 环境要求

- Xcode 16.0+
- Swift 5.9+
- iOS 17.0+ / macOS 14.0+

### 安装依赖

项目使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 管理项目配置。

```bash
# 安装 XcodeGen（如果尚未安装）
brew install xcodegen

# 生成 Xcode 项目
cd InkRoom
xcodegen generate
```

### 编译运行

1. 双击打开 `InkRoom/InkRoom.xcodeproj`
2. 选择对应平台的 Scheme（`InkRoom_iOS` / `InkRoom_macOS`）
3. 点击运行或按下 `⌘R`

---

## 🖥️ Xcode 运行步骤（详细）

### 1. 准备环境

| 项目 | 要求 |
|------|------|
| macOS | 14.0+（推荐最新版） |
| Xcode | 16.0+ |
| 命令行工具 | `xcode-select --install` |
| XcodeGen | `brew install xcodegen` |

首次克隆仓库后，**必须先执行** `xcodegen generate` 生成 `.xcodeproj`。若新增或删除了 Swift 源文件，也需重新执行该命令。

```bash
cd InkRoom
xcodegen generate
open InkRoom.xcodeproj
```

### 2. 选择 Scheme 与运行目标

Xcode 顶部工具栏左侧：

| Scheme | 用途 | 典型运行目标 |
|--------|------|-------------|
| `InkRoom_iOS` | iPhone / iPad | 任意 iOS 模拟器，或已连接的 iPhone |
| `InkRoom_macOS` | Mac 原生应用 | My Mac |

**iOS 模拟器示例**：`iPhone 16` / `iPad Pro 13-inch`  
**真机调试**：用数据线连接设备 → 在目标列表中选择你的 iPhone → 首次需在 **Signing & Capabilities** 中登录 Apple ID。

### 3. 配置签名（真机 / 归档必需）

1. 左侧选中工程 **InkRoom** → **TARGETS** → **InkRoom**
2. 打开 **Signing & Capabilities**
3. 勾选 **Automatically manage signing**
4. **Team** 选择你的 Apple Developer 账号（个人免费账号可用于本机调试）
5. 确认 **Bundle Identifier** 为 `com.inkroom.app`（或与 `project.yml` 一致）

Widget Extension（`InkRoomWidget`）需单独配置 Team，Bundle ID 为 `com.inkroom.app.widget`。

### 4. 运行与调试

| 操作 | 快捷键 |
|------|--------|
| 运行 | `⌘R` |
| 停止 | `⌘.` |
| 清理构建 | `⇧⌘K` |
| 重新构建 | `⌘B` |

**macOS**：运行后会打开独立窗口；系统设置可在 `⌘,` 或菜单 **InkRoom → Settings** 中打开。  
**iOS**：底部 Tab 切换「书架 / 分类 / 统计 / 我的」。

### 5. 命令行构建（CI / 快速验证）

```bash
cd InkRoom

# macOS
xcodebuild -scheme InkRoom_macOS -destination 'platform=macOS' build

# iOS 模拟器
xcodebuild -scheme InkRoom_iOS -destination 'generic/platform=iOS Simulator' build
```

### 6. 常见问题

| 现象 | 处理方式 |
|------|----------|
| 找不到新加的 Swift 文件 | 运行 `xcodegen generate` 后重新打开工程 |
| Signing 报错 | 检查 Team、Bundle ID 是否与已有证书冲突 |
| 模拟器无法启动 | Xcode → Settings → Platforms 下载对应 iOS 运行时 |
| SPM 依赖拉取失败 | File → Packages → Reset Package Caches |

---

## 🏪 App Store 发布与版本升级

### 版本号管理

版本在 `InkRoom/project.yml` 中统一配置：

```yaml
settings:
  base:
    MARKETING_VERSION: "1.0.0"   # 用户可见版本（CFBundleShortVersionString）
    CURRENT_PROJECT_VERSION: "1" # 构建号（CFBundleVersion）
```

**发版前务必：**

1. 递增 `MARKETING_VERSION`（例如 `1.0.0` → `1.0.1`）
2. 递增 `CURRENT_PROJECT_VERSION`（每次上传 App Store Connect 至少 +1）
3. 执行 `xcodegen generate` 同步到 Xcode 工程

### 归档与上传

1. Scheme 选 **Any iOS Device** 或 **My Mac**，菜单 **Product → Archive**
2. 归档完成后在 **Organizer** 中 **Distribute App**
3. 选择 **App Store Connect** → Upload
4. 登录 [App Store Connect](https://appstoreconnect.apple.com) 提交 TestFlight / 审核

iOS 与 macOS 可分别归档上传，共用同一 Bundle ID 家族。

### 应用内「检查更新」

墨斋内置 App Store 更新检查，通过 Apple 公开 **iTunes Lookup API** 获取最新版本：

- **自动检查**：启动时若开启「自动检查更新」，每 24 小时最多检查一次；发现新版本会弹窗提醒
- **手动检查**：**我的 → 检查 App Store 更新**
- **跳转更新**：点击「前往 App Store 更新」打开 App Store 应用页

相关配置位于 `Sources/Utilities/AppConfig.swift`：

```swift
enum AppConfig {
    static let bundleIdentifier = "com.inkroom.app"
    static let appStoreCountryCode = "cn"           // Lookup 地区
    static let appStoreFallbackURL: String? = nil   // 上架后可选填 App Store 链接
    static let proUpgradeURL: String? = nil         // Pro 订阅页（可选）
}
```

**上架后建议：**

1. 将 `appStoreFallbackURL` 设为应用页，例如 `https://apps.apple.com/app/id1234567890`（Lookup 成功时可留空）
2. 若提供 Pro 内购，填写 `proUpgradeURL`
3. 在 TestFlight / 正式版验证：**设置 → 检查 App Store 更新** 能正确识别新版本

> 应用未上架时，检查更新会提示「暂未在 App Store 找到该应用」，属正常现象。

### 升级发布 Checklist

- [ ] 更新 `project.yml` 版本号并 `xcodegen generate`
- [ ] 更新 README / 更新日志（如有）
- [ ] 本地 macOS + iOS 编译通过
- [ ] Archive 上传 App Store Connect
- [ ] 填写「此版本的新增内容」
- [ ] TestFlight 内测通过后提交审核
- [ ] 审核通过后确认应用内更新检查能发现新版本

---

## 📂 项目结构

```
InkRoom/
├── Sources/
│   ├── App/                 # 应用入口 & 主容器
│   │   ├── InkRoomApp.swift       # App 入口、主题、macOS 菜单
│   │   └── ContentView.swift      # 响应式主容器（Tab/SplitView）
│   ├── Models/              # 数据模型
│   │   ├── Book.swift             # 书籍、分类、章节模型
│   │   ├── Bookmark.swift         # 书签模型
│   │   ├── ReadingSession.swift   # 阅读会话模型（统计用）
│   │   ├── ReadingSettings.swift  # 阅读设置模型
│   │   └── WidgetData.swift       # 小组件共享数据模型
│   ├── Services/            # 业务服务
│   │   ├── AppStoreUpdateService.swift # App Store 版本检查与跳转
│   │   ├── BookParserService.swift    # EPUB/TXT 解析（含缓存）
│   │   ├── DatabaseService.swift      # SQLite 数据库（书籍/分类/书签/会话）
│   │   ├── TTSService.swift           # 语音朗读服务（AVSpeechSynthesizer）
│   │   └── WiFiTransferService.swift  # Wi-Fi 传书本地服务器
│   ├── Utilities/           # 工具类
│   │   ├── AppConfig.swift            # Bundle ID、App Store 配置
│   │   ├── AppVersion.swift           # 版本号比较
│   │   ├── EPUBXMLParser.swift        # EPUB XML 解析
│   │   ├── QRCodeGenerator.swift      # Wi-Fi 传书二维码
│   │   ├── ScrollReadingPosition.swift # 滚动模式页码估算
│   │   ├── AdaptiveLayout.swift       # 响应式布局（尺寸分类、跨平台图片）
│   │   └── Color+InkRoom.swift        # 墨斋主题色体系
│   ├── ViewModels/          # 视图模型
│   │   ├── LibraryViewModel.swift     # 书架/分类/书签数据管理
│   │   ├── ReaderViewModel.swift      # 阅读器状态与进度
│   │   └── SettingsViewModel.swift    # 阅读/TTS/外观设置
│   └── Views/               # 界面层
│       ├── Library/              # 书架（Grid/List、导入）
│       ├── Reader/               # 阅读器（翻页/搜索/书签/TTS）
│       ├── BookDetail/           # 书籍详情
│       ├── Categories/           # 分类管理
│       ├── Settings/             # 设置
│       ├── Statistics/           # 阅读统计
│       └── Components/           # 通用组件（BookCard、ProgressBar）
├── Widget/                  # 桌面小组件 Extension
│   ├── InkRoomWidget.swift        # Widget 配置 & Timeline Provider
│   ├── InkRoomWidgetView.swift    # Small/Medium/Large 三种尺寸 UI
│   └── InkRoomWidgetBundle.swift  # Widget Bundle 入口
├── Resources/               # 资源文件
└── project.yml              # XcodeGen 配置
```

---

## 🧩 核心模块

### 📚 智能书房
- Grid / List 双视图切换
- 智能分组：最近阅读、未读、在读、已读
- 多维度筛选与排序
- 封面异步加载，滚动流畅不卡顿
- Wi-Fi 传书后书架自动刷新

### 📖 沉浸阅读
- **阅读主题**：羊皮纸、护眼、夜间三种主题实时切换
- **排版微调**：字号、行距、字距自由调节
- **翻页方式**：左右滑动 / 点击翻页 / 垂直滚动
- **TXT 智能断章**：支持 20+ 种章节标题模式识别
- **书内搜索**：全文关键词搜索，结果高亮，点击跳转
- **书签管理**：阅读中添加/移除书签，目录侧栏切换查看章节/书签/搜索

### 🎧 听书功能
- 系统 TTS 语音朗读，完全离线
- 播放/暂停/上一页/下一页控制
- 语速调节（0.3x ~ 0.8x）
- 定时停止（15/30/60 分钟）
- 朗读高亮：当前朗读字词实时高亮
- 后台播放 + 锁屏/控制中心远程控制（iOS/iPadOS/macOS）

### 📊 阅读统计
- 自动记录每次阅读会话时长和翻页数
- 今日阅读时长、本周时长、总时长统计
- 连续阅读天数追踪
- 按书籍聚合展示阅读时长

### 📱 桌面小组件
- **Small**：当前在读书籍 + 进度
- **Medium**：书名、作者、章节、进度条、继续阅读入口
- **Large**：当前书籍 + 最近阅读列表（最多 3 本）
- 通过 App Group + UserDefaults 共享数据，阅读进度更新时自动刷新

### 🎛️ 响应式布局
- **compact**：iPhone 竖屏，底部 Tab Bar 导航
- **regular**：iPad 竖屏 / iPhone 横屏，侧边栏 + 内容双栏
- **expanded**：iPad 横屏 / Mac 宽窗口，优化空间利用

---

## 🛠️ 技术栈

- **框架**：SwiftUI
- **数据持久化**：SQLite.swift
- **网络服务**：Swifter（Wi-Fi 传书本地服务器）
- **文件解析**：ZIPFoundation（EPUB 解析）
- **语音合成**：AVSpeechSynthesizer（系统 TTS）
- **小组件**：WidgetKit
- **项目管理**：XcodeGen

---

## ⚡ 性能优化

- **解析缓存**：BookParserService 按文件路径缓存解析结果，翻页不再重新解析整本书
- **异步封面加载**：CoverImageView 组件异步加载封面图片，不阻塞主线程
- **数据库优化**：修复 N+1 查询，批量插入使用事务，UUID 解析失败记录警告
- **懒加载**：LazyVGrid / LazyVStack + 分页加载章节内容，减少内存占用

---

## 📝 开发说明

### 添加新页面

1. 在 `Sources/Views/` 下创建对应目录和 View
2. 在 `ContentView.swift` 中注册导航路由
3. 如有需要，在 `ViewModels/` 中添加对应 ViewModel
4. 运行 `xcodegen generate` 重新生成项目文件

### 响应式布局规范

所有页面应遵循以下规范以保证多端体验：

- 使用 `@Environment(\.layoutSizeClass)` 获取尺寸类
- 使用 `@Environment(\.isLandscape)` 判断横竖屏
- 内容区域设置最大宽度，避免超宽屏拉伸
- 重要操作按钮保持在拇指可达区域

### 跨平台开发规范

- 平台差异 API 使用 `#if os(iOS)` / `#if os(macOS)` 条件编译
- 图片类型使用 `PlatformImage`（UIImage/NSImage 自动适配）
- 使用 `GeometryReader` 获取视图尺寸，避免直接使用 `UIScreen`

---

## 📄 License

MIT License
