// ============================================================================
// 小酥 (XiaoSu) - App Widget 定义
//
// 职责：
// 1. 配置 MaterialApp.router（基于 GoRouter 的声明式路由）
// 2. 定义全局主题（亮色 / 暗色）
// 3. 配置全局 Provider（Riverpod）
// 4. 全局错误 Widget
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xiaosu/ui/theme/app_theme.dart';
import 'package:xiaosu/ui/pages/error_page.dart';

// ─── 真实实现页面（presentation 层）──────────────────────────
import 'package:xiaosu/presentation/chat/session_list_screen.dart';
import 'package:xiaosu/presentation/chat/chat_screen.dart';
import 'package:xiaosu/presentation/settings/settings_screen.dart';
import 'package:xiaosu/presentation/settings/model_settings_screen.dart';
import 'package:xiaosu/presentation/settings/skill_manager_screen.dart';
import 'package:xiaosu/presentation/dashboard/dashboard_screen.dart';
import 'package:xiaosu/presentation/plugin_store/plugin_store_screen.dart';
import 'package:xiaosu/presentation/monitor/monitor_dashboard.dart';
import 'package:xiaosu/presentation/workflow_editor/workflow_editor_screen.dart';

/// ============================================================================
// 小酥 APP 根 Widget
/// ============================================================================
class XiaoSuApp extends ConsumerWidget {
  const XiaoSuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 读取当前主题模式（亮色 / 暗色）
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      // ─── 应用基本信息 ────────────────────────────────────────
      title: '小酥',
      debugShowCheckedModeBanner: false,

      // ─── 路由配置 ──────────────────────────────────────────
      routerConfig: _buildRouter(),

      // ─── 主题配置 ──────────────────────────────────────────
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // ─── 全局错误 Widget ───────────────────────────────────
      builder: (context, child) {
        // 包裹 MediaQuery 确保无障碍字号不会破坏布局
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// 构建全局路由配置
  GoRouter _buildRouter() {
    return GoRouter(
      // 初始路由：会话列表（主页）
      initialLocation: '/',

      // 全局错误页面处理
      errorBuilder: (context, state) => ErrorPage(
        error: state.error,
        path: state.uri.toString(),
      ),

      // ─── 路由表定义 ─────────────────────────────────────────
      routes: [
        // 首页 —— 会话列表 / 主入口
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const SessionListScreen(),
        ),

        // 对话页 —— 与 AI 进行实时对话（完整版）
        GoRoute(
          path: '/chat/:conversationId',
          name: 'chat',
          builder: (context, state) {
            final conversationId = state.pathParameters['conversationId']!;
            return ChatScreen(conversationId: conversationId);
          },
        ),

        // 新建对话
        GoRoute(
          path: '/chat-new',
          name: 'chat-new',
          builder: (context, state) => const ChatScreen(conversationId: ''),
        ),

        // 技能管理页（完整版）
        GoRoute(
          path: '/skills',
          name: 'skills',
          builder: (context, state) => const SkillManagerScreen(),
        ),

        // 任务页 —— 仪表盘
        GoRoute(
          path: '/tasks',
          name: 'tasks',
          builder: (context, state) => const DashboardScreen(),
        ),

        // 设置页（完整版）
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),

        // 模型设置
        GoRoute(
          path: '/settings/model',
          name: 'model-settings',
          builder: (context, state) => const ModelSettingsScreen(),
        ),

        // 工作流编辑器
        GoRoute(
          path: '/workflow',
          name: 'workflow',
          builder: (context, state) => const WorkflowEditorScreen(),
        ),

        // 插件商店
        GoRoute(
          path: '/plugins',
          name: 'plugins',
          builder: (context, state) => const PluginStoreScreen(),
        ),

        // 监控面板
        GoRoute(
          path: '/monitor',
          name: 'monitor',
          builder: (context, state) => const MonitorDashboard(),
        ),
      ],
    );
  }
}

/// ============================================================================
/// 主题模式 Provider
/// 控制亮色 / 暗色 / 跟随系统
/// ============================================================================
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  // 默认跟随系统
  return ThemeMode.system;
});
