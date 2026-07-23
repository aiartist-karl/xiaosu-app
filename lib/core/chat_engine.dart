// ============================================================================
// 小酥 (XiaoSu) - 对话引擎（ChatEngine）
//
// 这是整个 APP 最核心的模块，职责：
// 1. 整合 LLMProvider（大模型调用）、MemoryCenter（记忆检索）、SkillRegistry（技能注册表）
// 2. 支持流式对话（SSE / WebSocket 流式返回）
// 3. 实现 Function Calling 循环（LLM 返回 tool_call → 执行技能 → 结果回传 → 继续生成）
// 4. 注入 Persona（角色设定）和 RAG 记忆片段
// 5. 对话持久化（保存到本地数据库）
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

import 'package:xiaosu_core/main.dart' show appLogger;
import 'package:xiaosu_core/services/llm_provider.dart';
import 'package:xiaosu_core/services/memory_center.dart';
import 'package:xiaosu_core/services/skill_registry.dart';
import 'package:xiaosu_core/services/database_service.dart';
import 'package:xiaosu_core/models/chat_message.dart';
import 'package:xiaosu_core/models/conversation.dart';
import 'package:xiaosu_core/models/skill_definition.dart';

/// ============================================================================
/// 对话引擎 —— 小酥的"大脑"
///
/// 使用单例模式，全局唯一实例。在 main.dart 中初始化。
///
/// 核心工作流：
/// ┌─────────────────────────────────────────────────┐
/// │  用户输入                                        │
/// │    ↓                                             │
/// │  [1] RAG 检索相关记忆                            │
/// │    ↓                                             │
/// │  [2] 组装 System Prompt（Persona + 记忆 + 技能） │
/// │    ↓                                             │
/// │  [3] 调用 LLM（流式）                           │
/// │    ↓                                             │
/// │  [4] 判断是否有 tool_call                        │
/// │    ├─ 是 → 执行技能 → 结果回传 → 回到 [3]       │
/// │    └─ 否 → 输出最终回复                          │
/// │    ↓                                             │
/// │  [5] 持久化对话记录                              │
/// └─────────────────────────────────────────────────┘
/// ============================================================================
class ChatEngine {
  /// 单例实例
  ChatEngine._internal();
  static final ChatEngine instance = ChatEngine._internal();

  /// ─── 依赖服务引用 ───────────────────────────────────────────
  late LLMProvider _llmProvider;
  late MemoryCenter _memoryCenter;
  late SkillRegistry _skillRegistry;

  /// ─── 日志器 ─────────────────────────────────────────────────
  final Logger _logger = appLogger;

  /// ─── 对话状态缓存 ───────────────────────────────────────────
  /// 活跃的对话上下文（key: conversationId）
  final Map<String, ConversationContext> _activeContexts = {};

  /// ─── 全局配置 ───────────────────────────────────────────────
  /// Function Calling 最大递归深度（防止无限循环）
  static const int maxToolCallRounds = 10;

  /// 默认上下文窗口大小（最近 N 条消息）
  static const int defaultContextWindowSize = 20;

  /// ─── UUID 生成器 ────────────────────────────────────────────
  static const _uuid = Uuid();

  // ==========================================================================
  // 初始化
  // ==========================================================================

  /// 初始化对话引擎，注入依赖服务
  void initialize({
    required LLMProvider llmProvider,
    required MemoryCenter memoryCenter,
    required SkillRegistry skillRegistry,
  }) {
    _llmProvider = llmProvider;
    _memoryCenter = memoryCenter;
    _skillRegistry = skillRegistry;
    _logger.i('💬 ChatEngine 初始化完成');
  }

  // ==========================================================================
  // 流式对话（核心方法）
  // ==========================================================================

  /// 发送消息并获取流式回复
  ///
  /// [conversationId] 对话 ID，用于关联上下文
  /// [userMessage] 用户输入的消息文本
  /// [attachments] 附件列表（图片、文件路径等）
  ///
  /// 返回 Stream<ChatStreamEvent>，包含：
  /// - ChatStreamToken: 逐 token 输出的文本片段
  /// - ChatStreamToolCall: LLM 请求调用某个技能
  /// - ChatStreamToolResult: 技能执行结果
  /// - ChatStreamComplete: 对话完成
  /// - ChatStreamError: 发生错误
  Stream<ChatStreamEvent> sendMessage({
    required String conversationId,
    required String userMessage,
    List<String> attachments = const [],
  }) async* {
    _logger.i('💬 收到用户消息 [会话:$conversationId]: ${_truncate(userMessage, 50)}');

    // ─── 步骤 1：获取或创建对话上下文 ───────────────────────────
    ConversationContext context = await _getOrCreateContext(conversationId);

    // ─── 步骤 2：保存用户消息 ───────────────────────────────────
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: MessageRole.user,
      content: userMessage,
      attachments: attachments,
      timestamp: DateTime.now(),
    );
    await _persistMessage(userMsg);
    context.addMessage(userMsg);

