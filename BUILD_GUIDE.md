# 小酥 APP 编译指南

## 项目概览

| 项目 | 值 |
|------|-----|
| 框架 | Flutter 3.10+ |
| Dart SDK | 3.0+（`>=3.0.0 <4.0.0`） |
| 最低 Android SDK | 24（Android 7.0） |
| 目标 Android SDK | 34（Android 14） |
| 最低 iOS | 15.0 |
| 包名 | `com.xiaosu.app` |
| 当前版本 | 2.0.0（build 20） |
| Gradle 版本 | 8.4-all |
| Android Gradle Plugin | 8.1.2 |
| Kotlin 版本 | 1.9.10 |

---

## 环境准备

### 通用环境

```bash
# 1. 安装 Flutter SDK（推荐 3.19+）
#    macOS / Linux:
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/flutter/bin"

#    Windows: 从 https://docs.flutter.dev/get-started/install 下载安装包

# 2. 检查环境
flutter doctor

# 3. 启用 Flutter 桌面支持（如需桌面端）
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop
```

> **国内用户提示**：建议配置镜像加速，避免下载超时：
> ```bash
> export PUB_HOSTED_URL=https://pub.flutter-io.cn
> export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
> ```

### Android 环境

| 依赖 | 版本要求 |
|------|---------|
| Android Studio | 最新稳定版（推荐 Iguana+） |
| Android SDK | API 34 |
| Android SDK Build-Tools | 34.0.0 |
| JDK | 17（Android Studio 自带或独立安装） |

**配置步骤：**

```bash
# 1. 设置环境变量
export ANDROID_HOME=$HOME/Android/Sdk          # Linux
export ANDROID_HOME=$HOME/Library/Android/sdk   # macOS
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# 2. 用 sdkmanager 确认已安装组件
sdkmanager --list
sdkmanager "platforms;android-34" "build-tools;34.0.0"

# 3. 接受许可证
flutter doctor --android-licenses

# 4. 验证
flutter doctor
```

### iOS 环境（需 macOS）

| 依赖 | 版本要求 |
|------|---------|
| Xcode | 15.0+ |
| CocoaPods | 最新稳定版 |
| Command Line Tools | `xcode-select --install` |

**配置步骤：**

```bash
# 1. 安装 Xcode 并同意许可协议
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept

# 2. 安装 CocoaPods
sudo gem install cocoapods
# 或使用 Homebrew
brew install cocoapods

# 3. 安装 iOS 依赖
cd ios && pod install && cd ..

# 4. 验证
flutter doctor
```

---

## 编译步骤

### Android APK

```bash
# 1. 获取依赖
cd xiaosucore
flutter pub get

# 2. 生成代码（drift、riverpod 等代码生成）
dart run build_runner build --delete-conflicting-outputs

# 3. 编译 Release APK
flutter build apk --release

# 产物路径
# build/app/outputs/flutter-apk/app-release.apk
```

**分 ABI 编译（减小 APK 体积）：**

```bash
# 按 ABI 分别编译，产物体积约为全量的 1/3
flutter build apk --release --split-per-abi

# 产物路径：
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk   (~30% 体积)
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk      (~35% 体积)
# build/app/outputs/flutter-apk/app-x86_64-release.apk         (~40% 体积)
```

> **提示**：目前大多数 Android 设备使用 `arm64-v8a`，优先分发该版本即可。

**Debug 包（快速调试）：**

```bash
flutter run                    # 自动选择连接的设备
flutter run -d <device_id>     # 指定设备
flutter build apk --debug      # 仅构建 debug APK
```

### Android App Bundle（Google Play 上架）

```bash
flutter build appbundle --release
# 产物路径：build/app/outputs/bundle/release/app-release.aab
```

### iOS IPA

```bash
# 1. 获取依赖 & 代码生成
cd xiaosucore
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 2. 安装/更新 iOS 依赖
cd ios && pod install --repo-update && cd ..

# 3. 编译（未签名，用于自签工具）
flutter build ios --release --no-codesign

# 4. 打包 IPA（未签名）
cd build/ios/iphoneos
mkdir Payload
cp -R Runner.app Payload/
zip -r unsigned.ipa Payload
cd ../../..
```

**签名方案：**

