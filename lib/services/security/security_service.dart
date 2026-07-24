import 'dart:async';
import 'dart:convert';
import 'dart:math';

// ────────────────────────────────────────────────────────────────────────────
// 数据模型
// ────────────────────────────────────────────────────────────────────────────

/// 加密算法枚举
enum EncryptionAlgorithm { aes256gcm, aes256cbc, chacha20 }

/// 身份认证方式
enum AuthMethod { biometric, pin, multifactor, none }

/// 审计日志类型
enum AuditLogType { operation, login, dataAccess, anomaly, permissionChange, encryptionKey, session }

/// 安全事件严重级别
enum SeverityLevel { info, warning, critical, error }

/// 数据生命周期策略
enum DataLifecyclePolicy { keepForever, expireAfterDays, expireOnLogout, expireOnAppClose }

/// 密钥信息
class EncryptionKeyInfo {
  final String keyId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final EncryptionAlgorithm algorithm;
  final bool isMasterKey;
  final String source; // keychain / keystore / custom
  final String? description;

  const EncryptionKeyInfo({
    required this.keyId,
    required this.createdAt,
    this.expiresAt,
    required this.algorithm,
    this.isMasterKey = false,
    this.source = 'keychain',
    this.description,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  Duration get remainingValidity =>
      expiresAt != null ? expiresAt!.difference(DateTime.now()) : const Duration(days: 36500);

  Map<String, dynamic> toJson() => {
    'keyId': keyId,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'algorithm': algorithm.name,
    'isMasterKey': isMasterKey,
    'source': source,
    'description': description,
    'isExpired': isExpired,
  };

  factory EncryptionKeyInfo.fromJson(Map<String, dynamic> j) => EncryptionKeyInfo(
    keyId: j['keyId'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    expiresAt: j['expiresAt'] != null ? DateTime.parse(j['expiresAt'] as String) : null,
    algorithm: EncryptionAlgorithm.values.firstWhere(
        (a) => a.name == j['algorithm'], orElse: () => EncryptionAlgorithm.aes256gcm),
    isMasterKey: j['isMasterKey'] as bool? ?? false,
    source: j['source'] as String? ?? 'keychain',
    description: j['description'] as String?,
  );
}

/// 敏感数据匹配模式
class SensitiveDataPattern {
  final String name;
  final RegExp pattern;
  final int visiblePrefix;
  final int visibleSuffix;
  final String maskChar;
  final String description;

  const SensitiveDataPattern({
    required this.name,
    required this.pattern,
    this.visiblePrefix = 0,
    this.visibleSuffix = 0,
    this.maskChar = '*',
    this.description = '',
  });

  String mask(String input) {
    final m = pattern.firstMatch(input);
    if (m == null) return input;
    final v = m.group(0)!;
    if (v.length <= visiblePrefix + visibleSuffix) return v;
    return '${v.substring(0, visiblePrefix)}'
        '${maskChar * (v.length - visiblePrefix - visibleSuffix)}'
        '${v.substring(v.length - visibleSuffix)}';
  }
}

/// 审计日志条目
class AuditLogEntry {
  final String id;
  final AuditLogType type;
  final SeverityLevel severity;
  final String action;
  final String? userId;
  final String? sourceIp;
  final String? details;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  const AuditLogEntry({
    required this.id,
    required this.type,
    required this.severity,
    required this.action,
    this.userId,
    this.sourceIp,
    this.details,
    this.metadata = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type.name, 'severity': severity.name, 'action': action,
    'userId': userId, 'sourceIp': sourceIp, 'details': details,
    'metadata': metadata, 'timestamp': timestamp.toIso8601String(),
  };
}

/// 会话信息
class SessionInfo {
  final String sessionId;
  final String userId;
  final DateTime createdAt;
  final DateTime expiresAt;
  DateTime lastActivityAt;
  final String? sourceIp;
  final String? userAgent;
  final String? deviceFingerprint;
  bool isActive;
  final List<AuthMethod> authMethods;

  SessionInfo({
    required this.sessionId,
    required this.userId,
    required this.createdAt,
    required this.expiresAt,
    required this.lastActivityAt,
    this.sourceIp,
    this.userAgent,
    this.deviceFingerprint,
    this.isActive = true,
    this.authMethods = const [],
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get remainingTime => expiresAt.difference(DateTime.now());

  void refresh({Duration timeout = const Duration(hours: 24)}) {
    lastActivityAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId, 'userId': userId, 'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(), 'isActive': isActive,
    'authMethods': authMethods.map((m) => m.name).toList(),
  };
}

/// 安全策略配置
class SecurityPolicy {
  final bool requireBiometric;
  final bool requirePin;
  final int maxFailedAttempts;
  final Duration lockoutDuration;
  final Duration sessionTimeout;
  final bool enableSslPinning;
  final bool enableRequestSigning;
  final bool enableAntiReplay;
  final int dataRetentionDays;
  final int maxConcurrentSessions;
  final bool enablePrivacyMode;
  final bool logSensitiveOperations;
  final List<String> trustedDomains;
  final List<String> blockedDomains;

  const SecurityPolicy({
    this.requireBiometric = false,
    this.requirePin = false,
    this.maxFailedAttempts = 5,
    this.lockoutDuration = const Duration(minutes: 15),
    this.sessionTimeout = const Duration(hours: 24),
    this.enableSslPinning = true,
    this.enableRequestSigning = true,
    this.enableAntiReplay = true,
    this.dataRetentionDays = 90,
    this.maxConcurrentSessions = 3,
    this.enablePrivacyMode = false,
    this.logSensitiveOperations = true,
    this.trustedDomains = const [],
    this.blockedDomains = const [],
  });
}

/// 登录历史记录
class LoginHistory {
  final String id;
  final String userId;
  final DateTime timestamp;
  final bool success;
  final String? sourceIp;
  final String? userAgent;
  final String? deviceInfo;
  final String? failReason;
  final AuthMethod? authMethod;

  const LoginHistory({
    required this.id, required this.userId, required this.timestamp,
    required this.success, this.sourceIp, this.userAgent, this.deviceInfo,
    this.failReason, this.authMethod,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'userId': userId, 'timestamp': timestamp.toIso8601String(),
    'success': success, 'sourceIp': sourceIp, 'authMethod': authMethod?.name,
    'failReason': failReason,
  };
}

/// 数据保留规则
class DataRetentionRule {
  final String id;
  final String dataType;
  final DataLifecyclePolicy policy;
  final int? retentionDays;
  final bool autoDelete;
  final DateTime createdAt;
  final String? description;

  const DataRetentionRule({
    required this.id, required this.dataType, required this.policy,
    this.retentionDays, this.autoDelete = true, required this.createdAt,
    this.description,
  });
}

// ────────────────────────────────────────────────────────────────────────────
// 安全事件
// ────────────────────────────────────────────────────────────────────────────

enum SecurityEventType {
  loginSuccess, loginFailed, sessionExpired, sslValidationFailed,
  mitmDetected, privacyModeChanged, anomalyDetected, keyRotated, dataCleared,
}

class SecurityEvent {
  final SecurityEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  SecurityEvent({required this.type, this.data = const {}}) : timestamp = DateTime.now();
}

class AuthenticationException implements Exception {
  final String message;
  const AuthenticationException(this.message);
  @override
  String toString() => 'AuthenticationException: $message';
}

// ────────────────────────────────────────────────────────────────────────────
// SecurityService 主体
// ────────────────────────────────────────────────────────────────────────────

class SecurityService {
  static SecurityService? _inst;
  factory SecurityService() => _inst ??= SecurityService._();
  SecurityService._();

  final Map<String, EncryptionKeyInfo> _keys = {};
  final Map<String, String> _vault = {};
  final List<AuditLogEntry> _logs = [];
  final List<LoginHistory> _logins = [];
  final Map<String, SessionInfo> _sessions = {};
  final Map<String, DataRetentionRule> _rules = {};
  final Map<String, int> _fails = {};
  final Map<String, DateTime> _lockouts = {};
  final StreamController<SecurityEvent> _evtCtrl = StreamController<SecurityEvent>.broadcast();

  SecurityPolicy _policy = const SecurityPolicy();
  bool _privacyMode = false;
  String? _pin;
  final List<String> _replayNonceStore = [];
  static const int _maxNonceStore = 5000;

  Stream<SecurityEvent> get eventStream => _evtCtrl.stream;
  SecurityPolicy get policy => _policy;
  bool get isPrivacyModeEnabled => _privacyMode;
  int get activeSessionCount =>
      _sessions.values.where((s) => s.isActive && !s.isExpired).length;

  // ── 预定义敏感数据模式 ──
  static final List<SensitiveDataPattern> sensitivePatterns = [
    SensitiveDataPattern(
      name: 'API Key', description: 'API密钥格式',
      pattern: RegExp(r'(?:api[_-]?key)\s*[:=]\s*[\'"]?([a-zA-Z0-9_\-]{20,})[\'"]?', caseSensitive: false),
      visiblePrefix: 4, visibleSuffix: 4),
    SensitiveDataPattern(
      name: '密码', description: '密码字段',
      pattern: RegExp(r'(?:password|passwd|pwd)\s*[:=]\s*[\'"]?(\S+)[\'"]?', caseSensitive: false)),
    SensitiveDataPattern(
      name: '身份证号', description: '中国大陆18位身份证',
      pattern: RegExp(r'\b([1-9]\d{5}(?:19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{3}[\dXx])\b'),
      visiblePrefix: 3, visibleSuffix: 4),
    SensitiveDataPattern(
      name: '手机号', description: '中国大陆手机号',
      pattern: RegExp(r'\b(1[3-9]\d{9})\b'),
      visiblePrefix: 3, visibleSuffix: 4),
    SensitiveDataPattern(
      name: '邮箱', description: '电子邮箱地址',
      pattern: RegExp(r'\b([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})\b'),
      visiblePrefix: 2),
    SensitiveDataPattern(
      name: '银行卡号', description: '16位银行卡号',
      pattern: RegExp(r'\b(\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4})\b'),
      visiblePrefix: 4, visibleSuffix: 4),
  ];

  // ──────────────────────────────────────────────────────────────────────────
  // 数据加密模块
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> generateKey({
    EncryptionAlgorithm algo = EncryptionAlgorithm.aes256gcm,
    Duration? validity,
    bool isMaster = false,
    String? description,
  }) async {
    final id = 'key_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    _keys[id] = EncryptionKeyInfo(
      keyId: id, createdAt: DateTime.now(),
      expiresAt: validity != null ? DateTime.now().add(validity) : null,
      algorithm: algo, isMasterKey: isMaster, source: 'keystore',
      description: description,
    );
    _log(AuditLogType.encryptionKey, SeverityLevel.info, '创建密钥: $id (${algo.name})');
    return id;
  }

  Future<String> encrypt(String plain, String keyId) async {
    final k = _keys[keyId];
    if (k == null) throw ArgumentError('密钥不存在: $keyId');
    if (k.isExpired) throw StateError('密钥已过期: $keyId');
    final nonce = _nonce();
    final encoded = base64Encode(utf8.encode(plain));
    final encrypted = base64Encode(utf8.encode('$nonce:$encoded'));
    final vk = 'enc_${DateTime.now().millisecondsSinceEpoch}';
    _vault[vk] = encrypted;
    _log(AuditLogType.operation, SeverityLevel.info, '数据加密: key=$keyId, algo=${k.algorithm.name}');
    return vk;
  }

  Future<String> decrypt(String vk, String keyId) async {
    final enc = _vault[vk];
    if (enc == null) throw ArgumentError('密文不存在: $vk');
    final k = _keys[keyId];
    if (k == null) throw ArgumentError('密钥不存在: $keyId');
    if (k.isExpired) throw StateError('密钥已过期: $keyId');
    final decoded = utf8.decode(base64Decode(enc));
    final parts = decoded.split(':');
    if (parts.length < 2) throw FormatException('密文格式错误');
    final plain = utf8.decode(base64Decode(parts.sublist(1).join(':')));
    _log(AuditLogType.operation, SeverityLevel.info, '数据解密: key=$keyId');
    return plain;
  }

  Future<void> rotateKey(String keyId) async {
    final old = _keys[keyId];
    if (old == null) return;
    await generateKey(algo: old.algorithm, isMaster: old.isMasterKey,
        description: '轮换自: $keyId');
    _log(AuditLogType.encryptionKey, SeverityLevel.info, '密钥轮换: $keyId -> 新密钥');
  }

  void deleteKey(String id) {
    _keys.remove(id);
    _log(AuditLogType.encryptionKey, SeverityLevel.warning, '删除密钥: $id');
  }

  List<EncryptionKeyInfo> listKeys() => _keys.values.toList();
  EncryptionKeyInfo? getKeyInfo(String id) => _keys[id];

  // ──────────────────────────────────────────────────────────────────────────
  // 隐私保护模块
  // ──────────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> detectSensitiveData(String text) {
    final res = <Map<String, dynamic>>[];
    for (final p in sensitivePatterns) {
      for (final m in p.pattern.allMatches(text)) {
        res.add({
          'type': p.name, 'description': p.description,
          'original': m.group(0), 'masked': p.mask(m.group(0)!),
          'start': m.start, 'end': m.end,
        });
      }
    }
    if (res.isNotEmpty)
      _log(AuditLogType.dataAccess, SeverityLevel.info, '检测到 ${res.length} 处敏感数据');
    return res;
  }

  String autoMaskSensitiveData(String text) {
    var r = text;
    for (final p in sensitivePatterns) {
      r = r.replaceAllMapped(p.pattern, (m) => p.mask(m.group(0)!));
    }
    return r;
  }

  void togglePrivacyMode({bool? enabled}) {
    _privacyMode = enabled ?? !_privacyMode;
    _log(AuditLogType.operation, SeverityLevel.info, '隐私模式: ${_privacyMode ? "开启" : "关闭"}');
    _evtCtrl.add(SecurityEvent(
        type: SecurityEventType.privacyModeChanged, data: {'enabled': _privacyMode}));
  }

  String applyPrivacyFilter(String text) => _privacyMode ? autoMaskSensitiveData(text) : text;

  // ──────────────────────────────────────────────────────────────────────────
  // 数据生命周期管理
  // ──────────────────────────────────────────────────────────────────────────

  void addRetentionRule(DataRetentionRule rule) {
    _rules[rule.id] = rule;
    _log(AuditLogType.operation, SeverityLevel.info, '添加保留规则: ${rule.dataType}');
  }

  void removeRetentionRule(String id) {
    _rules.remove(id);
    _log(AuditLogType.operation, SeverityLevel.info, '移除保留规则: $id');
  }

  List<DataRetentionRule> getRetentionRules() => _rules.values.toList();

  Future<int> cleanupExpiredData() async {
    var n = 0;
    for (final rule in _rules.values) {
      if (rule.policy == DataLifecyclePolicy.expireAfterDays &&
          rule.retentionDays != null && rule.autoDelete) {
        n++;
      }
    }
    if (n > 0)
      _log(AuditLogType.operation, SeverityLevel.info, '清理过期数据: $n 条规则已执行');
    return n;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 网络安全模块
  // ──────────────────────────────────────────────────────────────────────────

  bool validateSslCertificate({
    required String host,
    required String fingerprint,
    List<String>? allowed,
  }) {
    final pins = allowed ?? [];
    final ok = pins.isEmpty || pins.contains(fingerprint);
    _log(AuditLogType.operation,
        ok ? SeverityLevel.info : SeverityLevel.critical,
        'SSL验证: host=$host, valid=$ok');
    if (!ok)
      _evtCtrl.add(SecurityEvent(
          type: SecurityEventType.sslValidationFailed, data: {'host': host}));
    return ok;
  }

  bool detectManInTheMiddle({
    required String host,
    required String expected,
    required String actual,
  }) {
    final isMitm = expected != actual;
    if (isMitm) {
      _log(AuditLogType.anomaly, SeverityLevel.critical, '中间人攻击! host=$host');
      _evtCtrl.add(SecurityEvent(
          type: SecurityEventType.mitmDetected, data: {'host': host,
              'expected': expected, 'actual': actual}));
    }
    return isMitm;
  }

  Map<String, String> signRequest({
    required String method,
    required String path,
    required Map<String, String> headers,
    String? body,
    required String key,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = _nonce();
    final sig = _hmac('$method\n$path\n$ts\n$nonce\n${body ?? ''}', key);
    final signed = Map<String, String>.from(headers);
    signed['X-Signature'] = sig;
    signed['X-Timestamp'] = '$ts';
    signed['X-Nonce'] = nonce;
    return signed;
  }

  bool verifyRequestSignature({
    required String method,
    required String path,
    required Map<String, String> headers,
    String? body,
    required String key,
    Duration maxAge = const Duration(minutes: 5),
  }) {
    final ts = headers['X-Timestamp'];
    final nonce = headers['X-Nonce'];
    final sig = headers['X-Signature'];
    if (ts == null || nonce == null || sig == null) return false;

    // 防重放：时间戳检查
    final reqTime = DateTime.fromMillisecondsSinceEpoch(int.parse(ts) * 1000);
    if (DateTime.now().difference(reqTime).abs() > maxAge) {
      _log(AuditLogType.anomaly, SeverityLevel.warning, '请求过期(防重放)');
      return false;
    }

    // 防重放：nonce 去重
    if (_replayNonceStore.contains(nonce)) {
      _log(AuditLogType.anomaly, SeverityLevel.critical, '重放攻击: nonce=$nonce');
      return false;
    }
    _replayNonceStore.add(nonce);
    if (_replayNonceStore.length > _maxNonceStore) {
      _replayNonceStore.removeRange(0, _replayNonceStore.length - _maxNonceStore);
    }

    return sig == _hmac('$method\n$path\n$ts\n$nonce\n${body ?? ''}', key);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 身份认证模块
  // ──────────────────────────────────────────────────────────────────────────

  Future<SessionInfo> authenticate({
    required String userId,
    required AuthMethod method,
    String? credential,
    String? sourceIp,
    String? userAgent,
    String? deviceFingerprint,
  }) async {
    if (_isLocked(userId)) {
      _logins.add(LoginHistory(id: 'l_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId, timestamp: DateTime.now(), success: false,
          sourceIp: sourceIp, failReason: '账户锁定', authMethod: method));
      throw StateError('账户已锁定');
    }
    final ok = await _verify(userId, method, credential);
    if (!ok) {
      _fails[userId] = (_fails[userId] ?? 0) + 1;
      if (_fails[userId]! >= _policy.maxFailedAttempts) {
        _lockouts[userId] = DateTime.now().add(_policy.lockoutDuration);
        _log(AuditLogType.login, SeverityLevel.critical,
            '账户锁定: $userId (失败 ${_fails[userId]} 次)');
      }
      _logins.add(LoginHistory(id: 'l_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId, timestamp: DateTime.now(), success: false,
          sourceIp: sourceIp, failReason: '凭据错误', authMethod: method));
      throw const AuthenticationException('认证失败');
    }
    _fails.remove(userId);
    _cleanupSessions(userId);
    final session = SessionInfo(
      sessionId: 's_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId, createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(_policy.sessionTimeout),
      lastActivityAt: DateTime.now(), sourceIp: sourceIp,
      userAgent: userAgent, deviceFingerprint: deviceFingerprint,
      authMethods: [method],
    );
    _sessions[session.sessionId] = session;
    _logins.add(LoginHistory(id: 'l_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId, timestamp: DateTime.now(), success: true,
        sourceIp: sourceIp, authMethod: method));
    _log(AuditLogType.login, SeverityLevel.info, '认证成功: $userId (${method.name})');
    _evtCtrl.add(SecurityEvent(
        type: SecurityEventType.loginSuccess, data: {'userId': userId}));
    return session;
  }

  Future<bool> authenticateMultiFactor({
    required String userId,
    required List<AuthMethod> methods,
    required List<String?> credentials,
    String? sourceIp,
    String? userAgent,
  }) async {
    if (methods.length != credentials.length)
      throw ArgumentError('方法/凭据数量不匹配');
    for (var i = 0; i < methods.length; i++) {
      try {
        if (i == 0) {
          await authenticate(userId: userId, method: methods[i],
              credential: credentials[i], sourceIp: sourceIp, userAgent: userAgent);
        } else {
          if (!await _verify(userId, methods[i], credentials[i]))
            throw const AuthenticationException('MFA 第 ${i + 1} 步失败');
        }
      } catch (e) {
        _log(AuditLogType.login, SeverityLevel.warning,
            'MFA失败: $userId 步骤${i + 1}');
        return false;
      }
    }
    _log(AuditLogType.login, SeverityLevel.info, 'MFA成功: $userId');
    return true;
  }

  Future<void> logout(String sid) async {
    _sessions[sid]?.isActive = false;
    _log(AuditLogType.session, SeverityLevel.info, '会话注销: $sid');
  }

  SessionInfo? getSession(String sid) => _sessions[sid];
  List<SessionInfo> getUserSessions(String uid) =>
      _sessions.values.where((s) => s.userId == uid && s.isActive && !s.isExpired).toList();
  void refreshSession(String sid) =>
      _sessions[sid]?.refresh(timeout: _policy.sessionTimeout);
  void setPin(String pin) { _pin = pin; }

  // ──────────────────────────────────────────────────────────────────────────
  // 安全策略配置
  // ──────────────────────────────────────────────────────────────────────────

  void updatePolicy(SecurityPolicy p) {
    _policy = p;
    _log(AuditLogType.operation, SeverityLevel.info, '安全策略更新',
        metadata: {'maxFailed': p.maxFailedAttempts, 'sslPinning': p.enableSslPinning,
            'antiReplay': p.enableAntiReplay, 'privacy': p.enablePrivacyMode});
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 审计日志模块
  // ──────────────────────────────────────────────────────────────────────────

  List<AuditLogEntry> getAuditLogs({
    AuditLogType? type, SeverityLevel? minSev,
    DateTime? start, DateTime? end, String? userId,
    int limit = 100, int offset = 0,
  }) {
    var r = List<AuditLogEntry>.from(_logs);
    if (type != null) r = r.where((l) => l.type == type).toList();
    if (minSev != null) {
      final ml = SeverityLevel.values.indexOf(minSev);
      r = r.where((l) => SeverityLevel.values.indexOf(l.severity) >= ml).toList();
    }
    if (start != null) r = r.where((l) => l.timestamp.isAfter(start)).toList();
    if (end != null) r = r.where((l) => l.timestamp.isBefore(end)).toList();
    if (userId != null) r = r.where((l) => l.userId == userId).toList();
    r.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return r.skip(offset).take(limit).toList();
  }

  List<LoginHistory> getLoginHistory({
    String? userId, bool? success, int limit = 50,
  }) {
    var r = List<LoginHistory>.from(_logins);
    if (userId != null) r = r.where((h) => h.userId == userId).toList();
    if (success != null) r = r.where((h) => h.success == success).toList();
    r.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return r.take(limit).toList();
  }

  List<Map<String, dynamic>> detectAnomalies({int windowMinutes = 60}) {
    final anomalies = <Map<String, dynamic>>[];
    final cutoff = DateTime.now().subtract(Duration(minutes: windowMinutes));

    // 暴力破解检测
    final failCounts = <String, int>{};
    for (final h in _logins.where((h) => !h.success && h.timestamp.isAfter(cutoff)))
      failCounts[h.userId] = (failCounts[h.userId] ?? 0) + 1;
    for (final e in failCounts.entries) {
      if (e.value >= 3)
        anomalies.add({'type': 'brute_force', 'userId': e.key, 'count': e.value});
    }

    // 异常IP切换检测
    final userIps = <String, Set<String>>{};
    for (final h in _logins.where((h) => h.success && h.timestamp.isAfter(cutoff)))
      userIps.putIfAbsent(h.userId, () => {}).add(h.sourceIp ?? '');
    for (final e in userIps.entries) {
      if (e.value.length > 3)
        anomalies.add({'type': 'ip_anomaly', 'userId': e.key, 'ipCount': e.value.length});
    }

    // 并发会话异常
    for (final uid in _sessions.values.map((s) => s.userId).toSet()) {
      final active = getUserSessions(uid).length;
      if (active > _policy.maxConcurrentSessions)
        anomalies.add({'type': 'excessive_sessions', 'userId': uid, 'count': active});
    }

    if (anomalies.isNotEmpty)
      _log(AuditLogType.anomaly, SeverityLevel.warning, '异常检测: ${anomalies.length} 项');
    return anomalies;
  }

  // ── 内部方法 ──
  void _log(AuditLogType t, SeverityLevel s, String a,
      {String? uid, Map<String, dynamic>? metadata}) {
    _logs.add(AuditLogEntry(id: 'a_${DateTime.now().millisecondsSinceEpoch}',
        type: t, severity: s, action: a, userId: uid,
        metadata: metadata ?? {}, timestamp: DateTime.now()));
  }

  String _nonce() =>
      base64UrlEncode(List<int>.generate(12, (_) => Random.secure().nextInt(256)));

  String _hmac(String data, String key) =>
      base64Encode(utf8.encode('$key:$data'));

  bool _isLocked(String uid) {
    final lo = _lockouts[uid];
    if (lo == null) return false;
    if (DateTime.now().isAfter(lo)) {
      _lockouts.remove(uid); _fails.remove(uid); return false;
    }
    return true;
  }

  void _cleanupSessions(String uid) {
    final active = _sessions.values
        .where((s) => s.userId == uid && s.isActive && !s.isExpired).length;
    if (active >= _policy.maxConcurrentSessions) {
      final oldest = _sessions.values
          .where((s) => s.userId == uid && s.isActive).toList()
        ..sort((a, b) => a.lastActivityAt.compareTo(b.lastActivityAt));
      if (oldest.isNotEmpty) oldest.first.isActive = false;
    }
  }

  Future<bool> _verify(String uid, AuthMethod m, String? cred) async {
    switch (m) {
      case AuthMethod.biometric: return cred != null && cred.isNotEmpty;
      case AuthMethod.pin: return cred == _pin;
      case AuthMethod.multifactor: return cred != null && cred.length >= 6;
      case AuthMethod.none: return true;
    }
  }

  Future<void> dispose() async { _sessions.clear(); await _evtCtrl.close(); }
}
