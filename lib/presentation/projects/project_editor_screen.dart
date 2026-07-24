// ============================================================================
// 小酥 - 项目编辑器
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// 项目编辑器 - 简易代码编辑器
class ProjectEditorScreen extends StatefulWidget {
  final String projectId;
  const ProjectEditorScreen({super.key, required this.projectId});

  @override
  State<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  final ApiGateway _api = ApiGateway.instance;
  final TextEditingController _codeCtrl = TextEditingController();
  String _currentFile = '';
  bool _hasChanges = false;
  bool _isSaving = false;

  // 模拟文件列表
  final List<Map<String, String>> _files = [
    {'name': 'main.js', 'path': 'src/main.js'},
    {'name': 'app.css', 'path': 'src/app.css'},
    {'name': 'index.html', 'path': 'src/index.html'},
    {'name': 'package.json', 'path': 'package.json'},
  ];

  // 模拟文件内容
  final Map<String, String> _fileContents = {
    'src/main.js': '''import { createApp } from './app.js';
import { initRouter } from './router.js';

// 应用入口
const app = createApp({
  data() {
    return {
      title: '小酥工程项目',
      version: '1.0.0'
    };
  }
});

// 初始化路由
initRouter(app);

// 启动应用
app.mount('#app');
console.log('应用已启动');
''',
    'src/app.css': '''/* 全局样式 */
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: #f5f5f5;
  color: #333;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}
''',
    'src/index.html': '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>小酥工程项目</title>
  <link rel="stylesheet" href="app.css">
</head>
<body>
  <div id="app">
    <h1>欢迎使用小酥工程项目</h1>
  </div>
  <script type="module" src="main.js"></script>
</body>
</html>
''',
    'package.json': '''{
  "name": "xiaosu-project",
  "version": "1.0.0",
  "description": "小酥工程项目",
  "main": "src/main.js",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {},
  "devDependencies": {}
}
''',
  };

  @override
  void initState() {
    super.initState();
    if (_files.isNotEmpty) {
      _loadFile(_files.first['path']!);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _loadFile(String path) {
    setState(() {
      _currentFile = path;
      _codeCtrl.text = _fileContents[path] ?? '// 空文件';
      _hasChanges = false;
    });
  }

  Future<void> _saveFile() async {
    if (!_hasChanges) return;

    setState(() => _isSaving = true);

    try {
      await _api.post(
        '/api/projects/${widget.projectId}/file',
        body: {
          'path': _currentFile,
          'content': _codeCtrl.text,
        },
        headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
      );

      // 更新本地缓存
      _fileContents[_currentFile] = _codeCtrl.text;

      setState(() => _hasChanges = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已保存: $_currentFile'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('项目编辑器'),
        centerTitle: true,
        actions: [
          if (_hasChanges)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveFile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(_isSaving ? '保存中...' : '保存'),
            ),
        ],
      ),
      body: Row(
        children: [
          // 左侧文件树
          Container(
            width: 180,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '文件',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final isSelected = _currentFile == file['path'];
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: Colors.blue.withOpacity(0.1),
                        leading: Icon(
                          _fileIcon(file['name']!),
                          size: 16,
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                        title: Text(
                          file['name']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        onTap: () => _loadFile(file['path']!),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 右侧编辑区
          Expanded(
            child: Column(
              children: [
                // 文件路径栏
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        _currentFile,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      if (_hasChanges)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
                // 代码编辑区
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                      filled: true,
                      fillColor: Color(0xFF1E1E1E),
                    ),
                    onChanged: (_) {
                      if (!_hasChanges) {
                        setState(() => _hasChanges = true);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(String name) {
    if (name.endsWith('.js') || name.endsWith('.ts')) return Icons.javascript;
    if (name.endsWith('.css')) return Icons.style;
    if (name.endsWith('.html')) return Icons.html;
    if (name.endsWith('.json')) return Icons.data_object;
    if (name.endsWith('.dart')) return Icons.code;
    if (name.endsWith('.py')) return Icons.code;
    return Icons.insert_drive_file;
  }
}
