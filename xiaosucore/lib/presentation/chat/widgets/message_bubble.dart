// ============================================================================
// 小酥 v3 - 消息气泡
// - 用户消息：右对齐，浅蓝背景 #E3F2FD
// - Bot 消息：左对齐，白色背景 + 轻微阴影
// - 圆角 12px，内边距 12px
// - 支持 Markdown 渲染（flutter_markdown）
// - 流式输出时：逐字显示（打字机效果，间隔 ~25ms）
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/chat_message.dart';
import 'tool_call_card.dart';
import '../../theme/app_colors.dart';

/// 消息气泡组件
class MessageBubble extends StatefulWidget {
  final ChatMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  /// 打字机效果：当前已显示的字符数
  int _displayedChars = 0;

  /// 用于打字机动画的 Timer
  Timer? _typewriterTimer;

  /// 上一次的内容长度（用于检测新内容追加）
  int _lastContentLength = 0;

  bool get _isUser => widget.message.role == MessageRole.user;
  bool get _isStreaming => widget.message.status == MessageStatus.streaming;

  @override
  void initState() {
    super.initState();
    _startTypewriterIfNeeded();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当消息内容变长（流式追加）时，启动打字机动画
    if (widget.message.content.length > _lastContentLength) {
      if (_isStreaming && !_isUser) {
        _startTypewriterIfNeeded();
      } else {
        // 已完成的消息直接显示全部
        _displayedChars = widget.message.content.length;
      }
    }
    _lastContentLength = widget.message.content.length;
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  void _startTypewriterIfNeeded() {
    if (_isUser) {
      _displayedChars = widget.message.content.length;
      return;
    }

    _typewriterTimer?.cancel();

    if (!_isStreaming || widget.message.content.isEmpty) {
      _displayedChars = widget.message.content.length;
      return;
    }

    // 如果还没开始打字机效果，从当前位置开始
    if (_displayedChars >= widget.message.content.length) {
      return;
    }

    _typewriterTimer = Timer.periodic(
      const Duration(milliseconds: 25),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_displayedChars >= widget.message.content.length) {
          if (!_isStreaming) {
            timer.cancel();
          }
          return;
        }
        setState(() {
          // 每次追加 1-2 个字符，模拟自然节奏
          _displayedChars = (_displayedChars + 1).clamp(
            0,
            widget.message.content.length,
          );
        });
      },
    );
  }

  /// 获取当前应显示的文本
  String get _visibleText {
    if (_isUser) return widget.message.content;
    if (_displayedChars >= widget.message.content.length) {
      return widget.message.content;
    }
    return widget.message.content.substring(0, _displayedChars);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
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
                backgroundColor: AppColors.primary(isDark).withOpacity(0.12),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isUser
                    ? const Color(0xFFE3F2FD)
                    : (isDark ? AppColors.aiBubble(isDark) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isUser
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 消息内容
                  _isUser ? _buildUserContent() : _buildAssistantContent(context, isDark),

                  // 工具调用卡片
                  if (widget.message.toolCalls != null &&
                      widget.message.toolCalls!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...widget.message.toolCalls!.map(
                      (tc) => ToolCallCard(toolCall: tc),
                    ),
                  ],

                  // 流式输出光标
                  if (_isStreaming && _displayedChars < widget.message.content.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _buildCursor(isDark),
                    ),

                  // 时间戳
                  if (widget.message.status == MessageStatus.completed && !_isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _formatTime(widget.message.timestamp),
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
              backgroundColor: AppColors.primary(isDark).withOpacity(0.15),
              child: const Text('👤', style: TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }

  /// 用户消息：纯文本（深色文字在浅蓝背景上）
  Widget _buildUserContent() {
    return Text(
      widget.message.content,
      style: const TextStyle(
        color: Color(0xFF1A1A2E),
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  /// 助手消息：Markdown 渲染（带打字机效果）
  Widget _buildAssistantContent(BuildContext context, bool isDark) {
    final text = _visibleText;
    if (text.isEmpty) {
      return Text(
        '•••',
        style: TextStyle(
          color: AppColors.textHint(isDark),
          fontSize: 15,
        ),
      );
    }

    return MarkdownBody(
      data: text,
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
      onTapLink: (text, href, title) async {
        if (href != null) {
          final uri = Uri.tryParse(href);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }

  /// 流式输出闪烁光标
  Widget _buildCursor(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 0.2),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 2,
            height: 16,
            color: AppColors.primary(isDark),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
