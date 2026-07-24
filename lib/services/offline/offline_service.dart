/// Offline Service - Manages offline capabilities, queue, caching, and sync
///
/// Provides complete offline experience with graceful degradation,
/// task queuing, and automatic sync when connectivity is restored.
///
/// Author: XiaoSu Core Team
/// Date: 2026-06-29

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

// ============================================================================
// Enums
// ============================================================================

/// Network connectivity status
enum NetworkStatus {
  connected,
  disconnected,
  connecting,
  degraded,
}

/// Network type
enum NetworkType {
  wifi,
  mobile,
  ethernet,
  none,
  unknown,
}

/// Offline capability level for each feature
enum CapabilityLevel {
  full,
  degraded,
  unavailable,
}

/// Task queue status
enum QueuedTaskStatus {
  pending,
  running,
  completed,
  failed,
  conflict,
  retrying,
  cancelled,
}

/// Task priority
enum TaskPriority {
  critical,
  high,
  normal,
  low,
  background,
}

/// Sync policy
enum SyncPolicy {
  wifiOnly,
  always,
  manual,
}

/// Cache strategy
enum CacheStrategy {
  eager,
  lazy,
  ttl,
  manual,
}

/// Sync conflict resolution
enum ConflictResolution {
  localWins,
  remoteWins,
  merge,
  skip,
  prompt,
}

// ============================================================================
// Data Models
// ============================================================================

/// Overall offline state
class OfflineState {
  final NetworkStatus networkStatus;
  final NetworkType networkType;
  final bool isOffline;
  final DateTime? lastConnectedAt;
  final DateTime? lastSyncedAt;
  final int pendingTaskCount;
  final int cachedItemCount;
  final int totalCacheBytes;
  final double syncProgress;
  final bool isSyncing;
  final Map<String, CapabilityLevel> capabilityMatrix;
  final SyncPolicy syncPolicy;
  final String? lastError;

  const OfflineState({
    required this.networkStatus,
    required this.networkType,
    required this.isOffline,
    this.lastConnectedAt,
    this.lastSyncedAt,
    this.pendingTaskCount = 0,
    this.cachedItemCount = 0,
    this.totalCacheBytes = 0,
    this.syncProgress = 0.0,
    this.isSyncing = false,
    this.capabilityMatrix = const {},
    this.syncPolicy = SyncPolicy.wifiOnly,
    this.lastError,
  });

  OfflineState copyWith({
    NetworkStatus? networkStatus,
    NetworkType? networkType,
    bool? isOffline,
    DateTime? lastConnectedAt,
    DateTime? lastSyncedAt,
    int? pendingTaskCount,
    int? cachedItemCount,
    int? totalCacheBytes,
    double? syncProgress,
    bool? isSyncing,
    Map<String, CapabilityLevel>? capabilityMatrix,
    SyncPolicy? syncPolicy,
    String? lastError,
  }) {
    return OfflineState(
      networkStatus: networkStatus ?? this.networkStatus,
      networkType: networkType ?? this.networkType,
      isOffline: isOffline ?? this.isOffline,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingTaskCount: pendingTaskCount ?? this.pendingTaskCount,
      cachedItemCount: cachedItemCount ?? this.cachedItemCount,
      totalCacheBytes: totalCacheBytes ?? this.totalCacheBytes,
      syncProgress: syncProgress ?? this.syncProgress,
      isSyncing: isSyncing ?? this.isSyncing,
      capabilityMatrix: capabilityMatrix ?? this.capabilityMatrix,
      syncPolicy: syncPolicy ?? this.syncPolicy,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'network_status': networkStatus.name,
        'network_type': networkType.name,
        'is_offline': isOffline,
        'last_connected_at': lastConnectedAt?.toIso8601String(),
        'last_synced_at': lastSyncedAt?.toIso8601String(),
        'pending_task_count': pendingTaskCount,
        'cached_item_count': cachedItemCount,
        'total_cache_bytes': totalCacheBytes,
        'sync_progress': syncProgress,
        'is_syncing': isSyncing,
        'capability_matrix':
            capabilityMatrix.map((k, v) => MapEntry(k, v.name)),
        'sync_policy': syncPolicy.name,
        'last_error': lastError,
      };

  @override
  String toString() =>
      'OfflineState(status=${networkStatus.name}, offline=$isOffline, pending=$pendingTaskCount)';
}

/// Queued task for offline execution
class QueuedTask {
  final String id;
  final String taskType;
  final String description;
  final Map<String, dynamic> payload;
  final TaskPriority priority;
  final QueuedTaskStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int retryCount;
  final int maxRetries;
  final String? errorMessage;
  final String? resultJson;
  final bool requiresNetwork;
  final ConflictResolution conflictResolution;
  final List<String> dependencies;
  final String? groupId;

  const QueuedTask({
    required this.id,
    required this.taskType,
    required this.description,
    required this.payload,
    this.priority = TaskPriority.normal,
    this.status = QueuedTaskStatus.pending,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.errorMessage,
    this.resultJson,
    this.requiresNetwork = false,
    this.conflictResolution = ConflictResolution.localWins,
    this.dependencies = const [],
    this.groupId,
  });

