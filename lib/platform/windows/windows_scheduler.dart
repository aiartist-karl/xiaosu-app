// ============================================================================
// 小酥 (XiaoSu) - Windows 平台调度桥接层
//
// 职责：
// 封装 MethodChannel，与 Windows 原生层通信
// 提供系统托盘、窗口管理、全局快捷键、文件关联、注册表操作等 Windows 特有功能
//
// 原生侧（Windows/C++）需要实现：
// - 注册 MethodChannel "com.xiaosu.windows"
// - 处理 system_tray / window_manager / global_shortcut / registry 等方法
// - 使用 Win32 API 实现底层系统交互
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'package:xiaosu_core/main.dart' show appLogger;

// ============================================================================
// 数据模型
// ============================================================================

/// 系统托盘配置
class TrayConfig {
  /// 托盘图标路径（.ico 或 .png）
  final String iconPath;

  /// 悬停提示文本
  final String tooltip;

  /// 右键菜单项
  final List<TrayMenuItem> menuItems;

  /// 单击行为：show_window / show_menu / none
  final TrayClickAction clickAction;

  const TrayConfig({
    required this.iconPath,
    this.tooltip = '小酥',
    this.menuItems = const [],
    this.clickAction = TrayClickAction.showWindow,
  });

  Map<String, dynamic> toJson() => {
        'iconPath': iconPath,
        'tooltip': tooltip,
        'menuItems': menuItems.map((e) => e.toJson()).toList(),
        'clickAction': clickAction.name,
      };
}

/// 托盘单击行为
enum TrayClickAction { showWindow, showMenu, none }

/// 托盘右键菜单项
class TrayMenuItem {
  final String id;
  final String label;
  final String? iconPath;
  final bool enabled;
  final List<TrayMenuItem> subItems;

  const TrayMenuItem({
    required this.id,
    required this.label,
    this.iconPath,
    this.enabled = true,
    this.subItems = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (iconPath != null) 'iconPath': iconPath,
        'enabled': enabled,
        'subItems': subItems.map((e) => e.toJson()).toList(),
      };
}

/// 窗口置顶模式
enum TopMostMode { alwaysOnTop, alwaysOnBottom, normal }

/// 窗口配置
class WinWindowConfig {
  final double minWidth;
  final double minHeight;
  final double? maxWidth;
  final double? maxHeight;
  final bool transparent;
  final double titleBarHeight;
  final bool customTitleBar;
  final TopMostMode topMost;

  const WinWindowConfig({
    this.minWidth = 800,
    this.minHeight = 600,
    this.maxWidth,
    this.maxHeight,
    this.transparent = false,
    this.titleBarHeight = 32.0,
    this.customTitleBar = true,
    this.topMost = TopMostMode.normal,
  });

  Map<String, dynamic> toJson() => {
        'minWidth': minWidth,
        'minHeight': minHeight,
        if (maxWidth != null) 'maxWidth': maxWidth,
        if (maxHeight != null) 'maxHeight': maxHeight,
        'transparent': transparent,
        'titleBarHeight': titleBarHeight,
        'customTitleBar': customTitleBar,
        'topMost': topMost.name,
      };
}

/// 全局快捷键定义
class GlobalShortcut {
  /// 快捷键 ID
  final String id;

  /// 键名，如 "Ctrl+Shift+S"
  final String keyCombination;

  /// 描述
  final String description;

  const GlobalShortcut({
    required this.id,
    required this.keyCombination,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'keyCombination': keyCombination,
        'description': description,
      };
}

/// Toast 通知配置
class WinToastConfig {
  final String title;
  final String body;
  final String? iconPath;
  final String? attributionText;
  final Duration? expiration;
  final bool silent;
  final List<ToastAction> actions;

  const WinToastConfig({
    required this.title,
    required this.body,
    this.iconPath,
    this.attributionText,
    this.expiration,
    this.silent = false,
    this.actions = const [],
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        if (iconPath != null) 'iconPath': iconPath,
        if (attributionText != null) 'attributionText': attributionText,
        if (expiration != null) 'expirationMs': expiration!.inMilliseconds,
        'silent': silent,
        'actions': actions.map((e) => e.toJson()).toList(),
      };
}

/// Toast 通知按钮
class ToastAction {
  final String id;
  final String label;
  final String? arguments;

