// ============================================================================
// 小酥 AI 助手 - 邮件技能
// ============================================================================
// 提供邮件收发、管理、自动回复、模板引擎、联系人管理等功能
// 支持 SMTP/IMAP 协议、多账号、附件处理、邮件分类
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../core/skill/skill.dart';

// ============================================================================
// 数据模型
// ============================================================================

/// 邮件账号配置
class EmailAccount {
  final String id;
  final String emailAddress;
  final String displayName;
  final String smtpHost;
  final int smtpPort;
  final String imapHost;
  final int imapPort;
  final String username;
  final String password;
  final bool useSsl;
  final bool isDefault;
  final String signature;

  const EmailAccount({
    required this.id,
    required this.emailAddress,
    required this.displayName,
    required this.smtpHost,
    this.smtpPort = 465,
    required this.imapHost,
    this.imapPort = 993,
    required this.username,
    required this.password,
    this.useSsl = true,
    this.isDefault = false,
    this.signature = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': emailAddress,
    'display_name': displayName,
    'smtp_host': smtpHost,
    'smtp_port': smtpPort,
    'imap_host': imapHost,
    'imap_port': imapPort,
    'username': username,
    'use_ssl': useSsl,
    'is_default': isDefault,
    'signature': signature,
  };

  factory EmailAccount.fromJson(Map<String, dynamic> json) => EmailAccount(
    id: json['id'] as String,
    emailAddress: json['email'] as String,
    displayName: json['display_name'] as String? ?? '',
    smtpHost: json['smtp_host'] as String,
    smtpPort: json['smtp_port'] as int? ?? 465,
    imapHost: json['imap_host'] as String,
    imapPort: json['imap_port'] as int? ?? 993,
    username: json['username'] as String,
    password: json['password'] as String? ?? '',
    useSsl: json['use_ssl'] as bool? ?? true,
    isDefault: json['is_default'] as bool? ?? false,
    signature: json['signature'] as String? ?? '',
  );
}

/// 邮件地址
class EmailAddress {
  final String name;
  final String address;

  const EmailAddress({required this.address, this.name = ''});

  @override
  String toString() => name.isNotEmpty ? '$name <$address>' : address;

  Map<String, dynamic> toJson() => {'name': name, 'address': address};

  factory EmailAddress.fromJson(Map<String, dynamic> json) => EmailAddress(
    address: json['address'] as String,
    name: json['name'] as String? ?? '',
  );
}

/// 邮件附件
class EmailAttachment {
  final String filename;
  final String mimeType;
  final Uint8List data;
  final int size;
  final String? contentId;

  const EmailAttachment({
    required this.filename,
    required this.mimeType,
    required this.data,
    required this.size,
    this.contentId,
  });

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'mime_type': mimeType,
    'size': size,
    'content_id': contentId,
  };
}

/// 邮件消息
class EmailMessage {
  final String messageId;
  final EmailAddress from;
  final List<EmailAddress> to;
  final List<EmailAddress> cc;
  final List<EmailAddress> bcc;
  final String subject;
  final String textBody;
  final String? htmlBody;
  final DateTime date;
  final List<EmailAttachment> attachments;
  final List<String> labels;
  final bool isRead;
  final bool isStarred;
  final String? inReplyTo;
  final String? accountId;
  final Map<String, String> headers;

  const EmailMessage({
    required this.messageId,
    required this.from,
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    required this.subject,
    this.textBody = '',
    this.htmlBody,
    required this.date,
    this.attachments = const [],
    this.labels = const [],
    this.isRead = false,
    this.isStarred = false,
    this.inReplyTo,
    this.accountId,
    this.headers = const {},
  });

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'from': from.toJson(),
    'to': to.map((e) => e.toJson()).toList(),
    'cc': cc.map((e) => e.toJson()).toList(),
    'subject': subject,
    'text_body': textBody,
    'html_body': htmlBody,
    'date': date.toIso8601String(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'labels': labels,
    'is_read': isRead,
    'is_starred': isStarred,
    'in_reply_to': inReplyTo,
    'account_id': accountId,
  };

