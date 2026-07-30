// ============================================================================
// 小酥 v2 - Bot 编辑器
// Phase 2: 对接 Coze Studio Bot API，保留原有 UI 设计风格
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/models/bot_model.dart';
import '../../core/bot/bot_manager.dart';
import '../theme/app_colors.dart';

/// Bot 编辑器
class BotEditorScreen extends StatefulWidget {
  /// 编辑模式下传入 botId
  final String? botId;
  /// 可选的预加载 Bot 数据
  final BotModel? preloadBot;

  const BotEditorScreen({
    super.key,
    this.botId,
    this.preloadBot,
  });

  @override
  State<BotEditorScreen> createState() => _BotEditorScreenState();
}

class _BotEditorScreenState extends State<BotEditorScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _promptController = TextEditingController();
  final _onboardingController = TextEditingController();
  int _selectedAvatarIndex = 0;
  final Set<String> _selectedSkills = {};
  final Set<String> _selectedPlugins = {};

  bool _isLoading = false;
  bool _isSaving = false;

  final BotManager _botManager = BotManager.instance;

  /// 预设头像列表
  static const List<Map<String, String>> _presetAvatars = [
    {'emoji': '🤖', 'label': '机器人'},
    {'emoji': '📝', 'label': '写作'},
    {'emoji': '🎨', 'label': '绘画'},
    {'emoji': '💻', 'label': '代码'},
    {'emoji': '🌍', 'label': '翻译'},
    {'emoji': '📊', 'label': '数据'},
    {'emoji': '🎯', 'label': '目标'},
    {'emoji': '💡', 'label': '创意'},
    {'emoji': '🔬', 'label': '科研'},
    {'emoji': '📚', 'label': '学习'},
    {'emoji': '🎵', 'label': '音乐'},
    {'emoji': '🏋', 'label': '健身'},
  ];

  /// 可用技能列表
  static const List<Map<String, dynamic>> _availableSkills = [
    {'id': 'search', 'name': '联网搜索', 'desc': '搜索互联网获取实时信息', 'icon': 'travel_explore'},
    {'id': 'draw', 'name': 'AI 绘图', 'desc': '根据文字描述生成图片', 'icon': 'brush'},
    {'id': 'code', 'name': '代码执行', 'desc': '运行 Python/JS 代码', 'icon': 'code'},
    {'id': 'file', 'name': '文件处理', 'desc': '读取、解析和生成文件', 'icon': 'description'},
    {'id': 'math', 'name': '数学计算', 'desc': '高级数学运算与公式推导', 'icon': 'calculate'},
    {'id': 'image', 'name': '图片理解', 'desc': '识别和分析图片内容', 'icon': 'image'},
    {'id': 'tts', 'name': '语音合成', 'desc': '将文字转换为语音', 'icon': 'volume_up'},
    {'id': 'ocr', 'name': 'OCR 识别', 'desc': '从图片中提取文字', 'icon': 'document_scanner'},
  ];

  /// 可用插件列表
  static const List<Map<String, dynamic>> _availablePlugins = [
    {'id': 'weather', 'name': '天气查询', 'desc': '查询实时天气与预报', 'icon': 'cloud'},
    {'id': 'calendar', 'name': '日历管理', 'desc': '管理日程与提醒', 'icon': 'calendar_today'},
    {'id': 'email', 'name': '邮件助手', 'desc': '收发邮件自动化', 'icon': 'email'},
    {'id': 'database', 'name': '数据库', 'desc': '连接与查询数据库', 'icon': 'storage'},
    {'id': 'api', 'name': '自定义 API', 'desc': '接入第三方 API 服务', 'icon': 'api'},
    {'id': 'git', 'name': 'Git 集成', 'desc': '代码仓库管理', 'icon': 'terminal'},
  ];

  static const Map<String, IconData> _iconMap = {
    'travel_explore': Icons.travel_explore,
    'brush': Icons.brush,
    'code': Icons.code,
    'description': Icons.description,
    'calculate': Icons.calculate,
    'image': Icons.image,
    'volume_up': Icons.volume_up,
    'document_scanner': Icons.document_scanner,
    'cloud': Icons.cloud,
    'calendar_today': Icons.calendar_today,
    'email': Icons.email,
    'storage': Icons.storage,
    'api': Icons.api,
    'terminal': Icons.terminal,
  };

  bool get _isEditMode => widget.botId != null;
  int get _promptLength => _promptController.text.length;
  static const int _maxPromptLength = 5000;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadBotData();
    }
    _promptController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  /// 加载 Bot 数据（编辑模式）
  Future<void> _loadBotData() async {
    setState(() => _isLoading = true);

    BotModel? bot = widget.preloadBot;

    // 如果没有预加载数据，从 BotManager 获取
    if (bot == null && widget.botId != null) {
      bot = _botManager.getCachedBot(widget.botId!);
      if (bot == null) {
        bot = await _botManager.getBotDetail(widget.botId!);
      }
    }

    if (bot != null && mounted) {
      _nameController.text = bot.name;
      _descController.text = bot.description;
      if (bot.prompt != null) {
        _promptController.text = bot.prompt!;
      }
      if (bot.onboardingPrompt != null) {
        _onboardingController.text = bot.onboardingPrompt!;
      }
      // 恢复插件选择
      _selectedPlugins.addAll(bot.pluginIds);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _promptController.dispose();
    _onboardingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background(isDark),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: Column(
        children: [
          _buildTopBar(isDark),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildAvatarSection(isDark),
                  const SizedBox(height: 24),
                  _buildNameInput(isDark),
                  const SizedBox(height: 16),
                  _buildDescInput(isDark),
                  const SizedBox(height: 24),
                  _buildPromptEditor(isDark),
                  const SizedBox(height: 24),
                  _buildOnboardingInput(isDark),
                  const SizedBox(height: 24),
                  _buildSkillsSection(isDark),
                  const SizedBox(height: 24),
                  _buildPluginsSection(isDark),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _buildBottomBar(isDark),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.close, size: 22, color: AppColors.textPrimary(isDark)),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Text(
              _isEditMode ? '编辑 Bot' : '创建 Bot',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            if (_isEditMode) ...[
              const Spacer(),
              IconButton(
                icon: Icon(Icons.publish_outlined, size: 22, color: AppColors.primary(isDark)),
                onPressed: () => _publishBot(isDark),
                tooltip: '发布',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择头像',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary(isDark).withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _presetAvatars[_selectedAvatarIndex]['emoji']!,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider(isDark), width: 0.5),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _presetAvatars.length,
              itemBuilder: (context, index) {
                final selected = _selectedAvatarIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAvatarIndex = index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary(isDark).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primary(isDark) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _presetAvatars[index]['emoji']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInput(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bot 名称',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider(isDark), width: 0.5),
            ),
            child: TextField(
              controller: _nameController,
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary(isDark)),
              decoration: InputDecoration(
                hintText: '给你的 Bot 起个名字',
                hintStyle: TextStyle(fontSize: 15, color: AppColors.textHint(isDark)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescInput(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bot 描述',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider(isDark), width: 0.5),
            ),
            child: TextField(
              controller: _descController,
              maxLines: 2,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary(isDark)),
              decoration: InputDecoration(
                hintText: '简要描述 Bot 的功能和特点',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.textHint(isDark)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptEditor(bool isDark) {
    final isOverLimit = _promptLength > _maxPromptLength;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '系统提示词',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const Spacer(),
              Text(
                '$_promptLength / $_maxPromptLength',
                style: TextStyle(
                  fontSize: 12,
                  color: isOverLimit ? AppColors.error(isDark) : AppColors.textHint(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '定义 Bot 的角色、行为和能力边界',
            style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOverLimit ? AppColors.error(isDark) : AppColors.divider(isDark),
                width: 0.5,
              ),
            ),
            child: TextField(
              controller: _promptController,
              maxLines: 10,
              minLines: 6,
              maxLength: null,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary(isDark),
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: '你是一个专业的写作助手，擅长...\n\n请描述 Bot 的角色定位、核心能力、输出格式要求等。',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.textHint(isDark),
                  height: 1.6,
                ),
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingInput(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '开场白',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '用户进入对话时 Bot 的第一句话',
            style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider(isDark), width: 0.5),
            ),
            child: TextField(
              controller: _onboardingController,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary(isDark)),
              decoration: InputDecoration(
                hintText: '你好！我是你的 AI 助手，有什么可以帮你的吗？',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.textHint(isDark)),
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '技能配置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const Spacer(),
              Text(
                '已选 ${_selectedSkills.length} 项',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '为 Bot 添加可用的技能能力',
            style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark)),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider(isDark), width: 0.5),
            ),
            child: Column(
              children: _availableSkills.map((skill) {
                final selected = _selectedSkills.contains(skill['id']);
                return _buildCheckboxItem(
                  isDark: isDark,
                  icon: _iconMap[skill['icon']] ?? Icons.star,
                  name: skill['name'] as String,
                  desc: skill['desc'] as String,
                  isSelected: selected,
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedSkills.remove(skill['id']);
                      } else {
                        _selectedSkills.add(skill['id'] as String);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginsSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '插件配置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const Spacer(),
              Text(
                '已选 ${_selectedPlugins.length} 项',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '为 Bot 接入外部插件服务',
            style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark)),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider(isDark), width: 0.5),
            ),
            child: Column(
              children: _availablePlugins.map((plugin) {
                final selected = _selectedPlugins.contains(plugin['id']);
                return _buildCheckboxItem(
                  isDark: isDark,
                  icon: _iconMap[plugin['icon']] ?? Icons.extension,
                  name: plugin['name'] as String,
                  desc: plugin['desc'] as String,
                  isSelected: selected,
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedPlugins.remove(plugin['id']);
                      } else {
                        _selectedPlugins.add(plugin['id'] as String);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxItem({
    required bool isDark,
    required IconData icon,
    required String name,
    required String desc,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary(isDark).withOpacity(0.12)
                    : AppColors.surfaceVariant(isDark: isDark),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AppColors.primary(isDark)
                    : AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 11, color: AppColors.textHint(isDark)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary(isDark) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? AppColors.primary(isDark) : AppColors.textHint(isDark),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(
          top: BorderSide(color: AppColors.divider(isDark), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _saveDraft(isDark),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(isDark: isDark),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.divider(isDark), width: 0.5),
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            '保存草稿',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => _saveAndPublish(isDark),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary(isDark).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isEditMode ? '更新并发布' : '发布 Bot',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 业务逻辑
  // ==========================================================================

  /// 构建 BotModel
  BotModel _buildBotFromForm() {
    return BotModel(
      id: widget.botId ?? '',
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      prompt: _promptController.text.trim().isNotEmpty ? _promptController.text.trim() : null,
      onboardingPrompt: _onboardingController.text.trim().isNotEmpty
          ? _onboardingController.text.trim()
          : null,
      pluginIds: _selectedPlugins.toList(),
      isOwned: true,
    );
  }

  /// 表单校验
  bool _validateForm() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 Bot 名称')),
      );
      return false;
    }
    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入系统提示词')),
      );
      return false;
    }
    if (_promptLength > _maxPromptLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提示词超过最大长度')),
      );
      return false;
    }
    return true;
  }

  /// 保存草稿（不发布）
  Future<void> _saveDraft(bool isDark) async {
    if (!_validateForm()) return;

    setState(() => _isSaving = true);

    final bot = _buildBotFromForm();
    BotModel? result;

    if (_isEditMode && widget.botId != null) {
      result = await _botManager.updateBot(widget.botId!, bot);
    } else {
      result = await _botManager.createBot(bot);
    }

    setState(() => _isSaving = false);

    if (mounted) {
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已保存为草稿'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_botManager.lastError ?? '保存失败'),
            backgroundColor: AppColors.error(isDark),
          ),
        );
      }
    }
  }

  /// 保存并发布
  Future<void> _saveAndPublish(bool isDark) async {
    if (!_validateForm()) return;

    setState(() => _isSaving = true);

    final bot = _buildBotFromForm();
    BotModel? result;

    if (_isEditMode && widget.botId != null) {
      // 先更新
      result = await _botManager.updateBot(widget.botId!, bot);
      if (result != null) {
        // 再发布
        final published = await _botManager.publishBot(widget.botId!);
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(published ? '已更新并发布' : '更新成功，但发布失败'),
              duration: const Duration(seconds: 1),
            ),
          );
          if (published) Navigator.pop(context, result);
        }
      } else {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_botManager.lastError ?? '保存失败'),
              backgroundColor: AppColors.error(isDark),
            ),
          );
        }
      }
    } else {
      // 新建并创建
      result = await _botManager.createBot(bot);
      if (result != null) {
        // 创建成功后发布
        final published = await _botManager.publishBot(result.id);
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(published ? 'Bot 已创建并发布' : 'Bot 已创建，发布失败'),
              duration: const Duration(seconds: 1),
            ),
          );
          Navigator.pop(context, result);
        }
      } else {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_botManager.lastError ?? '创建失败'),
              backgroundColor: AppColors.error(isDark),
            ),
          );
        }
      }
    }
  }

  /// 直接发布（编辑模式下的顶部栏按钮）
  Future<void> _publishBot(bool isDark) async {
    if (widget.botId == null) return;

    final success = await _botManager.publishBot(widget.botId!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '发布成功' : '发布失败'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}