  bool get isPending => status == QueuedTaskStatus.pending;
  bool get isRetryable =>
      status == QueuedTaskStatus.failed && retryCount < maxRetries;
  bool get isTerminal =>
      status == QueuedTaskStatus.completed ||
      status == QueuedTaskStatus.cancelled;

  QueuedTask copyWith({
    String? id,
    String? taskType,
    String? description,
    Map<String, dynamic>? payload,
    TaskPriority? priority,
    QueuedTaskStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int? retryCount,
    int? maxRetries,
    String? errorMessage,
    String? resultJson,
    bool? requiresNetwork,
    ConflictResolution? conflictResolution,
    List<String>? dependencies,
    String? groupId,
  }) {
    return QueuedTask(
      id: id ?? this.id,
      taskType: taskType ?? this.taskType,
      description: description ?? this.description,
      payload: payload ?? this.payload,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      errorMessage: errorMessage ?? this.errorMessage,
      resultJson: resultJson ?? this.resultJson,
      requiresNetwork: requiresNetwork ?? this.requiresNetwork,
      conflictResolution: conflictResolution ?? this.conflictResolution,
      dependencies: dependencies ?? this.dependencies,
      groupId: groupId ?? this.groupId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'task_type': taskType,
        'description': description,
        'payload': payload,
        'priority': priority.name,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'retry_count': retryCount,
        'max_retries': maxRetries,
        'error_message': errorMessage,
        'result_json': resultJson,
        'requires_network': requiresNetwork,
        'conflict_resolution': conflictResolution.name,
        'dependencies': dependencies,
        'group_id': groupId,
      };

  factory QueuedTask.fromJson(Map<String, dynamic> json) => QueuedTask(
        id: json['id'] as String,
        taskType: json['task_type'] as String,
        description: json['description'] as String? ?? '',
        payload: (json['payload'] as Map<String, dynamic>?) ?? {},
        priority: TaskPriority.values.firstWhere(
            (e) => e.name == json['priority'],
            orElse: () => TaskPriority.normal),
        status: QueuedTaskStatus.values.firstWhere(
            (e) => e.name == json['status'],
            orElse: () => QueuedTaskStatus.pending),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        startedAt: json['started_at'] != null
            ? DateTime.parse(json['started_at'] as String)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        retryCount: json['retry_count'] as int? ?? 0,
        maxRetries: json['max_retries'] as int? ?? 3,
        errorMessage: json['error_message'] as String?,
        resultJson: json['result_json'] as String?,
        requiresNetwork: json['requires_network'] as bool? ?? false,
        conflictResolution: ConflictResolution.values.firstWhere(
            (e) => e.name == json['conflict_resolution'],
            orElse: () => ConflictResolution.localWins),
        dependencies:
            (json['dependencies'] as List<dynamic>?)?.cast<String>() ?? [],
        groupId: json['group_id'] as String?,
      );

  @override
  String toString() =>
      'QueuedTask($id, type=$taskType, status=${status.name}, priority=${priority.name})';
}

/// Cache status for a specific resource
class CacheStatus {
  final String resourceId;
  final String resourceType;
  final CacheStrategy strategy;
  final DateTime cachedAt;
  final DateTime? expiresAt;
  final int sizeBytes;
  final String? localPath;
  final bool isPinned;
  final int hitCount;
  final DateTime? lastAccessedAt;
  final String checksum;

