// ============================================================================
// 小酥 AI 助手 - 视频生成技能
// ============================================================================
// 提供文生视频、图生视频、幻灯片视频、字幕引擎、背景音乐管理
// 视频剪辑、帧提取、风格迁移等功能
// ============================================================================

import 'dart:async';
import 'dart:convert';

import '../../core/skill/skill.dart';

// ============================================================================
// 配置与数据模型
// ============================================================================

class VideoGenConfig {
  final String defaultApiBackend;
  final String defaultResolution;
  final int defaultFrameRate;
  final String defaultCodec;
  final int maxDurationSeconds;
  final List<String> supportedFormats;
  final Map<String, String> apiEndpoints;

  const VideoGenConfig({
    this.defaultApiBackend = 'runway',
    this.defaultResolution = '1080p',
    this.defaultFrameRate = 30,
    this.defaultCodec = 'h264',
    this.maxDurationSeconds = 300,
    this.supportedFormats = const ['mp4', 'mov', 'webm', 'avi'],
    this.apiEndpoints = const {
      'runway': 'https://api.runwayml.com/v1',
      'pika': 'https://api.pika.art/v1',
      'sora': 'https://api.openai.com/v1',
    },
  });
}

enum VideoGenMode {
  textToVideo('text_to_video', '文生视频'),
  imageToVideo('image_to_video', '图生视频'),
  slideshow('slideshow', '幻灯片视频'),
  editing('editing', '视频剪辑');

  final String code;
  final String displayName;
  const VideoGenMode(this.code, this.displayName);
}

class VideoProject {
  final String id;
  final String title;
  final VideoGenMode mode;
  final String status;
  final String? outputPath;
  final Map<String, dynamic> metadata;

  const VideoProject({
    required this.id, required this.title, required this.mode,
    this.status = 'pending', this.outputPath, this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'mode': mode.code,
    'status': status, 'output_path': outputPath, 'metadata': metadata,
  };
}

class SubtitleEntry {
  final int index;
  final Duration startTime;
  final Duration endTime;
  final String text;
  final Map<String, dynamic> style;

  const SubtitleEntry({
    required this.index, required this.startTime, required this.endTime,
    required this.text, this.style = const {},
  });

  String toSrt() {
    String fmt(Duration d) {
      final h = d.inHours.toString().padLeft(2, '0');
      final m = (d.inMinutes % 60).toString().padLeft(2, '0');
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
      return '$h:$m:$s,$ms';
    }
    return '${index}\n${fmt(startTime)} --> ${fmt(endTime)}\n$text\n';
  }

  Map<String, dynamic> toJson() => {
    'index': index, 'start': startTime.inMilliseconds,
    'end': endTime.inMilliseconds, 'text': text, 'style': style,
  };
}

class BgmTrack {
  final String id;
  final String name;
  final String genre;
  final int durationSeconds;
  final String? filePath;
  final String? url;
  final int bpm;
  final String mood;

  const BgmTrack({
    required this.id, required this.name, required this.genre,
    required this.durationSeconds, this.filePath, this.url,
    this.bpm = 120, this.mood = 'neutral',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'genre': genre,
    'duration_seconds': durationSeconds, 'bpm': bpm, 'mood': mood,
  };
}

class ExportConfig {
  final String resolution;
  final int frameRate;
  final String codec;
  final int bitrate;
  final String format;
  final bool includeAudio;

  const ExportConfig({
    this.resolution = '1080p', this.frameRate = 30,
    this.codec = 'h264', this.bitrate = 8000000,
    this.format = 'mp4', this.includeAudio = true,
  });

  Map<String, dynamic> toJson() => {
    'resolution': resolution, 'frame_rate': frameRate,
    'codec': codec, 'bitrate': bitrate,
    'format': format, 'include_audio': includeAudio,
  };
}

class VideoClip {
  final String id;
  final String sourcePath;
  final Duration startTime;
  final Duration endTime;
  final String? transition;
  final double volume;

  const VideoClip({
    required this.id, required this.sourcePath,
    required this.startTime, required this.endTime,
    this.transition, this.volume = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'source_path': sourcePath,
    'start_time': startTime.inMilliseconds,
    'end_time': endTime.inMilliseconds,
    'transition': transition, 'volume': volume,
  };
}

class ExtractedFrame {
  final int frameIndex;
  final Duration timestamp;
  final String filePath;
  final int width;
  final int height;

  const ExtractedFrame({
    required this.frameIndex, required this.timestamp,
    required this.filePath, required this.width, required this.height,
  });