| 方案 | 适用场景 | 操作 |
|------|---------|------|
| **Xcode 签名** | 有 Apple Developer 账号 | 用 Xcode 打开 `ios/Runner.xcworkspace`，配置签名后 `Product → Archive` |
| **ESign** | 免费签名（无需电脑） | 将 `unsigned.ipa` 传到手机，用 ESign 重签安装 |
| **AltStore** | 免费签名（7 天续签） | 用 AltServer 将 `unsigned.ipa` 侧载到设备 |
| **TestFlight** | 内测分发 | 通过 Xcode Archive 上传到 App Store Connect |

**Xcode 签名构建（正式版）：**

```bash
# 方式一：命令行
flutter build ipa --release

# 方式二：Xcode GUI
# 1. 打开 ios/Runner.xcworkspace（注意是 .xcworkspace 不是 .xcodeproj）
# 2. 选择 Runner target → Signing & Capabilities → 选择 Team
# 3. Product → Archive → Distribute App
```

---

## 架构说明

### 六层架构

```
┌──────────────────────────────────────────────────────┐
│  Layer 1: Presentation 层（UI）                       │
│  presentation/  — 页面、组件、主题、路由              │
│  ui/            — 传统页面（兼容层）                   │
├──────────────────────────────────────────────────────┤
│  Layer 2: Provider 层（状态管理）                     │
│  providers/     — Riverpod Provider，连接 UI 与业务   │
├──────────────────────────────────────────────────────┤
│  Layer 3: Core 层（核心引擎）                         │
│  core/chat_engine   — 对话引擎（最核心）              │
│  core/agent         — Agent 系统（Supervisor/DAG）    │
│  core/llm           — LLM 多模型路由                  │
│  core/memory        — 记忆中心（RAG/向量存储）        │
│  core/skill         — 技能抽象基类                    │
│  core/gateway       — API 网关（认证/限流/熔断）      │
│  core/task          — 任务调度器                      │
│  core/workflow      — 工作流引擎                      │
│  core/local_llm     — 本地模型推理                    │
│  core/plugin_market — 插件市场                        │
├──────────────────────────────────────────────────────┤
│  Layer 4: Services 层（服务封装）                     │
│  services/llm_provider      — LLM 调用封装           │
│  services/memory_center     — 记忆服务                │
│  services/skill_registry    — 技能注册表              │
│  services/database_service  — 本地数据库              │
│  services/security/         — 安全服务                │
│  services/offline/          — 离线服务                │
│  services/performance/      — 性能监控                │
├──────────────────────────────────────────────────────┤
│  Layer 5: Data 层（数据持久化）                       │
│  data/database/     — Drift 数据库定义                │
│  data/models/       — 数据实体                        │
│  data/repositories/ — 数据仓库                        │
├──────────────────────────────────────────────────────┤
│  Layer 6: Platform 层（平台桥接）                     │
│  platform/          — 各平台原生能力桥接              │
│  ├─ android/        — Android WorkManager 调度        │
│  ├─ ios/            — iOS 后台任务                    │
│  ├─ macos/          — macOS 适配                      │
│  ├─ windows/        — Windows 适配                    │
│  └─ linux/          — Linux 适配                      │
└──────────────────────────────────────────────────────┘
```

### 核心模块列表

| 模块 | 路径 | 说明 |
|------|------|------|
| 对话引擎 | `core/chat_engine.dart` | APP 最核心模块，整合 LLM + 记忆 + 技能，支持流式对话与 Function Calling |
| Agent 系统 | `core/agent/` | Supervisor Agent 多智能体协作，Task DAG 任务编排 |
| LLM 路由 | `core/llm/` | 多模型路由（OpenAI / 通义千问等），自动选择最优模型 |
| 记忆中心 | `core/memory/` | RAG 语义检索，向量存储，Embedding 生成 |
| API 网关 | `core/gateway/` | 统一 API 调用入口，认证/限流/熔断/缓存中间件 |
| 凭证管理 | `core/gateway/credential_manager.dart` | 安全管理各类 API 凭证，支持多 Provider |
| 任务调度 | `core/task/task_scheduler.dart` | 定时任务、周期任务调度 |
| 工作流引擎 | `core/workflow/` | 可编排工作流，支持模板 |
| 技能系统 | `core/skill/` | 技能抽象基类，定义统一的生命周期与工具调用规范 |
| 插件市场 | `core/plugin_market/` | 插件发现与安装 |

### 技能系统

技能系统是小酥的核心能力扩展机制。所有技能继承自 `Skill` 基类，遵循统一的生命周期：

```
uninitialized → initializing → ready → running → ready → ... → disposed
```

**技能注册流程：**

