// ============================================================================
// 小酥 - Agent消息模型（SSE流式解析）
// ============================================================================

/// Agent消息类型
enum AgentMessageType {
  thinking,     // AI思考过程
  toolCall,     // 工具调用
  toolResult,   // 工具执行结果
  answer,       // 最终回答
  error,        // 错误
  done;         // 完成

  static AgentMessageType fromString(String type) {
    switch (type) {
      case 'thinking': return AgentMessageType.thinking;
      case 'tool_call': return AgentMessageType.toolCall;
      case 'tool_result': return AgentMessageType.toolResult;
      case 'answer': return AgentMessageType.answer;
      case 'error': return AgentMessageType.error;
      case 'done': return AgentMessageType.done;
      default: return AgentMessageType.answer;
    }
  }
}

/// 工具调用状态
enum ToolCallStatus {
  pending,   // 等待执行
  running,   // 执行中
  success,   // 成功
  error,     // 失败
  timeout,   // 超时
}

/// 工具类型定义
class ToolTypeConfig {
  final String name;
  final String icon;
  final String colorHex;
  final String displayName;

  const ToolTypeConfig({
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.displayName,
  });

  /// 获取所有支持的工具类型配置
  static const Map<String, ToolTypeConfig> allTools = {
    'bash_execute': ToolTypeConfig(
      name: 'bash_execute',
      icon: '⌨️',
      colorHex: '#4CAF50',
      displayName: '命令执行',
    ),
    'web_search': ToolTypeConfig(
      name: 'web_search',
      icon: '🔍',
      colorHex: '#2196F3',
      displayName: '网页搜索',
    ),
    'web_fetch': ToolTypeConfig(
      name: 'web_fetch',
      icon: '🌐',
      colorHex: '#00BCD4',
      displayName: '网页抓取',
    ),
    'github_api': ToolTypeConfig(
      name: 'github_api',
      icon: '🐙',
      colorHex: '#6A1B9A',
      displayName: 'GitHub操作',
    ),
    'image_generate': ToolTypeConfig(
      name: 'image_generate',
      icon: '🎨',
      colorHex: '#E91E63',
      displayName: '图片生成',
    ),
    'calendar_create': ToolTypeConfig(
      name: 'calendar_create',
      icon: '📅',
      colorHex: '#FF9800',
      displayName: '日历事件',
    ),
    'email_send': ToolTypeConfig(
      name: 'email_send',
      icon: '📧',
      colorHex: '#795548',
      displayName: '邮件发送',
    ),
    'memory_save': ToolTypeConfig(
      name: 'memory_save',
      icon: '💾',
      colorHex: '#607D8B',
      displayName: '记忆保存',
    ),
    'memory_search': ToolTypeConfig(
      name: 'memory_search',
      icon: '🧠',
      colorHex: '#9C27B0',
      displayName: '记忆搜索',
    ),
    'process_manager': ToolTypeConfig(
      name: 'process_manager',
      icon: '⚙️',
      colorHex: '#FF5722',
      displayName: '进程管理',
    ),
    'file_write': ToolTypeConfig(
      name: 'file_write',
      icon: '📝',
      colorHex: '#3F51B5',
      displayName: '文件写入',
    ),
    'file_read': ToolTypeConfig(
      name: 'file_read',
      icon: '📄',
      colorHex: '#009688',
      displayName: '文件读取',
    ),
    'code_execute': ToolTypeConfig(
      name: 'code_execute',
      icon: '💻',
      colorHex: '#795548',
      displayName: '代码执行',
    ),
  };

  /// 获取工具配置，未知工具返回默认配置
  static ToolTypeConfig getConfig(String toolName) {
    return allTools[toolName] ?? ToolTypeConfig(
      name: toolName,
      icon: '🔧',
      colorHex: '#9E9E9E',
      displayName: toolName,
    );
  }
}

/// Agent流式消息
class AgentMessage {
  final String id;
  final AgentMessageType type;
  final String content;
  final DateTime timestamp;