  Map<String, dynamic> toJson() => {
    'frame_index': frameIndex, 'timestamp': timestamp.inMilliseconds,
    'file_path': filePath, 'width': width, 'height': height,
  };
}

// ============================================================================
// 字幕引擎
// ============================================================================

class SubtitleEngine {
  List<SubtitleEntry> parseSrt(String srtContent) {
    final entries = <SubtitleEntry>[];
    final blocks = srtContent.trim().split(RegExp(r'\n\n+'));
    for (var i = 0; i < blocks.length; i++) {
      final lines = blocks[i].trim().split('\n');
      if (lines.length < 3) continue;
      final index = int.tryParse(lines[0]) ?? (i + 1);
      final timeParts = lines[1].split(' --> ');
      if (timeParts.length != 2) continue;
      final start = _parseTimestamp(timeParts[0]);
      final end = _parseTimestamp(timeParts[1]);
      final text = lines.sublist(2).join('\n');
      entries.add(SubtitleEntry(index: index, startTime: start, endTime: end, text: text));
    }
    return entries;
  }

  List<SubtitleEntry> parseAss(String assContent) {
    final entries = <SubtitleEntry>[];
    final lines = assContent.split('\n');
    var idx = 0;
    for (final line in lines) {
      if (!line.startsWith('Dialogue:')) continue;
      idx++;
      final parts = line.substring(9).split(',');
      if (parts.length < 10) continue;
      final start = _parseAssTime(parts[1].trim());
      final end = _parseAssTime(parts[2].trim());
      final text = parts.sublist(9).join(',').replaceAll(r'\N', '\n');
      entries.add(SubtitleEntry(index: idx, startTime: start, endTime: end, text: text));
    }
    return entries;
  }

  String generateSrt(List<SubtitleEntry> entries) {
    return entries.map((e) => e.toSrt()).join('\n');
  }

  Map<String, dynamic> getDefaultStyle({String preset = 'default'}) {
    return switch (preset) {
      'bold' => {'font_size': 24, 'font_color': '#FFFFFF', 'bg_color': '#00000080',
        'position': 'bottom', 'font_family': 'sans-serif', 'bold': true},
      'elegant' => {'font_size': 20, 'font_color': '#F5F5F5', 'bg_color': '#00000040',
        'position': 'bottom', 'font_family': 'serif', 'italic': true},
      'dynamic' => {'font_size': 28, 'font_color': '#FFD700', 'bg_color': '#00000060',
        'position': 'center', 'font_family': 'sans-serif', 'bold': true},
      _ => {'font_size': 22, 'font_color': '#FFFFFF', 'bg_color': '#00000060',
        'position': 'bottom', 'font_family': 'sans-serif'},
    };
  }

  Duration _parseTimestamp(String ts) {
    final parts = ts.trim().replaceAll(',', '.').split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final secParts = parts[2].split('.');
      final s = int.tryParse(secParts[0]) ?? 0;
      final ms = secParts.length > 1 ? int.tryParse(secParts[1]) ?? 0 : 0;
      return Duration(hours: h, minutes: m, seconds: s, milliseconds: ms);
    }
    return Duration.zero;
  }

  Duration _parseAssTime(String ts) {
    final parts = ts.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final secParts = parts[2].split('.');
      final s = int.tryParse(secParts[0]) ?? 0;
      final cs = secParts.length > 1 ? int.tryParse(secParts[1]) ?? 0 : 0;
      return Duration(hours: h, minutes: m, seconds: s, milliseconds: cs * 10);
    }
    return Duration.zero;
  }
}

// ============================================================================
// 背景音乐管理器
// ============================================================================

class BgmManager {
  static const List<BgmTrack> _library = [
    BgmTrack(id: 'bgm_001', name: '轻快节奏', genre: 'pop', durationSeconds: 180, bpm: 128, mood: 'happy'),
    BgmTrack(id: 'bgm_002', name: '温暖午后', genre: 'acoustic', durationSeconds: 210, bpm: 90, mood: 'warm'),
    BgmTrack(id: 'bgm_003', name: '科技未来', genre: 'electronic', durationSeconds: 150, bpm: 140, mood: 'tech'),
    BgmTrack(id: 'bgm_004', name: '感性时光', genre: 'piano', durationSeconds: 240, bpm: 72, mood: 'emotional'),
    BgmTrack(id: 'bgm_005', name: '冒险出发', genre: 'cinematic', durationSeconds: 200, bpm: 110, mood: 'epic'),
    BgmTrack(id: 'bgm_006', name: '治愈日常', genre: 'lofi', durationSeconds: 300, bpm: 85, mood: 'chill'),
    BgmTrack(id: 'bgm_007', name: '活力运动', genre: 'rock', durationSeconds: 180, bpm: 150, mood: 'energetic'),
    BgmTrack(id: 'bgm_008', name: '安静夜晚', genre: 'ambient', durationSeconds: 360, bpm: 60, mood: 'calm'),
  ];

  List<BgmTrack> search({String? genre, String? mood, int? maxDuration}) {
    var results = _library.toList();
    if (genre != null) results = results.where((t) => t.genre == genre).toList();
    if (mood != null) results = results.where((t) => t.mood == mood).toList();
    if (maxDuration != null) results = results.where((t) => t.durationSeconds <= maxDuration).toList();
    return results;
  }

