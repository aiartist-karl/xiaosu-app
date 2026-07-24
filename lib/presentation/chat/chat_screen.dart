import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_styles.dart';
import 'chat_controller.dart';
import 'widgets/message_bubble.dart';
import 'widgets/chat_input.dart';
import 'widgets/thinking_indicator.dart';

/// 聊天主界面
/// 完整的对话界面，包含顶部栏、消息列表、输入区域
/// 支持流式输出、滚动加载历史、长按消息菜单等
class ChatScreen extends ConsumerStatefulWidget {
  /// 会话 ID（可选，用于打开特定会话）
  final String? sessionId;

  const ChatScreen({super.key, this.sessionId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  /// 消息列表滚动控制器
  final ScrollController _scrollController = ScrollController();

  /// 是否滚动到底部
  bool _isAtBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 如果有指定会话，切换过去
    if (widget.sessionId != null) {
      // 实际项目中应从存储加载会话
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 监听滚动事件
  void _onScroll() {
    // 检测是否在底部
    final isAtBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100;

    if (isAtBottom != _isAtBottom) {
      setState(() => _isAtBottom = isAtBottom);
    }

    // 滚动到顶部时加载历史消息
    if (_scrollController.position.pixels <= 50 &&
        !_scrollController.position.outOfRange) {
      ref.read(chatControllerProvider.notifier).loadMoreHistory();
    }
  }

  /// 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppTheme.durationNormal,
        curve: AppTheme.curveEmphasized,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatState = ref.watch(chatControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      // ==================== 顶部栏 ====================
      appBar: _buildAppBar(context, isDark, chatState),
      // ==================== 主体 ====================
      body: Column(
        children: [
          // 消息列表
          Expanded(child: _buildMessageList(context, isDark, chatState)),

          // 输入区域
          ChatInput(
            isGenerating: chatState.isGenerating,
            onSend: () {
              // 发送后滚动到底部
              Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
            },
            onStop: () {
              ref.read(chatControllerProvider.notifier).stopGenerating();
            },
            onVoiceInput: () {
              // TODO: 实现语音输入
              _showSnackBar(context, '语音输入功能开发中...', isDark);
            },
            onAttach: () {
              _showAttachSheet(context, isDark);
            },
          ),
        ],
      ),

      // 浮动回到底部按钮
      floatingActionButton: _isAtBottom
          ? null
          : FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              elevation: 2,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textPrimary(isDark),
              ),
            ),
    );
  }

