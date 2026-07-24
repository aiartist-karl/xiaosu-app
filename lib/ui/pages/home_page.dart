// ============================================================================
// 小酥 (XiaoSu) - 首页（对话列表）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 首页 —— 显示所有对话列表
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('小酥'),
        actions: [
          IconButton(
            icon: const Icon(Icons.build),
            onPressed: () => context.go('/skills'),
            tooltip: '技能管理',
          ),
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: () => context.go('/tasks'),
            tooltip: '任务管理',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
            tooltip: '设置',
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '开始新对话',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '点击右下角按钮创建对话',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 创建新对话并跳转
        },
        tooltip: '新建对话',
        child: const Icon(Icons.add),
      ),
    );
  }
}
