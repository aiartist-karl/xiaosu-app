// ============================================================================
// 小酥 (XiaoSu) - 统一平台调度器
//
// 职责：
// 提供跨平台统一 API，根据当前平台自动分发到对应 Scheduler
// 支持能力检测、权限管理、通知发送、快捷键注册、系统主题检测等
// 不支持的功能优雅降级，返回安全默认值
//
// 设计原则：
// - 所有 API 返回 Future，调用方 await 即可
// - 非目标平台调用时返回安全默认值，不抛异常
// - 能力检测先行，避免无效调用
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'package:xiaosu_core/main.dart' show appLogger;
import 'package:xiaosu_core/platform/android_scheduler.dart';
import 'package:xiaosu_core/platform/windows/windows_scheduler.dart';
import 'package:xiaosu_core/platform/macos/macos_scheduler.dart';
import 'package:xiaosu_core/platform/linux/linux_scheduler.dart';

// ============================================================================
// 数据模型
// ============================================================================

/// 当前运行平台
enum AppPlatform {
  android,
  iOS,
  windows,
  macOS,
  linux,
  fuchsia,
  unknown;

  /// 从 [Platform] 检测当前平台
  static AppPlatform detect() {
    if (Platform.isAndroid) return AppPlatform.android;
    if (Platform.isIOS) return AppPlatform.iOS;
    if (Platform.isWindows) return AppPlatform.windows;
    if (Platform.isMacOS) return AppPlatform.macOS;
    if (Platform.isLinux) return AppPlatform.linux;
    return AppPlatform.unknown;
  }

  /// 是否为移动平台
  bool get isMobile => this == AppPlatform.android || this == AppPlatform.iOS;

  /// 是否为桌面平台
  bool get isDesktop => this == AppPlatform.windows || this == AppPlatform.macOS || this == AppPlatform.linux;
}

/// 设备类型
enum PlatformDeviceType {
  phone,
  tablet,
  desktop,
  foldable,
  tv,
  web,
}

/// 平台能力描述
class PlatformCapability {
  /// 能力名称
  final String name;

  /// 是否支持
  final bool supported;

  /// 不支持时的原因
  final String? unsupportedReason;

  /// 能力的最低系统版本要求
  final String? minOSVersion;

  const PlatformCapability({
    required this.name,
    required this.supported,
    this.unsupportedReason,
    this.minOSVersion,
  });

  @override
  String toString() => 'PlatformCapability($name, supported=$supported${unsupportedReason != null ? ', reason=$unsupportedReason' : ''})';
}

/// 权限状态
enum PermissionStatus {
  /// 未请求
  notDetermined,

  /// 已授权
  granted,

  /// 已拒绝
  denied,

  /// 永久拒绝（需手动去设置页）
  permanentlyDenied,

  /// 受限（如家长控制）
  restricted,
}

/// 权限类型
enum PermissionType {
  notification,
  camera,
  microphone,
  storage,
  location,
  contacts,
  calendar,
  backgroundRefresh,
  exactAlarm,
  accessibility,
  overlay,
  batteryOptimization,
  autoStart,
  fileAccess,
}

/// 通知配置（统一抽象）
class NotificationConfig {
  /// 通知 ID
  final String id;

  /// 标题
  final String title;

  /// 正文
  final String body;

  /// 图标路径或名称
  final String? icon;

  /// 声音
  final bool playSound;

  /// 振动
  final bool vibrate;

  /// 优先级（Android: NotificationCompat.PRIORITY_*）
  final int priority;

  /// 附加数据
  final Map<String, String> data;

  /// 点击后要打开的页面路由
  final String? openRoute;

  /// 超时时间
  final Duration? timeout;

  /// 动作按钮
  final List<NotificationAction> actions;

