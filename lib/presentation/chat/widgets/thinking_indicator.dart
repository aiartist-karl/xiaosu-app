// ============================================================================
// 小酥 - 思考中指示器
// ============================================================================

import 'package:flutter/material.dart';

/// 思考中指示器 - AI正在回复时的动画
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Text('🧠', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotAnimation(controller: _controller, index: 0),
                const SizedBox(width: 4),
                _DotAnimation(controller: _controller, index: 1),
                const SizedBox(width: 4),
                _DotAnimation(controller: _controller, index: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotAnimation extends StatelessWidget {
  final AnimationController controller;
  final int index;

  const _DotAnimation({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final delay = index * 0.2;
        final progress = (controller.value + delay) % 1.0;
        final opacity = 0.3 + 0.7 * (1.0 - (progress * 2 - 1).abs());
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
