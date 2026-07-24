// ============================================================================
// 小酥 (XiaoSu) - 跨平台统一调度器
//
// 职责：
// 自动识别运行平台，统一封装 iOS / Windows / macOS / Linux 的
// 原生桥接能力（后台任务、通知、系统集成等）
// 上层业务代码仅需调用 PlatformScheduler 统一接口
// ============================================================================

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:logger/logger.dart';

import 'package:xiaosu_core/main.dart' show appLogger;

// ============================================================================
// 平台类型枚举
// ============================================================================

/// 支持的目标平台
enum TargetPlatform_x {
  ios,
  android,
  windows,
  macOS,
  linux,
  web,
  unknown,
}

/// 平台能力描述
class PlatformCapabilities {
  final TargetPlatform_x platform;
  final bool supportsBackgroundTasks;
  final bool supportsPushNotifications;
  final bool supportsBiometricAuth;
  final bool supportsSystemTray;
  final bool supportsGlobalHotkeys;
  final bool supportsFileAssociations;
  final bool supportsAutoStart;
  final bool supportsShareSheet;
  final bool supportsWidgets;
  final bool supportsSpotlight;
  final bool supportsDockControl;
  final bool supportsDBusNotifications;
  final bool supportsAppIndicator;
  final bool supportsSiriShortcuts;
  final bool supportsNotificationCenter;
  final String osVersion;
  final String deviceName;

  const PlatformCapabilities({
    required this.platform,
    this.supportsBackgroundTasks = false,
    this.supportsPushNotifications = false,
    this.supportsBiometricAuth = false,
    this.supportsSystemTray = false,
    this.supportsGlobalHotkeys = false,
    this.supportsFileAssociations = false,
    this.supportsAutoStart = false,
    this.supportsShareSheet = false,
    this.supportsWidgets = false,
    this.supportsSpotlight = false,
    this.supportsDockControl = false,
    this.supportsDBusNotifications = false,
    this.supportsAppIndicator = false,
    this.supportsSiriShortcuts = false,
    this.supportsNotificationCenter = false,
    this.osVersion = '',
    this.deviceName = 'Unknown',
  });

  Map<String, bool> toMap() => {
        'background_tasks': supportsBackgroundTasks,
        'push_notifications': supportsPushNotifications,
        'biometric_auth': supportsBiometricAuth,
        'system_tray': supportsSystemTray,
        'global_hotkeys': supportsGlobalHotkeys,
        'file_associations': supportsFileAssociations,
        'auto_start': supportsAutoStart,
        'share_sheet': supportsShareSheet,
        'widgets': supportsWidgets,
        'spotlight': supportsSpotlight,
        'dock_control': supportsDockControl,
        'dbus_notifications': supportsDBusNotifications,
        'app_indicator': supportsAppIndicator,
        'siri_shortcuts': supportsSiriShortcuts,
        'notification_center': supportsNotificationCenter,
      };

  @override
  String toString() => 'PlatformCapabilities($platform, os=$osVersion)';
}

// ============================================================================
// 统一通知模型
// ============================================================================

/// 跨平台通知
class PlatformNotification {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, String> payload;
  final NotificationPriority priority;
  final DateTime? scheduledTime;

  const PlatformNotification({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.payload = const {},
    this.priority = NotificationPriority.normal,
    this.scheduledTime,
  });
}

enum NotificationPriority { low, normal, high, critical }

/// 通知点击回调
typedef NotificationTapCallback = void Function(PlatformNotification notification);

// ============================================================================
// 文件路径服务
// ============================================================================

/// 跨平台统一文件路径
class PlatformFilePaths {
  final TargetPlatform_x platform;

  const PlatformFilePaths(this.platform);

  /// 应用数据目录
  String get appDataDir {
    switch (platform) {
      case TargetPlatform_x.iOS:
        return '~/Documents/XiaoSu';
      case TargetPlatform_x.macOS:
        return '~/Library/Application Support/XiaoSu';
      case TargetPlatform_x.windows:
        return r'%APPDATA%\XiaoSu';
      case TargetPlatform_x.linux:
        return '~/.local/share/xiaosu';
      case TargetPlatform_x.android:
        return '/data/data/com.xiaosu.app/files';
      default:
        return '.';
    }
  }

