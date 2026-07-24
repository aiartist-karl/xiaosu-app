// ============================================================================
// 小酥 - 工具调用卡片（支持多种工具类型）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/agent_message.dart';

/// 工具调用卡片组件
class ToolCallCard extends StatefulWidget {
  final AgentMessage message;
  final VoidCallback? onTap;

  const ToolCallCard({
    super.key,
    required this.message,
    this.onTap,
  });

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final msg = widget.message;
    final toolConfig = ToolTypeConfig.getConfig(msg.toolName ?? 'unknown');
    final toolColor = _hexToColor(toolConfig.colorHex);
    final status = msg.toolStatus ?? ToolCallStatus.pending;
    final isRunning = status == ToolCallStatus.running || status == ToolCallStatus.pending;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? toolColor.withOpacity(0.08)
            : toolColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: toolColor.withOpacity(isRunning ? 0.5 : 0.2),
          width: isRunning ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片头部：图标 + 名称 + 状态
          _buildHeader(toolConfig, toolColor, status, isRunning, isDark),
          
          // 工具参数摘要
          if (msg.toolArgs != null && msg.toolArgs!.isNotEmpty)
            _buildArgsSummary(msg.toolArgs!, toolColor, isDark),
          
          // 执行中动画
          if (isRunning) _buildRunningIndicator(toolColor),
          
          // 执行结果（成功/失败）
          if (status == ToolCallStatus.success || status == ToolCallStatus.error)
            _buildResultSection(toolConfig, toolColor, isDark),
          
