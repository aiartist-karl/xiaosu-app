// ============================================================================
// 小酥 (XiaoSu) - macOS 平台调度桥接层
//
// 职责：
// 封装 MethodChannel，与 macOS 原生层通信
// 提供菜单栏应用、Dock 控制、通知中心、Spotlight、Handoff、
// Universal Clipboard、Touch Bar、沙箱权限管理等 macOS 特有功能
//
// 原生侧（macOS/Swift）需要实现：
// - 注册 MethodChannel "com.xiaosu.macos"
// - 处理 menu_bar / dock / notification / handoff / spotlight 等方法
// - 使用 AppKit / Foundation / UserNotifications 框架实现底层系统交互
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'package:xiaosu_core/main.dart' show appLogger;

// ============================================================================
// 数据模型
// ============================================================================

/// 菜单栏应用配置
class MenuBarConfig {
  /// 是否启用菜单栏模式（隐藏 Dock 图标）
  final bool menuBarOnly;

  /// 菜单栏图标名称（SF Symbol 或自定义图标）
  final String iconName;

  /// 是否使用 SF Symbol
  final bool useSFSymbol;

  /// 菜单栏菜单项
  final List<MacMenuItem> menuItems;

  const MenuBarConfig({
    this.menuBarOnly = false,
    this.iconName = 'cpu',
    this.useSFSymbol = true,
    this.menuItems = const [],
  });

  Map<String, dynamic> toJson() => {
        'menuBarOnly': menuBarOnly,
        'iconName': iconName,
        'useSFSymbol': useSFSymbol,
        'menuItems': menuItems.map((e) => e.toJson()).toList(),
      };
}

/// macOS 菜单项
class MacMenuItem {
  final String id;
  final String title;
  final String? shortcut;
  final bool enabled;
  final bool checked;
  final bool isSeparator;
  final List<MacMenuItem> subItems;

  const MacMenuItem({
    required this.id,
    required this.title,
    this.shortcut,
    this.enabled = true,
    this.checked = false,
    this.isSeparator = false,
    this.subItems = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (shortcut != null) 'shortcut': shortcut,
        'enabled': enabled,
        'checked': checked,
        'isSeparator': isSeparator,
        'subItems': subItems.map((e) => e.toJson()).toList(),
      };
}

/// Dock 配置
class DockConfig {
  /// 是否显示 Dock 图标
  final bool showInDock;

  /// Dock 角标数字（null 表示不显示）
  final int? badgeCount;

  /// Dock 图标弹跳效果
  final DockBounceType bounceType;

  /// 是否在 Dock 中显示最近文档
  final bool showRecentDocuments;

  const DockConfig({
    this.showInDock = true,
    this.badgeCount,
    this.bounceType = DockBounceType.none,
    this.showRecentDocuments = false,
  });

  Map<String, dynamic> toJson() => {
        'showInDock': showInDock,
        if (badgeCount != null) 'badgeCount': badgeCount,
        'bounceType': bounceType.name,
        'showRecentDocuments': showRecentDocuments,
      };
}

/// Dock 弹跳类型
enum DockBounceType { none, informational, critical }

/// 通知中心配置
class MacNotificationConfig {
  final String identifier;
  final String title;
  final String subtitle;
  final String body;
  final String? soundName;
  final int? badgeCount;
  final String? categoryIdentifier;
  final Map<String, String> userInfo;
  final Duration? delay;
  final MacNotificationAction? action;

  const MacNotificationConfig({
    required this.identifier,
    required this.title,
    this.subtitle = '',
    required this.body,
    this.soundName,
    this.badgeCount,
    this.categoryIdentifier,
    this.userInfo = const {},
    this.delay,
    this.action,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'title': title,
        'subtitle': subtitle,
        'body': body,
        if (soundName != null) 'soundName': soundName,
        if (badgeCount != null) 'badgeCount': badgeCount,
        if (categoryIdentifier != null) 'categoryIdentifier': categoryIdentifier,
        'userInfo': userInfo,
        if (delay != null) 'delaySeconds': delay!.inSeconds,
        if (action != null) 'action': action!.toJson(),
      };
}

/// macOS 通知动作
class MacNotificationAction {
  final String identifier;
  final String title;
  final bool isDestructive;
  final bool requiresAuthentication;