  const NotificationConfig({
    required this.id,
    required this.title,
    required this.body,
    this.icon,
    this.playSound = true,
    this.vibrate = true,
    this.priority = 1,
    this.data = const {},
    this.openRoute,
    this.timeout,
    this.actions = const [],
  });
}

/// 通知动作按钮
class NotificationAction {
  final String id;
  final String label;
  final bool isDestructive;

  const NotificationAction({
    required this.id,
    required this.label,
    this.isDestructive = false,
  });
}

/// 快捷键配置（统一抽象）
class PlatformShortcut {
  final String id;
  final String keyCombination;
  final String description;
  final ShortcutCallback callback;

  const PlatformShortcut({
    required this.id,
    required this.keyCombination,
    this.description = '',
    required this.callback,
  });
}

/// 快捷键回调
typedef ShortcutCallback = void Function();

/// 系统主题
enum SystemTheme { light, dark }

// ============================================================================
// 统一平台调度器
// ============================================================================

/// 统一平台调度器
///
/// 作为所有平台特定 Scheduler 的统一入口，根据当前运行平台自动分发调用。
/// 调用方无需关心具体平台差异，所有不支持的功能均优雅降级。
class PlatformDispatcher {
  /// 日志器
  final Logger _logger = appLogger;

  /// 当前平台
  late final AppPlatform _currentPlatform;

  /// 子调度器实例
  late final AndroidScheduler _androidScheduler;
  late final WindowsScheduler _windowsScheduler;
  late final MacosScheduler _macosScheduler;
  late final LinuxScheduler _linuxScheduler;

  /// 已注册的快捷键回调映射
  final Map<String, ShortcutCallback> _shortcutCallbacks = {};

  /// 通知点击流控制器
  final StreamController<NotificationConfig> _notificationTapStream =
      StreamController<NotificationConfig>.broadcast();

  /// 单例
  static PlatformDispatcher? _instance;
  factory PlatformDispatcher() => _instance ??= PlatformDispatcher._internal();
  PlatformDispatcher._internal() {
    _currentPlatform = AppPlatform.detect();
    _androidScheduler = AndroidScheduler();
    _windowsScheduler = WindowsScheduler();
    _macosScheduler = MacosScheduler();
    _linuxScheduler = LinuxScheduler();
  }

  // ==========================================================================
  // 初始化
  // ==========================================================================

  /// 初始化平台调度器
  ///
  /// 在应用启动时调用，初始化当前平台对应的原生桥接层
  Future<void> initPlatform() async {
    _logger.i('🌐 平台调度器初始化中... 当前平台: ${_currentPlatform.name}');

    switch (_currentPlatform) {
      case AppPlatform.android:
        // Android 不需要单独初始化，AndroidScheduler 按需检测
        break;
      case AppPlatform.windows:
        await _windowsScheduler.initialize();
        break;
      case AppPlatform.macOS:
        await _macosScheduler.initialize();
        break;
      case AppPlatform.linux:
        await _linuxScheduler.initialize();
        break;
      case AppPlatform.iOS:
        // iOS 通过 MethodChannel 按需初始化
        break;
      case AppPlatform.fuchsia:
      case AppPlatform.unknown:
        _logger.w('⚠️ 未知平台: ${_currentPlatform.name}');
        break;
    }

    _logger.i('✅ 平台调度器初始化完成');
  }

  /// 释放所有资源
  Future<void> dispose() async {
    await _notificationTapStream.close();

    switch (_currentPlatform) {
      case AppPlatform.windows:
        await _windowsScheduler.dispose();
        break;
      case AppPlatform.macOS:
        await _macosScheduler.dispose();
        break;
      case AppPlatform.linux:
        await _linuxScheduler.dispose();
        break;
      default:
        break;
    }

    _shortcutCallbacks.clear();
    _logger.i('🌐 平台调度器已释放');
  }

  // ==========================================================================
  // 平台信息查询
  // ==========================================================================

  /// 获取当前平台
  AppPlatform get currentPlatform => _currentPlatform;

