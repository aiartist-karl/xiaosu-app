// ============================================================================
// 小酥 (XiaoSu) - 技能管理页
// ============================================================================

import 'package:flutter/material.dart';

/// 技能页 —— 查看和管理已注册技能
class SkillsPage extends StatelessWidget {
  const SkillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('技能管理'),
      ),
      body: const Center(
        child: Text('TODO: 展示所有已注册技能列表\n支持启用/禁用、查看描述'),
      ),
    );
  }
}
