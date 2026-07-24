// ============================================================================
// 小酥 - 凭证管理器
// ============================================================================

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 凭证管理器 - 安全存储API Key等敏感信息
class CredentialManager {
  static final CredentialManager instance = CredentialManager._();
  CredentialManager._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _keyPrefix = 'xiaosu_cred_';

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
}