  BgmTrack? suggest(String videoMood) {
    final matched = _library.where((t) => t.mood == videoMood);
    return matched.isNotEmpty ? matched.first : _library.first;
  }
}

// ============================================================================
// 视频生成引擎
// ============================================================================

class VideoGenEngine {
  final VideoGenConfig _config;
  VideoGenEngine(this._config);

  Future<Map<String, dynamic>> generateFromText({
    required String prompt,
    required SkillContext context,
    String? negativePrompt,
    String? resolution,
    int? duration,
    String? backend,
  }) async {
    final effectiveBackend = backend ?? _config.defaultApiBackend;
    final endpoint = _config.apiEndpoints[effectiveBackend] ?? _config.apiEndpoints['runway']!;

    context.logger.info('文生视频：backend=$effectiveBackend, prompt=${prompt.substring(0, prompt.length.clamp(0, 50))}...');

    final body = {
      'model': effectiveBackend,
      'prompt': prompt,
      if (negativePrompt != null) 'negative_prompt': negativePrompt,
      'resolution': resolution ?? _config.defaultResolution,
      'duration_seconds': duration ?? 10,
      'fps': _config.defaultFrameRate,
    };

    // 模拟 API 调用
    final projectId = 'vp_${DateTime.now().millisecondsSinceEpoch}';
    return {
      'project_id': projectId,
      'status': 'processing',
      'backend': effectiveBackend,
      'prompt': prompt,
      'resolution': body['resolution'],
      'duration_seconds': body['duration_seconds'],
      'estimated_time_seconds': 120,
      'endpoint': endpoint,
    };
  }

  Future<Map<String, dynamic>> generateFromImage({
    required String imagePath,
    required SkillContext context,
    String? motionPrompt,
    int? duration,
  }) async {
    context.logger.info('图生视频：image=$imagePath');
    final projectId = 'vp_${DateTime.now().millisecondsSinceEpoch}';
    return {
      'project_id': projectId, 'status': 'processing', 'mode': 'image_to_video',
      'source_image': imagePath, 'motion_prompt': motionPrompt ?? 'slow zoom in',
      'duration_seconds': duration ?? 5, 'interpolation': 'keyframe',
      'estimated_time_seconds': 90,
    };
  }

  Future<Map<String, dynamic>> createSlideshow({
    required List<String> imagePaths,
    required SkillContext context,
    String? transition,
    int? slideDuration,
    String? bgmId,
  }) async {
    final effectiveTransition = transition ?? 'fade';
    final effectiveSlideDuration = slideDuration ?? 3;

    context.logger.info('幻灯片视频：${imagePaths.length}张图片');
    final projectId = 'vp_${DateTime.now().millisecondsSinceEpoch}';

    final segments = <Map<String, dynamic>>[];
    for (var i = 0; i < imagePaths.length; i++) {
      segments.add({
        'index': i, 'image': imagePaths[i],
        'duration': effectiveSlideDuration,
        'transition': i < imagePaths.length - 1 ? effectiveTransition : null,
      });
    }

    return {
      'project_id': projectId, 'status': 'processing', 'mode': 'slideshow',
      'segments': segments, 'total_duration': imagePaths.length * effectiveSlideDuration,
      'bgm_id': bgmId,
    };
  }
}

// ============================================================================
// 视频剪辑引擎
// ============================================================================

class VideoEditEngine {
  Future<Map<String, dynamic>> trimClip({
    required String sourcePath, required Duration startTime, required Duration endTime,
  }) async {
    return {
      'action': 'trim', 'source': sourcePath,
      'start_time': startTime.inMilliseconds, 'end_time': endTime.inMilliseconds,
      'output_duration': (endTime - startTime).inMilliseconds,
      'status': 'completed',
    };
  }

  Future<Map<String, dynamic>> mergeClips({
    required List<VideoClip> clips, String? transition,
  }) async {
    final totalDuration = clips.fold<Duration>(
      Duration.zero, (sum, clip) => sum + (clip.endTime - clip.startTime),
    );
    return {
      'action': 'merge', 'clip_count': clips.length,
      'clips': clips.map((c) => c.toJson()).toList(),
      'total_duration': totalDuration.inMilliseconds,
      'default_transition': transition ?? 'cut',
      'status': 'completed',
    };
  }

  Future<Map<String, dynamic>> applyTransition({
    required String clipId1, required String clipId2,
    required String transitionType, int durationMs = 500,
  }) async {
    return {
      'action': 'transition', 'from_clip': clipId1, 'to_clip': clipId2,
      'type': transitionType, 'duration_ms': durationMs, 'status': 'applied',
    };
  }

  List<String> getAvailableTransitions() => [
    'cut', 'fade', 'dissolve', 'wipe_left', 'wipe_right',
    'slide_up', 'slide_down', 'zoom_in', 'zoom_out', 'blur',
    'spin', 'flip', 'glitch', 'light_leak',
  ];
}

// ============================================================================
// 帧提取与分析引擎
// ============================================================================

class FrameExtractor {
  Future<List<ExtractedFrame>> extractFrames({
    required String videoPath, required int intervalSeconds,
    required String outputDir,
  }) async {
    final frames = <ExtractedFrame>[];
    // 模拟帧提取
    final totalFrames = 30;
    for (var i = 0; i < totalFrames; i++) {
      frames.add(ExtractedFrame(
        frameIndex: i,
        timestamp: Duration(seconds: i * intervalSeconds),
        filePath: '$outputDir/frame_${i.toString().padLeft(4, '0')}.jpg',
        width: 1920, height: 1080,
      ));
    }
    return frames;
  }

