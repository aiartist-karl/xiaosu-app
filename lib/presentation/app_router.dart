// ============================================================================
// 小酥 - 应用路由管理
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/pages/home_page.dart';
import '../ui/pages/chat_page.dart';
import '../ui/pages/settings_page.dart';
import '../ui/pages/skills_page.dart';
import '../ui/pages/tasks_page.dart';
import '../ui/pages/error_page.dart';
import 'chat/chat_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/model_settings_screen.dart';
import 'settings/skill_manager_screen.dart';
import 'chat/session_list_screen.dart';
import 'workflow_editor/workflow_editor_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'plugin_store/plugin_store_screen.dart';
import 'monitor/monitor_dashboard.dart';

/// 应用路由管理
class AppRouter {
  /// 创建GoRouter实例
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: '/',
      errorBuilder: (context, state) => ErrorPage(
        error: state.error,
        path: state.uri.toString(),
      ),
      routes: [
        GoRoute(path: '/', name: 'home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/chat/:conversationId',
          name: 'chat',
          builder: (_, state) {
            final id = state.pathParameters['conversationId']!;
            return ChatPage(conversationId: id);
          },
        ),
        GoRoute(path: '/chat-new', name: 'chat-new', builder: (_, __) => const ChatScreen(conversationId: '')),
        GoRoute(path: '/sessions', name: 'sessions', builder: (_, __) => const SessionListScreen()),
        GoRoute(path: '/skills', name: 'skills', builder: (_, __) => const SkillsPage()),
        GoRoute(path: '/skill-manager', name: 'skill-manager', builder: (_, __) => const SkillManagerScreen()),
        GoRoute(path: '/tasks', name: 'tasks', builder: (_, __) => const TasksPage()),
        GoRoute(path: '/settings', name: 'settings', builder: (_, __) => const SettingsPage()),
        GoRoute(path: '/settings/full', name: 'settings-full', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/settings/model', name: 'model-settings', builder: (_, __) => const ModelSettingsScreen()),
        GoRoute(path: '/workflow', name: 'workflow', builder: (_, __) => const WorkflowEditorScreen()),
        GoRoute(path: '/dashboard', name: 'dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/plugins', name: 'plugins', builder: (_, __) => const PluginStoreScreen()),
        GoRoute(path: '/monitor', name: 'monitor', builder: (_, __) => const MonitorDashboard()),
      ],
    );
  }
}