  const MacNotificationAction({
    required this.identifier,
    required this.title,
    this.isDestructive = false,
    this.requiresAuthentication = false,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'title': title,
        'isDestructive': isDestructive,
        'requiresAuthentication': requiresAuthentication,
      };
}

/// Spotlight 搜索项
class SpotlightItem {
  final String uniqueIdentifier;
  final String title;
  final String? contentDescription;
  final List<String> keywords;
  final String? url;
  final DateTime? lastUsedDate;

  const SpotlightItem({
    required this.uniqueIdentifier,
    required this.title,
    this.contentDescription,
    this.keywords = const [],
    this.url,
    this.lastUsedDate,
  });

  Map<String, dynamic> toJson() => {
        'uniqueIdentifier': uniqueIdentifier,
        'title': title,
        if (contentDescription != null) 'contentDescription': contentDescription,
        'keywords': keywords,
        if (url != null) 'url': url,
        if (lastUsedDate != null) 'lastUsedDate': lastUsedDate!.toIso8601String(),
      };
}

/// Handoff 活动配置
class HandoffActivity {
  /// 活动类型标识（需在 Info.plist 中注册 NSUserActivityTypes）
  final String activityType;

  /// 活动标题
  final String title;

  /// 附加信息
  final Map<String, dynamic> userInfo;

  /// 是否在 Handoff 中可见
  final bool isEligibleForHandoff;

  /// 是否支持搜索
  final bool isEligibleForSearch;

  /// 是否支持公共索引
  final bool isEligibleForPublicIndexing;

  const HandoffActivity({
    required this.activityType,
    required this.title,
    this.userInfo = const {},
    this.isEligibleForHandoff = true,
    this.isEligibleForSearch = true,
    this.isEligibleForPublicIndexing = false,
  });

  Map<String, dynamic> toJson() => {
        'activityType': activityType,
        'title': title,
        'userInfo': userInfo,
        'isEligibleForHandoff': isEligibleForHandoff,
        'isEligibleForSearch': isEligibleForSearch,
        'isEligibleForPublicIndexing': isEligibleForPublicIndexing,
      };
}

/// Touch Bar 配置
class TouchBarConfig {
  /// 是否启用自定义 Touch Bar
  final bool enabled;

  /// Touch Bar 按钮项
  final List<TouchBarItem> items;

