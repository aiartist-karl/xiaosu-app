// ============================================================================
// 小酥 v2 - Bot 管理器
// Phase 2: 提供 Bot 业务逻辑层，管理 Bot 缓存、选中状态、切换事件
// ============================================================================

import 'dart:async';
import '../../data/models/bot_model.dart';
import '../../data/repositories/bot_repository.dart';

/// Bot 管理器 - 业务逻辑层
///
/// 职责：
/// - 管理当前选中的 Bot
/// - 缓存 Bot 列表，避免频繁请求
/// - 提供 Bot 切换事件流
/// - 协调数据仓库与 UI 层
class BotManager {
  static final BotManager instance = BotManager._();
  BotManager._();

  final BotRepository _repository = BotRepository();

  // ==========================================================================
  // 状态
  // ==========================================================================

  /// 当前选中的 Bot
  BotModel? _currentBot;
  BotModel? get currentBot => _currentBot;

  /// Bot 列表缓存
  List<BotModel> _cachedBots = [];
  List<BotModel> get cachedBots => List.unmodifiable(_cachedBots);

  /// 缓存时间
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// 是否正在加载
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 最后一次错误
  String? _lastError;
  String? get lastError => _lastError;

  // ==========================================================================
  // 事件流
  // ==========================================================================

  /// Bot 切换事件流控制器
  final StreamController<BotModel?> _botSwitchController =
      StreamController<BotModel?>.broadcast();

  /// Bot 列表更新事件流控制器
  final StreamController<List<BotModel>> _botListUpdateController =
      StreamController<List<BotModel>>.broadcast();

  /// 监听 Bot 切换事件
  Stream<BotModel?> get onBotSwitched => _botSwitchController.stream;

  /// 监听 Bot 列表更新事件
  Stream<List<BotModel>> get onBotListUpdated => _botListUpdateController.stream;

  // ==========================================================================
  // Bot 列表管理
  // ==========================================================================

  /// 获取 Bot 列表（带缓存）
  ///
  /// [forceRefresh] 为 true 时强制刷新，忽略缓存
  Future<List<BotModel>> fetchBotList({
    bool forceRefresh = false,
    String? keyword,
  }) async {
    // 检查缓存有效性
    if (!forceRefresh &&
        _cachedBots.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration &&
        keyword == null) {
      return _cachedBots;
    }

    _isLoading = true;
    _lastError = null;

    try {
      final response = await _repository.fetchBotList(keyword: keyword);

      if (response.success && response.data != null) {
        _cachedBots = response.data!;
        _lastFetchTime = DateTime.now();
        _botListUpdateController.add(_cachedBots);
        return _cachedBots;
      } else {
        _lastError = response.error ?? '获取 Bot 列表失败';
        // 返回缓存数据（如果有）
        return _cachedBots;
      }
    } catch (e) {
      _lastError = '获取 Bot 列表异常: ${e.toString()}';
      return _cachedBots;
    } finally {
      _isLoading = false;
    }
  }

  /// 清除 Bot 列表缓存
  void clearCache() {
    _cachedBots = [];
    _lastFetchTime = null;
  }

  // ==========================================================================
  // 当前 Bot 管理
  // ==========================================================================

  /// 切换当前 Bot
  ///
  /// [botId] Bot ID
  /// 会先从缓存中查找，找不到则请求详情接口
  Future<BotModel?> switchBot(String botId) async {
    // 先从缓存查找
    BotModel? bot = _cachedBots.where((b) => b.id == botId).firstOrNull;

    // 缓存中没有，请求详情
    if (bot == null) {
      final response = await _repository.fetchBotDetail(botId);
      if (response.success && response.data != null) {
        bot = response.data!;
      }
    }

    if (bot != null) {
      _currentBot = bot;
      _botSwitchController.add(bot);
    }

    return bot;
  }

  /// 直接设置当前 Bot（从列表中选中时调用，无需再请求）
  void setCurrentBot(BotModel bot) {
    _currentBot = bot;
    _botSwitchController.add(bot);
  }

