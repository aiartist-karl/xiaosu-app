// ============================================================================
// 小酥 - 聊天输入组件（真实文件选择 + 后端上传）
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/agent_api_service.dart';

/// 附件信息
class AttachmentInfo {
  final String name;
  final String path;
  final int size;
  final String type;
  String? serverPath;
  bool uploading;
  bool uploaded;

  AttachmentInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.type,
    this.serverPath,
    this.uploading = false,
    this.uploaded = false,
  });
}

/// 聊天输入组件
class ChatInput extends StatefulWidget {
  final void Function(String text, {List<String>? filePaths}) onSend;
  final bool isLoading;
  final VoidCallback? onStop;

  const ChatInput({
    super.key,
    required this.onSend,
    this.isLoading = false,
    this.onStop,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<AttachmentInfo> _attachments = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 选择图片
  Future<void> _pickImage() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      for (final xfile in images) {
        final file = File(xfile.path);
        final size = await file.length();
        setState(() {
          _attachments.add(AttachmentInfo(
            name: xfile.name,
            path: xfile.path,
            size: size,
            type: 'image',
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: ${e.toString()}')),
        );
      }
    }
  }

  /// 拍摄照片
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (photo != null) {
        final file = File(photo.path);
        final size = await file.length();
        setState(() {
          _attachments.add(AttachmentInfo(
            name: photo.name,
            path: photo.path,
            size: size,
            type: 'image',
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: ${e.toString()}')),
        );
      }
    }
  }

  /// 选择文件
  Future<void> _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      
      if (result != null) {
        for (final platformFile in result.files) {
          if (platformFile.path != null) {
            setState(() {
              _attachments.add(AttachmentInfo(
                name: platformFile.name,
                path: platformFile.path!,
                size: platformFile.size,
                type: 'file',
              ));
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: ${e.toString()}')),
        );
      }
    }
  }

  /// 显示附件来源选项
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('从相册选择'),
              onTap: () { Navigator.pop(ctx); _pickImage(); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('拍照'),
              onTap: () { Navigator.pop(ctx); _takePhoto(); },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.orange),
              title: const Text('选择文件'),
              onTap: () { Navigator.pop(ctx); _pickFile(); },
            ),
          ],
        ),
      ),
    );
  }

  /// 移除附件
  void _removeAttachment(int index) {
    setState(() { _attachments.removeAt(index); });
  }

  /// 上传所有附件到后端
  Future<List<String>> _uploadAttachments() async {
    final List<String> serverPaths = [];
    setState(() { _isUploading = true; });

    try {
      for (int i = 0; i < _attachments.length; i++) {
        if (_attachments[i].uploaded && _attachments[i].serverPath != null) {
          serverPaths.add(_attachments[i].serverPath!);
          continue;
        }

        setState(() { _attachments[i].uploading = true; });

        try {
          final result = await AgentApiService.instance.uploadFile(
            _attachments[i].path,
            fileName: _attachments[i].name,
          );

          if (result['success'] == true) {
            setState(() {
              _attachments[i].serverPath = result['file_path'] as String;
              _attachments[i].uploaded = true;
              _attachments[i].uploading = false;
            });
            serverPaths.add(result['file_path'] as String);
          } else {
            throw Exception('上传失败');
          }
        } catch (e) {
          setState(() { _attachments[i].uploading = false; });
          throw Exception('上传 ${_attachments[i].name} 失败: ${e.toString()}');
        }
      }
    } finally {
      setState(() { _isUploading = false; });
    }

    return serverPaths;
  }

  /// 发送消息
  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    if (widget.isLoading) return;

    List<String>? filePaths;
    if (_attachments.isNotEmpty) {
      try {
        filePaths = await _uploadAttachments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('附件上传失败: ${e.toString()}')),
          );
        }
        return;
      }
    }

    widget.onSend(text, filePaths: filePaths);
    _controller.clear();
    setState(() { _attachments.clear(); });
    _focusNode.requestFocus();
  }

  /// 格式化文件大小
  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 附件预览区
          if (_attachments.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _attachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, index) {
                  final att = _attachments[index];
                  return Stack(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                        ),
                        child: att.type == 'image'
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(att.path), fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.insert_drive_file, size: 28, color: Colors.blue[400]),
                                  const SizedBox(height: 2),
                                  Text(_formatSize(att.size), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                ],
                              ),
                      ),
                      if (att.uploading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.black45,
                            ),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          ),
                        ),
                      if (att.uploaded)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.check, size: 12, color: Colors.white),
                          ),
                        ),
                      Positioned(
                        top: -4,
                        left: -4,
                        child: GestureDetector(
                          onTap: () => _removeAttachment(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (_attachments.isNotEmpty) const SizedBox(height: 8),

          // 输入行
          Row(
            children: [
              GestureDetector(
                onTap: _showAttachmentOptions,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.add, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 22),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.isLoading ? widget.onStop : _handleSend,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isLoading ? Colors.red : Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    widget.isLoading ? Icons.stop : Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('正在上传附件...', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
        ],
      ),
    );
  }
}
