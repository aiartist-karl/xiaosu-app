// ============================================================================
// 小酥 AI 助手 - 凭证管理器
// ============================================================================
// 安全管理各类 API 凭证（Token、密钥、Cookie 等）
// 使用 flutter_secure_storage 实现加密存储
// 支持多 Provider 凭证管理（OpenAI、火山引擎、橘子AI 等）
// ============================================================================

import 'dart:async';
import 'dart:convert';

/// 凭证管理器
/// 统一管理和安全存储各类 API 凭证
class CredentialManager {
  /// 底层安全存储
  final SecureStorage _storage;

  /// 凭证变更监听器
  final StreamController<CredentialChangeEvent> _changeController =
      StreamController<CredentialChangeEvent>.broadcast();

  /// 凭证变更流
  Stream<CredentialChangeEvent> get changes => _changeController.stream;

  /// 内存缓存（减少存储读取次数）
  final Map<String, String> _cache = {};

  /// 缓存过期时间
  final Duration _cacheExpiry;

  /// 缓存时间戳
  final Map<String, DateTime> _cacheTimestamps = {};

  CredentialManager({
    required SecureStorage storage,
    Duration cacheExpiry = const Duration(minutes: 5),
  })  : _storage = storage,
        _cacheExpiry = cacheExpiry;

  // ============================================================================
  // 凭证 CRUD
  // ============================================================================

  /// 保存凭证
  ///
  /// [provider] 服务提供者标识
  /// [credential] 凭证信息
  Future<void> saveCredential({
    required String provider,
    required Credential credential,
  }) async {
    final key = _buildKey(provider, credential.type);
    final value = credential.toJsonString();

    // 写入安全存储
    await _storage.write(key: key, value: value);

    // 更新缓存
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();

    _changeController.add(CredentialChangeEvent(
      provider: provider,
      type: credential.type,
      action: CredentialAction.saved,
    ));
  }

  /// 获取凭证
  ///
  /// [provider] 服务提供者标识
  /// [type] 凭证类型
  Future<Credential?> getCredential({
    required String provider,
    required CredentialType type,
  }) async {
    final key = _buildKey(provider, type);

    // 尝试从缓存读取
    final cachedValue = _getCachedValue(key);
    if (cachedValue != null) {
      return Credential.fromJsonString(cachedValue);
    }

    // 从安全存储读取
    final value = await _storage.read(key: key);
    if (value == null) return null;

    // 更新缓存
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();

    return Credential.fromJsonString(value);
  }

  /// 获取 API Key（快捷方法）
  Future<String?> getApiKey(String provider) async {
    final credential = await getCredential(
      provider: provider,
      type: CredentialType.apiKey,
    );
    return credential?.value;
  }

  /// 获取 Access Token（快捷方法）
  Future<String?> getAccessToken(String provider) async {
    final credential = await getCredential(
      provider: provider,
      type: CredentialType.accessToken,
    );
    return credential?.value;
  }

  /// 删除凭证
  ///
  /// [provider] 服务提供者标识
  /// [type] 凭证类型
  Future<void> deleteCredential({
    required String provider,
    required CredentialType type,
  }) async {
    final key = _buildKey(provider, type);

    await _storage.delete(key: key);

    // 清除缓存
    _cache.remove(key);
    _cacheTimestamps.remove(key);

    _changeController.add(CredentialChangeEvent(
      provider: provider,
      type: type,
      action: CredentialAction.deleted,
    ));
  }

  /// 删除某个 Provider 的所有凭证
  Future<void> deleteAllForProvider(String provider) async {
    for (final type in CredentialType.values) {
      await deleteCredential(provider: provider, type: type);
    }
  }

  /// 检查凭证是否存在
  Future<bool> hasCredential({
    required String provider,
    required CredentialType type,
  }) async {
    final key = _buildKey(provider, type);

    // 先查缓存
    if (_getCachedValue(key) != null) return true;

    // 查存储
    final value = await _storage.read(key: key);
    return value != null;
  }

  /// 获取所有已配置的 Provider 列表
  Future<List<ProviderInfo>> getConfiguredProviders() async {
    final providers = <ProviderInfo>[];
    final allKeys = await _storage.readAll();

    for (final provider in CredentialProvider.knownProviders) {
      final types = <CredentialType>[];

      for (final type in CredentialType.values) {
        final key = _buildKey(provider.id, type);
        if (allKeys.containsKey(key)) {
          types.add(type);
        }
      }

      if (types.isNotEmpty) {
        providers.add(ProviderInfo(
          provider: provider,
          configuredTypes: types,
        ));
      }
    }

    return providers;
  }