  const ToastAction({
    required this.id,
    required this.label,
    this.arguments,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (arguments != null) 'arguments': arguments,
      };
}

/// 文件关联配置
class FileAssociation {
  final String extension;
  final String description;
  final String iconPath;
  final String verb;

  const FileAssociation({
    required this.extension,
    this.description = '小酥配置文件',
    required this.iconPath,
    this.verb = 'open',
  });

  Map<String, dynamic> toJson() => {
        'extension': extension,
        'description': description,
        'iconPath': iconPath,
        'verb': verb,
      };
}

/// DPI 感知信息
class DpiInfo {
  final int dpiX;
  final int dpiY;
  final double scaleFactor;
  final DpiAwarenessLevel awareness;

  const DpiInfo({
    required this.dpiX,
    required this.dpiY,
    required this.scaleFactor,
    required this.awareness,
  });

  factory DpiInfo.fromMap(Map<String, dynamic> map) => DpiInfo(
        dpiX: map['dpiX'] as int? ?? 96,
        dpiY: map['dpiY'] as int? ?? 96,
        scaleFactor: (map['scaleFactor'] as num?)?.toDouble() ?? 1.0,
        awareness: DpiAwarenessLevel.values.firstWhere(
          (e) => e.name == map['awareness'],
          orElse: () => DpiAwarenessLevel.unaware,
        ),
      );
}

/// DPI 感知级别
enum DpiAwarenessLevel { unaware, systemAware, perMonitorAware, perMonitorAwareV2 }

/// 注册表操作结果
class RegistryResult {
  final bool success;
  final String? error;
  final dynamic value;

  const RegistryResult({
    required this.success,
    this.error,
    this.value,
  });

  factory RegistryResult.fromMap(Map<String, dynamic> map) => RegistryResult(
        success: map['success'] as bool? ?? false,
        error: map['error'] as String?,
        value: map['value'],
      );
}

// ============================================================================
// Windows 调度器 —— 核心实现
// ============================================================================

/// Windows 平台调度桥接
///
/// 通过 MethodChannel 与 Windows 原生层（C++ / Win32 API）通信，
/// 提供系统托盘、窗口管理、全局快捷键、注册表操作等 Windows 平台特有能力。
class WindowsScheduler {
  /// MethodChannel 实例
  static const MethodChannel _channel = MethodChannel('com.xiaosu.windows');

  /// 托盘菜单点击事件流控制器
  final StreamController<String> _trayMenuStream = StreamController<String>.broadcast();

  /// 全局快捷键触发流
  final StreamController<String> _shortcutStream = StreamController<String>.broadcast();

  /// Toast 通知动作流
  final StreamController<String> _toastActionStream = StreamController<String>.broadcast();

  /// 日志器
  final Logger _logger = appLogger;

  /// 平台检查缓存
  bool _platformChecked = false;
  bool _isWindows = false;

  /// 当前托盘配置
  TrayConfig? _currentTrayConfig;

  /// 已注册的全局快捷键
  final Set<String> _registeredShortcuts = {};

  /// 单例模式（可选）
  static WindowsScheduler? _instance;
  factory WindowsScheduler() => _instance ??= WindowsScheduler._internal();
  WindowsScheduler._internal() {
    _setupMethodCallHandler();
  }

  // ==========================================================================
  // 初始化与生命周期
  // ==========================================================================

