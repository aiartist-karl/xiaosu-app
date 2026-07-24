// ============================================================================
// 小酥 - 模型设置页面
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/llm/llm_router.dart';

/// 模型设置页面
class ModelSettingsScreen extends StatefulWidget {
  const ModelSettingsScreen({super.key});

  @override
  State<ModelSettingsScreen> createState() => _ModelSettingsScreenState();
}

class _ModelSettingsScreenState extends State<ModelSettingsScreen> {
  final LlmRouter _router = LlmRouter.instance;
  double _temperature = 0.7;
  int _maxTokens = 2048;

  @override
  Widget build(BuildContext context) {
    final models = _router.availableModels;

    return Scaffold(
      appBar: AppBar(title: const Text('模型设置'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 模型选择
          Text('选择模型', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...models.map((m) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.smart_toy, size: 20),
              ),
              title: Text(m.name),
              subtitle: Text('上下文窗口: ${m.contextWindow}'),
              trailing: Radio<String>(
                value: m.id,
                groupValue: 'deepseek-v4-flash',
                onChanged: (v) {
                  _router.setDefaultModel(v!);
                  setState(() {});
                },
              ),
            ),
          )),

          const SizedBox(height: 24),
          // 温度调节
          Text('温度 (Temperature)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Slider(
            value: _temperature,
            min: 0, max: 2, divisions: 20,
            label: _temperature.toStringAsFixed(1),
            onChanged: (v) => setState(() => _temperature = v),
          ),
          Text('较低=确定性高，较高=创造性强',
              style: Theme.of(context).textTheme.bodySmall),

          const SizedBox(height: 24),
          // 最大Token
          Text('最大Token数', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Slider(
            value: _maxTokens.toDouble(),
            min: 256, max: 8192, divisions: 16,
            label: '$_maxTokens',
            onChanged: (v) => setState(() => _maxTokens = v.toInt()),
          ),

          const SizedBox(height: 32),
          // 添加自定义模型
          OutlinedButton.icon(
            onPressed: () {
              // TODO: 添加自定义模型API
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请在代码中配置自定义模型')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('添加自定义模型'),
          ),
        ],
      ),
    );
  }
}