  Future<Map<String, dynamic>> analyzeSceneChanges({
    required String videoPath, double threshold = 0.3,
  }) async {
    return {
      'video_path': videoPath, 'threshold': threshold,
      'scenes': [
        {'start': 0, 'end': 15, 'dominant_color': '#2C3E50'},
        {'start': 15, 'end': 45, 'dominant_color': '#E74C3C'},
        {'start': 45, 'end': 90, 'dominant_color': '#3498DB'},
      ],
      'total_scenes': 3,
    };
  }
}

// ============================================================================
// 风格迁移引擎
// ============================================================================

class StyleTransferEngine {
  Future<Map<String, dynamic>> applyStyle({
    required String videoPath, required String style,
    double intensity = 0.8,
  }) async {
    final availableStyles = {
      'cinematic': '电影质感：宽画幅、胶片颗粒、色彩分级',
      'anime': '动漫风格：线条清晰、色彩饱和、赛璐璐渲染',
      'watercolor': '水彩画风格：柔和边缘、色彩晕染、纸质纹理',
      'vintage': '复古风格：褪色、暖色调、胶片质感、暗角',
      'noir': '黑色电影：高对比度、黑白为主、阴影强烈',
      'cyberpunk': '赛博朋克：霓虹灯效、暗色调、科技光效',
      'ghibli': '吉卜力风格：柔和色彩、自然光感、手绘质感',
      'pop_art': '波普艺术：高饱和、网点纹理、大胆撞色',
    };

    return {
      'video_path': videoPath, 'style': style,
      'style_description': availableStyles[style] ?? style,
      'intensity': intensity, 'status': 'processing',
      'estimated_time_seconds': 180,
    };
  }

  List<String> getAvailableStyles() => [
    'cinematic', 'anime', 'watercolor', 'vintage',
    'noir', 'cyberpunk', 'ghibli', 'pop_art',
  ];
}

// ============================================================================
// 视频生成技能主类
// ============================================================================

class VideoGenSkill extends Skill {
  final VideoGenConfig _config;
  late final VideoGenEngine _genEngine;
  late final SubtitleEngine _subtitleEngine;
  late final BgmManager _bgmManager;
  late final VideoEditEngine _editEngine;
  late final FrameExtractor _frameExtractor;
  late final StyleTransferEngine _styleEngine;
  final List<VideoProject> _projects = [];

  VideoGenSkill({VideoGenConfig? config}) : _config = config ?? const VideoGenConfig() {
    _genEngine = VideoGenEngine(_config);
    _subtitleEngine = SubtitleEngine();
    _bgmManager = BgmManager();
    _editEngine = VideoEditEngine();
    _frameExtractor = FrameExtractor();
    _styleEngine = StyleTransferEngine();
  }

  @override
  SkillManifest get manifest => const SkillManifest(
    id: 'video_gen', name: '\u89C6\u9891\u751F\u6210',
    description: '\u751F\u6210\u548C\u7F16\u8F91\u89C6\u9891\u3002\u652F\u6301\u6587\u751F\u89C6\u9891\u3001\u56FE\u751F\u89C6\u9891\u3001\u5E7B\u706F\u7247\u89C6\u9891\u3001'
        '\u5B57\u5E55\u6DFB\u52A0\u3001\u80CC\u666F\u97F3\u4E50\u3001\u89C6\u9891\u526A\u8F91\u3001\u5E27\u63D0\u53D6\u3001\u98CE\u683C\u8FC1\u79FB\u7B49\u529F\u80FD\u3002',
    version: '1.0.0', author: '\u5C0F\u9165',
    permissions: [SkillPermission.networkAccess, SkillPermission.fileRead,
      SkillPermission.fileWrite, SkillPermission.mediaAccess],
    loadStrategy: SkillLoadStrategy.lazy,
  );

  @override
  List<SkillTool> get tools => [
    _generateVideoTool, _createSlideshowTool, _textToVideoTool,
    _imageToVideoTool, _addSubtitlesTool, _addBgmTool,
    _videoEditTool, _extractFramesTool, _mergeClipsTool, _videoStyleTransferTool,
  ];

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('\u89C6\u9891\u751F\u6210\u6280\u80FD\u521D\u59CB\u5316\u5B8C\u6210');
  }

  @override
  Future<void> onDispose() async { _projects.clear(); }

  // ======================== 工具定义 ========================

