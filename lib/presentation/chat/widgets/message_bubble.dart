// ============================================================================
// 小酥 - 消息气泡（支持Agent消息类型）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../models/chat_message.dart';
import '../../../models/agent_message.dart';
import 'tool_call_card.dart';
import 'thinking_block.dart';

/// 消息气泡组件
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final List<AgentMessage>? agentMessages;
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    this.agentMessages,
    this.isStreaming = false,
  });

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI头像
          if (!_isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Text('🧠', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
          ],
          // 消息内容
          Flexible(
            child: Column(
              crossAxisAlignment: _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (_isUser)
                  _buildUserBubble(context, isDark)
                else
                  _buildAssistantContent(context, isDark),
                // 时间戳
                if (message.status == MessageStatus.completed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: _isUser
                            ? Colors.white70
                            : (isDark ? Colors.white38 : Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 用户头像
          if (_isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: const Text('👤', style: TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserBubble(BuildContext context, bool isDark) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Text(
        message.content,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildAssistantContent(BuildContext context, bool isDark) {
    final maxWidth = MediaQuery.of(context).size.width * 0.82;

    // 如果有Agent消息，使用增强展示
    if (agentMessages != null && agentMessages!.isNotEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._buildAgentContent(context, isDark),
            // 流式指示器
            if (isStreaming)
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
          ],
        ),
      );
    }

    // 普通消息气泡
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF242836)
            : const Color(0xFFF0F1F5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Markdown渲染
          if (message.content.isNotEmpty)
            MarkdownBody(
              data: message.content,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                code: TextStyle(
                  backgroundColor: isDark ? Colors.black38 : Colors.grey[200],
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              selectable: true,
            ),
          // 流式指示器
          if (message.status == MessageStatus.streaming)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          // 错误状态
          if (message.status == MessageStatus.error && message.content.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 14, color: Colors.red[isDark ? 300 : 700]),
                const SizedBox(width: 4),
                Text(
                  message.content,
                  style: TextStyle(color: Colors.red[isDark ? 300 : 700], fontSize: 13),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAgentContent(BuildContext context, bool isDark) {
    final widgets = <Widget>[];
    final msgs = agentMessages!;

    // 提取不同类型的消息
    final thinkingMsgs = msgs
        .where((m) => m.type == AgentMessageType.thinking)
        .toList();
    final toolCallMsgs = msgs
        .where((m) => m.type == AgentMessageType.toolCall)
        .toList();
    final toolResultMsgs = msgs
        .where((m) => m.type == AgentMessageType.toolResult)
        .toList();
    final answerMsgs = msgs
        .where((m) => m.type == AgentMessageType.answer)
        .toList();
    final errorMessages = msgs
        .where((m) => m.type == AgentMessageType.error)
        .toList();

    // 1. 思考过程（折叠展示）
    if (thinkingMsgs.isNotEmpty) {
      widgets.add(ThinkingBlock(thinkingMessages: thinkingMsgs));
    }

    // 2. 工具调用卡片（合并call和result）
    final mergedTools = _mergeToolMessages(toolCallMsgs, toolResultMsgs);
    for (final tool in mergedTools) {
      widgets.add(ToolCallCard(message: tool));
    }

    // 3. 最终回答
    final fullAnswer = answerMsgs.map((a) => a.content).join();
    if (fullAnswer.isNotEmpty) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF242836)
                : const Color(0xFFF0F1F5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: MarkdownBody(
            data: fullAnswer,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
              code: TextStyle(
                backgroundColor: isDark ? Colors.black38 : Colors.grey[200],
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              codeblockDecoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            selectable: true,
          ),
        ),
      );
    }

    // 4. 错误消息
    if (errorMessages.isNotEmpty) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: Colors.red[isDark ? 300 : 700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMessages.map((e) => e.errorMessage ?? e.content).join('\n'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red[isDark ? 300 : 700],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  List<AgentMessage> _mergeToolMessages(
    List<AgentMessage> calls,
    List<AgentMessage> results,
  ) {
    final Map<String, AgentMessage> merged = {};
    
    for (final msg in calls) {
      merged[msg.callId ?? msg.id] = msg;
    }
    
    for (final msg in results) {
      final key = msg.callId ?? msg.id;
      if (merged.containsKey(key)) {
        merged[key] = merged[key]!.copyWith(
          toolStatus: msg.toolStatus,
          toolResult: msg.toolResult,
          durationMs: msg.durationMs,
          errorMessage: msg.errorMessage,
        );
      } else {
        merged[key] = msg;
      }
    }
    
    return merged.values.toList();
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
