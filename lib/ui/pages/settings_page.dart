// ============================================================================
// 小酥 (XiaoSu) - 设置页
// ============================================================================

import 'package:flutter/material.dart';

/// 设置页 —— 用户偏好、API Key 配置等
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: const [
          // TODO: 实现设置项
          // - API Key 配置
          // - 模型选择
          // - 主题切换（亮色/暗色）
          // - 通知权限
          // - 数据管理（备份/恢复/清除）
          // - 关于
          ListTile(
            title: Text('设置页 - 待实现'),
            subtitle: Text('API Key、模型选择、主题、通知等'),
          ),
        ],
      ),
    );
  }
}