  /// 缓存目录
  String get cacheDir {
    switch (platform) {
      case TargetPlatform_x.iOS:
        return '~/Library/Caches/XiaoSu';
      case TargetPlatform_x.macOS:
        return '~/Library/Caches/XiaoSu';
      case TargetPlatform_x.windows:
        return r'%LOCALAPPDATA%\XiaoSu\Cache';
      case TargetPlatform_x.linux:
        return '~/.cache/xiaosu';
      case TargetPlatform_x.android:
        return '/data/data/com.xiaosu.app/cache';
      default:
        return '.';
    }
  }

  /// 日志目录
  String get logDir {
    switch (platform) {
      case TargetPlatform_x.iOS:
        return '~/Library/Logs/XiaoSu';
      case TargetPlatform_x.macOS:
        return '~/Library/Logs/XiaoSu';
      case TargetPlatform_x.windows:
        return r'%LOCALAPPDATA%\XiaoSu\Logs';
      case TargetPlatform_x.linux:
        return '~/.local/state/xiaosu/logs';
      default:
        return '$appDataDir/logs';
    }
  }

  /// 自启动配置文件路径
  String get autoStartConfigPath {
    switch (platform) {
      case TargetPlatform_x.linux:
        return '~/.config/autostart/xiaosu.desktop';
      case TargetPlatform_x.windows:
        return r'%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\xiaosu.lnk';
      case TargetPlatform_x.macOS:
        return '~/Library/LaunchAgents/com.xiaosu.app.plist';
      default:
        return '';
    }
  }
}

// ============================================================================
// PlatformScheduler 主类
// ============================================================================

/// 跨平台统一调度器
///
/// 提供平台检测、初始化、服务注册、通知、文件路径等统一接口。
/// 内部根据当前平台委托到对应的桥接实现。
class PlatformScheduler {
  // ─── MethodChannel 实例 ───
  static const MethodChannel _iosChannel = MethodChannel('com.xiaosu.ios_scheduler');
  static const MethodChannel _winChannel = MethodChannel('com.xiaosu.windows_scheduler');
  static const MethodChannel _macChannel = MethodChannel('com.xiaosu.macos_scheduler');
  static const MethodChannel _linuxChannel = MethodChannel('com.xiaosu.linux_scheduler');

  // ─── 日志 ───
  final Logger _logger = appLogger;

  // ─── 平台状态 ───
  TargetPlatform_x _detectedPlatform = TargetPlatform_x.unknown;
  PlatformCapabilities? _capabilities;
  bool _initialized = false;

  // ─── 通知回调 ───
  final Map<String, NotificationTapCallback> _notificationCallbacks = {};
  NotificationTapCallback? _globalNotificationTap;

  // ─── 文件路径服务 ───
  late PlatformFilePaths _filePaths;

  // ─── 注册的平台服务 ───
  final Map<String, PlatformServiceEntry> _registeredServices = {};

  // =========================================================================
  // 平台检测
  // =========================================================================

  /// 当前平台
  TargetPlatform_x get currentPlatform => _detectedPlatform;

  /// 平台能力
  PlatformCapabilities get capabilities => _capabilities ?? const PlatformCapabilities(platform: TargetPlatform_x.unknown);

  /// 文件路径服务
  PlatformFilePaths get filePaths => _filePaths;

  /// 是否已初始化
  bool get isInitialized => _initialized;

  // =========================================================================
  // 初始化
  // =========================================================================

