// ============================================================================
// 小酥 - AI思考过程展示组件
// ============================================================================

import 'package:flutter/material.dart';
import '../../../models/agent_message.dart';

/// 思考过程折叠块
class ThinkingBlock extends StatefulWidget {
  final List<AgentMessage> thinkingMessages;
  final bool defaultExpanded;

  const ThinkingBlock({
    super.key,
    required this.thinkingMessages,
    this.defaultExpanded = false,
  });

  @override
  State<ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<ThinkingBlock>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.defaultExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heightAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thinkingContent = widget.thinkingMessages
        .map((m) => m.content)
        .join('\n')
        .trim();

    if (thinkingContent.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.amber.withOpacity(0.06)
            : Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          InkWell(
            onTap: _toggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  // 思考图标动画
                  _ThinkingDots(isAnimating: !_isExpanded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💭 思考过程',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber[300] : Colors.amber[800],
                      ),
                    ),
                  ),
                  // 内容长度
                  Text(
                    '${thinkingContent.length}字',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  RotationTransition(
                    turns: _heightAnimation.drive(Tween(begin: 0.0, end: 0.5)),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: isDark ? Colors.amber[300] : Colors.amber[700],
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 折叠内容
          SizeTransition(
            sizeFactor: _heightAnimation,
            axisAlignment: -1,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: SelectableText(
                  thinkingContent,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey[700],
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 思考动画点
class _ThinkingDots extends StatefulWidget {
  final bool isAnimating;
  const _ThinkingDots({required this.isAnimating});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isAnimating) _controller.repeat();
  }

  @override
  void didUpdateWidget(_ThinkingDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final progress = (_controller.value + delay) % 1.0;
            final opacity = 0.3 + 0.7 * (1.0 - (progress * 2 - 1).abs());
            return Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