1. 技能类继承 `Skill` 基类，实现 `manifest`（清单）、`tools`（工具列表）、`onInitialize`、`onDispose`
2. 在 `P1SkillRegistry` 中注册技能实例
3. `ChatEngine` 通过 `SkillRegistry` 获取可用工具列表，注入到 LLM 的 Function Calling 中
4. LLM 返回 `tool_call` 时，`ChatEngine` 路由到对应技能执行

**内置技能列表：**

| 技能 | 目录 | 说明 |
|------|------|------|
| 网络搜索 | `skills/web_search/` | 搜索互联网获取最新信息 |
| 图片生成 | `skills/image_gen/` | AI 图片生成 |
| 浏览器 | `skills/browser/` | 浏览器自动化操作 |
| 邮件 | `skills/email/` | 邮件收发 |
| 文档生成 | `skills/doc_gen/` | PDF / Word / PPT 生成 |
| 播客生成 | `skills/podcast/` | 播客音频生成 |
| 视频生成 | `skills/video/` | AI 视频生成 |
| 社交媒体 | `skills/social/` | 小红书 / 微博等平台运营 |
| 飞书集成 | `skills/lark/` | 飞书 API 集成 |
| 话题追踪 | `skills/tracking/` | 话题持续跟踪与简报 |
| 数据图表 | `skills/chart/` | 数据可视化图表生成 |
| TTS 语音 | `skills/tts/` | 文字转语音 |
| 违禁词检测 | `skills/forbidden_word/` | 多平台违禁词检测 |
| 专业域名 | `skills/pro_domain/` | 知识付费 / 域名管理 |
| 代码沙箱 | `skills/code_sandbox/` | 安全代码执行环境 |
| 云同步 | `skills/cloud_sync/` | 数据云同步 |

**技能依赖图：**

```
cloud_sync (P10)    ─┐
forbidden_word (P10) ─┤
chart (P10)          ─┤
email (P20)          ─┼→ lark (P40, 依赖 email)
doc_gen (P20)        ─┤
podcast (P20)        ─┤
web_search (P30)     ─┼→ browser (P30)
                     ─┼→ topic_tracking (P50)
                     ─┼→ pro_domain (P50)
image_gen (P0)       ─┼→ social_media (P30)
                     ─└→ video_gen (P30)
```

---

## 配置 API Key

### 配置方式

小酥支持多种 LLM 服务商，API Key 通过**应用内设置页面**配置，使用安全存储加密保存。

**支持的 Provider：**

| Provider | ID | 需要的凭证 | 说明 |
|----------|----|-----------|------|
| OpenAI | `openai` | API Key | GPT-4 / GPT-3.5 |
| Anthropic | `anthropic` | API Key | Claude 系列 |
| Google AI | `google` | API Key | Gemini 系列 |
| DeepSeek | `deepseek` | API Key | DeepSeek 系列 |
| 智谱 AI | `zhipu` | API Key | GLM 系列 |
| 火山引擎 | `volcengine` | API Key + Token | 豆包大模型 / TTS |
| 橘子 AI | `orange_ai` | API Key + Token | 图像生成 |
| 联网搜索 | `web_search` | API Key | 搜索服务 |

### 配置路径

```
应用内：设置页 → 模型设置 → 选择 Provider → 输入 API Key
```

API Key 存储在 `CredentialManager` 中，底层使用 `flutter_secure_storage`（Android: EncryptedSharedPreferences，iOS: Keychain）。

### 环境变量（可选）

对于开发调试，也可以通过环境变量传入默认 Key：

```bash
# .env 文件（不要提交到版本库）
OPENAI_API_KEY=sk-xxxxx
ANTHROPIC_API_KEY=sk-ant-xxxxx
DEEPSEEK_API_KEY=sk-xxxxx
VOLCENGINE_API_KEY=xxxxx
```

> ⚠️ **安全提醒**：`.env` 文件应加入 `.gitignore`，切勿提交到代码仓库。生产环境建议用户通过应用内设置页配置。

### 凭证类型说明

| 类型 | 枚举值 | 用途 |
|------|--------|------|
| `apiKey` | `api_key` | 标准 API 密钥 |
| `accessToken` | `access_token` | OAuth 访问令牌（有过期时间） |
| `refreshToken` | `refresh_token` | OAuth 刷新令牌 |
| `sessionCookie` | `session_cookie` | Session Cookie |
| `oauthToken` | `oauth_token` | OAuth Token |

---

## 目录结构