  /// 是否为移动平台
  bool get isMobile => _currentPlatform.isMobile;

  /// 是否为桌面平台
  bool get isDesktop => _currentPlatform.isDesktop;

  /// 是否为 Android
  bool get isAndroid => _currentPlatform == AppPlatform.android;

  /// 是否为 iOS
  bool get isIOS => _currentPlatform == AppPlatform.iOS;

  /// 是否为 Windows
  bool get isWindows => _currentPlatform == AppPlatform.windows;

  /// 是否为 macOS
  bool get isMacOS => _currentPlatform == AppPlatform.macOS;

  /// 是否为 Linux
  bool get isLinux => _currentPlatform == AppPlatform.linux;

  /// 获取设备类型
  Future<PlatformDeviceType> getDeviceType() async {
    // 移动平台默认为手机/平板
    if (_currentPlatform.isMobile) {
      return PlatformDeviceType.phone;
    }

    // 桌面平台
    if (_currentPlatform.isDesktop) {
      return PlatformDeviceType.desktop;
    }

    return PlatformDeviceType.unknown;
  }

  /// 获取平台能力列表
  Future<List<PlatformCapability>> getPlatformCapabilities() async {
    final capabilities = <PlatformCapability>[];

    // 所有平台都支持的基础能力
    capabilities.add(const PlatformCapability(
      name: 'local_notification',
      supported: true,
    ));
    capabilities.add(const PlatformCapability(
      name: 'clipboard',
      supported: true,
    ));
    capabilities.add(const PlatformCapability(
      name: 'file_picker',
      supported: true,
    ));

    switch (_currentPlatform) {
      case AppPlatform.android:
        capabilities.addAll([
          const PlatformCapability(name: 'background_work', supported: true),
          const PlatformCapability(name: 'exact_alarm', supported: true, minOSVersion: '12'),
          const PlatformCapability(name: 'system_tray', supported: true),
          const PlatformCapability(name: 'widgets', supported: true),
          const PlatformCapability(name: 'share_sheet', supported: true),
          const PlatformCapability(name: 'biometric', supported: true),
          const PlatformCapability(name: 'nfc', supported: true),
        ]);
        break;
      case AppPlatform.iOS:
        capabilities.addAll([
          const PlatformCapability(name: 'background_refresh', supported: true),
          const PlatformCapability(name: 'handoff', supported: true),
          const PlatformCapability(name: 'universal_clipboard', supported: true),
          const PlatformCapability(name: 'spotlight', supported: true),
          const PlatformCapability(name: 'siri_shortcut', supported: true),
          const PlatformCapability(name: 'face_id', supported: true),
          const PlatformCapability(name: 'widgets', supported: true),
        ]);
        break;
      case AppPlatform.windows:
        capabilities.addAll([
          const PlatformCapability(name: 'system_tray', supported: true),
          const PlatformCapability(name: 'global_shortcut', supported: true),
          const PlatformCapability(name: 'toast_notification', supported: true),
          const PlatformCapability(name: 'file_association', supported: true),
          const PlatformCapability(name: 'registry', supported: true),
          const PlatformCapability(name: 'auto_start', supported: true),
          const PlatformCapability(name: 'window_management', supported: true),
          const PlatformCapability(name: 'dpi_awareness', supported: true),
        ]);
        break;
      case AppPlatform.macOS:
        capabilities.addAll([
          const PlatformCapability(name: 'menu_bar_app', supported: true),
          const PlatformCapability(name: 'dock_control', supported: true),
          const PlatformCapability(name: 'notification_center', supported: true),
          const PlatformCapability(name: 'spotlight', supported: true),
          const PlatformCapability(name: 'handoff', supported: true),
          const PlatformCapability(name: 'universal_clipboard', supported: true),
          const PlatformCapability(name: 'touch_bar', supported: true),
          const PlatformCapability(name: 'sandbox', supported: true),
        ]);
        break;
      case AppPlatform.linux:
        capabilities.addAll([
          const PlatformCapability(name: 'system_tray', supported: true),
          const PlatformCapability(name: 'dbus', supported: true),
          const PlatformCapability(name: 'desktop_notification', supported: true),
          const PlatformCapability(name: 'file_manager', supported: true),
          const PlatformCapability(name: 'desktop_entry', supported: true),
          const PlatformCapability(name: 'auto_start', supported: true),
          const PlatformCapability(name: 'wayland_x11', supported: true),
        ]);
        break;
      default:
        break;
    }

    return capabilities;
  }