  /// 构建顶部应用栏
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isDark,
    ChatState chatState,
  ) {
    final sessionTitle = chatState.currentSession?.title ?? '新对话';

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, size: 22),
        onPressed: () {
          Navigator.of(context).pushNamed('/sessions');
        },
      ),
      title: Column(
        children: [
          Text(
            sessionTitle,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary(isDark),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            chatState.isGenerating ? '生成中...' : '小酥 AI',
            style: AppTextStyles.labelSmall.copyWith(
              color: chatState.isGenerating
                  ? AppColors.primary(isDark)
                  : AppColors.textSecondary(isDark),
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
        // 模型选择
        PopupMenuButton<String>(
          icon: Icon(
            Icons.tune_rounded,
            color: AppColors.textSecondary(isDark),
            size: 22,
          ),
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          onSelected: (value) {
            // TODO: 切换模型
            debugPrint('选择模型: $value');
          },
          itemBuilder: (context) => [
            _buildModelMenuItem('GPT-4o', Icons.auto_awesome_rounded, isDark),
            _buildModelMenuItem('Claude 3.5', Icons.psychology_rounded, isDark),
            _buildModelMenuItem('通义千问', Icons.cloud_rounded, isDark),
            const Divider(height: 1),
            _buildModelMenuItem('更多模型...', Icons.settings_rounded, isDark),
          ],
        ),

        // 更多菜单
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_horiz_rounded,
            color: AppColors.textSecondary(isDark),
            size: 22,
          ),
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          onSelected: (value) {
            switch (value) {
              case 'new':
                ref.read(chatControllerProvider.notifier).newSession();
                break;
              case 'clear':
                _showClearDialog(context, isDark);
                break;
              case 'export':
                _showSnackBar(context, '导出功能开发中...', isDark);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'new',
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text('新建对话', style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.error(isDark)),
                  const SizedBox(width: 12),
                  Text(
                    '清空对话',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error(isDark),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  const Icon(Icons.ios_share_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text('导出对话', style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建模型菜单项
  PopupMenuItem<String> _buildModelMenuItem(
    String label,
    IconData icon,
    bool isDark,
  ) {
    return PopupMenuItem(
      value: label,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary(isDark)),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  /// 构建消息列表
  Widget _buildMessageList(
    BuildContext context,
    bool isDark,
    ChatState chatState,
  ) {
    if (chatState.messages.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      // 反向列表，新消息从底部开始
      reverse: false,
      itemCount: chatState.messages.length + _getExtraItemCount(chatState),
      itemBuilder: (context, index) {
        // 顶部加载更多指示器
        if (index == 0 && chatState.hasMoreHistory) {
          return _buildLoadMoreIndicator(isDark, chatState.isLoadingHistory);
        }

        final adjustedIndex = chatState.hasMoreHistory ? index - 1 : index;

        // 检查是否是思考指示器位置
        if (adjustedIndex >= chatState.messages.length) {
          if (chatState.isGenerating) {
            // 显示 AI 正在思考/流式输出
            final lastMessage = chatState.messages.last;
            if (lastMessage.isStreaming) {
              return ThinkingIndicator(
                streamingText: lastMessage.content,
              );
            }
            return const ThinkingIndicator();
          }
          return const SizedBox.shrink();
        }

        final message = chatState.messages[adjustedIndex];
        return MessageBubble(
          key: ValueKey(message.id),
          message: message,
          isSelected: chatState.selectedMessageId == message.id,
          onLongPress: () {
            ref.read(chatControllerProvider.notifier).selectMessage(message.id);
          },
          onCopy: () {
            ref.read(chatControllerProvider.notifier).copyMessage(message.id);
            _showSnackBar(context, '已复制', isDark);
            ref.read(chatControllerProvider.notifier).selectMessage(null);
          },
          onDelete: () {
            ref.read(chatControllerProvider.notifier).deleteMessage(message.id);
            _showSnackBar(context, '已删除', isDark);
          },
          onForward: () {
            _showSnackBar(context, '转发功能开发中...', isDark);
          },
        );
      },
    );
  }

  /// 计算额外项目数量（加载更多、思考指示器等）
  int _getExtraItemCount(ChatState chatState) {
    int count = 0;
    if (chatState.hasMoreHistory) count++; // 加载更多指示器
    return count;
  }

  /// 构建加载更多指示器
  Widget _buildLoadMoreIndicator(bool isDark, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary(isDark),
                  ),
                ),
              )
            : Text(
                '向上滚动加载更多历史',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint(isDark),
                ),
              ),
      ),
    );
  }

  /// 构建空状态（欢迎页）
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 60),
            // Logo / 欢迎图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryLight.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // 欢迎文字
            Text(
              '你好，我是小酥 🍪',
              style: AppTextStyles.displaySmall.copyWith(
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '你的全能 AI 助手，有什么我可以帮你的？',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // 快捷操作卡片
            _buildQuickActions(context, isDark),
          ],
        ),
      ),
    );
  }

  /// 构建快捷操作区
  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final actions = [
      _QuickAction(
        icon: Icons.edit_note_rounded,
        label: '帮我写文案',
        color: AppColors.primaryLight,
        message: '帮我写一篇关于周末生活的短文',
      ),
      _QuickAction(
        icon: Icons.code_rounded,
        label: '写段代码',
        color: AppColors.secondaryLight,
        message: '帮我写一个 Flutter 的倒计时组件',
      ),
      _QuickAction(
        icon: Icons.lightbulb_rounded,
        label: '头脑风暴',
        color: AppColors.warningLight,
        message: '我想做一个新的 APP，帮我头脑风暴一下',
      ),
      _QuickAction(
        icon: Icons.translate_rounded,
        label: '翻译内容',
        color: AppColors.infoLight,
        message: '帮我翻译以下内容：',
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions.map((action) {
        return GestureDetector(
          onTap: () {
            // 将快捷消息填入输入框
            ref.read(chatControllerProvider.notifier).updateInput(action.message);
          },
          child: Container(
            width: (MediaQuery.of(context).size.width - 76) / 2,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: action.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: action.color.withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(action.icon, color: action.color, size: 24),
                const SizedBox(height: 10),
                Text(
                  action.label,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 显示附件选择面板
  void _showAttachSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '选择附件',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachOption(
                      context,
                      icon: Icons.image_rounded,
                      label: '图片',
                      color: AppColors.primaryLight,
                      onTap: () {
                        Navigator.pop(context);
                        _showSnackBar(context, '图片选择开发中...', isDark);
                      },
                    ),
                    _buildAttachOption(
                      context,
                      icon: Icons.insert_drive_file_rounded,
                      label: '文件',
                      color: AppColors.infoLight,
                      onTap: () {
                        Navigator.pop(context);
                        _showSnackBar(context, '文件选择开发中...', isDark);
                      },
                    ),
                    _buildAttachOption(
                      context,
                      icon: Icons.camera_alt_rounded,
                      label: '拍照',
                      color: AppColors.successLight,
                      onTap: () {
                        Navigator.pop(context);
                        _showSnackBar(context, '拍照功能开发中...', isDark);
                      },
                    ),
                    _buildAttachOption(
                      context,
                      icon: Icons.link_rounded,
                      label: '链接',
                      color: AppColors.secondaryLight,
                      onTap: () {
                        Navigator.pop(context);
                        _showSnackBar(context, '链接解析开发中...', isDark);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建附件选项
  Widget _buildAttachOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示清空对话确认
  void _showClearDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清空对话'),
          content: const Text('确定要清空当前对话吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                ref.read(chatControllerProvider.notifier).newSession();
                Navigator.pop(context);
              },
              child: Text(
                '清空',
                style: TextStyle(color: AppColors.error(isDark)),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 显示 SnackBar
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
}

/// 快捷操作数据
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final String message;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.message,
  });
}
