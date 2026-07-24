// ============================================================================
// 小酥 (XiaoSu) - 设置页（完整版）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/agent_api_service.dart';
import '../../config/app_config.dart';

/// 设置页 —— 用户偏好、API配置、后端连接等
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AgentApiService _agentApi = AgentApiService.instance;
  bool _darkMode = false;
  bool _enableMemory = true;
  bool _enableVoice = false;
  bool _isTestingConnection = false;
  String? _connectionStatus;
  String _selectedModel = 'DeepSeek V4 Flash';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: ListView(
        children: [
          _buildSection('通用', [
            SwitchListTile(
              title: const Text('深色模式'),
              subtitle: const Text('跟随系统或手动切换'),
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v),
              secondary: const Icon(Icons.dark_mode),
            ),
          ]),
          _buildSection('AI 模型', [
            ListTile(
              leading: const Icon(Icons.smart_toy),
              title: const Text('默认模型'),
              subtitle: Text(_selectedModel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('model-settings'),
            ),
          ]),
          _buildSection('后端连接', [
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('后端API地址'),
              subtitle: Text(AppConfig.agentApiBase, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            ListTile(
              leading: const Icon(Icons.wifi_tethering),
              title: const Text('测试后端连接'),
              subtitle: _connectionStatus != null
                  ? Text(_connectionStatus!, style: TextStyle(
                      color: _connectionStatus == '✅ 连接正常' ? Colors.green : Colors.red,
                    ))
                  : const Text('点击检查后端服务是否可用'),
              trailing: _isTestingConnection
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              onTap: _isTestingConnection ? null : _testConnection,
            ),
            ListTile(
              leading: const Icon(Icons.settings_input_antenna),
              title: const Text('WebSocket连接'),
              subtitle: const Text('ws://47.116.29.140/agent/ws/chat'),
            ),
          ]),
          _buildSection('记忆', [
            SwitchListTile(
              title: const Text('长期记忆'),
              subtitle: const Text('记住重要信息，提升对话质量'),
              value: _enableMemory,
              onChanged: (v) => setState(() => _enableMemory = v),
              secondary: const Icon(Icons.memory),
            ),
          ]),
          _buildSection('语音', [
            SwitchListTile(
              title: const Text('语音回复'),
              subtitle: const Text('自动语音播报AI回复'),
              value: _enableVoice,
              onChanged: (v) => setState(() => _enableVoice = v),
              secondary: const Icon(Icons.record_voice_over),
            ),
          ]),
          _buildSection('技能与插件', [
            ListTile(
              leading: const Icon(Icons.extension),
              title: const Text('技能管理'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/skills'),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('插件商店'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/plugins'),
            ),
          ]),
          _buildSection('高级', [
            ListTile(
              leading: const Icon(Icons.monitor_heart),
              title: const Text('性能监控'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/monitor'),
            ),
            ListTile(
              leading: const Icon(Icons.work_outline),
              title: const Text('工作流编辑器'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/workflow'),
            ),
          ]),
          _buildSection('关于', [
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('版本'),
              subtitle: Text('v2.3.2 (Build 25)'),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('开源协议'),
              subtitle: const Text('MIT License'),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(title, style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          )),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final ok = await _agentApi.healthCheck();
      setState(() {
        _isTestingConnection = false;
        _connectionStatus = ok ? '✅ 连接正常' : '❌ 连接失败';
      });
    } catch (e) {
      setState(() {
        _isTestingConnection = false;
        _connectionStatus = '❌ 错误: $e';
      });
    }
  }
}