    // ─── 步骤 3：RAG 检索相关记忆 ───────────────────────────────
    final memories = await _memoryCenter.searchRelevantMemories(
      query: userMessage,
      topK: 5,
    );
    _logger.d('🔍 RAG 检索到 ${memories.length} 条相关记忆');

    // ─── 步骤 4：组装 System Prompt ─────────────────────────────
    final systemPrompt = _buildSystemPrompt(
      persona: context.persona,
      memories: memories,
      availableSkills: _skillRegistry.getAllSkills(),
    );

    // ─── 步骤 5：构建消息历史 ───────────────────────────────────
    final messageHistory = _buildMessageHistory(context);

    // ─── 步骤 6：Function Calling 循环 ──────────────────────────
    int round = 0;
    List<Map<String, dynamic>> currentMessages = messageHistory;
    String finalResponse = '';
    final List<ChatStreamEvent> events = [];

    while (round < maxToolCallRounds) {
      round++;
      _logger.d('🔄 Function Calling 轮次: $round / $maxToolCallRounds');

      // 调用 LLM（流式）
      final llmRequest = LLMRequest(
        systemPrompt: systemPrompt,
        messages: currentMessages,
        tools: _skillRegistry.getToolDefinitions(),
        stream: true,
      );

      // 收集流式响应
      String accumulatedText = '';
      final List<ToolCall> toolCalls = [];

      await for (final chunk in _llmProvider.streamChat(llmRequest)) {
        if (chunk.hasContent) {
          accumulatedText += chunk.content;
          yield ChatStreamToken(
            conversationId: conversationId,
            token: chunk.content,
          );
        }

        if (chunk.hasToolCalls) {
          toolCalls.addAll(chunk.toolCalls);
          // 通知 UI 正在调用技能
          for (final tc in chunk.toolCalls) {
            yield ChatStreamToolCallStart(
              conversationId: conversationId,
              skillName: tc.function.name,
              arguments: tc.function.arguments,
            );
          }
        }
      }

      // ─── 判断是否有 Function Calling ─────────────────────────
      if (toolCalls.isEmpty) {
        // 没有 tool_call → 最终回复
        finalResponse = accumulatedText;
        break;
      }

      // ─── 执行技能调用 ───────────────────────────────────────
      // 将 assistant 的回复（含 tool_calls）加入消息历史
      currentMessages.add({
        'role': 'assistant',
        'content': accumulatedText.isNotEmpty ? accumulatedText : null,
        'tool_calls': toolCalls.map((tc) => tc.toJson()).toList(),
      });

      // 逐个执行技能
      for (final toolCall in toolCalls) {
        final result = await _executeToolCall(toolCall);
        yield ChatStreamToolResult(
          conversationId: conversationId,
          toolCallId: toolCall.id,
          skillName: toolCall.function.name,
          result: result,
          isSuccess: true,
        );

        // 将技能执行结果加入消息历史
        currentMessages.add({
          'role': 'tool',
          'tool_call_id': toolCall.id,
          'content': jsonEncode(result),
        });
      }

      // 继续下一轮循环，让 LLM 根据技能结果继续生成
    }

    // ─── 超过最大轮次仍未结束 ──────────────────────────────────
    if (round >= maxToolCallRounds && finalResponse.isEmpty) {
      finalResponse = '（技能调用轮次已达上限，自动终止）';
      yield ChatStreamError(
        conversationId: conversationId,
        error: 'Function Calling 递归深度超过 $maxToolCallRounds',
      );
    }

