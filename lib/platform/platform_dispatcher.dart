// ============================================================================
// 小酥 - 平台调度器分发
// ============================================================================

import 'dart:io';
import 'platform_scheduler.dart';
import 'android_scheduler.dart';
import 'ios/ios_scheduler.dart';
import 'linux/linux_scheduler.dart';
import 'macos/macos_scheduler.dart';
import 'windows/windows_scheduler.dart';

/// 平台调度器分发 - 根据当前平台选择对应的调度器
class PlatformDispatcher {
  static final PlatformDispatcher instance = PlatformDispatcher._();
  PlatformDispatcher._();

  PlatformScheduler? _scheduler;

  PlatformScheduler get scheduler {
    if (_scheduler != null) return _scheduler!;
    _scheduler = _createForCurrentPlatform();
    return _scheduler!;
  }

  PlatformScheduler _createForCurrentPlatform() {
    if (Platform.isAndroid) return AndroidScheduler();
    if (Platform.isIOS) return IosScheduler();
    if (Platform.isLinux) return LinuxScheduler();
    if (Platform.isMacOS) return MacosScheduler();
    if (Platform.isWindows) return WindowsScheduler();
    return AndroidScheduler(); // 默认
  }

  Future<void> initialize() async {
    await scheduler.initialize();
  }

  Future<void> dispose() async {
    await _scheduler?.dispose();
  }
}
