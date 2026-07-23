import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_text_styles.dart';

/// AI 正在思考的动画指示器
/// 显示三个跳动圆点 + 可选的流式文字效果
class ThinkingIndicator extends StatefulWidget {
  /// 是否显示流式文字（打字机效果）
  final String? streamingText;

  /// 提示文字（非流式模式）
  final String hint;

  const ThinkingIndicator({
    super.key,
    this.streamingText,
    this.hint = '正在思考...',
  });

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  /// 圆点动画控制器
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 头像
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary(isDark).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(width: 10),

          // 思考内容区
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 圆点动画
                _buildDotAnimation(isDark),
                const SizedBox(height: 8),

                // 流式文字 或 提示文字
                if (widget.streamingText != null &&
                    widget.streamingText!.isNotEmpty)
                  _buildStreamingText(isDark)
                else
                  _buildHintText(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建三个跳动的圆点
  Widget _buildDotAnimation(bool isDark) {
    return AnimatedBuilder2(
      animation: _dotController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // 每个圆点有错开的动画相位
            final phase = (index * 0.2);
            final t = (_dotController.value + phase) % 1.0;
            final scale = 0.6 + 0.4 * _bounceCurve(t);
            final opacity = 0.4 + 0.6 * _bounceCurve(t);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8 * scale,
              height: 8 * scale,
              decoration: BoxDecoration(
                color: AppColors.primary(isDark).withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  /// 弹跳曲线
  double _bounceCurve(double t) {
    if (t < 0.5) {
      return t * 2;
    }
    return 2 - t * 2;
  }

  /// 构建流式文字显示（打字机效果）
  Widget _buildStreamingText(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.aiBubbleDark : AppColors.aiBubbleLight,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          topLeft: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.streamingText!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary(isDark),
              height: 1.6,
            ),
          ),
          // 光标闪烁
          const SizedBox(height: 2),
          _buildCursor(isDark),
        ],
      ),
    );
  }

  /// 构建提示文字
  Widget _buildHintText(bool isDark) {
    return Text(
      widget.hint,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary(isDark),
      ),
    );
  }

  /// 闪烁光标
  Widget _buildCursor(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        // 使用 sin 函数模拟闪烁
        final opacity = (value * 3.14159 * 2).sin.abs();
        return Opacity(
          opacity: opacity.clamp(0.2, 1.0),
          child: Container(
            width: 2,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary(isDark),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }
}

/// 扩展 double 的 sin 方法
extension _SinExtension on double {
  double get sin => _sin(this);

  static double _sin(double x) {
    // 使用 Taylor 级数近似
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
}

/// AnimatedBuilder2 是 AnimatedWidget 的包装
class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
