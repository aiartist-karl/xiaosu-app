// ============================================================================
// 小酥 v2 - App Widget 定义
// 路由：4 Tab（首页/Bot商店/工作台/我的）+ 子页面（聊天/Bot详情/设置等）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xiaosu/ui/theme/app_theme.dart';
import 'package:xiaosu/ui/pages/error_page.dart';

// ─── Shell 布局 ─────────────────────────────────────────────
import 'package:xiaosu/presentation/shell/shell_screen.dart';

// ─── 新版 Tab 页面 ──────────────────────────────────────────
import 'package:xiaosu/presentation/home/home_page.dart';
import 'package:xiaosu/presentation/bot_store/bot_store_screen.dart';
import 'package:xiaosu/presentation/workbench/workbench_screen.dart';
import 'package:xiaosu/presentation/profile/profile_screen.dart';

// ─── 子页面（从 Tab 页进入，需要返回按钮）───────────────────
import 'package:xiaosu/presentation/chat/chat_screen.dart';
import 'package:xiaosu/presentation/settings/model_settings_screen.dart';
import 'package:xiaosu/presentation/settings/settings_screen.dart';
import 'package:xiaosu/presentation/settings/skill_manager_screen.dart';
import 'package:xiaosu/presentation/plugin_store/plugin_store_screen.dart';
import 'package:xiaosu/presentation/workflow_editor/workflow_editor_screen.dart';
import 'package:xiaosu/presentation/bot_store/bot_detail_screen.dart';
import 'package:xiaosu/presentation/bot_store/bot_editor_screen.dart';
import 'package:xiaosu/presentation/workbench/files_screen.dart';
import 'package:xiaosu/presentation/workbench/schedule_screen.dart';
import 'package:xiaosu/presentation/workbench/project_screen.dart';
import 'package:xiaosu/presentation/workbench/memory_screen.dart';

// ─── Profile 子页面 ─────────────────────────────────────────
import 'package:xiaosu/presentation/profile/token_recharge_screen.dart';
import 'package:xiaosu/presentation/profile/about_screen.dart';
import 'package:xiaosu/presentation/profile/privacy_screen.dart';
import 'package:xiaosu/presentation/profile/notification_screen.dart';

/// ============================================================================
// 小酥 APP 根 Widget
/// ============================================================================
class XiaoSuApp extends ConsumerWidget {
  const XiaoSuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: '小酥',
      debugShowCheckedModeBanner: false,
      routerConfig: _buildRouter(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/',
      errorBuilder: (context, state) => ErrorPage(
        error: state.error,
        path: state.uri.toString(),
      ),
      routes: [
        // ===== ShellRoute：底部 4 Tab =====
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return ShellScreen(navigationShell: navigationShell);
          },
          branches: [
            // Tab 1: 首页（对话列表 + Token余额卡片）
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomePage(),
              ),
            ]),
            // Tab 2: Bot 商店
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/bot-store',
                name: 'bot-store',
                builder: (context, state) => const BotStoreScreen(),
              ),
            ]),
            // Tab 3: 工作台
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/workbench',
                name: 'workbench',
                builder: (context, state) => const WorkbenchScreen(),
              ),
            ]),
            // Tab 4: 我的
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ]),
          ],
        ),

        // ===== 子页面（Shell 外，有返回按钮）=====

        // 聊天页
        GoRoute(
          path: '/chat/:conversationId',
          name: 'chat',
          builder: (context, state) {
            final conversationId = state.pathParameters['conversationId']!;
            final botName = state.uri.queryParameters['botName'];
            return ChatScreen(
              conversationId: conversationId,
              botName: botName,
            );
          },
        ),

        // 新建对话
        GoRoute(
          path: '/chat-new',
          name: 'chat-new',
          builder: (context, state) => const ChatScreen(conversationId: ''),
        ),

        // 设置
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

        // 技能管理（旧版保留）
        GoRoute(
          path: '/skills',
          name: 'skills',
          builder: (context, state) => const SkillManagerScreen(),
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

        // Bot 详情
        GoRoute(
          path: '/bot-store/detail',
          name: 'bot-detail',
          builder: (context, state) {
            final botId = state.uri.queryParameters['botId'] ?? '1';
            return BotDetailScreen(botId: botId);
          },
        ),

        // Bot 编辑器
        GoRoute(
          path: '/bot-store/editor',
          name: 'bot-editor',
          builder: (context, state) {
            final botId = state.uri.queryParameters['botId'];
            return BotEditorScreen(botId: botId);
          },
        ),

        // ===== Profile 子页面 =====

        // Token 充值
        GoRoute(
          path: '/profile/token',
          name: 'token-recharge',
          builder: (context, state) => const TokenRechargeScreen(),
        ),

        // 关于小酥
        GoRoute(
          path: '/profile/about',
          name: 'about',
          builder: (context, state) => const AboutScreen(),
        ),

        // 隐私设置
        GoRoute(
          path: '/profile/privacy',
          name: 'privacy',
          builder: (context, state) => const PrivacyScreen(),
        ),

        // 通知设置
        GoRoute(
          path: '/profile/notification',
          name: 'notification',
          builder: (context, state) => const NotificationScreen(),
        ),

        // ===== 工作台子页面 =====
        GoRoute(
          path: '/workbench/files',
          name: 'workbench-files',
          builder: (context, state) => const FilesScreen(),
        ),
        GoRoute(
          path: '/workbench/schedule',
          name: 'workbench-schedule',
          builder: (context, state) => const ScheduleScreen(),
        ),
        GoRoute(
          path: '/workbench/project',
          name: 'workbench-project',
          builder: (context, state) => const ProjectScreen(),
        ),
        GoRoute(
          path: '/workbench/memory',
          name: 'workbench-memory',
          builder: (context, state) => const MemoryScreen(),
        ),
      ],
    );
  }
}

/// 主题模式 Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
