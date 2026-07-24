// ============================================================================
// 小酥 - 设置主页面（完整版）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 设置主页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _enableMemory = true;
  bool _enableVoice = false;
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
              onTap: () => context.pushNamed('skill-manager'),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('插件商店'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('plugins'),
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
              onTap: () => context.pushNamed('workflow'),
            ),
          ]),
          _buildSection('关于', [
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('版本'),
              subtitle: Text('v2.3.0'),
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
            fontSize: 13, fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          )),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }
}
