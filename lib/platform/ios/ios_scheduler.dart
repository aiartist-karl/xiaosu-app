/// iOS Scheduler - Platform bridge for iOS-specific features
///
/// Handles push notifications (APNs), background tasks (BGTaskScheduler),
/// biometric authentication, camera/photos, file sandbox, Siri shortcuts,
/// Widget Kit, Apple Pencil, and haptic feedback.
///
/// Author: XiaoSu Core Team
/// Date: 2026-06-29

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// ============================================================================
// Enums
// ============================================================================

/// Biometric authentication type
enum BiometricType {
  faceId,
  touchId,
  none,
  notAvailable,
}

/// Authentication result
enum AuthResult {
  success,
  failed,
  cancelled,
  notAvailable,
  notEnrolled,
  lockedOut,
  systemCancel,
}

/// iOS permission status
enum PermissionStatus {
  notDetermined,
  authorized,
  denied,
  restricted,
  limited,
}

/// Permission type
enum PermissionType {
  camera,
  photoLibrary,
  notification,
  location,
  microphone,
  contacts,
  calendar,
  reminders,
  motion,
  siri,
}

/// Background task result
enum BackgroundTaskResult {
  newData,
  noNewData,
  failed,
}

/// Haptic feedback style
enum HapticStyle {
  light,
  medium,
  heavy,
  soft,
  rigid,
  selection,
  success,
  warning,
  error,
}

/// Widget family (size)
enum WidgetFamily {
  systemSmall,
  systemMedium,
  systemLarge,
  systemExtraLarge,
  accessoryCircular,
  accessoryRectangular,
  accessoryInline,
}

/// Siri intent type
enum SiriIntentType {
  startChat,
  sendToContact,
  searchHistory,
  createReminder,
  toggleSetting,
}

/// Apple Pencil interaction type
enum PencilInteraction {
  tap,
  doubleTap,
  squeeze,
  hover,
}

/// APNs environment
enum APNsEnvironment {
  development,
  production,
}

/// Notification priority
enum NotificationPriority {
  immediate,
  active,
  passive,
  timeSensitive,
  critical,
}

/// iOS device capability
enum DeviceCapability {
  faceId,
  touchId,
  applePencil,
  lidar,
  ultraWideband,
  nfc,
}

// ============================================================================
// Data Models
// ============================================================================

/// iOS device info
class IosDeviceInfo {
  final String model;
  final String systemName;
  final String systemVersion;
  final String identifier;
  final String name;
  final bool isIPad;
  final bool isIPhone;
  final bool isSimulator;
  final double screenScale;
  final List<DeviceCapability> capabilities;

  const IosDeviceInfo({
    required this.model,
    required this.systemName,
    required this.systemVersion,
    required this.identifier,
    required this.name,
    this.isIPad = false,
    this.isIPhone = false,
    this.isSimulator = false,
    this.screenScale = 2.0,
    this.capabilities = const [],
  });

  bool supportsFaceId => capabilities.contains(DeviceCapability.faceId);
  bool supportsTouchId => capabilities.contains(DeviceCapability.touchId);
  bool supportsApplePencil => capabilities.contains(DeviceCapability.applePencil);
  bool hasBiometrics => supportsFaceId || supportsTouchId;

  Map<String, dynamic> toJson() => {
        'model': model,
        'system_name': systemName,
        'system_version': systemVersion,
        'identifier': identifier,
        'name': name,
        'is_ipad': isIPad,
        'is_iphone': isIPhone,
        'is_simulator': isSimulator,
        'screen_scale': screenScale,
        'capabilities': capabilities.map((c) => c.name).toList(),
      };