  /// 平台初始化（应用启动时调用一次）
  Future<void> initPlatform() async {
    if (_initialized) {
      _logger.w('PlatformScheduler 已初始化，跳过');
      return;
    }

    _logger.i('🖥️ PlatformScheduler 初始化开始...');
    final stopwatch = Stopwatch()..start();

    // 检测平台
    _detectedPlatform = _detectPlatform();
    _logger.i('  检测到平台: $_detectedPlatform');

    // 初始化文件路径服务
    _filePaths = PlatformFilePaths(_detectedPlatform);

    // 获取平台能力
    _capabilities = await _queryCapabilities();
    _logger.i('  平台能力: ${_capabilities!.toMap().entries.where((e) => e.value).map((e) => e.key).join(", ")}');

    // 平台特定初始化
    switch (_detectedPlatform) {
      case TargetPlatform_x.iOS:
        await _initIos();
        break;
      case TargetPlatform_x.windows:
        await _initWindows();
        break;
      case TargetPlatform_x.macOS:
        await _initMacOS();
        break;
      case TargetPlatform_x.linux:
        await _initLinux();
        break;
      default:
        _logger.d('  当前平台无需额外初始化');
    }

    _initialized = true;
    stopwatch.stop();
    _logger.i('🖥️ PlatformScheduler 初始化完成 (${stopwatch.elapsedMilliseconds}ms)');
  }

  /// 检测当前运行平台
  TargetPlatform_x _detectPlatform() {
    if (kIsWeb) return TargetPlatform_x.web;
    if (Platform.isIOS) return TargetPlatform_x.ios;
    if (Platform.isAndroid) return TargetPlatform_x.android;
    if (Platform.isWindows) return TargetPlatform_x.windows;
    if (Platform.isMacOS) return TargetPlatform_x.macOS;
    if (Platform.isLinux) return TargetPlatform_x.linux;
    return TargetPlatform_x.unknown;
  }

  /// 查询平台能力
  Future<PlatformCapabilities> _queryCapabilities() async {
    switch (_detectedPlatform) {
      case TargetPlatform_x.iOS:
        return const PlatformCapabilities(
          platform: TargetPlatform_x.ios,
          supportsBackgroundTasks: true,
          supportsPushNotifications: true,
          supportsBiometricAuth: true,
          supportsShareSheet: true,
          supportsWidgets: true,
          supportsSiriShortcuts: true,
        );
      case TargetPlatform_x.windows:
        return const PlatformCapabilities(
          platform: TargetPlatform_x.windows,
          supportsSystemTray: true,
          supportsGlobalHotkeys: true,
          supportsFileAssociations: true,
          supportsAutoStart: true,
          supportsPushNotifications: true,
        );
      case TargetPlatform_x.macOS:
        return const PlatformCapabilities(
          platform: TargetPlatform_x.macOS,
          supportsSystemTray: true,
          supportsSpotlight: true,
          supportsDockControl: true,
          supportsNotificationCenter: true,
          supportsAutoStart: true,
          supportsBiometricAuth: true,
        );
      case TargetPlatform_x.linux:
        return const PlatformCapabilities(
          platform: TargetPlatform_x.linux,
          supportsAppIndicator: true,
          supportsDBusNotifications: true,
          supportsAutoStart: true,
        );
      case TargetPlatform_x.android:
        return const PlatformCapabilities(
          platform: TargetPlatform_x.android,
          supportsBackgroundTasks: true,
          supportsPushNotifications: true,
          supportsBiometricAuth: true,
          supportsShareSheet: true,
        );
      default:
        return const PlatformCapabilities(platform: TargetPlatform_x.unknown);
    }
  }

  // =========================================================================
  // 服务注册
  // =========================================================================

  /// 注册平台服务
  Future<void> registerPlatformServices() async {
    _logger.i('📦 注册平台服务...');

    // 注册统一通知服务
    _registerService('notification', PlatformServiceEntry(
      name: '统一通知服务',
      initCallback: _initNotificationService,
    ));

    // 注册后台任务服务
    if (capabilities.supportsBackgroundTasks) {
      _registerService('background_task', PlatformServiceEntry(
        name: '后台任务服务',
        initCallback: _initBackgroundTaskService,
      ));
    }

    // 注册系统集成服务
    if (capabilities.supportsSystemTray || capabilities.supportsAppIndicator) {
      _registerService('system_tray', PlatformServiceEntry(
        name: '系统托盘服务',
        initCallback: _initSystemTrayService,
      ));
    }

    // 初始化所有服务
    for (final entry in _registeredServices.values) {
      try {
        await entry.initCallback();
        _logger.d('  ✓ ${entry.name} 已初始化');
      } catch (e) {
        _logger.e('  ✗ ${entry.name} 初始化失败: $e');
      }
    }
  }

