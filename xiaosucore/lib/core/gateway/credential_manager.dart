// ============================================================================
// 小酥 - 凭证管理器
// Phase 1: 增加 Coze Studio Session Token + PAT Token 管理
// ============================================================================

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 凭证管理器 - 安全存储API Key等敏感信息
class CredentialManager {
  static final CredentialManager instance = CredentialManager._();
  CredentialManager._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _keyPrefix = 'xiaosu_cred_';

  // Coze Studio 专用 key 常量
  static const String _cozePatTokenKey = 'coze_pat_token';
  static const String _cozeSessionKey = 'coze_session_key';
  static const String _cozeUserIdKey = 'coze_user_id';
  static const String _cozeSpaceIdKey = 'coze_space_id';

  // ==========================================================================
  // 通用凭证操作
  // ==========================================================================

  /// 保存凭证
  Future<void> saveCredential(String key, String value) async {
    await _storage.write(key: '$_keyPrefix$key', value: value);
  }

  /// 获取凭证
  Future<String?> getCredential(String key) async {
    return await _storage.read(key: '$_keyPrefix$key');
  }

  /// 删除凭证
  Future<void> deleteCredential(String key) async {
    await _storage.delete(key: '$_keyPrefix$key');
  }

  /// 保存API Key
  Future<void> saveApiKey(String provider, String apiKey) async {
    await saveCredential('api_key_$provider', apiKey);
  }

  /// 获取API Key
  Future<String?> getApiKey(String provider) async {
    return await getCredential('api_key_$provider');
  }

  /// 获取所有已存储的Key名称
  Future<List<String>> getAllKeys() async {
    final all = await _storage.readAll();
    return all.keys
        .where((k) => k.startsWith(_keyPrefix))
        .map((k) => k.substring(_keyPrefix.length))
        .toList();
  }

  /// 清除所有凭证
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// 检查是否有指定凭证
  Future<bool> hasCredential(String key) async {
    final value = await getCredential(key);
    return value != null && value.isNotEmpty;
  }

  // ==========================================================================
  // Coze Studio 认证管理
  // ==========================================================================

  /// 保存 Coze Studio PAT Token
  Future<void> saveCozePatToken(String token) async {
    await _storage.write(key: '$_keyPrefix$_cozePatTokenKey', value: token);
  }

  /// 获取 Coze Studio PAT Token
  Future<String?> getCozePatToken() async {
    return await _storage.read(key: '$_keyPrefix$_cozePatTokenKey');
  }

  /// 删除 Coze Studio PAT Token
  Future<void> deleteCozePatToken() async {
    await _storage.delete(key: '$_keyPrefix$_cozePatTokenKey');
  }

  /// 保存 Coze Studio Session Key
  Future<void> saveCozeSessionKey(String sessionKey) async {
    await _storage.write(key: '$_keyPrefix$_cozeSessionKey', value: sessionKey);
  }

  /// 获取 Coze Studio Session Key
  Future<String?> getCozeSessionKey() async {
    return await _storage.read(key: '$_keyPrefix$_cozeSessionKey');
  }

  /// 删除 Coze Studio Session Key
  Future<void> deleteCozeSessionKey() async {
    await _storage.delete(key: '$_keyPrefix$_cozeSessionKey');
  }

  /// 保存 Coze Studio 用户 ID
  Future<void> saveCozeUserId(String userId) async {
    await _storage.write(key: '$_keyPrefix$_cozeUserIdKey', value: userId);
  }

  /// 获取 Coze Studio 用户 ID
  Future<String?> getCozeUserId() async {
    return await _storage.read(key: '$_keyPrefix$_cozeUserIdKey');
  }

  /// 保存 Coze Studio 工作空间 ID
  Future<void> saveCozeSpaceId(String spaceId) async {
    await _storage.write(key: '$_keyPrefix$_cozeSpaceIdKey', value: spaceId);
  }

  /// 获取 Coze Studio 工作空间 ID
  Future<String?> getCozeSpaceId() async {
    return await _storage.read(key: '$_keyPrefix$_cozeSpaceIdKey');
  }

  /// 检查是否已配置 Coze Studio 认证（PAT 或 Session 任一即可）
  Future<bool> hasCozeAuth() async {
    final pat = await getCozePatToken();
    final session = await getCozeSessionKey();
    return (pat != null && pat.isNotEmpty) || (session != null && session.isNotEmpty);
  }

  /// 清除所有 Coze Studio 相关凭证
  Future<void> clearCozeAuth() async {
    await deleteCozePatToken();
    await deleteCozeSessionKey();
    await _storage.delete(key: '$_keyPrefix$_cozeUserIdKey');
    await _storage.delete(key: '$_keyPrefix$_cozeSpaceIdKey');
  }
}