  factory EmailMessage.fromJson(Map<String, dynamic> json) => EmailMessage(
    messageId: json['message_id'] as String,
    from: EmailAddress.fromJson(json['from'] as Map<String, dynamic>),
    to: (json['to'] as List?)
        ?.map((e) => EmailAddress.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    cc: (json['cc'] as List?)
        ?.map((e) => EmailAddress.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    subject: json['subject'] as String,
    textBody: json['text_body'] as String? ?? '',
    htmlBody: json['html_body'] as String?,
    date: DateTime.parse(json['date'] as String),
    labels: (json['labels'] as List?)?.cast<String>() ?? [],
    isRead: json['is_read'] as bool? ?? false,
    isStarred: json['is_starred'] as bool? ?? false,
    inReplyTo: json['in_reply_to'] as String?,
    accountId: json['account_id'] as String?,
  );
}

/// 联系人
class EmailContact {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? company;
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastContactedAt;
  final int contactCount;

  const EmailContact({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.company,
    this.notes,
    required this.createdAt,
    this.lastContactedAt,
    this.contactCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'company': company,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'last_contacted_at': lastContactedAt?.toIso8601String(),
    'contact_count': contactCount,
  };

  factory EmailContact.fromJson(Map<String, dynamic> json) => EmailContact(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    company: json['company'] as String?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    lastContactedAt: json['last_contacted_at'] != null
        ? DateTime.parse(json['last_contacted_at'] as String) : null,
    contactCount: json['contact_count'] as int? ?? 0,
  );
}

/// 自动回复规则
class AutoReplyRule {
  final String id;
  final String name;
  final bool enabled;
  final List<String> senderPatterns;
  final List<String> subjectPatterns;
  final String? labelFilter;
  final String replyTemplateId;
  final String replySubject;
  final String replyBody;
  final int cooldownMinutes;
  final DateTime? lastTriggeredAt;

  const AutoReplyRule({
    required this.id,
    required this.name,
    this.enabled = true,
    this.senderPatterns = const [],
    this.subjectPatterns = const [],
    this.labelFilter,
    required this.replyTemplateId,
    required this.replySubject,
    required this.replyBody,
    this.cooldownMinutes = 60,
    this.lastTriggeredAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'sender_patterns': senderPatterns,
    'subject_patterns': subjectPatterns,
    'label_filter': labelFilter,
    'reply_template_id': replyTemplateId,
    'reply_subject': replySubject,
    'reply_body': replyBody,
    'cooldown_minutes': cooldownMinutes,
    'last_triggered_at': lastTriggeredAt?.toIso8601String(),
  };

  factory AutoReplyRule.fromJson(Map<String, dynamic> json) => AutoReplyRule(
    id: json['id'] as String,
    name: json['name'] as String,
    enabled: json['enabled'] as bool? ?? true,
    senderPatterns: (json['sender_patterns'] as List?)?.cast<String>() ?? [],
    subjectPatterns: (json['subject_patterns'] as List?)?.cast<String>() ?? [],
    labelFilter: json['label_filter'] as String?,
    replyTemplateId: json['reply_template_id'] as String,
    replySubject: json['reply_subject'] as String,
    replyBody: json['reply_body'] as String,
    cooldownMinutes: json['cooldown_minutes'] as int? ?? 60,
    lastTriggeredAt: json['last_triggered_at'] != null
        ? DateTime.parse(json['last_triggered_at'] as String) : null,
  );
}

/// 邮件分类规则
class EmailFilterRule {
  final String id;
  final String name;
  final bool enabled;
  final String? fromPattern;
  final String? toPattern;
  final String? subjectContains;
  final String? bodyContains;
  final bool? hasAttachment;
  final List<String> assignLabels;
  final bool markAsRead;
  final bool markAsStarred;
  final String? forwardTo;

  const EmailFilterRule({
    required this.id,
    required this.name,
    this.enabled = true,
    this.fromPattern,
    this.toPattern,
    this.subjectContains,
    this.bodyContains,
    this.hasAttachment,
    this.assignLabels = const [],
    this.markAsRead = false,
    this.markAsStarred = false,
    this.forwardTo,
  });

  bool matches(EmailMessage msg) {
    if (fromPattern != null) {
      final regex = RegExp(fromPattern!, caseSensitive: false);
      if (!regex.hasMatch(msg.from.address) &&
          !regex.hasMatch(msg.from.name)) return false;
    }
    if (subjectContains != null) {
      if (!msg.subject.toLowerCase().contains(subjectContains!.toLowerCase())) {
        return false;
      }
    }
    if (bodyContains != null) {
      if (!msg.textBody.toLowerCase().contains(bodyContains!.toLowerCase())) {
        return false;
      }
    }
    if (hasAttachment != null) {
      final msgHasAttachment = msg.attachments.isNotEmpty;
      if (hasAttachment != msgHasAttachment) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'from_pattern': fromPattern,
    'to_pattern': toPattern,
    'subject_contains': subjectContains,
    'body_contains': bodyContains,
    'has_attachment': hasAttachment,
    'assign_labels': assignLabels,
    'mark_as_read': markAsRead,
    'mark_as_starred': markAsStarred,
    'forward_to': forwardTo,
  };

  factory EmailFilterRule.fromJson(Map<String, dynamic> json) => EmailFilterRule(
    id: json['id'] as String,
    name: json['name'] as String,
    enabled: json['enabled'] as bool? ?? true,
    fromPattern: json['from_pattern'] as String?,
    toPattern: json['to_pattern'] as String?,
    subjectContains: json['subject_contains'] as String?,
    bodyContains: json['body_contains'] as String?,
    hasAttachment: json['has_attachment'] as bool?,
    assignLabels: (json['assign_labels'] as List?)?.cast<String>() ?? [],
    markAsRead: json['mark_as_read'] as bool? ?? false,
    markAsStarred: json['mark_as_starred'] as bool? ?? false,
    forwardTo: json['forward_to'] as String?,
  );
}

/// 邮件模板
class EmailTemplate {
  final String id;
  final String name;
  final String subjectTemplate;
  final String bodyTemplate;
  final bool isHtml;
  final Map<String, String> defaultVariables;

  const EmailTemplate({
    required this.id,
    required this.name,
    required this.subjectTemplate,
    required this.bodyTemplate,
    this.isHtml = true,
    this.defaultVariables = const {},
  });

  String renderSubject(Map<String, String> variables) {
    return _renderTemplate(subjectTemplate, {...defaultVariables, ...variables});
  }

  String renderBody(Map<String, String> variables) {
    return _renderTemplate(bodyTemplate, {...defaultVariables, ...variables});
  }

  static String _renderTemplate(String template, Map<String, String> vars) {
    String result = template;
    vars.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
      result = result.replaceAll('{{ $key }}', value);
    });
    return result;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subject_template': subjectTemplate,
    'body_template': bodyTemplate,
    'is_html': isHtml,
    'default_variables': defaultVariables,
  };

  factory EmailTemplate.fromJson(Map<String, dynamic> json) => EmailTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    subjectTemplate: json['subject_template'] as String,
    bodyTemplate: json['body_template'] as String,
    isHtml: json['is_html'] as bool? ?? true,
    defaultVariables: (json['default_variables'] as Map?)
        ?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
  );
}

// ============================================================================
// SMTP 客户端（Socket 层模拟）
// ============================================================================

/// SMTP 客户端，用于发送邮件
class SmtpClient {
  final EmailAccount account;
  Socket? _socket;
  bool _connected = false;

  SmtpClient(this.account);

  bool get isConnected => _connected;

  /// 连接到 SMTP 服务器
  Future<void> connect() async {
    try {
      if (account.useSsl && account.smtpPort == 465) {
        _socket = await SecureSocket.connect(
          account.smtpHost,
          account.smtpPort,
          onBadCertificate: (_) => false,
        );
      } else {
        _socket = await Socket.connect(account.smtpHost, account.smtpPort)
            .timeout(const Duration(seconds: 15));
      }

      // 读取服务器问候语
      final greeting = await _readResponse();
      if (!greeting.startsWith('220')) {
        throw SmtpException('SMTP 服务器拒绝连接: $greeting');
      }

      // EHLO
      await _sendCommand('EHLO ${account.smtpHost}');

      // STARTTLS (如果非 SSL 连接)
      if (!account.useSsl) {
        await _sendCommand('STARTTLS');
        _socket = await SecureSocket.secure(
          _socket!,
          onBadCertificate: (_) => false,
        );
        await _sendCommand('EHLO ${account.smtpHost}');
      }

      // AUTH LOGIN
      await _sendCommand('AUTH LOGIN');
      await _sendCommand(base64Encode(utf8.encode(account.username)));
      final authResult = await _sendCommand(
          base64Encode(utf8.encode(account.password)));
      if (!authResult.startsWith('235')) {
        throw SmtpException('SMTP 认证失败: $authResult');
      }

      _connected = true;
    } catch (e) {
      if (e is SmtpException) rethrow;
      throw SmtpException('SMTP 连接失败: $e');
    }
  }

  /// 发送邮件
  Future<void> sendMail(EmailMessage message) async {
    if (!_connected) throw SmtpException('未连接到 SMTP 服务器');

    final fromAddr = '<${account.emailAddress}>';
    await _sendCommand('MAIL FROM: $fromAddr');

    final allRecipients = <EmailAddress>[
      ...message.to,
      ...message.cc,
      ...message.bcc,
    ];
    for (final rcpt in allRecipients) {
      await _sendCommand('RCPT TO: <${rcpt.address}>');
    }

    await _sendCommand('DATA');

    // 构建邮件内容
    final boundary = '----=_Part_${DateTime.now().millisecondsSinceEpoch}';
    final sb = StringBuffer();
    sb.writeln('From: ${account.displayName} <${account.emailAddress}>');
    sb.writeln('To: ${message.to.map((e) => e.toString()).join(', ')}');
    if (message.cc.isNotEmpty) {
      sb.writeln('Cc: ${message.cc.map((e) => e.toString()).join(', ')}');
    }
    sb.writeln('Subject: =?UTF-8?B?${base64Encode(utf8.encode(message.subject))}?=');
    sb.writeln('Date: ${_formatDate(message.date)}');
    sb.writeln('Message-ID: <${message.messageId}>');
    if (message.inReplyTo != null) {
      sb.writeln('In-Reply-To: <${message.inReplyTo}>');
      sb.writeln('References: <${message.inReplyTo}>');
    }
    sb.writeln('MIME-Version: 1.0');

    if (message.attachments.isNotEmpty || message.htmlBody != null) {
      sb.writeln('Content-Type: multipart/mixed; boundary="$boundary"');
      sb.writeln();
      sb.writeln('--$boundary');
      sb.writeln('Content-Type: multipart/alternative; boundary="alt_$boundary"');
      sb.writeln();
    }

    // 纯文本正文
    if (message.textBody.isNotEmpty) {
      if (message.htmlBody != null || message.attachments.isNotEmpty) {
        sb.writeln('--alt_$boundary');
      }
      sb.writeln('Content-Type: text/plain; charset="UTF-8"');
      sb.writeln('Content-Transfer-Encoding: base64');
      sb.writeln();
      sb.writeln(base64Encode(utf8.encode(message.textBody)));
      if (message.htmlBody != null || message.attachments.isNotEmpty) {
        sb.writeln('--alt_$boundary--');
      }
    }

    // HTML 正文
    if (message.htmlBody != null) {
      if (message.textBody.isNotEmpty) {
        sb.writeln('--alt_$boundary');
      } else if (message.attachments.isNotEmpty) {
        sb.writeln('--alt_$boundary');
      }
      sb.writeln('Content-Type: text/html; charset="UTF-8"');
      sb.writeln('Content-Transfer-Encoding: base64');
      sb.writeln();
      sb.writeln(base64Encode(utf8.encode(message.htmlBody!)));
      if (message.textBody.isNotEmpty || message.attachments.isNotEmpty) {
        sb.writeln('--alt_$boundary--');
      }
    }

    // 附件
    for (final att in message.attachments) {
      sb.writeln('--$boundary');
      sb.writeln(
          'Content-Type: ${att.mimeType}; name="${att.filename}"');
      sb.writeln('Content-Transfer-Encoding: base64');
      sb.writeln('Content-Disposition: attachment; filename="${att.filename}"');
      if (att.contentId != null) {
        sb.writeln('Content-ID: <${att.contentId}>');
      }
      sb.writeln();
      sb.writeln(base64Encode(att.data));
    }

    if (message.attachments.isNotEmpty || message.htmlBody != null) {
      sb.writeln('--$boundary--');
    }

    // 签名
    if (account.signature.isNotEmpty) {
      sb.writeln();
      sb.writeln('-- ');
      sb.writeln(account.signature);
    }

    final mailData = sb.toString();
    // 点填充转义
    final escapedData = mailData.split('\n').map((line) {
      if (line.startsWith('.')) return '.$line';
      return line;
    }).join('\n');

    await _writeRaw('$escapedData\r\n.');
    final dataResult = await _readResponse();
    if (!dataResult.startsWith('250')) {
      throw SmtpException('邮件发送失败: $dataResult');
    }

    await _sendCommand('QUIT');
  }

  /// 关闭连接
  Future<void> disconnect() async {
    if (_connected) {
      try {
        await _sendCommand('QUIT');
      } catch (_) {}
      _socket?.destroy();
      _socket = null;
      _connected = false;
    }
  }

  Future<String> _sendCommand(String command) async {
    await _writeRaw('$command\r\n');
    return await _readResponse();
  }

  Future<void> _writeRaw(String data) async {
    _socket!.add(utf8.encode(data));
    await _socket!.flush();
  }

  Future<String> _readResponse() async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    StreamSubscription? subscription;

    subscription = _socket!.listen(
      (data) {
        buffer.write(utf8.decode(data));
        final text = buffer.toString();
        if (text.contains('\r\n') || text.contains('\n')) {
          final lines = text.split(RegExp(r'\r?\n'));
          final lastLine = lines.lastWhere(
            (l) => l.length >= 4 && l.substring(3, 4) == ' ',
            orElse: () => lines.first,
          );
          if (!completer.isCompleted) completer.complete(lastLine.trim());
          subscription?.cancel();
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        subscription?.cancel();
        throw SmtpException('SMTP 响应超时');
      },
    );
  }

  String _formatDate(DateTime dt) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final utc = dt.toUtc();
    return '${days[utc.weekday - 1]}, ${utc.day} ${months[utc.month - 1]} '
        '${utc.year} ${utc.hour.toString().padLeft(2, '0')}:'
        '${utc.minute.toString().padLeft(2, '0')}:'
        '${utc.second.toString().padLeft(2, '0')} +0000';
  }
}

/// SMTP 异常
class SmtpException implements Exception {
  final String message;
  const SmtpException(this.message);
  @override
  String toString() => 'SmtpException: $message';
}

// ============================================================================
// IMAP 客户端（Socket 层模拟）
// ============================================================================

/// IMAP 客户端，用于接收和管理邮件
class ImapClient {
  final EmailAccount account;
  Socket? _socket;
  bool _connected = false;
  bool _selected = false;
  String _currentMailbox = 'INBOX';
  int _tagCounter = 0;

