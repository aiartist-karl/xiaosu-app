// ============================================================================
// 小酥 (XiaoSu) - Linux 平台调度桥接层
//
// 职责：
// 封装 MethodChannel，与 Linux 原生层通信
// 提供系统托盘（AppIndicator）、D-Bus 集成、桌面通知（libnotify）、
// 文件管理器集成、自启动（.desktop 文件）、Wayland/X11 适配等 Linux 特有功能
//
// 原生侧（Linux/Rust）需要实现：
// - 注册 MethodChannel "com.xiaosu.linux"
// - 处理 tray / dbus / notify / desktop_entry 等方法
// - 使用 GTK / GLib / D-Bus 库实现底层系统交互
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'package:xiaosu_core/main.dart' show appLogger;

// ============================================================================
// 数据模型
// ============================================================================

/// 系统托盘配置（基于 AppIndicator / StatusNotifier）
class LinuxTrayConfig {
  /// 应用 ID
  final String appId;

  /// 图标名称（主题图标或绝对路径）
  final String iconName;

  /// 图标类型
  final LinuxTrayIconType iconType;

  /// 悬停提示文本
  final String tooltip;

  /// 右键菜单项
  final List<LinuxTrayMenuItem> menuItems;

  const LinuxTrayConfig({
    required this.appId,
    required this.iconName,
    this.iconType = LinuxTrayIconType.themeIcon,
    this.tooltip = '小酥',
    this.menuItems = const [],
  });

  Map<String, dynamic> toJson() => {
        'appId': appId,
        'iconName': iconName,
        'iconType': iconType.name,
        'tooltip': tooltip,
        'menuItems': menuItems.map((e) => e.toJson()).toList(),
      };
}

/// 托盘图标类型
enum LinuxTrayIconType { themeIcon, filePath, iconName }

/// 托盘菜单项
class LinuxTrayMenuItem {
  final String id;
  final String label;
  final bool enabled;
  final bool checked;
  final bool isSeparator;
  final String? iconName;
  final List<LinuxTrayMenuItem> subItems;

  const LinuxTrayMenuItem({
    required this.id,
    required this.label,
    this.enabled = true,
    this.checked = false,
    this.isSeparator = false,
    this.iconName,
    this.subItems = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'enabled': enabled,
        'checked': checked,
        'isSeparator': isSeparator,
        if (iconName != null) 'iconName': iconName,
        'subItems': subItems.map((e) => e.toJson()).toList(),
      };
}

/// 桌面通知配置（基于 libnotify / freedesktop Notification）
class LinuxNotifyConfig {
  /// 应用名称
  final String appName;

  /// 替换 ID（相同 ID 的通知会被替换）
  final int? replacesId;

  /// 摘要（标题）
  final String summary;

  /// 正文
  final String body;

  /// 图标
  final String? iconName;

  /// 超时时间（毫秒），0 表示使用默认值
  final int timeoutMs;

  /// 动作按钮
  final List<LinuxNotifyAction> actions;

  /// 通知分类
  final String? category;

  /// 紧急级别
  final LinuxNotifyUrgency urgency;

  /// 附加提示
  final Map<String, String> hints;

  const LinuxNotifyConfig({
    this.appName = '小酥',
    this.replacesId,
    required this.summary,
    required this.body,
    this.iconName,
    this.timeoutMs = 5000,
    this.actions = const [],
    this.category,
    this.urgency = LinuxNotifyUrgency.normal,
    this.hints = const {},
  });

  Map<String, dynamic> toJson() => {
        'appName': appName,
        if (replacesId != null) 'replacesId': replacesId,
        'summary': summary,
        'body': body,
        if (iconName != null) 'iconName': iconName,
        'timeoutMs': timeoutMs,
        'actions': actions.map((e) => e.toJson()).toList(),
        if (category != null) 'category': category,
        'urgency': urgency.name,
        'hints': hints,
      };
}

/// 通知动作按钮
class LinuxNotifyAction {
  final String key;
  final String label;

  const LinuxNotifyAction({required this.key, required this.label});

  Map<String, dynamic> toJson() => {'key': key, 'label': label};
}

/// 通知紧急级别
enum LinuxNotifyUrgency { low, normal, critical }

/// Desktop Entry 配置（.desktop 文件）
class DesktopEntry {
  /// 应用 ID（文件名不含 .desktop 后缀）
  final String appId;