  const TouchBarConfig({
    this.enabled = true,
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

/// Touch Bar 按钮
class TouchBarItem {
  final String id;
  final String label;
  final String? iconName;
  final String? colorHex;
  final TouchBarType type;

  const TouchBarItem({
    required this.id,
    required this.label,
    this.iconName,
    this.colorHex,
    this.type = TouchBarType.button,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (iconName != null) 'iconName': iconName,
        if (colorHex != null) 'colorHex': colorHex,
        'type': type.name,
      };
}

/// Touch Bar 按钮类型
enum TouchBarType { button, label, slider, popover, scrubber }

/// 沙箱权限状态
enum MacPermissionStatus {
  notDetermined,
  granted,
  denied,
  restricted,
}

/// 沙箱权限类型
enum MacSandboxPermission {
  /// 文件访问 - 用户选择的文件
  userSelectedFile,

  /// 文件访问 - 下载文件夹
  downloadsFolder,

  /// 文件访问 - 桌面文件夹
  desktopFolder,

  /// 文件访问 - 文档文件夹
  documentsFolder,

  /// 网络访问 - 出站连接
  networkOutbound,

  /// 网络访问 - 入站连接
  networkInbound,

  /// 摄像头
  camera,

  /// 麦克风
  microphone,

  /// 辅助功能
  accessibility,

  /// 自动化
  automation,

  /// Apple 事件
  appleEvents,

  /// 日历
  calendar,

  /// 地址簿
  addressBook,
}

// ============================================================================
// macOS 调度器 —— 核心实现
// ============================================================================

/// macOS 平台调度桥接
///
/// 通过 MethodChannel 与 macOS 原生层（Swift / AppKit）通信，
/// 提供菜单栏应用、Dock 控制、通知中心、Spotlight、Handoff 等 macOS 特有能力。
class MacosScheduler {
  /// MethodChannel 实例
  static const MethodChannel _channel = MethodChannel('com.xiaosu.macos');

  /// 菜单栏菜单点击事件流
  final StreamController<String> _menuClickStream = StreamController<String>.broadcast();

  /// 通知中心动作流
  final StreamController<String> _notificationActionStream = StreamController<String>.broadcast();

  /// Handoff 活动恢复流
  final StreamController<HandoffActivity> _handoffStream = StreamController<HandoffActivity>.broadcast();

  /// Touch Bar 按钮点击流
  final StreamController<String> _touchBarStream = StreamController<String>.broadcast();

  /// Universal Clipboard 变更流
  final StreamController<String> _clipboardStream = StreamController<String>.broadcast();

  /// Spotlight 搜索触发流
  final StreamController<String> _spotlightStream = StreamController<String>.broadcast();

  /// 日志器
  final Logger _logger = appLogger;

  /// 平台检查缓存
  bool _platformChecked = false;
  bool _isMacos = false;

  /// 单例模式
  static MacosScheduler? _instance;
  factory MacosScheduler() => _instance ??= MacosScheduler._internal();
  MacosScheduler._internal() {
    _setupMethodCallHandler();
  }

  // ==========================================================================
  // 初始化与生命周期
  // ==========================================================================

  /// 初始化 macOS 调度器
  Future<void> initialize() async {
    if (!await isMacos) {
      _logger.d('🍎 非 macOS 平台，macOS 调度器不可用');
      return;
    }
    _logger.i('🍎 macOS 调度器初始化中...');

    try {
      await _channel.invokeMethod('initialize');
      _logger.i('✅ macOS 调度器初始化完成');
    } on PlatformException catch (e) {
      _logger.e('❌ macOS 调度器初始化失败: ${e.message}');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _menuClickStream.close();
    await _notificationActionStream.close();
    await _handoffStream.close();
    await _touchBarStream.close();
    await _clipboardStream.close();
    await _spotlightStream.close();
    _logger.i('🍎 macOS 调度器已释放');
  }

  /// 检测当前平台是否为 macOS
  Future<bool> get isMacos async {
    if (!_platformChecked) {
      try {
        final result = await _channel.invokeMethod<bool>('isMacosPlatform');
        _isMacos = result ?? Platform.isMacOS;
      } catch (e) {
        _isMacos = Platform.isMacOS;
        _logger.d('🍎 macOS 平台检测: $_isMacos');
      }
      _platformChecked = true;
    }
    return _isMacos;
  }

  // ==========================================================================
  // 菜单栏应用
  // ==========================================================================

  /// 配置菜单栏应用
  Future<bool> configureMenuBar(MenuBarConfig config) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('configureMenuBar', config.toJson());
      _logger.i('📌 菜单栏应用已配置: ${config.iconName}');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 配置菜单栏失败: ${e.message}');
      return false;
    }
  }

  /// 更新菜单栏图标
  Future<bool> updateMenuBarIcon(String iconName, {bool useSFSymbol = true}) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('updateMenuBarIcon', {
        'iconName': iconName,
        'useSFSymbol': useSFSymbol,
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 更新菜单栏图标失败: ${e.message}');
      return false;
    }
  }

  /// 显示/隐藏菜单栏弹出面板
  Future<bool> toggleMenuBarPopover({bool? show}) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('toggleMenuBarPopover', {
        if (show != null) 'show': show,
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 切换面板失败: ${e.message}');
      return false;
    }
  }

  /// 监听菜单栏菜单点击
  Stream<String> get onMenuClick => _menuClickStream.stream;

  // ==========================================================================
  // Dock 图标控制
  // ==========================================================================

  /// 配置 Dock 图标
  Future<bool> configureDock(DockConfig config) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('configureDock', config.toJson());
      _logger.i('📌 Dock 配置已应用');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 配置 Dock 失败: ${e.message}');
      return false;
    }
  }

  /// 设置 Dock 角标数字
  Future<bool> setDockBadge(int count) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('setDockBadge', {'count': count});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 设置角标失败: ${e.message}');
      return false;
    }
  }

  /// 清除 Dock 角标
  Future<bool> clearDockBadge() async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('setDockBadge', {'count': 0});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 清除角标失败: ${e.message}');
      return false;
    }
  }