  factory IosDeviceInfo.fromJson(Map<String, dynamic> json) => IosDeviceInfo(
        model: json['model'] as String? ?? 'Unknown',
        systemName: json['system_name'] as String? ?? 'iOS',
        systemVersion: json['system_version'] as String? ?? '17.0',
        identifier: json['identifier'] as String? ?? '',
        name: json['name'] as String? ?? '',
        isIPad: json['is_ipad'] as bool? ?? false,
        isIPhone: json['is_iphone'] as bool? ?? false,
        isSimulator: json['is_simulator'] as bool? ?? false,
        screenScale: (json['screen_scale'] as num?)?.toDouble() ?? 2.0,
        capabilities: (json['capabilities'] as List<dynamic>?)
                ?.map((c) => DeviceCapability.values
                    .firstWhere((e) => e.name == c, orElse: () => DeviceCapability.nfc))
                .toList() ??
            [],
      );

  @override
  String toString() =>
      'IosDeviceInfo($model, $systemName $systemVersion, iPad=$isIPad)';
}

/// Push notification payload
class IosNotification {
  final String id;
  final String title;
  final String body;
  final String? subtitle;
  final String? sound;
  final String? categoryIdentifier;
  final Map<String, dynamic> userInfo;
  final NotificationPriority priority;
  final DateTime? fireDate;
  final bool isRepeating;
  final Duration? repeatInterval;
  final String? threadIdentifier;
  final String? summaryArgument;
  final int? badgeCount;
  final List<IosNotificationAction> actions;
  final String? attachmentUrl;

  const IosNotification({
    required this.id,
    required this.title,
    required this.body,
    this.subtitle,
    this.sound = 'default',
    this.categoryIdentifier,
    this.userInfo = const {},
    this.priority = NotificationPriority.active,
    this.fireDate,
    this.isRepeating = false,
    this.repeatInterval,
    this.threadIdentifier,
    this.summaryArgument,
    this.badgeCount,
    this.actions = const [],
    this.attachmentUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'subtitle': subtitle,
        'sound': sound,
        'category_identifier': categoryIdentifier,
        'user_info': userInfo,
        'priority': priority.name,
        'fire_date': fireDate?.toIso8601String(),
        'is_repeating': isRepeating,
        'repeat_interval_ms': repeatInterval?.inMilliseconds,
        'thread_identifier': threadIdentifier,
        'summary_argument': summaryArgument,
        'badge_count': badgeCount,
        'actions': actions.map((a) => a.toJson()).toList(),
        'attachment_url': attachmentUrl,
      };

  factory IosNotification.fromJson(Map<String, dynamic> json) =>
      IosNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        subtitle: json['subtitle'] as String?,
        sound: json['sound'] as String? ?? 'default',
        categoryIdentifier: json['category_identifier'] as String?,
        userInfo: (json['user_info'] as Map<String, dynamic>?) ?? {},
        priority: NotificationPriority.values.firstWhere(
            (e) => e.name == json['priority'],
            orElse: () => NotificationPriority.active),
        fireDate: json['fire_date'] != null
            ? DateTime.parse(json['fire_date'] as String)
            : null,
        isRepeating: json['is_repeating'] as bool? ?? false,
        repeatInterval: json['repeat_interval_ms'] != null
            ? Duration(milliseconds: json['repeat_interval_ms'] as int)
            : null,
        threadIdentifier: json['thread_identifier'] as String?,
        summaryArgument: json['summary_argument'] as String?,
        badgeCount: json['badge_count'] as int?,
        actions: (json['actions'] as List<dynamic>?)
                ?.map((a) => IosNotificationAction.fromJson(
                    a as Map<String, dynamic>))
                .toList() ??
            [],
        attachmentUrl: json['attachment_url'] as String?,
      );
}

/// Notification action button
class IosNotificationAction {
  final String id;
  final String title;
  final bool isDestructive;
  final bool requiresAuthentication;
  final bool opensApp;
  final String? textInputButtonTitle;
  final String? textInputPlaceholder;

  const IosNotificationAction({
    required this.id,
    required this.title,
    this.isDestructive = false,
    this.requiresAuthentication = false,
    this.opensApp = true,
    this.textInputButtonTitle,
    this.textInputPlaceholder,
  });

