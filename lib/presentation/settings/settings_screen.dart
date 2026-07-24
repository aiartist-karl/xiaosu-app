// ============================================================================
// 小酥 - 设置主页面（完整版）- 深色模式持久化
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app.dart';

/// 设置主页面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _themeKey = 'xiaosu_theme_mode';
  
  bool _darkMode = false;
  bool _enableMemory = true;
  bool _enableVoice = false;
  String _selectedModel = 'DeepSeek V4 Pro';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_themeKey) ?? 'system';
    setState(() {
      _darkMode = themeStr == 'dark';
      _isInitialized = true;
    });
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => _darkMode = value);
    
    final themeMode = value ? ThemeMode.dark : ThemeMode.light;
    ref.read(themeModeProvider.notifier).state = themeMode;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value ? 'dark' : 'light');
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
              subtitle: Text(_darkMode ? '当前：深色主题' : '当前：浅色主题'),
              value: _darkMode,
              onChanged: _setDarkMode,
              secondary: Icon(_darkMode ? Icons.dark_mode : Icons.light_mode),
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
              onTap: () => context.go('/skills'),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('插件商店'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/plugins'),
            ),
          ]),
          _buildSection('工具', [
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('工具集'),
              subtitle: const Text('日历、邮件、文件管理、记忆'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/tools'),
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