  /// 显示名称
  final String name;

  /// 注释/描述
  final String? comment;

  /// 可执行文件路径
  final String exec;

  /// 图标名称或路径
  final String icon;

  /// 分类
  final List<String> categories;

  /// 是否在终端中运行
  final bool terminal;

  /// MIME 类型关联
  final List<String> mimeTypes;

  /// 是否支持单实例（X-MultipleInstances = false）
  final bool singleInstance;

  /// 启动通知（StartupWMClass）
  final String? startupWMClass;

  /// 额外条目
  final Map<String, String> extraKeys;

  const DesktopEntry({
    required this.appId,
    required this.name,
    this.comment,
    required this.exec,
    required this.icon,
    this.categories = const ['Utility'],
    this.terminal = false,
    this.mimeTypes = const [],
    this.singleInstance = true,
    this.startupWMClass,
    this.extraKeys = const {},
  });

  Map<String, dynamic> toJson() => {
        'appId': appId,
        'name': name,
        if (comment != null) 'comment': comment,
        'exec': exec,
        'icon': icon,
        'categories': categories.join(';'),
        'terminal': terminal,
        'mimeTypes': mimeTypes.join(';'),
        'singleInstance': singleInstance,
        if (startupWMClass != null) 'startupWMClass': startupWMClass,
        'extraKeys': extraKeys,
      };
}

/// D-Bus 服务信息
class DbusServiceInfo {
  final String busName;
  final String objectPath;
  final String interfaceName;

  const DbusServiceInfo({
    required this.busName,
    required this.objectPath,
    required this.interfaceName,
  });

  Map<String, dynamic> toJson() => {
        'busName': busName,
        'objectPath': objectPath,
        'interfaceName': interfaceName,
      };
}

/// D-Bus 方法调用结果
class DbusCallResult {
  final bool success;
  final dynamic value;
  final String? error;

  const DbusCallResult({required this.success, this.value, this.error});

  factory DbusCallResult.fromMap(Map<String, dynamic> map) => DbusCallResult(
        success: map['success'] as bool? ?? false,
        value: map['value'],
        error: map['error'] as String?,
      );
}

/// 显示服务器类型
enum DisplayServerType { x11, wayland, unknown }

/// 显示服务器信息
class DisplayServerInfo {
  final DisplayServerType type;
  final String? displayName;
  final String? waylandDisplay;
  final String? xdgSessionType;
  final int screenWidth;
  final int screenHeight;
  final double scaleFactor;

  const DisplayServerInfo({
    required this.type,
    this.displayName,
    this.waylandDisplay,
    this.xdgSessionType,
    required this.screenWidth,
    required this.screenHeight,
    required this.scaleFactor,
  });

  factory DisplayServerInfo.fromMap(Map<String, dynamic> map) => DisplayServerInfo(
        type: DisplayServerType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => DisplayServerType.unknown,
        ),
        displayName: map['displayName'] as String?,
        waylandDisplay: map['waylandDisplay'] as String?,
        xdgSessionType: map['xdgSessionType'] as String?,
        screenWidth: map['screenWidth'] as int? ?? 1920,
        screenHeight: map['screenHeight'] as int? ?? 1080,
        scaleFactor: (map['scaleFactor'] as num?)?.toDouble() ?? 1.0,
      );
}

/// 文件管理器信息
class FileManagerInfo {
  final String name;
  final String exec;
  final bool isDefault;

  const FileManagerInfo({
    required this.name,
    required this.exec,
    this.isDefault = false,
  });

  factory FileManagerInfo.fromMap(Map<String, dynamic> map) => FileManagerInfo(
        name: map['name'] as String? ?? 'Unknown',
        exec: map['exec'] as String? ?? '',
        isDefault: map['isDefault'] as bool? ?? false,
      );
}

// ============================================================================
// Linux 调度器 —— 核心实现
// ============================================================================

/// Linux 平台调度桥接
///
/// 通过 MethodChannel 与 Linux 原生层（Rust / GTK）通信，
/// 提供系统托盘、D-Bus、桌面通知、文件管理器集成、自启动、Wayland/X11 适配等能力。
class LinuxScheduler {
  /// MethodChannel 实例
  static const MethodChannel _channel = MethodChannel('com.xiaosu.linux');