  bool get isTextInput => textInputButtonTitle != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'is_destructive': isDestructive,
        'requires_authentication': requiresAuthentication,
        'opens_app': opensApp,
        'text_input_button_title': textInputButtonTitle,
        'text_input_placeholder': textInputPlaceholder,
      };

  factory IosNotificationAction.fromJson(Map<String, dynamic> json) =>
      IosNotificationAction(
        id: json['id'] as String,
        title: json['title'] as String,
        isDestructive: json['is_destructive'] as bool? ?? false,
        requiresAuthentication: json['requires_authentication'] as bool? ?? false,
        opensApp: json['opens_app'] as bool? ?? true,
        textInputButtonTitle: json['text_input_button_title'] as String?,
        textInputPlaceholder: json['text_input_placeholder'] as String?,
      );
}

/// Background task configuration
class BackgroundTaskConfig {
  final String taskId;
  final bool requiresNetwork;
  final bool requiresCharging;
  final Duration earliestRunDate;
  final Duration? timeoutInterval;
  final bool isRecurring;

  const BackgroundTaskConfig({
    required this.taskId,
    this.requiresNetwork = false,
    this.requiresCharging = false,
    this.earliestRunDate = Duration.zero,
    this.timeoutInterval,
    this.isRecurring = false,
  });

  Map<String, dynamic> toJson() => {
        'task_id': taskId,
        'requires_network': requiresNetwork,
        'requires_charging': requiresCharging,
        'earliest_run_date_seconds': earliestRunDate.inSeconds,
        'timeout_interval_seconds': timeoutInterval?.inSeconds,
        'is_recurring': isRecurring,
      };
}

/// Widget configuration
class WidgetConfig {
  final String kind;
  final String displayName;
  final String description;
  final List<WidgetFamily> supportedFamilies;
  final Map<String, dynamic> data;
  final DateTime? lastUpdated;
  final Duration? refreshInterval;

  const WidgetConfig({
    required this.kind,
    required this.displayName,
    required this.description,
    this.supportedFamilies = const [WidgetFamily.systemSmall, WidgetFamily.systemMedium],
    this.data = const {},
    this.lastUpdated,
    this.refreshInterval,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'display_name': displayName,
        'description': description,
        'supported_families': supportedFamilies.map((f) => f.name).toList(),
        'data': data,
        'last_updated': lastUpdated?.toIso8601String(),
        'refresh_interval_seconds': refreshInterval?.inSeconds,
      };
}

/// Siri shortcut configuration
class SiriShortcut {
  final String id;
  final String title;
  final String subtitle;
  final SiriIntentType intentType;
  final Map<String, dynamic> parameters;
  final bool isEligibleForSearch;
  final bool isEligibleForPrediction;
  final String? suggestedInvocationPhrase;

  const SiriShortcut({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.intentType,
    this.parameters = const {},
    this.isEligibleForSearch = true,
    this.isEligibleForPrediction = true,
    this.suggestedInvocationPhrase,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'intent_type': intentType.name,
        'parameters': parameters,
        'is_eligible_for_search': isEligibleForSearch,
        'is_eligible_for_prediction': isEligibleForPrediction,
        'suggested_invocation_phrase': suggestedInvocationPhrase,
      };
}

// ============================================================================
// Permission Manager
// ============================================================================

class IosPermissionManager {
  static const MethodChannel _channel = MethodChannel('com.xiaosu/ios_permissions');
  final Map<PermissionType, PermissionStatus> _statusCache = {};
  final StreamController<Map<PermissionType, PermissionStatus>> _statusStream =
      StreamController<Map<PermissionType, PermissionStatus>>.broadcast();

  Stream<Map<PermissionType, PermissionStatus>> get statusStream =>
      _statusStream.stream;

  PermissionStatus getStatus(PermissionType type) =>
      _statusCache[type] ?? PermissionStatus.notDetermined;

