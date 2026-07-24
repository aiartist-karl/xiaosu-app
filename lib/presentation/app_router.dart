import 'package:flutter/material.dart';
import 'chat/chat_screen.dart';
import 'settings/settings_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'tools/tools_screen.dart';
import 'agents/agents_screen.dart';
import 'files/file_manager_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String chat = '/chat';
  static const String settings = '/settings';
  static const String dashboard = '/dashboard';
  static const String tools = '/tools';
  static const String agents = '/agents';
  static const String files = '/files';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
      case chat:
        return MaterialPageRoute(
          builder: (_) => const ChatScreen(),
          settings: settings,
        );
      case settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      case dashboard:
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
          settings: settings,
        );
      case tools:
        return MaterialPageRoute(
          builder: (_) => const ToolsScreen(),
          settings: settings,
        );
      case agents:
        return MaterialPageRoute(
          builder: (_) => const AgentsScreen(),
          settings: settings,
        );
      case files:
        return MaterialPageRoute(
          builder: (_) => const FileManagerScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('页面未找到')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text('路径: ${settings.name}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    icon: const Icon(Icons.home),
                    label: const Text('返回首页'),
                  ),
                ],
              ),
            ),
          ),
          settings: settings,
        );
    }
  }
}