          // 耗时
          if (msg.durationMs != null && !isRunning)
            _buildDuration(msg.durationMs!, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ToolTypeConfig toolConfig,
    Color toolColor,
    ToolCallStatus status,
    bool isRunning,
    bool isDark,
  ) {
    return InkWell(
      onTap: widget.onTap ?? _toggleExpand,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
        child: Row(
        children: [
          // 工具图标
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: toolColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                toolConfig.icon,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 工具名 + 描述
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toolConfig.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (msg.toolName != null)
                  Text(
                    msg.toolName!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          // 状态指示
          _buildStatusBadge(status, toolColor),
          // 展开/折叠箭头
          if (widget.message.toolResult != null)
            RotationTransition(
              turns: _expandAnimation.drive(Tween(begin: 0.0, end: 0.5)),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: toolColor.withOpacity(0.6),
                size: 20,
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildStatusBadge(ToolCallStatus status, Color toolColor) {
    switch (status) {
      case ToolCallStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '等待中',
            style: TextStyle(fontSize: 11, color: Colors.orange[700]),
          ),
        );
      case ToolCallStatus.running:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: toolColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '执行中',
            style: TextStyle(fontSize: 11, color: toolColor),
          ),
        );
      case ToolCallStatus.success:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
              const SizedBox(width: 3),
              Text(
                '成功',
                style: TextStyle(fontSize: 11, color: Colors.green[700]),
              ),
            ],
          ),
        );
      case ToolCallStatus.error:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, size: 12, color: Colors.red[700]),
              const SizedBox(width: 3),
              Text(
                '失败',
                style: TextStyle(fontSize: 11, color: Colors.red[700]),
              ),
            ],
          ),
        );
      case ToolCallStatus.timeout:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '超时',
            style: TextStyle(fontSize: 11, color: Colors.amber[700]),
          ),
        );
    }
  }

  Widget _buildArgsSummary(
    Map<String, dynamic> args,
    Color toolColor,
    bool isDark,
  ) {
    // 根据工具类型展示不同的参数摘要
    final summary = _getToolSummary(args);

    if (summary.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(54, 0, 12, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          summary,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: isDark ? Colors.white70 : Colors.grey[700],
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  String _getToolSummary(Map<String, dynamic> args) {
    final toolName = widget.message.toolName ?? '';
    switch (toolName) {
      case 'bash_execute':
        return '命令: ${args['command'] ?? ''}';
      case 'web_search':
        return '搜索: ${args['query'] ?? args['keyword'] ?? ''}';
      case 'web_fetch':
        return 'URL: ${args['url'] ?? ''}';
      case 'github_api':
        final action = args['action'] ?? args['operation'] ?? '';
        final repo = args['repo'] ?? args['repository'] ?? '';
        return '$action $repo';
      case 'image_generate':
        return '提示词: ${args['prompt'] ?? ''}';
      case 'calendar_create':
        return '${args['title'] ?? args['summary'] ?? ''}\n${args['time'] ?? args['start_time'] ?? ''}';
      case 'email_send':
        return '收件人: ${args['to'] ?? args['recipient'] ?? ''}\n主题: ${args['subject'] ?? ''}';
      case 'memory_save':
        return '保存: ${args['content'] ?? ''}'.substring(0, (args['content'] ?? '').toString().length.clamp(0, 80));
      case 'memory_search':
        return '搜索: ${args['query'] ?? ''}';
      case 'process_manager':
        return '${args['action'] ?? ''}: ${args['process'] ?? args['name'] ?? ''}';
      case 'file_write':
        return '写入: ${args['path'] ?? args['file'] ?? ''}';
      case 'file_read':
        return '读取: ${args['path'] ?? args['file'] ?? ''}';
      case 'code_execute':
        return '语言: ${args['language'] ?? ''}\n${args['code'] ?? ''}'.substring(0, 80);
      default:
        // 通用：显示前几个参数
        if (args.isEmpty) return '';
        final entries = args.entries.take(2).toList();
        return entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
  }

  Widget _buildRunningIndicator(Color toolColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(54, 4, 12, 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: toolColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _getRunningText(),
            style: TextStyle(
              fontSize: 12,
              color: toolColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getRunningText() {
    switch (widget.message.toolName) {
      case 'bash_execute':
        return '正在执行命令...';
      case 'web_search':
        return '正在搜索...';
      case 'web_fetch':
        return '正在抓取网页...';
      case 'github_api':
        return '正在操作GitHub...';
      case 'image_generate':
        return '正在生成图片...';
      case 'calendar_create':
        return '正在创建日历事件...';
      case 'email_send':
        return '正在发送邮件...';
      case 'memory_save':
        return '正在保存记忆...';
      case 'memory_search':
        return '正在搜索记忆...';
      case 'process_manager':
        return '正在管理进程...';
      default:
        return '正在执行...';
    }
  }

  Widget _buildResultSection(
    ToolTypeConfig toolConfig,
    Color toolColor,
    bool isDark,
  ) {
    final result = widget.message.toolResult;
    if (result == null) return const SizedBox.shrink();

    final resultStr = result.toString();
    final isError = widget.message.toolStatus == ToolCallStatus.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 结果摘要
        if (!_isExpanded && resultStr.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(54, 2, 12, 8),
            child: Text(
              _getResultPreview(resultStr, isError),
              style: TextStyle(
                fontSize: 12,
                color: isError
                    ? Colors.red[isDark ? 300 : 700]
                    : (isDark ? Colors.white70 : Colors.grey[700]),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        // 展开的完整结果
        if (_isExpanded && resultStr.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(54, 2, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 根据工具类型特殊渲染结果
                _buildDetailedResult(toolName: widget.message.toolName ?? '', result: resultStr, isError: isError),
                // 复制按钮
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: resultStr));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制到剪贴板'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 12, color: toolColor.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          '复制结果',
                          style: TextStyle(fontSize: 11, color: toolColor.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDetailedResult({
    required String toolName,
    required String result,
    required bool isError,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 特殊工具的结果渲染
    switch (toolName) {
      case 'image_generate':
        // 图片生成结果可能包含URL
        if (result.startsWith('http') || result.contains('http')) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Image.network(
                    result.trim(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildTextResult(result, isError, isDark),
                  ),
                ),
              ),
            ],
          );
        }
        return _buildTextResult(result, isError, isDark);
      
      case 'web_search':
      case 'memory_search':
        // 搜索结果用列表展示
        return _buildTextResult(result, isError, isDark);
      
      default:
        return _buildTextResult(result, isError, isDark);
    }
  }

  Widget _buildTextResult(String result, bool isError, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? (isError ? Colors.red.withOpacity(0.08) : Colors.white.withOpacity(0.05))
            : (isError ? Colors.red.withOpacity(0.04) : Colors.grey.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? Colors.red.withOpacity(0.2)
              : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: SelectableText(
        result.length > 2000 ? result.substring(0, 2000) + '\n...(内容已截断)' : result,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: isError
              ? (isDark ? Colors.red[300] : Colors.red[800])
              : (isDark ? Colors.white70 : Colors.grey[800]),
          height: 1.5,
        ),
      ),
    );
  }

  String _getResultPreview(String result, bool isError) {
    final preview = result.length > 100 ? result.substring(0, 100) + '...' : result;
    return isError ? '❌ $preview' : '✅ $preview';
  }

  Widget _buildDuration(int durationMs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(54, 0, 12, 8),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 12,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            _formatDuration(durationMs),
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)}s';
    return '${(ms / 60000).toStringAsFixed(1)}min';
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  AgentMessage get msg => widget.message;
}
