// ============================================================================
// 小酥 v3 - 聊天输入栏
// 布局：⊕ + 📎 + 模型名(Auto▼) + 输入框(提示"发送消息") + 🎤
// 输入文字后：输入框右侧出现发送按钮 ⬆（蓝色实心圆形）
// ============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 聊天输入栏组件
class ChatInput extends StatefulWidget {
  final void Function(String text) onSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onModelSelect;
  final VoidCallback? onStop;
  final VoidCallback? onVoice;
  final bool isLoading;
  final bool isStreaming;
  final String selectedModel;

  const ChatInput({
    super.key,
    required this.onSend,
    this.onAttachment,
    this.onModelSelect,
    this.onStop,
    this.onVoice,
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
        border: Border(
          top: BorderSide(color: AppColors.divider(isDark), width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 8,
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
              // ─── ⊕ 按钮（展开附件菜单） ───
              _buildCircleButton(
                icon: Icons.add,
                isDark: isDark,
                bgColor: AppColors.primary(isDark).withOpacity(0.1),
                iconColor: AppColors.primary(isDark),
                size: 34,
                onTap: _showAttachmentMenu,
              ),
              const SizedBox(width: 4),

              // ─── 📎 附件按钮 ───
              _buildCircleButton(
                icon: Icons.attach_file,
                isDark: isDark,
                bgColor: isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariantLight,
                iconColor: AppColors.textSecondary(isDark),
                size: 34,
                iconSize: 18,
                onTap: widget.onAttachment ?? () {},
              ),
              const SizedBox(width: 4),

              // ─── 模型选择器 (Auto▼) ───
              GestureDetector(
                onTap: widget.onModelSelect ?? () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceVariantDark
                        : AppColors.surfaceVariantLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.selectedModel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                      const SizedBox(width: 1),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // ─── 输入框 ───
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: '发送消息',
                    hintStyle: TextStyle(
                      color: AppColors.textHint(isDark),
                      fontSize: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant(isDark: isDark),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  onChanged: (v) =>
                      setState(() => _hasText = v.trim().isNotEmpty),
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // ─── 右侧操作区：🎤 或 ⬆ 发送 ───
              _buildRightAction(isDark),
            ],
          ),
        ],
      ),
    );
  }

  /// 右侧：有文字时显示发送按钮，否则显示 🎤 语音按钮
  Widget _buildRightAction(bool isDark) {
    if (_hasText) {
      // 发送按钮 ⬆（蓝色实心圆形）
      return GestureDetector(
        onTap: _handleSend,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary(isDark),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_upward,
            size: 18,
            color: Colors.white,
          ),
        ),
      );
    }

    // 🎤 语音按钮
    return _buildCircleButton(
      icon: Icons.mic,
      isDark: isDark,
      bgColor: isDark
          ? AppColors.surfaceVariantDark
          : AppColors.surfaceVariantLight,
      iconColor: AppColors.textSecondary(isDark),
      size: 34,
      iconSize: 18,
      onTap: widget.onVoice ?? () {},
    );
  }

  /// 通用圆形按钮
  Widget _buildCircleButton({
    required IconData icon,
    required bool isDark,
    required Color bgColor,
    required Color iconColor,
    required double size,
    double iconSize = 20,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }

  /// ⊕ 附件菜单 BottomSheet：上传图片、上传文件、拍照
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
              // 拖拽条
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
                  _menuItem(
                    Icons.image,
                    '上传图片',
                    AppColors.primary(isDark),
                    () => Navigator.pop(ctx),
                  ),
                  _menuItem(
                    Icons.description,
                    '上传文件',
                    AppColors.info(isDark),
                    () => Navigator.pop(ctx),
                  ),
                  _menuItem(
                    Icons.camera_alt,
                    '拍照',
                    AppColors.secondary(isDark),
                    () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
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
