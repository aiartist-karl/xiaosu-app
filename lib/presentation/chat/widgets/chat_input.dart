import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_text_styles.dart';
import '../chat_controller.dart';

/// 聊天输入区域组件
/// 包含多行输入框、发送按钮、语音按钮、附件按钮、@技能选择
class ChatInput extends ConsumerStatefulWidget {
  /// 是否正在生成中（控制显示停止按钮）
  final bool isGenerating;

  /// 发送回调
  final VoidCallback? onSend;

  /// 停止生成回调
  final VoidCallback? onStop;

  /// 语音输入回调
  final VoidCallback? onVoiceInput;

  /// 附件选择回调
  final VoidCallback? onAttach;

  const ChatInput({
    super.key,
    this.isGenerating = false,
    this.onSend,
    this.onStop,
    this.onVoiceInput,
    this.onAttach,
  });

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput>
    with SingleTickerProviderStateMixin {
  /// 文本控制器
  late final TextEditingController _textController;

  /// 焦点节点
  late final FocusNode _focusNode;

  /// 输入框高度动画控制器
  late AnimationController _heightController;
  late Animation<double> _heightAnimation;

  /// 当前输入框高度
  double _inputHeight = 48;

  /// 最大输入框高度
  static const double _maxInputHeight = 160;

  /// 最小输入框高度
  static const double _minInputHeight = 48;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();

    _heightController = AnimationController(
      vsync: this,
      duration: AppTheme.durationNormal,
    );
    _heightAnimation = Tween<double>(
      begin: _minInputHeight,
      end: _minInputHeight,
    ).animate(CurvedAnimation(
      parent: _heightController,
      curve: AppTheme.curveEmphasized,
    ));

    // 监听文本变化以动态调整高度
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    _heightController.dispose();
    super.dispose();
  }

  /// 文本变化时调整输入框高度
  void _onTextChanged() {
    final text = _textController.text;
    ref.read(chatControllerProvider.notifier).updateInput(text);

    // 根据内容行数调整高度
    final textLength = text.split('\n').length;
    final estimatedHeight = (textLength * 22 + 24).clamp(
      _minInputHeight,
      _maxInputHeight,
    );

    if (estimatedHeight != _inputHeight) {
      setState(() => _inputHeight = estimatedHeight);
    }
  }

  /// 处理发送
  void _handleSend() {
    if (widget.isGenerating) {
      widget.onStop?.call();
      ref.read(chatControllerProvider.notifier).stopGenerating();
      return;
    }

    if (_textController.text.trim().isEmpty) return;

    widget.onSend?.call();
    ref.read(chatControllerProvider.notifier).sendMessage();
    _textController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatState = ref.watch(chatControllerProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 生成状态指示
            if (widget.isGenerating) _buildGeneratingBar(isDark),

            // 输入区域主体
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 附件按钮
                  _buildAttachButton(isDark),
                  const SizedBox(width: 4),

                  // 输入框
                  Expanded(child: _buildInputField(isDark)),
                  const SizedBox(width: 8),

                  // 语音按钮（非生成状态时显示）或停止按钮（生成状态时显示）
                  if (!widget.isGenerating)
                    _buildVoiceButton(isDark)
                  else
                    _buildStopButton(isDark),
                  const SizedBox(width: 4),

                  // 发送按钮
                  _buildSendButton(isDark, chatState),
                ],
              ),
            ),

            // @技能快捷栏
            _buildSkillBar(isDark),
          ],
        ),
      ),
    );
  }

  /// 构建生成中状态指示条
  Widget _buildGeneratingBar(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary(isDark).withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '正在生成回复...',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建附件按钮
  Widget _buildAttachButton(bool isDark) {
    return IconButton(
      onPressed: widget.onAttach,
      icon: Icon(
        Icons.add_circle_outline_rounded,
        color: AppColors.textSecondary(isDark),
        size: 24,
      ),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }

  /// 构建输入框
  Widget _buildInputField(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxHeight: _maxInputHeight),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        maxLines: null,
        minLines: 1,
        maxLength: 5000,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary(isDark),
        ),
        cursorColor: AppColors.primary(isDark),
        decoration: InputDecoration(
          hintText: '发送消息给小酥...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textHint(isDark),
          ),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          counterText: '', // 隐藏字数统计
        ),
        textInputAction: TextInputAction.newline,
        onSubmitted: (_) => _handleSend(),
      ),
    );
  }

  /// 构建语音按钮
  Widget _buildVoiceButton(bool isDark) {
    return IconButton(
      onPressed: widget.onVoiceInput,
      icon: Icon(
        Icons.mic_rounded,
        color: AppColors.textSecondary(isDark),
        size: 24,
      ),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }

  /// 构建停止生成按钮
  Widget _buildStopButton(bool isDark) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.error(isDark).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: () {
          widget.onStop?.call();
          ref.read(chatControllerProvider.notifier).stopGenerating();
        },
        icon: Icon(
          Icons.stop_rounded,
          color: AppColors.error(isDark),
          size: 20,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  /// 构建发送按钮
  Widget _buildSendButton(bool isDark, ChatState chatState) {
    final hasText = chatState.inputText.trim().isNotEmpty;
    final canSend = hasText && !widget.isGenerating;

    return GestureDetector(
      onTap: canSend ? _handleSend : null,
      child: AnimatedSendButton(
        duration: AppTheme.durationFast,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: canSend ? AppColors.primaryGradient : null,
          color: canSend ? null : (isDark
              ? AppColors.surfaceVariantDark
              : AppColors.surfaceVariantLight),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          color: canSend
              ? Colors.white
              : AppColors.textHint(isDark),
          size: 20,
        ),
      ),
    );
  }

  /// 构建 @技能快捷栏
  Widget _buildSkillBar(bool isDark) {
    // 常用技能列表（实际应从技能管理器获取）
    final skills = [
      _SkillChip(label: '搜索', icon: Icons.search_rounded),
      _SkillChip(label: '翻译', icon: Icons.translate_rounded),
      _SkillChip(label: '总结', icon: Icons.summarize_rounded),
      _SkillChip(label: '代码', icon: Icons.code_rounded),
      _SkillChip(label: '图片', icon: Icons.image_rounded),
    ];

    return Container(
      height: 36,
      padding: const EdgeInsets.only(bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: skills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final skill = skills[index];
          return GestureDetector(
            onTap: () {
              // 在输入框插入 @技能 标记
              final current = _textController.text;
              _textController.text = '$current @${skill.label} ';
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.primary(isDark).withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(
                  color: AppColors.primary(isDark).withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    skill.icon,
                    size: 14,
                    color: AppColors.primary(isDark),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    skill.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary(isDark),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 带动画的发送按钮容器
/// 使用 Flutter 内置 AnimatedContainer 包装
class AnimatedSendButton extends StatelessWidget {
  final Duration duration;
  final double? width;
  final double? height;
  final BoxDecoration? decoration;
  final Widget? child;

  const AnimatedSendButton({
    super.key,
    required this.duration,
    this.width,
    this.height,
    this.decoration,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      width: width,
      height: height,
      decoration: decoration,
      child: child,
    );
  }
}

/// 技能快捷按钮数据
class _SkillChip {
  final String label;
  final IconData icon;

  const _SkillChip({required this.label, required this.icon});
}
