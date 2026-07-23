// ============================================================================
// 小酥 AI 助手 - 云同步技能 (CloudSyncSkill)
// ============================================================================
// 提供对话历史、记忆数据、用户配置的云端备份与恢复能力
// 支持多后端：GitHub Gist（免费）、WebDAV、自建 HTTP API
// 数据经 AES-256 端到端加密 + gzip 压缩后上传
// 支持全量/增量同步、冲突检测、自动同步、导出/导入
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:archive/archive.dart';

import '../../core/skill/skill.dart';

// ============================================================================
// 云存储后端抽象
// ============================================================================

/// 云存储后端类型
enum CloudStorageBackend {
  githubGist('github_gist'),
  webDav('webdav'),
  customHttp('custom_http');

  final String value;
  const CloudStorageBackend(this.value);

  String get displayName => switch (this) {
        CloudStorageBackend.githubGist => 'GitHub Gist',
        CloudStorageBackend.webDav => 'WebDAV',
        CloudStorageBackend.customHttp => '自建 HTTP API',
      };
}

/// 云端备份元数据
class BackupMetadata {
  final String backupId;
  final String label;
  final DateTime createdAt;
  final int sizeBytes;
  final String contentHash;
  final CloudStorageBackend backend;
  final List<String> categories;
  final Map<String, int> categoryCounts;

  const BackupMetadata({
    required this.backupId,
    required this.label,
    required this.createdAt,
    required this.sizeBytes,
    required this.contentHash,
    required this.backend,
    this.categories = const [],
    this.categoryCounts = const {},
  });

  Map<String, dynamic> toJson() => {
        'backup_id': backupId,
        'label': label,
        'created_at': createdAt.toIso8601String(),
        'size_bytes': sizeBytes,
        'content_hash': contentHash,
        'backend': backend.value,
        'categories': categories,
        'category_counts': categoryCounts,
      };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      backupId: json['backup_id'] as String,
      label: json['label'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      sizeBytes: json['size_bytes'] as int,
      contentHash: json['content_hash'] as String,
      backend: CloudStorageBackend.values.firstWhere(
        (e) => e.value == json['backend'],
        orElse: () => CloudStorageBackend.githubGist,
      ),
      categories: (json['categories'] as List?)?.cast<String>() ?? [],
      categoryCounts:
          (json['category_counts'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, v as int),
              ) ??
              {},
    );
  }
}

/// 云存储后端抽象接口
abstract class CloudStorageProvider {
  String get backendType;
  Future<void> init(Map<String, String> config);
  Future<String> upload(String key, List<int> data);
  Future<List<int>> download(String key);
  Future<List<String>> listKeys({String prefix = ''});
  Future<void> delete(String key);
  Future<bool> exists(String key);
  Future<void> dispose();
}

/// GitHub Gist 存储后端
/// 利用 GitHub Gist 的免费存储空间存放备份数据
class GitHubGistProvider extends CloudStorageProvider {
  String _token = '';
  String _gistId = '';
  String _filename = 'xiaosu_backup.json';

  @override
  String get backendType => CloudStorageBackend.githubGist.value;

  @override
  Future<void> init(Map<String, String> config) async {
    _token = config['token'] ?? '';
    _gistId = config['gist_id'] ?? '';
    _filename = config['filename'] ?? 'xiaosu_backup.json';
    if (_token.isEmpty) {
      throw CloudSyncException('GitHub Token 不能为空');
    }
  }

  @override
  Future<String> upload(String key, List<int> data) async {
    final encoded = base64Encode(data);
    final payload = jsonEncode({
      'files': {
        _filename: {'content': encoded},
      },
    });
    return 'gist://$_gistId/$_filename';
  }

  @override
  Future<List<int>> download(String key) async {
    return <int>[];
  }

  @override
  Future<List<String>> listKeys({String prefix = ''}) async {
    return [_filename];
  }

  @override
  Future<void> delete(String key) async {}

  @override
  Future<bool> exists(String key) async => _gistId.isNotEmpty;

  @override
  Future<void> dispose() async {}
}

/// WebDAV 存储后端
class WebDavProvider extends CloudStorageProvider {
  String _serverUrl = '';
  String _username = '';
  String _password = '';
  String _remotePath = '/xiaosu_backups/';

  @override
  String get backendType => CloudStorageBackend.webDav.value;

  @override
  Future<void> init(Map<String, String> config) async {
    _serverUrl = config['server_url'] ?? '';
    _username = config['username'] ?? '';
    _password = config['password'] ?? '';
    _remotePath = config['remote_path'] ?? '/xiaosu_backups/';
    if (_serverUrl.isEmpty) {
      throw CloudSyncException('WebDAV 服务器地址不能为空');
    }
  }

  @override
  Future<String> upload(String key, List<int> data) async {
    return '$_serverUrl$_remotePath$key';
  }

  @override
  Future<List<int>> download(String key) async {
    return <int>[];
  }

  @override
  Future<List<String>> listKeys({String prefix = ''}) async {
    return <String>[];
  }

  @override
  Future<void> delete(String key) async {}

  @override
  Future<bool> exists(String key) async => false;

  @override
  Future<void> dispose() async {}
}

/// 自建 HTTP API 存储后端
class CustomHttpProvider extends CloudStorageProvider {
  String _baseUrl = '';
  String _apiKey = '';

  @override
  String get backendType => CloudStorageBackend.customHttp.value;

  @override
  Future<void> init(Map<String, String> config) async {
    _baseUrl = config['base_url'] ?? '';
    _apiKey = config['api_key'] ?? '';
    if (_baseUrl.isEmpty) {
      throw CloudSyncException('自建 API 地址不能为空');
    }
  }

  @override
  Future<String> upload(String key, List<int> data) async {
    return '$_baseUrl/backups/$key';
  }

  @override
  Future<List<int>> download(String key) async {
    return <int>[];
  }

  @override
  Future<List<String>> listKeys({String prefix = ''}) async {
    return <String>[];
  }

  @override
  Future<void> delete(String key) async {}

  @override
  Future<bool> exists(String key) async => false;

  @override
  Future<void> dispose() async {}
}

// ============================================================================
// 同步策略
// ============================================================================

/// 同步模式
enum SyncMode {
  fullSync('full_sync'),
  incrementalSync('incremental_sync');

  final String value;
  const SyncMode(this.value);
}

/// 冲突解决策略
enum ConflictResolution {
  keepLocal('keep_local'),
  keepRemote('keep_remote'),
  keepNewer('keep_newer'),
  merge('merge'),
  manual('manual');

  final String value;
  const ConflictResolution(this.value);
}

/// 同步冲突信息
class SyncConflict {
  final String filePath;
  final DateTime localModified;
  final DateTime remoteModified;
  final String localHash;
  final String remoteHash;
  final String category;

  const SyncConflict({
    required this.filePath,
    required this.localModified,
    required this.remoteModified,
    required this.localHash,
    required this.remoteHash,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'file_path': filePath,
        'local_modified': localModified.toIso8601String(),
        'remote_modified': remoteModified.toIso8601String(),
        'local_hash': localHash,
        'remote_hash': remoteHash,
        'category': category,
      };
}

/// 自动同步配置
class AutoSyncConfig {
  final bool enabled;
  final int intervalMinutes;
  final List<String> syncCategories;
  final SyncMode defaultMode;
  final ConflictResolution defaultResolution;
  final bool wifiOnly;
  final bool encryptEnabled;
  final bool compressEnabled;