  Future<PermissionStatus> requestPermission(PermissionType type) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'requestPermission',
        {'type': type.name},
      );
      final status = PermissionStatus.values.firstWhere(
        (e) => e.name == result,
        orElse: () => PermissionStatus.denied,
      );
      _statusCache[type] = status;
      _statusStream.add(Map.from(_statusCache));
      return status;
    } catch (e) {
      _statusCache[type] = PermissionStatus.denied;
      return PermissionStatus.denied;
    }
  }

  Future<Map<PermissionType, PermissionStatus>> checkAllPermissions() async {
    final results = <PermissionType, PermissionStatus>{};
    for (final type in PermissionType.values) {
      results[type] = await checkPermission(type);
    }
    _statusCache.addAll(results);
    return results;
  }

  Future<PermissionStatus> checkPermission(PermissionType type) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'checkPermission',
        {'type': type.name},
      );
      return PermissionStatus.values.firstWhere(
        (e) => e.name == result,
        orElse: () => PermissionStatus.notDetermined,
      );
    } catch (_) {
      return PermissionStatus.notDetermined;
    }
  }

  bool isGranted(PermissionType type) =>
      _statusCache[type] == PermissionStatus.authorized;

  Future<void> openSettings() async {
    await _channel.invokeMethod('openAppSettings');
  }

  Future<void> dispose() async {
    await _statusStream.close();
  }
}

// ============================================================================
// MethodChannel Bridge (Mock for compilation)
// ============================================================================

/// Mock MethodChannel for compile-time compatibility
/// In production, this would use flutter/services MethodChannel
class MethodChannel {
  final String name;
  MethodChannel(this.name);

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    // In production: routes to native iOS via Flutter MethodChannel
    return null;
  }

  void setMethodCallHandler(
      Future<dynamic> Function(MethodCall call)? handler) {
    // In production: registers handler for calls from native
  }
}

class MethodCall {
  final String method;
  final dynamic arguments;
  const MethodCall(this.method, this.arguments);
}

// ============================================================================
// Main IosScheduler
// ============================================================================

class IosScheduler {
  static const MethodChannel _channel = MethodChannel('com.xiaosu/ios_scheduler');
  final IosPermissionManager permissionManager = IosPermissionManager();

  IosDeviceInfo? _deviceInfo;
  bool _initialized = false;
  APNsEnvironment _apnsEnvironment = APNsEnvironment.development;

  // Stream controllers
  final StreamController<IosNotification> _notificationController =
      StreamController<IosNotification>.broadcast();
  final StreamController<BackgroundTaskResult> _bgTaskController =
      StreamController<BackgroundTaskResult>.broadcast();
  final StreamController<String> _siriController =
      StreamController<String>.broadcast();
  final StreamController<PencilInteraction> _pencilController =
      StreamController<PencilInteraction>.broadcast();
  final StreamController<WidgetConfig> _widgetController =
      StreamController<WidgetConfig>.broadcast();

  // Streams
  Stream<IosNotification> get notificationStream => _notificationController.stream;
  Stream<BackgroundTaskResult> get bgTaskStream => _bgTaskController.stream;
  Stream<String> get siriStream => _siriController.stream;
  Stream<PencilInteraction> get pencilStream => _pencilController.stream;
  Stream<WidgetConfig> get widgetStream => _widgetController.stream;

  IosDeviceInfo? get deviceInfo => _deviceInfo;
  bool get isInitialized => _initialized;

  // --------------------------------------------------------------------------
  // Initialization
  // --------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;

    _deviceInfo = await _fetchDeviceInfo();
    _setupMethodCallHandler();
    _registerBackgroundTasks();
    _registerNotificationCategories();

