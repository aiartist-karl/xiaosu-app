// ============================================================================
// 小酥 - 工具集界面（日历、邮件、文件管理、记忆）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 工具集主页面
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工具集'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildToolCard(
            context,
            icon: Icons.calendar_today,
            color: Colors.orange,
            title: '日历管理',
            subtitle: '查看和创建日历事件',
            onTap: () => _showCalendarTools(context),
          ),
          const SizedBox(height: 12),
          _buildToolCard(
            context,
            icon: Icons.email,
            color: Colors.blue,
            title: '邮件助手',
            subtitle: '撰写和发送邮件',
            onTap: () => _showEmailTools(context),
          ),
          const SizedBox(height: 12),
          _buildToolCard(
            context,
            icon: Icons.folder,
            color: Colors.green,
            title: '文件管理',
            subtitle: '浏览后端工作目录文件',
            onTap: () => _showFileTools(context),
          ),
          const SizedBox(height: 12),
          _buildToolCard(
            context,
            icon: Icons.memory,
            color: Colors.purple,
            title: '记忆管理',
            subtitle: '查看、搜索和管理AI记忆',
            onTap: () => _showMemoryTools(context),
          ),
          const SizedBox(height: 12),
          _buildToolCard(
            context,
            icon: Icons.search,
            color: Colors.teal,
            title: '网页搜索',
            subtitle: '搜索互联网获取信息',
            onTap: () {
              Navigator.pop(context);
              _goNewChat();
            },
          ),
          const SizedBox(height: 12),
          _buildToolCard(
            context,
            icon: Icons.image,
            color: Colors.pink,
            title: '图片生成',
            subtitle: '使用AI生成图片',
            onTap: () {
              Navigator.pop(context);
              _goNewChat();
            },
          ),
          const SizedBox(height: 12),
          _buildToolCard(
            context,
            icon: Icons.code,
            color: Colors.brown,
            title: '代码执行',
            subtitle: '在沙箱中执行代码',
            onTap: () {
              Navigator.pop(context);
              _goNewChat();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    );
  }

  void _showCalendarTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('日历管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.event, color: Colors.orange),
                title: const Text('创建日程'),
                subtitle: const Text('通过AI助手创建日历事件'),
                onTap: () {
                  Navigator.pop(context);
                  _goNewChat();
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.orange),
                title: const Text('查看今日日程'),
                subtitle: const Text('查看今天的日历安排'),
                onTap: () {
                  Navigator.pop(context);
                  _goNewChat();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('邮件助手', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.blue),
                title: const Text('撰写邮件'),
                subtitle: const Text('通过AI助手撰写并发送邮件'),
                onTap: () {
                  Navigator.pop(context);
                  _goNewChat();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileTools(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('文件管理'),
        content: const Text('通过对话让小酥帮你管理文件：\n\n• 查看工作目录文件列表\n• 读取指定文件内容\n• 创建/写入新文件\n• 整理文件结构'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goNewChat();
            },
            child: const Text('查看文件'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showMemoryTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('记忆管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.search, color: Colors.purple),
                title: const Text('搜索记忆'),
                subtitle: const Text('搜索AI已记住的信息'),
                onTap: () {
                  Navigator.pop(context);
                  _goNewChat();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.purple),
                title: const Text('添加记忆'),
                subtitle: const Text('告诉AI需要记住的信息'),
                onTap: () {
                  Navigator.pop(context);
                  _goNewChat();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goNewChat() {
    final id = 'conv_${DateTime.now().millisecondsSinceEpoch}';
    context.push('/chat/$id');
  }
}
