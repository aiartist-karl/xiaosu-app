// ============================================================================
// 小酥 - 消息气泡（长按菜单：引用/复制/朗读）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../models/chat_message.dart';
import '../../../models/agent_message.dart';
import 'tool_call_card.dart';
import 'thinking_block.dart';
import '../../../core/services/tts_service.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final List<AgentMessage>? agentMessages;
  final bool isStreaming;
  final void Function(String content, String author)? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    this.agentMessages,
    this.isStreaming = false,
    this.onReply,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isSpeaking = false;

  ChatMessage get message => widget.message;
  List<AgentMessage>? get agentMessages => widget.agentMessages;
  bool get isStreaming => widget.isStreaming;
  bool get _isUser => message.role == MessageRole.user;

  void _toggleTts(String text) {
    if (_isSpeaking) {
      TtsService.instance.stop();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      TtsService.instance.speak(text).then((_) {
        if (mounted) setState(() => _isSpeaking = false);
      });
    }
  }

  void _showLongPressMenu(String content) {
    final author = _isUser ? '我' : '小酥';
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.format_quote),
              title: const Text('引用回复'),
              onTap: () {
                Navigator.pop(context);
                widget.onReply?.call(content, author);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制文本'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
              },
            ),
            if (!_isUser && content.isNotEmpty)
              ListTile(
                leading: Icon(_isSpeaking ? Icons.stop_circle : Icons.volume_up),
                title: Text(_isSpeaking ? '停止朗读' : '朗读'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleTts(content);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final replyContent = message.metadata?['reply_to'] as String?;
    final replyAuthor = message.metadata?['reply_to_author'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isUser) ...[
            CircleAvatar(radius: 16, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Text('🧠', style: TextStyle(fontSize: 16))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 引用预览
                if (replyContent != null)
                  Container(
                    margin: EdgeInsets.only(bottom: 4, left: _isUser ? 0 : 32, right: _isUser ? 32 : 0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3)),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: '回复 ${replyAuthor ?? ""}：', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                          TextSpan(text: replyContent, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
                // 气泡本体
                if (_isUser)
                  GestureDetector(
                    onLongPress: () => _showLongPressMenu(message.content),
                    child: _buildUserBubble(context, isDark),
                  )
                else
                  GestureDetector(
                    onLongPress: () => _showLongPressMenu(_getFullText()),
                    child: _buildAssistantContent(context, isDark),
                  ),
                // 时间戳
                if (message.status == MessageStatus.completed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formatTime(message.timestamp), style: TextStyle(fontSize: 11, color: _isUser ? Colors.white70 : (isDark ? Colors.white38 : Colors.grey))),
                        if (!_isUser && message.content.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _toggleTts(message.content),
                            child: Icon(_isSpeaking ? Icons.stop_circle : Icons.volume_up_outlined, size: 14, color: _isSpeaking ? Colors.blue : (isDark ? Colors.white38 : Colors.grey)),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(radius: 16, backgroundColor: Theme.of(context).colorScheme.secondaryContainer, child: const Text('👤', style: TextStyle(fontSize: 16))),
          ],
        ],
      ),
    );
  }

  String _getFullText() {
    if (agentMessages != null && agentMessages!.isNotEmpty) {
      final answers = agentMessages!.where((m) => m.type == AgentMessageType.answer).map((a) => a.content).join();
      if (answers.isNotEmpty) return answers;
    }
    return message.content;
  }

  Widget _buildUserBubble(BuildContext context, bool isDark) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4)),
      ),
      child: Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
    );
  }

  Widget _buildAssistantContent(BuildContext context, bool isDark) {
    final maxWidth = MediaQuery.of(context).size.width * 0.82;

    if (agentMessages != null && agentMessages!.isNotEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._buildAgentContent(context, isDark),
            if (isStreaming) const Padding(padding: EdgeInsets.only(top: 4, left: 4), child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))),
          ],
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242836) : const Color(0xFFF0F1F5),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.content.isNotEmpty)
            MarkdownBody(
              data: message.content,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 15, height: 1.5, color: isDark ? Colors.white : Colors.black87),
                code: TextStyle(backgroundColor: isDark ? Colors.black38 : Colors.grey[200], fontSize: 13, fontFamily: 'monospace'),
                codeblockDecoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              ),
              selectable: true,
            ),
          if (message.status == MessageStatus.streaming)
            const Padding(padding: EdgeInsets.only(top: 4), child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))),
          if (message.status == MessageStatus.error && message.content.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 14, color: Colors.red[isDark ? 300 : 700]),
              const SizedBox(width: 4),
              Text(message.content, style: TextStyle(color: Colors.red[isDark ? 300 : 700], fontSize: 13)),
            ]),
        ],
      ),
    );
  }

  List<Widget> _buildAgentContent(BuildContext context, bool isDark) {
    final widgets = <Widget>[];
    final msgs = agentMessages!;
    final thinkingMsgs = msgs.where((m) => m.type == AgentMessageType.thinking).toList();
    final toolCallMsgs = msgs.where((m) => m.type == AgentMessageType.toolCall).toList();
    final toolResultMsgs = msgs.where((m) => m.type == AgentMessageType.toolResult).toList();
    final answerMsgs = msgs.where((m) => m.type == AgentMessageType.answer).toList();
    final errorMessages = msgs.where((m) => m.type == AgentMessageType.error).toList();

    if (thinkingMsgs.isNotEmpty) widgets.add(ThinkingBlock(thinkingMessages: thinkingMsgs));

    final mergedTools = _mergeToolMessages(toolCallMsgs, toolResultMsgs);
    for (final tool in mergedTools) { widgets.add(ToolCallCard(message: tool)); }

    final fullAnswer = answerMsgs.map((a) => a.content).join();
    if (fullAnswer.isNotEmpty) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242836) : const Color(0xFFF0F1F5),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
          ),
          child: MarkdownBody(
            data: fullAnswer,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(fontSize: 15, height: 1.5, color: isDark ? Colors.white : Colors.black87),
              code: TextStyle(backgroundColor: isDark ? Colors.black38 : Colors.grey[200], fontSize: 13, fontFamily: 'monospace'),
              codeblockDecoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            ),
            selectable: true,
          ),
        ),
      );
    }

    if (errorMessages.isNotEmpty) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.2))),
          child: Row(children: [
            Icon(Icons.error_outline, size: 16, color: Colors.red[isDark ? 300 : 700]),
            const SizedBox(width: 8),
            Expanded(child: Text(errorMessages.map((e) => e.errorMessage ?? e.content).join('\n'), style: TextStyle(fontSize: 13, color: Colors.red[isDark ? 300 : 700]))),
          ]),
        ),
      );
    }

    return widgets;
  }

  List<AgentMessage> _mergeToolMessages(List<AgentMessage> calls, List<AgentMessage> results) {
    final Map<String, AgentMessage> merged = {};
    for (final msg in calls) { merged[msg.callId ?? msg.id] = msg; }
    for (final msg in results) {
      final key = msg.callId ?? msg.id;
      if (merged.containsKey(key)) {
        merged[key] = merged[key]!.copyWith(toolStatus: msg.toolStatus, toolResult: msg.toolResult, durationMs: msg.durationMs, errorMessage: msg.errorMessage);
      } else {
        merged[key] = msg;
      }
    }
    return merged.values.toList();
  }

  String _formatTime(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
