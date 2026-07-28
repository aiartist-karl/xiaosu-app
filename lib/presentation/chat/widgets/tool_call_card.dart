// ============================================================================
// 小酥 v2 - 工具调用折叠卡片
// ============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 工具调用类型
enum ToolCallType {
  webSearch,      // 联网搜索
  fileRead,       // 读取文件
  imageGen,       // 生成图片
  mobileTask,     // 手机任务
  browserTask,    // 浏览器任务
  codeExecute,    // 代码执行
  apiCall,        // API调用
  other,          // 其他
}

/// 工具调用模型
class ToolCallInfo {
  final String id;
  final ToolCallType type;
  final String toolName;
  final String summary;
  final String? detail;
  final String? thumbnailUrl;
  final bool isCompleted;

  const ToolCallInfo({
    required this.id,
    required this.type,
    required this.toolName,
    required this.summary,
    this.detail,
    this.thumbnailUrl,
    this.isCompleted = true,
  });

  IconData get icon {
    switch (type) {
      case ToolCallType.webSearch: return Icons.search;
      case ToolCallType.fileRead: return Icons.description_outlined;
      case ToolCallType.imageGen: return Icons.image_outlined;
      case ToolCallType.mobileTask: return Icons.phone_android;
      case ToolCallType.browserTask: return Icons.language;
      case ToolCallType.codeExecute: return Icons.code;
      case ToolCallType.apiCall: return Icons.api;
      case ToolCallType.other: return Icons.build_outlined;
    }
  }

  Color iconColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case ToolCallType.webSearch: return AppColors.secondary(isDark);
      case ToolCallType.fileRead: return AppColors.info(isDark);
      case ToolCallType.imageGen: return AppColors.primary(isDark);
      case ToolCallType.mobileTask: return AppColors.success(isDark);
      case ToolCallType.browserTask: return AppColors.info(isDark);
      case ToolCallType.codeExecute: return AppColors.warning(isDark);
      case ToolCallType.apiCall: return AppColors.secondary(isDark);
      case ToolCallType.other: return AppColors.textSecondary(isDark);
    }
  }
}

/// 工具调用折叠卡片
class ToolCallCard extends StatefulWidget {
  final ToolCallInfo toolCall;

  const ToolCallCard({super.key, required this.toolCall});

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animController;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tool = widget.toolCall;
    final iconColor = tool.iconColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── 头部（始终可见） ───
          InkWell(
            onTap: tool.detail != null ? _toggle : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // 图标
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      tool.icon,
                      size: 16,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 工具名 + 摘要
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tool.toolName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tool.summary,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary(isDark),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 状态/展开箭头
                  if (!tool.isCompleted)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      ),
                    ),
                  if (tool.detail != null)
                    RotationTransition(
                      turns: _rotateAnimation,
                      child: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: AppColors.textHint(isDark),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ─── 展开详情 ───
          if (tool.detail != null)
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildDetail(isDark),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
        ],
      ),
    );
  }

  Widget _buildDetail(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 缩略图（如有）
          if (widget.toolCall.thumbnailUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.toolCall.thumbnailUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: Colors.grey.withOpacity(0.1),
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          // 详情文本
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.toolCall.detail!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(isDark),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