  void _registerService(String key, PlatformServiceEntry entry) {
    _registeredServices[key] = entry;
  }

  // =========================================================================
  // iOS 特定实现
  // =========================================================================

  Future<void> _initIos() async {
    try {
      await _iosChannel.invokeMethod('initialize');
      _logger.d('  iOS 原生桥接已初始化');
    } on PlatformException catch (e) {
      _logger.w('  iOS 初始化失败: ${e.message}');
    }
  }

  /// iOS: 注册后台任务 (BGTaskScheduler)
  Future<bool> registerBackgroundTask({
    required String taskId,
    required Duration interval,
    required String prompt,
  }) async {
    try {
      final result = await _iosChannel.invokeMethod<bool>('registerBGTask', {
        'taskId': taskId,
        'intervalSeconds': interval.inSeconds,
        'prompt': prompt,
      });
      return result ?? false;
    } catch (e) {
      _logger.e('注册 iOS 后台任务失败: $e');
      return false;
    }
  }

  /// iOS: 注册推送通知 (APNs)
  Future<bool> registerPushNotifications() async {
    try {
      final result = await _iosChannel.invokeMethod<bool>('registerAPNs');
      return result ?? false;
    } catch (e) {
      _logger.e('注册 APNs 失败: $e');
      return false;
    }
  }

  /// iOS: 生物识别认证 (LocalAuthentication)
  Future<bool> authenticateWithBiometrics({String reason = '请验证身份'}) async {
    try {
      final result = await _iosChannel.invokeMethod<bool>('biometricAuth', {
        'reason': reason,
      });
      return result ?? false;
    } catch (e) {
      _logger.e('生物识别认证失败: $e');
      return false;
    }
  }

  /// iOS: 分享 (Share Sheet)
  Future<bool> shareContent({required String text, String? url}) async {
    try {
      await _iosChannel.invokeMethod('share', {
        'text': text,
        if (url != null) 'url': url,
      });
      return true;
    } catch (e) {
      _logger.e('分享失败: $e');
      return false;
    }
  }

  /// iOS: Widget 数据更新
  Future<bool> updateWidgetData(String widgetId, Map<String, dynamic> data) async {
    try {
      await _iosChannel.invokeMethod('updateWidget', {
        'widgetId': widgetId,
        'data': data,
      });
      return true;
    } catch (e) {
      _logger.e('Widget 更新失败: $e');
      return false;
    }
  }

  /// iOS: 快捷指令 (Siri Shortcuts)
  Future<bool> registerSiriShortcut({
    required String activityId,
    required String title,
    required String prompt,
  }) async {
    try {
      await _iosChannel.invokeMethod('registerShortcut', {
        'activityId': activityId,
        'title': title,
        'prompt': prompt,
      });
      return true;
    } catch (e) {
      _logger.e('Siri 快捷指令注册失败: $e');
      return false;
    }
  }

  // =========================================================================
  // Windows 特定实现
  // =========================================================================

  Future<void> _initWindows() async {
    try {
      await _winChannel.invokeMethod('initialize');
      _logger.d('  Windows 原生桥接已初始化');
    } on PlatformException catch (e) {
      _logger.w('  Windows 初始化失败: ${e.message}');
    }
  }

  /// Windows: 系统托盘
  Future<void> setupSystemTray({String? tooltip, List<TrayMenuItem>? menuItems}) async {
    try {
      await _winChannel.invokeMethod('setupTray', {
        'tooltip': tooltip ?? '小酥 AI 助手',
        'menuItems': menuItems?.map((m) => m.toMap()).toList() ?? [],
      });
    } catch (e) {
      _logger.e('系统托盘设置失败: $e');
    }
  }

  /// Windows: 注册全局快捷键
  Future<bool> registerGlobalHotkey({
    required String hotkeyId,
    required int keyCode,
    required List<int> modifiers,
  }) async {
    try {
      final result = await _winChannel.invokeMethod<bool>('registerHotkey', {
        'hotkeyId': hotkeyId,
        'keyCode': keyCode,
        'modifiers': modifiers,
      });
      return result ?? false;
    } catch (e) {
      _logger.e('全局快捷键注册失败: $e');
      return false;
    }
  }

