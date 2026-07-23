import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'chat/chat_screen.dart';
import 'chat/session_list_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/model_settings_screen.dart';
import 'settings/skill_manager_screen.dart';

/// 小酥 APP 路由配置
/// 使用 go_router 管理所有页面路由
/// 支持深链接、转场动画
class AppRouter {
  AppRouter._();

  // ==================== 路由路径常量 ====================
  static const String home = '/';
  static const String chat = '/chat';
  static const String chatWithId = '/chat/:sessionId';
  static const String sessions = '/sessions';
  static const String settings = '/settings';
  static const String settingsModel = '/settings/model';
  static const String settingsSkills = '/settings/skills';

  // ==================== 路由配置 ====================

  /// 创建 GoRouter 实例
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: home,
      debugLogDiagnostics: true,

      // 路由匹配
      routes: [
        // 首页仪表盘
        GoRoute(
          path: home,
          name: 'home',
          builder: (context, state) => const DashboardScreen(),
          // 深链接支持
          routes: [],
        ),

        // 聊天界面（新对话）
        GoRoute(
          path: chat,
          name: 'chat',
          builder: (context, state) => const ChatScreen(),
          pageBuilder: (context, state) => _buildPage(
            context: context,
            child: const ChatScreen(),
            animationType: AnimationType.slideUp,
          ),
        ),

        // 聊天界面（指定会话）
        GoRoute(
          path: chatWithId,
          name: 'chatSession',
          builder: (context, state) {
            final sessionId = state.pathParameters['sessionId'];
            return ChatScreen(sessionId: sessionId);
          },
          pageBuilder: (context, state) {
            final sessionId = state.pathParameters['sessionId'];
            return _buildPage(
              context: context,
              child: ChatScreen(sessionId: sessionId),
              animationType: AnimationType.slideUp,
            );
          },
        ),

        // 会话列表
        GoRoute(
          path: sessions,
          name: 'sessions',
          builder: (context, state) => const SessionListScreen(),
          pageBuilder: (context, state) => _buildPage(
            context: context,
            child: const SessionListScreen(),
            animationType: AnimationType.slideRight,
          ),
        ),

        // 设置主页
        GoRoute(
          path: settings,
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
          pageBuilder: (context, state) => _buildPage(
            context: context,
            child: const SettingsScreen(),
            animationType: AnimationType.slideRight,
          ),
        ),

        // 模型设置
        GoRoute(
          path: settingsModel,
          name: 'settingsModel',
          builder: (context, state) => const ModelSettingsScreen(),
          pageBuilder: (context, state) => _buildPage(
            context: context,
            child: const ModelSettingsScreen(),
            animationType: AnimationType.slideRight,
          ),
        ),

        // 技能管理
        GoRoute(
          path: settingsSkills,
          name: 'settingsSkills',
          builder: (context, state) => const SkillManagerScreen(),
          pageBuilder: (context, state) => _buildPage(
            context: context,
            child: const SkillManagerScreen(),
            animationType: AnimationType.slideRight,
          ),
        ),
      ],

      // 错误处理
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                '页面未找到',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '路径: ${state.uri}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(home),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),

      // 路由重定向
      redirect: (context, state) {
        // 这里可以添加路由重定向逻辑
        // 例如：未登录时重定向到登录页
        return null;
      },

      // 刷新监听（深链接）
      refreshListenable: GoRouterRefreshStream(),
    );
  }

  // ==================== 转场动画 ====================

  /// 自定义页面构建器
  static CustomTransitionPage _buildPage({
    required BuildContext context,
    required Widget child,
    AnimationType animationType = AnimationType.fade,
  }) {
    return CustomTransitionPage<void>(
      key: ValueKey(context.hashCode),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        switch (animationType) {
          case AnimationType.fade:
            return _fadeTransition(animation, child);
          case AnimationType.slideRight:
            return _slideRightTransition(animation, child);
          case AnimationType.slideUp:
            return _slideUpTransition(animation, child);
          case AnimationType.scale:
            return _scaleTransition(animation, child);
        }
      },
      transitionDuration: AppTheme.pageTransitionDuration,
    );
  }

  /// 淡入淡出动画
  static Widget _fadeTransition(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }

  /// 从右滑入动画
  static Widget _slideRightTransition(
    Animation<double> animation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: AppTheme.curveEmphasized,
      )),
      child: child,
    );
  }

  /// 从下滑入动画
  static Widget _slideUpTransition(
    Animation<double> animation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: AppTheme.curveEmphasized,
      )),
      child: child,
    );
  }

  /// 缩放动画
  static Widget _scaleTransition(
    Animation<double> animation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.9,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: AppTheme.curveEmphasized,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

/// 动画类型枚举
enum AnimationType {
  /// 淡入淡出
  fade,

  /// 从右滑入
  slideRight,

  /// 从下滑入
  slideUp,

  /// 缩放
  scale,
}

/// GoRouter 刷新流
/// 用于监听路由状态变化以支持深链接
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream();
}

// ==================== 路由扩展方法 ====================

/// 路由导航扩展方法
/// 提供类型安全的导航方式
extension RouterNavigation on BuildContext {
  /// 导航到首页
  void goHome() => go(AppRouter.home);

  /// 导航到聊天界面
  void goChat() => push(AppRouter.chat);

  /// 导航到指定会话
  void goChatSession(String sessionId) =>
      push('/chat/$sessionId');

  /// 导航到会话列表
  void goSessions() => push(AppRouter.sessions);

  /// 导航到设置
  void goSettings() => push(AppRouter.settings);

  /// 导航到模型设置
  void goModelSettings() => push(AppRouter.settingsModel);

  /// 导航到技能管理
  void goSkillManager() => push(AppRouter.settingsSkills);
}

// ==================== 路由 Provider ====================

/// GoRouter Provider
final routerProvider = Provider<GoRouter>((ref) {
  return AppRouter.createRouter();
});