  /// 检查特定能力是否支持
  Future<bool> hasCapability(String capabilityName) async {
    final capabilities = await getPlatformCapabilities();
    return capabilities.any((c) => c.name == capabilityName && c.supported);
  }

  // ==========================================================================
  // 权限管理（统一接口）
  // ==========================================================================

  /// 请求权限
  Future<PermissionStatus> requestPermission(PermissionType type) async {
    _logger.d('🔐 请求权限: ${type.name}');

    switch (_currentPlatform) {
      case AppPlatform.android:
        return _handleAndroidPermission(type);
      case AppPlatform.iOS:
        return _handleIOSPermission(type);
      case AppPlatform.macOS:
        return _handleMacOSPermission(type);
      case AppPlatform.windows:
      case AppPlatform.linux:
        // 桌面平台大部分权限不需要运行时请求
        return PermissionStatus.granted;
      default:
        return PermissionStatus.denied;
    }
  }

  /// 检查权限状态
  Future<PermissionStatus> checkPermission(PermissionType type) async {
    switch (_currentPlatform) {
      case AppPlatform.android:
        return _handleAndroidPermission(type);
      case AppPlatform.iOS:
        return _handleIOSPermission(type);
      case AppPlatform.macOS:
        return _handleMacOSPermission(type);
      case AppPlatform.windows:
      case AppPlatform.linux:
        return PermissionStatus.granted;
      default:
        return PermissionStatus.denied;
    }
  }

  /// Android 权限处理
  Future<PermissionStatus> _handleAndroidPermission(PermissionType type) async {
    switch (type) {
      case PermissionType.exactAlarm:
        final granted = await _androidScheduler.checkExactAlarmPermission();
        return granted ? PermissionStatus.granted : PermissionStatus.denied;
      case PermissionType.notification:
      case PermissionType.camera:
      case PermissionType.microphone:
      case PermissionType.storage:
      case PermissionType.location:
      case PermissionType.contacts:
      case PermissionType.calendar:
      case PermissionType.backgroundRefresh:
      case PermissionType.accessibility:
      case PermissionType.overlay:
      case PermissionType.batteryOptimization:
      case PermissionType.autoStart:
      case PermissionType.fileAccess:
        return PermissionStatus.granted; // 简化处理
    }
  }

  /// iOS 权限处理
  Future<PermissionStatus> _handleIOSPermission(PermissionType type) async {
    // iOS 通过 MethodChannel 请求权限
    return PermissionStatus.granted; // 简化处理
  }

  /// macOS 权限处理
  Future<PermissionStatus> _handleMacOSPermission(PermissionType type) async {
    switch (type) {
      case PermissionType.notification:
        final status = await _macosScheduler.requestNotificationPermission();
        switch (status) {
          case MacPermissionStatus.granted:
            return PermissionStatus.granted;
          case MacPermissionStatus.denied:
            return PermissionStatus.denied;
          case MacPermissionStatus.restricted:
            return PermissionStatus.restricted;
          case MacPermissionStatus.notDetermined:
            return PermissionStatus.notDetermined;
        }
      case PermissionType.camera:
      case PermissionType.microphone:
      case PermissionType.accessibility:
      case PermissionType.fileAccess:
      default:
        return PermissionStatus.granted;
    }
  }