  late final SkillTool _generateVideoTool = SkillTool(
    name: 'generate_video',
    description: '\u8C03\u7528 AI API\uFF08Runway/Pika/Sora\uFF09\u6839\u636E\u63CF\u8FF0\u751F\u6210\u89C6\u9891\u3002\u652F\u6301\u591A\u79CD\u5206\u8FA8\u7387\u548C\u65F6\u957F\u3002',
    parameters: [
      ToolParameter(name: 'prompt', description: '\u89C6\u9891\u63CF\u8FF0/\u63D0\u793A\u8BCD', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'negative_prompt', description: '\u4E0D\u60F3\u51FA\u73B0\u7684\u5185\u5BB9', type: ToolParameterType.stringType),
      ToolParameter(name: 'resolution', description: '\u5206\u8FA8\u7387', type: ToolParameterType.stringType,
        enumValues: ['480p', '720p', '1080p', '4k'], defaultValue: '1080p'),
      ToolParameter(name: 'duration', description: '\u89C6\u9891\u65F6\u957F\uFF08\u79D2\uFF09', type: ToolParameterType.intType, minValue: 2, maxValue: 60, defaultValue: 10),
      ToolParameter(name: 'backend', description: '\u751F\u6210\u540E\u7AEF', type: ToolParameterType.stringType,
        enumValues: ['runway', 'pika', 'sora'], defaultValue: 'runway'),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.1, '\u6B63\u5728\u63D0\u4EA4\u89C6\u9891\u751F\u6210\u4EFB\u52A1...');
      final result = await _genEngine.generateFromText(
        prompt: args['prompt'] as String, context: context,
        negativePrompt: args['negative_prompt'] as String?,
        resolution: args['resolution'] as String?,
        duration: args['duration'] as int?,
        backend: args['backend'] as String?,
      );
      context.onProgress?.call(1.0, '\u89C6\u9891\u751F\u6210\u4EFB\u52A1\u5DF2\u63D0\u4EA4');
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _createSlideshowTool = SkillTool(
    name: 'create_slideshow',
    description: '\u5C06\u591A\u5F20\u56FE\u7247\u5408\u6210\u5E7B\u706F\u7247\u89C6\u9891\u3002\u652F\u6301\u8F6C\u573A\u6548\u679C\u3001\u80CC\u666F\u97F3\u4E50\u3001\u6BCF\u5F20\u505C\u7559\u65F6\u957F\u8BBE\u7F6E\u3002',
    parameters: [
      ToolParameter(name: 'image_paths', description: '\u56FE\u7247\u8DEF\u5F84\u5217\u8868', type: ToolParameterType.arrayType, required: true),
      ToolParameter(name: 'transition', description: '\u8F6C\u573A\u6548\u679C', type: ToolParameterType.stringType,
        enumValues: ['fade', 'dissolve', 'wipe', 'slide', 'zoom', 'cut'], defaultValue: 'fade'),
      ToolParameter(name: 'slide_duration', description: '\u6BCF\u5F20\u505C\u7559\u79D2\u6570', type: ToolParameterType.intType, minValue: 1, maxValue: 15, defaultValue: 3),
      ToolParameter(name: 'bgm_id', description: '\u80CC\u666F\u97F3\u4E50 ID\uFF08\u53EF\u9009\uFF09', type: ToolParameterType.stringType),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.3, '\u6B63\u5728\u521B\u5EFA\u5E7B\u706F\u7247\u89C6\u9891...');
      final images = (args['image_paths'] as List).cast<String>();
      final result = await _genEngine.createSlideshow(
        imagePaths: images, context: context,
        transition: args['transition'] as String?,
        slideDuration: args['slide_duration'] as int?,
        bgmId: args['bgm_id'] as String?,
      );
      context.onProgress?.call(1.0, '\u5E7B\u706F\u7247\u89C6\u9891\u521B\u5EFA\u5B8C\u6210');
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _textToVideoTool = SkillTool(
    name: 'text_to_video',
    description: '\u5C06\u6587\u672C\u5185\u5BB9\u8F6C\u5316\u4E3A\u89C6\u9891\u3002\u81EA\u52A8\u751F\u6210\u753B\u9762\u3001\u914D\u4E50\u3001\u5B57\u5E55\u3002',
    parameters: [
      ToolParameter(name: 'text', description: '\u8981\u8F6C\u5316\u7684\u6587\u672C\u5185\u5BB9', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'style', description: '\u89C6\u9891\u98CE\u683C', type: ToolParameterType.stringType,
        enumValues: ['cinematic', 'documentary', 'creative', 'minimal'], defaultValue: 'cinematic'),
      ToolParameter(name: 'voice', description: '\u65C1\u767D\u97F3\u8272', type: ToolParameterType.stringType),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.1, '\u6B63\u5728\u5206\u6790\u6587\u672C\u5E76\u751F\u6210\u89C6\u9891...');
      final text = args['text'] as String;
      final style = args['style'] as String? ?? 'cinematic';
      final result = {
        'mode': 'text_to_video', 'text_length': text.length,
        'style': style, 'voice': args['voice'],
        'scenes': _generateScenesFromText(text),
        'status': 'processing',
      };
      context.onProgress?.call(1.0, '\u6587\u672C\u8F6C\u89C6\u9891\u4EFB\u52A1\u5DF2\u521B\u5EFA');
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _imageToVideoTool = SkillTool(
    name: 'image_to_video',
    description: '\u5C06\u9759\u6001\u56FE\u7247\u8F6C\u5316\u4E3A\u52A8\u6001\u89C6\u9891\u3002\u652F\u6301\u5173\u952E\u5E27\u63D2\u503C\u3001\u8FD0\u52A8\u63CF\u8FF0\u3002',
    parameters: [
      ToolParameter(name: 'image_path', description: '\u8F93\u5165\u56FE\u7247\u8DEF\u5F84', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'motion_prompt', description: '\u8FD0\u52A8\u63CF\u8FF0\uFF08\u5982 zoom in\u3001pan left\uFF09', type: ToolParameterType.stringType),
      ToolParameter(name: 'duration', description: '\u89C6\u9891\u65F6\u957F\uFF08\u79D2\uFF09', type: ToolParameterType.intType, minValue: 2, maxValue: 30, defaultValue: 5),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.3, '\u6B63\u5728\u56FE\u751F\u89C6\u9891...');
      final result = await _genEngine.generateFromImage(
        imagePath: args['image_path'] as String, context: context,
        motionPrompt: args['motion_prompt'] as String?,
        duration: args['duration'] as int?,
      );
      context.onProgress?.call(1.0, '\u56FE\u751F\u89C6\u9891\u5B8C\u6210');
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _addSubtitlesTool = SkillTool(
    name: 'add_subtitles',
    description: '\u4E3A\u89C6\u9891\u6DFB\u52A0\u5B57\u5E55\u3002\u652F\u6301 SRT/ASS \u6587\u4EF6\u5BFC\u5165\u3001ASR \u81EA\u52A8\u8BC6\u522B\u3001\u624B\u52A8\u8F93\u5165\u3002\u53EF\u81EA\u5B9A\u4E49\u5B57\u5E55\u6837\u5F0F\u3002',
    parameters: [
      ToolParameter(name: 'video_path', description: '\u89C6\u9891\u6587\u4EF6\u8DEF\u5F84', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'subtitle_source', description: '\u5B57\u5E55\u6765\u6E90', type: ToolParameterType.stringType,
        enumValues: ['srt_file', 'ass_file', 'asr_auto', 'manual'], required: true),
      ToolParameter(name: 'subtitle_content', description: '\u5B57\u5E55\u5185\u5BB9\uFF08srt\u6587\u672C\u6216\u624B\u52A8\u8F93\u5165\uFF09', type: ToolParameterType.stringType),
      ToolParameter(name: 'style_preset', description: '\u5B57\u5E55\u6837\u5F0F', type: ToolParameterType.stringType,
        enumValues: ['default', 'bold', 'elegant', 'dynamic'], defaultValue: 'default'),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.3, '\u6B63\u5728\u5904\u7406\u5B57\u5E55...');
      final source = args['subtitle_source'] as String;
      final content = args['subtitle_content'] as String?;
      final style = _subtitleEngine.getDefaultStyle(preset: args['style_preset'] as String? ?? 'default');

      List<SubtitleEntry> entries = [];
      if (source == 'srt_file' && content != null) {
        entries = _subtitleEngine.parseSrt(content);
      } else if (source == 'ass_file' && content != null) {
        entries = _subtitleEngine.parseAss(content);
      } else if (source == 'asr_auto') {
        entries = _generateMockAsrEntries();
      }

      final srtOutput = _subtitleEngine.generateSrt(entries);
      final result = {
        'video_path': args['video_path'], 'subtitle_count': entries.length,
        'style': style, 'srt_content': srtOutput,
        'subtitles': entries.map((e) => e.toJson()).toList(),
      };
      context.onProgress?.call(1.0, '\u5B57\u5E55\u6DFB\u52A0\u5B8C\u6210');
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _addBgmTool = SkillTool(
    name: 'add_bgm',
    description: '\u4E3A\u89C6\u9891\u6DFB\u52A0\u80CC\u666F\u97F3\u4E50\u3002\u652F\u6301\u97F3\u4E50\u5E93\u641C\u7D22\u3001\u667A\u80FD\u63A8\u8350\u3001\u97F3\u91CF\u8C03\u8282\u3002',
    parameters: [
      ToolParameter(name: 'video_path', description: '\u89C6\u9891\u6587\u4EF6\u8DEF\u5F84', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'bgm_id', description: '\u97F3\u4E50\u5E93\u4E2D\u7684\u97F3\u4E50 ID', type: ToolParameterType.stringType),
      ToolParameter(name: 'mood', description: '\u97F3\u4E50\u6C1B\u56F4\uFF08\u7528\u4E8E\u641C\u7D22\u63A8\u8350\uFF09', type: ToolParameterType.stringType,
        enumValues: ['happy', 'warm', 'tech', 'emotional', 'epic', 'chill', 'energetic', 'calm']),
      ToolParameter(name: 'volume', description: '\u97F3\u91CF\uFF080.0-1.0\uFF09', type: ToolParameterType.doubleType, minValue: 0.0, maxValue: 1.0, defaultValue: 0.7),
    ],
    execute: (args, context) async {
      var bgmId = args['bgm_id'] as String?;
      final mood = args['mood'] as String?;
      if (bgmId == null && mood != null) {
        final suggested = _bgmManager.suggest(mood);
        bgmId = suggested?.id;
      }
      final library = _bgmManager.search(mood: mood);
      final result = {
        'video_path': args['video_path'], 'bgm_id': bgmId,
        'volume': args['volume'] ?? 0.7,
        'available_bgm': library.map((t) => t.toJson()).toList(),
      };
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _videoEditTool = SkillTool(
    name: 'video_edit',
    description: '\u89C6\u9891\u7F16\u8F91\u3002\u652F\u6301\u88C1\u526A\u3001\u62FC\u63A5\u3001\u8F6C\u573A\u6548\u679C\u3002\u53EF\u6307\u5B9A\u5BFC\u51FA\u914D\u7F6E\u3002',
    parameters: [
      ToolParameter(name: 'action', description: '\u7F16\u8F91\u64CD\u4F5C', type: ToolParameterType.stringType,
        enumValues: ['trim', 'split', 'merge', 'add_transition'], required: true),
      ToolParameter(name: 'source_path', description: '\u6E90\u89C6\u9891\u8DEF\u5F84', type: ToolParameterType.stringType),
      ToolParameter(name: 'start_time_ms', description: '\u8D77\u59CB\u65F6\u95F4\uFF08\u6BEB\u79D2\uFF09', type: ToolParameterType.intType),
      ToolParameter(name: 'end_time_ms', description: '\u7ED3\u675F\u65F6\u95F4\uFF08\u6BEB\u79D2\uFF09', type: ToolParameterType.intType),
      ToolParameter(name: 'transition', description: '\u8F6C\u573A\u7C7B\u578B', type: ToolParameterType.stringType),
      ToolParameter(name: 'export_config', description: '\u5BFC\u51FA\u914D\u7F6E', type: ToolParameterType.objectType),
    ],
    execute: (args, context) async {
      final action = args['action'] as String;
      Map<String, dynamic> result;
      switch (action) {
        case 'trim':
          result = await _editEngine.trimClip(
            sourcePath: args['source_path'] as String,
            startTime: Duration(milliseconds: args['start_time_ms'] as int? ?? 0),
            endTime: Duration(milliseconds: args['end_time_ms'] as int? ?? 30000),
          );
        case 'add_transition':
          result = await _editEngine.applyTransition(
            clipId1: 'clip_1', clipId2: 'clip_2',
            transitionType: args['transition'] as String? ?? 'fade',
          );
        default:
          result = {'action': action, 'status': 'completed', 'available_transitions': _editEngine.getAvailableTransitions()};
      }
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _extractFramesTool = SkillTool(
    name: 'extract_frames',
    description: '\u4ECE\u89C6\u9891\u4E2D\u63D0\u53D6\u5E27\u56FE\u7247\u3002\u652F\u6301\u6309\u65F6\u95F4\u95F4\u9694\u63D0\u53D6\u3001\u573A\u666F\u5207\u6362\u68C0\u6D4B\u3002',
    parameters: [
      ToolParameter(name: 'video_path', description: '\u89C6\u9891\u6587\u4EF6\u8DEF\u5F84', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'interval_seconds', description: '\u63D0\u53D6\u95F4\u9694\uFF08\u79D2\uFF09', type: ToolParameterType.intType, minValue: 1, maxValue: 60, defaultValue: 5),
      ToolParameter(name: 'output_dir', description: '\u8F93\u51FA\u76EE\u5F55', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'detect_scenes', description: '\u662F\u5426\u68C0\u6D4B\u573A\u666F\u53D8\u5316', type: ToolParameterType.boolType, defaultValue: false),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.2, '\u6B63\u5728\u63D0\u53D6\u5E27...');
      final frames = await _frameExtractor.extractFrames(
        videoPath: args['video_path'] as String,
        intervalSeconds: args['interval_seconds'] as int? ?? 5,
        outputDir: args['output_dir'] as String,
      );
      Map<String, dynamic>? sceneAnalysis;
      if (args['detect_scenes'] == true) {
        sceneAnalysis = await _frameExtractor.analyzeSceneChanges(videoPath: args['video_path'] as String);
      }
      context.onProgress?.call(1.0, '\u5E27\u63D0\u53D6\u5B8C\u6210');
      final result = {
        'frame_count': frames.length,
        'frames': frames.map((f) => f.toJson()).toList(),
        if (sceneAnalysis != null) 'scene_analysis': sceneAnalysis,
      };
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _mergeClipsTool = SkillTool(
    name: 'merge_clips',
    description: '\u5C06\u591A\u4E2A\u89C6\u9891\u7247\u6BB5\u62FC\u63A5\u5408\u5E76\u3002\u652F\u6301\u6DFB\u52A0\u8F6C\u573A\u6548\u679C\u3002',
    parameters: [
      ToolParameter(name: 'clips', description: '\u7247\u6BB5\u5217\u8868\uFF08\u5305\u542B source_path\u3001start_time_ms\u3001end_time_ms\uFF09', type: ToolParameterType.arrayType, required: true),
      ToolParameter(name: 'transition', description: '\u9ED8\u8BA4\u8F6C\u573A\u6548\u679C', type: ToolParameterType.stringType, defaultValue: 'cut'),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.3, '\u6B63\u5728\u62FC\u63A5\u7247\u6BB5...');
      final clipData = (args['clips'] as List).cast<Map<String, dynamic>>();
      final clips = clipData.map((c) => VideoClip(
        id: c['id'] as String? ?? 'clip_${clipData.indexOf(c)}',
        sourcePath: c['source_path'] as String,
        startTime: Duration(milliseconds: c['start_time_ms'] as int? ?? 0),
        endTime: Duration(milliseconds: c['end_time_ms'] as int? ?? 10000),
      )).toList();
      final result = await _editEngine.mergeClips(
        clips: clips, transition: args['transition'] as String?,
      );
      context.onProgress?.call(1.0, '\u7247\u6BB5\u62FC\u63A5\u5B8C\u6210');
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _videoStyleTransferTool = SkillTool(
    name: 'video_style_transfer',
    description: '\u89C6\u9891\u98CE\u683C\u8FC1\u79FB\u3002\u652F\u6301\u7535\u5F71\u611F\u3001\u52A8\u6F2B\u3001\u6C34\u5F69\u3001\u590D\u53E4\u3001\u8D5B\u535A\u670B\u514B\u7B49\u591A\u79CD\u98CE\u683C\u3002',
    parameters: [
      ToolParameter(name: 'video_path', description: '\u89C6\u9891\u6587\u4EF6\u8DEF\u5F84', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'style', description: '\u98CE\u683C', type: ToolParameterType.stringType,
        enumValues: ['cinematic', 'anime', 'watercolor', 'vintage', 'noir', 'cyberpunk', 'ghibli', 'pop_art'],
        required: true),
      ToolParameter(name: 'intensity', description: '\u98CE\u683C\u5F3A\u5EA6\uFF080.0-1.0\uFF09', type: ToolParameterType.doubleType, minValue: 0.0, maxValue: 1.0, defaultValue: 0.8),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.1, '\u6B63\u5728\u5E94\u7528\u98CE\u683C\u8FC1\u79FB...');
      final result = await _styleEngine.applyStyle(
        videoPath: args['video_path'] as String,
        style: args['style'] as String,
        intensity: (args['intensity'] as num?)?.toDouble() ?? 0.8,
      );
      result['available_styles'] = _styleEngine.getAvailableStyles();
      context.onProgress?.call(1.0, '\u98CE\u683C\u8FC1\u79FB\u5B8C\u6210');
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  // ======================== 内部方法 ========================

  List<Map<String, dynamic>> _generateScenesFromText(String text) {
    final sentences = text.split(RegExp(r'[。！？\.\!\?]')).where((s) => s.trim().isNotEmpty).toList();
    final scenes = <Map<String, dynamic>>[];
    for (var i = 0; i < sentences.length && i < 10; i++) {
      scenes.add({
        'scene_index': i, 'text': sentences[i].trim(),
        'duration_seconds': 5, 'visual_prompt': sentences[i].trim(),
      });
    }
    return scenes;
  }

  List<SubtitleEntry> _generateMockAsrEntries() {
    return [
      SubtitleEntry(index: 1, startTime: Duration(seconds: 0), endTime: Duration(seconds: 3), text: '\u6B22\u8FCE\u6536\u770B\u672C\u89C6\u9891'),
      SubtitleEntry(index: 2, startTime: Duration(seconds: 3), endTime: Duration(seconds: 8), text: '\u4ECA\u5929\u6211\u4EEC\u6765\u804A\u804A\u4E00\u4E2A\u6709\u8DA3\u7684\u8BDD\u9898'),
      SubtitleEntry(index: 3, startTime: Duration(seconds: 8), endTime: Duration(seconds: 15), text: '\u9996\u5148\u6211\u4EEC\u9700\u8981\u4E86\u89E3\u57FA\u672C\u6982\u5FF5'),
      SubtitleEntry(index: 4, startTime: Duration(seconds: 15), endTime: Duration(seconds: 25), text: '\u63A5\u4E0B\u6765\u662F\u5177\u4F53\u7684\u5B9E\u64CD\u6B65\u9AA4'),
      SubtitleEntry(index: 5, startTime: Duration(seconds: 25), endTime: Duration(seconds: 30), text: '\u611F\u8C22\u89C2\u770B\uFF0C\u8BB0\u5F97\u70B9\u8D5E\u5173\u6CE8'),
    ];
  }
}