  /// 弹跳 Dock 图标
  Future<bool> bounceDockIcon(DockBounceType type) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('bounceDock', {'type': type.name});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 弹跳 Dock 失败: ${e.message}');
      return false;
    }
  }

  /// 隐藏/显示 Dock 图标
  Future<bool> setDockVisibility(bool visible) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('setDockVisibility', {'visible': visible});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 设置 Dock 可见性失败: ${e.message}');
      return false;
    }
  }

  // ==========================================================================
  // 通知中心
  // ==========================================================================

  /// 请求通知权限
  Future<MacPermissionStatus> requestNotificationPermission() async {
    if (!await isMacos) return MacPermissionStatus.denied;

    try {
      final result = await _channel.invokeMethod<String>('requestNotificationPermission');
      return MacPermissionStatus.values.firstWhere(
        (e) => e.name == result,
        orElse: () => MacPermissionStatus.denied,
      );
    } on PlatformException catch (e) {
      _logger.e('❌ 请求通知权限失败: ${e.message}');
      return MacPermissionStatus.denied;
    }
  }

  /// 发送通知到通知中心
  Future<bool> sendNotification(MacNotificationConfig config) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('sendNotification', config.toJson());
      _logger.d('🔔 通知已发送: ${config.title}');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 发送通知失败: ${e.message}');
      return false;
    }
  }

  /// 移除指定通知
  Future<bool> removeNotification(String identifier) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('removeNotification', {'identifier': identifier});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 移除通知失败: ${e.message}');
      return false;
    }
  }

  /// 移除所有通知
  Future<bool> removeAllNotifications() async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('removeAllNotifications');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 移除所有通知失败: ${e.message}');
      return false;
    }
  }

  /// 注册通知分类
  Future<bool> registerNotificationCategories(List<MacNotificationAction> actions) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('registerNotificationCategories', {
        'actions': actions.map((a) => a.toJson()).toList(),
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 注册通知分类失败: ${e.message}');
      return false;
    }
  }

  /// 监听通知中心动作
  Stream<String> get onNotificationAction => _notificationActionStream.stream;

  // ==========================================================================
  // Spotlight 搜索集成
  // ==========================================================================

  /// 添加 Spotlight 搜索项（CSSearchableItem）
  Future<bool> addSpotlightItem(SpotlightItem item) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('addSpotlightItem', item.toJson());
      _logger.d('🔍 Spotlight 项已添加: ${item.title}');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 添加 Spotlight 项失败: ${e.message}');
      return false;
    }
  }

  /// 批量添加 Spotlight 项
  Future<bool> addSpotlightItems(List<SpotlightItem> items) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('addSpotlightItems', {
        'items': items.map((e) => e.toJson()).toList(),
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 批量添加 Spotlight 项失败: ${e.message}');
      return false;
    }
  }

  /// 删除 Spotlight 项
  Future<bool> removeSpotlightItem(String identifier) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('removeSpotlightItem', {'identifier': identifier});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 删除 Spotlight 项失败: ${e.message}');
      return false;
    }
  }

  /// 监听 Spotlight 搜索触发
  Stream<String> get onSpotlightSearch => _spotlightStream.stream;

  // ==========================================================================
  // Handoff（跨设备接力）
  // ==========================================================================

  /// 开始 Handoff 活动
  Future<bool> startHandoffActivity(HandoffActivity activity) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('startHandoff', activity.toJson());
      _logger.d('🔄 Handoff 活动已开始: ${activity.title}');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 开始 Handoff 失败: ${e.message}');
      return false;
    }
  }

  /// 更新 Handoff 活动信息
  Future<bool> updateHandoffActivity(String activityType, Map<String, dynamic> userInfo) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('updateHandoff', {
        'activityType': activityType,
        'userInfo': userInfo,
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 更新 Handoff 失败: ${e.message}');
      return false;
    }
  }

  /// 结束 Handoff 活动
  Future<bool> stopHandoffActivity(String activityType) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('stopHandoff', {'activityType': activityType});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 结束 Handoff 失败: ${e.message}');
      return false;
    }
  }

  /// 监听 Handoff 活动恢复（从其他设备接力）
  Stream<HandoffActivity> get onHandoffReceived => _handoffStream.stream;

  // ==========================================================================
  // Universal Clipboard（通用剪贴板）
  // ==========================================================================

  /// 设置剪贴板内容（自动同步到 iCloud 设备）
  Future<bool> setUniversalClipboard(String text, {String? typeIdentifier}) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('setClipboard', {
        'text': text,
        if (typeIdentifier != null) 'typeIdentifier': typeIdentifier,
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 设置剪贴板失败: ${e.message}');
      return false;
    }
  }

  /// 获取剪贴板内容
  Future<String?> getUniversalClipboard() async {
    if (!await isMacos) return null;

    try {
      final result = await _channel.invokeMethod<String>('getClipboard');
      return result;
    } on PlatformException catch (e) {
      _logger.e('❌ 获取剪贴板失败: ${e.message}');
      return null;
    }
  }

  /// 监听剪贴板变更（来自其他 Apple 设备）
  Stream<String> get onClipboardChanged => _clipboardStream.stream;

  // ==========================================================================
  // Touch Bar 支持
  // ==========================================================================

  /// 配置 Touch Bar
  Future<bool> configureTouchBar(TouchBarConfig config) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('configureTouchBar', config.toJson());
      _logger.d('⌨️ Touch Bar 已配置，共 ${config.items.length} 个按钮');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 配置 Touch Bar 失败: ${e.message}');
      return false;
    }
  }

  /// 更新 Touch Bar 按钮状态
  Future<bool> updateTouchBarItem(String itemId, {String? label, String? colorHex}) async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('updateTouchBarItem', {
        'id': itemId,
        if (label != null) 'label': label,
        if (colorHex != null) 'colorHex': colorHex,
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 更新 Touch Bar 按钮失败: ${e.message}');
      return false;
    }
  }

  /// 监听 Touch Bar 按钮点击
  Stream<String> get onTouchBarPress => _touchBarStream.stream;

  // ==========================================================================
  // 沙箱权限管理
  // ==========================================================================

  /// 请求沙箱权限
  Future<MacPermissionStatus> requestPermission(MacSandboxPermission permission) async {
    if (!await isMacos) return MacPermissionStatus.denied;

    try {
      final result = await _channel.invokeMethod<String>(
        'requestPermission',
        {'permission': permission.name},
      );
      return MacPermissionStatus.values.firstWhere(
        (e) => e.name == result,
        orElse: () => MacPermissionStatus.denied,
      );
    } on PlatformException catch (e) {
      _logger.e('❌ 请求权限失败: ${e.message}');
      return MacPermissionStatus.denied;
    }
  }

  /// 检查权限状态
  Future<MacPermissionStatus> checkPermission(MacSandboxPermission permission) async {
    if (!await isMacos) return MacPermissionStatus.denied;

    try {
      final result = await _channel.invokeMethod<String>(
        'checkPermission',
        {'permission': permission.name},
      );
      return MacPermissionStatus.values.firstWhere(
        (e) => e.name == result,
        orElse: () => MacPermissionStatus.notDetermined,
      );
    } on PlatformException catch (e) {
      _logger.e('❌ 检查权限失败: ${e.message}');
      return MacPermissionStatus.notDetermined;
    }
  }

  /// 批量检查权限
  Future<Map<MacSandboxPermission, MacPermissionStatus>> checkAllPermissions(
    List<MacSandboxPermission> permissions,
  ) async {
    final results = <MacSandboxPermission, MacPermissionStatus>{};
    for (final perm in permissions) {
      results[perm] = await checkPermission(perm);
    }
    return results;
  }

  /// 打开系统设置页面（引导用户授权）
  Future<bool> openSystemSettings() async {
    if (!await isMacos) return false;

    try {
      await _channel.invokeMethod('openSystemSettings');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 打开系统设置失败: ${e.message}');
      return false;
    }
  }

  // ==========================================================================
  // 系统主题
  // ==========================================================================

  /// 获取系统外观模式
  Future<String> getSystemAppearance() async {
    if (!await isMacos) return 'light';

    try {
      final result = await _channel.invokeMethod<String>('getSystemAppearance');
      return result ?? 'light';
    } on PlatformException catch (e) {
      _logger.e('❌ 获取系统外观失败: ${e.message}');
      return 'light';
    }
  }

  /// 监听系统外观变化
  Stream<String> get onSystemAppearanceChanged {
    const eventChannel = EventChannel('com.xiaosu.macos/appearance');
    return eventChannel.receiveBroadcastStream().map((event) => event as String? ?? 'light');
  }

  // ==========================================================================
  // MethodChannel 回调处理
  // ==========================================================================

  /// 设置原生回调处理器
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onMenuClick':
          final id = call.arguments as String;
          _menuClickStream.add(id);
          break;
        case 'onNotificationAction':
          final actionId = call.arguments as String;
          _notificationActionStream.add(actionId);
          break;
        case 'onHandoffReceived':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          _handoffStream.add(HandoffActivity(
            activityType: args['activityType'] as String,
            title: args['title'] as String? ?? '',
            userInfo: args['userInfo'] != null
                ? Map<String, dynamic>.from(args['userInfo'] as Map)
                : {},
          ));
          break;
        case 'onTouchBarPress':
          final itemId = call.arguments as String;
          _touchBarStream.add(itemId);
          break;
        case 'onClipboardChanged':
          final content = call.arguments as String;
          _clipboardStream.add(content);
          break;
        case 'onSpotlightSearch':
          final query = call.arguments as String;
          _spotlightStream.add(query);
          break;
      }
    });
  }
}
