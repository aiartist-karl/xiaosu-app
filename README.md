# 小酥 - 全能 AI Agent 助手

> 一个基于 Flutter 构建的全能 AI Agent 助手 APP，集成 LLM 对话、技能系统（Function Calling）、任务调度、记忆中心（RAG）等核心能力。

## 📋 项目概述

小酥（XiaoSu）不是一个简单的聊天机器人，而是一个**真正的 AI Agent**——它拥有：

- 🧠 **智能对话**：流式对话 + Function Calling 自动调用技能
- 💾 **长期记忆**：RAG 语义检索，记住与你的每次对话
- 🛠️ **技能系统**：可插拔的技能架构，支持网络搜索、计算器、天气等
- ⏰ **任务调度**：定时提醒、周期任务、话题追踪
- 🔒 **本地存储**：所有数据存储在本地，保护隐私

## 📁 项目结构

```
xiaosucore/
├── lib/
│   ├── main.dart                    # APP 入口（初始化流程）
│   ├── app.dart                     # App Widget（主题、路由）
│   │
│   ├── core/                        # 核心引擎
│   │   ├── chat_engine.dart         # 🧠 对话引擎（最核心）
│   │   └── task/
│   │       └── task_scheduler.dart  # ⏰ 任务调度器
│   │
│   ├── services/                    # 服务层
│   │   ├── llm_provider.dart        # 大模型 API 封装
│   │   ├── memory_center.dart       # 记忆中心（RAG）
│   │   ├── skill_registry.dart      # 技能注册表
│   │   └── database_service.dart    # 本地数据库
│   │
│   ├── models/                      # 数据模型
│   │   ├── chat_message.dart        # 聊天消息
│   │   ├── conversation.dart        # 对话
│   │   ├── skill_definition.dart    # 技能定义
│   │   └── task_model.dart          # 任务模型
│   │
│   ├── platform/                    # 平台桥接
│   │   └── android_scheduler.dart   # Android WorkManager 桥接
│   │
│   ├── ui/                          # UI 层
│   │   ├── theme/
│   │   │   └── app_theme.dart       # 全局主题
│   │   ├── pages/
│   │   │   ├── home_page.dart       # 首页（对话列表）
│   │   │   ├── chat_page.dart       # 对话页
│   │   │   ├── skills_page.dart     # 技能管理
│   │   │   ├── tasks_page.dart      # 任务管理
│   │   │   ├── settings_page.dart   # 设置
│   │   │   └── error_page.dart      # 错误页
│   │   └── widgets/                 # 通用组件
│   │
│   ├── providers/                   # Riverpod Provider
│   └── utils/                       # 工具类
│
├── assets/
│   ├── images/                      # 图片资源
│   └── models/                      # 本地模型（如有）
│
├── pubspec.yaml                     # 项目依赖配置
├── analysis_options.yaml            # 代码规范
└── README.md                        # 本文件
```

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / Xcode（用于原生构建）

### 安装依赖

```bash
flutter pub get
```

### 生成代码

```bash
# 生成 Drift、Riverpod、JSON 序列化代码
dart run build_runner build --delete-conflicting-outputs
```

### 运行

```bash
# Android
flutter run

# iOS
flutter run --device-id=<simulator_id>

# Debug 模式
flutter run --debug

# Release 模式
flutter run --release
```

## 🏗️ 构建指南

### Android APK

```bash
flutter build apk --release
# 输出：build/app/outputs/flutter-apk/app-release.apk
```

### Android AAB（Google Play 上架）

```bash
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
# 然后用 Xcode 打开 Runner.xcworkspace 进行签名和发布
```

### 原生配置（Android）

在 `android/app/build.gradle` 中添加：

```gradle
dependencies {
    implementation "androidx.work:work-runtime:2.9.0"
    implementation "androidx.work:work-runtime-ktx:2.9.0"
}
```

在 `android/app/src/main/kotlin/` 中实现 WorkManager 桥接：

```kotlin
class XiaoSuSchedulerPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.xiaosu.scheduler")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scheduleOneTime" -> scheduleOneTime(call, result)
            "schedulePeriodic" -> schedulePeriodic(call, result)
            "cancelTask" -> cancelTask(call, result)
            "getPendingTasks" -> getPendingTasks(result)
            else -> result.notImplemented()
        }
    }
    // ... 实现细节
}
```

## 🔧 技术栈

| 领域 | 技术 | 说明 |
|------|------|------|
| 框架 | Flutter 3.x | 跨平台移动应用框架 |
| 状态管理 | Riverpod | 编译时安全的响应式状态管理 |
| 路由 | GoRouter | 声明式路由 |
| 网络 | Dio | HTTP 客户端 |
| 数据库 | Drift + SQLite | 类型安全的本地数据库 |
| KV 存储 | Hive | 轻量级键值存储 |
| 安全存储 | flutter_secure_storage | 加密存储 API Key |
| 序列化 | json_serializable | JSON 代码生成 |
| Markdown | flutter_markdown | Markdown 渲染 |
| 代码高亮 | flutter_highlighter | 语法高亮 |
| 后台任务 | WorkManager | Android 原生后台调度 |

## 📅 开发计划

### Phase 1：基础框架 ✅
- [x] 项目结构搭建
- [x] 依赖配置
- [x] 初始化流程
- [x] 主题系统
- [x] 路由配置
- [x] 数据库服务
- [x] 对话引擎核心

### Phase 2：核心功能
- [ ] 对话 UI（流式渲染、Markdown、代码高亮）
- [ ] LLM API 集成（OpenAI 兼容接口）
- [ ] 技能系统完善（搜索、计算、天气）
- [ ] 记忆中心（Embedding + 向量检索）

### Phase 3：高级功能
- [ ] 任务调度（WorkManager 原生实现）
- [ ] 话题追踪系统
- [ ] 文件上传与解析
- [ ] 多模态输入（图片、语音）

### Phase 4：优化与发布
- [ ] 性能优化
- [ ] 安全加固
- [ ] 多语言支持
- [ ] Google Play / App Store 上架

## 📄 License

Private - 内部项目
