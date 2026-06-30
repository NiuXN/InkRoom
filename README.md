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

1. 双击打开 `InkRoom.xcodeproj`
2. 选择对应平台的 Scheme（`InkRoom_iOS` / `InkRoom_macOS`）
3. 点击运行或按下 `⌘R`

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
│   │   ├── BookParserService.swift    # EPUB/TXT 解析（含缓存）
│   │   ├── DatabaseService.swift      # SQLite 数据库（书籍/分类/书签/会话）
│   │   ├── TTSService.swift           # 语音朗读服务（AVSpeechSynthesizer）
│   │   └── WiFiTransferService.swift  # Wi-Fi 传书本地服务器
│   ├── Utilities/           # 工具类
│   │   ├── AdaptiveLayout.swift       # 响应式布局（尺寸分类、跨平台图片）
│   │   └── Color+InkRoom.swift        # 墨斋主题色体系
│   ├── ViewModels/          # 视图模型
│   │   ├── LibraryViewModel.swift     # 书架/分类/书签数据管理
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
