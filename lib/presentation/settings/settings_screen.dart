// ============================================================================
// 小酥 - 设置主页面（持久化版本）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置主页面 - 使用 SharedPreferences 持久化
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
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _darkMode = _prefs?.getBool('settings_dark_mode') ?? false;
      _enableMemory = _prefs?.getBool('settings_memory') ?? true;
      _enableVoice = _prefs?.getBool('settings_voice') ?? false;
      _selectedModel = _prefs?.getString('settings_model') ?? 'DeepSeek V4 Flash';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    await _prefs?.setString(key, value.toString());
    // 实际 key 需要动态拼接，这里简化处理
  }

  Future<void> _setDarkMode(bool v) async {
    await _prefs?.setBool('settings_dark_mode', v);
    setState(() => _darkMode = v);
  }

  Future<void> _setMemory(bool v) async {
    await _prefs?.setBool('settings_memory', v);
    setState(() => _enableMemory = v);
  }

  Future<void> _setVoice(bool v) async {
    await _prefs?.setBool('settings_voice', v);
    setState(() => _enableVoice = v);
  }

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
              onChanged: _setDarkMode,
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
              onChanged: _setMemory,
              secondary: const Icon(Icons.memory),
            ),
          ]),
          _buildSection('语音', [
            SwitchListTile(
              title: const Text('语音回复'),
              subtitle: const Text('自动语音播报AI回复'),
              value: _enableVoice,
              onChanged: _setVoice,
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
              leading: const Icon(Icons.account_tree),
              title: const Text('工作流管理'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('workflow'),
            ),
          ]),
          _buildSection('关于', [
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('版本'),
              subtitle: Text('v2.0.0'),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }
}
