// ============================================================================
// 小酥 v2 - 消息气泡（支持 Markdown 渲染 + 代码高亮 + 工具调用卡片）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../models/chat_message.dart';
import 'tool_call_card.dart';
import '../../theme/app_colors.dart';

/// 消息气泡组件
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final List<ToolCallInfo>? toolCalls;

  const MessageBubble({
    super.key,
    required this.message,
    this.toolCalls,
  });

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 头像
          if (!_isUser) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Text('🧠', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 消息内容区
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: _isUser ? 14 : 12,
                vertical: _isUser ? 10 : 8,
              ),
              decoration: BoxDecoration(
                color: _isUser
                    ? AppColors.userBubble(isDark)
                    : AppColors.aiBubble(isDark),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(_isUser ? 18 : 4),
                  bottomRight: Radius.circular(_isUser ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 消息内容
                  _isUser ? _buildUserContent() : _buildAssistantContent(context, isDark),
                  // 工具调用卡片
                  if (toolCalls != null && toolCalls!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...toolCalls!.map((tc) => ToolCallCard(toolCall: tc)),
                  ],
                  // 状态指示
                  if (message.status == MessageStatus.streaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isUser ? Colors.white : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  // 时间
                  if (message.status == MessageStatus.completed && !_isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint(isDark),
                        ),
                      ),
                    ),
                ],
              ),
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

  /// 用户消息：纯文本
  Widget _buildUserContent() {
    return Text(
      message.content,
      style: TextStyle(
        color: AppColors.userBubbleTextLight,
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  /// 助手消息：Markdown 渲染
  Widget _buildAssistantContent(BuildContext context, bool isDark) {
    return MarkdownBody(
      data: message.content.isEmpty ? '•••' : message.content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: AppColors.textPrimary(isDark),
          fontSize: 15,
          height: 1.5,
        ),
        code: TextStyle(
          color: AppColors.primary(isDark),
          backgroundColor: isDark ? Colors.black26 : Colors.grey.shade200,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.surfaceVariant(isDark: isDark),
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          color: AppColors.primary(isDark).withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(
              color: AppColors.primary(isDark),
              width: 3,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.all(10),
        listBullet: TextStyle(
          color: AppColors.textSecondary(isDark),
        ),
        h1: TextStyle(
          color: AppColors.textPrimary(isDark),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        h2: TextStyle(
          color: AppColors.textPrimary(isDark),
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        h3: TextStyle(
          color: AppColors.textPrimary(isDark),
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        a: TextStyle(
          color: AppColors.info(isDark),
          decoration: TextDecoration.underline,
        ),
        tableBorder: TableBorder.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
        tableColumnWidth: const FlexColumnWidth(),
        tableCellsPadding: const EdgeInsets.all(8),
        tableHead: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(isDark),
        ),
        tableCellsDecoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        ),
      ),
      onTapLink: (text, href, title) {
        // TODO: 用 url_launcher 打开链接
      },
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