  // ============================================================================
  // Token 刷新
  // ============================================================================

  /// 刷新 Access Token
  /// 使用 Refresh Token 获取新的 Access Token
  ///
  /// [provider] 服务提供者
  Future<TokenRefreshResult> refreshAccessToken(String provider) async {
    final refreshToken = await getCredential(
      provider: provider,
      type: CredentialType.refreshToken,
    );

    if (refreshToken == null) {
      return const TokenRefreshResult(
        success: false,
        error: '未找到 Refresh Token',
      );
    }

    try {
      // 根据 Provider 调用对应的刷新接口
      final newTokens = await _callRefreshEndpoint(
        provider: provider,
        refreshToken: refreshToken.value,
      );

      // 保存新的 Token
      if (newTokens.accessToken != null) {
        await saveCredential(
          provider: provider,
          credential: Credential(
            type: CredentialType.accessToken,
            value: newTokens.accessToken!,
            expiresAt: newTokens.expiresAt,
          ),
        );
      }

      if (newTokens.refreshToken != null) {
        await saveCredential(
          provider: provider,
          credential: Credential(
            type: CredentialType.refreshToken,
            value: newTokens.refreshToken!,
          ),
        );
      }

      return TokenRefreshResult(
        success: true,
        accessToken: newTokens.accessToken,
        expiresAt: newTokens.expiresAt,
      );
    } catch (e) {
      return TokenRefreshResult(
        success: false,
        error: 'Token 刷新失败: $e',
      );
    }
  }

  /// 检查 Token 是否即将过期
  Future<bool> isTokenExpiringSoon({
    required String provider,
    Duration threshold = const Duration(minutes: 5),
  }) async {
    final credential = await getCredential(
      provider: provider,
      type: CredentialType.accessToken,
    );

    if (credential?.expiresAt == null) return false;

    return DateTime.now().add(threshold).isAfter(credential!.expiresAt!);
  }

  /// 获取有效的 Access Token（自动刷新）
  /// 如果 Token 已过期或即将过期，自动刷新
  Future<String?> getValidAccessToken({
    required String provider,
    Duration threshold = const Duration(minutes: 5),
  }) async {
    // 检查是否需要刷新
    if (await isTokenExpiringSoon(provider: provider, threshold: threshold)) {
      final result = await refreshAccessToken(provider);
      if (result.success) return result.accessToken;
      return null;
    }

    return await getAccessToken(provider);
  }

  // ============================================================================
  // 批量操作
  // ============================================================================

  /// 批量导入凭证
  ///
  /// [credentials] 凭证映射 (provider -> List<Credential>)
  Future<void> importCredentials(
      Map<String, List<Credential>> credentials) async {
    for (final entry in credentials.entries) {
      for (final credential in entry.value) {
        await saveCredential(
          provider: entry.key,
          credential: credential,
        );
      }
    }
  }

  /// 导出所有凭证（加密）
  ///
  /// [password] 加密密码
  Future<String> exportCredentials({required String password}) async {
    final allKeys = await _storage.readAll();
    final exportData = {
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'credentials': allKeys,
    };

    // TODO: 实际项目中应使用 AES 加密
    // 当前仅做 JSON 序列化
    final jsonString = jsonEncode(exportData);
    return base64Encode(utf8.encode(jsonString));
  }

  /// 导入凭证（解密）
  ///
  /// [data] 加密的凭证数据
  /// [password] 解密密码
  Future<int> importCredentialsFromExport({
    required String data,
    required String password,
  }) async {
    // TODO: 实际项目中应使用 AES 解密
    final jsonString = utf8.decode(base64Decode(data));
    final exportData = jsonDecode(jsonString) as Map<String, dynamic>;
    final credentials = exportData['credentials'] as Map<String, dynamic>;

    int count = 0;
    for (final entry in credentials.entries) {
      await _storage.write(key: entry.key, value: entry.value as String);
      count++;
    }

    _cache.clear();
    _cacheTimestamps.clear();

    return count;
  }

  /// 清除所有凭证
  Future<void> clearAll() async {
    await _storage.deleteAll();
    _cache.clear();
    _cacheTimestamps.clear();

    _changeController.add(const CredentialChangeEvent(
      provider: '*',
      type: CredentialType.apiKey, // 占位
      action: CredentialAction.cleared,
    ));
  }

  // ============================================================================
  // 内部方法
  // ============================================================================

  /// 构建存储键名
  String _buildKey(String provider, CredentialType type) {
    return 'credential:$provider:${type.value}';
  }