  /// 初始化 Windows 调度器
  Future<void> initialize() async {
    if (!await isWindows) {
      _logger.d('🖥️ 非 Windows 平台，Windows 调度器不可用');
      return;
    }
    _logger.i('🖥️ Windows 调度器初始化中...');

    try {
      await _channel.invokeMethod('initialize');
      _logger.i('✅ Windows 调度器初始化完成');
    } on PlatformException catch (e) {
      _logger.e('❌ Windows 调度器初始化失败: ${e.message}');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _trayMenuStream.close();
    await _shortcutStream.close();
    await _toastActionStream.close();
    _registeredShortcuts.clear();
    _logger.i('🖥️ Windows 调度器已释放');
  }

  /// 检测当前平台是否为 Windows
  Future<bool> get isWindows async {
    if (!_platformChecked) {
      try {
        final result = await _channel.invokeMethod<bool>('isWindowsPlatform');
        _isWindows = result ?? Platform.isWindows;
      } catch (e) {
        _isWindows = Platform.isWindows;
        _logger.d('🖥️ Windows 平台检测: $_isWindows');
      }
      _platformChecked = true;
    }
    return _isWindows;
  }

  // ==========================================================================
  // 系统托盘
  // ==========================================================================

  /// 创建系统托盘
  Future<bool> createTray(TrayConfig config) async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('createTray', config.toJson());
      _currentTrayConfig = config;
      _logger.i('📌 系统托盘已创建: ${config.tooltip}');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 创建系统托盘失败: ${e.message}');
      return false;
    }
  }

  /// 更新托盘图标
  Future<bool> updateTrayIcon(String iconPath) async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('updateTrayIcon', {'iconPath': iconPath});
      _logger.d('🔄 托盘图标已更新');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 更新托盘图标失败: ${e.message}');
      return false;
    }
  }

  /// 显示气泡通知（传统托盘气泡）
  Future<bool> showBalloonNotification({
    required String title,
    required String message,
    BalloonIcon icon = BalloonIcon.info,
    Duration duration = const Duration(seconds: 5),
  }) async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('showBalloon', {
        'title': title,
        'message': message,
        'icon': icon.name,
        'durationMs': duration.inMilliseconds,
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 气泡通知失败: ${e.message}');
      return false;
    }
  }

