// ============================================================================
// 小酥 v2 - App Widget 定义
// Phase 2: 添加登录页面和认证检查
// 路由：登录页 + 4 Tab（首页/Bot商店/工作台/我的）+ 子页面（聊天/Bot详情/设置等）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xiaosu/ui/theme/app_theme.dart';
import 'package:xiaosu/ui/pages/error_page.dart';

// ─── 登录页 ──────────────────────────────────────────────────
import 'package:xiaosu/presentation/auth/login_screen.dart';

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

// ─── 新增功能页面 ─────────────────────────────────────────────
import 'package:xiaosu/presentation/workflow/workflow_list_screen.dart';
import 'package:xiaosu/presentation/workflow/workflow_detail_screen.dart';
import 'package:xiaosu/presentation/plugin/plugin_market_screen.dart';
import 'package:xiaosu/presentation/plugin/plugin_detail_screen.dart';
import 'package:xiaosu/presentation/knowledge/knowledge_list_screen.dart';
import 'package:xiaosu/presentation/knowledge/knowledge_detail_screen.dart';
import 'package:xiaosu/presentation/token/token_balance_screen.dart';
import 'package:xiaosu/presentation/settings/api_config_screen.dart';
import 'package:xiaosu/presentation/file/file_list_screen.dart';

// ─── 认证管理 ─────────────────────────────────────────────────
import 'core/gateway/api_gateway.dart';

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
      redirect: (context, state) {
        // 检查是否需要登录
        final isLoggedIn = ApiGateway.instance.isAuthenticated;
        final isOnLoginPage = state.uri.path == '/login';
        
        // 如果未登录且不在登录页，跳转到登录页
        if (!isLoggedIn && !isOnLoginPage) {
          return '/login';
        }
        
        // 如果已登录且在登录页，跳转到主页
        if (isLoggedIn && isOnLoginPage) {
          return '/';
        }
        
        // 其他情况不重定向
        return null;
      },
      refreshListenable: GoRouterRefreshStream(),
      errorBuilder: (context, state) => ErrorPage(
        error: state.error,
        path: state.uri.toString(),
      ),
      routes: [
        // ===== 登录页 =====
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        
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

        // ===== 新增功能页面 =====

        // 工作流列表
        GoRoute(
          path: '/workflows',
          name: 'workflow-list',
          builder: (context, state) => const WorkflowListScreen(),
        ),
        // 工作流详情
        GoRoute(
          path: '/workflows/detail',
          name: 'workflow-detail',
          builder: (context, state) {
            final workflowId = state.uri.queryParameters['workflowId'] ?? '';
            return WorkflowDetailScreen(workflowId: workflowId);
          },
        ),
        // 插件市场
        GoRoute(
          path: '/plugin-market',
          name: 'plugin-market',
          builder: (context, state) => const PluginMarketScreen(),
        ),
        // 插件详情
        GoRoute(
          path: '/plugin-market/detail',
          name: 'plugin-detail',
          builder: (context, state) {
            final pluginId = state.uri.queryParameters['pluginId'] ?? '';
            return PluginDetailScreen(pluginId: pluginId);
          },
        ),
        // 知识库列表
        GoRoute(
          path: '/knowledge',
          name: 'knowledge-list',
          builder: (context, state) => const KnowledgeListScreen(),
        ),
        // 知识库详情
        GoRoute(
          path: '/knowledge/detail',
          name: 'knowledge-detail',
          builder: (context, state) {
            final datasetId = state.uri.queryParameters['datasetId'] ?? '';
            final datasetName = state.uri.queryParameters['datasetName'] ?? '知识库';
            return KnowledgeDetailScreen(
              datasetId: datasetId,
              datasetName: datasetName,
            );
          },
        ),
        // Token 余额
        GoRoute(
          path: '/token-balance',
          name: 'token-balance',
          builder: (context, state) => const TokenBalanceScreen(),
        ),
        // API 配置
        GoRoute(
          path: '/api-config',
          name: 'api-config',
          builder: (context, state) => const ApiConfigScreen(),
        ),
        // Coze 文件管理
        GoRoute(
          path: '/coze-files',
          name: 'coze-files',
          builder: (context, state) => const FileListScreen(),
        ),
      ],
    );
  }
}

/// 主题模式 Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// GoRouter 刷新流 - 用于监听认证状态变化
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream() {
    // 定时检查认证状态变化（简单实现）
    // 实际项目中可以使用 ChangeNotifier 或 Riverpod 监听
  }

  void refresh() {
    notifyListeners();
  }
}