  /// 托盘菜单点击事件流
  final StreamController<String> _trayMenuStream = StreamController<String>.broadcast();

  /// 桌面通知动作流
  final StreamController<String> _notifyActionStream = StreamController<String>.broadcast();

  /// D-Bus 信号流
  final StreamController<Map<String, dynamic>> _dbusSignalStream = StreamController<Map<String, dynamic>>.broadcast();

  /// 日志器
  final Logger _logger = appLogger;

  /// 平台检查缓存
  bool _platformChecked = false;
  bool _isLinux = false;

  /// 当前显示服务器信息缓存
  DisplayServerInfo? _displayServerInfo;

  /// 单例模式
  static LinuxScheduler? _instance;
  factory LinuxScheduler() => _instance ??= LinuxScheduler._internal();
  LinuxScheduler._internal() {
    _setupMethodCallHandler();
  }

  // ==========================================================================
  // 初始化与生命周期
  // ==========================================================================

  /// 初始化 Linux 调度器
  Future<void> initialize() async {
    if (!await isLinux) {
      _logger.d('🐧 非 Linux 平台，Linux 调度器不可用');
      return;
    }
    _logger.i('🐧 Linux 调度器初始化中...');

    try {
      await _channel.invokeMethod('initialize');
      // 缓存显示服务器信息
      _displayServerInfo = await getDisplayServerInfo();
      _logger.i('✅ Linux 调度器初始化完成 (显示: ${_displayServerInfo?.type.name})');
    } on PlatformException catch (e) {
      _logger.e('❌ Linux 调度器初始化失败: ${e.message}');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _trayMenuStream.close();
    await _notifyActionStream.close();
    await _dbusSignalStream.close();
    _logger.i('🐧 Linux 调度器已释放');
  }

  /// 检测当前平台是否为 Linux
  Future<bool> get isLinux async {
    if (!_platformChecked) {
      try {
        final result = await _channel.invokeMethod<bool>('isLinuxPlatform');
        _isLinux = result ?? Platform.isLinux;
      } catch (e) {
        _isLinux = Platform.isLinux;
        _logger.d('🐧 Linux 平台检测: $_isLinux');
      }
      _platformChecked = true;
    }
    return _isLinux;
  }

  // ==========================================================================
  // 系统托盘（AppIndicator / StatusNotifier）
  // ==========================================================================

  /// 创建系统托盘
  Future<bool> createTray(LinuxTrayConfig config) async {
    if (!await isLinux) return false;

    try {
      await _channel.invokeMethod('createTray', config.toJson());
      _logger.i('📌 Linux 系统托盘已创建: ${config.tooltip}');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 创建系统托盘失败: ${e.message}');
      return false;
    }
  }

  /// 更新托盘图标
  Future<bool> updateTrayIcon(String iconName, {LinuxTrayIconType type = LinuxTrayIconType.themeIcon}) async {
    if (!await isLinux) return false;

    try {
      await _channel.invokeMethod('updateTrayIcon', {
        'iconName': iconName,
        'iconType': type.name,
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 更新托盘图标失败: ${e.message}');
      return false;
    }
  }

  /// 更新托盘提示
  Future<bool> updateTrayTooltip(String tooltip) async {
    if (!await isLinux) return false;

    try {
      await _channel.invokeMethod('updateTrayTooltip', {'tooltip': tooltip});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 更新托盘提示失败: ${e.message}');
      return false;
    }
  }

  /// 销毁系统托盘
  Future<bool> destroyTray() async {
    if (!await isLinux) return false;

    try {
      await _channel.invokeMethod('destroyTray');
      _logger.i('🗑️ Linux 系统托盘已销毁');
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 销毁系统托盘失败: ${e.message}');
      return false;
    }
  }

  /// 监听托盘菜单点击
  Stream<String> get onTrayMenuClick => _trayMenuStream.stream;

  // ==========================================================================
  // D-Bus 集成
  // ==========================================================================

  /// 调用 D-Bus 方法
  Future<DbusCallResult> callDbusMethod({
    required String busName,
    required String objectPath,
    required String interfaceName,
    required String methodName,
    List<dynamic> arguments = const [],
    String? destination,
  }) async {
    if (!await isLinux) {
      return const DbusCallResult(success: false, error: '非 Linux 平台');
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'callDbusMethod',
        {
          'busName': busName,
          'objectPath': objectPath,
          'interfaceName': interfaceName,
          'methodName': methodName,
          'arguments': arguments,
          if (destination != null) 'destination': destination,
        },
      );
      if (result == null) {
        return const DbusCallResult(success: false, error: '无响应');
      }
      return DbusCallResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      _logger.e('❌ D-Bus 调用失败: ${e.message}');
      return DbusCallResult(success: false, error: e.message);
    }
  }

  /// 监听 D-Bus 信号
  Future<bool> subscribeDbusSignal({
    required String busName,
    required String objectPath,
    required String interfaceName,
    String? member,
  }) async {
    if (!await isLinux) return false;

    try {
      await _channel.invokeMethod('subscribeDbusSignal', {
        'busName': busName,
        'objectPath': objectPath,
        'interfaceName': interfaceName,
        if (member != null) 'member': member,
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 订阅 D-Bus 信号失败: ${e.message}');
      return false;
    }
  }

  /// 监听 D-Bus 信号流
  Stream<Map<String, dynamic>> get onDbusSignal => _dbusSignalStream.stream;

  // ==========================================================================
  // 桌面通知（libnotify / freedesktop.org Notifications）
  // ==========================================================================

  /// 发送桌面通知
  Future<int?> sendNotification(LinuxNotifyConfig config) async {
    if (!await isLinux) return null;

    try {
      final result = await _channel.invokeMethod<int>('sendNotification', config.toJson());
      _logger.d('🔔 桌面通知已发送: ${config.summary}');
      return result;
    } on PlatformException catch (e) {
      _logger.e('❌ 发送通知失败: ${e.message}');
      return null;
    }
  }

  /// 关闭通知
  Future<bool> closeNotification(int notifyId) async {
    if (!await isLinux) return false;

    try {
      await _channel.invokeMethod('closeNotification', {'notifyId': notifyId});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 关闭通知失败: ${e.message}');
      return false;
    }
  }

  /// 检查通知能力
  Future<Map<String, dynamic>> getNotificationCapabilities() async {
    if (!await isLinux) return {};

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getNotifyCapabilities');
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _logger.e('❌ 获取通知能力失败: ${e.message}');
      return {};
    }
  }

  /// 监听通知动作
  Stream<String> get onNotifyAction => _notifyActionStream.stream;

  // ==========================================================================
  // 文件管理器集成
  // ==========================================================================

  /// 在文件管理器中显示文件（选中文件）
  Future<bool> showFileInFileManager(String filePath) async {
    if (!await isLinux) return false;

    try {
      await _channel.invokeMethod('showFileInFileManager', {'filePath': filePath});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 打开文件管理器失败: ${e.message}');
      return false;
    }
  }

  /// 获取默认文件管理器信息
  Future<FileManagerInfo?> getDefaultFileManager() async {
    if (!await isLinux) return null;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDefaultFileManager');
      if (result == null) return null;
      return FileManagerInfo.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      _logger.e('❌ 获取文件管理器失败: ${e.message}');
      return null;
    }
  }

  /// 打开目录
  Future<bool> openDirectory(String directoryPath) async {
    if (!await isLinux) return false;

    try {
      await _channel.invokeMethod('openDirectory', {'path': directoryPath});
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 打开目录失败: ${e.message}');
      return false;
    }
  }

  // ==========================================================================
  // 自启动（.desktop 文件）
  // ==========================================================================

  /// 安装 Desktop Entry 到自启动目录
  Future<bool> installAutoStart(DesktopEntry entry) async {
    if (!await isLinux) return false;

    try {
      final result = await _channel.invokeMethod<bool>('installAutoStart', entry.toJson());
      _logger.i('🚀 自启动已${result == true ? "安装" : "未安装"}: ${entry.appId}');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 安装自启动失败: ${e.message}');
      return false;
    }
  }

  /// 移除自启动配置
  Future<bool> removeAutoStart(String appId) async {
    if (!await isLinux) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'removeAutoStart',
        {'appId': appId},
      );
      _logger.i('🗑️ 自启动已移除: $appId');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 移除自启动失败: ${e.message}');
      return false;
    }
  }

