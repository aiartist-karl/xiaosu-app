// ============================================================================
// 小酥 AI 助手 - 图像生成技能
// ============================================================================
// 提供文生图、图生图、抠图等图像处理功能
// 支持多后端：橘子 AI API、本地 Stable Diffusion
// ============================================================================

import 'dart:async';
import 'dart:convert';

import '../../core/skill/skill.dart';

/// 图像生成技能
/// 提供 generate_image 和 edit_image 两个核心工具
class ImageGenSkill extends Skill {
  /// 技能配置
  final ImageGenConfig _config;

  /// 生成任务队列（防止并发过多）
  final List<String> _pendingTasks = [];

  /// 最大并发数
  static const int _maxConcurrency = 3;

  ImageGenSkill({ImageGenConfig? config})
      : _config = config ?? const ImageGenConfig();

  // ============================================================================
  // 技能元数据
  // ============================================================================

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'image_gen',
        name: '图像生成',
        description: '生成和编辑图片。支持文字生成图片（文生图）、'
            '图片编辑（图生图）、抠图等功能。'
            '可用于设计海报、生成插图、制作表情包等创意场景。',
        version: '1.0.0',
        author: '小酥',
        permissions: [
          SkillPermission.networkAccess,
          SkillPermission.fileRead,
          SkillPermission.fileWrite,
        ],
        loadStrategy: SkillLoadStrategy.lazy,
      );

  @override
  List<SkillTool> get tools => [
        _generateImageTool,
        _editImageTool,
      ];

  // ============================================================================
  // 工具定义
  // ============================================================================

  /// generate_image 工具
  /// 根据文字描述生成图片
  late final SkillTool _generateImageTool = SkillTool(
    name: 'generate_image',
    description: '根据文字描述生成图片。支持多种风格和尺寸。'
        '可以生成写实照片、插画、动漫风格、海报设计等各种类型的图片。',
    parameters: [
      ToolParameter(
        name: 'prompt',
        description: '图片描述/生成提示词，描述你想要的画面内容',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'negative_prompt',
        description: '负面提示词，描述不想出现的内容',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'style',
        description: '图片风格',
        type: ToolParameterType.stringType,
        enumValues: [
          'realistic',
          'anime',
          'illustration',
          'oil_painting',
          'watercolor',
          'pixel_art',
          '3d_render',
          'sketch',
        ],
        defaultValue: 'realistic',
      ),
      ToolParameter(
        name: 'size',
        description: '图片尺寸',
        type: ToolParameterType.stringType,
        enumValues: [
          '512x512',
          '768x768',
          '1024x1024',
          '1024x768',
          '768x1024',
          '1920x1080',
        ],
        defaultValue: '1024x1024',
      ),
      ToolParameter(
        name: 'count',
        description: '生成数量',
        type: ToolParameterType.intType,
        minValue: 1,
        maxValue: 4,
        defaultValue: 1,
      ),
      ToolParameter(
        name: 'backend',
        description: '生成后端',
        type: ToolParameterType.stringType,
        enumValues: ['orange_ai', 'stable_diffusion'],
        defaultValue: 'orange_ai',
      ),
      ToolParameter(
        name: 'guidance_scale',
        description: '引导系数（越高越贴近提示词）',
        type: ToolParameterType.doubleType,
        minValue: 1.0,
        maxValue: 20.0,
        defaultValue: 7.5,
      ),
      ToolParameter(
        name: 'steps',
        description: '采样步数（越高越精细但越慢）',
        type: ToolParameterType.intType,
        minValue: 10,
        maxValue: 100,
        defaultValue: 30,
      ),
    ],
    timeoutMs: 120000, // 图像生成可能较慢
    execute: _executeGenerateImage,
  );

  /// edit_image 工具
  /// 编辑/处理已有图片
  late final SkillTool _editImageTool = SkillTool(
    name: 'edit_image',
    description: '编辑或处理已有图片。支持图生图、风格转换、'
        '局部修改、抠图、放大等功能。',
    parameters: [
      ToolParameter(
        name: 'image_path',
        description: '输入图片路径或 URL',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'edit_mode',
        description: '编辑模式',
        type: ToolParameterType.stringType,
        enumValues: [
          'img2img',
          'inpaint',
          'outpaint',
          'style_transfer',
          'remove_background',
          'upscale',
          'text_edit',
        ],
        required: true,
      ),
      ToolParameter(
        name: 'prompt',
        description: '编辑提示词（描述想要的效果）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'strength',
        description: '编辑强度（0-1，越高变化越大）',
        type: ToolParameterType.doubleType,
        minValue: 0.0,
        maxValue: 1.0,
        defaultValue: 0.75,
      ),
      ToolParameter(
        name: 'mask_path',
        description: '蒙版图片路径（inpaint 模式使用）',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 180000,
    execute: _executeEditImage,
  );

  // ============================================================================
  // 生命周期
  // ============================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('图像生成技能初始化完成');
    context.logger.info('默认后端: ${_config.defaultBackend}');
  }

  @override
  Future<void> onDispose() async {
    _pendingTasks.clear();
  }

  // ============================================================================
  // 工具实现
  // ============================================================================

  /// 执行图片生成
  Future<ToolResult> _executeGenerateImage(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final prompt = args['prompt'] as String;
    final negativePrompt = args['negative_prompt'] as String?;
    final style = args['style'] as String? ?? 'realistic';
    final size = args['size'] as String? ?? '1024x1024';
    final count = args['count'] as int? ?? 1;
    final backend = args['backend'] as String? ?? _config.defaultBackend;
    final guidanceScale = (args['guidance_scale'] as num?)?.toDouble() ?? 7.5;
    final steps = args['steps'] as int? ?? 30;

    // 并发控制
    if (_pendingTasks.length >= _maxConcurrency) {
      return ToolResult.failure(
        error: '当前生成任务过多，请稍后再试',
        errorCode: 'RATE_LIMITED',
      );
    }

    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    _pendingTasks.add(taskId);

    try {
      context.logger.info(
        '生成图片: "$prompt" (风格: $style, 尺寸: $size, 数量: $count)',
      );

      // 报告进度
      context.onProgress?.call(0.1, '正在准备生成任务...');

      // 增强提示词（根据风格添加优化词）
      final enhancedPrompt = _enhancePrompt(prompt, style);

      // 根据后端选择生成方式
      final List<String> imageUrls;
      if (backend == 'orange_ai') {
        imageUrls = await _generateWithOrangeAI(
          prompt: enhancedPrompt,
          negativePrompt: negativePrompt,
          size: size,
          count: count,
          guidanceScale: guidanceScale,
          steps: steps,
          context: context,
        );
      } else {
        imageUrls = await _generateWithStableDiffusion(
          prompt: enhancedPrompt,
          negativePrompt: negativePrompt,
          size: size,
          count: count,
          guidanceScale: guidanceScale,
          steps: steps,
          context: context,
        );
      }

      context.onProgress?.call(1.0, '生成完成！');

      // 构建结果
      final resultBuffer = StringBuffer();
      resultBuffer.writeln('已生成 $count 张图片：');
      for (int i = 0; i < imageUrls.length; i++) {
        resultBuffer.writeln('${i + 1}. ${imageUrls[i]}');
      }

      final attachments = imageUrls
          .map((url) => ToolAttachment(
                type: AttachmentType.image,
                uri: url,
                description: prompt,
              ))
          .toList();

      return ToolResult.success(
        content: resultBuffer.toString().trim(),
        data: {
          'prompt': prompt,
          'style': style,
          'size': size,
          'count': imageUrls.length,
          'backend': backend,
          'image_urls': imageUrls,
        },
        attachments: attachments,
      );
    } catch (e) {
      context.logger.error('图片生成失败', e);
      return ToolResult.failure(
        error: '图片生成失败: $e',
        errorCode: 'GENERATION_FAILED',
      );
    } finally {
      _pendingTasks.remove(taskId);
    }
  }

  /// 执行图片编辑
  Future<ToolResult> _executeEditImage(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final imagePath = args['image_path'] as String;
    final editMode = args['edit_mode'] as String;
    final prompt = args['prompt'] as String?;
    final strength = (args['strength'] as num?)?.toDouble() ?? 0.75;
    final maskPath = args['mask_path'] as String?;

    context.logger.info('编辑图片: $imagePath (模式: $editMode)');

    try {
      context.onProgress?.call(0.1, '正在加载图片...');

      // 构建编辑请求
      final requestBody = <String, dynamic>{
        'image_path': imagePath,
        'edit_mode': editMode,
        'strength': strength,
        if (prompt != null) 'prompt': prompt,
        if (maskPath != null) 'mask_path': maskPath,
      };

      // 发送到后端处理
      final response = await context.http.post(
        '${_config.apiBaseUrl}/image/edit',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_config.apiKey}',
        },
        body: requestBody,
      );

      final responseData = jsonDecode(response) as Map<String, dynamic>;

      if (responseData['error'] != null) {
        return ToolResult.failure(
          error: '图片编辑失败: ${responseData['error']}',
          errorCode: 'EDIT_FAILED',
        );
      }

      final resultUrl = responseData['result_url'] as String? ?? '';
      context.onProgress?.call(1.0, '编辑完成！');

      return ToolResult.success(
        content: '图片编辑完成\n结果: $resultUrl',
        data: {
          'source': imagePath,
          'edit_mode': editMode,
          'result_url': resultUrl,
        },
        attachments: [
          ToolAttachment(
            type: AttachmentType.image,
            uri: resultUrl,
            description: '编辑后的图片',
          ),
        ],
      );
    } catch (e) {
      context.logger.error('图片编辑失败', e);
      return ToolResult.failure(
        error: '图片编辑失败: $e',
        errorCode: 'EDIT_ERROR',
      );
    }
  }

  // ============================================================================
  // 后端实现
  // ============================================================================

  /// 使用橘子 AI API 生成图片
  Future<List<String>> _generateWithOrangeAI({
    required String prompt,
    String? negativePrompt,
    required String size,
    required int count,
    required double guidanceScale,
    required int steps,
    required SkillContext context,
  }) async {
    context.onProgress?.call(0.3, '正在连接橘子 AI...');

    final response = await context.http.post(
      '${_config.apiBaseUrl}/image/generate',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config.apiKey}',
      },
      body: {
        'provider': 'orange_ai',
        'prompt': prompt,
        if (negativePrompt != null) 'negative_prompt': negativePrompt,
        'size': size,
        'count': count,
        'guidance_scale': guidanceScale,
        'steps': steps,
      },
    );

    context.onProgress?.call(0.7, '正在处理生成结果...');

    final responseData = jsonDecode(response) as Map<String, dynamic>;
    final images = responseData['images'] as List? ?? [];

    return images
        .map((img) => (img as Map<String, dynamic>)['url'] as String)
        .toList();
  }

  /// 使用 Stable Diffusion 生成图片
  Future<List<String>> _generateWithStableDiffusion({
    required String prompt,
    String? negativePrompt,
    required String size,
    required int count,
    required double guidanceScale,
    required int steps,
    required SkillContext context,
  }) async {
    context.onProgress?.call(0.3, '正在连接 SD 后端...');

    // TODO: 实现本地 SD 后端连接
    // 当前通过 API 代理调用
    final response = await context.http.post(
      '${_config.apiBaseUrl}/image/generate',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config.apiKey}',
      },
      body: {
        'provider': 'stable_diffusion',
        'prompt': prompt,
        if (negativePrompt != null) 'negative_prompt': negativePrompt,
        'size': size,
        'count': count,
        'guidance_scale': guidanceScale,
        'steps': steps,
        'model': _config.sdModel,
      },
    );

    context.onProgress?.call(0.7, '正在处理生成结果...');

    final responseData = jsonDecode(response) as Map<String, dynamic>;
    final images = responseData['images'] as List? ?? [];

    return images
        .map((img) => (img as Map<String, dynamic>)['url'] as String)
        .toList();
  }

  // ============================================================================
  // 辅助方法
  // ============================================================================

  /// 增强提示词
  /// 根据风格自动添加质量提升词
  String _enhancePrompt(String prompt, String style) {
    final styleEnhancements = <String, String>{
      'realistic': 'highly detailed, photorealistic, 8k, professional photography',
      'anime': 'anime style, vibrant colors, detailed illustration, manga art',
      'illustration': 'digital illustration, detailed, colorful, artistic',
      'oil_painting': 'oil painting style, textured, classical art, masterpiece',
      'watercolor': 'watercolor painting, soft colors, artistic, flowing',
      'pixel_art': 'pixel art style, retro, 16-bit, detailed pixel work',
      '3d_render': '3d render, octane render, volumetric lighting, detailed',
      'sketch': 'pencil sketch, detailed line art, hand drawn, artistic',
    };

    final enhancement = styleEnhancements[style] ?? '';
    return enhancement.isNotEmpty ? '$prompt, $enhancement' : prompt;
  }
}

// ============================================================================
// 配置
// ============================================================================

/// 图像生成技能配置
class ImageGenConfig {
  /// API 基础 URL
  final String apiBaseUrl;

  /// API 密钥
  final String apiKey;

  /// 默认后端
  final String defaultBackend;

  /// SD 模型名称
  final String sdModel;

  /// 最大并发数
  final int maxConcurrency;

  const ImageGenConfig({
    this.apiBaseUrl = 'https://api.xiaosu.ai/v1',
    this.apiKey = '',
    this.defaultBackend = 'orange_ai',
    this.sdModel = 'sd_xl_base_1.0',
    this.maxConcurrency = 3,
  });
}
