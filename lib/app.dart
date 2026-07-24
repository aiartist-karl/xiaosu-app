// ============================================================================
// 小酥 (XiaoSu) - App Widget 定义
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xiaosu/ui/theme/app_theme.dart';
import 'package:xiaosu/ui/pages/error_page.dart';

// ─── Shell 布局 ─────────────────────────────────────────────
import 'package:xiaosu/presentation/shell/shell_screen.dart';

// ─── 主 Tab 页面 ─────────────────────────────────────────────
import 'package:xiaosu/presentation/chat/session_list_screen.dart';
import 'package:xiaosu/presentation/settings/skill_manager_screen.dart';
import 'package:xiaosu/presentation/dashboard/dashboard_screen.dart';
import 'package:xiaosu/presentation/monitor/monitor_dashboard.dart';
import 'package:xiaosu/presentation/settings/settings_screen.dart';

// ─── 子页面 ────────────────────────────────────────────────────
import 'package:xiaosu/presentation/chat/chat_screen.dart';
import 'package:xiaosu/presentation/settings/model_settings_screen.dart';
import 'package:xiaosu/presentation/plugin_store/plugin_store_screen.dart';
import 'package:xiaosu/presentation/workflow_editor/workflow_editor_screen.dart';
import 'package:xiaosu/presentation/tools/tools_screen.dart';

/// 小酥 APP 根 Widget
class XiaoSuApp extends ConsumerStatefulWidget {
  const XiaoSuApp({super.key});

  @override
  ConsumerState<XiaoSuApp> createState() => _XiaoSuAppState();
}

class _XiaoSuAppState extends ConsumerState<XiaoSuApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isThemeLoaded = false;

  static const String _themeKey = 'xiaosu_theme_mode';

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_themeKey) ?? 'system';
    final mode = switch (themeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    if (mounted) {
      setState(() {
        _themeMode = mode;
        _isThemeLoaded = true;
      });
      // 同步到provider
      ref.read(themeModeProvider.notifier).state = mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听provider变化（从设置页面切换时）
    final providerThemeMode = ref.watch(themeModeProvider);
    
    // 如果provider有变化，同步到本地状态
    if (providerThemeMode != _themeMode && _isThemeLoaded) {
      _themeMode = providerThemeMode;
    }

    if (!_isThemeLoaded) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: '小酥',
      debugShowCheckedModeBanner: false,
      routerConfig: _buildRouter(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      builder: (context, child) {
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
      initialLocation: '/',
      errorBuilder: (context, state) => ErrorPage(
        error: state.error,
        path: state.uri.toString(),
      ),
      routes: [
        // ===== ShellRoute：底部导航栏 =====
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return ShellScreen(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const SessionListScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/skills',
                name: 'skills',
                builder: (context, state) => const SkillManagerScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/tasks',
                name: 'tasks',
                builder: (context, state) => const DashboardScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/monitor',
                name: 'monitor',
                builder: (context, state) => const MonitorDashboard(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ]),
          ],
        ),

        // ===== 子页面 =====
        GoRoute(
          path: '/chat/:conversationId',
          name: 'chat',
          builder: (context, state) {
            final conversationId = state.pathParameters['conversationId']!;
            return ChatScreen(conversationId: conversationId);
          },
        ),
        GoRoute(
          path: '/chat-new',
          name: 'chat-new',
          builder: (context, state) => ChatScreen(conversationId: ''),
        ),
        GoRoute(
          path: '/settings/model',
          name: 'model-settings',
          builder: (context, state) => const ModelSettingsScreen(),
        ),
        GoRoute(
          path: '/workflow',
          name: 'workflow',
          builder: (context, state) => const WorkflowEditorScreen(),
        ),
        GoRoute(
          path: '/plugins',
          name: 'plugins',
          builder: (context, state) => const PluginStoreScreen(),
        ),
        // 工具集页面
        GoRoute(
          path: '/tools',
          name: 'tools',
          builder: (context, state) => const ToolsScreen(),
        ),
      ],
    );
  }
}

/// 主题模式 Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});