  ImapClient(this.account);

  bool get isConnected => _connected;
  String get currentMailbox => _currentMailbox;

  /// 连接到 IMAP 服务器
  Future<void> connect() async {
    try {
      if (account.useSsl) {
        _socket = await SecureSocket.connect(
          account.imapHost,
          account.imapPort,
          onBadCertificate: (_) => false,
        );
      } else {
        _socket = await Socket.connect(account.imapHost, account.imapPort)
            .timeout(const Duration(seconds: 15));
      }

      // 读取服务器问候语
      final greeting = await _readLine();
      if (!greeting.contains('OK')) {
        throw ImapException('IMAP 服务器拒绝连接: $greeting');
      }

      // 登录
      await _sendCommand('LOGIN ${account.username} ${account.password}');
      _connected = true;
    } catch (e) {
      if (e is ImapException) rethrow;
      throw ImapException('IMAP 连接失败: $e');
    }
  }

  /// 选择邮箱
  Future<void> selectMailbox(String mailbox) async {
    final result = await _sendCommand('SELECT "$mailbox"');
    if (result.contains('OK')) {
      _currentMailbox = mailbox;
      _selected = true;
    } else {
      throw ImapException('选择邮箱失败: $mailbox');
    }
  }

  /// 搜索邮件
  Future<List<String>> search(String criteria) async {
    if (!_selected) await selectMailbox('INBOX');
    final result = await _sendCommand('SEARCH $criteria');
    final lines = result.split('\n');
    for (final line in lines) {
      if (line.contains('SEARCH')) {
        final match = RegExp(r'\* SEARCH (.+)').firstMatch(line);
        if (match != null) {
          return match.group(1)!.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
        }
      }
    }
    return [];
  }