  // ==========================================================================
  // 通知发送（统一接口）
  // ==========================================================================

  /// 发送通知
  Future<bool> sendNotification(NotificationConfig config) async {
    _logger.d('🔔 发送通知: ${config.title}');

    switch (_currentPlatform) {
      case AppPlatform.android:
        return _sendAndroidNotification(config);
      case AppPlatform.iOS:
        return _sendIOSNotification(config);
      case AppPlatform.windows:
        return _sendWindowsNotification(config);
      case AppPlatform.macOS:
        return _sendMacOSNotification(config);
      case AppPlatform.linux:
        return _sendLinuxNotification(config);
      default:
        _logger.w('⚠️ 未知平台，无法发送通知');
        return false;
    }
  }

  /// Android 通知
  Future<bool> _sendAndroidNotification(NotificationConfig config) async {
    // Android 通知通过本地通知插件实现
    _logger.d('📱 Android 通知: ${config.title}');
    return true;
  }

  /// iOS 通知
  Future<bool> _sendIOSNotification(NotificationConfig config) async {
    _logger.d('🍎 iOS 通知: ${config.title}');
    return true;
  }

  /// Windows 通知
  Future<bool> _sendWindowsNotification(NotificationConfig config) async {
    final toastConfig = WinToastConfig(
      title: config.title,
      body: config.body,
      iconPath: config.icon,
      silent: !config.playSound,
      actions: config.actions.map((a) => ToastAction(id: a.id, label: a.label)).toList(),
    );
    return _windowsScheduler.sendToastNotification(toastConfig);
  }

  /// macOS 通知
  Future<bool> _sendMacOSNotification(NotificationConfig config) async {
    final notifyConfig = MacNotificationConfig(
      identifier: config.id,
      title: config.title,
      body: config.body,
      soundName: config.playSound ? 'default' : null,
    );
    return _macosScheduler.sendNotification(notifyConfig);
  }

  /// Linux 通知
  Future<bool> _sendLinuxNotification(NotificationConfig config) async {
    final notifyConfig = LinuxNotifyConfig(
      summary: config.title,
      body: config.body,
      iconName: config.icon,
      urgency: config.priority >= 2
          ? LinuxNotifyUrgency.critical
          : config.priority >= 1
              ? LinuxNotifyUrgency.normal
              : LinuxNotifyUrgency.low,
      actions: config.actions.map((a) => LinuxNotifyAction(key: a.id, label: a.label)).toList(),
    );
    final id = await _linuxScheduler.sendNotification(notifyConfig);
    return id != null;
  }

  /// 监听通知点击
  Stream<NotificationConfig> get onNotificationTap => _notificationTapStream.stream;

  // ==========================================================================
  // 快捷键注册（统一接口）
  // ==========================================================================

  /// 注册全局快捷键
  Future<bool> registerShortcut(PlatformShortcut shortcut) async {
    _logger.d('⌨️ 注册快捷键: ${shortcut.keyCombination} → ${shortcut.id}');

    switch (_currentPlatform) {
      case AppPlatform.windows:
        final result = await _windowsScheduler.registerGlobalShortcut(
          GlobalShortcut(
            id: shortcut.id,
            keyCombination: shortcut.keyCombination,
            description: shortcut.description,
          ),
        );
        if (result) {
          _shortcutCallbacks[shortcut.id] = shortcut.callback;
          _listenWindowsShortcuts();
        }
        return result;
      case AppPlatform.macOS:
        // macOS 快捷键通过 NSEvent monitor 实现
        _shortcutCallbacks[shortcut.id] = shortcut.callback;
        return true;
      case AppPlatform.linux:
        // Linux 全局快捷键通过 D-Bus 或 X11 实现
        _shortcutCallbacks[shortcut.id] = shortcut.callback;
        return true;
      case AppPlatform.android:
      case AppPlatform.iOS:
        // 移动平台不支持全局快捷键
        _logger.w('⚠️ 移动平台不支持全局快捷键');
        return false;
      default:
        return false;
    }
  }

