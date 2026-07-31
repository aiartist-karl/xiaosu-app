// ============================================================================
// 小酥 v2 - 插件详情页
// 显示插件详细信息，配置插件参数
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/plugin_repository.dart';
import '../../data/models/plugin_model.dart';
import '../theme/app_colors.dart';

/// 插件详情页
class PluginDetailScreen extends StatefulWidget {
  final String pluginId;

  const PluginDetailScreen({super.key, required this.pluginId});

  @override
  State<PluginDetailScreen> createState() => _PluginDetailScreenState();
}

class _PluginDetailScreenState extends State<PluginDetailScreen> {
  final PluginRepository _repo = PluginRepository();

  PluginModel? _plugin;
  bool _isLoading = true;
  String? _error;
  bool _isInvoking = false;

  // 当前选中的工具和参数
  PluginTool? _selectedTool;
  final Map<String, TextEditingController> _paramControllers = {};

  // 调用结果
  Map<String, dynamic>? _invokeResult;
  String? _invokeError;

  @override
  void initState() {
    super.initState();
    _loadPlugin();
  }

  @override
  void dispose() {
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPlugin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 同时加载详情和工具列表
    final results = await Future.wait([
      _repo.fetchPluginDetail(widget.pluginId),
      _repo.fetchPluginTools(widget.pluginId),
    ]);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (results[0].success && results[0].data != null) {
        _plugin = results[0].data as PluginModel?;
      }
      // 合并工具列表
      if (results[1].success && results[1].data != null && (results[1].data as List<PluginTool>?)!.isNotEmpty) {
        _plugin = _plugin?.copyWith(tools: results[1].data as List<PluginTool>?) ?? _plugin;
      }
      if (_plugin == null) {
        _error = results[0].error ?? '加载失败';
      }
      // 默认选中第一个工具
      if (_plugin != null && _plugin!.tools.isNotEmpty && _selectedTool == null) {
        _selectedTool = _plugin!.tools.first;
        _initParamControllers();
      }
    });
  }

  void _initParamControllers() {
    // 清理旧的
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    _paramControllers.clear();

    if (_selectedTool == null) return;

    for (final param in _selectedTool!.parameters) {
      _paramControllers[param.name] = TextEditingController(
        text: param.defaultValue?.toString() ?? '',
      );
    }
  }

  void _selectTool(PluginTool tool) {
    setState(() {
      _selectedTool = tool;
      _invokeResult = null;
      _invokeError = null;
    });
    _initParamControllers();
  }

  Future<void> _invokeTool() async {
    if (_selectedTool == null || _plugin == null) return;

    final params = <String, dynamic>{};
    for (final entry in _paramControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        params[entry.key] = entry.value.text;
      }
    }

    setState(() {
      _isInvoking = true;
      _invokeResult = null;
      _invokeError = null;
    });

    final result = await _repo.invokePlugin(
      pluginId: _plugin!.id,
      toolName: _selectedTool!.name,
      params: params,
    );

    if (!mounted) return;

    setState(() {
      _isInvoking = false;
      if (result.success && result.data != null) {
        _invokeResult = result.data;
      } else {
        _invokeError = result.error ?? '调用失败';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_plugin?.name ?? '插件详情'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlugin,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(isDark)
              : _plugin != null
                  ? _buildContent(isDark)
                  : const SizedBox.shrink(),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.textHint(isDark)),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: AppColors.textSecondary(isDark))),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadPlugin,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 插件头部信息
        _buildHeader(isDark),
        const SizedBox(height: 20),
        // 工具列表（Tab 形式）
        if (_plugin!.tools.isNotEmpty) ...[
          Text(
            '可用工具（${_plugin!.tools.length}）',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 12),
          ..._plugin!.tools.map((tool) => _buildToolItem(tool, isDark)),
          const SizedBox(height: 20),
        ],
        // 参数配置区
        if (_selectedTool != null) ...[
          _buildParamsSection(isDark),
          const SizedBox(height: 16),
          // 调用结果
          if (_invokeResult != null || _invokeError != null)
            _buildResultSection(isDark),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.secondary(isDark).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: _plugin!.iconUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_plugin!.iconUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _plugin!.iconUrl == null
                    ? Icon(Icons.extension, size: 28, color: AppColors.secondary(isDark))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _plugin!.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _plugin!.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(isDark),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _infoChip('作者', _plugin!.author.isNotEmpty ? _plugin!.author : '未知', isDark),
              const SizedBox(width: 8),
              _infoChip('分类', _plugin!.category, isDark),
              const SizedBox(width: 8),
              _infoChip('版本', 'v${_plugin!.version}', isDark),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _infoChip('来源', _sourceLabel(_plugin!.sourceType), isDark),
              const SizedBox(width: 8),
              if (_plugin!.isPublished)
                _infoChip('状态', '已发布', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem(PluginTool tool, bool isDark) {
    final isSelected = _selectedTool?.id == tool.id;
    return GestureDetector(
      onTap: () => _selectTool(tool),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary(isDark).withOpacity(0.05)
              : AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary(isDark).withOpacity(0.3)
                : AppColors.divider(isDark),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected
                  ? AppColors.primary(isDark)
                  : AppColors.textHint(isDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  if (tool.description.isNotEmpty)
                    Text(
                      tool.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              '${tool.parameters.length}个参数',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textHint(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParamsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '参数配置 - ${_selectedTool!.name}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 4),
          if (_selectedTool!.description.isNotEmpty)
            Text(
              _selectedTool!.description,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          const SizedBox(height: 16),
          if (_paramControllers.isEmpty)
            Text(
              '该工具无需参数',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint(isDark),
              ),
            )
          else
            ..._selectedTool!.parameters.map((param) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _paramControllers[param.name],
                  decoration: InputDecoration(
                    labelText: '${param.name}${param.required ? ' *' : ''}',
                    hintText: param.description ?? '请输入${param.name}',
                    helperText: '类型：${param.type}',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: AppColors.surfaceVariant(isDark: isDark),
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isInvoking ? null : _invokeTool,
              icon: _isInvoking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isInvoking ? '调用中...' : '测试调用'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _invokeError != null
            ? AppColors.error(isDark).withOpacity(0.05)
            : AppColors.success(isDark).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _invokeError != null
              ? AppColors.error(isDark).withOpacity(0.3)
              : AppColors.success(isDark).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _invokeError != null ? Icons.error_outline : Icons.check_circle,
                size: 18,
                color: _invokeError != null
                    ? AppColors.error(isDark)
                    : AppColors.success(isDark),
              ),
              const SizedBox(width: 8),
              Text(
                _invokeError != null ? '调用失败' : '调用结果',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const Spacer(),
              if (_invokeResult != null)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _invokeResult.toString()),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制到剪贴板')),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _invokeError ?? _invokeResult.toString(),
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: _invokeError != null
                  ? AppColors.error(isDark)
                  : AppColors.textPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(isDark: isDark),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary(isDark),
        ),
      ),
    );
  }

  String _sourceLabel(PluginSourceType type) {
    switch (type) {
      case PluginSourceType.builtIn:
        return '内置';
      case PluginSourceType.coze:
        return 'Coze';
      case PluginSourceType.custom:
        return '自定义';
    }
  }
}