  // 工具调用相关
  final String? toolName;
  final Map<String, dynamic>? toolArgs;
  final String? callId;
  final ToolCallStatus? toolStatus;
  final dynamic toolResult;
  final String? errorMessage;

  // 耗时
  final int? durationMs;

  const AgentMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.toolName,
    this.toolArgs,
    this.callId,
    this.toolStatus,
    this.toolResult,
    this.errorMessage,
    this.durationMs,
  });

  /// 从SSE JSON创建
  factory AgentMessage.fromSSE(Map<String, dynamic> json) {
    final type = AgentMessageType.fromString(json['type'] as String? ?? 'answer');
    final now = DateTime.now();

    switch (type) {
      case AgentMessageType.thinking:
        return AgentMessage(
          id: 'thinking_${now.millisecondsSinceEpoch}',
          type: type,
          content: json['content'] as String? ?? '',
          timestamp: now,
        );

      case AgentMessageType.toolCall:
        return AgentMessage(
          id: json['call_id'] as String? ?? 'tool_${now.millisecondsSinceEpoch}',
          type: type,
          content: '',
          timestamp: now,
          toolName: json['tool'] as String? ?? 'unknown',
          toolArgs: json['args'] as Map<String, dynamic>?,
          callId: json['call_id'] as String?,
          toolStatus: ToolCallStatus.running,
        );

      case AgentMessageType.toolResult:
        final statusStr = json['status'] as String? ?? 'success';
        final status = statusStr == 'success'
            ? ToolCallStatus.success
            : ToolCallStatus.error;
        return AgentMessage(
          id: json['call_id'] as String? ?? 'result_${now.millisecondsSinceEpoch}',
          type: type,
          content: '',
          timestamp: now,
          callId: json['call_id'] as String?,
          toolStatus: status,
          toolResult: json['result'],
          toolName: json['tool'] as String?,
          durationMs: json['duration_ms'] as int?,
          errorMessage: statusStr != 'success' ? json['error'] as String? : null,
        );

      case AgentMessageType.answer:
        return AgentMessage(
          id: 'answer_${now.millisecondsSinceEpoch}',
          type: type,
          content: json['content'] as String? ?? '',
          timestamp: now,
        );

      case AgentMessageType.error:
        return AgentMessage(
          id: 'error_${now.millisecondsSinceEpoch}',
          type: type,
          content: '',
          timestamp: now,
          errorMessage: json['error'] as String? ?? json['content'] as String? ?? '未知错误',
        );

      case AgentMessageType.done:
        return AgentMessage(
          id: 'done_${now.millisecondsSinceEpoch}',
          type: type,
          content: '',
          timestamp: now,
        );
    }
  }

  AgentMessage copyWith({
    String? content,
    ToolCallStatus? toolStatus,
    dynamic toolResult,
    String? errorMessage,
    int? durationMs,
    String? toolName,
  }) {
    return AgentMessage(
      id: id,
      type: type,
      content: content ?? this.content,
      timestamp: timestamp,
      toolName: toolName ?? this.toolName,
      toolArgs: toolArgs,
      callId: callId,
      toolStatus: toolStatus ?? this.toolStatus,
      toolResult: toolResult ?? this.toolResult,
      errorMessage: errorMessage ?? this.errorMessage,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}

/// 一组Agent消息的聚合视图（用于UI展示）
class AgentResponseGroup {
  final List<AgentMessage> thinkingMessages;
  final List<AgentMessage> toolCalls;
  final List<AgentMessage> answers;
  final bool isComplete;
  final String? error;

  const AgentResponseGroup({
    this.thinkingMessages = const [],
    this.toolCalls = const [],
    this.answers = const [],
    this.isComplete = false,
    this.error,
  });

  String get fullAnswer => answers.map((a) => a.content).join();
  bool get hasThinking => thinkingMessages.isNotEmpty;
  bool get hasTools => toolCalls.isNotEmpty;
  String get thinkingContent => thinkingMessages.map((t) => t.content).join('\n');
}