  /// Windows: 文件关联
  Future<bool> registerFileAssociation(String extension) async {
    try {
      final result = await _winChannel.invokeMethod<bool>('registerFileAssoc', {
        'extension': extension,
      });
      return result ?? false;
    } catch (e) {
      _logger.e('文件关联注册失败: $e');
      return false;
    }
  }

  /// Windows: 自启动
  Future<bool> setAutoStart({required bool enable, String? args}) async {
    try {
      final result = await _winChannel.invokeMethod<bool>('setAutoStart', {
        'enable': enable,
        if (args != null) 'args': args,
      });
      return result ?? false;
    } catch (e) {
      _logger.e('自启动设置失败: $e');
      return false;
    }
  }

  /// Windows: Toast 通知
  Future<bool> showWindowsNotification(PlatformNotification notification) async {
    try {
      await _winChannel.invokeMethod('showToast', {
        'id': notification.id,
        'title': notification.title,
        'body': notification.body,
        if (notification.imageUrl != null) 'imageUrl': notification.imageUrl,
      });
      return true;
    } catch (e) {
      _logger.e('Toast 通知失败: $e');
      return false;
    }
  }

  // =========================================================================
  // macOS 特定实现
  // =========================================================================

  Future<void> _initMacOS() async {
    try {
      await _macChannel.invokeMethod('initialize');
      _logger.d('  macOS 原生桥接已初始化');
    } on PlatformException catch (e) {
      _logger.w('  macOS 初始化失败: ${e.message}');
    }
  }

  /// macOS: 菜单栏应用
  Future<void> setupMenuBarApp({bool enabled = true}) async {
    try {
      await _macChannel.invokeMethod('setupMenuBar', {'enabled': enabled});
    } catch (e) {
      _logger.e('菜单栏设置失败: $e');
    }
  }

  /// macOS: Spotlight 集成
  Future<bool> registerSpotlightItem({
    required String title,
    required String content,
    Map<String, String>? metadata,
  }) async {
    try {
      await _macChannel.invokeMethod('registerSpotlight', {
        'title': title,
        'content': content,
        'metadata': metadata ?? {},
      });
      return true;
    } catch (e) {
      _logger.e('Spotlight 注册失败: $e');
      return false;
    }
  }

  /// macOS: Dock 图标控制
  Future<void> setDockBadge({String? label, int? count}) async {
    try {
      await _macChannel.invokeMethod('setDockBadge', {
        if (label != null) 'label': label,
        if (count != null) 'count': count,
      });
    } catch (e) {
      _logger.e('Dock 设置失败: $e');
    }
  }

  /// macOS: 通知中心
  Future<bool> postMacNotification(PlatformNotification notification) async {
    try {
      await _macChannel.invokeMethod('postNotification', {
        'id': notification.id,
        'title': notification.title,
        'body': notification.body,
      });
      return true;
    } catch (e) {
      _logger.e('macOS 通知失败: $e');
      return false;
    }
  }

  // =========================================================================
  // Linux 特定实现
  // =========================================================================

  Future<void> _initLinux() async {
    try {
      await _linuxChannel.invokeMethod('initialize');
      _logger.d('  Linux 原生桥接已初始化');
    } on PlatformException catch (e) {
      _logger.w('  Linux 初始化失败: ${e.message}');
    }
  }

  /// Linux: AppIndicator 系统托盘
  Future<void> setupAppIndicator({
    String? iconName,
    List<TrayMenuItem>? menuItems,
  }) async {
    try {
      await _linuxChannel.invokeMethod('setupAppIndicator', {
        'iconName': iconName ?? 'xiaosu',
        'menuItems': menuItems?.map((m) => m.toMap()).toList() ?? [],
      });
    } catch (e) {
      _logger.e('AppIndicator 设置失败: $e');
    }
  }

  /// Linux: D-Bus 通知
  Future<bool> sendDBusNotification(PlatformNotification notification) async {
    try {
      await _linuxChannel.invokeMethod('dbusNotify', {
        'appName': 'XiaoSu',
        'summary': notification.title,
        'body': notification.body,
        'urgency': switch (notification.priority) {
          NotificationPriority.low => 0,
          NotificationPriority.normal => 1,
          NotificationPriority.high => 2,
          NotificationPriority.critical => 2,
        },
      });
      return true;
    } catch (e) {
      _logger.e('D-Bus 通知失败: $e');
      return false;
    }
  }