```
xiaosucore/
├── pubspec.yaml                          # 项目依赖配置
├── analysis_options.yaml                 # Dart 静态分析配置
├── README.md                             # 项目说明
│
├── lib/
│   ├── main.dart                         # APP 入口（初始化所有核心服务）
│   ├── app.dart                          # App Widget（主题、路由配置）
│   ├── p2_bootstrap.dart                 # P2 阶段引导启动
│   │
│   ├── core/                             # ══ 核心引擎层 ══
│   │   ├── chat_engine.dart              # 对话引擎（最核心模块）
│   │   ├── common/
│   │   │   └── models.dart               # 核心公共模型
│   │   ├── agent/                        # Agent 系统
│   │   │   ├── agent.dart                # Agent 基类
│   │   │   ├── agent_bus.dart            # Agent 消息总线
│   │   │   ├── supervisor_agent.dart     # Supervisor 多智能体协调
│   │   │   └── task_dag.dart             # 任务 DAG 编排
│   │   ├── gateway/                      # API 网关
│   │   │   ├── api_gateway.dart          # 统一 API 入口（认证/限流/熔断）
│   │   │   └── credential_manager.dart   # 凭证管理器
│   │   ├── llm/                          # LLM 多模型层
│   │   │   ├── llm_provider.dart         # LLM Provider 抽象接口
│   │   │   ├── llm_router.dart           # 模型路由（自动选择最优模型）
│   │   │   ├── openai_provider.dart      # OpenAI 实现
│   │   │   └── qwen_provider.dart        # 通义千问实现
│   │   ├── local_llm/
│   │   │   └── local_llm_engine.dart     # 本地模型推理引擎
│   │   ├── memory/                       # 记忆系统
│   │   │   ├── memory_center.dart        # 记忆中心
│   │   │   ├── vector_store.dart         # 向量存储
│   │   │   └── embedder.dart             # Embedding 生成
│   │   ├── skill/                        # 技能系统
│   │   │   ├── skill.dart                # Skill 基类（生命周期/工具定义）
│   │   │   └── skill_registry.dart       # 核心技能注册表
│   │   ├── task/
│   │   │   └── task_scheduler.dart       # 任务调度器
│   │   ├── workflow/                     # 工作流引擎
│   │   │   ├── workflow_engine.dart      # 工作流执行引擎
│   │   │   └── workflow_templates.dart   # 工作流模板
│   │   └── plugin_market/
│   │       └── plugin_market.dart        # 插件市场
│   │
│   ├── services/                         # ══ 服务层 ══
│   │   ├── llm_provider.dart             # LLM 调用封装
│   │   ├── memory_center.dart            # 记忆服务封装
│   │   ├── skill_registry.dart           # 技能注册表服务
│   │   ├── database_service.dart         # 本地数据库服务
│   │   ├── service_locator.dart          # 服务定位器
│   │   ├── offline/
│   │   │   └── offline_service.dart      # 离线模式服务
│   │   ├── performance/
│   │   │   └── performance_monitor.dart  # 性能监控
│   │   └── security/
│   │       └── security_service.dart     # 安全服务
│   │
│   ├── data/                             # ══ 数据层 ══
│   │   ├── database/
│   │   │   └── app_database.dart         # Drift 数据库定义
│   │   ├── models/
│   │   │   ├── conversation_model.dart   # 对话数据模型
│   │   │   └── user_profile_model.dart   # 用户画像模型
│   │   └── repositories/
│   │       ├── conversation_repository.dart  # 对话仓库
│   │       └── memory_repository.dart        # 记忆仓库
│   │
│   ├── models/                           # ══ 领域模型 ══
│   │   ├── chat_message.dart             # 聊天消息
│   │   ├── conversation.dart             # 对话
│   │   ├── skill_definition.dart         # 技能定义
│   │   └── task_model.dart               # 任务模型
│   │
│   ├── presentation/                     # ══ 表现层 ══
│   │   ├── app_router.dart               # 路由配置
│   │   ├── adaptive/
│   │   │   └── adaptive_layout_engine.dart   # 自适应布局引擎
│   │   ├── theme/                        # 主题
│   │   │   ├── app_theme.dart            # 主题定义
│   │   │   ├── app_colors.dart           # 颜色系统
│   │   │   └── app_text_styles.dart      # 字体样式
│   │   ├── chat/                         # 对话模块
│   │   │   ├── chat_screen.dart          # 对话页
│   │   │   ├── chat_controller.dart      # 对话控制器
│   │   │   ├── session_list_screen.dart  # 会话列表
│   │   │   └── widgets/
│   │   │       ├── chat_input.dart       # 输入组件
│   │   │       ├── message_bubble.dart   # 消息气泡
│   │   │       └── thinking_indicator.dart   # 思考指示器
│   │   ├── dashboard/
│   │   │   └── dashboard_screen.dart     # 仪表盘
│   │   ├── monitor/
│   │   │   └── monitor_dashboard.dart    # 监控面板
│   │   ├── plugin_store/
│   │   │   └── plugin_store_screen.dart  # 插件商店
│   │   ├── settings/
│   │   │   ├── settings_screen.dart      # 设置页
│   │   │   ├── model_settings_screen.dart    # 模型设置
│   │   │   └── skill_manager_screen.dart     # 技能管理
│   │   ├── workflow_editor/
│   │   │   └── workflow_editor_screen.dart   # 工作流编辑器
│   │   └── widgets/
│   │       └── common_widgets.dart       # 通用组件
│   │
│   ├── ui/                               # ══ UI 兼容层 ══
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   ├── pages/
│   │   │   ├── home_page.dart            # 首页（对话列表）
│   │   │   ├── chat_page.dart            # 对话页
│   │   │   ├── skills_page.dart          # 技能管理
│   │   │   ├── tasks_page.dart           # 任务管理
│   │   │   ├── settings_page.dart        # 设置
│   │   │   └── error_page.dart           # 错误页
│   │   └── widgets/                      # 通用组件
│   │
│   ├── platform/                         # ══ 平台桥接层 ══
│   │   ├── platform_dispatcher.dart      # 平台调度器
│   │   ├── platform_scheduler.dart       # 平台调度抽象
│   │   ├── android_scheduler.dart        # Android 实现
│   │   ├── ios/ios_scheduler.dart        # iOS 实现
│   │   ├── macos/macos_scheduler.dart    # macOS 实现
│   │   ├── windows/windows_scheduler.dart    # Windows 实现
│   │   └── linux/linux_scheduler.dart    # Linux 实现
│   │
│   ├── providers/                        # ══ Riverpod Provider ══
│   └── utils/                            # ══ 工具类 ══
│
├── skills/                               # ══ 技能实现 ══
│   ├── all_skills_bootstrap.dart         # 全技能引导注册
│   ├── p1_skill_registry.dart            # P1 技能注册中心
│   ├── web_search/web_search_skill.dart  # 网络搜索
│   ├── image_gen/image_gen_skill.dart    # 图片生成
│   ├── browser/browser_skill.dart        # 浏览器自动化
│   ├── email/email_skill.dart            # 邮件收发
│   ├── doc_gen/doc_gen_skill.dart        # 文档生成
│   ├── podcast/podcast_skill.dart        # 播客生成
│   ├── video/video_skill.dart            # 视频生成
│   ├── social/social_skill.dart          # 社交媒体
│   ├── lark/lark_skill.dart              # 飞书集成
│   ├── tracking/tracking_skill.dart      # 话题追踪
│   ├── chart/chart_skill.dart            # 数据图表
│   ├── tts/tts_skill.dart                # 语音合成
│   ├── forbidden_word/forbidden_word_skill.dart  # 违禁词检测
│   ├── pro_domain/pro_domain_skill.dart  # 专业域名
│   ├── code_sandbox/code_sandbox_skill.dart  # 代码沙箱
│   └── cloud_sync/cloud_sync_skill.dart  # 云同步
│
├── assets/                               # ══ 资源文件 ══
│   ├── images/                           # 图片资源
│   ├── icons/                            # 图标资源
│   ├── models/                           # 本地 AI 模型
│   ├── templates/                        # 模板文件
│   └── fonts/
│       └── XiaosuIcon.ttf               # 自定义图标字体
│
├── android/                              # ══ Android 平台 ══
│   ├── build.gradle                      # 根 Gradle 配置
│   ├── settings.gradle                   # Gradle 设置
│   ├── gradle/wrapper/
│   │   └── gradle-wrapper.properties     # Gradle 8.4
│   └── app/
│       ├── build.gradle                  # App Gradle（SDK 版本、签名等）
│       └── src/main/                     # Android 源码
│
├── ios/                                  # ══ iOS 平台 ══
│   ├── Podfile                           # CocoaPods 依赖
│   ├── Flutter/                          # Flutter 引擎配置
│   ├── Runner/                           # iOS 主工程
│   │   ├── Info.plist                    # iOS 配置（权限声明等）
│   │   ├── Assets.xcassets/              # 图标/启动图
│   │   └── Base.lproj/                   # Storyboard
│   └── Runner.xcodeproj/                 # Xcode 工程文件
│
└── test/                                 # ══ 测试 ══
```

