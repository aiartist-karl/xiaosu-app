import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_text_styles.dart';
import '../chat_controller.dart';

/// 消息气泡组件
/// 根据消息角色（用户/AI/系统/工具）渲染不同的气泡样式
/// 支持 Markdown 渲染、代码高亮、图片、工具调用结果展示
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final VoidCallback? onForward;

  const MessageBubble({
    super.key,
    required this.message,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onCopy,
    this.onDelete,
    this.onForward,
  });

  /// 是否为用户消息
  bool get _isUser => message.role == MessageRole.user;

  /// 是否为系统消息
  bool get _isSystem => message.role == MessageRole.system;

  /// 是否为工具调用消息
  bool get _isToolCall => message.role == MessageRole.tool;

  @override
  Widget build(BuildContext context) {
    // 系统消息用特殊样式
    if (_isSystem) {
      return _buildSystemMessage(context);
    }

    // 工具调用消息
    if (_isToolCall) {
      return _buildToolCallMessage(context);
    }

    return _buildChatBubble(context);
  }

  /// 构建普通聊天消息气泡
  Widget _buildChatBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // AI 消息左侧头像
          if (!_isUser) ...[
            _buildAvatar(isDark),
            const SizedBox(width: 10),
          ],

          // 消息主体
          Flexible(
            child: Column(
              crossAxisAlignment:
                  _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 气泡
                GestureDetector(
                  onTap: onTap,
                  onLongPress: onLongPress ??
                      () => _showContextMenu(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: _buildBubbleDecoration(isDark),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      child: _buildMessageContent(isDark),
                    ),
                  ),
                ),
                // 时间戳
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textHint(isDark),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 用户消息右侧头像
          if (_isUser) ...[
            const SizedBox(width: 10),
            _buildAvatar(isDark),
          ],
        ],
      ),
    );
  }

  /// 构建头像
  Widget _buildAvatar(bool isDark) {
    if (_isUser) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.secondary(isDark).withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.person_rounded,
          size: 18,
          color: AppColors.secondaryLight,
        ),
      );
    }
    // AI 头像
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 18,
        color: Colors.white,
      ),
    );
  }

  /// 构建气泡装饰
  BoxDecoration _buildBubbleDecoration(bool isDark) {
    return BoxDecoration(
      color: _isUser
          ? (isDark ? AppColors.userBubbleDark : AppColors.userBubbleLight)
          : (isDark ? AppColors.aiBubbleDark : AppColors.aiBubbleLight),
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(_isUser ? 18 : 4),
        bottomRight: Radius.circular(_isUser ? 4 : 18),
      ),
      border: isSelected
          ? Border.all(
              color: AppColors.primary(isDark),
              width: 1.5,
            )
          : null,
    );
  }

  /// 构建消息内容
  Widget _buildMessageContent(bool isDark) {
    switch (message.contentType) {
      case MessageContentType.image:
        return _buildImageContent(isDark);
      case MessageContentType.code:
        return _buildCodeContent(isDark);
      case MessageContentType.text:
      default:
        return _buildTextContent(isDark);
    }
  }

  /// 构建文本内容（支持 Markdown）
  Widget _buildTextContent(bool isDark) {
    // 用户消息直接用 Text，不解析 Markdown
    if (_isUser) {
      return Text(
        message.content,
        style: AppTextStyles.bodyMedium.copyWith(
          color: _isUser
              ? (isDark
                  ? AppColors.userBubbleTextDark
                  : AppColors.userBubbleTextLight)
              : AppColors.textPrimary(isDark),
        ),
      );
    }

    // AI 消息用 Markdown 渲染
    return MarkdownBody(
      data: message.content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary(isDark),
          height: 1.6,
        ),
        h1: AppTextStyles.headlineLarge.copyWith(
          color: AppColors.textPrimary(isDark),
        ),
        h2: AppTextStyles.headlineMedium.copyWith(
          color: AppColors.textPrimary(isDark),
        ),
        h3: AppTextStyles.headlineSmall.copyWith(
          color: AppColors.textPrimary(isDark),
        ),
        code: AppTextStyles.codeInline.copyWith(
          color: isDark ? const Color(0xFFE8895C) : const Color(0xFFD4764D),
          backgroundColor: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
        codeblockDecoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppColors.primary(isDark),
              width: 3,
            ),
          ),
        ),
        blockquotePadding:
            const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        listBullet: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary(isDark),
        ),
        linkStyle: TextStyle(
          color: AppColors.info(isDark),
          decoration: TextDecoration.underline,
        ),
        strong: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(isDark),
        ),
        em: TextStyle(
          fontStyle: FontStyle.italic,
          color: AppColors.textPrimary(isDark),
        ),
      ),
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href));
        }
      },
    );
  }

  /// 构建图片内容
  Widget _buildImageContent(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: message.imageUrl != null
          ? Image.network(
              message.imageUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: 200,
                  height: 150,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => _buildImageError(isDark),
            )
          : _buildImageError(isDark),
    );
  }

  /// 图片加载错误占位
  Widget _buildImageError(bool isDark) {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(isDark: isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 32,
            color: AppColors.textHint(isDark),
          ),
          const SizedBox(height: 8),
          Text(
            '图片加载失败',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint(isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建代码块内容
  Widget _buildCodeContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 语言标签
        if (message.codeLanguage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              message.codeLanguage!,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary(isDark),
                fontSize: 10,
              ),
            ),
          ),
        // 代码内容
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              message.content,
              style: AppTextStyles.codeBlock.copyWith(
                color: isDark
                    ? const Color(0xFFD4D4D8)
                    : const Color(0xFF2D2D2D),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建系统消息
  Widget _buildSystemMessage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant(isDark: isDark),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  message.content,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建工具调用消息
  Widget _buildToolCallMessage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 头像
          _buildAvatar(isDark),
          const SizedBox(width: 10),

          // 工具调用卡片
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? AppColors.dividerDark
                      : AppColors.dividerLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 工具名称
                  Row(
                    children: [
                      Icon(
                        Icons.build_rounded,
                        size: 14,
                        color: AppColors.info(isDark),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '调用工具: ${message.toolName ?? '未知'}',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.info(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 工具结果
                  if (message.toolResult != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(
                        message.toolResult!,
                        style: AppTextStyles.codeInline.copyWith(
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ),
                  // 消息内容
                  if (message.content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      message.content,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示长按上下文菜单
  void _showContextMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽指示条
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.divider(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 复制
                _buildMenuItem(
                  context,
                  icon: Icons.copy_rounded,
                  label: '复制',
                  isDark: isDark,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    Navigator.pop(context);
                    onCopy?.call();
                    _showSnackBar(context, '已复制到剪贴板', isDark);
                  },
                ),
                // 转发
                _buildMenuItem(
                  context,
                  icon: Icons.share_rounded,
                  label: '转发',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    onForward?.call();
                  },
                ),
                // 删除（仅用户消息或允许删除时）
                if (message.role != MessageRole.system)
                  _buildMenuItem(
                    context,
                    icon: Icons.delete_outline_rounded,
                    label: '删除',
                    isDark: isDark,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      onDelete?.call();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建菜单项
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isDark,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error(isDark) : null,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive
              ? AppColors.error(isDark)
              : AppColors.textPrimary(isDark),
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }

  /// 显示 SnackBar 提示
  void _showSnackBar(BuildContext context, String text, bool isDark) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) {
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    }
    return '${time.month}/${time.day}';
  }
}

// surfaceVariant 颜色已添加到 AppColors 工具方法中