  /// Linux: 自启动 (.desktop 文件)
  Future<bool> setLinuxAutoStart({required bool enable}) async {
    try {
      final result = await _linuxChannel.invokeMethod<bool>('setAutoStart', {
        'enable': enable,
        'desktopFile': _filePaths.autoStartConfigPath,
      });
      return result ?? false;
    } catch (e) {
      _logger.e('Linux 自启动设置失败: $e');
      return false;
    }
  }

  // =========================================================================
  // 统一通知服务
  // =========================================================================

  Future<void> _initNotificationService() async {
    _logger.d('  初始化统一通知服务...');
  }

  Future<void> _initBackgroundTaskService() async {
    _logger.d('  初始化后台任务服务...');
  }

  Future<void> _initSystemTrayService() async {
    _logger.d('  初始化系统托盘服务...');
  }

  /// 发送统一通知（自动适配平台）
  Future<bool> sendNotification(PlatformNotification notification) async {
    switch (_detectedPlatform) {
      case TargetPlatform_x.iOS:
        return _sendIosNotification(notification);
      case TargetPlatform_x.android:
        return _sendAndroidNotification(notification);
      case TargetPlatform_x.windows:
        return showWindowsNotification(notification);
      case TargetPlatform_x.macOS:
        return postMacNotification(notification);
      case TargetPlatform_x.linux:
        return sendDBusNotification(notification);
      default:
        _logger.w('当前平台不支持通知');
        return false;
    }
  }

  Future<bool> _sendIosNotification(PlatformNotification notification) async {
    try {
      await _iosChannel.invokeMethod('showLocalNotification', {
        'id': notification.id,
        'title': notification.title,
        'body': notification.body,
        if (notification.scheduledTime != null)
          'fireDate': notification.scheduledTime!.toIso8601String(),
        'payload': notification.payload,
      });
      return true;
    } catch (e) {
      _logger.e('iOS 通知发送失败: $e');
      return false;
    }
  }

  Future<bool> _sendAndroidNotification(PlatformNotification notification) async {
    try {
      const androidChannel = MethodChannel('com.xiaosu.android_notification');
      await androidChannel.invokeMethod('showNotification', {
        'id': notification.id.hashCode,
        'title': notification.title,
        'body': notification.body,
        'payload': notification.payload,
      });
      return true;
    } catch (e) {
      _logger.e('Android 通知发送失败: $e');
      return false;
    }
  }

  /// 监听通知点击
  void onNotificationTap(NotificationTapCallback callback) {
    _globalNotificationTap = callback;
  }

  // =========================================================================
  // 生命周期
  // =========================================================================

  /// 获取系统状态摘要
  Map<String, dynamic> getStatusSummary() {
    return {
      'platform': _detectedPlatform.name,
      'initialized': _initialized,
      'capabilities': _capabilities?.toMap(),
      'registered_services': _registeredServices.keys.toList(),
      'app_data_dir': _filePaths.appDataDir,
      'cache_dir': _filePaths.cacheDir,
      'log_dir': _filePaths.logDir,
    };
  }

  /// 释放资源
  Future<void> dispose() async {
    _logger.i('PlatformScheduler 释放资源...');
    _registeredServices.clear();
    _notificationCallbacks.clear();
    _initialized = false;
  }
}

// ============================================================================
// 辅助类
// ============================================================================

/// 平台服务条目
class PlatformServiceEntry {
  final String name;
  final Future<void> Function() initCallback;
  bool isInitialized = false;

  PlatformServiceEntry({
    required this.name,
    required this.initCallback,
  });
}

/// 托盘菜单项
class TrayMenuItem {
  final String id;
  final String label;
  final bool enabled;
  final bool isSeparator;

  const TrayMenuItem({
    required this.id,
    required this.label,
    this.enabled = true,
    this.isSeparator = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'enabled': enabled,
        'isSeparator': isSeparator,
      };
}