  /// 检查是否已设置自启动
  Future<bool> isAutoStartEnabled(String appId) async {
    if (!await isLinux) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'isAutoStartEnabled',
        {'appId': appId},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 检查自启动失败: ${e.message}');
      return false;
    }
  }

  /// 安装完整的 .desktop 文件到应用目录
  Future<bool> installDesktopEntry(DesktopEntry entry) async {
    if (!await isLinux) return false;

    try {
      final result = await _channel.invokeMethod<bool>('installDesktopEntry', entry.toJson());
      _logger.i('📝 Desktop Entry 已安装: ${entry.appId}.desktop');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 安装 Desktop Entry 失败: ${e.message}');
      return false;
    }
  }

  // ==========================================================================
  // Wayland / X11 适配
  // ==========================================================================

  /// 获取显示服务器信息
  Future<DisplayServerInfo> getDisplayServerInfo() async {
    if (!await isLinux) {
      return const DisplayServerInfo(
        type: DisplayServerType.unknown,
        screenWidth: 1920,
        screenHeight: 1080,
        scaleFactor: 1.0,
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDisplayServerInfo');
      if (result == null) {
        return const DisplayServerInfo(
          type: DisplayServerType.unknown,
          screenWidth: 1920,
          screenHeight: 1080,
          scaleFactor: 1.0,
        );
      }
      return DisplayServerInfo.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      _logger.e('❌ 获取显示服务器信息失败: ${e.message}');
      return const DisplayServerInfo(
        type: DisplayServerType.unknown,
        screenWidth: 1920,
        screenHeight: 1080,
        scaleFactor: 1.0,
      );
    }
  }

  /// 当前是否为 Wayland
  Future<bool> get isWayland async {
    final info = _displayServerInfo ?? await getDisplayServerInfo();
    return info.type == DisplayServerType.wayland;
  }

  /// 当前是否为 X11
  Future<bool> get isX11 async {
    final info = _displayServerInfo ?? await getDisplayServerInfo();
    return info.type == DisplayServerType.x11;
  }

  /// 设置 Wayland 特定窗口属性
  Future<bool> setWaylandWindowProperty(String key, dynamic value) async {
    if (!await isLinux) return false;
    if (!await isWayland) {
      _logger.w('⚠️ 非 Wayland 环境，无法设置 Wayland 属性');
      return false;
    }

    try {
      await _channel.invokeMethod('setWaylandWindowProp', {
        'key': key,
        'value': value,
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 设置 Wayland 属性失败: ${e.message}');
      return false;
    }
  }

  /// 设置 X11 特定窗口属性（如 _NET_WM_STATE）
  Future<bool> setX11WindowProperty(String property, dynamic value) async {
    if (!await isLinux) return false;
    if (!await isX11) {
      _logger.w('⚠️ 非 X11 环境，无法设置 X11 属性');
      return false;
    }

    try {
      await _channel.invokeMethod('setX11WindowProp', {
        'property': property,
        'value': value,
      });
      return true;
    } on PlatformException catch (e) {
      _logger.e('❌ 设置 X11 属性失败: ${e.message}');
      return false;
    }
  }

  // ==========================================================================
  // 系统主题
  // ==========================================================================

  /// 获取系统主题
  Future<String> getSystemTheme() async {
    if (!await isLinux) return 'light';

    try {
      // 优先从 GTK 设置获取
      final result = await _channel.invokeMethod<String>('getSystemTheme');
      return result ?? 'light';
    } on PlatformException catch (e) {
      _logger.e('❌ 获取系统主题失败: ${e.message}');
      return 'light';
    }
  }

  /// 监听系统主题变化
  Stream<String> get onSystemThemeChanged {
    const eventChannel = EventChannel('com.xiaosu.linux/theme');
    return eventChannel.receiveBroadcastStream().map((event) => event as String? ?? 'light');
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
        case 'onNotifyAction':
          final actionId = call.arguments as String;
          _notifyActionStream.add(actionId);
          break;
        case 'onDbusSignal':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          _dbusSignalStream.add(args);
          break;
        case 'onFileOpened':
          final path = call.arguments as String;
          _logger.i('📂 通过文件管理器打开: $path');
          break;
        case 'onThemeChanged':
          _logger.d('🎨 系统主题已切换: ${call.arguments}');
          break;
      }
    });
  }
}
