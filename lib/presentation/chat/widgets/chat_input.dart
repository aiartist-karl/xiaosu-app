// ============================================================================
// 小酥 v2 - 聊天输入栏（含附件/模型切换/语音按钮）
// ============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 聊天输入栏组件
class ChatInput extends StatefulWidget {
  final void Function(String text) onSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onModelSelect;
  final VoidCallback? onStop;
  final bool isLoading;
  final bool isStreaming;
  final String selectedModel;

  const ChatInput({
    super.key,
    required this.onSend,
    this.onAttachment,
    this.onModelSelect,
    this.onStop,
    this.isLoading = false,
    this.isStreaming = false,
    this.selectedModel = 'Auto',
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() => _hasText = false);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(top: BorderSide(color: AppColors.divider(isDark), width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // + 按钮（展开附件菜单）
              GestureDetector(
                onTap: _showAttachmentMenu,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary(isDark).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, size: 20, color: AppColors.primary(isDark)),
                ),
              ),
              const SizedBox(width: 6),
              // 附件按钮
              GestureDetector(
                onTap: widget.onAttachment ?? () {},
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.attach_file, size: 18, color: AppColors.textSecondary(isDark)),
                ),
              ),
              const SizedBox(width: 8),
              // 输入框
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: '给小酥发消息...',
                    hintStyle: TextStyle(color: AppColors.textHint(isDark), fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant(isDark: isDark),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  onChanged: (v) => setState(() => _hasText = v.trim().isNotEmpty),
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 模型选择器 或 发送/停止按钮
              if (_hasText || widget.isStreaming)
                _buildActionButtons(isDark)
              else
                _buildModelSelector(isDark),
            ],
          ),
        ],
      ),
    );
  }

  /// 右侧：模型选择器（无文字时显示）
  Widget _buildModelSelector(bool isDark) {
    return GestureDetector(
      onTap: widget.onModelSelect ?? () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.selectedModel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary(isDark)),
          ],
        ),
      ),
    );
  }

  /// 右侧：发送按钮 + 停止按钮（有文字或流式输出时显示）
  Widget _buildActionButtons(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 停止按钮（流式输出时显示）
        if (widget.isStreaming)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: widget.onStop ?? () {},
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.error(isDark).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.stop, size: 18, color: AppColors.error(isDark)),
              ),
            ),
          ),
        // 发送按钮
        if (_hasText)
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary(isDark),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward, size: 18, color: Colors.white),
            ),
          ),
      ],
    );
  }

  /// 附件菜单（弹出底部选项）
  void _showAttachmentMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _menuItem(Icons.image, '图片', AppColors.primary(isDark), () {
                    Navigator.pop(ctx);
                  }),
                  _menuItem(Icons.description, '文件', AppColors.info(isDark), () {
                    Navigator.pop(ctx);
                  }),
                  _menuItem(Icons.camera_alt, '拍照', AppColors.secondary(isDark), () {
                    Navigator.pop(ctx);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
