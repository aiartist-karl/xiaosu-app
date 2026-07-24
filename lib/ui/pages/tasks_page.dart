// ============================================================================
// 小酥 (XiaoSu) - 任务管理页
// ============================================================================

import 'package:flutter/material.dart';

/// 任务页 —— 查看和管理定时任务 / 话题追踪
class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务管理'),
      ),
      body: const Center(
        child: Text('TODO: 展示所有定时任务列表\n支持暂停/恢复/删除/立即执行'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 创建新任务
        },
        tooltip: '新建任务',
        child: const Icon(Icons.add),
      ),
    );
  }
}