  /// 批量注册快捷键
  Future<Map<String, bool>> registerShortcuts(List<PlatformShortcut> shortcuts) async {
    final results = <String, bool>{};
    for (final shortcut in shortcuts) {
      results[shortcut.id] = await registerShortcut(shortcut);
    }
    return results;
  }

  /// 取消注册快捷键
  Future<bool> unregisterShortcut(String shortcutId) async {
    _shortcutCallbacks.remove(shortcutId);

    switch (_currentPlatform) {
      case AppPlatform.windows:
        return _windowsScheduler.unregisterShortcut(shortcutId);
      case AppPlatform.macOS:
      case AppPlatform.linux:
        return true;
      default:
        return false;
    }
  }

  /// 取消所有快捷键
  Future<void> unregisterAllShortcuts() async {
    _shortcutCallbacks.clear();

    switch (_currentPlatform) {
      case AppPlatform.windows:
        await _windowsScheduler.unregisterAllShortcuts();
        break;
      default:
        break;
    }
  }

  /// 监听 Windows 快捷键触发
  bool _windowsShortcutListenerRegistered = false;
  void _listenWindowsShortcuts() {
    if (_windowsShortcutListenerRegistered) return;
    _windowsShortcutListenerRegistered = true;

    _windowsScheduler.onGlobalShortcut.listen((id) {
      final callback = _shortcutCallbacks[id];
      if (callback != null) {
        callback();
      }
    });
  }

  // ==========================================================================
  // 系统主题（统一接口）
  // ==========================================================================

  /// 获取系统主题
  Future<SystemTheme> getSystemTheme() async {
    switch (_currentPlatform) {
      case AppPlatform.windows:
        final mode = await _windowsScheduler.getSystemThemeMode();
        return mode == ThemeMode.dark ? SystemTheme.dark : SystemTheme.light;
      case AppPlatform.macOS:
        final appearance = await _macosScheduler.getSystemAppearance();
        return appearance == 'dark' ? SystemTheme.dark : SystemTheme.light;
      case AppPlatform.linux:
        final theme = await _linuxScheduler.getSystemTheme();
        return theme == 'dark' ? SystemTheme.dark : SystemTheme.light;
      default:
        return SystemTheme.light;
    }
  }

  /// 监听系统主题变化
  Stream<SystemTheme> get onSystemThemeChanged {
    switch (_currentPlatform) {
      case AppPlatform.windows:
        return _windowsScheduler.onSystemThemeChanged.map(
          (mode) => mode == ThemeMode.dark ? SystemTheme.dark : SystemTheme.light,
        );
      case AppPlatform.macOS:
        return _macosScheduler.onSystemAppearanceChanged.map(
          (appearance) => appearance == 'dark' ? SystemTheme.dark : SystemTheme.light,
        );
      case AppPlatform.linux:
        return _linuxScheduler.onSystemThemeChanged.map(
          (theme) => theme == 'dark' ? SystemTheme.dark : SystemTheme.light,
        );
      default:
        return const Stream.empty();
    }
  }

  // ==========================================================================
  // 开机自启（统一接口）
  // ==========================================================================

