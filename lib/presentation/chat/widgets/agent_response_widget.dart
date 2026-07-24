// ============================================================================
// 小酥 - Agent响应组合组件
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../models/agent_message.dart';
import 'tool_call_card.dart';
import 'thinking_block.dart';

/// Agent响应消息组件（包含思考+工具调用+回答）
class AgentResponseWidget extends StatelessWidget {
  final List<AgentMessage> agentMessages;
  final String finalAnswer;
  final bool isStreaming;

  const AgentResponseWidget({
    super.key,
    required this.agentMessages,
    required this.finalAnswer,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final thinking = agentMessages
        .where((m) => m.type == AgentMessageType.thinking)
        .toList();
    final toolCalls = agentMessages
        .where((m) => m.type == AgentMessageType.toolCall || m.type == AgentMessageType.toolResult)
        .toList();
    final answers = agentMessages
        .where((m) => m.type == AgentMessageType.answer)
        .toList();
    
    // 合并tool_call和tool_result
    final mergedTools = _mergeToolMessages(toolCalls);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 思考过程（折叠）
        if (thinking.isNotEmpty)
          ThinkingBlock(thinkingMessages: thinking),

        // 工具调用卡片列表
        ...mergedTools.map((tool) => ToolCallCard(message: tool)),

        // 最终回答（Markdown）
        if (finalAnswer.isNotEmpty)
          _buildAnswer(context, finalAnswer),
        
        // 流式中的光标
        if (isStreaming && finalAnswer.isNotEmpty)
          _buildStreamingCursor(context),
      ],
    );
  }

  List<AgentMessage> _mergeToolMessages(List<AgentMessage> tools) {
    final Map<String, AgentMessage> merged = {};
    
    for (final msg in tools) {
      if (msg.type == AgentMessageType.toolCall) {
        merged[msg.callId ?? msg.id] = msg;
      } else if (msg.type == AgentMessageType.toolResult) {
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
    }
    
    return merged.values.toList();
  }

  Widget _buildAnswer(BuildContext context, String answer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF242836)
            : const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
      ),
      child: MarkdownBody(
        data: answer,
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
          a: TextStyle(
            color: isDark ? Colors.blue[300] : Colors.blue[700],
            decoration: TextDecoration.underline,
          ),
        ),
        selectable: true,
      ),
    );
  }

  Widget _buildStreamingCursor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 2,
            height: 16,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ],
      ),
    );
  }
}
