// ============================================================================
// 小酥 (XiaoSu) - APP 入口文件
//
// 职责：
// 1. 初始化所有核心服务（日志、数据库、存储、技能注册等）
// 2. 配置全局错误捕获与处理
// 3. 启动 Flutter 渲染树
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import 'package:xiaosu_core/app.dart';
import 'package:xiaosu_core/core/chat_engine.dart';
import 'package:xiaosu_core/core/task/task_scheduler.dart';
import 'package:xiaosu_core/services/database_service.dart';
import 'package:xiaosu_core/services/memory_center.dart';
import 'package:xiaosu_core/services/skill_registry.dart';
import 'package:xiaosu_core/services/llm_provider.dart';

/// ============================================================================
/// 全局日志器 —— 所有模块共用
/// ============================================================================
final Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 80,
    colors: !kReleaseMode,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/// ============================================================================
/// 全局日志器 —— 仅输出关键信息（用于生产环境）
/// ============================================================================
final Logger releaseLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 60,
    colors: false,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/// ============================================================================
/// 应用启动入口
/// ============================================================================
void main() {
  // 1. 初始化 Flutter 绑定
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 启动异步初始化流程，等待所有服务就绪后再启动 UI
  _initApp().then((_) {
    // 3. 启动 APP，包裹 ProviderScope（Riverpod 状态管理根节点）
    runApp(
      const ProviderScope(
        child: XiaoSuApp(),
      ),
    );
  }).catchError((error, stackTrace) {
    // 4. 初始化阶段发生致命错误
    appLogger.e('❌ APP 初始化失败: $error', error: error, stackTrace: stackTrace);

    // 在 Release 模式下显示一个错误 Widget
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '小酥启动失败\n$error\n\n请重启应用',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  });
}

/// ============================================================================
/// 异步初始化流程
/// 按依赖顺序逐步启动所有服务
/// ============================================================================
Future<void> _initApp() async {
  // ─── 阶段 1：全局错误捕获 ───────────────────────────────────────
  // 捕获未处理的异步错误，防止崩溃
  FlutterError.onError = _handleFlutterError;
  PlatformDispatcher.instance.onError = _handlePlatformError;

  appLogger.i('🚀 小酥正在启动...');

  // ─── 阶段 2：初始化 Hive 本地存储 ───────────────────────────────
  // Hive 需要在其他服务之前初始化（配置存储依赖它）
  await Hive.initFlutter();
  appLogger.i('📦 Hive 本地存储初始化完成');

  // ─── 阶段 3：获取应用目录 ───────────────────────────────────────
  // 数据库文件需要存放在应用文档目录中
  final appDir = await getApplicationDocumentsDirectory();
  appLogger.i('📁 应用目录: ${appDir.path}');

  // ─── 阶段 4：初始化数据库服务 ───────────────────────────────────
  // Drift 数据库需要创建表结构和执行迁移
  await DatabaseService.instance.initialize(databasePath: appDir.path);
  appLogger.i('🗄️ 数据库服务初始化完成');

  // ─── 阶段 5：初始化 LLM 提供者 ──────────────────────────────────
  // 加载 API Key（从安全存储读取），配置模型参数
  await LLMProvider.instance.initialize();
  appLogger.i('🧠 LLM 提供者初始化完成');

  // ─── 阶段 6：初始化记忆中心 ─────────────────────────────────────
  // 加载长期记忆索引、配置 RAG 检索参数
  await MemoryCenter.instance.initialize();
  appLogger.i('💾 记忆中心初始化完成');

  // ─── 阶段 7：注册内置技能 ───────────────────────────────────────
  // 将所有内置技能（Function Calling）注册到技能注册表
  SkillRegistry.instance.registerBuiltinSkills();
  appLogger.i('🛠️ 技能注册完成，已注册 ${SkillRegistry.instance.skillCount} 个技能');

  // ─── 阶段 8：初始化对话引擎 ─────────────────────────────────────
  // ChatEngine 整合 LLM + 记忆 + 技能，是核心运行时
  ChatEngine.instance.initialize(
    llmProvider: LLMProvider.instance,
    memoryCenter: MemoryCenter.instance,
    skillRegistry: SkillRegistry.instance,
  );
  appLogger.i('💬 对话引擎初始化完成');

  // ─── 阶段 9：初始化任务调度器 ───────────────────────────────────
  // 恢复持久化的定时任务，同步到系统 WorkManager
  await TaskScheduler.instance.initialize();
  appLogger.i('⏰ 任务调度器初始化完成');

  // ─── 完成 ─────────────────────────────────────────────────────
  appLogger.i('✅ 小酥启动完成！所有服务已就绪');
}

/// ============================================================================
/// Flutter 框架层错误处理
/// 处理 Widget 构建、布局等阶段的异常
/// ============================================================================
void _handleFlutterError(FlutterErrorDetails details) {
  // 在 Debug 模式下让 IDE 断点生效
  if (kDebugMode) {
    FlutterError.presentError(details);
  }

  // 记录错误日志
  appLogger.e(
    '🐛 Flutter 错误: ${details.exception}',
    error: details.exception,
    stackTrace: details.stack,
  );

  // TODO: 上报到错误追踪服务（如 Sentry）
}

/// ============================================================================
/// 平台层错误处理
/// 捕获所有未被 try-catch 捕获的异步错误
/// 返回 true 表示错误已被处理
/// ============================================================================
bool _handlePlatformError(Object error, StackTrace stackTrace) {
  appLogger.e(
    '💥 未捕获的异步错误: $error',
    error: error,
    stackTrace: stackTrace,
  );

  // TODO: 上报到错误追踪服务

  // 返回 true 表示错误已被处理，不再传递给平台默认处理器
  return true;
}
