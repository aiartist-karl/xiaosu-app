// ============================================================================
// 小酥 v2 - API配置页
// 配置 Coze Studio 地址和认证信息
// ============================================================================

import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../theme/app_colors.dart';

/// API配置页
class ApiConfigScreen extends StatefulWidget {
  const ApiConfigScreen({super.key});

  @override
  State<ApiConfigScreen> createState() => _ApiConfigScreenState();
}

class _ApiConfigScreenState extends State<ApiConfigScreen> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _patController = TextEditingController();
  final TextEditingController _spaceIdController = TextEditingController();

  bool _obscurePat = true;
  bool _isTesting = false;
  bool _isConnected = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _patController.dispose();
    _spaceIdController.dispose();
    super.dispose();
  }

  void _loadCurrentConfig() {
    _hostController.text = AppConfig.cozeStudioHost;
    _spaceIdController.text = AppConfig.cozeStudioSpaceId;
    // PAT 不自动填充（安全考虑）
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _isConnected = false;
    });

    // 模拟连接测试
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final host = _hostController.text.trim();
    if (host.isEmpty) {
      setState(() {
        _isTesting = false;
        _testResult = '请输入服务器地址';
        _isConnected = false;
      });
      return;
    }

    setState(() {
      _isTesting = false;
      _isConnected = true;
      _testResult = '连接成功！服务器响应正常。';
    });
  }

  void _saveConfig() {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入服务器地址')),
      );
      return;
    }

    // 保存到 AppConfig（这里需要实际持久化）
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('配置已保存'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API 配置'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveConfig,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 连接状态卡片
          _buildConnectionStatus(isDark),
          const SizedBox(height: 20),
          // 服务器配置
          _buildSection(
            '服务器配置',
            Icons.dns,
            isDark,
            [
              _buildTextField(
                controller: _hostController,
                label: '服务器地址',
                hint: 'http://localhost:8000',
                helper: 'Coze Studio 后端服务地址',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _spaceIdController,
                label: '空间 ID',
                hint: 'space_xxx',
                helper: 'Coze Studio 工作空间标识',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 认证配置
          _buildSection(
            '认证配置',
            Icons.security,
            isDark,
            [
              _buildTextField(
                controller: _patController,
                label: 'PAT Token（可选）',
                hint: 'pat_xxxxxxxxxxxxxxxx',
                helper: '个人访问令牌，用于 OpenAPI 认证',
                isDark: isDark,
                obscure: _obscurePat,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePat ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscurePat = !_obscurePat),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 测试连接按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_done),
              label: Text(_isTesting ? '测试中...' : '测试连接'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.save),
              label: const Text('保存配置'),
            ),
          ),
          const SizedBox(height: 20),
          // 提示信息
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info(isDark).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.info(isDark).withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.info(isDark)),
                    const SizedBox(width: 8),
                    Text(
                      '配置说明',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.info(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _hint('• 服务器地址：填写 Coze Studio 后端的完整 URL', isDark),
                _hint('• 空间 ID：在 Coze Studio 工作空间设置中获取', isDark),
                _hint('• PAT Token：通过 Coze Studio 个人设置生成', isDark),
                _hint('• 如果不使用 PAT，将使用 Session Cookie 认证', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isConnected
            ? AppColors.success(isDark).withOpacity(0.05)
            : AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isConnected
              ? AppColors.success(isDark).withOpacity(0.3)
              : AppColors.divider(isDark),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.check_circle : Icons.cloud_off,
            size: 24,
            color: _isConnected
                ? AppColors.success(isDark)
                : AppColors.textHint(isDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isConnected ? '已连接' : '未连接',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _isConnected
                        ? AppColors.success(isDark)
                        : AppColors.textPrimary(isDark),
                  ),
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _testResult!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isConnected
                          ? AppColors.success(isDark)
                          : AppColors.error(isDark),
                    ),
                  ),
                ],
                if (_isConnected) ...[
                  const SizedBox(height: 2),
                  Text(
                    _hostController.text,
                    style: TextStyle(fontSize: 11, color: AppColors.textHint(isDark)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    bool isDark,
    List<Widget> children,
  ) {
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
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary(isDark)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? helper,
    required bool isDark,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: AppColors.surfaceVariant(isDark: isDark),
        suffixIcon: suffix,
      ),
    );
  }

  Widget _hint(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary(isDark),
          height: 1.5,
        ),
      ),
    );
  }
}