  /// 从缓存获取值
  String? _getCachedValue(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;

    if (DateTime.now().difference(timestamp) > _cacheExpiry) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }

    return _cache[key];
  }

  /// 调用 Token 刷新端点
  Future<_NewTokens> _callRefreshEndpoint({
    required String provider,
    required String refreshToken,
  }) async {
    // TODO: 实际项目中根据不同 Provider 调用对应的刷新接口
    switch (provider) {
      case 'openai':
        // OpenAI 不支持 refresh token
        throw UnsupportedError('OpenAI 不支持 Token 刷新');

      case 'volcengine':
        // 火山引擎 Token 刷新
        // TODO: 调用火山引擎 OAuth 刷新接口
        return _NewTokens(
          accessToken: 'new_access_token_placeholder',
          refreshToken: null,
          expiresAt: DateTime.now().add(const Duration(hours: 2)),
        );

      case 'orange_ai':
        // 橘子 AI Token 刷新
        // TODO: 调用橘子 AI 刷新接口
        return _NewTokens(
          accessToken: 'new_access_token_placeholder',
          refreshToken: null,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

      default:
        throw UnsupportedError('不支持的 Provider: $provider');
    }
  }

  /// 释放资源
  void dispose() {
    _changeController.close();
    _cache.clear();
    _cacheTimestamps.clear();
  }
}

// ============================================================================
// 数据模型
// ============================================================================

/// 凭证类型
enum CredentialType {
  /// API Key
  apiKey('api_key'),

  /// Access Token
  accessToken('access_token'),

  /// Refresh Token
  refreshToken('refresh_token'),

  /// Session Cookie
  sessionCookie('session_cookie'),

  /// OAuth Token
  oauthToken('oauth_token'),

  /// 其他
  other('other');

  final String value;
  const CredentialType(this.value);

  static CredentialType fromString(String type) {
    return CredentialType.values.firstWhere(
      (t) => t.value == type,
      orElse: () => CredentialType.other,
    );
  }
}

/// 凭证信息
class Credential {
  /// 凭证类型
  final CredentialType type;

  /// 凭证值
  final String value;

  /// 过期时间（可选）
  final DateTime? expiresAt;

  /// 额外元数据
  final Map<String, dynamic>? metadata;

  /// 创建时间
  final DateTime createdAt;

  Credential({
    required this.type,
    required this.value,
    this.expiresAt,
    this.metadata,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 是否已过期
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// 是否即将过期
  bool isExpiringSoon({Duration threshold = const Duration(minutes: 5)}) {
    if (expiresAt == null) return false;
    return DateTime.now().add(threshold).isAfter(expiresAt!);
  }

  /// 距离过期的时间
  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now());
  }

  /// 序列化
  Map<String, dynamic> toJson() => {
        'type': type.value,
        'value': value,
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
      };

  /// 序列化为 JSON 字符串
  String toJsonString() => jsonEncode(toJson());