  /// 销毁系统托盘
  Future<bool> destroyTray() async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('destroyTray');
      _currentTrayConfig = null;
      _logger.i('🗑️ 系统托盘已销毁');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 销毁系统托盘失败: ${e.message}');
      return false;
    }
  }

  /// 监听托盘菜单点击事件
  Stream<String> get onTrayMenuClick => _trayMenuStream.stream;

  // ==========================================================================
  // 窗口管理
  // ==========================================================================

  /// 应用窗口配置
  Future<bool> applyWindowConfig(WinWindowConfig config) async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('applyWindowConfig', config.toJson());
      _logger.i('🪟 窗口配置已应用');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 应用窗口配置失败: ${e.message}');
      return false;
    }
  }

  /// 最小化到系统托盘
  Future<bool> minimizeToTray() async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('minimizeToTray');
      _logger.d('📌 已最小化到托盘');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 最小化到托盘失败: ${e.message}');
      return false;
    }
  }

  /// 从托盘恢复窗口
  Future<bool> restoreFromTray() async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('restoreFromTray');
      _logger.d('📌 已从托盘恢复');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 恢复窗口失败: ${e.message}');
      return false;
    }
  }

  /// 设置窗口置顶
  Future<bool> setTopMost(TopMostMode mode) async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('setTopMost', {'mode': mode.name});
      _logger.d('📌 窗口置顶模式: ${mode.name}');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 设置置顶失败: ${e.message}');
      return false;
    }
  }

  /// 设置窗口透明度
  Future<bool> setWindowOpacity(double opacity) async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('setOpacity', {'opacity': opacity.clamp(0.0, 1.0)});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 设置透明度失败: ${e.message}');
      return false;
    }
  }

  /// 设置标题栏高度
  Future<bool> setTitleBarHeight(double height) async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('setTitleBarHeight', {'height': height});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 设置标题栏高度失败: ${e.message}');
      return false;
    }
  }

  // ==========================================================================
  // 全局快捷键
  // ==========================================================================

  /// 注册全局快捷键
  Future<bool> registerGlobalShortcut(GlobalShortcut shortcut) async {
    if (!await isWindows) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'registerShortcut',
        shortcut.toJson(),
      );
      if (result == true) {
        _registeredShortcuts.add(shortcut.id);
        _logger.i('⌨️ 全局快捷键已注册: ${shortcut.keyCombination} → ${shortcut.id}');
      }
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 注册快捷键失败: ${e.message}');
      return false;
    }
  }

  /// 批量注册快捷键
  Future<Map<String, bool>> registerShortcuts(List<GlobalShortcut> shortcuts) async {
    final results = <String, bool>{};
    for (final shortcut in shortcuts) {
      results[shortcut.id] = await registerGlobalShortcut(shortcut);
    }
    return results;
  }

  /// 取消注册快捷键
  Future<bool> unregisterShortcut(String shortcutId) async {
    if (!await isWindows) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'unregisterShortcut',
        {'id': shortcutId},
      );
      if (result == true) {
        _registeredShortcuts.remove(shortcutId);
      }
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 取消快捷键失败: ${e.message}');
      return false;
    }
  }

  /// 取消所有快捷键
  Future<bool> unregisterAllShortcuts() async {
    if (!await isWindows) return false;

    try {
      final result = await _channel.invokeMethod<bool>('unregisterAllShortcuts');
      _registeredShortcuts.clear();
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 取消所有快捷键失败: ${e.message}');
      return false;
    }
  }

  /// 监听全局快捷键触发
  Stream<String> get onGlobalShortcut => _shortcutStream.stream;

  // ==========================================================================
  // Toast 通知（Windows 10+ Action Center）
  // ==========================================================================

  /// 发送 Toast 通知
  Future<bool> sendToastNotification(WinToastConfig config) async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('sendToast', config.toJson());
      _logger.d('🔔 Toast 通知已发送: ${config.title}');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ Toast 通知失败: ${e.message}');
      return false;
    }
  }

  /// 清除所有 Toast 通知
  Future<bool> clearToastNotifications() async {
    if (!await isWindows) return false;

    try {
      await _channel.invokeMethod('clearToasts');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 清除通知失败: ${e.message}');
      return false;
    }
  }

  /// 监听 Toast 动作
  Stream<String> get onToastAction => _toastActionStream.stream;

  // ==========================================================================
  // 文件关联
  // ==========================================================================

  /// 注册文件关联
  Future<bool> registerFileAssociation(FileAssociation association) async {
    if (!await isWindows) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'registerFileAssociation',
        association.toJson(),
      );
      _logger.i('📎 文件关联已注册: ${association.extension}');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 注册文件关联失败: ${e.message}');
      return false;
    }
  }

  /// 检查文件关联是否已注册
  Future<bool> isFileAssociationRegistered(String extension) async {
    if (!await isWindows) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'isFileAssociationRegistered',
        {'extension': extension},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 检查文件关联失败: ${e.message}');
      return false;
    }
  }

  // ==========================================================================
  // 注册表操作
  // ==========================================================================

  /// 读取注册表值
  Future<RegistryResult> readRegistry({
    required String keyPath,
    required String valueName,
    RegistryHive hive = RegistryHive.currentUser,
  }) async {
    if (!await isWindows) {
      return const RegistryResult(success: false, error: '非 Windows 平台');
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'readRegistry',
        {
          'keyPath': keyPath,
          'valueName': valueName,
          'hive': hive.name,
        },
      );
      if (result == null) {
        return const RegistryResult(success: false, error: '键值不存在');
      }
      return RegistryResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      _logger.e('❌ 读取注册表失败: ${e.message}');
      return RegistryResult(success: false, error: e.message);
    }
  }

  /// 写入注册表值
  Future<RegistryResult> writeRegistry({
    required String keyPath,
    required String valueName,
    required dynamic value,
    RegistryHive hive = RegistryHive.currentUser,
    RegistryValueType type = RegistryValueType.string,
  }) async {
    if (!await isWindows) {
      return const RegistryResult(success: false, error: '非 Windows 平台');
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'writeRegistry',
        {
          'keyPath': keyPath,
          'valueName': valueName,
          'value': value,
          'hive': hive.name,
          'type': type.name,
        },
      );
      if (result == null) {
        return const RegistryResult(success: false, error: '写入失败');
      }
      return RegistryResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      _logger.e('❌ 写入注册表失败: ${e.message}');
      return RegistryResult(success: false, error: e.message);
    }
  }

  /// 删除注册表值
  Future<bool> deleteRegistryValue({
    required String keyPath,
    required String valueName,
    RegistryHive hive = RegistryHive.currentUser,
  }) async {
    if (!await isWindows) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'deleteRegistryValue',
        {
          'keyPath': keyPath,
          'valueName': valueName,
          'hive': hive.name,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 删除注册表值失败: ${e.message}');
      return false;
    }
  }

  // ==========================================================================
  // 开机自启
  // ==========================================================================

  /// 启用/禁用开机自启动
  Future<bool> setAutoStart({
    required bool enable,
    String appName = 'XiaoSu',
    List<String> arguments = const ['--minimized'],
  }) async {
    if (!await isWindows) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'setAutoStart',
        {
          'enable': enable,
          'appName': appName,
          'arguments': arguments,
        },
      );
      _logger.i('🚀 开机自启: ${enable ? "启用" : "禁用"}');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 设置自启动失败: ${e.message}');
      return false;
    }
  }

  /// 检查是否已设置开机自启
  Future<bool> isAutoStartEnabled({String appName = 'XiaoSu'}) async {
    if (!await isWindows) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'isAutoStartEnabled',
        {'appName': appName},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 检查自启动失败: ${e.message}');
      return false;
    }
  }

  // ==========================================================================
  // 系统主题
  // ==========================================================================

  /// 获取系统主题模式
  Future<ThemeMode> getSystemThemeMode() async {
    if (!await isWindows) return ThemeMode.light;

    try {
      final result = await _channel.invokeMethod<String>('getSystemTheme');
      return result == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } on PlatformException catch (e) {
      _logger.e('❌ 获取系统主题失败: ${e.message}');
      return ThemeMode.light;
    }
  }

  /// 监听系统主题变化
  Stream<ThemeMode> get onSystemThemeChanged {
    const eventChannel = EventChannel('com.xiaosu.windows/theme');
    return eventChannel.receiveBroadcastStream().map((event) {
      return event == 'dark' ? ThemeMode.dark : ThemeMode.light;
    });
  }

  // ==========================================================================
  // DPI 感知
  // ==========================================================================

  /// 获取当前 DPI 信息
  Future<DpiInfo> getDpiInfo() async {
    if (!await isWindows) {
      return const DpiInfo(dpiX: 96, dpiY: 96, scaleFactor: 1.0, awareness: DpiAwarenessLevel.systemAware);
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDpiInfo');
      if (result == null) {
        return const DpiInfo(dpiX: 96, dpiY: 96, scaleFactor: 1.0, awareness: DpiAwarenessLevel.systemAware);
      }
      return DpiInfo.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      _logger.e('❌ 获取 DPI 信息失败: ${e.message}');
      return const DpiInfo(dpiX: 96, dpiY: 96, scaleFactor: 1.0, awareness: DpiAwarenessLevel.systemAware);
    }
  }

  /// 设置 DPI 感知级别
  Future<bool> setDpiAwareness(DpiAwarenessLevel level) async {
    if (!await isWindows) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'setDpiAwareness',
        {'level': level.name},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 设置 DPI 感知失败: ${e.message}');
      return false;
    }
  }

  // ==========================================================================
  // MethodChannel 回调处理
  // ==========================================================================

  /// 设置原生回调处理器
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onTrayMenuClick':
          final id = call.arguments as String;
          _trayMenuStream.add(id);
          break;
        case 'onGlobalShortcut':
          final id = call.arguments as String;
          _shortcutStream.add(id);
          break;
        case 'onToastAction':
          final actionId = call.arguments as String;
          _toastActionStream.add(actionId);
          break;
        case 'onFileOpened':
          final path = call.arguments as String;
          _logger.i('📂 通过文件关联打开: $path');
          break;
      }
    });
  }
}

// ============================================================================
// 辅助枚举
// ============================================================================

/// 气球通知图标类型
enum BalloonIcon { none, info, warning, error }

/// 注册表根键
enum RegistryHive {
  classesRoot,
  currentUser,
  localMachine,
  users,
  currentConfig,
}

/// 注册表值类型
enum RegistryValueType {
  string,
  expandString,
  binary,
  dword,
  qword,
  multiString,
}

/// 主题模式（与 Flutter 的 ThemeMode 保持一致，这里独立定义避免冲突）
enum ThemeMode { light, dark, system }