  /// 获取邮件摘要
  Future<List<EmailMessage>> fetchMessages(List<String> uids, {bool fetchBody = false}) async {
    if (!_selected) await selectMailbox('INBOX');
    final messages = <EmailMessage>[];

    for (final uid in uids) {
      final fetchCmd = fetchBody
          ? 'FETCH $uid (UID FLAGS ENVELOPE BODY[TEXT])'
          : 'FETCH $uid (UID FLAGS ENVELOPE)';
      final result = await _sendCommand(fetchCmd);
      final msg = _parseFetchResponse(uid, result);
      if (msg != null) messages.add(msg);
    }
    return messages;
  }

  /// 设置邮件标记
  Future<void> setFlags(String uid, List<String> flags, {bool add = true}) async {
    final action = add ? '+FLAGS' : '-FLAGS';
    final flagStr = flags.join(' ');
    await _sendCommand('STORE $uid $action ($flagStr)');
  }

  /// 复制邮件到其他邮箱
  Future<void> copyMessage(String uid, String destMailbox) async {
    await _sendCommand('COPY $uid "$destMailbox"');
  }

  /// 删除邮件（标记为删除 + EXPUNGE）
  Future<void> deleteMessage(String uid) async {
    await setFlags(uid, [r'\Deleted']);
    await _sendCommand('EXPUNGE');
  }

  /// 列出所有邮箱
  Future<List<String>> listMailboxes() async {
    final result = await _sendCommand('LIST "" "*"');
    final mailboxes = <String>[];
    final lines = result.split('\n');
    for (final line in lines) {
      final match = RegExp(r'"[^"]*"\s+"[^"]*"\s+"?(.+?)"?\s*$').firstMatch(line);
      if (match != null) {
        mailboxes.add(match.group(1)!.replaceAll('"', ''));
      }
    }
    return mailboxes;
  }

  /// 关闭连接
  Future<void> disconnect() async {
    if (_connected) {
      try {
        await _sendCommand('LOGOUT');
      } catch (_) {}
      _socket?.destroy();
      _socket = null;
      _connected = false;
      _selected = false;
    }
  }

  String _nextTag() => 'A${(++_tagCounter).toString().padLeft(4, '0')}';

  Future<String> _sendCommand(String command) async {
    final tag = _nextTag();
    _socket!.add(utf8.encode('$tag $command\r\n'));
    await _socket!.flush();
    return await _readResponse(tag);
  }

  Future<String> _readLine() async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    late StreamSubscription sub;