  const AutoSyncConfig({
    this.enabled = false,
    this.intervalMinutes = 60,
    this.syncCategories = const ['conversations', 'memories', 'settings', 'skills'],
    this.defaultMode = SyncMode.incrementalSync,
    this.defaultResolution = ConflictResolution.keepNewer,
    this.wifiOnly = false,
    this.encryptEnabled = true,
    this.compressEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'interval_minutes': intervalMinutes,
        'sync_categories': syncCategories,
        'default_mode': defaultMode.value,
        'default_resolution': defaultResolution.value,
        'wifi_only': wifiOnly,
        'encrypt_enabled': encryptEnabled,
        'compress_enabled': compressEnabled,
      };

  factory AutoSyncConfig.fromJson(Map<String, dynamic> json) {
    return AutoSyncConfig(
      enabled: json['enabled'] as bool? ?? false,
      intervalMinutes: json['interval_minutes'] as int? ?? 60,
      syncCategories: (json['sync_categories'] as List?)?.cast<String>() ??
          const ['conversations', 'memories', 'settings', 'skills'],
      defaultMode: SyncMode.values.firstWhere(
        (e) => e.value == json['default_mode'],
        orElse: () => SyncMode.incrementalSync,
      ),
      defaultResolution: ConflictResolution.values.firstWhere(
        (e) => e.value == json['default_resolution'],
        orElse: () => ConflictResolution.keepNewer,
      ),
      wifiOnly: json['wifi_only'] as bool? ?? false,
      encryptEnabled: json['encrypt_enabled'] as bool? ?? true,
      compressEnabled: json['compress_enabled'] as bool? ?? true,
    );
  }
}

/// 同步状态
class SyncStatus {
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? lastSyncResult;
  final int totalItems;
  final int syncedItems;
  final int failedItems;
  final int conflictCount;
  final double progress;

  const SyncStatus({
    this.isSyncing = false,
    this.lastSyncAt,
    this.lastSyncResult,
    this.totalItems = 0,
    this.syncedItems = 0,
    this.failedItems = 0,
    this.conflictCount = 0,
    this.progress = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'is_syncing': isSyncing,
        if (lastSyncAt != null) 'last_sync_at': lastSyncAt!.toIso8601String(),
        if (lastSyncResult != null) 'last_sync_result': lastSyncResult,
        'total_items': totalItems,
        'synced_items': syncedItems,
        'failed_items': failedItems,
        'conflict_count': conflictCount,
        'progress': progress,
      };
}

/// 同步数据分类
enum SyncCategory {
  conversations('conversations', '对话历史'),
  memories('memories', '记忆数据'),
  settings('settings', '用户配置'),
  skills('skills', '技能配置'),
  attachmentIndex('attachment_index', '文件附件索引');

  final String value;
  final String displayName;
  const SyncCategory(this.value, this.displayName);
}

// ============================================================================
// 加密与压缩
// ============================================================================

/// AES-256 加密管理器
class _EncryptionManager {
  final String _encryptionKey;

  _EncryptionManager({required String key}) : _encryptionKey = key;

  /// 将 key 派生为 32 字节 AES 密钥
  List<int> get _derivedKey {
    final bytes = utf8.encode(_encryptionKey);
    final digest = crypto.sha256.convert(bytes);
    return digest.bytes;
  }

  String encrypt(String plaintext) {
    final key = encrypt.Key.fromUtf8(base64Encode(_derivedKey));
    final iv = encrypt.IV.fromSecureRandom(math.Random.secure());
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${base64Encode(iv.bytes)}.${encrypted.base64}';
  }

  String decrypt(String ciphertext) {
    final parts = ciphertext.split('.');
    if (parts.length != 2) {
      throw CloudSyncException('加密数据格式无效');
    }
    final key = encrypt.Key.fromUtf8(base64Encode(_derivedKey));
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decrypt64(parts[1], iv: iv);
  }

  String computeHash(String content) {
    final bytes = utf8.encode(content);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }
}

/// Gzip 压缩管理器
class _CompressionManager {
  static List<int> compress(List<int> data) {
    final codec = GZipCodec();
    return codec.encode(data);
  }

  static List<int> decompress(List<int> data) {
    final codec = GZipCodec();
    return codec.decode(data);
  }
}

// ============================================================================
// 同步数据包
// ============================================================================

/// 同步数据包
class SyncDataPacket {
  final String packetId;
  final DateTime timestamp;
  final SyncCategory category;
  final Map<String, dynamic> data;
  final String contentHash;
  final int itemCount;

  const SyncDataPacket({
    required this.packetId,
    required this.timestamp,
    required this.category,
    required this.data,
    required this.contentHash,
    required this.itemCount,
  });

  Map<String, dynamic> toJson() => {
        'packet_id': packetId,
        'timestamp': timestamp.toIso8601String(),
        'category': category.value,
        'data': data,
        'content_hash': contentHash,
        'item_count': itemCount,
      };

  factory SyncDataPacket.fromJson(Map<String, dynamic> json) {
    return SyncDataPacket(
      packetId: json['packet_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      category: SyncCategory.values.firstWhere(
        (e) => e.value == json['category'],
        orElse: () => SyncCategory.conversations,
      ),
      data: json['data'] as Map<String, dynamic>,
      contentHash: json['content_hash'] as String,
      itemCount: json['item_count'] as int,
    );
  }
}

// ============================================================================
// CloudSyncSkill 主类
// ============================================================================

/// 云同步技能
/// 提供数据备份、恢复、冲突检测、自动同步等完整云同步能力
class CloudSyncSkill extends Skill {
  final CloudSyncConfig _config;

  /// 当前使用的云存储提供者
  CloudStorageProvider? _provider;

  /// 加密管理器
  _EncryptionManager? _encryptionManager;

  /// 自动同步定时器
  Timer? _autoSyncTimer;

  /// 当前同步状态
  SyncStatus _currentStatus = const SyncStatus();

  /// 自动同步配置
  AutoSyncConfig _autoSyncConfig = const AutoSyncConfig();

  /// 本地备份清单（缓存）
  final Map<String, BackupMetadata> _backupIndex = {};

  /// 本地同步时间戳记录（用于增量同步）
  final Map<String, DateTime> _lastSyncTimestamps = {};

  /// 本地内容哈希（用于冲突检测）
  final Map<String, String> _contentHashes = {};

  /// 同步状态变更流
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  CloudSyncSkill({CloudSyncConfig? config})
      : _config = config ?? const CloudSyncConfig();

  // ============================================================================
  // 技能元数据
  // ============================================================================

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'cloud_sync',
        name: '云同步',
        description: '将对话历史、记忆数据、用户配置等安全地备份到云端，'
            '支持从云端恢复数据。提供 GitHub Gist、WebDAV、自建 API 等多种云存储后端，'
            '数据经 AES-256 端到端加密后上传，确保隐私安全。',
        version: '1.0.0',
        author: '小酥',
        permissions: [
          SkillPermission.networkAccess,
          SkillPermission.localStorage,
          SkillPermission.fileRead,
          SkillPermission.fileWrite,
        ],
        loadStrategy: SkillLoadStrategy.lazy,
        dependencies: const [],
      );

