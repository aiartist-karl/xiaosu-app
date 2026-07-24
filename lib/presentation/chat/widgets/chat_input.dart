// ============================================================================
// 小酥 - 聊天输入框（支持附件）
// ============================================================================

import 'package:flutter/material.dart';

/// 聊天输入框组件
class ChatInput extends StatefulWidget {
  final void Function(String text, {List<String>? filePaths}) onSend;
  final bool isLoading;

  const ChatInput({
    super.key,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final List<_AttachmentItem> _attachments = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    final hasAttachments = _attachments.isNotEmpty;
    if (text.isEmpty && !hasAttachments) return;
    if (widget.isLoading) return;

    final filePaths = _attachments.map((a) => a.path).toList();
    widget.onSend(text, filePaths: filePaths.isNotEmpty ? filePaths : null);
    _controller.clear();
    _attachments.clear();
    _focusNode.requestFocus();
    // Force rebuild to clear attachment previews
    if (mounted) setState(() {});
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('从相册选择'),
              subtitle: const Text('选择图片或视频'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('拍照'),
              subtitle: const Text('拍摄照片'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.orange),
              title: const Text('选择文件'),
              subtitle: const Text('选择文档或其他文件'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    // 模拟图片选择 - 实际使用 image_picker
    // 在真实环境中: final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    _addMockAttachment('image', '照片_${DateTime.now().millisecondsSinceEpoch % 10000}.jpg');
  }

  Future<void> _takePhoto() async {
    // 模拟拍照
    _addMockAttachment('image', '拍照_${DateTime.now().millisecondsSinceEpoch % 10000}.jpg');
  }

  Future<void> _pickFile() async {
    // 模拟文件选择
    _addMockAttachment('file', '文档_${DateTime.now().millisecondsSinceEpoch % 10000}.pdf');
  }

  void _addMockAttachment(String type, String name) {
    setState(() {
      _attachments.add(_AttachmentItem(
        path: '/uploads/$name',
        name: name,
        type: type,
      ));
    });
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  IconData _getAttachmentIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'file':
        return Icons.insert_drive_file;
      default:
        return Icons.attach_file;
    }
  }

  Color _getAttachmentColor(String type) {
    switch (type) {
      case 'image':
        return Colors.blue;
      case 'video':
        return Colors.purple;
      case 'file':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: _attachments.isNotEmpty ? 8 : 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 附件预览区域
          if (_attachments.isNotEmpty)
            Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _attachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final att = _attachments[index];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _getAttachmentColor(att.type).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getAttachmentColor(att.type).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getAttachmentIcon(att.type),
                              color: _getAttachmentColor(att.type),
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              att.name.length > 8 ? '${att.name.substring(0, 8)}...' : att.name,
                              style: TextStyle(
                                fontSize: 9,
                                color: _getAttachmentColor(att.type),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => _removeAttachment(index),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          // 输入行
          Row(
            children: [
              // 附件按钮
              IconButton(
                icon: const Icon(Icons.attach_file, size: 22),
                onPressed: _showAttachmentMenu,
                tooltip: '添加附件',
                color: Colors.grey.shade600,
              ),
              // 输入框
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: _attachments.isNotEmpty ? '输入消息或发送附件...' : '给小酥发消息...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: 4),
              // 发送按钮
              Container(
                decoration: BoxDecoration(
                  color: widget.isLoading
                      ? Colors.grey.shade300
                      : Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: widget.isLoading ? null : _handleSend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 附件项数据模型
class _AttachmentItem {
  final String path;
  final String name;
  final String type;

  const _AttachmentItem({
    required this.path,
    required this.name,
    required this.type,
  });
}
