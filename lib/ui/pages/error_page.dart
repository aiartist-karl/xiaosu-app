// ============================================================================
// 小酥 (XiaoSu) - 全局错误页
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 全局错误页 —— 当路由匹配失败时显示
class ErrorPage extends StatelessWidget {
  final Exception? error;
  final String path;

  const ErrorPage({
    super.key,
    this.error,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('页面未找到'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                '哎呀，找不到这个页面',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '路径: $path',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              if (error != null) ...[
                const SizedBox(height: 4),
                Text(
                  '错误: ${error.toString()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