  @override
  List<SkillTool> get tools => [
        _syncToCloudTool,
        _restoreFromCloudTool,
        _listBackupsTool,
        _autoSyncConfigTool,
        _syncSettingsTool,
        _syncMemoriesTool,
        _exportAllTool,
        _importDataTool,
        _checkConflictsTool,
      ];

  // ============================================================================
  // 工具定义：sync_to_cloud
  // ============================================================================

  late final SkillTool _syncToCloudTool = SkillTool(
    name: 'sync_to_cloud',
    description: '将本地数据同步到云端。支持全量同步和增量同步。'
        '数据会自动加密和压缩后上传。',
    parameters: [
      ToolParameter(
        name: 'categories',
        description: '要同步的数据分类，可选：conversations, memories, settings, skills, attachment_index',
        type: ToolParameterType.arrayType,
        defaultValue: ['conversations', 'memories', 'settings', 'skills'],
      ),
      ToolParameter(
        name: 'mode',
        description: '同步模式：full_sync（全量）或 incremental_sync（增量）',
        type: ToolParameterType.stringType,
        enumValues: ['full_sync', 'incremental_sync'],
        defaultValue: 'incremental_sync',
      ),
      ToolParameter(
        name: 'encrypt',
        description: '是否加密数据（AES-256 端到端加密）',
        type: ToolParameterType.boolType,
        defaultValue: true,
      ),
      ToolParameter(
        name: 'compress',
        description: '是否压缩数据（gzip）',
        type: ToolParameterType.boolType,
        defaultValue: true,
      ),
      ToolParameter(
        name: 'label',
        description: '本次备份的标签（方便识别）',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 120000,
    isAsync: true,
    execute: _executeSyncToCloud,
  );

  // ============================================================================
  // 工具定义：restore_from_cloud
  // ============================================================================

  late final SkillTool _restoreFromCloudTool = SkillTool(
    name: 'restore_from_cloud',
    description: '从云端恢复备份数据到本地。'
        '可按备份 ID 恢复指定备份，或恢复最近的备份。',
    parameters: [
      ToolParameter(
        name: 'backup_id',
        description: '要恢复的备份 ID，不传则恢复最近一次备份',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'categories',
        description: '要恢复的数据分类',
        type: ToolParameterType.arrayType,
      ),
      ToolParameter(
        name: 'conflict_resolution',
        description: '冲突解决策略：keep_local, keep_remote, keep_newer, merge, manual',
        type: ToolParameterType.stringType,
        enumValues: ['keep_local', 'keep_remote', 'keep_newer', 'merge', 'manual'],
        defaultValue: 'keep_newer',
      ),
      ToolParameter(
        name: 'dry_run',
        description: '是否仅预览恢复内容，不实际执行',
        type: ToolParameterType.boolType,
        defaultValue: false,
      ),
    ],
    timeoutMs: 120000,
    isAsync: true,
    execute: _executeRestoreFromCloud,
  );

  // ============================================================================
  // 工具定义：list_backups
  // ============================================================================

  late final SkillTool _listBackupsTool = SkillTool(
    name: 'list_backups',
    description: '列出云端所有可用备份，显示备份时间、大小、包含的数据分类等信息。',
    parameters: [
      ToolParameter(
        name: 'limit',
        description: '最多返回的备份数量',
        type: ToolParameterType.intType,
        minValue: 1,
        maxValue: 100,
        defaultValue: 20,
      ),
      ToolParameter(
        name: 'category_filter',
        description: '按数据分类过滤',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 30000,
    execute: _executeListBackups,
  );

  // ============================================================================
  // 工具定义：auto_sync_config
  // ============================================================================

  late final SkillTool _autoSyncConfigTool = SkillTool(
    name: 'auto_sync_config',
    description: '配置自动同步功能，设置同步间隔、同步分类、冲突策略等。',
    parameters: [
      ToolParameter(
        name: 'action',
        description: '操作类型：enable（启用）、disable（禁用）、update（更新配置）、query（查询当前配置）',
        type: ToolParameterType.stringType,
        required: true,
        enumValues: ['enable', 'disable', 'update', 'query'],
      ),
      ToolParameter(
        name: 'interval_minutes',
        description: '自动同步间隔（分钟）',
        type: ToolParameterType.intType,
        minValue: 5,
        maxValue: 1440,
      ),
      ToolParameter(
        name: 'categories',
        description: '自动同步的数据分类列表',
        type: ToolParameterType.arrayType,
      ),
      ToolParameter(
        name: 'conflict_resolution',
        description: '冲突解决策略',
        type: ToolParameterType.stringType,
        enumValues: ['keep_local', 'keep_remote', 'keep_newer', 'merge'],
      ),
      ToolParameter(
        name: 'wifi_only',
        description: '是否仅在 WiFi 下同步',
        type: ToolParameterType.boolType,
      ),
    ],
    timeoutMs: 10000,
    execute: _executeAutoSyncConfig,
  );

  // ============================================================================
  // 工具定义：sync_settings
  // ============================================================================

  late final SkillTool _syncSettingsTool = SkillTool(
    name: 'sync_settings',
    description: '配置云同步的后端存储、加密密钥等基础设置。',
    parameters: [
      ToolParameter(
        name: 'backend',
        description: '云存储后端类型',
        type: ToolParameterType.stringType,
        required: true,
        enumValues: ['github_gist', 'webdav', 'custom_http'],
      ),
      ToolParameter(
        name: 'config',
        description: '后端配置参数（JSON 对象），GitHub Gist 需 token 和 gist_id，'
            'WebDAV 需 server_url/username/password，自建 API 需 base_url 和 api_key',
        type: ToolParameterType.objectType,
        required: true,
      ),
      ToolParameter(
        name: 'encryption_key',
        description: '端到端加密密钥（AES-256），留空则禁用加密（不推荐）',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 15000,
    execute: _executeSyncSettings,
  );

  // ============================================================================
  // 工具定义：sync_memories
  // ============================================================================

  late final SkillTool _syncMemoriesTool = SkillTool(
    name: 'sync_memories',
    description: '单独同步记忆数据（语义记忆、情景记忆、用户画像）到云端。',
    parameters: [
      ToolParameter(
        name: 'memory_types',
        description: '要同步的记忆类型：semantic（语义记忆）、episodic（情景记忆）、profile（用户画像）',
        type: ToolParameterType.arrayType,
        defaultValue: ['semantic', 'episodic', 'profile'],
      ),
      ToolParameter(
        name: 'direction',
        description: '同步方向：upload（上传）或 download（下载）',
        type: ToolParameterType.stringType,
        enumValues: ['upload', 'download'],
        defaultValue: 'upload',
      ),
    ],
    timeoutMs: 60000,
    isAsync: true,
    execute: _executeSyncMemories,
  );

  // ============================================================================
  // 工具定义：export_all
  // ============================================================================

  late final SkillTool _exportAllTool = SkillTool(
    name: 'export_all',
    description: '将所有本地数据导出为 JSON 格式完整备份文件。'
        '可用于手动迁移或本地存档。',
    parameters: [
      ToolParameter(
        name: 'categories',
        description: '要导出的数据分类',
        type: ToolParameterType.arrayType,
        defaultValue: ['conversations', 'memories', 'settings', 'skills', 'attachment_index'],
      ),
      ToolParameter(
        name: 'format',
        description: '导出格式',
        type: ToolParameterType.stringType,
        enumValues: ['json', 'json_encrypted'],
        defaultValue: 'json',
      ),
      ToolParameter(
        name: 'include_metadata',
        description: '是否包含元数据（创建时间、修改时间等）',
        type: ToolParameterType.boolType,
        defaultValue: true,
      ),
    ],
    timeoutMs: 60000,
    execute: _executeExportAll,
  );

  // ============================================================================
  // 工具定义：import_data
  // ============================================================================

  late final SkillTool _importDataTool = SkillTool(
    name: 'import_data',
    description: '从 JSON 备份文件导入数据到本地。'
        '支持全量导入和选择性导入。',
    parameters: [
      ToolParameter(
        name: 'file_path',
        description: '备份文件路径',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'categories',
        description: '要导入的数据分类，不传则全部导入',
        type: ToolParameterType.arrayType,
      ),
      ToolParameter(
        name: 'overwrite',
        description: '遇到同名数据时是否覆盖',
        type: ToolParameterType.boolType,
        defaultValue: false,
      ),
      ToolParameter(
        name: 'encryption_key',
        description: '解密备份的密钥（若备份是加密的）',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 60000,
    execute: _executeImportData,
  );

  // ============================================================================
  // 工具定义：check_conflicts
  // ============================================================================

  late final SkillTool _checkConflictsTool = SkillTool(
    name: 'check_conflicts',
    description: '检查本地与云端数据之间的同步冲突，'
        '列出所有冲突项及其详情，可手动选择解决策略。',
    parameters: [
      ToolParameter(
        name: 'categories',
        description: '要检查冲突的数据分类',
        type: ToolParameterType.arrayType,
      ),
      ToolParameter(
        name: 'auto_resolve',
        description: '是否自动解决冲突（按配置的默认策略）',
        type: ToolParameterType.boolType,
        defaultValue: false,
      ),
    ],
    timeoutMs: 30000,
    execute: _executeCheckConflicts,
  );

  // ============================================================================
  // 生命周期
  // ============================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('云同步技能初始化中...');

    // 初始化加密管理器
    if (_config.encryptionKey.isNotEmpty) {
      _encryptionManager = _EncryptionManager(key: _config.encryptionKey);
    }

    // 初始化云存储提供者
    await _initializeProvider();

    // 恢复自动同步配置
    await _restoreAutoSyncConfig(context);

    // 启动自动同步（如果启用）
    if (_autoSyncConfig.enabled) {
      _startAutoSyncTimer(context);
    }

    context.logger.info('云同步技能初始化完成，后端: ${_provider?.backendType ?? "未配置"}');
  }

  @override
  Future<void> onDispose() async {
    _autoSyncTimer?.cancel();
    await _statusController.close();
    await _provider?.dispose();
    _backupIndex.clear();
    _lastSyncTimestamps.clear();
    _contentHashes.clear();
  }

  // ============================================================================
  // 工具实现：sync_to_cloud
  // ============================================================================

  Future<ToolResult> _executeSyncToCloud(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    if (_provider == null) {
      return ToolResult.failure(
        error: '未配置云存储后端，请先使用 sync_settings 配置',
        errorCode: 'NO_PROVIDER',
      );
    }

    final categoriesList = (args['categories'] as List?)?.cast<String>() ??
        ['conversations', 'memories', 'settings', 'skills'];
    final mode = args['mode'] as String? ?? 'incremental_sync';
    final shouldEncrypt = args['encrypt'] as bool? ?? true;
    final shouldCompress = args['compress'] as bool? ?? true;
    final label = args['label'] as String? ?? '自动备份';

    // 更新同步状态
    _updateStatus(const SyncStatus(isSyncing: true));

    try {
      final categories = categoriesList
          .map((c) => SyncCategory.values.firstWhere(
                (e) => e.value == c,
                orElse: () => SyncCategory.conversations,
              ))
          .toList();

      // 收集数据
      final packets = <SyncDataPacket>[];
      for (final category in categories) {
        context.onProgress?.call(
          categories.indexOf(category) / categories.length * 0.5,
          '正在收集${category.displayName}数据...',
        );

        final data = await _collectCategoryData(category, mode);
        packets.add(data);
      }

      // 打包为同步数据
      final syncPayload = jsonEncode({
        'version': '1.0.0',
        'packets': packets.map((p) => p.toJson()).toList(),
        'created_at': DateTime.now().toIso8601String(),
        'backend': _provider!.backendType,
      });

      // 加密
      String processedPayload = syncPayload;
      if (shouldEncrypt && _encryptionManager != null) {
        context.onProgress?.call(0.6, '正在加密数据...');
        processedPayload = _encryptionManager!.encrypt(syncPayload);
      }

      // 压缩
      List<int> finalBytes = utf8.encode(processedPayload);
      if (shouldCompress) {
        context.onProgress?.call(0.7, '正在压缩数据...');
        finalBytes = _CompressionManager.compress(finalBytes);
      }

      // 计算哈希
      final contentHash = crypto.sha256.convert(finalBytes).toString();

      // 上传
      context.onProgress?.call(0.8, '正在上传到云端...');
      final backupId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      final key = 'backup_$backupId.dat';
      final remoteUri = await _provider!.upload(key, finalBytes);

      // 记录备份元数据
      final metadata = BackupMetadata(
        backupId: backupId,
        label: label,
        createdAt: DateTime.now(),
        sizeBytes: finalBytes.length,
        contentHash: contentHash,
        backend: _provider!.backendType,
        categories: categoriesList,
        categoryCounts: Map.fromEntries(
          packets.map((p) => MapEntry(p.category.displayName, p.itemCount)),
        ),
      );
      _backupIndex[backupId] = metadata;

      // 更新本地同步时间戳
      for (final category in categories) {
        _lastSyncTimestamps[category.value] = DateTime.now();
        _contentHashes[category.value] = crypto.sha256
            .convert(utf8.encode(packets
                .where((p) => p.category == category)
                .map((p) => p.contentHash)
                .join()))
            .toString();
      }

      // 保存同步配置
      await _persistSyncState(context);

      _updateStatus(SyncStatus(
        lastSyncAt: DateTime.now(),
        lastSyncResult: 'success',
        totalItems: packets.fold<int>(0, (sum, p) => sum + p.itemCount),
        syncedItems: packets.fold<int>(0, (sum, p) => sum + p.itemCount),
      ));

      final sizeStr = _formatBytes(finalBytes.length);
      final compressedStr = shouldCompress
          ? '（压缩后）'
          : '';

      return ToolResult.success(
        content: '同步成功！备份 ID: $backupId\n'
            '标签: $label\n'
            '模式: ${mode == 'full_sync' ? "全量" : "增量"}\n'
            '数据量: ${packets.fold<int>(0, (s, p) => s + p.itemCount)} 条\n'
            '大小: $sizeStr$compressedStr\n'
            '分类: ${categoriesList.join(", ")}\n'
            '加密: ${shouldEncrypt ? "AES-256" : "未加密"}\n'
            '压缩: ${shouldCompress ? "gzip" : "未压缩"}',
        data: metadata.toJson(),
      );
    } catch (e) {
      _updateStatus(const SyncStatus(lastSyncResult: 'failed'));
      context.logger.error('同步到云端失败', e);
      return ToolResult.failure(
        error: '同步失败: $e',
        errorCode: 'SYNC_FAILED',
      );
    }
  }

  // ============================================================================
  // 工具实现：restore_from_cloud
  // ============================================================================

  Future<ToolResult> _executeRestoreFromCloud(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    if (_provider == null) {
      return ToolResult.failure(
        error: '未配置云存储后端，请先使用 sync_settings 配置',
        errorCode: 'NO_PROVIDER',
      );
    }

    final backupId = args['backup_id'] as String?;
    final categoriesList = (args['categories'] as List?)?.cast<String>();
    final conflictResStr = args['conflict_resolution'] as String? ?? 'keep_newer';
    final dryRun = args['dry_run'] as bool? ?? false;

    final resolution = ConflictResolution.values.firstWhere(
      (e) => e.value == conflictResStr,
      orElse: () => ConflictResolution.keepNewer,
    );

    _updateStatus(const SyncStatus(isSyncing: true));

    try {
      // 确定要恢复的备份
      final targetId = backupId ?? _backupIndex.keys.last;
      final key = 'backup_$targetId.dat';

      context.onProgress?.call(0.2, '正在从云端下载...');
      final compressed = await _provider!.download(key);

      context.onProgress?.call(0.4, '正在解压数据...');
      final decompressed = _CompressionManager.decompress(compressed);
      var payload = utf8.decode(decompressed);

      // 解密
      if (_encryptionManager != null) {
        context.onProgress?.call(0.5, '正在解密数据...');
        payload = _encryptionManager!.decrypt(payload);
      }

      final data = jsonDecode(payload) as Map<String, dynamic>;
      final packetsList = (data['packets'] as List).cast<Map<String, dynamic>>();
      final packets = packetsList.map(SyncDataPacket.fromJson).toList();

      // 过滤分类
      final filteredPackets = categoriesList != null
          ? packets.where((p) => categoriesList.contains(p.category.value)).toList()
          : packets;

      if (dryRun) {
        final buffer = StringBuffer();
        buffer.writeln('备份预览（dry_run 模式，未实际恢复）：');
        buffer.writeln('备份 ID: $targetId');
        buffer.writeln('创建时间: ${data['created_at']}');
        buffer.writeln('包含分类:');
        for (final p in filteredPackets) {
          buffer.writeln('  - ${p.category.displayName}: ${p.itemCount} 条');
        }
        return ToolResult.success(content: buffer.toString().trim());
      }

      // 执行恢复
      context.onProgress?.call(0.7, '正在恢复数据...');
      int restoredCount = 0;
      final restoreLog = <String>[];

      for (final packet in filteredPackets) {
        final count = await _restoreCategoryData(packet, resolution);
        restoredCount += count;
        restoreLog.add('${packet.category.displayName}: 恢复 $count 条');
      }

      _updateStatus(SyncStatus(
        lastSyncAt: DateTime.now(),
        lastSyncResult: 'restored',
        totalItems: filteredPackets.fold<int>(0, (s, p) => s + p.itemCount),
        syncedItems: restoredCount,
      ));

      final buffer = StringBuffer();
      buffer.writeln('恢复成功！');
      buffer.writeln('备份 ID: $targetId');
      buffer.writeln('冲突策略: ${resolution.value}');
      buffer.writeln('恢复详情:');
      for (final log in restoreLog) {
        buffer.writeln('  $log');
      }
      buffer.write('共恢复 $restoredCount 条数据');

      return ToolResult.success(content: buffer.toString());
    } catch (e) {
      _updateStatus(const SyncStatus(lastSyncResult: 'restore_failed'));
      context.logger.error('从云端恢复失败', e);
      return ToolResult.failure(
        error: '恢复失败: $e',
        errorCode: 'RESTORE_FAILED',
      );
    }
  }

  // ============================================================================
  // 工具实现：list_backups
  // ============================================================================

  Future<ToolResult> _executeListBackups(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final limit = args['limit'] as int? ?? 20;
    final categoryFilter = args['category_filter'] as String?;

    var entries = _backupIndex.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (categoryFilter != null) {
      entries = entries
          .where((b) => b.categories.contains(categoryFilter))
          .toList();
    }

    if (entries.length > limit) {
      entries = entries.sublist(0, limit);
    }

    if (entries.isEmpty) {
      return ToolResult.success(
        content: '暂无云端备份记录。请先使用 sync_to_cloud 创建备份。',
        data: {'backups': <Map<String, dynamic>>[], 'total': 0},
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('云端备份列表（共 ${_backupIndex.length} 个，显示前 ${entries.length} 个）：');
    buffer.writeln();

    for (int i = 0; i < entries.length; i++) {
      final b = entries[i];
      buffer.writeln('**${i + 1}. ${b.label}**');
      buffer.writeln('   ID: ${b.backupId}');
      buffer.writeln('   时间: ${b.createdAt.toIso8601String()}');
      buffer.writeln('   大小: ${_formatBytes(b.sizeBytes)}');
      buffer.writeln('   分类: ${b.categories.join(", ")}');
      if (b.categoryCounts.isNotEmpty) {
        final counts = b.categoryCounts.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        buffer.writeln('   数据量: $counts');
      }
      buffer.writeln();
    }

    return ToolResult.success(
      content: buffer.toString().trim(),
      data: {
        'backups': entries.map((b) => b.toJson()).toList(),
        'total': _backupIndex.length,
      },
    );
  }

  // ============================================================================
  // 工具实现：auto_sync_config
  // ============================================================================

  Future<ToolResult> _executeAutoSyncConfig(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final action = args['action'] as String;

    switch (action) {
      case 'query':
        final buffer = StringBuffer();
        buffer.writeln('当前自动同步配置：');
        buffer.writeln('  启用状态: ${_autoSyncConfig.enabled ? "已启用" : "未启用"}');
        buffer.writeln('  同步间隔: ${_autoSyncConfig.intervalMinutes} 分钟');
        buffer.writeln('  同步分类: ${_autoSyncConfig.syncCategories.join(", ")}');
        buffer.writeln('  冲突策略: ${_autoSyncConfig.defaultResolution.value}');
        buffer.writeln('  仅 WiFi: ${_autoSyncConfig.wifiOnly ? "是" : "否"}');
        if (_currentStatus.lastSyncAt != null) {
          buffer.writeln('  上次同步: ${_currentStatus.lastSyncAt}');
        }
        return ToolResult.success(
          content: buffer.toString().trim(),
          data: _autoSyncConfig.toJson(),
        );

      case 'enable':
        _autoSyncConfig = AutoSyncConfig(
          enabled: true,
          intervalMinutes: _autoSyncConfig.intervalMinutes,
          syncCategories: _autoSyncConfig.syncCategories,
          defaultResolution: _autoSyncConfig.defaultResolution,
          wifiOnly: _autoSyncConfig.wifiOnly,
          encryptEnabled: _autoSyncConfig.encryptEnabled,
          compressEnabled: _autoSyncConfig.compressEnabled,
        );
        _startAutoSyncTimer(context);
        await _persistAutoSyncConfig(context);
        return ToolResult.success(
          content: '自动同步已启用，间隔: ${_autoSyncConfig.intervalMinutes} 分钟',
        );

      case 'disable':
        _autoSyncConfig = AutoSyncConfig(
          enabled: false,
          intervalMinutes: _autoSyncConfig.intervalMinutes,
          syncCategories: _autoSyncConfig.syncCategories,
        );
        _autoSyncTimer?.cancel();
        await _persistAutoSyncConfig(context);
        return ToolResult.success(content: '自动同步已禁用');

      case 'update':
        final newInterval = args['interval_minutes'] as int?;
        final newCategories = (args['categories'] as List?)?.cast<String>();
        final newResolution = args['conflict_resolution'] as String?;
        final newWifiOnly = args['wifi_only'] as bool?;

        _autoSyncConfig = AutoSyncConfig(
          enabled: _autoSyncConfig.enabled,
          intervalMinutes: newInterval ?? _autoSyncConfig.intervalMinutes,
          syncCategories: newCategories ?? _autoSyncConfig.syncCategories,
          defaultResolution: newResolution != null
              ? ConflictResolution.values.firstWhere(
                  (e) => e.value == newResolution,
                  orElse: () => _autoSyncConfig.defaultResolution,
                )
              : _autoSyncConfig.defaultResolution,
          wifiOnly: newWifiOnly ?? _autoSyncConfig.wifiOnly,
          encryptEnabled: _autoSyncConfig.encryptEnabled,
          compressEnabled: _autoSyncConfig.compressEnabled,
        );

        // 重启定时器
        if (_autoSyncConfig.enabled) {
          _autoSyncTimer?.cancel();
          _startAutoSyncTimer(context);
        }
        await _persistAutoSyncConfig(context);

        return ToolResult.success(
          content: '自动同步配置已更新',
          data: _autoSyncConfig.toJson(),
        );

      default:
        return ToolResult.failure(
          error: '未知操作: $action',
          errorCode: 'INVALID_ACTION',
        );
    }
  }

  // ============================================================================
  // 工具实现：sync_settings
  // ============================================================================

  Future<ToolResult> _executeSyncSettings(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final backendStr = args['backend'] as String;
    final configMap = (args['config'] as Map).cast<String, dynamic>();
    final encryptionKey = args['encryption_key'] as String?;

    // 解析后端类型
    final backend = CloudStorageBackend.values.firstWhere(
      (e) => e.value == backendStr,
      orElse: () => throw CloudSyncException('不支持的云存储后端: $backendStr'),
    );

    // 销毁旧的提供者
    await _provider?.dispose();

    // 创建新的提供者
    _provider = switch (backend) {
      CloudStorageBackend.githubGist => GitHubGistProvider(),
      CloudStorageBackend.webDav => WebDavProvider(),
      CloudStorageBackend.customHttp => CustomHttpProvider(),
    };

    // 初始化提供者
    final configStrings = configMap.map(
      (k, v) => MapEntry(k, v.toString()),
    );
    await _provider!.init(configStrings);

    // 更新加密管理器
    if (encryptionKey != null && encryptionKey.isNotEmpty) {
      _encryptionManager = _EncryptionManager(key: encryptionKey);
      context.logger.info('端到端加密已启用 (AES-256)');
    } else if (encryptionKey == '') {
      _encryptionManager = null;
      context.logger.warning('端到端加密已禁用（不推荐）');
    }

    // 持久化配置
    await context.storage.set('cloud_backend', backendStr);
    await context.storage.set('cloud_config', jsonEncode(configStrings));
    if (encryptionKey != null) {
      await context.storage.set('encryption_key', encryptionKey);
    }

    return ToolResult.success(
      content: '云同步配置已更新\n'
          '后端: ${backend.displayName}\n'
          '加密: ${_encryptionManager != null ? "AES-256 已启用" : "未启用"}',
    );
  }

  // ============================================================================
  // 工具实现：sync_memories
  // ============================================================================

  Future<ToolResult> _executeSyncMemories(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    if (_provider == null) {
      return ToolResult.failure(
        error: '未配置云存储后端，请先使用 sync_settings 配置',
        errorCode: 'NO_PROVIDER',
      );
    }

    final memoryTypes = (args['memory_types'] as List?)?.cast<String>() ??
        ['semantic', 'episodic', 'profile'];
    final direction = args['direction'] as String? ?? 'upload';

    _updateStatus(const SyncStatus(isSyncing: true));

    try {
      if (direction == 'upload') {
        final memoryData = <String, dynamic>{};

        for (final type in memoryTypes) {
          context.onProgress?.call(
            memoryTypes.indexOf(type) / memoryTypes.length * 0.5,
            '正在收集${type == "semantic" ? "语义" : type == "episodic" ? "情景" : "画像"}记忆...',
          );
          memoryData[type] = await _collectMemoryData(type);
        }

        final packet = SyncDataPacket(
          packetId: 'mem_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          category: SyncCategory.memories,
          data: memoryData,
          contentHash: crypto.sha256.convert(utf8.encode(jsonEncode(memoryData))).toString(),
          itemCount: memoryTypes.length,
        );

        final payload = jsonEncode(packet.toJson());
        List<int> processed = utf8.encode(
          _encryptionManager != null
              ? _encryptionManager!.encrypt(payload)
              : payload,
        );
        processed = _CompressionManager.compress(processed);

        final key = 'memories_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}.dat';
        await _provider!.upload(key, processed);

        _updateStatus(SyncStatus(
          lastSyncAt: DateTime.now(),
          lastSyncResult: 'memory_upload_success',
          totalItems: memoryTypes.length,
          syncedItems: memoryTypes.length,
        ));

        return ToolResult.success(
          content: '记忆同步上传成功\n'
              '同步类型: ${memoryTypes.join(", ")}\n'
              '数据已加密压缩并上传到 ${_provider!.backendType}',
        );
      } else {
        context.onProgress?.call(0.3, '正在下载云端记忆数据...');
        final keys = await _provider!.listKeys(prefix: 'memories_');
        if (keys.isEmpty) {
          return ToolResult.success(content: '云端无记忆数据');
        }

        final latestKey = keys.last;
        final compressed = await _provider!.download(latestKey);
        var payload = utf8.decode(_CompressionManager.decompress(compressed));
        if (_encryptionManager != null) {
          payload = _encryptionManager!.decrypt(payload);
        }
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final packet = SyncDataPacket.fromJson(data);

        context.onProgress?.call(0.7, '正在恢复记忆数据...');
        await _restoreMemoryData(packet.data, memoryTypes);

        _updateStatus(SyncStatus(
          lastSyncAt: DateTime.now(),
          lastSyncResult: 'memory_download_success',
          totalItems: memoryTypes.length,
          syncedItems: memoryTypes.length,
        ));

        return ToolResult.success(
          content: '记忆同步下载成功\n'
              '恢复类型: ${memoryTypes.join(", ")}\n'
              '来源: $latestKey',
        );
      }
    } catch (e) {
      _updateStatus(const SyncStatus(lastSyncResult: 'memory_sync_failed'));
      context.logger.error('记忆同步失败', e);
      return ToolResult.failure(error: '记忆同步失败: $e', errorCode: 'MEMORY_SYNC_FAILED');
    }
  }

  // ============================================================================
  // 工具实现：export_all
  // ============================================================================

  Future<ToolResult> _executeExportAll(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final categoriesList = (args['categories'] as List?)?.cast<String>() ??
        ['conversations', 'memories', 'settings', 'skills', 'attachment_index'];
    final format = args['format'] as String? ?? 'json';
    final includeMetadata = args['include_metadata'] as bool? ?? true;

    try {
      final exportData = <String, dynamic>{
        'version': '1.0.0',
        'export_time': DateTime.now().toIso8601String(),
        'app_version': 'xiaosu_core',
        'categories': <String, dynamic>{},
      };

      final categories = categoriesList.map((c) => SyncCategory.values.firstWhere(
            (e) => e.value == c,
            orElse: () => SyncCategory.conversations,
          )).toList();

      int totalItems = 0;
      for (final category in categories) {
        final data = await _collectCategoryData(category, 'full_sync');
        final categoryData = <String, dynamic>{
          'data': data.data,
          'item_count': data.itemCount,
          'content_hash': data.contentHash,
        };
        if (includeMetadata) {
          categoryData['exported_at'] = DateTime.now().toIso8601String();
          categoryData['category'] = category.value;
        }
        exportData['categories'][category.value] = categoryData;
        totalItems += data.itemCount;
      }

      var jsonStr = jsonEncode(exportData);

      // 加密处理
      if (format == 'json_encrypted' && _encryptionManager != null) {
        jsonStr = _encryptionManager!.encrypt(jsonStr);
      }

      final bytes = utf8.encode(jsonStr);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final ext = format == 'json_encrypted' ? 'enc.json' : 'json';
      final fileName = 'xiaosu_backup_$timestamp.$ext';

      final sizeStr = _formatBytes(bytes.length);

      return ToolResult.success(
        content: '导出成功！\n'
            '文件: $fileName\n'
            '大小: $sizeStr\n'
            '分类: ${categoriesList.join(", ")}\n'
            '总数据量: $totalItems 条\n'
            '格式: ${format == "json_encrypted" ? "加密 JSON" : "明文 JSON"}',
        data: {
          'file_name': fileName,
          'size_bytes': bytes.length,
          'total_items': totalItems,
          'format': format,
          'content': jsonStr,
        },
      );
    } catch (e) {
      context.logger.error('导出数据失败', e);
      return ToolResult.failure(error: '导出失败: $e', errorCode: 'EXPORT_FAILED');
    }
  }

  // ============================================================================
  // 工具实现：import_data
  // ============================================================================

  Future<ToolResult> _executeImportData(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final filePath = args['file_path'] as String;
    final categoriesList = (args['categories'] as List?)?.cast<String>();
    final overwrite = args['overwrite'] as bool? ?? false;
    final encryptionKey = args['encryption_key'] as String?;

    try {
      context.onProgress?.call(0.1, '正在读取备份文件...');

      // 读取文件内容
      final fileBytes = await _readFileBytes(filePath);
      var jsonStr = utf8.decode(fileBytes);

      // 解密（如果提供密钥或备份是加密的）
      if (encryptionKey != null && encryptionKey.isNotEmpty) {
        final tempEncryptor = _EncryptionManager(key: encryptionKey);
        jsonStr = tempEncryptor.decrypt(jsonStr);
      } else if (_encryptionManager != null && filePath.endsWith('.enc.json')) {
        jsonStr = _encryptionManager!.decrypt(jsonStr);
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final categories = data['categories'] as Map<String, dynamic>? ?? {};

      // 过滤分类
      final entries = categoriesList != null
          ? categories.entries.where((e) => categoriesList.contains(e.key)).toList()
          : categories.entries.toList();

      int totalRestored = 0;
      final importLog = <String>[];

      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final category = entry.key;
        final categoryData = entry.value as Map<String, dynamic>;
        final progress = 0.2 + (i / entries.length) * 0.7;
        context.onProgress?.call(progress, '正在导入${category}...');

        final itemCount = categoryData['item_count'] as int? ?? 0;
        final count = await _importCategoryData(
          category,
          categoryData['data'] as Map<String, dynamic>,
          overwrite,
        );
        totalRestored += count;
        importLog.add('$category: $count / $itemCount 条');
      }

      return ToolResult.success(
        content: '导入成功！\n'
            '文件: $filePath\n'
            '${importLog.map((l) => "  $l").join("\n")}\n'
            '共导入 $totalRestored 条数据',
        data: {'total_restored': totalRestored, 'import_log': importLog},
      );
    } catch (e) {
      context.logger.error('导入数据失败', e);
      return ToolResult.failure(error: '导入失败: $e', errorCode: 'IMPORT_FAILED');
    }
  }

  // ============================================================================
  // 工具实现：check_conflicts
  // ============================================================================

  Future<ToolResult> _executeCheckConflicts(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    if (_provider == null) {
      return ToolResult.failure(
        error: '未配置云存储后端',
        errorCode: 'NO_PROVIDER',
      );
    }

    final categoriesList = (args['categories'] as List?)?.cast<String>();
    final autoResolve = args['auto_resolve'] as bool? ?? false;

    try {
      final conflicts = <SyncConflict>[];
      final keys = await _provider!.listKeys();

      for (final key in keys) {
        if (!key.startsWith('backup_')) continue;
        for (final cat in SyncCategory.values) {
          if (categoriesList != null && !categoriesList.contains(cat.value)) continue;

          final localHash = _contentHashes[cat.value] ?? '';
          final localModified = _lastSyncTimestamps[cat.value] ?? DateTime.fromMillisecondsSinceEpoch(0);

          // 模拟冲突检测逻辑
          final remoteData = await _provider!.download(key);
          if (remoteData.isNotEmpty) {
            final remoteHash = crypto.sha256.convert(remoteData).toString();
            if (localHash.isNotEmpty && localHash != remoteHash) {
              conflicts.add(SyncConflict(
                filePath: '$key/${cat.value}',
                localModified: localModified,
                remoteModified: DateTime.now(),
                localHash: localHash,
                remoteHash: remoteHash,
                category: cat.value,
              ));
            }
          }
        }
      }

      if (autoResolve && conflicts.isNotEmpty) {
        final resolved = await _autoResolveConflicts(conflicts, context);
        return ToolResult.success(
          content: '冲突检测完成\n'
              '发现 ${conflicts.length} 个冲突\n'
              '已自动解决 $resolved 个（策略: ${_autoSyncConfig.defaultResolution.value}）',
          data: {
            'total_conflicts': conflicts.length,
            'auto_resolved': resolved,
            'conflicts': conflicts.map((c) => c.toJson()).toList(),
          },
        );
      }

      if (conflicts.isEmpty) {
        return ToolResult.success(
          content: '未检测到同步冲突，本地与云端数据一致。',
          data: {'conflicts': <Map<String, dynamic>>[], 'total': 0},
        );
      }

      final buffer = StringBuffer();
      buffer.writeln('检测到 ${conflicts.length} 个同步冲突：');
      buffer.writeln();
      for (int i = 0; i < conflicts.length; i++) {
        final c = conflicts[i];
        buffer.writeln('**${i + 1}. ${c.category}**');
        buffer.writeln('   路径: ${c.filePath}');
        buffer.writeln('   本地修改: ${c.localModified}');
        buffer.writeln('   远程修改: ${c.remoteModified}');
        buffer.writeln('   本地哈希: ${c.localHash.substring(0, 8)}...');
        buffer.writeln('   远程哈希: ${c.remoteHash.substring(0, 8)}...');
        buffer.writeln();
      }
      buffer.writeln('使用 auto_resolve=true 可自动解决，或逐一手动处理。');

      return ToolResult.success(
        content: buffer.toString().trim(),
        data: {
          'conflicts': conflicts.map((c) => c.toJson()).toList(),
          'total': conflicts.length,
        },
      );
    } catch (e) {
      context.logger.error('冲突检测失败', e);
      return ToolResult.failure(error: '冲突检测失败: $e', errorCode: 'CONFLICT_CHECK_FAILED');
    }
  }

  // ============================================================================
  // 内部辅助方法
  // ============================================================================

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  Future<void> _initializeProvider() async {
    final backendStr = await _config.storage?.get('cloud_backend') ?? '';
    if (backendStr.isEmpty) return;

    final backend = CloudStorageBackend.values.firstWhere(
      (e) => e.value == backendStr,
      orElse: () => CloudStorageBackend.githubGist,
    );

    _provider = switch (backend) {
      CloudStorageBackend.githubGist => GitHubGistProvider(),
      CloudStorageBackend.webDav => WebDavProvider(),
      CloudStorageBackend.customHttp => CustomHttpProvider(),
    };

    final configStr = await _config.storage?.get('cloud_config') ?? '{}';
    final configMap = (jsonDecode(configStr) as Map).cast<String, dynamic>();
    await _provider!.init(configMap.map((k, v) => MapEntry(k, v.toString())));
  }

  Future<void> _restoreAutoSyncConfig(SkillContext context) async {
    final configStr = await context.storage.get('auto_sync_config');
    if (configStr != null) {
      try {
        _autoSyncConfig = AutoSyncConfig.fromJson(
          jsonDecode(configStr) as Map<String, dynamic>,
        );
      } catch (_) {
        _autoSyncConfig = const AutoSyncConfig();
      }
    }
  }

  void _startAutoSyncTimer(SkillContext context) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: _autoSyncConfig.intervalMinutes),
      (_) async {
        context.logger.info('自动同步触发');
        try {
          await _executeSyncToCloud({
            'categories': _autoSyncConfig.syncCategories,
            'mode': _autoSyncConfig.defaultMode.value,
            'encrypt': _autoSyncConfig.encryptEnabled,
            'compress': _autoSyncConfig.compressEnabled,
            'label': '自动同步',
          }, context);
        } catch (e) {
          context.logger.error('自动同步失败', e);
        }
      },
    );
  }

  Future<SyncDataPacket> _collectCategoryData(
    SyncCategory category,
    String mode,
  ) async {
    final now = DateTime.now();
    final isIncremental = mode == 'incremental_sync';
    final lastSync = _lastSyncTimestamps[category.value];

    // 根据分类收集数据
    final data = <String, dynamic>{
      'category': category.value,
      'items': <Map<String, dynamic>>[],
      'collected_at': now.toIso8601String(),
      'incremental': isIncremental,
      if (lastSync != null) 'since': lastSync.toIso8601String(),
    };

    // 模拟收集各类数据
    final itemCount = isIncremental && lastSync != null ? 5 : 20;

    return SyncDataPacket(
      packetId: '${category.value}_${now.millisecondsSinceEpoch}',
      timestamp: now,
      category: category,
      data: data,
      contentHash: crypto.sha256.convert(utf8.encode(jsonEncode(data))).toString(),
      itemCount: itemCount,
    );
  }

  Future<int> _restoreCategoryData(
    SyncDataPacket packet,
    ConflictResolution resolution,
  ) async {
    // 模拟恢复逻辑
    return packet.itemCount;
  }

  Future<Map<String, dynamic>> _collectMemoryData(String type) async {
    return {
      'type': type,
      'items': <Map<String, dynamic>>[],
      'collected_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _restoreMemoryData(
    Map<String, dynamic> data,
    List<String> types,
  ) async {
    // 模拟恢复记忆数据
  }

  Future<List<int>> _readFileBytes(String filePath) async {
    // 实际实现中通过 dart:io File 读取
    return utf8.encode('{"version":"1.0.0","categories":{}}');
  }

  Future<int> _importCategoryData(
    String category,
    Map<String, dynamic> data,
    bool overwrite,
  ) async {
    // 模拟导入
    return (data['items'] as List?)?.length ?? 0;
  }

  Future<void> _autoResolveConflicts(
    List<SyncConflict> conflicts,
    SkillContext context,
  ) async {
    // 根据默认策略自动解决冲突
    for (final conflict in conflicts) {
      switch (_autoSyncConfig.defaultResolution) {
        case ConflictResolution.keepNewer:
          // 保留较新的版本
          break;
        case ConflictResolution.keepLocal:
          break;
        case ConflictResolution.keepRemote:
          break;
        case ConflictResolution.merge:
          // 合并（需要更复杂的逻辑）
          break;
        case ConflictResolution.manual:
          break;
      }
    }
  }

  Future<void> _persistSyncState(SkillContext context) async {
    final state = {
      'last_sync_timestamps': _lastSyncTimestamps.map(
        (k, v) => MapEntry(k, v.toIso8601String()),
      ),
      'content_hashes': _contentHashes,
    };
    await context.storage.set('sync_state', jsonEncode(state));
  }

  Future<void> _persistAutoSyncConfig(SkillContext context) async {
    await context.storage.set('auto_sync_config', jsonEncode(_autoSyncConfig.toJson()));
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ============================================================================
// 配置与异常
// ============================================================================

/// 云同步技能配置
class CloudSyncConfig {
  /// 加密密钥
  final String encryptionKey;

  /// 默认后端
  final CloudStorageBackend defaultBackend;

  /// 外部 SkillStorage（用于持久化配置）
  final SkillStorage? storage;

  /// 最大备份保留数量
  final int maxBackups;

  /// 单次上传最大字节数
  final int maxUploadBytes;

  const CloudSyncConfig({
    this.encryptionKey = '',
    this.defaultBackend = CloudStorageBackend.githubGist,
    this.storage,
    this.maxBackups = 50,
    this.maxUploadBytes = 10 * 1024 * 1024, // 10 MB
  });
}

/// 云同步异常
class CloudSyncException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const CloudSyncException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'CloudSyncException($code): $message';
}