    _initialized = true;
  }

  Future<IosDeviceInfo> _fetchDeviceInfo() async {
    // In production, fetches from native via MethodChannel
    return const IosDeviceInfo(
      model: 'iPhone 15 Pro',
      systemName: 'iOS',
      systemVersion: '17.5',
      identifier: 'com.xiaosu.app',
      name: 'XiaoSu',
      isIPhone: true,
      screenScale: 3.0,
      capabilities: [
        DeviceCapability.faceId,
        DeviceCapability.lidar,
        DeviceCapability.nfc,
        DeviceCapability.ultraWideband,
      ],
    );
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onNotificationTapped':
          _handleNotificationTap(call.arguments as Map<String, dynamic>);
          break;
        case 'onBackgroundTask':
          return _handleBackgroundTask(call.arguments as Map<String, dynamic>);
        case 'onSiriIntent':
          _handleSiriIntent(call.arguments as Map<String, dynamic>);
          break;
        case 'onPencilInteraction':
          _handlePencilInteraction(call.arguments as Map<String, dynamic>);
          break;
        case 'onWidgetTimelineUpdate':
          _handleWidgetUpdate(call.arguments as Map<String, dynamic>);
          break;
      }
    });
  }

  // --------------------------------------------------------------------------
  // Push Notifications (APNs)
  // --------------------------------------------------------------------------

  Future<PermissionStatus> requestNotificationPermission() async {
    return permissionManager.requestPermission(PermissionType.notification);
  }

  Future<void> setAPNsEnvironment(APNsEnvironment env) async {
    _apnsEnvironment = env;
  }

  Future<String?> getDeviceToken() async {
    final token = await _channel.invokeMethod<String>('getAPNsToken');
    return token;
  }

  Future<void> registerForPushNotifications() async {
    await _channel.invokeMethod('registerForPushNotifications', {
      'environment': _apnsEnvironment.name,
    });
  }

  Future<void> scheduleNotification(IosNotification notification) async {
    await _channel.invokeMethod('scheduleNotification', notification.toJson());
  }

  Future<void> sendLocalNotification({
    required String title,
    required String body,
    String? subtitle,
    Map<String, dynamic>? userInfo,
    String? sound,
    int? badgeCount,
  }) async {
    final notification = IosNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      subtitle: subtitle,
      userInfo: userInfo ?? {},
      sound: sound,
      badgeCount: badgeCount,
    );
    await scheduleNotification(notification);
  }

  Future<void> cancelNotification(String id) async {
    await _channel.invokeMethod('cancelNotification', {'id': id});
  }

  Future<void> cancelAllNotifications() async {
    await _channel.invokeMethod('cancelAllNotifications');
  }

  Future<void> setBadgeCount(int count) async {
    await _channel.invokeMethod('setBadgeCount', {'count': count});
  }

  void _registerNotificationCategories() {
    _channel.invokeMethod('registerNotificationCategories', {
      'categories': [
        {
          'identifier': 'CHAT_RESPONSE',
          'actions': [
            {
              'id': 'REPLY',
              'title': 'Reply',
              'text_input_button_title': 'Send',
              'text_input_placeholder': 'Type a message...',
            },
            {
              'id': 'DISMISS',
              'title': 'Dismiss',
              'is_destructive': false,
            },
          ],
        },
        {
          'identifier': 'TASK_ALERT',
          'actions': [
            {
              'id': 'COMPLETE',
              'title': 'Mark Complete',
            },
            {
              'id': 'SNOOZE',
              'title': 'Snooze',
            },
          ],
        },
      ],
    });
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final notification = IosNotification.fromJson(data);
    _notificationController.add(notification);
  }

  // --------------------------------------------------------------------------
  // Background Tasks (BGTaskScheduler)
  // --------------------------------------------------------------------------

  Future<void> registerBackgroundTask(BackgroundTaskConfig config) async {
    await _channel.invokeMethod('registerBackgroundTask', config.toJson());
  }

  Future<void> _registerBackgroundTasks() async {
    // Register standard background tasks
    await registerBackgroundTask(const BackgroundTaskConfig(
      taskId: 'com.xiaosu.refresh',
      requiresNetwork: true,
      isRecurring: true,
      earliestRunDate: Duration(hours: 1),
    ));
    await registerBackgroundTask(const BackgroundTaskConfig(
      taskId: 'com.xiaosu.sync',
      requiresNetwork: true,
      requiresCharging: true,
      isRecurring: true,
      earliestRunDate: Duration(hours: 4),
    ));
  }

  Future<BackgroundTaskResult> _handleBackgroundTask(
      Map<String, dynamic> data) async {
    final taskId = data['task_id'] as String? ?? '';

    try {
      switch (taskId) {
        case 'com.xiaosu.refresh':
          await _performBackgroundRefresh();
          return BackgroundTaskResult.newData;
        case 'com.xiaosu.sync':
          await _performBackgroundSync();
          return BackgroundTaskResult.newData;
        default:
          return BackgroundTaskResult.noNewData;
      }
    } catch (e) {
      return BackgroundTaskResult.failed;
    }
  }

  Future<void> _performBackgroundRefresh() async {
    // Fetch latest data for widgets, notifications, etc.
    await _channel.invokeMethod('updateWidgetTimeline');
    await _channel.invokeMethod('refreshBadges');
  }

  Future<void> _performBackgroundSync() async {
    // Sync offline data with server
    await _channel.invokeMethod('syncOfflineData');
  }

  Future<void> submitBackgroundTask({
    required String taskId,
    required Future<void> Function() work,
  }) async {
    try {
      await work();
      _bgTaskController.add(BackgroundTaskResult.newData);
    } catch (e) {
      _bgTaskController.add(BackgroundTaskResult.failed);
    }
  }

  // --------------------------------------------------------------------------
  // Biometric Authentication (Face ID / Touch ID)
  // --------------------------------------------------------------------------

  Future<BiometricType> getAvailableBiometric() async {
    final device = _deviceInfo;
    if (device == null) return BiometricType.notAvailable;
    if (device.supportsFaceId) return BiometricType.faceId;
    if (device.supportsTouchId) return BiometricType.touchId;
    return BiometricType.none;
  }

  Future<AuthResult> authenticate({
    String reason = 'Authenticate to access XiaoSu',
    bool useFallback = false,
  }) async {
    final biometricType = await getAvailableBiometric();
    if (biometricType == BiometricType.none ||
        biometricType == BiometricType.notAvailable) {
      return AuthResult.notAvailable;
    }

    try {
      final result = await _channel.invokeMethod<String>('authenticate', {
        'reason': reason,
        'biometric_type': biometricType.name,
        'use_fallback': useFallback,
      });
      return AuthResult.values.firstWhere(
        (e) => e.name == result,
        orElse: () => AuthResult.failed,
      );
    } catch (e) {
      return AuthResult.failed;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final result = await _channel.invokeMethod<bool>('isBiometricEnabled');
    return result ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _channel.invokeMethod('setBiometricEnabled', {'enabled': enabled});
  }

  // --------------------------------------------------------------------------
  // Camera & Photo Library
  // --------------------------------------------------------------------------

  Future<String?> capturePhoto({int quality = 85}) async {
    final status = await permissionManager.requestPermission(PermissionType.camera);
    if (status != PermissionStatus.authorized) return null;

    final path = await _channel.invokeMethod<String>('capturePhoto', {
      'quality': quality,
    });
    return path;
  }

  Future<String?> pickImage({
    bool allowCamera = true,
    bool allowGallery = true,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    if (allowGallery) {
      final status = await permissionManager.requestPermission(
          PermissionType.photoLibrary);
      if (status != PermissionStatus.authorized) return null;
    }

    final path = await _channel.invokeMethod<String>('pickImage', {
      'allow_camera': allowCamera,
      'allow_gallery': allowGallery,
      'max_width': maxWidth,
      'max_height': maxHeight,
    });
    return path;
  }

  Future<List<String>> pickMultipleImages({int maxCount = 9}) async {
    final status = await permissionManager.requestPermission(
        PermissionType.photoLibrary);
    if (status != PermissionStatus.authorized) return [];

    final paths = await _channel.invokeMethod<List>('pickMultipleImages', {
      'max_count': maxCount,
    });
    return paths?.cast<String>() ?? [];
  }

  Future<bool> saveImageToGallery(String filePath) async {
    final status = await permissionManager.requestPermission(
        PermissionType.photoLibrary);
    if (status != PermissionStatus.authorized) return false;

    final result = await _channel.invokeMethod<bool>('saveImageToGallery', {
      'file_path': filePath,
    });
    return result ?? false;
  }

  // --------------------------------------------------------------------------
  // File System Sandbox
  // --------------------------------------------------------------------------

  Future<String> getDocumentsDirectory() async {
    final path = await _channel.invokeMethod<String>('getDocumentsDirectory');
    return path ?? '';
  }

  Future<String> getCachesDirectory() async {
    final path = await _channel.invokeMethod<String>('getCachesDirectory');
    return path ?? '';
  }

  Future<String> getTemporaryDirectory() async {
    final path = await _channel.invokeMethod<String>('getTemporaryDirectory');
    return path ?? '';
  }

  Future<String> getApplicationSupportDirectory() async {
    final path = await _channel
        .invokeMethod<String>('getApplicationSupportDirectory');
    return path ?? '';
  }

  Future<int> getAvailableStorage() async {
    final bytes = await _channel.invokeMethod<int>('getAvailableStorage');
    return bytes ?? 0;
  }

  Future<bool> fileExistsInSandbox(String path) async {
    final exists =
        await _channel.invokeMethod<bool>('fileExists', {'path': path});
    return exists ?? false;
  }

  Future<void> clearCacheDirectory() async {
    await _channel.invokeMethod('clearCacheDirectory');
  }

  // --------------------------------------------------------------------------
  // Siri Shortcuts
  // --------------------------------------------------------------------------

  Future<void> registerSiriShortcut(SiriShortcut shortcut) async {
    await _channel.invokeMethod(
        'registerSiriShortcut', shortcut.toJson());
  }

  Future<void> registerDefaultShortcuts() async {
    await registerSiriShortcut(const SiriShortcut(
      id: 'start_chat',
      title: 'Chat with XiaoSu',
      subtitle: 'Start a new conversation',
      intentType: SiriIntentType.startChat,
      isEligibleForSearch: true,
      isEligibleForPrediction: true,
      suggestedInvocationPhrase: 'Chat with XiaoSu',
    ));

    await registerSiriShortcut(const SiriShortcut(
      id: 'search_history',
      title: 'Search XiaoSu History',
      subtitle: 'Search your conversation history',
      intentType: SiriIntentType.searchHistory,
      isEligibleForSearch: true,
      isEligibleForPrediction: true,
      suggestedInvocationPhrase: 'Search XiaoSu',
    ));

    await registerSiriShortcut(const SiriShortcut(
      id: 'create_reminder',
      title: 'XiaoSu Reminder',
      subtitle: 'Create a reminder with XiaoSu',
      intentType: SiriIntentType.createReminder,
      isEligibleForSearch: true,
      isEligibleForPrediction: true,
      suggestedInvocationPhrase: 'Remind me with XiaoSu',
    ));
  }

  Future<void> donateSiriIntent({
    required SiriIntentType intentType,
    Map<String, dynamic> parameters = const {},
  }) async {
    await _channel.invokeMethod('donateSiriIntent', {
      'intent_type': intentType.name,
      'parameters': parameters,
    });
  }

  Future<void> deleteSiriShortcut(String shortcutId) async {
    await _channel.invokeMethod('deleteSiriShortcut', {'id': shortcutId});
  }

  void _handleSiriIntent(Map<String, dynamic> data) {
    final intentType = data['intent_type'] as String? ?? '';
    _siriController.add(intentType);
  }

  // --------------------------------------------------------------------------
  // Widget Kit
  // --------------------------------------------------------------------------

  Future<void> updateWidget(WidgetConfig config) async {
    await _channel.invokeMethod('updateWidget', config.toJson());
    _widgetController.add(config);
  }

  Future<void> updateAllWidgets() async {
    await _channel.invokeMethod('updateAllWidgets');
  }

  Future<void> refreshWidgetTimeline() async {
    await _channel.invokeMethod('reloadWidgetTimelines');
  }

  Future<List<WidgetConfig>> getActiveWidgets() async {
    final result = await _channel.invokeMethod<List>('getActiveWidgets');
    if (result == null) return [];
    return result
        .map((w) => WidgetConfig.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  void _handleWidgetUpdate(Map<String, dynamic> data) {
    final config = WidgetConfig.fromJson(data);
    _widgetController.add(config);
  }

  Future<void> setWidgetData({
    required String kind,
    required Map<String, dynamic> data,
  }) async {
    await _channel.invokeMethod('setWidgetData', {
      'kind': kind,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // --------------------------------------------------------------------------
  // Apple Pencil Support
  // --------------------------------------------------------------------------

  bool get isApplePencilSupported {
    return _deviceInfo?.supportsApplePencil ?? false;
  }

  Future<void> enablePencilInteraction({
    List<PencilInteraction> interactions = const [
      PencilInteraction.tap,
      PencilInteraction.doubleTap,
    ],
  }) async {
    if (!isApplePencilSupported) return;
    await _channel.invokeMethod('enablePencilInteraction', {
      'interactions': interactions.map((i) => i.name).toList(),
    });
  }

  Future<void> disablePencilInteraction() async {
    await _channel.invokeMethod('disablePencilInteraction');
  }

  Stream<PencilInteraction> get pencilInteractions => _pencilController.stream;

  void _handlePencilInteraction(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final interaction = PencilInteraction.values.firstWhere(
      (e) => e.name == type,
      orElse: () => PencilInteraction.tap,
    );
    _pencilController.add(interaction);
  }

  // --------------------------------------------------------------------------
  // Haptic Feedback
  // --------------------------------------------------------------------------

  Future<void> triggerHaptic(HapticStyle style) async {
    await _channel.invokeMethod('triggerHaptic', {
      'style': style.name,
    });
  }

  Future<void> hapticSelection() async {
    await triggerHaptic(HapticStyle.selection);
  }

  Future<void> hapticNotification({
    bool success = true,
  }) async {
    if (success) {
      await triggerHaptic(HapticStyle.success);
    } else {
      await triggerHaptic(HapticStyle.error);
    }
  }

  Future<void> hapticImpact({
    bool heavy = false,
  }) async {
    await triggerHaptic(heavy ? HapticStyle.heavy : HapticStyle.light);
  }

  // --------------------------------------------------------------------------
  // Deep Links & Universal Links
  // --------------------------------------------------------------------------

  Future<String?> getInitialDeepLink() async {
    return _channel.invokeMethod<String>('getInitialDeepLink');
  }

  Stream<String> get deepLinkStream {
    // In production, returns a stream of deep link URLs
    return const Stream<String>.empty();
  }

  // --------------------------------------------------------------------------
  // App Lifecycle
  // --------------------------------------------------------------------------

  Future<void> requestAppReview() async {
    await _channel.invokeMethod('requestAppReview');
  }

  Future<bool> isLowPowerModeEnabled() async {
    final result =
        await _channel.invokeMethod<bool>('isLowPowerModeEnabled');
    return result ?? false;
  }

  Future<double> getBatteryLevel() async {
    final level = await _channel.invokeMethod<double>('getBatteryLevel');
    return level ?? -1.0;
  }

  // --------------------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------------------

  Future<void> dispose() async {
    await permissionManager.dispose();
    await _notificationController.close();
    await _bgTaskController.close();
    await _siriController.close();
    await _pencilController.close();
    await _widgetController.close();
  }

  @override
  String toString() =>
      'IosScheduler(device=${_deviceInfo?.model ?? "unknown"}, initialized=$_initialized)';
}