---

## 常见问题

### 1. Gradle 版本不匹配

**现象：** `Could not determine the dependencies of ':app'` 或 Gradle 同步失败

**解决方案：**

```bash
# 确保使用项目指定的 Gradle 版本
# android/gradle/wrapper/gradle-wrapper.properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-all.zip

# 清理缓存后重试
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

**常见 Gradle 版本对应关系：**

| AGP 版本 | 最低 Gradle 版本 | 本项目 |
|---------|----------------|--------|
| 8.1.x | 8.0 | ✅ 使用 8.4 |
| 8.0.x | 8.0 | |
| 7.4.x | 7.5 | |

### 2. CocoaPods 缓存问题

**现象：** `pod install` 失败或 iOS 编译报 `library not found`

**解决方案：**

```bash
# 清理 CocoaPods 缓存
cd ios
pod deintegrate
rm -rf Pods Podfile.lock
pod cache clean --all
pod install --repo-update
cd ..

# 如果仍有问题，清理 Flutter 缓存
flutter clean
flutter pub get
cd ios && pod install && cd ..
```

### 3. Flutter 依赖下载失败

**现象：** `flutter pub get` 超时或报网络错误

**解决方案：**

```bash
# 方案一：配置国内镜像
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# 方案二：清理缓存重试
flutter pub cache clean
flutter pub get

