import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_styles.dart';

/// AI 模型设置界面
/// Provider 列表管理、API Key 配置、连接测试、默认模型选择
class ModelSettingsScreen extends ConsumerStatefulWidget {
  const ModelSettingsScreen({super.key});

  @override
  ConsumerState<ModelSettingsScreen> createState() =>
      _ModelSettingsScreenState();
}

class _ModelSettingsScreenState extends ConsumerState<ModelSettingsScreen> {
  /// 当前选中的 Provider
  String? _selectedProvider;

  /// 各 Provider 的配置数据
  final Map<String, _ProviderConfig> _configs = {
    'openai': _ProviderConfig(
      id: 'openai',
      name: 'OpenAI',
      icon: Icons.auto_awesome_rounded,
      color: const Color(0xFF10A37F),
      description: 'GPT-4o, GPT-4, GPT-3.5 Turbo',
      apiKey: '',
      baseUrl: 'https://api.openai.com/v1',
      models: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'],
    ),
    'qwen': _ProviderConfig(
      id: 'qwen',
      name: '通义千问',
      icon: Icons.cloud_rounded,
      color: const Color(0xFF615CED),
      description: 'Qwen-Max, Qwen-Plus, Qwen-Turbo',
      apiKey: '',
      baseUrl: 'https://dashscope.aliyuncs.com',
      models: ['qwen-max', 'qwen-plus', 'qwen-turbo', 'qwen-long'],
    ),
    'claude': _ProviderConfig(
      id: 'claude',
      name: 'Claude',
      icon: Icons.psychology_rounded,
      color: const Color(0xFFCC785C),
      description: 'Claude 3.5 Sonnet, Claude 3 Opus',
      apiKey: '',
      baseUrl: 'https://api.anthropic.com',
      models: [
        'claude-3-5-sonnet-20241022',
        'claude-3-opus-20240229',
        'claude-3-sonnet-20240229',
      ],
    ),
    'local': _ProviderConfig(
      id: 'local',
      name: '本地模型',
      icon: Icons.memory_rounded,
      color: const Color(0xFF6B7280),
      description: 'Ollama, LM Studio, 自定义端点',
      apiKey: '',
      baseUrl: 'http://localhost:11434',
      models: ['llama3', 'mistral', 'qwen2', 'codellama'],
    ),
  };

  /// API Key 输入控制器
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();

  /// 是否显示 API Key
  bool _showApiKey = false;

  /// 是否正在测试连接
  bool _isTesting = false;

  /// 测试结果
  String? _testResult;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('模型配置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ==================== Provider 列表 ====================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'AI 提供商',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primary(isDark),
              ),
            ),
          ),

          // Provider 卡片列表
          ..._configs.values.map((config) {
            return _buildProviderCard(context, config, isDark);
          }),

          const SizedBox(height: 8),

          // ==================== 选中 Provider 的配置区 ====================
          if (_selectedProvider != null) ...[
            _buildConfigSection(isDark),
          ],

          // ==================== 默认模型选择 ====================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              '默认模型',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primary(isDark),
              ),
            ),
          ),
          _buildDefaultModelSelector(isDark),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 构建 Provider 卡片
  Widget _buildProviderCard(
    BuildContext context,
    _ProviderConfig config,
    bool isDark,
  ) {
    final isSelected = _selectedProvider == config.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isSelected
              ? config.color
              : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedProvider = isSelected ? null : config.id;
              _apiKeyController.text = config.apiKey;
              _baseUrlController.text = config.baseUrl;
              _testResult = null;
            });
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Provider 图标
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: config.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(config.icon, color: config.color, size: 24),
                ),
                const SizedBox(width: 14),

                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            config.name,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                          if (config.apiKey.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.success(isDark).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusFull),
                              ),
                              child: Text(
                                '已配置',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.success(isDark),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config.description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),

                // 选择指示
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: config.color,
                    size: 22,
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textHint(isDark),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建配置区域
  Widget _buildConfigSection(bool isDark) {
    final config = _configs[_selectedProvider]!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(config.icon, color: config.color, size: 20),
              const SizedBox(width: 8),
              Text(
                '${config.name} 配置',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // API Base URL
          Text(
            'API 地址',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _baseUrlController,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary(isDark),
            ),
            decoration: InputDecoration(
              hintText: 'https://api.example.com/v1',
              prefixIcon: const Icon(Icons.link_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 16),

          // API Key
          Text(
            'API Key',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _apiKeyController,
            obscureText: !_showApiKey,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary(isDark),
              fontFamily: 'JetBrains Mono, monospace',
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'sk-xxxxxxxxxxxxxxxx',
              prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _showApiKey
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _showApiKey = !_showApiKey);
                },
              ),
            ),
            onChanged: (value) {
              config.apiKey = value;
            },
          ),
          const SizedBox(height: 20),

          // 操作按钮
          Row(
            children: [
              // 保存按钮
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    config.apiKey = _apiKeyController.text;
                    config.baseUrl = _baseUrlController.text;
                    _showSnackBar('配置已保存');
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('保存'),
                  style: FilledButton.styleFrom(
                    backgroundColor: config.color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 测试连接
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: config.color,
                          ),
                        )
                      : Icon(Icons.wifi_rounded, size: 18),
                  label: Text(_isTesting ? '测试中...' : '测试连接'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: config.color,
                    side: BorderSide(color: config.color),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          // 测试结果
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _testResult == '连接成功'
                    ? AppColors.success(isDark).withOpacity(0.1)
                    : AppColors.error(isDark).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _testResult == '连接成功'
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: _testResult == '连接成功'
                        ? AppColors.success(isDark)
                        : AppColors.error(isDark),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _testResult!,
                    style: TextStyle(
                      color: _testResult == '连接成功'
                          ? AppColors.success(isDark)
                          : AppColors.error(isDark),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 模型列表
          Text(
            '可用模型',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: config.models.map((model) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: config.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                    color: config.color.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  model,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: config.color,
                    fontSize: 11,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建默认模型选择器
  Widget _buildDefaultModelSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // 当前默认模型
          Row(
            children: [
              Icon(Icons.star_rounded,
                  color: AppColors.primary(isDark), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前默认: GPT-4o',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    Text(
                      '来自 OpenAI',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint(isDark), size: 22),
            ],
          ),
        ],
      ),
    );
  }

  /// 测试连接
  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    // 模拟连接测试
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isTesting = false;
      _testResult = _apiKeyController.text.isNotEmpty
          ? '连接成功'
          : '连接失败: API Key 不能为空';
    });
  }

  /// 显示 SnackBar
  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Provider 配置数据
class _ProviderConfig {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  String apiKey;
  String baseUrl;
  final List<String> models;

  _ProviderConfig({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.apiKey,
    required this.baseUrl,
    required this.models,
  });
}