  const CacheStatus({
    required this.resourceId,
    required this.resourceType,
    required this.strategy,
    required this.cachedAt,
    this.expiresAt,
    this.sizeBytes = 0,
    this.localPath,
    this.isPinned = false,
    this.hitCount = 0,
    this.lastAccessedAt,
    this.checksum = '',
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isValid => !isExpired;

  CacheStatus copyWith({
    String? resourceId,
    String? resourceType,
    CacheStrategy? strategy,
    DateTime? cachedAt,
    DateTime? expiresAt,
    int? sizeBytes,
    String? localPath,
    bool? isPinned,
    int? hitCount,
    DateTime? lastAccessedAt,
    String? checksum,
  }) {
    return CacheStatus(
      resourceId: resourceId ?? this.resourceId,
      resourceType: resourceType ?? this.resourceType,
      strategy: strategy ?? this.strategy,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      localPath: localPath ?? this.localPath,
      isPinned: isPinned ?? this.isPinned,
      hitCount: hitCount ?? this.hitCount,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      checksum: checksum ?? this.checksum,
    );
  }

  Map<String, dynamic> toJson() => {
        'resource_id': resourceId,
        'resource_type': resourceType,
        'strategy': strategy.name,
        'cached_at': cachedAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'size_bytes': sizeBytes,
        'local_path': localPath,
        'is_pinned': isPinned,
        'hit_count': hitCount,
        'last_accessed_at': lastAccessedAt?.toIso8601String(),
        'checksum': checksum,
      };

  factory CacheStatus.fromJson(Map<String, dynamic> json) => CacheStatus(
        resourceId: json['resource_id'] as String,
        resourceType: json['resource_type'] as String,
        strategy: CacheStrategy.values.firstWhere(
            (e) => e.name == json['strategy'],
            orElse: () => CacheStrategy.lazy),
        cachedAt: json['cached_at'] != null
            ? DateTime.parse(json['cached_at'] as String)
            : DateTime.now(),
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
        sizeBytes: json['size_bytes'] as int? ?? 0,
        localPath: json['local_path'] as String?,
        isPinned: json['is_pinned'] as bool? ?? false,
        hitCount: json['hit_count'] as int? ?? 0,
        lastAccessedAt: json['last_accessed_at'] != null
            ? DateTime.parse(json['last_accessed_at'] as String)
            : null,
        checksum: json['checksum'] as String? ?? '',
      );

  @override
  String toString() =>
      'CacheStatus($resourceId, type=$resourceType, valid=$isValid, size=$sizeBytes)';
}

/// Offline capability descriptor
class OfflineCapability {
  final String featureName;
  final String displayName;
  final String description;
  final CapabilityLevel onlineLevel;
  final CapabilityLevel offlineLevel;
  final bool requiresNetwork;
  final List<String> localDependencies;

  const OfflineCapability({
    required this.featureName,
    required this.displayName,
    required this.description,
    required this.onlineLevel,
    required this.offlineLevel,
    this.requiresNetwork = false,
    this.localDependencies = const [],
  });
}

/// Sync result after reconnection
class SyncResult {
  final int tasksProcessed;
  final int tasksFailed;
  final int conflictsResolved;
  final int dataItemsSynced;
  final Duration duration;
  final List<String> errors;
  final DateTime completedAt;

  const SyncResult({
    required this.tasksProcessed,
    required this.tasksFailed,
    required this.conflictsResolved,
    required this.dataItemsSynced,
    required this.duration,
    this.errors = const [],
    required this.completedAt,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isCompleteSuccess => tasksFailed == 0 && errors.isEmpty;

  @override
  String toString() =>
      'SyncResult(processed=$tasksProcessed, failed=$tasksFailed, '
      'conflicts=$conflictsResolved, duration=${duration.inSeconds}s)';
}

// ============================================================================
// Network Monitor
// ============================================================================

class NetworkMonitor {
  NetworkStatus _status = NetworkStatus.unknown;
  NetworkType _type = NetworkType.none;
  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();
  Timer? _pollTimer;
  bool _initialized = false;

  NetworkStatus get status => _status;
  NetworkType get type => _type;
  Stream<NetworkStatus> get statusStream => _statusController.stream;
  bool get isConnected => _status == NetworkStatus.connected;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _checkConnectivity();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivity() async {
    final previousStatus = _status;
    try {
      final results = await Future.wait([
        InternetAddress.lookup('connectivitycheck.gstatic.com')
            .timeout(const Duration(seconds: 5)),
      ]);
      if (results.first.isNotEmpty) {
        _status = NetworkStatus.connected;
        _type = NetworkType.wifi; // Simplified detection
      } else {
        _status = NetworkStatus.disconnected;
        _type = NetworkType.none;
      }
    } on SocketException {
      _status = NetworkStatus.disconnected;
      _type = NetworkType.none;
    } catch (_) {
      _status = NetworkStatus.disconnected;
      _type = NetworkType.none;
    }

    if (_status != previousStatus) {
      _statusController.add(_status);
    }
  }

  Future<void> dispose() async {
    _pollTimer?.cancel();
    await _statusController.close();
  }
}

// ============================================================================
// Cache Manager
// ============================================================================

class CacheManager {
  final String cacheDir;
  final int maxCacheSizeBytes;
  final Map<String, CacheStatus> _cacheIndex = {};
  final String _indexPath;

  CacheManager({
    required this.cacheDir,
    this.maxCacheSizeBytes = 500 * 1024 * 1024, // 500MB default
  }) : _indexPath = '$cacheDir/cache_index.json';

  Future<void> initialize() async {
    final dir = Directory(cacheDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _loadIndex();
  }

  Future<void> _loadIndex() async {
    final file = File(_indexPath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final data = jsonDecode(content) as List<dynamic>;
        _cacheIndex.clear();
        for (final item in data) {
          final status = CacheStatus.fromJson(item as Map<String, dynamic>);
          _cacheIndex[status.resourceId] = status;
        }
      } catch (_) {
        _cacheIndex.clear();
      }
    }
  }

  Future<void> _saveIndex() async {
    final file = File(_indexPath);
    final data = _cacheIndex.values.map((s) => s.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> cacheResource({
    required String resourceId,
    required String resourceType,
    required List<int> data,
    CacheStrategy strategy = CacheStrategy.lazy,
    Duration? ttl,
    bool pinned = false,
  }) async {
    await _evictIfNeeded(data.length);

    final filePath = '$cacheDir/${resourceId.replaceAll('/', '_')}';
    final file = File(filePath);
    await file.writeAsBytes(data);

    _cacheIndex[resourceId] = CacheStatus(
      resourceId: resourceId,
      resourceType: resourceType,
      strategy: strategy,
      cachedAt: DateTime.now(),
      expiresAt: ttl != null ? DateTime.now().add(ttl) : null,
      sizeBytes: data.length,
      localPath: filePath,
      isPinned: pinned,
    );
    await _saveIndex();
  }

  Future<List<int>?> getCachedResource(String resourceId) async {
    final status = _cacheIndex[resourceId];
    if (status == null || !status.isValid) return null;

    final file = File(status.localPath ?? '');
    if (!await file.exists()) return null;

    // Update access stats
    _cacheIndex[resourceId] = status.copyWith(
      hitCount: status.hitCount + 1,
      lastAccessedAt: DateTime.now(),
    );
    await _saveIndex();

    return file.readAsBytes();
  }

  Future<bool> isCached(String resourceId) async {
    final status = _cacheIndex[resourceId];
    if (status == null) return false;
    if (!status.isValid) return false;
    final file = File(status.localPath ?? '');
    return file.exists();
  }

  Future<void> removeCachedResource(String resourceId) async {
    final status = _cacheIndex[resourceId];
    if (status != null && status.localPath != null) {
      final file = File(status.localPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _cacheIndex.remove(resourceId);
    await _saveIndex();
  }

  Future<void> _evictIfNeeded(int additionalBytes) async {
    final totalSize = getTotalCacheSize();
    if (totalSize + additionalBytes <= maxCacheSizeBytes) return;

    // LRU eviction: sort by last accessed, remove oldest unpinned
    final entries = _cacheIndex.entries
        .where((e) => !e.value.isPinned)
        .toList()
      ..sort((a, b) {
        final aTime = a.value.lastAccessedAt ?? a.value.cachedAt;
        final bTime = b.value.lastAccessedAt ?? b.value.cachedAt;
        return aTime.compareTo(bTime);
      });

    var freedBytes = 0;
    final needed = totalSize + additionalBytes - maxCacheSizeBytes;
    for (final entry in entries) {
      if (freedBytes >= needed) break;
      final status = entry.value;
      if (status.localPath != null) {
        final file = File(status.localPath!);
        if (await file.exists()) {
          await file.delete();
          freedBytes += status.sizeBytes;
        }
      }
      _cacheIndex.remove(entry.key);
    }
    await _saveIndex();
  }

  int getTotalCacheSize() {
    return _cacheIndex.values.fold<int>(0, (sum, s) => sum + s.sizeBytes);
  }

  int getCachedItemCount() => _cacheIndex.length;

  Future<void> clearAll() async {
    for (final status in _cacheIndex.values) {
      if (status.localPath != null) {
        final file = File(status.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    _cacheIndex.clear();
    await _saveIndex();
  }

  List<CacheStatus> getAllCachedResources() =>
      _cacheIndex.values.toList();

  Future<void> pinResource(String resourceId) async {
    final status = _cacheIndex[resourceId];
    if (status != null) {
      _cacheIndex[resourceId] = status.copyWith(isPinned: true);
      await _saveIndex();
    }
  }

  Future<void> unpinResource(String resourceId) async {
    final status = _cacheIndex[resourceId];
    if (status != null) {
      _cacheIndex[resourceId] = status.copyWith(isPinned: false);
      await _saveIndex();
    }
  }
}

// ============================================================================
// Task Queue
// ============================================================================

class TaskQueue {
  final List<QueuedTask> _tasks = [];
  final String _persistPath;
  final StreamController<QueuedTask> _taskUpdates =
      StreamController<QueuedTask>.broadcast();
  final StreamController<List<QueuedTask>> _queueUpdates =
      StreamController<List<QueuedTask>>.broadcast();
  bool _isProcessing = false;

  Stream<QueuedTask> get taskUpdates => _taskUpdates.stream;
  Stream<List<QueuedTask>> get queueUpdates => _queueUpdates.stream;
  List<QueuedTask> get pendingTasks =>
      _tasks.where((t) => t.status == QueuedTaskStatus.pending).toList();
  List<QueuedTask> get allTasks => List.unmodifiable(_tasks);
  int get length => _tasks.length;
  bool get isEmpty => _tasks.isEmpty;
  bool get isNotEmpty => _tasks.isNotEmpty;

  TaskQueue({required String persistPath}) : _persistPath = persistPath;

  Future<void> initialize() async {
    await _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    final file = File(_persistPath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final data = jsonDecode(content) as List<dynamic>;
        _tasks.clear();
        for (final item in data) {
          _tasks.add(QueuedTask.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {
        _tasks.clear();
      }
    }
  }

  Future<void> _saveToDisk() async {
    final file = File(_persistPath);
    final data = _tasks.map((t) => t.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  Future<String> enqueue({
    required String taskType,
    required String description,
    required Map<String, dynamic> payload,
    TaskPriority priority = TaskPriority.normal,
    bool requiresNetwork = false,
    List<String> dependencies = const [],
    String? groupId,
    ConflictResolution conflictResolution = ConflictResolution.localWins,
  }) async {
    final task = QueuedTask(
      id: _generateId(),
      taskType: taskType,
      description: description,
      payload: payload,
      priority: priority,
      status: QueuedTaskStatus.pending,
      createdAt: DateTime.now(),
      requiresNetwork: requiresNetwork,
      dependencies: dependencies,
      groupId: groupId,
      conflictResolution: conflictResolution,
    );
    _tasks.add(task);
    await _saveToDisk();
    _taskUpdates.add(task);
    _notifyQueueUpdate();
    return task.id;
  }

  Future<void> updateTaskStatus(String taskId, QueuedTaskStatus status,
      {String? error, String? result}) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    _tasks[index] = _tasks[index].copyWith(
      status: status,
      errorMessage: error,
      resultJson: result,
      startedAt: status == QueuedTaskStatus.running ? DateTime.now() : null,
      completedAt: status == QueuedTaskStatus.completed ||
              status == QueuedTaskStatus.failed
          ? DateTime.now()
          : null,
    );
    await _saveToDisk();
    _taskUpdates.add(_tasks[index]);
    _notifyQueueUpdate();
  }

  Future<QueuedTask?> getNextPendingTask({bool networkAvailable = false}) async {
    final candidates = _tasks
        .where((t) => t.status == QueuedTaskStatus.pending)
        .where((t) => !t.requiresNetwork || networkAvailable)
        .where((t) => _areDependenciesMet(t))
        .toList();

    if (candidates.isEmpty) return null;

    // Sort by priority (critical first)
    candidates.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return candidates.first;
  }

  bool _areDependenciesMet(QueuedTask task) {
    for (final depId in task.dependencies) {
      final dep = _tasks.where((t) => t.id == depId).firstOrNull;
      if (dep == null || dep.status != QueuedTaskStatus.completed) {
        return false;
      }
    }
    return true;
  }

  Future<void> removeTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    await _saveToDisk();
    _notifyQueueUpdate();
  }

  Future<void> clearCompleted() async {
    _tasks.removeWhere((t) => t.isTerminal);
    await _saveToDisk();
    _notifyQueueUpdate();
  }

  Future<void> cancelAll() async {
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].status == QueuedTaskStatus.pending) {
        _tasks[i] = _tasks[i].copyWith(status: QueuedTaskStatus.cancelled);
      }
    }
    await _saveToDisk();
    _notifyQueueUpdate();
  }

  int getPendingCount() =>
      _tasks.where((t) => t.status == QueuedTaskStatus.pending).length;

  int getNetworkDependentCount() =>
      _tasks.where((t) => t.requiresNetwork && t.isPending).length;

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return 'task_${now}_$rand';
  }

  void _notifyQueueUpdate() {
    _queueUpdates.add(List.unmodifiable(_tasks));
  }

  Future<void> dispose() async {
    await _taskUpdates.close();
    await _queueUpdates.close();
  }
}

// ============================================================================
// Main OfflineService
// ============================================================================

class OfflineService {
  final String dataDir;
  final SyncPolicy syncPolicy;

  late final NetworkMonitor _networkMonitor;
  late final CacheManager _cacheManager;
  late final TaskQueue _taskQueue;

  OfflineState _state = const OfflineState(
    networkStatus: NetworkStatus.unknown,
    networkType: NetworkType.none,
    isOffline: true,
  );

  final StreamController<OfflineState> _stateController =
      StreamController<OfflineState>.broadcast();
  final StreamController<SyncResult> _syncResultController =
      StreamController<SyncResult>.broadcast();
  final StreamController<String> _notificationController =
      StreamController<String>.broadcast();

  Stream<OfflineState> get stateStream => _stateController.stream;
  Stream<SyncResult> get syncResultStream => _syncResultController.stream;
  Stream<String> get notifications => _notificationController.stream;
  OfflineState get state => _state;
  NetworkMonitor get networkMonitor => _networkMonitor;
  CacheManager get cacheManager => _cacheManager;
  TaskQueue get taskQueue => _taskQueue;

  // Capability matrix
  static const Map<String, OfflineCapability> _capabilities = {
    'local_model_chat': OfflineCapability(
      featureName: 'local_model_chat',
      displayName: 'Local Model Chat',
      description: 'Converse with local AI models - fully offline',
      onlineLevel: CapabilityLevel.full,
      offlineLevel: CapabilityLevel.full,
    ),
    'memory_retrieval': OfflineCapability(
      featureName: 'memory_retrieval',
      displayName: 'Memory Retrieval',
      description: 'Search local vector database - fully offline',
      onlineLevel: CapabilityLevel.full,
      offlineLevel: CapabilityLevel.full,
    ),
    'history_browse': OfflineCapability(
      featureName: 'history_browse',
      displayName: 'History Browse',
      description: 'View conversation history - fully offline',
      onlineLevel: CapabilityLevel.full,
      offlineLevel: CapabilityLevel.full,
    ),
    'local_skill_execution': OfflineCapability(
      featureName: 'local_skill_execution',
      displayName: 'Local Skill Execution',
      description: 'Run code sandbox, charts, document generation locally',
      onlineLevel: CapabilityLevel.full,
      offlineLevel: CapabilityLevel.full,
    ),
    'web_search': OfflineCapability(
      featureName: 'web_search',
      displayName: 'Web Search',
      description: 'Search the internet - requires network',
      onlineLevel: CapabilityLevel.full,
      offlineLevel: CapabilityLevel.unavailable,
      requiresNetwork: true,
    ),
    'cloud_image_gen': OfflineCapability(
      featureName: 'cloud_image_gen',
      displayName: 'Cloud Image Generation',
      description: 'Generate images with cloud models - requires network',
      onlineLevel: CapabilityLevel.full,
      offlineLevel: CapabilityLevel.unavailable,
      requiresNetwork: true,
    ),
    'cloud_model_chat': OfflineCapability(
      featureName: 'cloud_model_chat',
      displayName: 'Cloud Model Chat',
      description: 'Chat with cloud-hosted models - requires network',
      onlineLevel: CapabilityLevel.full,
      offlineLevel: CapabilityLevel.unavailable,
      requiresNetwork: true,
    ),
    'real_time_data': OfflineCapability(
      featureName: 'real_time_data',
      displayName: 'Real-time Data',
      description: 'Stock prices, weather, news - requires network',
      onlineLevel: CapabilityLevel.full,
      offlineLevel: CapabilityLevel.unavailable,
      requiresNetwork: true,
    ),
    'cached_web_search': OfflineCapability(
      featureName: 'cached_web_search',
      displayName: 'Cached Web Search',
      description: 'Browse previously cached web results',
      onlineLevel: CapabilityLevel.full,
      offlineLevel: CapabilityLevel.degraded,
    ),
  };

  OfflineService({
    required this.dataDir,
    this.syncPolicy = SyncPolicy.wifiOnly,
  });

  // --------------------------------------------------------------------------
  // Initialization
  // --------------------------------------------------------------------------

  Future<void> initialize() async {
    // Initialize sub-components
    _networkMonitor = NetworkMonitor();
    _cacheManager = CacheManager(
      cacheDir: '$dataDir/offline_cache',
    );
    _taskQueue = TaskQueue(
      persistPath: '$dataDir/offline_queue.json',
    );

    await _networkMonitor.initialize();
    await _cacheManager.initialize();
    await _taskQueue.initialize();

    // Listen to network changes
    _networkMonitor.statusStream.listen(_onNetworkStatusChanged);

    // Initial state update
    _updateState();

    // Pre-cache common data
    await _preCacheCommonData();

    // Start task processing if online
    if (_networkMonitor.isConnected) {
      await _processQueue(networkAvailable: true);
    }
  }

  // --------------------------------------------------------------------------
  // Network Status Handling
  // --------------------------------------------------------------------------

  Future<void> _onNetworkStatusChanged(NetworkStatus status) async {
    final wasOffline = _state.isOffline;
    final isNowOnline = status == NetworkStatus.connected;

    _state = _state.copyWith(
      networkStatus: status,
      networkType: _networkMonitor.type,
      isOffline: !isNowOnline,
      lastConnectedAt: isNowOnline ? DateTime.now() : _state.lastConnectedAt,
    );
    _updateState();

    if (wasOffline && isNowOnline) {
      // Just came online - trigger sync
      _notificationController.add('Network reconnected. Starting sync...');
      await _handleReconnection();
    } else if (!wasOffline && !isNowOnline) {
      // Just went offline
      _notificationController.add('You are now offline. Some features are limited.');
    }
  }

  Future<void> _handleReconnection() async {
    if (!_shouldSync()) return;

    final result = await syncNow();
    _syncResultController.add(result);

    if (result.isCompleteSuccess) {
      _notificationController.add(
          'Sync complete: ${result.tasksProcessed} tasks processed.');
    } else {
      _notificationController.add(
          'Sync completed with ${result.tasksFailed} errors.');
    }
  }

  bool _shouldSync() {
    switch (syncPolicy) {
      case SyncPolicy.always:
        return true;
      case SyncPolicy.wifiOnly:
        return _networkMonitor.type == NetworkType.wifi;
      case SyncPolicy.manual:
        return false;
    }
  }

  // --------------------------------------------------------------------------
  // Capability Matrix
  // --------------------------------------------------------------------------

  Map<String, CapabilityLevel> getCapabilityMatrix() {
    final isOffline = _state.isOffline;
    return _capabilities.map((key, cap) {
      final level = isOffline ? cap.offlineLevel : cap.onlineLevel;
      return MapEntry(key, level);
    });
  }

  CapabilityLevel getCapabilityLevel(String featureName) {
    final cap = _capabilities[featureName];
    if (cap == null) return CapabilityLevel.unavailable;
    return _state.isOffline ? cap.offlineLevel : cap.onlineLevel;
  }

  List<String> getAvailableFeatures() {
    return getCapabilityMatrix()
        .entries
        .where((e) => e.value != CapabilityLevel.unavailable)
        .map((e) => e.key)
        .toList();
  }

  List<String> getUnavailableFeatures() {
    return getCapabilityMatrix()
        .entries
        .where((e) => e.value == CapabilityLevel.unavailable)
        .map((e) => e.key)
        .toList();
  }

  List<String> getDegradedFeatures() {
    return getCapabilityMatrix()
        .entries
        .where((e) => e.value == CapabilityLevel.degraded)
        .map((e) => e.key)
        .toList();
  }

  // --------------------------------------------------------------------------
  // Offline Queue Management
  // --------------------------------------------------------------------------

  Future<String> queueTask({
    required String taskType,
    required String description,
    required Map<String, dynamic> payload,
    TaskPriority priority = TaskPriority.normal,
    List<String> dependencies = const [],
    String? groupId,
  }) async {
    final requiresNetwork = _taskRequiresNetwork(taskType);
    return _taskQueue.enqueue(
      taskType: taskType,
      description: description,
      payload: payload,
      priority: priority,
      requiresNetwork: requiresNetwork,
      dependencies: dependencies,
      groupId: groupId,
    );
  }

  bool _taskRequiresNetwork(String taskType) {
    const networkTasks = {
      'web_search',
      'cloud_chat',
      'cloud_image_gen',
      'cloud_tts',
      'sync_contacts',
      'fetch_news',
      'stock_data',
      'weather_update',
    };
    return networkTasks.contains(taskType);
  }

  Future<void> cancelTask(String taskId) async {
    await _taskQueue.updateTaskStatus(taskId, QueuedTaskStatus.cancelled);
  }

  Future<void> retryTask(String taskId) async {
    final task = _taskQueue.allTasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw ArgumentError('Task not found: $taskId'),
    );
    if (task.retryCount >= task.maxRetries) {
      throw StateError('Max retries exceeded for task: $taskId');
    }
    await _taskQueue.updateTaskStatus(
      taskId,
      QueuedTaskStatus.pending,
    );
  }

  // --------------------------------------------------------------------------
  // Sync Engine
  // --------------------------------------------------------------------------

  Future<SyncResult> syncNow() async {
    if (_state.isOffline) {
      throw StateError('Cannot sync while offline');
    }

    final startTime = DateTime.now();
    var tasksProcessed = 0;
    var tasksFailed = 0;
    var conflictsResolved = 0;
    var dataItemsSynced = 0;
    final errors = <String>[];

    _state = _state.copyWith(isSyncing: true, syncProgress: 0.0);
    _updateState();

    // Process queued tasks that need network
    while (true) {
      final task = await _taskQueue.getNextPendingTask(networkAvailable: true);
      if (task == null) break;

      try {
        await _taskQueue.updateTaskStatus(
            task.id, QueuedTaskStatus.running);

        final result = await _executeTask(task);
        await _taskQueue.updateTaskStatus(
          task.id,
          QueuedTaskStatus.completed,
          result: jsonEncode(result),
        );
        tasksProcessed++;
      } catch (e) {
        tasksFailed++;
        errors.add('${task.id}: ${e.toString()}');

        if (task.isRetryable) {
          await _taskQueue.updateTaskStatus(
            task.id,
            QueuedTaskStatus.pending,
          );
          // Increment retry count by replacing the task
        } else {
          await _taskQueue.updateTaskStatus(
            task.id,
            QueuedTaskStatus.failed,
            error: e.toString(),
          );
        }
      }

      // Update progress
      final total = _taskQueue.getPendingCount() + tasksProcessed;
      _state = _state.copyWith(
        syncProgress: total > 0 ? tasksProcessed / total : 1.0,
      );
      _updateState();
    }

    // Sync cached data
    dataItemsSynced = await _syncCachedData();

    final duration = DateTime.now().difference(startTime);
    _state = _state.copyWith(
      isSyncing: false,
      syncProgress: 1.0,
      lastSyncedAt: DateTime.now(),
    );
    _updateState();

    return SyncResult(
      tasksProcessed: tasksProcessed,
      tasksFailed: tasksFailed,
      conflictsResolved: conflictsResolved,
      dataItemsSynced: dataItemsSynced,
      duration: duration,
      errors: errors,
      completedAt: DateTime.now(),
    );
  }

  Future<Map<String, dynamic>> _executeTask(QueuedTask task) async {
    // Simulate task execution based on type
    switch (task.taskType) {
      case 'web_search':
        await Future.delayed(const Duration(milliseconds: 500));
        return {'status': 'searched', 'query': task.payload['query']};
      case 'cloud_chat':
        await Future.delayed(const Duration(seconds: 1));
        return {'status': 'responded', 'model': task.payload['model']};
      case 'cloud_image_gen':
        await Future.delayed(const Duration(seconds: 2));
        return {'status': 'generated', 'prompt': task.payload['prompt']};
      case 'sync_contacts':
        await Future.delayed(const Duration(milliseconds: 300));
        return {'status': 'synced'};
      default:
        await Future.delayed(const Duration(milliseconds: 100));
        return {'status': 'completed', 'type': task.taskType};
    }
  }

  Future<int> _syncCachedData() async {
    // Sync locally cached data with remote
    var synced = 0;
    final resources = _cacheManager.getAllCachedResources();
    for (final resource in resources) {
      if (resource.resourceType == 'conversation' && !resource.isPinned) {
        // Would upload to server in production
        synced++;
      }
    }
    return synced;
  }

  // --------------------------------------------------------------------------
  // Pre-Caching
  // --------------------------------------------------------------------------

  Future<void> _preCacheCommonData() async {
    // Pre-cache is handled on-demand; this sets up initial state
  }

  Future<void> preCacheConversation(String conversationId, String data) async {
    await _cacheManager.cacheResource(
      resourceId: 'conv_$conversationId',
      resourceType: 'conversation',
      data: utf8.encode(data),
      strategy: CacheStrategy.ttl,
      ttl: const Duration(days: 7),
      pinned: true,
    );
  }

  Future<void> preCacheModelWeights(String modelId, List<int> data) async {
    await _cacheManager.cacheResource(
      resourceId: 'model_$modelId',
      resourceType: 'model_weights',
      data: data,
      strategy: CacheStrategy.manual,
      pinned: true,
    );
  }

  Future<void> preCacheSkillResources(
      String skillId, Map<String, dynamic> resources) async {
    final data = utf8.encode(jsonEncode(resources));
    await _cacheManager.cacheResource(
      resourceId: 'skill_$skillId',
      resourceType: 'skill_resources',
      data: data,
      strategy: CacheStrategy.ttl,
      ttl: const Duration(days: 30),
      pinned: true,
    );
  }

  Future<String?> getCachedConversation(String conversationId) async {
    final data = await _cacheManager.getCachedResource('conv_$conversationId');
    if (data == null) return null;
    return utf8.decode(data);
  }

  // --------------------------------------------------------------------------
  // Process Queue (for offline-executable tasks)
  // --------------------------------------------------------------------------

  Future<void> _processQueue({bool networkAvailable = false}) async {
    while (true) {
      final task = await _taskQueue.getNextPendingTask(
        networkAvailable: networkAvailable,
      );
      if (task == null) break;

      if (task.requiresNetwork && !networkAvailable) {
        // Can't process network-dependent tasks while offline
        break;
      }

      try {
        await _taskQueue.updateTaskStatus(
            task.id, QueuedTaskStatus.running);
        final result = await _executeTask(task);
        await _taskQueue.updateTaskStatus(
          task.id,
          QueuedTaskStatus.completed,
          result: jsonEncode(result),
        );
      } catch (e) {
        await _taskQueue.updateTaskStatus(
          task.id,
          QueuedTaskStatus.failed,
          error: e.toString(),
        );
      }
    }
  }

  // --------------------------------------------------------------------------
  // State Helpers
  // --------------------------------------------------------------------------

  void _updateState() {
    _state = _state.copyWith(
      pendingTaskCount: _taskQueue.getPendingCount(),
      cachedItemCount: _cacheManager.getCachedItemCount(),
      totalCacheBytes: _cacheManager.getTotalCacheSize(),
      capabilityMatrix: getCapabilityMatrix(),
    );
    _stateController.add(_state);
  }

  String getOfflineStatusMessage() {
    if (!_state.isOffline) {
      return 'Online - All features available';
    }

    final available = getAvailableFeatures();
    final unavailable = getUnavailableFeatures();
    final degraded = getDegradedFeatures();

    final sb = StringBuffer('Offline Mode\n');
    sb.writeln('${available.length} features available locally');
    if (unavailable.isNotEmpty) {
      sb.writeln('${unavailable.length} features unavailable');
    }
    if (degraded.isNotEmpty) {
      sb.writeln('${degraded.length} features with limited functionality');
    }
    if (_state.pendingTaskCount > 0) {
      sb.writeln('${_state.pendingTaskCount} tasks queued for sync');
    }
    return sb.toString();
  }

  // --------------------------------------------------------------------------
  // Manual Sync Trigger
  // --------------------------------------------------------------------------

  Future<SyncResult> triggerManualSync() async {
    if (_state.isOffline) {
      throw StateError('Cannot sync while offline. Connect to a network first.');
    }
    return syncNow();
  }

  Future<void> setSyncPolicy(SyncPolicy policy) async {
    _state = _state.copyWith(syncPolicy: policy);
    _updateState();
  }

  // --------------------------------------------------------------------------
  // Cache Management Shortcuts
  // --------------------------------------------------------------------------

  Future<String> getCacheSummary() async {
    final totalSize = _cacheManager.getTotalCacheSize();
    final count = _cacheManager.getCachedItemCount();
    final formattedSize = _formatBytes(totalSize);
    return 'Cache: $count items, $formattedSize total';
  }

  Future<void> clearCache() async {
    await _cacheManager.clearAll();
    _updateState();
  }

  Future<void> clearQueue() async {
    await _taskQueue.cancelAll();
    await _taskQueue.clearCompleted();
    _updateState();
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(1)} GB';
    if (bytes >= 1e6) return '${(bytes / 1e6).toStringAsFixed(1)} MB';
    if (bytes >= 1e3) return '${(bytes / 1e3).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  // --------------------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------------------

  Future<void> dispose() async {
    await _networkMonitor.dispose();
    await _taskQueue.dispose();
    await _stateController.close();
    await _syncResultController.close();
    await _notificationController.close();
  }

  @override
  String toString() =>
      'OfflineService(offline=${_state.isOffline}, '
      'pending=${_state.pendingTaskCount}, '
      'cached=${_state.cachedItemCount})';
}
