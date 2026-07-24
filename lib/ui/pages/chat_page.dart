// ============================================================================
// 小酥 (XiaoSu) - 对话页
// ============================================================================

import 'package:flutter/material.dart';

/// 对话页 —— 与 AI 进行实时对话
class ChatPage extends StatelessWidget {
  final String conversationId;

  const ChatPage({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('对话'),
      ),
      body: Center(
        child: Text('对话页 - 会话: $conversationId\n\nTODO: 实现流式对话 UI'),
      ),
      // TODO: 实现完整的聊天 UI
      // - 消息列表（ListView）
      // - 消息输入框
      // - 流式文本渲染
      // - Markdown 渲染
      // - 代码高亮
      // - 技能调用进度指示器
    );
  }
}
