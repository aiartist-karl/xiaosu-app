// ============================================================================
// 小酥 - 离线服务
// ============================================================================

import 'package:connectivity_plus/connectivity_plus.dart';

/// 离线服务 - 网络状态管理
class OfflineService {
  static final OfflineService instance = OfflineService._();
  OfflineService._();

  bool _isOnline = true;
  final List<void Function(bool)> _listeners = [];

  /// 是否在线
  bool get isOnline => _isOnline;

  /// 初始化
  Future<void> initialize() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = result != ConnectivityResult.none;

    Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      if (wasOnline != _isOnline) {
        for (final listener in _listeners) {
          listener(_isOnline);
        }
      }
    });
  }

  /// 监听网络变化
  void addListener(void Function(bool isOnline) listener) {
    _listeners.add(listener);
  }

  /// 移除监听
  void removeListener(void Function(bool isOnline) listener) {
    _listeners.remove(listener);
  }
}