  /// 清除当前 Bot
  void clearCurrentBot() {
    _currentBot = null;
    _botSwitchController.add(null);
  }

  // ==========================================================================
  // Bot CRUD 操作
  // ==========================================================================

  /// 创建 Bot
  Future<BotModel?> createBot(BotModel bot) async {
    final response = await _repository.createBot(bot);

    if (response.success && response.data != null) {
      final newBot = response.data!;
      // 更新缓存
      _cachedBots.insert(0, newBot);
      _lastFetchTime = DateTime.now();
      _botListUpdateController.add(_cachedBots);
      return newBot;
    }

    _lastError = response.error;
    return null;
  }

  /// 更新 Bot
  Future<BotModel?> updateBot(String botId, BotModel bot) async {
    final response = await _repository.updateBot(botId, bot);

    if (response.success && response.data != null) {
      final updatedBot = response.data!;
      // 更新缓存
      final index = _cachedBots.indexWhere((b) => b.id == botId);
      if (index >= 0) {
        _cachedBots[index] = updatedBot;
      }
      // 如果是当前 Bot，同步更新
      if (_currentBot?.id == botId) {
        _currentBot = updatedBot;
        _botSwitchController.add(updatedBot);
      }
      _botListUpdateController.add(_cachedBots);
      return updatedBot;
    }

    _lastError = response.error;
    return null;
  }

  /// 发布 Bot
  Future<bool> publishBot(String botId, {String? versionDesc}) async {
    final response = await _repository.publishBot(
      botId,
      versionDesc: versionDesc,
    );

    if (response.success) {
      // 更新缓存中的状态
      final index = _cachedBots.indexWhere((b) => b.id == botId);
      if (index >= 0) {
        _cachedBots[index] = _cachedBots[index].copyWith(
          status: BotStatus.published,
        );
        _botListUpdateController.add(_cachedBots);
      }
      if (_currentBot?.id == botId) {
        _currentBot = _currentBot!.copyWith(status: BotStatus.published);
        _botSwitchController.add(_currentBot);
      }
      return true;
    }

    _lastError = response.error;
    return false;
  }

  /// 删除 Bot
  Future<bool> deleteBot(String botId) async {
    final response = await _repository.deleteBot(botId);

    if (response.success) {
      // 从缓存移除
      _cachedBots.removeWhere((b) => b.id == botId);
      _botListUpdateController.add(_cachedBots);
      // 如果删除的是当前 Bot，清除
      if (_currentBot?.id == botId) {
        clearCurrentBot();
      }
      return true;
    }

    _lastError = response.error;
    return false;
  }

  /// 获取 Bot 详情（不更新缓存）
  Future<BotModel?> getBotDetail(String botId) async {
    final response = await _repository.fetchBotDetail(botId);

    if (response.success && response.data != null) {
      return response.data!;
    }

    _lastError = response.error;
    return null;
  }

  /// 复制 Bot
  Future<BotModel?> duplicateBot(String botId, {String? targetName}) async {
    final response = await _repository.duplicateBot(
      botId,
      targetName: targetName,
    );

    if (response.success && response.data != null) {
      final duplicated = response.data!;
      _cachedBots.insert(0, duplicated);
      _botListUpdateController.add(_cachedBots);
      return duplicated;
    }

    _lastError = response.error;
    return null;
  }

  // ==========================================================================
  // 辅助方法
  // ==========================================================================

  /// 从缓存中获取 Bot
  BotModel? getCachedBot(String botId) {
    return _cachedBots.where((b) => b.id == botId).firstOrNull;
  }

  /// 检查缓存是否有效
  bool get isCacheValid =>
      _cachedBots.isNotEmpty &&
      _lastFetchTime != null &&
      DateTime.now().difference(_lastFetchTime!) < _cacheDuration;

  // ==========================================================================
  // 清理
  // ==========================================================================

  /// 释放资源
  void dispose() {
    _botSwitchController.close();
    _botListUpdateController.close();
  }
}
