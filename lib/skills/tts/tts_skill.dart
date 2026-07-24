// ============================================================================
// 小酥 AI 助手 - TTS 语音合成技能
// ============================================================================
// 提供文本转语音功能，支持多种音色
// 集成火山引擎 TTS SDK
// ============================================================================

import 'dart:async';
import 'dart:convert';

import '../../core/skill/skill.dart';

/// TTS 语音合成技能
/// 提供 text_to_speech 工具
class TTSSkill extends Skill {
  /// 技能配置
  final TTSConfig _config;

  /// 可用的音色列表（初始化时从配置加载）
  late final List<VoiceInfo> _availableVoices;

  /// 合成任务队列
  final List<String> _activeTasks = [];

  /// 最大并发合成数
  static const int _maxConcurrency = 5;

  TTSSkill({TTSConfig? config}) : _config = config ?? const TTSConfig();

  // ============================================================================
  // 技能元数据
  // ============================================================================

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'tts',
        name: '语音合成',
        description: '将文本转换为语音音频。支持多种音色选择，'
            '可用于朗读文章、生成播客、语音回复等场景。',
        version: '1.0.0',
        author: '小酥',
        permissions: [
          SkillPermission.networkAccess,
          SkillPermission.mediaAccess,
        ],
        loadStrategy: SkillLoadStrategy.lazy,
      );

  @override
  List<SkillTool> get tools => [
        _textToSpeechTool,
      ];

  // ============================================================================
  // 工具定义
  // ============================================================================

  /// text_to_speech 工具
  late final SkillTool _textToSpeechTool = SkillTool(
    name: 'text_to_speech',
    description: '将文本转换为语音音频文件。支持多种音色选择，'
        '可以调整语速、音调等参数。适用于朗读文本、生成语音消息等。',
    parameters: [
      ToolParameter(
        name: 'text',
        description: '要转换的文本内容',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'voice',
        description: '音色标识符',
        type: ToolParameterType.stringType,
        enumValues: [
          'xiaoyan',     // 小燕（女声，温柔）
          'xiaoming',    // 小明（男声，阳光）
          'xiaoxue',     // 小雪（女声，甜美）
          'xiaogang',    // 小刚（男声，沉稳）
          'xiaoli',      // 小丽（女声，知性）
          'xiaowei',     // 小伟（男声，磁性）
          'xiaomei',     // 小美（女声，活泼）
          'xiaocheng',   // 小城（男声，新闻播报）
        ],
        defaultValue: 'xiaoyan',
      ),
      ToolParameter(
        name: 'speed',
        description: '语速（0.5-2.0，1.0 为正常速度）',
        type: ToolParameterType.doubleType,
        minValue: 0.5,
        maxValue: 2.0,
        defaultValue: 1.0,
      ),
      ToolParameter(
        name: 'pitch',
        description: '音调（0.5-2.0，1.0 为正常音调）',
        type: ToolParameterType.doubleType,
        minValue: 0.5,
        maxValue: 2.0,
        defaultValue: 1.0,
      ),
      ToolParameter(
        name: 'volume',
        description: '音量（0-100）',
        type: ToolParameterType.intType,
        minValue: 0,
        maxValue: 100,
        defaultValue: 70,
      ),
      ToolParameter(
        name: 'format',
        description: '输出音频格式',
        type: ToolParameterType.stringType,
        enumValues: ['mp3', 'wav', 'ogg', 'pcm'],
        defaultValue: 'mp3',
      ),
      ToolParameter(
        name: 'sample_rate',
        description: '采样率（Hz）',
        type: ToolParameterType.intType,
        enumValues: ['8000', '16000', '24000', '44100'],
        defaultValue: '24000',
      ),
    ],
    timeoutMs: 60000,
    execute: _executeTextToSpeech,
  );

  // ============================================================================
  // 生命周期
  // ============================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    // 初始化可用音色列表
    _availableVoices = _loadVoices();
    context.logger.info(
      'TTS 技能初始化完成，可用音色: ${_availableVoices.length} 种',
    );

    // 预连接火山引擎 SDK
    await _warmupConnection(context);
  }

  @override
  Future<void> onDispose() async {
    _activeTasks.clear();
  }

  // ============================================================================
  // 工具实现
  // ============================================================================

  /// 执行语音合成
  Future<ToolResult> _executeTextToSpeech(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final text = args['text'] as String;
    final voice = args['voice'] as String? ?? 'xiaoyan';
    final speed = (args['speed'] as num?)?.toDouble() ?? 1.0;
    final pitch = (args['pitch'] as num?)?.toDouble() ?? 1.0;
    final volume = args['volume'] as int? ?? 70;
    final format = args['format'] as String? ?? 'mp3';
    final sampleRate = args['sample_rate'] as String? ?? '24000';

    // 验证文本长度
    if (text.isEmpty) {
      return ToolResult.failure(
        error: '文本内容不能为空',
        errorCode: 'EMPTY_TEXT',
      );
    }

    if (text.length > _config.maxTextLength) {
      return ToolResult.failure(
        error: '文本过长（${text.length} 字符），最大支持 ${_config.maxTextLength} 字符',
        errorCode: 'TEXT_TOO_LONG',
      );
    }

    // 并发控制
    if (_activeTasks.length >= _maxConcurrency) {
      return ToolResult.failure(
        error: '合成任务过多，请稍后再试',
        errorCode: 'RATE_LIMITED',
      );
    }

    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeTasks.add(taskId);

    try {
      context.logger.info(
        'TTS 合成: ${text.length} 字符, 音色: $voice, 速度: $speed',
      );

      context.onProgress?.call(0.1, '正在初始化语音合成引擎...');

      // 分片处理长文本（火山引擎单次最大 300 字）
      final segments = _splitTextIntoSegments(text, _config.segmentSize);
      context.logger.info('文本分为 ${segments.length} 个片段');

      final audioSegments = <String>[];

      for (int i = 0; i < segments.length; i++) {
        context.onProgress?.call(
          0.1 + (0.8 * (i + 1) / segments.length),
          '正在合成第 ${i + 1}/${segments.length} 段...',
        );

        final audioUrl = await _synthesizeSegment(
          text: segments[i],
          voice: voice,
          speed: speed,
          pitch: pitch,
          volume: volume,
          format: format,
          sampleRate: int.parse(sampleRate),
          context: context,
        );

        audioSegments.add(audioUrl);
      }

      // 如果是多段，需要合并音频
      String finalAudioUrl;
      if (audioSegments.length == 1) {
        finalAudioUrl = audioSegments.first;
      } else {
        context.onProgress?.call(0.95, '正在合并音频片段...');
        finalAudioUrl = await _mergeAudioSegments(
          segments: audioSegments,
          format: format,
          context: context,
        );
      }

      context.onProgress?.call(1.0, '语音合成完成！');

      // 计算预估时长
      final estimatedDuration = _estimateDuration(text, speed);

      return ToolResult.success(
        content: '语音合成完成\n'
            '文本长度: ${text.length} 字符\n'
            '音色: $voice\n'
            '语速: ${speed}x\n'
            '预估时长: ${estimatedDuration.inSeconds} 秒\n'
            '音频地址: $finalAudioUrl',
        data: {
          'text_length': text.length,
          'voice': voice,
          'speed': speed,
          'format': format,
          'duration_seconds': estimatedDuration.inSeconds,
          'audio_url': finalAudioUrl,
          'segments': segments.length,
        },
        attachments: [
          ToolAttachment(
            type: AttachmentType.audio,
            uri: finalAudioUrl,
            description: '合成的语音音频',
            mimeType: 'audio/$format',
          ),
        ],
      );
    } catch (e) {
      context.logger.error('TTS 合成失败', e);
      return ToolResult.failure(
        error: '语音合成失败: $e',
        errorCode: 'TTS_FAILED',
      );
    } finally {
      _activeTasks.remove(taskId);
    }
  }

  // ============================================================================
  // 内部方法
  // ============================================================================

  /// 合成单个文本片段
  Future<String> _synthesizeSegment({
    required String text,
    required String voice,
    required double speed,
    required double pitch,
    required int volume,
    required String format,
    required int sampleRate,
    required SkillContext context,
  }) async {
    // 调用火山引擎 TTS API
    // TODO: 实际项目中需要使用火山引擎 SDK
    // https://www.volcengine.com/docs/6561/79823
    final response = await context.http.post(
      '${_config.apiBaseUrl}/tts/synthesize',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config.apiKey}',
      },
      body: {
        'text': text,
        'voice': voice,
        'speed': speed,
        'pitch': pitch,
        'volume': volume,
        'format': format,
        'sample_rate': sampleRate,
        'engine': 'volcengine',
      },
    );

    final responseData = jsonDecode(response) as Map<String, dynamic>;

    if (responseData['error'] != null) {
      throw Exception('TTS API 错误: ${responseData['error']}');
    }

    return responseData['audio_url'] as String;
  }

  /// 合并多个音频片段
  Future<String> _mergeAudioSegments({
    required List<String> segments,
    required String format,
    required SkillContext context,
  }) async {
    final response = await context.http.post(
      '${_config.apiBaseUrl}/tts/merge',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config.apiKey}',
      },
      body: {
        'segments': segments,
        'format': format,
      },
    );

    final responseData = jsonDecode(response) as Map<String, dynamic>;
    return responseData['merged_url'] as String;
  }

  /// 将长文本拆分为片段
  /// 按句子/段落边界拆分，避免截断单词
  List<String> _splitTextIntoSegments(String text, int maxSegmentSize) {
    if (text.length <= maxSegmentSize) return [text];

    final segments = <String>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      if (remaining.length <= maxSegmentSize) {
        segments.add(remaining);
        break;
      }

      // 在 maxSegmentSize 范围内找最近的句子边界
      var splitIndex = maxSegmentSize;
      final searchRange = remaining.substring(
        0,
        maxSegmentSize.clamp(0, remaining.length),
      );

      // 按优先级查找分隔符
      for (final delimiter in ['。', '！', '？', '.', '!', '?', '\n', '；', ';']) {
        final idx = searchRange.lastIndexOf(delimiter);
        if (idx > maxSegmentSize ~/ 2) {
          splitIndex = idx + 1;
          break;
        }
      }

      segments.add(remaining.substring(0, splitIndex).trim());
      remaining = remaining.substring(splitIndex).trim();
    }

    return segments.where((s) => s.isNotEmpty).toList();
  }

  /// 预估语音时长
  Duration _estimateDuration(String text, double speed) {
    // 中文语速：正常约 250 字/分钟
    // 英文语速：正常约 150 词/分钟
    // 简化计算：按字符数估算
    final charCount = text.length;
    final estimatedSeconds = (charCount / (250.0 / 60.0)) / speed;
    return Duration(seconds: estimatedSeconds.round());
  }

  /// 预连接（warmup）
  Future<void> _warmupConnection(SkillContext context) async {
    try {
      // 发送一个空请求来预热连接
      await context.http.get(
        '${_config.apiBaseUrl}/tts/voices',
        headers: {
          'Authorization': 'Bearer ${_config.apiKey}',
        },
      );
    } catch (e) {
      context.logger.warning('TTS warmup 失败: $e');
    }
  }

  /// 加载可用音色列表
  List<VoiceInfo> _loadVoices() {
    return [
      const VoiceInfo(
        id: 'xiaoyan',
        name: '小燕',
        description: '温柔女声',
        gender: 'female',
        language: 'zh-CN',
      ),
      const VoiceInfo(
        id: 'xiaoming',
        name: '小明',
        description: '阳光男声',
        gender: 'male',
        language: 'zh-CN',
      ),
      const VoiceInfo(
        id: 'xiaoxue',
        name: '小雪',
        description: '甜美女声',
        gender: 'female',
        language: 'zh-CN',
      ),
      const VoiceInfo(
        id: 'xiaogang',
        name: '小刚',
        description: '沉稳男声',
        gender: 'male',
        language: 'zh-CN',
      ),
      const VoiceInfo(
        id: 'xiaoli',
        name: '小丽',
        description: '知性女声',
        gender: 'female',
        language: 'zh-CN',
      ),
      const VoiceInfo(
        id: 'xiaowei',
        name: '小伟',
        description: '磁性男声',
        gender: 'male',
        language: 'zh-CN',
      ),
      const VoiceInfo(
        id: 'xiaomei',
        name: '小美',
        description: '活泼女声',
        gender: 'female',
        language: 'zh-CN',
      ),
      const VoiceInfo(
        id: 'xiaocheng',
        name: '小城',
        description: '新闻播报男声',
        gender: 'male',
        language: 'zh-CN',
      ),
    ];
  }
}

// ============================================================================
// 配置与模型
// ============================================================================

/// TTS 技能配置
class TTSConfig {
  /// API 基础 URL
  final String apiBaseUrl;

  /// API 密钥
  final String apiKey;

  /// 火山引擎 App ID
  final String volcAppId;

  /// 火山引擎 Token
  final String volcToken;

  /// 单次最大文本长度
  final int maxTextLength;

  /// 分段大小（火山引擎限制）
  final int segmentSize;

  /// 默认音色
  final String defaultVoice;

  const TTSConfig({
    this.apiBaseUrl = 'https://api.xiaosu.ai/v1',
    this.apiKey = '',
    this.volcAppId = '',
    this.volcToken = '',
    this.maxTextLength = 5000,
    this.segmentSize = 300,
    this.defaultVoice = 'xiaoyan',
  });
}

/// 音色信息
class VoiceInfo {
  final String id;
  final String name;
  final String description;
  final String gender;
  final String language;

  const VoiceInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.gender,
    required this.language,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'gender': gender,
        'language': language,
      };
}
