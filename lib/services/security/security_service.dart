// ============================================================================
// 小酥 - 安全服务
// ============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// 安全服务 - 加密/解密/校验
class SecurityService {
  static final SecurityService instance = SecurityService._();
  SecurityService._();

  // AES加密密钥（实际应用应从安全存储获取）
  static final _key = Key.fromUtf8('xiaosu2024secret');
  static final _iv = IV.fromLength(16);
  late final _encrypter = Encrypter(AES(_key, mode: AESMode.cbc));

  /// 加密文本
  String encrypt(String plainText) {
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (_) {
      return plainText;
    }
  }

  /// 解密文本
  String decrypt(String encryptedText) {
    try {
      final decrypted = _encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (_) {
      return encryptedText;
    }
  }

  /// SHA256哈希
  String sha256Hash(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// 验证输入安全性（防止注入）
  bool isSafe(String input) {
    // 简单的安全检查
    final dangerous = ['<script', 'javascript:', 'onerror=', 'onload='];
    final lower = input.toLowerCase();
    return !dangerous.any((d) => lower.contains(d));
  }

  /// 过滤危险字符
  String sanitize(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }
}