    sub = _socket!.listen(
      (data) {
        buffer.write(utf8.decode(data));
        final text = buffer.toString();
        if (text.contains('\r\n')) {
          final line = text.split('\r\n').first;
          if (!completer.isCompleted) completer.complete(line);
          sub.cancel();
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    return completer.future.timeout(const Duration(seconds: 30));
  }

  Future<String> _readResponse(String tag) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    late StreamSubscription sub;

    sub = _socket!.listen(
      (data) {
        buffer.write(utf8.decode(data));
        final text = buffer.toString();
        if (text.contains('$tag ')) {
          if (!completer.isCompleted) completer.complete(text);
          sub.cancel();
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => buffer.toString(),
    );
  }

  EmailMessage? _parseFetchResponse(String uid, String response) {
    // 解析 ENVELOPE 获取邮件元数据
    final subjectMatch = RegExp(r'"\(SUBJECT "([^"]*)"\)"').firstMatch(response);
    final fromMatch = RegExp(r'\(FROM \("([^"]*)" NIL "([^"]*)" "([^"]*)"\)')
        .firstMatch(response);
    final dateMatch = RegExp(r'"\(DATE "([^"]*)"\)"').firstMatch(response);
    final msgIdMatch = RegExp(r'MESSAGE-ID "([^"]*)"').firstMatch(response);

    final subject = subjectMatch?.group(1) ?? '(无主题)';
    final senderName = fromMatch?.group(1) ?? '';
    final senderLocal = fromMatch?.group(2) ?? '';
    final senderDomain = fromMatch?.group(3) ?? '';
    final senderAddr = '$senderLocal@$senderDomain';
    final dateStr = dateMatch?.group(1);
    final messageId = msgIdMatch?.group(1) ?? uid;

    final isRead = response.contains(r'\Seen');
    final isStarred = response.contains(r'\Flagged');

    return EmailMessage(
      messageId: messageId,
      from: EmailAddress(address: senderAddr, name: senderName),
      subject: subject,
      date: dateStr != null ? _parseDate(dateStr) : DateTime.now(),
      isRead: isRead,
      isStarred: isStarred,
      accountId: account.id,
    );
  }

  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }
}

/// IMAP 异常
class ImapException implements Exception {
  final String message;
  const ImapException(this.message);
  @override
  String toString() => 'ImapException: $message';
}

// ============================================================================
// 邮件技能主类
// ============================================================================

/// 邮件技能
/// 提供完整的邮件收发、管理、自动化功能
class EmailSkill extends Skill {
  /// 多账号管理
  final Map<String, EmailAccount> _accounts = {};
  String? _defaultAccountId;

  /// SMTP/IMAP 连接池
  final Map<String, SmtpClient> _smtpClients = {};
  final Map<String, ImapClient> _imapClients = {};

  /// 联系人列表
  final Map<String, EmailContact> _contacts = {};

  /// 模板列表
  final Map<String, EmailTemplate> _templates = {};

  /// 自动回复规则
  final Map<String, AutoReplyRule> _autoReplyRules = {};

  /// 邮件分类规则
  final Map<String, EmailFilterRule> _filterRules = {};

  /// 本地邮件缓存
  final List<EmailMessage> _messageCache = [];
  static const int _maxCacheSize = 500;

  // ==========================================================================
  // 技能元数据
  // ==========================================================================

  @override
  SkillManifest get manifest => const SkillManifest(
    id: 'email',
    name: '邮件助手',
    description: '管理电子邮件，发送和接收邮件，管理联系人，设置自动回复和分类规则。'
        '支持多邮箱账号、HTML 模板、附件处理、邮件搜索和摘要生成。',
    version: '1.0.0',
    author: '小酥',
    permissions: [
      SkillPermission.networkAccess,
      SkillPermission.localStorage,
    ],
    loadStrategy: SkillLoadStrategy.lazy,
    priority: 50,
  );

  @override
  List<SkillTool> get tools => [
    _sendEmailTool,
    _readEmailsTool,
    _replyEmailTool,
    _searchEmailsTool,
    _getContactsTool,
  ];

  // ==========================================================================
  // 初始化与销毁
  // ==========================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('邮件技能初始化中...');
    await _loadAccountsFromStorage(context);
    await _loadContactsFromStorage(context);
    await _loadTemplatesFromStorage(context);
    await _loadRulesFromStorage(context);
    context.logger.info('邮件技能初始化完成，已加载 ${_accounts.length} 个账号');
  }

  @override
  Future<void> onDispose() async {
    for (final client in _smtpClients.values) {
      await client.disconnect();
    }
    for (final client in _imapClients.values) {
      await client.disconnect();
    }
    _smtpClients.clear();
    _imapClients.clear();
  }

  Future<void> _loadAccountsFromStorage(SkillContext context) async {
    final data = await context.storage.get('email_accounts');
    if (data != null) {
      final list = jsonDecode(data) as List;
      for (final item in list) {
        final account = EmailAccount.fromJson(item as Map<String, dynamic>);
        _accounts[account.id] = account;
        if (account.isDefault) _defaultAccountId = account.id;
      }
    }
  }

  Future<void> _loadContactsFromStorage(SkillContext context) async {
    final data = await context.storage.get('email_contacts');
    if (data != null) {
      final list = jsonDecode(data) as List;
      for (final item in list) {
        final contact = EmailContact.fromJson(item as Map<String, dynamic>);
        _contacts[contact.id] = contact;
      }
    }
  }

  Future<void> _loadTemplatesFromStorage(SkillContext context) async {
    final data = await context.storage.get('email_templates');
    if (data != null) {
      final list = jsonDecode(data) as List;
      for (final item in list) {
        final tpl = EmailTemplate.fromJson(item as Map<String, dynamic>);
        _templates[tpl.id] = tpl;
      }
    }
  }

  Future<void> _loadRulesFromStorage(SkillContext context) async {
    final arData = await context.storage.get('email_auto_reply_rules');
    if (arData != null) {
      final list = jsonDecode(arData) as List;
      for (final item in list) {
        final rule = AutoReplyRule.fromJson(item as Map<String, dynamic>);
        _autoReplyRules[rule.id] = rule;
      }
    }
    final frData = await context.storage.get('email_filter_rules');
    if (frData != null) {
      final list = jsonDecode(frData) as List;
      for (final item in list) {
        final rule = EmailFilterRule.fromJson(item as Map<String, dynamic>);
        _filterRules[rule.id] = rule;
      }
    }
  }

  // ==========================================================================
  // 工具定义
  // ==========================================================================

  /// send_email - 发送邮件
  late final SkillTool _sendEmailTool = SkillTool(
    name: 'send_email',
    description: '发送电子邮件。支持收件人、抄送、密送、HTML 正文、附件。'
        '可指定发件账号（不指定则使用默认账号），支持邮件模板。',
    parameters: [
      ToolParameter(
        name: 'to',
        description: '收件人邮箱地址列表',
        type: ToolParameterType.arrayType,
        required: true,
      ),
      ToolParameter(
        name: 'subject',
        description: '邮件主题',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'body',
        description: '邮件正文内容',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'html',
        description: '是否为 HTML 格式邮件',
        type: ToolParameterType.boolType,
      ),
      ToolParameter(
        name: 'cc',
        description: '抄送邮箱地址列表',
        type: ToolParameterType.arrayType,
      ),
      ToolParameter(
        name: 'bcc',
        description: '密送邮箱地址列表',
        type: ToolParameterType.arrayType,
      ),
      ToolParameter(
        name: 'account_id',
        description: '发件账号 ID（不指定则使用默认账号）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'template_id',
        description: '邮件模板 ID（使用模板时，body 中的变量会被替换）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'template_variables',
        description: '模板变量（key-value 对，用于替换模板中的 {{variable}}）',
        type: ToolParameterType.objectType,
      ),
      ToolParameter(
        name: 'attachments',
        description: '附件文件路径列表',
        type: ToolParameterType.arrayType,
      ),
    ],
    isAsync: true,
    timeoutMs: 60000,
    execute: _handleSendEmail,
  );

  /// read_emails - 读取邮件
  late final SkillTool _readEmailsTool = SkillTool(
    name: 'read_emails',
    description: '读取收件箱中的邮件列表。支持按邮箱、文件夹、未读/已读筛选，'
        '可指定返回数量和偏移量。',
    parameters: [
      ToolParameter(
        name: 'account_id',
        description: '账号 ID（不指定则使用默认账号）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'mailbox',
        description: '邮箱文件夹（默认 INBOX）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'limit',
        description: '返回邮件数量（默认 20，最大 100）',
        type: ToolParameterType.intType,
      ),
      ToolParameter(
        name: 'offset',
        description: '偏移量（用于分页，默认 0）',
        type: ToolParameterType.intType,
      ),
      ToolParameter(
        name: 'unread_only',
        description: '是否仅返回未读邮件',
        type: ToolParameterType.boolType,
      ),
      ToolParameter(
        name: 'fetch_body',
        description: '是否获取邮件正文（默认 false，仅获取摘要）',
        type: ToolParameterType.boolType,
      ),
    ],
    isAsync: true,
    timeoutMs: 30000,
    execute: _handleReadEmails,
  );

  /// reply_email - 回复邮件
  late final SkillTool _replyEmailTool = SkillTool(
    name: 'reply_email',
    description: '回复指定邮件。自动设置 In-Reply-To 和 References 头，'
        '保持邮件线程。支持回复全部（含抄送人）。',
    parameters: [
      ToolParameter(
        name: 'message_id',
        description: '要回复的邮件 Message-ID',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'body',
        description: '回复内容',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'reply_all',
        description: '是否回复全部收件人（含抄送）',
        type: ToolParameterType.boolType,
      ),
      ToolParameter(
        name: 'account_id',
        description: '发件账号 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    isAsync: true,
    timeoutMs: 60000,
    execute: _handleReplyEmail,
  );

  /// search_emails - 搜索邮件
  late final SkillTool _searchEmailsTool = SkillTool(
    name: 'search_emails',
    description: '搜索邮件。支持按发件人、主题关键词、日期范围、'
        '是否有附件等条件组合搜索。',
    parameters: [
      ToolParameter(
        name: 'query',
        description: '搜索关键词（匹配主题和正文）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'from',
        description: '发件人地址或名称',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'subject',
        description: '主题关键词',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'date_after',
        description: '日期范围起始（ISO 8601 格式）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'date_before',
        description: '日期范围结束（ISO 8601 格式）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'has_attachment',
        description: '是否仅搜索有附件的邮件',
        type: ToolParameterType.boolType,
      ),
      ToolParameter(
        name: 'label',
        description: '按标签/文件夹筛选',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'account_id',
        description: '账号 ID',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'limit',
        description: '最大返回数量（默认 20）',
        type: ToolParameterType.intType,
      ),
    ],
    isAsync: true,
    timeoutMs: 30000,
    execute: _handleSearchEmails,
  );

  /// get_contacts - 获取联系人
  late final SkillTool _getContactsTool = SkillTool(
    name: 'get_contacts',
    description: '获取邮件联系人列表。支持按名称、邮箱搜索，'
        '返回联系人详情及最近联系时间。',
    parameters: [
      ToolParameter(
        name: 'query',
        description: '搜索关键词（匹配名称或邮箱）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'limit',
        description: '返回数量（默认 20）',
        type: ToolParameterType.intType,
      ),
      ToolParameter(
        name: 'sort_by',
        description: '排序方式：name / last_contacted / contact_count',
        type: ToolParameterType.stringType,
        enumValues: ['name', 'last_contacted', 'contact_count'],
      ),
    ],
    execute: _handleGetContacts,
  );

  // ==========================================================================
  // 工具执行处理
  // ==========================================================================

  Future<ToolResult> _handleSendEmail(
      Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final toList = (args['to'] as List).cast<String>();
      final subject = args['subject'] as String;
      var body = args['body'] as String;
      final isHtml = args['html'] as bool? ?? false;
      final ccList = (args['cc'] as List?)?.cast<String>() ?? <String>[];
      final bccList = (args['bcc'] as List?)?.cast<String>() ?? <String>[];
      final accountId = args['account_id'] as String? ?? _defaultAccountId;
      final templateId = args['template_id'] as String?;
      final templateVars = (args['template_variables'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? <String, String>{};
      final attachmentPaths = (args['attachments'] as List?)?.cast<String>() ?? <String>[];

      if (accountId == null || !_accounts.containsKey(accountId)) {
        return ToolResult.failure(
          error: '未找到发件账号，请先配置邮箱账号',
          errorCode: 'ACCOUNT_NOT_FOUND',
        );
      }
      final account = _accounts[accountId]!;

      // 模板渲染
      if (templateId != null && _templates.containsKey(templateId)) {
        final tpl = _templates[templateId]!;
        body = tpl.renderBody(templateVars);
      }

      // 加载附件
      final attachments = <EmailAttachment>[];
      for (final path in attachmentPaths) {
        try {
          final file = File(path);
          final data = await file.readAsBytes();
          final mimeType = _guessMimeType(path);
          attachments.add(EmailAttachment(
            filename: path.split(Platform.pathSeparator).last,
            mimeType: mimeType,
            data: data,
            size: data.length,
          ));
        } catch (e) {
          ctx.logger.warning('附件加载失败: $path - $e');
        }
      }

      // 构建邮件消息
      final message = EmailMessage(
        messageId: '${DateTime.now().millisecondsSinceEpoch}@${account.emailAddress}',
        from: EmailAddress(address: account.emailAddress, name: account.displayName),
        to: toList.map((e) => EmailAddress(address: e)).toList(),
        cc: ccList.map((e) => EmailAddress(address: e)).toList(),
        bcc: bccList.map((e) => EmailAddress(address: e)).toList(),
        subject: subject,
        textBody: isHtml ? '' : body,
        htmlBody: isHtml ? body : null,
        date: DateTime.now(),
        attachments: attachments,
        accountId: accountId,
      );

      // 通过 SMTP 发送
      final client = await _getSmtpClient(accountId);
      await client.sendMail(message);

      // 更新联系人
      for (final addr in toList) {
        await _upsertContact(addr, '', ctx);
      }

      stopwatch.stop();
      return ToolResult.success(
        content: '邮件已发送至 ${toList.join(', ')}',
        data: {
          'message_id': message.messageId,
          'to': toList,
          'subject': subject,
        },
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      ctx.logger.error('发送邮件失败', e);
      return ToolResult.failure(
        error: '发送邮件失败: $e',
        errorCode: 'SEND_FAILED',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<ToolResult> _handleReadEmails(
      Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final accountId = args['account_id'] as String? ?? _defaultAccountId;
      final mailbox = args['mailbox'] as String? ?? 'INBOX';
      final limit = (args['limit'] as int?) ?? 20;
      final offset = args['offset'] as int? ?? 0;
      final unreadOnly = args['unread_only'] as bool? ?? false;
      final fetchBody = args['fetch_body'] as bool? ?? false;

      if (accountId == null || !_accounts.containsKey(accountId)) {
        return ToolResult.failure(
          error: '未找到邮箱账号',
          errorCode: 'ACCOUNT_NOT_FOUND',
        );
      }

      final client = await _getImapClient(accountId);
      await client.selectMailbox(mailbox);

      String criteria = 'ALL';
      if (unreadOnly) criteria = 'UNSEEN';

      final uids = await client.search(criteria);
      final total = uids.length;
      final start = offset;
      final end = (offset + limit).clamp(0, uids.length);
      final pageUids = uids.sublist(
        start.clamp(0, uids.length),
        end.clamp(0, uids.length),
      );

      if (pageUids.isEmpty) {
        return ToolResult.success(
          content: '没有邮件',
          data: {'total': 0, 'messages': []},
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      final messages = await client.fetchMessages(pageUids, fetchBody: fetchBody);

      // 缓存邮件
      _addToCache(messages);

      // 应用分类规则
      for (final msg in messages) {
        await _applyFilterRules(msg, ctx);
      }

      stopwatch.stop();
      return ToolResult.success(
        content: '获取到 ${messages.length} 封邮件（共 $total 封）',
        data: {
          'total': total,
          'offset': offset,
          'limit': limit,
          'messages': messages.map((m) => m.toJson()).toList(),
        },
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      ctx.logger.error('读取邮件失败', e);
      return ToolResult.failure(
        error: '读取邮件失败: $e',
        errorCode: 'READ_FAILED',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<ToolResult> _handleReplyEmail(
      Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final messageId = args['message_id'] as String;
      final body = args['body'] as String;
      final replyAll = args['reply_all'] as bool? ?? false;
      final accountId = args['account_id'] as String? ?? _defaultAccountId;

      if (accountId == null || !_accounts.containsKey(accountId)) {
        return ToolResult.failure(
          error: '未找到发件账号',
          errorCode: 'ACCOUNT_NOT_FOUND',
        );
      }

      // 从缓存中查找原邮件
      final original = _messageCache.where((m) => m.messageId == messageId).firstOrNull;
      if (original == null) {
        return ToolResult.failure(
          error: '未找到原始邮件: $messageId',
          errorCode: 'MESSAGE_NOT_FOUND',
        );
      }

      final account = _accounts[accountId]!;
      final replyTo = original.from;
      final ccRecipients = replyAll ? original.cc : <EmailAddress>[];

      final replyMessage = EmailMessage(
        messageId: '${DateTime.now().millisecondsSinceEpoch}@${account.emailAddress}',
        from: EmailAddress(address: account.emailAddress, name: account.displayName),
        to: [replyTo],
        cc: ccRecipients,
        subject: original.subject.startsWith('Re:') ? original.subject : 'Re: ${original.subject}',
        textBody: body,
        date: DateTime.now(),
        inReplyTo: original.messageId,
        accountId: accountId,
      );

      final client = await _getSmtpClient(accountId);
      await client.sendMail(replyMessage);

      stopwatch.stop();
      return ToolResult.success(
        content: '已回复邮件给 ${replyTo.address}',
        data: {
          'message_id': replyMessage.messageId,
          'in_reply_to': original.messageId,
          'to': replyTo.address,
        },
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      ctx.logger.error('回复邮件失败', e);
      return ToolResult.failure(
        error: '回复邮件失败: $e',
        errorCode: 'REPLY_FAILED',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<ToolResult> _handleSearchEmails(
      Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final query = args['query'] as String?;
      final from = args['from'] as String?;
      final subject = args['subject'] as String?;
      final dateAfter = args['date_after'] as String?;
      final dateBefore = args['date_before'] as String?;
      final hasAttachment = args['has_attachment'] as bool?;
      final label = args['label'] as String?;
      final accountId = args['account_id'] as String? ?? _defaultAccountId;
      final limit = (args['limit'] as int?) ?? 20;

      // 优先从缓存搜索
      var results = List<EmailMessage>.from(_messageCache);

      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        results = results.where((m) =>
            m.subject.toLowerCase().contains(q) ||
            m.textBody.toLowerCase().contains(q)).toList();
      }
      if (from != null && from.isNotEmpty) {
        final f = from.toLowerCase();
        results = results.where((m) =>
            m.from.address.toLowerCase().contains(f) ||
            m.from.name.toLowerCase().contains(f)).toList();
      }
      if (subject != null && subject.isNotEmpty) {
        final s = subject.toLowerCase();
        results = results.where((m) => m.subject.toLowerCase().contains(s)).toList();
      }
      if (dateAfter != null) {
        final after = DateTime.tryParse(dateAfter);
        if (after != null) {
          results = results.where((m) => m.date.isAfter(after)).toList();
        }
      }
      if (dateBefore != null) {
        final before = DateTime.tryParse(dateBefore);
        if (before != null) {
          results = results.where((m) => m.date.isBefore(before)).toList();
        }
      }
      if (hasAttachment == true) {
        results = results.where((m) => m.attachments.isNotEmpty).toList();
      } else if (hasAttachment == false) {
        results = results.where((m) => m.attachments.isEmpty).toList();
      }
      if (label != null && label.isNotEmpty) {
        results = results.where((m) => m.labels.contains(label)).toList();
      }

      results = results.take(limit).toList();

      stopwatch.stop();
      return ToolResult.success(
        content: '搜索到 ${results.length} 封邮件',
        data: {
          'total': results.length,
          'messages': results.map((m) => m.toJson()).toList(),
        },
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      ctx.logger.error('搜索邮件失败', e);
      return ToolResult.failure(
        error: '搜索邮件失败: $e',
        errorCode: 'SEARCH_FAILED',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<ToolResult> _handleGetContacts(
      Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final query = args['query'] as String?;
      final limit = (args['limit'] as int?) ?? 20;
      final sortBy = args['sort_by'] as String? ?? 'name';

      var contacts = _contacts.values.toList();

      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        contacts = contacts.where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q)).toList();
      }

      switch (sortBy) {
        case 'last_contacted':
          contacts.sort((a, b) {
            final aDate = a.lastContactedAt ?? DateTime(2000);
            final bDate = b.lastContactedAt ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });
        case 'contact_count':
          contacts.sort((a, b) => b.contactCount.compareTo(a.contactCount));
        default:
          contacts.sort((a, b) => a.name.compareTo(b.name));
      }

      contacts = contacts.take(limit).toList();

      stopwatch.stop();
      return ToolResult.success(
        content: '找到 ${contacts.length} 个联系人',
        data: {
          'total': contacts.length,
          'contacts': contacts.map((c) => c.toJson()).toList(),
        },
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(
        error: '获取联系人失败: $e',
        errorCode: 'CONTACT_ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  // ==========================================================================
  // 内部方法
  // ==========================================================================

  /// 获取或创建 SMTP 客户端
  Future<SmtpClient> _getSmtpClient(String accountId) async {
    if (_smtpClients.containsKey(accountId) && _smtpClients[accountId]!.isConnected) {
      return _smtpClients[accountId]!;
    }
    final account = _accounts[accountId]!;
    final client = SmtpClient(account);
    await client.connect();
    _smtpClients[accountId] = client;
    return client;
  }

  /// 获取或创建 IMAP 客户端
  Future<ImapClient> _getImapClient(String accountId) async {
    if (_imapClients.containsKey(accountId) && _imapClients[accountId]!.isConnected) {
      return _imapClients[accountId]!;
    }
    final account = _accounts[accountId]!;
    final client = ImapClient(account);
    await client.connect();
    _imapClients[accountId] = client;
    return client;
  }

  /// 添加到邮件缓存
  void _addToCache(List<EmailMessage> messages) {
    for (final msg in messages) {
      final idx = _messageCache.indexWhere((m) => m.messageId == msg.messageId);
      if (idx >= 0) {
        _messageCache[idx] = msg;
      } else {
        _messageCache.add(msg);
      }
    }
    while (_messageCache.length > _maxCacheSize) {
      _messageCache.removeAt(0);
    }
  }

  /// 应用分类规则
  Future<void> _applyFilterRules(EmailMessage msg, SkillContext ctx) async {
    for (final rule in _filterRules.values) {
      if (!rule.enabled) continue;
      if (rule.matches(msg)) {
        ctx.logger.info('邮件 "${msg.subject}" 匹配规则 "${rule.name}"');
        // 在实际实现中，这里会调用 IMAP 的 STORE 命令设置标记
      }
    }
  }

  /// 处理自动回复
  Future<void> processAutoReply(EmailMessage msg, SkillContext ctx) async {
    for (final rule in _autoReplyRules.values) {
      if (!rule.enabled) continue;

      // 检查冷却时间
      if (rule.lastTriggeredAt != null) {
        final elapsed = DateTime.now().difference(rule.lastTriggeredAt!);
        if (elapsed.inMinutes < rule.cooldownMinutes) continue;
      }

      // 匹配发件人
      if (rule.senderPatterns.isNotEmpty) {
        final matched = rule.senderPatterns.any((p) {
          return RegExp(p, caseSensitive: false).hasMatch(msg.from.address);
        });
        if (!matched) continue;
      }

      // 匹配主题
      if (rule.subjectPatterns.isNotEmpty) {
        final matched = rule.subjectPatterns.any((p) {
          return RegExp(p, caseSensitive: false).hasMatch(msg.subject);
        });
        if (!matched) continue;
      }

      // 发送自动回复
      ctx.logger.info('触发自动回复规则: ${rule.name}');
      final replyMsg = EmailMessage(
        messageId: '${DateTime.now().millisecondsSinceEpoch}@auto',
        from: EmailAddress(address: msg.to.first.address),
        to: [msg.from],
        subject: rule.replySubject,
        textBody: rule.replyBody,
        date: DateTime.now(),
        inReplyTo: msg.messageId,
        accountId: msg.accountId,
      );

      try {
        final client = await _getSmtpClient(msg.accountId ?? _defaultAccountId!);
        await client.sendMail(replyMsg);
      } catch (e) {
        ctx.logger.error('自动回复发送失败', e);
      }
    }
  }

  /// 生成邮件摘要（调用 LLM）
  Future<String> generateSummary(EmailMessage msg, SkillContext ctx) async {
    final prompt = '请为以下邮件生成简洁的中文摘要（不超过3句话）：\n\n'
        '发件人: ${msg.from}\n'
        '主题: ${msg.subject}\n'
        '正文:\n${msg.textBody}';

    try {
      final response = await ctx.http.post(
        'https://api.openai.com/v1/chat/completions',
        headers: {'Content-Type': 'application/json'},
        body: {
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'system', 'content': '你是一个邮件摘要助手，擅长提取邮件核心内容。'},
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 200,
          'temperature': 0.3,
        },
      );
      final result = jsonDecode(response);
      return (result['choices'] as List)[0]['message']['content'] as String;
    } catch (e) {
      ctx.logger.error('邮件摘要生成失败', e);
      return '摘要生成失败: $e';
    }
  }

  /// 添加/更新联系人
  Future<void> _upsertContact(String email, String name, SkillContext ctx) async {
    final existing = _contacts.values.where((c) => c.email == email).firstOrNull;
    if (existing != null) {
      _contacts[existing.id] = EmailContact(
        id: existing.id,
        name: name.isNotEmpty ? name : existing.name,
        email: email,
        phone: existing.phone,
        company: existing.company,
        notes: existing.notes,
        createdAt: existing.createdAt,
        lastContactedAt: DateTime.now(),
        contactCount: existing.contactCount + 1,
      );
    } else {
      final id = 'contact_${DateTime.now().millisecondsSinceEpoch}';
      _contacts[id] = EmailContact(
        id: id,
        name: name,
        email: email,
        createdAt: DateTime.now(),
        lastContactedAt: DateTime.now(),
        contactCount: 1,
      );
    }
    // 持久化
    await _saveContactsToStorage(ctx);
  }

  Future<void> _saveContactsToStorage(SkillContext ctx) async {
    final data = jsonEncode(_contacts.values.map((c) => c.toJson()).toList());
    await ctx.storage.set('email_contacts', data);
  }

  /// 添加账号
  Future<void> addAccount(EmailAccount account, SkillContext ctx) async {
    _accounts[account.id] = account;
    if (account.isDefault) _defaultAccountId = account.id;
    await _saveAccountsToStorage(ctx);
  }

  Future<void> _saveAccountsToStorage(SkillContext ctx) async {
    final data = jsonEncode(_accounts.values.map((a) => a.toJson()).toList());
    await ctx.storage.set('email_accounts', data);
  }

  /// 添加模板
  void addTemplate(EmailTemplate template) {
    _templates[template.id] = template;
  }

  /// 添加自动回复规则
  void addAutoReplyRule(AutoReplyRule rule) {
    _autoReplyRules[rule.id] = rule;
  }

  /// 添加分类规则
  void addFilterRule(EmailFilterRule rule) {
    _filterRules[rule.id] = rule;
  }

  /// 获取账号列表
  List<EmailAccount> get accounts => _accounts.values.toList();

  /// 获取模板列表
  List<EmailTemplate> get templates => _templates.values.toList();

  /// 猜测 MIME 类型
  String _guessMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'svg' => 'image/svg+xml',
      'zip' => 'application/zip',
      'txt' => 'text/plain',
      'html' || 'htm' => 'text/html',
      'csv' => 'text/csv',
      'json' => 'application/json',
      'xml' => 'application/xml',
      'mp3' => 'audio/mpeg',
      'mp4' => 'video/mp4',
      _ => 'application/octet-stream',
    };
  }
}