    // ─── 步骤 7：保存 AI 回复 ───────────────────────────────────
    final assistantMsg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: MessageRole.assistant,
      content: finalResponse,
      timestamp: DateTime.now(),
    );
    await _persistMessage(assistantMsg);
    context.addMessage(assistantMsg);

    // ─── 步骤 8：更新记忆（异步，不阻塞响应）──────────────────
    _updateMemoryAsync(conversationId, userMessage, finalResponse);

    // ─── 步骤 9：发出完成事件 ───────────────────────────────────
    yield ChatStreamComplete(
      conversationId: conversationId,
      messageId: assistantMsg.id,
      totalTokens: context.estimateTokenCount(),
    );

    _logger.i('✅ 对话完成 [会话:$conversationId] 轮次:$round');
  }

  // ==========================================================================
  // System Prompt 构建
  // ==========================================================================

  /// 构建完整的 System Prompt
  /// 包含：角色设定 + RAG 记忆片段 + 可用技能描述
  String _buildSystemPrompt({
    required String persona,
    required List<MemoryFragment> memories,
    required List<SkillDefinition> availableSkills,
  }) {
    final buffer = StringBuffer();

    // ─── 角色设定 ─────────────────────────────────────────────
    buffer.writeln(persona);
    buffer.writeln();

    // ─── RAG 记忆注入 ─────────────────────────────────────────
    if (memories.isNotEmpty) {
      buffer.writeln('## 相关记忆');
      buffer.writeln('以下是与当前对话相关的历史记忆，请在回复时适当参考：');
      buffer.writeln();
      for (final memory in memories) {
        buffer.writeln('- [${memory.category}] ${memory.content}');
        buffer.writeln('  （来源：${memory.source}，时间：${memory.timestamp.toString().substring(0, 10)}）');
      }
      buffer.writeln();
    }

    // ─── 当前时间 ─────────────────────────────────────────────
    buffer.writeln('## 当前环境');
    buffer.writeln('当前时间：${DateTime.now().toString()}');
    buffer.writeln();

    return buffer.toString();
  }

  // ==========================================================================
  // Function Calling 执行
  // ==========================================================================

  /// 执行单个技能调用
  ///
  /// [toolCall] LLM 返回的技能调用请求
  /// 返回技能执行结果（Map 格式）
  Future<Map<String, dynamic>> _executeToolCall(ToolCall toolCall) async {
    final skillName = toolCall.function.name;
    final arguments = toolCall.function.arguments;

    _logger.i('🛠️ 执行技能: $skillName');

    try {
      // 从注册表中获取技能处理器
      final handler = _skillRegistry.getHandler(skillName);
      if (handler == null) {
        throw SkillNotFoundException('技能 "$skillName" 未注册');
      }

      // 解析参数
      final Map<String, dynamic> params;
      if (arguments is String) {
        params = jsonDecode(arguments) as Map<String, dynamic>;
      } else {
        params = arguments as Map<String, dynamic>;
      }

      // 执行技能
      final result = await handler.execute(params);

      _logger.i('✅ 技能执行成功: $skillName');
      return {
        'status': 'success',
        'data': result,
      };
    } catch (e, stackTrace) {
      _logger.e('❌ 技能执行失败: $skillName - $e', stackTrace: stackTrace);
      return {
        'status': 'error',
        'error': e.toString(),
        'skill': skillName,
      };
    }
  }

  // ==========================================================================
  // 消息历史构建
  // ==========================================================================

  /// 构建发送给 LLM 的消息历史
  /// 只保留最近 N 条消息，避免超出上下文窗口
  List<Map<String, dynamic>> _buildMessageHistory(ConversationContext context) {
    final messages = context.recentMessages(defaultContextWindowSize);
    final result = <Map<String, dynamic>>[];

    for (final msg in messages) {
      final map = <String, dynamic>{
        'role': msg.role.value,
        'content': msg.content,
      };

      // 如果有附件（图片），加入多模态内容
      if (msg.attachments.isNotEmpty) {
        map['content'] = [
          {'type': 'text', 'text': msg.content},
          for (final att in msg.attachments)
            if (att.endsWith('.png') || att.endsWith('.jpg') || att.endsWith('.jpeg'))
              {'type': 'image_url', 'image_url': {'url': att}},
        ];
      }

      result.add(map);
    }

    return result;
  }

  // ==========================================================================
  // 对话上下文管理
  // ==========================================================================

  /// 获取或创建对话上下文
  Future<ConversationContext> _getOrCreateContext(String conversationId) async {
    if (_activeContexts.containsKey(conversationId)) {
      return _activeContexts[conversationId]!;
    }

    // 从数据库加载历史对话
    final conversation = await DatabaseService.instance.getConversation(conversationId);
    final messages = await DatabaseService.instance.getMessages(conversationId);

    final context = ConversationContext(
      conversationId: conversationId,
      persona: conversation?.persona ?? _defaultPersona(),
    );

    // 恢复历史消息到上下文
    for (final msg in messages) {
      context.addMessage(msg);
    }

    _activeContexts[conversationId] = context;
    return context;
  }

  /// 创建新对话
  Future<String> createConversation({
    String? title,
    String? persona,
  }) async {
    final conversationId = _uuid.v4();

    final conversation = Conversation(
      id: conversationId,
      title: title ?? '新对话',
      persona: persona ?? _defaultPersona(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await DatabaseService.instance.saveConversation(conversation);

    _activeContexts[conversationId] = ConversationContext(
      conversationId: conversationId,
      persona: conversation.persona,
    );

    _logger.i('📝 创建新对话: $conversationId');
    return conversationId;
  }

  /// 清除对话上下文缓存
  void clearContext(String conversationId) {
    _activeContexts.remove(conversationId);
    _logger.d('🧹 清除对话上下文: $conversationId');
  }

  // ==========================================================================
  // 持久化
  // ==========================================================================

  /// 持久化单条消息到数据库
  Future<void> _persistMessage(ChatMessage message) async {
    try {
      await DatabaseService.instance.saveMessage(message);
    } catch (e) {
      _logger.e('❌ 消息持久化失败: $e');
    }
  }

  /// 异步更新记忆（不阻塞对话响应）
  Future<void> _updateMemoryAsync(
    String conversationId,
    String userMessage,
    String assistantResponse,
  ) async {
    try {
      // 提取关键信息作为记忆
      await _memoryCenter.extractAndStoreMemories(
        conversationId: conversationId,
        userMessage: userMessage,
        assistantResponse: assistantResponse,
      );
      _logger.d('💾 记忆更新完成');
    } catch (e) {
      _logger.e('❌ 记忆更新失败: $e');
    }
  }

  // ==========================================================================
  // 默认 Persona
  // ==========================================================================

  /// 默认角色设定
  String _defaultPersona() {
    return '''
你是「小酥」，一个全能 AI Agent 助手。

## 性格特点
- 温暖友好，像一个贴心的朋友
- 专业高效，能快速理解用户需求
- 有自己的想法和判断，不只是机械回答
- 幽默但不油腻，偶尔会开个小玩笑

## 能力
- 你可以调用各种技能（工具）来完成用户的任务
- 你有长期记忆能力，能记住之前对话的内容
- 你可以进行多轮对话，理解上下文

## 行为规范
- 回复要简洁有条理，避免冗长
- 使用 Markdown 格式让回复更清晰
- 如果不确定，坦诚说明而不是编造
- 需要调用技能时，自然地和用户沟通进度
''';
  }

  // ==========================================================================
  // 工具方法
  // ==========================================================================

  /// 截断文本（用于日志输出）
  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

// ============================================================================
/// 对话上下文 —— 维护单个对话的运行时状态
/// ============================================================================
class ConversationContext {
  final String conversationId;
  final String persona;
  final List<ChatMessage> _messages = [];

  ConversationContext({
    required this.conversationId,
    required this.persona,
  });

  /// 获取所有消息
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// 添加一条消息
  void addMessage(ChatMessage message) {
    _messages.add(message);
  }

  /// 获取最近 N 条消息
  List<ChatMessage> recentMessages(int count) {
    if (_messages.length <= count) return List.of(_messages);
    return _messages.sublist(_messages.length - count);
  }

  /// 估算当前 Token 数量（粗略：中文约 1.5 字/token，英文约 4 字符/token）
  int estimateTokenCount() {
    int total = 0;
    for (final msg in _messages) {
      total += (msg.content.length / 1.5).ceil();
    }
    return total;
  }
}

// ============================================================================
/// 流式事件基类
/// ============================================================================
abstract class ChatStreamEvent {
  final String conversationId;
  const ChatStreamEvent({required this.conversationId});
}

/// 逐 Token 输出的文本片段
class ChatStreamToken extends ChatStreamEvent {
  final String token;
  const ChatStreamToken({
    required super.conversationId,
    required this.token,
  });
}

/// 技能调用开始
class ChatStreamToolCallStart extends ChatStreamEvent {
  final String skillName;
  final dynamic arguments;
  const ChatStreamToolCallStart({
    required super.conversationId,
    required this.skillName,
    required this.arguments,
  });
}

/// 技能执行结果
class ChatStreamToolResult extends ChatStreamEvent {
  final String toolCallId;
  final String skillName;
  final Map<String, dynamic> result;
  final bool isSuccess;
  const ChatStreamToolResult({
    required super.conversationId,
    required this.toolCallId,
    required this.skillName,
    required this.result,
    required this.isSuccess,
  });
}

/// 对话完成
class ChatStreamComplete extends ChatStreamEvent {
  final String messageId;
  final int totalTokens;
  const ChatStreamComplete({
    required super.conversationId,
    required this.messageId,
    required this.totalTokens,
  });
}

/// 对话错误
class ChatStreamError extends ChatStreamEvent {
  final String error;
  const ChatStreamError({
    required super.conversationId,
    required this.error,
  });
}

// ============================================================================
/// 技能未找到异常
/// ============================================================================
class SkillNotFoundException implements Exception {
  final String message;
  const SkillNotFoundException(this.message);

  @override
  String toString() => 'SkillNotFoundException: $message';
}
