// ============================================================================
// 小酥 - 技能管理页面
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/skill/skill_registry.dart';

/// 技能管理页面
class SkillManagerScreen extends StatefulWidget {
  const SkillManagerScreen({super.key});

  @override
  State<SkillManagerScreen> createState() => _SkillManagerScreenState();
}

class _SkillManagerScreenState extends State<SkillManagerScreen> {
  final SkillRegistry _registry = SkillRegistry.instance;

  @override
  Widget build(BuildContext context) {
    final skills = _registry.allSkills;

    return Scaffold(
      appBar: AppBar(title: const Text('技能管理'), centerTitle: true),
      body: skills.isEmpty
          ? const Center(child: Text('暂无已注册技能'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: skills.length,
              itemBuilder: (context, index) {
                final skill = skills[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: skill.enabled
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.grey.shade200,
                      child: Text(_getSkillIcon(skill.skillId), style: const TextStyle(fontSize: 18)),
                    ),
                    title: Text(skill.name),
                    subtitle: Text(skill.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Switch(
                      value: skill.enabled,
                      onChanged: (v) {
                        setState(() => skill.enabled = v);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _getSkillIcon(String skillId) {
    const icons = {
      'image_gen': '🎨', 'tts': '🔊', 'web_search': '🔍',
      'email': '📧', 'lark': '🐦', 'social': '📱',
      'video': '🎬', 'podcast': '🎙️', 'pro_domain': '🎓',
      'forbidden_word': '⚠️', 'cloud_sync': '☁️', 'tracking': '📡',
      'browser': '🌐', 'chart': '📊', 'doc_gen': '📄',
      'code_sandbox': '💻',
    };
    return icons[skillId] ?? '⚙️';
  }
}