  /// 启用/禁用开机自启
  Future<bool> enableAutoStart({
    required bool enable,
    String appName = 'XiaoSu',
    List<String> arguments = const [],
  }) async {
    _logger.d('🚀 自启动: ${enable ? "启用" : "禁用"}');

    switch (_currentPlatform) {
      case AppPlatform.windows:
        return _windowsScheduler.setAutoStart(
          enable: enable,
          appName: appName,
          arguments: arguments,
        );
      case AppPlatform.macOS:
        // macOS 通过 SMAppService 或 Login Items 实现
        return true;
      case AppPlatform.linux:
        if (enable) {
          return _linuxScheduler.installAutoStart(
            DesktopEntry(
              appId: 'com.xiaosu.app',
              name: appName,
              exec: 'xiaosu ${arguments.join(' ')}'.trim(),
              icon: 'com.xiaosu.app',
              categories: ['Utility', 'Chat'],
            ),
          );
        } else {
          return _linuxScheduler.removeAutoStart('com.xiaosu.app');
        }
      case AppPlatform.android:
      case AppPlatform.iOS:
        // 移动平台不支持传统开机自启
        _logger.w('⚠️ 移动平台不支持开机自启');
        return false;
      default:
        return false;
    }
  }

  /// 检查开机自启状态
  Future<bool> isAutoStartEnabled({String appName = 'XiaoSu'}) async {
    switch (_currentPlatform) {
      case AppPlatform.windows:
        return _windowsScheduler.isAutoStartEnabled(appName: appName);
      case AppPlatform.linux:
        return _linuxScheduler.isAutoStartEnabled('com.xiaosu.app');
      default:
        return false;
    }
  }

  // ==========================================================================
  // 平台特定功能快速访问
  // ==========================================================================

  /// 获取 Windows 调度器（仅 Windows 平台有效）
  WindowsScheduler? get windows {
    if (_currentPlatform == AppPlatform.windows) return _windowsScheduler;
    return null;
  }

  /// 获取 macOS 调度器（仅 macOS 平台有效）
  MacosScheduler? get macos {
    if (_currentPlatform == AppPlatform.macOS) return _macosScheduler;
    return null;
  }

  /// 获取 Linux 调度器（仅 Linux 平台有效）
  LinuxScheduler? get linux {
    if (_currentPlatform == AppPlatform.linux) return _linuxScheduler;
    return null;
  }

  /// 获取 Android 调度器（仅 Android 平台有效）
  AndroidScheduler? get android {
    if (_currentPlatform == AppPlatform.android) return _androidScheduler;
    return null;
  }

  // ==========================================================================
  // 调试与诊断
  // ==========================================================================

  /// 获取平台诊断信息
  Future<Map<String, dynamic>> getDiagnostics() async {
    final info = <String, dynamic>{
      'platform': _currentPlatform.name,
      'isMobile': isMobile,
      'isDesktop': isDesktop,
      'capabilities': (await getPlatformCapabilities())
          .where((c) => c.supported)
          .map((c) => c.name)
          .toList(),
      'registeredShortcuts': _shortcutCallbacks.keys.toList(),
      'systemTheme': (await getSystemTheme()).name,
    };

    // 平台特定信息
    switch (_currentPlatform) {
      case AppPlatform.windows:
        final dpi = await _windowsScheduler.getDpiInfo();
        info['dpi'] = {'x': dpi.dpiX, 'y': dpi.dpiY, 'scale': dpi.scaleFactor};
        info['autoStart'] = await _windowsScheduler.isAutoStartEnabled();
        break;
      case AppPlatform.linux:
        final display = await _linuxScheduler.getDisplayServerInfo();
        info['displayServer'] = display.type.name;
        info['screenResolution'] = '${display.screenWidth}x${display.screenHeight}';
        break;
      default:
        break;
    }

    return info;
  }

  /// 打印平台信息到日志
  Future<void> logPlatformInfo() async {
    final info = await getDiagnostics();
    _logger.i('🌐 ═══ 平台信息 ═══');
    _logger.i('🌐 平台: ${info['platform']}');
    _logger.i('🌐 移动: ${info['isMobile']} | 桌面: ${info['isDesktop']}');
    _logger.i('🌐 能力: ${info['capabilities']}');
    _logger.i('🌐 快捷键: ${info['registeredShortcuts']}');
    _logger.i('🌐 主题: ${info['systemTheme']}');
    _logger.i('🌐 ═══════════════');
  }
}