# 方案三：手动指定 pubspec 中的镜像源
# 在项目根目录创建 .pub-cache 配置
```

### 4. 签名配置

**Android 签名（Release 包）：**

```bash
# 1. 生成密钥库
keytool -genkey -v -keystore ~/xiaosu-release.keystore \
  -alias xiaosu -keyalg RSA -keysize 2048 -validity 10000

# 2. 创建 key.properties
cat > android/key.properties << 'EOF'
storePassword=你的密码
keyPassword=你的密码
keyAlias=xiaosu
storeFile=/你的路径/xiaosu-release.keystore
EOF

# 3. 在 android/app/build.gradle 中配置签名
# （注意：当前项目默认使用 debug 签名用于快速测试）
```

> ⚠️ **安全提醒**：`key.properties` 和 `.keystore` 文件切勿提交到版本库，应加入 `.gitignore`。

**iOS 签名：**

iOS 签名必须通过 Xcode 配置：

1. 打开 `ios/Runner.xcworkspace`
2. 选择 Runner → Signing & Capabilities
3. 选择 Team（需要 Apple Developer 账号）
4. 确保 Bundle Identifier 为 `com.xiaosu.app`

### 5. 代码生成失败

**现象：** `build_runner` 报错或生成文件缺失

**解决方案：**

```bash
# 清理并重新生成
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs

# 如果特定模块报错，检查生成器版本兼容性
# drift_dev 版本需与 drift 版本匹配
# riverpod_generator 版本需与 flutter_riverpod 版本匹配
```

### 6. 内存不足导致编译失败

**现象：** `GC overhead limit exceeded` 或 `Java heap space`

**解决方案：**

```bash
# 增大 Gradle JVM 内存
# 在 android/gradle.properties 中添加：
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=512m

# 减少并行编译
org.gradle.parallel=false
```

### 7. 多平台编译注意事项

| 平台 | 注意事项 |
|------|---------|
| Android | 需要 JDK 17，不支持 JDK 21+ |
| iOS | 必须在 macOS 上编译，需要 Xcode 15+ |
| macOS | 需要 `flutter config --enable-macos-desktop` |
| Windows | 需要 Visual Studio 2022 + C++ 桌面开发工作负载 |
| Linux | 需要 GTK dev 库：`sudo apt install libgtk-3-dev` |

---

## 快速编译速查表

```bash
# ===== Android =====
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release                          # 全量 APK
flutter build apk --release --split-per-abi          # 分 ABI
flutter build appbundle --release                    # Google Play

# ===== iOS =====
flutter pub get
dart run build_runner build --delete-conflicting-outputs
cd ios && pod install --repo-update && cd ..
flutter build ios --release --no-codesign            # 未签名
flutter build ipa --release                          # 签名版

# ===== 开发调试 =====
flutter run                                          # 热重载调试
flutter run --profile                                # 性能分析模式
flutter test                                         # 运行测试
```