  /// 从 JSON 反序列化
  factory Credential.fromJson(Map<String, dynamic> json) {
    return Credential(
      type: CredentialType.fromString(json['type'] as String),
      value: json['value'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// 从 JSON 字符串反序列化
  factory Credential.fromJsonString(String jsonString) {
    return Credential.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

/// 凭证提供者信息
class CredentialProvider {
  /// Provider 唯一标识
  final String id;

  /// 显示名称
  final String name;

  /// 描述
  final String description;

  /// 支持的凭证类型
  final List<CredentialType> supportedTypes;

  /// 图标 URL
  final String? iconUrl;

  /// 配置页面 URL
  final String? configUrl;

  const CredentialProvider({
    required this.id,
    required this.name,
    required this.description,
    this.supportedTypes = const [CredentialType.apiKey],
    this.iconUrl,
    this.configUrl,
  });

  /// 已知的 Provider 列表
  static const List<CredentialProvider> knownProviders = [
    CredentialProvider(
      id: 'openai',
      name: 'OpenAI',
      description: 'GPT-4、GPT-3.5 等模型',
      supportedTypes: [CredentialType.apiKey],
    ),
    CredentialProvider(
      id: 'volcengine',
      name: '火山引擎',
      description: '豆包大模型、TTS 语音合成等',
      supportedTypes: [
        CredentialType.apiKey,
        CredentialType.accessToken,
        CredentialType.refreshToken,
      ],
    ),
    CredentialProvider(
      id: 'orange_ai',
      name: '橘子 AI',
      description: '图像生成、多模态模型',
      supportedTypes: [
        CredentialType.apiKey,
        CredentialType.accessToken,
      ],
    ),
    CredentialProvider(
      id: 'anthropic',
      name: 'Anthropic',
      description: 'Claude 系列模型',
      supportedTypes: [CredentialType.apiKey],
    ),
    CredentialProvider(
      id: 'google',
      name: 'Google AI',
      description: 'Gemini 系列模型',
      supportedTypes: [CredentialType.apiKey],
    ),
    CredentialProvider(
      id: 'deepseek',
      name: 'DeepSeek',
      description: 'DeepSeek 系列模型',
      supportedTypes: [CredentialType.apiKey],
    ),
    CredentialProvider(
      id: 'zhipu',
      name: '智谱 AI',
      description: 'GLM 系列模型',
      supportedTypes: [CredentialType.apiKey],
    ),
    CredentialProvider(
      id: 'web_search',
      name: '联网搜索',
      description: '互联网搜索服务',
      supportedTypes: [CredentialType.apiKey],
    ),
  ];
}

/// Provider 配置信息
class ProviderInfo {
  final CredentialProvider provider;
  final List<CredentialType> configuredTypes;

  const ProviderInfo({
    required this.provider,
    required this.configuredTypes,
  });

  bool get isFullyConfigured {
    return configuredTypes.contains(CredentialType.apiKey);
  }
}

/// 凭证变更事件
class CredentialChangeEvent {
  final String provider;
  final CredentialType type;
  final CredentialAction action;

  const CredentialChangeEvent({
    required this.provider,
    required this.type,
    required this.action,
  });
}

/// 凭证变更动作
enum CredentialAction {
  saved,
  deleted,
  cleared,
  refreshed,
}

/// Token 刷新结果
class TokenRefreshResult {
  final bool success;
  final String? accessToken;
  final DateTime? expiresAt;
  final String? error;

  const TokenRefreshResult({
    required this.success,
    this.accessToken,
    this.expiresAt,
    this.error,
  });
}

/// 新 Token 集合
class _NewTokens {
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  const _NewTokens({
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });
}

// ============================================================================
// 安全存储抽象
// ============================================================================

/// 安全存储接口
/// 实际项目中使用 flutter_secure_storage 实现
abstract class SecureStorage {
  /// 写入键值对
  Future<void> write({required String key, required String value});

  /// 读取值
  Future<String?> read({required String key});

  /// 删除值
  Future<void> delete({required String key});

  /// 删除所有
  Future<void> deleteAll();

  /// 读取所有
  Future<Map<String, String>> readAll();

  /// 检查是否存在
  Future<bool> containsKey({required String key});
}

/// 模拟安全存储实现（开发/测试用）
/// 实际项目中使用 flutter_secure_storage
class MockSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return _store[key];
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.from(_store);
  }

  @override
  Future<bool> containsKey({required String key}) async {
    return _store.containsKey(key);
  }
}

/// Flutter Secure Storage 封装
/// 实际生产环境使用此实现
class FlutterSecureStorageImpl implements SecureStorage {
  // TODO: 实际项目中引入 flutter_secure_storage 包
  // import 'package:flutter_secure_storage/flutter_secure_storage.dart';
  // final _storage = FlutterSecureStorage(
  //   aOptions: AndroidOptions(encryptedSharedPreferences: true),
  //   iOptions: IOSOptions(accountName: 'xiaosu_credentials'),
  // );

  @override
  Future<void> write({required String key, required String value}) async {
    // TODO: await _storage.write(key: key, value: value);
    throw UnimplementedError('请使用 flutter_secure_storage 包实现');
  }

  @override
  Future<String?> read({required String key}) async {
    // TODO: return await _storage.read(key: key);
    throw UnimplementedError('请使用 flutter_secure_storage 包实现');
  }

  @override
  Future<void> delete({required String key}) async {
    // TODO: await _storage.delete(key: key);
    throw UnimplementedError('请使用 flutter_secure_storage 包实现');
  }

  @override
  Future<void> deleteAll() async {
    // TODO: await _storage.deleteAll();
    throw UnimplementedError('请使用 flutter_secure_storage 包实现');
  }

  @override
  Future<Map<String, String>> readAll() async {
    // TODO: return await _storage.readAll();
    throw UnimplementedError('请使用 flutter_secure_storage 包实现');
  }

  @override
  Future<bool> containsKey({required String key}) async {
    // TODO: return await _storage.containsKey(key: key);
    throw UnimplementedError('请使用 flutter_secure_storage 包实现');
  }
}
