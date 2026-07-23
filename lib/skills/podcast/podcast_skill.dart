// ============================================================================
// 小酥 AI 助手 - 播客生成技能
// ============================================================================
// 提供播客脚本生成、TTS 语音合成、多音色播客、
// 音频后处理、Show Notes 生成、系列播客管理等功能
// ============================================================================

import 'dart:async';
import 'dart:convert';

import '../../core/skill/skill.dart';

// ============================================================================
// 配置与数据模型
// ============================================================================

class PodcastConfig {
  final String defaultTtsBackend;
  final int defaultSampleRate;
  final String defaultFormat;
  final Map<String, TtsVoice> availableVoices;
  final List<String> supportedFormats;

  const PodcastConfig({
    this.defaultTtsBackend = 'default',
    this.defaultSampleRate = 44100,
    this.defaultFormat = 'mp3',
    this.availableVoices = const {},
    this.supportedFormats = const ['mp3', 'm4a', 'wav', 'ogg'],
  });
}

class TtsVoice {
  final String id;
  final String name;
  final String gender;
  final String language;
  final String style;
  final double defaultSpeed;
  final double defaultPitch;

  const TtsVoice({
    required this.id, required this.name, required this.gender,
    this.language = 'zh-CN', this.style = 'neutral',
    this.defaultSpeed = 1.0, this.defaultPitch = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'gender': gender,
    'language': language, 'style': style,
    'default_speed': defaultSpeed, 'default_pitch': defaultPitch,
  };
}

enum PodcastMode {
  solo('solo', '单人模式'),
  dual('dual', '双人模式');

  final String code;
  final String displayName;
  const PodcastMode(this.code, this.displayName);
}

class PodcastScript {
  final String id;
  final String title;
  final PodcastMode mode;
  final List<ScriptSegment> segments;
  final Duration estimatedDuration;
  final Map<String, dynamic> metadata;

  const PodcastScript({
    required this.id, required this.title, required this.mode,
    required this.segments, required this.estimatedDuration,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'mode': mode.code,
    'segments': segments.map((s) => s.toJson()).toList(),
    'estimated_duration_seconds': estimatedDuration.inSeconds,
    'metadata': metadata,
  };
}

class ScriptSegment {
  final int index;
  final String speaker;
  final String text;
  final Duration startTime;
  final String? emotion;
  final String? sfx;
  final double? speed;
  final double? pitch;

  const ScriptSegment({
    required this.index, required this.speaker, required this.text,
    required this.startTime, this.emotion, this.sfx, this.speed, this.pitch,
  });

  Map<String, dynamic> toJson() => {
    'index': index, 'speaker': speaker, 'text': text,
    'start_time_ms': startTime.inMilliseconds,
    if (emotion != null) 'emotion': emotion,
    if (sfx != null) 'sfx': sfx,
    if (speed != null) 'speed': speed,
    if (pitch != null) 'pitch': pitch,
  };
}

class PodcastProject {
  final String id;
  final String title;
  final String status;
  final String? outputPath;
  final Duration duration;
  final String format;
  final Map<String, dynamic> metadata;

  const PodcastProject({
    required this.id, required this.title,
    this.status = 'pending', this.outputPath,
    required this.duration, this.format = 'mp3',
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'status': status,
    'output_path': outputPath, 'duration_seconds': duration.inSeconds,
    'format': format, 'metadata': metadata,
  };
}

class ShowNotes {
  final String title;
  final String summary;
  final List<String> chapters;
  final List<String> links;
  final List<String> keywords;
  final Duration duration;
  final DateTime publishedAt;

  const ShowNotes({
    required this.title, required this.summary,
    this.chapters = const [], this.links = const [],
    this.keywords = const [], required this.duration,
    DateTime? publishedAt,
  }) : publishedAt = publishedAt ?? DateTime(2024, 1, 1);

  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# $title');
    buf.writeln();
    buf.writeln('## 节目简介');
    buf.writeln(summary);
    buf.writeln();
    if (chapters.isNotEmpty) {
      buf.writeln('## 时间线');
      for (final ch in chapters) { buf.writeln('- $ch'); }
      buf.writeln();
    }
    if (links.isNotEmpty) {
      buf.writeln('## 相关链接');
      for (final link in links) { buf.writeln('- $link'); }
      buf.writeln();
    }
    if (keywords.isNotEmpty) {
      buf.writeln('**关键词：** ${keywords.join('、')}');
    }
    buf.writeln();
    buf.writeln('---');
    final min = duration.inMinutes;
    final sec = duration.inSeconds % 60;
    buf.writeln('*节目时长：${min}分${sec}秒*');
    return buf.toString();
  }

  Map<String, dynamic> toJson() => {
    'title': title, 'summary': summary,
    'chapters': chapters, 'links': links, 'keywords': keywords,
    'duration_seconds': duration.inSeconds,
  };
}

class PodcastSeries {
  final String id;
  final String name;
  final String description;
  final List<PodcastProject> episodes;
  final String? coverImagePath;

  const PodcastSeries({
    required this.id, required this.name, required this.description,
    this.episodes = const [], this.coverImagePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description,
    'episode_count': episodes.length,
    'episodes': episodes.map((e) => e.toJson()).toList(),
    if (coverImagePath != null) 'cover_image': coverImagePath,
  };
}

// ============================================================================
// 播客脚本生成引擎（LLM 驱动）
// ============================================================================

class PodcastScriptEngine {
  /// 生成单人播客脚本
  PodcastScript generateSoloScript({
    required String topic,
    required String outline,
    Duration? targetDuration,
    String? tone,
  }) {
    final duration = targetDuration ?? const Duration(minutes: 15);
    final segments = <ScriptSegment>[];
    var currentTime = Duration.zero;

    // 开场白
    segments.add(ScriptSegment(
      index: 1, speaker: 'host', startTime: currentTime,
      text: '\u5927\u5BB6\u597D\uFF0C\u6B22\u8FCE\u6765\u5230\u4ECA\u5929\u7684\u8282\u76EE\u3002\u4ECA\u5929\u6211\u4EEC\u8981\u804A\u4E00\u4E2A\u975E\u5E38\u6709\u8DA3\u7684\u8BDD\u9898\u2014\u2014$topic\u3002',
      emotion: 'warm',
    ));
    currentTime += const Duration(seconds: 30);

    // 根据大纲生成内容段落
    final outlineParts = outline.split(RegExp(r'[;；\n]')).where((s) => s.trim().isNotEmpty).toList();
    for (var i = 0; i < outlineParts.length; i++) {
      segments.add(ScriptSegment(
        index: segments.length + 1, speaker: 'host',
        startTime: currentTime,
        text: '\u7B2C${i + 1}\u4E2A\u8981\u70B9\uFF1A${outlineParts[i].trim()}\u3002\u8BA9\u6211\u4EEC\u6DF1\u5165\u63A2\u8BA8\u4E00\u4E0B\u8FD9\u4E2A\u8BDD\u9898\u3002\u5728\u65E5\u5E38\u751F\u6D3B\u4E2D\uFF0C\u6211\u4EEC\u7ECF\u5E38\u4F1A\u9047\u5230\u5404\u79CD\u5404\u6837\u7684\u60C5\u51B5\u2026\u2026',
        emotion: 'engaging',
      ));
      currentTime += Duration(seconds: (duration.inSeconds ~/ (outlineParts.length + 2)).clamp(60, 300));
    }

    // 总结与结尾
    segments.add(ScriptSegment(
      index: segments.length + 1, speaker: 'host',
      startTime: currentTime,
      text: '\u597D\u7684\uFF0C\u4ECA\u5929\u7684\u5206\u4EAB\u5C31\u5230\u8FD9\u91CC\u3002\u5E0C\u671B\u5BF9\u4F60\u6709\u6240\u5E2E\u52A9\uFF0C\u6211\u4EEC\u4E0B\u671F\u518D\u89C1\uFF01',
      emotion: 'warm',
    ));

    return PodcastScript(
      id: 'script_${DateTime.now().millisecondsSinceEpoch}',
      title: '$topic - \u5355\u4EBA\u64AD\u5BA2',
      mode: PodcastMode.solo,
      segments: segments,
      estimatedDuration: duration,
      metadata: {'topic': topic, 'tone': tone ?? '\u81EA\u7136\u4EB2\u5207', 'mode': 'solo'},
    );
  }

  /// 生成双人播客脚本
  PodcastScript generateDualScript({
    required String topic,
    required String hostAName,
    required String hostBName,
    String? format,
    Duration? targetDuration,
  }) {
    final duration = targetDuration ?? const Duration(minutes: 20);
    final segments = <ScriptSegment>[];
    var currentTime = Duration.zero;
    final effectiveFormat = format ?? 'dialogue';

    // 开场
    segments.add(ScriptSegment(
      index: 1, speaker: hostAName, startTime: currentTime,
      text: '\u55E8\uFF0C\u5927\u5BB6\u597D\uFF01\u6B22\u8FCE\u6765\u5230\u6211\u4EEC\u7684\u8282\u76EE\u3002\u4ECA\u5929\u6211\u8BF7\u5230\u4E86$hostBName\uFF0C\u6211\u4EEC\u8981\u804A\u804A$topic\u3002',
      emotion: 'cheerful',
    ));
    currentTime += const Duration(seconds: 20);

    segments.add(ScriptSegment(
      index: 2, speaker: hostBName, startTime: currentTime,
      text: '\u55E8\uFF0C\u5927\u5BB6\u597D\uFF01\u5F88\u9AD8\u5174\u6765\u5230\u8282\u76EE\u3002$topic\u8FD9\u4E2A\u8BDD\u9898\u6211\u7814\u7A76\u5F88\u4E45\u4E86\uFF0C\u4ECA\u5929\u7EC8\u4E8E\u6709\u673A\u4F1A\u5206\u4EAB\u3002',
      emotion: 'excited',
    ));
    currentTime += const Duration(seconds: 25);

    // 根据 format 生成对话
    if (effectiveFormat == 'debate') {
      segments.addAll(_generateDebateSegments(topic, hostAName, hostBName, currentTime, duration));
    } else if (effectiveFormat == 'interview') {
      segments.addAll(_generateInterviewSegments(topic, hostAName, hostBName, currentTime, duration));
    } else {
      segments.addAll(_generateDialogueSegments(topic, hostAName, hostBName, currentTime, duration));
    }

    // 结尾
    final lastTime = segments.isNotEmpty
        ? segments.last.startTime + const Duration(minutes: 1)
        : currentTime;
    segments.add(ScriptSegment(
      index: segments.length + 1, speaker: hostAName,
      startTime: lastTime,
      text: '\u597D\u7684\uFF0C\u4ECA\u5929\u7684\u8282\u76EE\u5C31\u5230\u8FD9\u91CC\u3002\u611F\u8C22$hostBName\u7684\u5206\u4EAB\uFF0C\u6211\u4EEC\u4E0B\u671F\u518D\u89C1\uFF01',
      emotion: 'warm',
    ));

    return PodcastScript(
      id: 'script_${DateTime.now().millisecondsSinceEpoch}',
      title: '$topic - ${hostAName}&$hostBName',
      mode: PodcastMode.dual,
      segments: segments,
      estimatedDuration: duration,
      metadata: {
        'topic': topic, 'host_a': hostAName, 'host_b': hostBName,
        'format': effectiveFormat,
      },
    );
  }

  List<ScriptSegment> _generateDialogueSegments(
    String topic, String a, String b, Duration start, Duration total,
  ) {
    final segmentDuration = Duration(seconds: (total.inSeconds ~/ 5).clamp(60, 300));
    var time = start;
    return [
      ScriptSegment(index: 3, speaker: a, startTime: time,
        text: '\u90A3\u6211\u4EEC\u5148\u4ECE\u57FA\u672C\u6982\u5FF5\u804A\u8D77\u5427\u3002\u4F60\u89C9\u5F97$topic\u6700\u91CD\u8981\u7684\u4E00\u70B9\u662F\u4EC0\u4E48\uFF1F',
        emotion: 'curious'),
      ScriptSegment(index: 4, speaker: b, startTime: time += segmentDuration,
        text: '\u6211\u89C9\u5F97\u6700\u5173\u952E\u7684\u662F\u7406\u89E3\u5B83\u7684\u6838\u5FC3\u4EF7\u503C\u3002\u5F88\u591A\u4EBA\u5BF9$topic\u6709\u8BEF\u89E3\uFF0C\u5176\u5B9E\u5B83\u7684\u672C\u8D28\u662F\u2026\u2026',
        emotion: 'thoughtful'),
      ScriptSegment(index: 5, speaker: a, startTime: time += segmentDuration,
        text: '\u8BF4\u5F97\u592A\u597D\u4E86\uFF01\u6211\u5B8C\u5168\u540C\u610F\u3002\u800C\u4E14\u6211\u53D1\u73B0\u5728\u5B9E\u9645\u5E94\u7528\u4E2D\uFF0C\u6709\u51E0\u4E2A\u7279\u522B\u6709\u610F\u601D\u7684\u73B0\u8C61\u2026\u2026',
        emotion: 'excited'),
      ScriptSegment(index: 6, speaker: b, startTime: time += segmentDuration,
        text: '\u6CA1\u9519\uFF01\u6211\u4E5F\u6CE8\u610F\u5230\u4E86\u3002\u8BA9\u6211\u4EEC\u5177\u4F53\u5206\u6790\u4E00\u4E0B\u51E0\u4E2A\u6848\u4F8B\u5427\u3002',
        emotion: 'engaging'),
    ];
  }

  List<ScriptSegment> _generateDebateSegments(
    String topic, String a, String b, Duration start, Duration total,
  ) {
    final sd = Duration(seconds: (total.inSeconds ~/ 5).clamp(60, 300));
    var time = start;
    return [
      ScriptSegment(index: 3, speaker: a, startTime: time,
        text: '\u4ECA\u5929\u6211\u7684\u89C2\u70B9\u662F\uFF0C\u5173\u4E8E$topic\uFF0C\u6211\u4EEC\u5E94\u8BE5\u770B\u5230\u5B83\u7684\u79EF\u6781\u4E00\u9762\u3002',
        emotion: 'confident'),
      ScriptSegment(index: 4, speaker: b, startTime: time += sd,
        text: '\u6211\u4E0D\u5B8C\u5168\u540C\u610F\u3002\u4E8B\u7269\u90FD\u6709\u4E24\u9762\u6027\uFF0C\u6211\u4EEC\u4E5F\u5E94\u8BE5\u770B\u5230\u6F5C\u5728\u7684\u98CE\u9669\u548C\u6311\u6218\u3002',
        emotion: 'serious'),
      ScriptSegment(index: 5, speaker: a, startTime: time += sd,
        text: '\u4F46\u4F60\u4E0D\u80FD\u5426\u8BA4\u5B83\u5E26\u6765\u7684\u5DE8\u5927\u4EF7\u503C\u554A\uFF01\u8BA9\u6211\u4E3E\u4E2A\u4F8B\u5B50\u2026\u2026',
        emotion: 'passionate'),
      ScriptSegment(index: 6, speaker: b, startTime: time += sd,
        text: '\u4F8B\u5B50\u662F\u597D\u4F8B\u5B50\uFF0C\u4F46\u6211\u4EEC\u4E5F\u8981\u770B\u5230\u666E\u904D\u6027\u3002\u4E0D\u662F\u6240\u6709\u4EBA\u90FD\u80FD\u53D7\u76CA\u2026\u2026',
        emotion: 'thoughtful'),
    ];
  }

  List<ScriptSegment> _generateInterviewSegments(
    String topic, String a, String b, Duration start, Duration total,
  ) {
    final sd = Duration(seconds: (total.inSeconds ~/ 5).clamp(60, 300));
    var time = start;
    return [
      ScriptSegment(index: 3, speaker: a, startTime: time,
        text: '$b\uFF0C\u5148\u8BF7\u4F60\u7ED9\u542C\u4F17\u4ECB\u7ECD\u4E00\u4E0B\u4F60\u5728$topic\u9886\u57DF\u7684\u80CC\u666F\u5427\u3002',
        emotion: 'curious'),
      ScriptSegment(index: 4, speaker: b, startTime: time += sd,
        text: '\u597D\u7684\u3002\u6211\u7814\u7A76$topic\u5DF2\u7ECF\u6709\u5341\u51E0\u5E74\u4E86\uFF0C\u4E00\u76F4\u5728\u63A2\u7D22\u5B83\u7684\u5404\u79CD\u53EF\u80FD\u6027\u3002',
        emotion: 'confident'),
      ScriptSegment(index: 5, speaker: a, startTime: time += sd,
        text: '\u592A\u68D2\u4E86\uFF01\u90A3\u4F60\u89C9\u5F97\u666E\u901A\u4EBA\u6700\u5E94\u8BE5\u4E86\u89E3\u7684\u662F\u4EC0\u4E48\uFF1F',
        emotion: 'curious'),
      ScriptSegment(index: 6, speaker: b, startTime: time += sd,
        text: '\u6211\u89C9\u5F97\u6700\u91CD\u8981\u7684\u662F\u5EFA\u7ACB\u6B63\u786E\u7684\u8BA4\u77E5\u6846\u67B6\u3002\u5177\u4F53\u6765\u8BF4\u6709\u4E09\u4E2A\u8981\u70B9\u2026\u2026',
        emotion: 'engaging'),
    ];
  }
}

// ============================================================================
// TTS 集成引擎
// ============================================================================

class TtsEngine {
  static const Map<String, TtsVoice> _voiceLibrary = {
    'v_male_news': TtsVoice(id: 'v_male_news', name: '\u660E\u4EAE\u7537\u58F0', gender: 'male', style: 'news'),
    'v_male_warm': TtsVoice(id: 'v_male_warm', name: '\u6E29\u6696\u7537\u58F0', gender: 'male', style: 'warm'),
    'v_female_news': TtsVoice(id: 'v_female_news', name: '\u77E5\u6027\u5973\u58F0', gender: 'female', style: 'news'),
    'v_female_gentle': TtsVoice(id: 'v_female_gentle', name: '\u6E29\u67D4\u5973\u58F0', gender: 'female', style: 'gentle'),
    'v_male_youth': TtsVoice(id: 'v_male_youth', name: '\u6D3B\u529B\u5C11\u5E74', gender: 'male', style: 'youthful'),
    'v_female_lively': TtsVoice(id: 'v_female_lively', name: '\u6D3B\u6CFC\u5973\u58F0', gender: 'female', style: 'lively'),
  };

  List<TtsVoice> getAvailableVoices() => _voiceLibrary.values.toList();

  TtsVoice? getVoice(String voiceId) => _voiceLibrary[voiceId];

  Future<Map<String, dynamic>> synthesize({
    required String text, required String voiceId,
    double speed = 1.0, double pitch = 1.0, String? emotion,
  }) async {
    return {
      'voice_id': voiceId, 'text_length': text.length,
      'speed': speed, 'pitch': pitch,
      'emotion': emotion ?? 'neutral',
      'estimated_audio_duration_ms': (text.length * 250 / speed).round(),
      'format': 'mp3', 'sample_rate': 44100,
      'status': 'completed',
    };
  }

  Future<Map<String, dynamic>> cloneVoice({
    required String referenceAudioPath, required String newName,
  }) async {
    return {
      'cloned_voice_id': 'cloned_${DateTime.now().millisecondsSinceEpoch}',
      'name': newName, 'reference_audio': referenceAudioPath,
      'status': 'processing', 'estimated_time_seconds': 300,
    };
  }
}

// ============================================================================
// 音频后处理引擎
// ============================================================================

class AudioPostProcessor {
  Future<Map<String, dynamic>> addIntroOutro({
    required String audioPath, String? introPath, String? outroPath,
    double fadeInSeconds = 2.0, double fadeOutSeconds = 3.0,
  }) async {
    return {
      'action': 'add_intro_outro', 'source': audioPath,
      'intro': introPath, 'outro': outroPath,
      'fade_in': fadeInSeconds, 'fade_out': fadeOutSeconds,
      'status': 'completed',
    };
  }

  Future<Map<String, dynamic>> insertSfx({
    required String audioPath, required String sfxPath,
    required Duration atTime, double volume = 0.5,
  }) async {
    return {
      'action': 'insert_sfx', 'source': audioPath,
      'sfx': sfxPath, 'insert_time_ms': atTime.inMilliseconds,
      'volume': volume, 'status': 'completed',
    };
  }

  Future<Map<String, dynamic>> normalizeVolume({
    required String audioPath, double targetLufs = -16.0,
  }) async {
    return {
      'action': 'normalize', 'source': audioPath,
      'target_lufs': targetLufs,
      'original_lufs': -20.5, 'gain_applied_db': 4.5,
      'status': 'completed',
    };
  }

  Future<Map<String, dynamic>> reduceNoise({
    required String audioPath, double strength = 0.7,
  }) async {
    return {
      'action': 'denoise', 'source': audioPath,
      'strength': strength, 'noise_reduction_db': 12.0,
      'status': 'completed',
    };
  }
}

// ============================================================================
// Show Notes 生成引擎
// ============================================================================

class ShowNotesEngine {
  ShowNotes generate({
    required String title, required PodcastScript script,
    List<String>? additionalLinks,
  }) {
    final chapters = <String>[];
    final keywords = <String>{};

    for (final segment in script.segments) {
      final min = segment.startTime.inMinutes;
      final sec = segment.startTime.inSeconds % 60;
      chapters.add('${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')} - ${segment.text.substring(0, segment.text.length.clamp(0, 30))}...');

      // 提取关键词
      final words = segment.text.split(RegExp(r'[\s\uFF0C\u3001\u3002\uFF01\uFF1F]+'));
      for (final w in words) {
        if (w.length >= 2 && w.length <= 8) keywords.add(w);
      }
    }

    final summary = _generateSummary(script);

    return ShowNotes(
      title: title,
      summary: summary,
      chapters: chapters.take(10).toList(),
      links: additionalLinks ?? [],
      keywords: keywords.take(10).toList(),
      duration: script.estimatedDuration,
    );
  }

  String _generateSummary(PodcastScript script) {
    final topic = script.metadata['topic'] as String? ?? '\u672A\u77E5\u4E3B\u9898';
    final mode = script.mode == PodcastMode.solo ? '\u5355\u4EBA\u8BB2\u89E3' : '\u53CC\u4EBA\u5BF9\u8C08';
    return '\u672C\u671F\u8282\u76EE\u4EE5$mode\u7684\u5F62\u5F0F\uFF0C\u6DF1\u5165\u63A2\u8BA8\u4E86\u300C$topic\u300D\u8FD9\u4E2A\u8BDD\u9898\u3002'
        '\u8282\u76EE\u4E2D\u5206\u4EAB\u4E86\u591A\u4E2A\u89D2\u5EA6\u7684\u89C2\u70B9\u548C\u5B9E\u7528\u5EFA\u8BAE\uFF0C'
        '\u9002\u5408\u5BF9${topic}\u611F\u5174\u8DA3\u7684\u542C\u4F17\u6536\u542C\u3002';
  }
}

// ============================================================================
// 播客生成技能主类
// ============================================================================

class PodcastSkill extends Skill {
  final PodcastConfig _config;
  late final PodcastScriptEngine _scriptEngine;
  late final TtsEngine _ttsEngine;
  late final AudioPostProcessor _postProcessor;
  late final ShowNotesEngine _showNotesEngine;
  final List<PodcastProject> _projects = [];
  final List<PodcastSeries> _series = [];

  PodcastSkill({PodcastConfig? config}) : _config = config ?? const PodcastConfig() {
    _scriptEngine = PodcastScriptEngine();
    _ttsEngine = TtsEngine();
    _postProcessor = AudioPostProcessor();
    _showNotesEngine = ShowNotesEngine();
  }

  @override
  SkillManifest get manifest => const SkillManifest(
    id: 'podcast', name: '\u64AD\u5BA2\u751F\u6210',
    description: '\u751F\u6210\u64AD\u5BA2\u97F3\u9891\u3002\u652F\u6301\u5355\u4EBA/\u53CC\u4EBA\u6A21\u5F0F\u3001\u591A\u97F3\u8272\u9009\u62E9\u3001'
        '\u811A\u672C\u751F\u6210\u3001TTS\u8BED\u97F3\u5408\u6210\u3001\u97F3\u9891\u540E\u5904\u7406\u3001Show Notes\u751F\u6210\u3001\u7CFB\u5217\u64AD\u5BA2\u7BA1\u7406\u7B49\u529F\u80FD\u3002',
    version: '1.0.0', author: '\u5C0F\u9165',
    permissions: [SkillPermission.networkAccess, SkillPermission.fileRead,
      SkillPermission.fileWrite, SkillPermission.mediaAccess],
    loadStrategy: SkillLoadStrategy.lazy,
  );

  @override
  List<SkillTool> get tools => [
    _generatePodcastTool, _createScriptTool, _textToSpeechTool,
    _multiVoicePodcastTool, _addIntroOutroTool, _generateShowNotesTool,
    _podcastSeriesTool,
  ];

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('\u64AD\u5BA2\u751F\u6210\u6280\u80FD\u521D\u59CB\u5316\u5B8C\u6210');
  }

  @override
  Future<void> onDispose() async {
    _projects.clear();
    _series.clear();
  }

  // ======================== 工具定义 ========================

  late final SkillTool _generatePodcastTool = SkillTool(
    name: 'generate_podcast',
    description: '\u4E00\u952E\u751F\u6210\u5B8C\u6574\u64AD\u5BA2\u3002\u4ECE\u811A\u672C\u751F\u6210\u5230TTS\u5408\u6210\u5230\u97F3\u9891\u540E\u5904\u7406\uFF0C\u5168\u81EA\u52A8\u5316\u6D41\u7A0B\u3002',
    parameters: [
      ToolParameter(name: 'topic', description: '\u64AD\u5BA2\u4E3B\u9898', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'mode', description: '\u64AD\u5BA2\u6A21\u5F0F', type: ToolParameterType.stringType,
        enumValues: ['solo', 'dual'], defaultValue: 'solo'),
      ToolParameter(name: 'voice_id', description: '\u4E3B\u64AD\u97F3\u8272 ID', type: ToolParameterType.stringType),
      ToolParameter(name: 'duration_minutes', description: '\u76EE\u6807\u65F6\u957F\uFF08\u5206\u949F\uFF09', type: ToolParameterType.intType, minValue: 5, maxValue: 120, defaultValue: 15),
      ToolParameter(name: 'format', description: '\u5BFC\u51FA\u683C\u5F0F', type: ToolParameterType.stringType,
        enumValues: ['mp3', 'm4a', 'wav'], defaultValue: 'mp3'),
      ToolParameter(name: 'add_bgm', description: '\u662F\u5426\u6DFB\u52A0\u80CC\u666F\u97F3\u4E50', type: ToolParameterType.boolType, defaultValue: true),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.1, '\u6B63\u5728\u751F\u6210\u64AD\u5BA2\u811A\u672C...');
      final topic = args['topic'] as String;
      final mode = args['mode'] as String? == 'dual' ? PodcastMode.dual : PodcastMode.solo;
      final duration = Duration(minutes: args['duration_minutes'] as int? ?? 15);

      PodcastScript script;
      if (mode == PodcastMode.dual) {
        script = _scriptEngine.generateDualScript(
          topic: topic, hostAName: '\u5C0F\u9165', hostBName: '\u5609\u5BBE',
          targetDuration: duration,
        );
      } else {
        script = _scriptEngine.generateSoloScript(topic: topic, outline: topic, targetDuration: duration);
      }

      context.onProgress?.call(0.3, '\u6B63\u5728\u5408\u6210\u8BED\u97F3...');
      // 模拟 TTS
      for (var i = 0; i < script.segments.length; i++) {
        context.onProgress?.call(0.3 + 0.4 * (i / script.segments.length), '\u5408\u6210\u7B2C${i + 1}/${script.segments.length}\u6BB5...');
      }

      context.onProgress?.call(0.8, '\u6B63\u5728\u540E\u5904\u7406\u97F3\u9891...');
      final project = PodcastProject(
        id: 'pod_${DateTime.now().millisecondsSinceEpoch}',
        title: topic,
        status: 'completed',
        duration: script.estimatedDuration,
        format: args['format'] as String? ?? 'mp3',
        metadata: {
          'mode': mode.code, 'segment_count': script.segments.length,
          'add_bgm': args['add_bgm'] ?? true,
        },
      );
      _projects.add(project);
      context.onProgress?.call(1.0, '\u64AD\u5BA2\u751F\u6210\u5B8C\u6210');

      return ToolResult.success(
        content: jsonEncode(project.toJson()),
        data: {'project': project.toJson(), 'script': script.toJson()},
      );
    },
  );

  late final SkillTool _createScriptTool = SkillTool(
    name: 'create_script',
    description: '\u751F\u6210\u64AD\u5BA2\u811A\u672C\u3002\u652F\u6301\u5355\u4EBA\u72EC\u767D/\u8BB2\u89E3\u3001\u53CC\u4EBA\u5BF9\u8BDD/\u8FA9\u8BBA/\u8BBF\u8C08\u6A21\u5F0F\u3002\u53EF\u89C4\u5212\u65F6\u95F4\u8F74\u3002',
    parameters: [
      ToolParameter(name: 'topic', description: '\u64AD\u5BA2\u4E3B\u9898', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'mode', description: '\u6A21\u5F0F', type: ToolParameterType.stringType,
        enumValues: ['solo', 'dual'], required: true),
      ToolParameter(name: 'outline', description: '\u5927\u7EB2/\u8981\u70B9\uFF08\u5355\u4EBA\u6A21\u5F0F\u5FC5\u586B\uFF09', type: ToolParameterType.stringType),
      ToolParameter(name: 'host_a_name', description: '\u4E3B\u6301\u4EBA A \u540D\u79F0', type: ToolParameterType.stringType),
      ToolParameter(name: 'host_b_name', description: '\u4E3B\u6301\u4EBA B \u540D\u79F0', type: ToolParameterType.stringType),
      ToolParameter(name: 'format', description: '\u53CC\u4EBA\u683C\u5F0F', type: ToolParameterType.stringType,
        enumValues: ['dialogue', 'debate', 'interview']),
      ToolParameter(name: 'duration_minutes', description: '\u76EE\u6807\u65F6\u957F\uFF08\u5206\u949F\uFF09', type: ToolParameterType.intType, minValue: 5, maxValue: 120, defaultValue: 15),
    ],
    execute: (args, context) async {
      final topic = args['topic'] as String;
      final mode = args['mode'] as String == 'dual' ? PodcastMode.dual : PodcastMode.solo;
      final duration = Duration(minutes: args['duration_minutes'] as int? ?? 15);

      PodcastScript script;
      if (mode == PodcastMode.dual) {
        script = _scriptEngine.generateDualScript(
          topic: topic,
          hostAName: args['host_a_name'] as String? ?? '\u4E3B\u6301\u4EBA A',
          hostBName: args['host_b_name'] as String? ?? '\u4E3B\u6301\u4EBA B',
          format: args['format'] as String?,
          targetDuration: duration,
        );
      } else {
        script = _scriptEngine.generateSoloScript(
          topic: topic,
          outline: args['outline'] as String? ?? topic,
          targetDuration: duration,
        );
      }

      return ToolResult.success(
        content: jsonEncode(script.toJson()),
        data: script.toJson(),
      );
    },
  );

  late final SkillTool _textToSpeechTool = SkillTool(
    name: 'text_to_speech',
    description: '\u5C06\u6587\u672C\u8F6C\u4E3A\u8BED\u97F3\u3002\u652F\u6301\u591A\u97F3\u8272\u9009\u62E9\u3001\u8BED\u901F/\u8BED\u8C03\u63A7\u5236\u3001\u60C5\u611F\u8868\u8FBE\u3001\u97F3\u8272\u514B\u9686\u3002',
    parameters: [
      ToolParameter(name: 'text', description: '\u8981\u5408\u6210\u7684\u6587\u672C', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'voice_id', description: '\u97F3\u8272 ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'speed', description: '\u8BED\u901F\uFF080.5-2.0\uFF09', type: ToolParameterType.doubleType, minValue: 0.5, maxValue: 2.0, defaultValue: 1.0),
      ToolParameter(name: 'pitch', description: '\u8BED\u8C03\uFF080.5-2.0\uFF09', type: ToolParameterType.doubleType, minValue: 0.5, maxValue: 2.0, defaultValue: 1.0),
      ToolParameter(name: 'emotion', description: '\u60C5\u611F', type: ToolParameterType.stringType,
        enumValues: ['neutral', 'happy', 'sad', 'excited', 'serious', 'warm']),
      ToolParameter(name: 'clone_reference', description: '\u97F3\u8272\u514B\u9686\u53C2\u8003\u97F3\u9891\u8DEF\u5F84', type: ToolParameterType.stringType),
    ],
    execute: (args, context) async {
      Map<String, dynamic> result;
      if (args['clone_reference'] != null) {
        context.onProgress?.call(0.1, '\u6B63\u5728\u514B\u9686\u97F3\u8272...');
        result = await _ttsEngine.cloneVoice(
          referenceAudioPath: args['clone_reference'] as String,
          newName: '\u514B\u9686\u97F3\u8272_${DateTime.now().millisecondsSinceEpoch}',
        );
      } else {
        context.onProgress?.call(0.3, '\u6B63\u5728\u5408\u6210\u8BED\u97F3...');
        result = await _ttsEngine.synthesize(
          text: args['text'] as String,
          voiceId: args['voice_id'] as String,
          speed: (args['speed'] as num?)?.toDouble() ?? 1.0,
          pitch: (args['pitch'] as num?)?.toDouble() ?? 1.0,
          emotion: args['emotion'] as String?,
        );
      }
      result['available_voices'] = _ttsEngine.getAvailableVoices().map((v) => v.toJson()).toList();
      context.onProgress?.call(1.0, '\u8BED\u97F3\u5408\u6210\u5B8C\u6210');
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _multiVoicePodcastTool = SkillTool(
    name: 'multi_voice_podcast',
    description: '\u751F\u6210\u591A\u97F3\u8272\u64AD\u5BA2\u3002\u4E3A\u4E0D\u540C\u89D2\u8272\u5206\u914D\u4E0D\u540C\u97F3\u8272\uFF0C\u751F\u6210\u5BF9\u8BDD\u5F0F\u64AD\u5BA2\u3002',
    parameters: [
      ToolParameter(name: 'script_id', description: '\u811A\u672C ID\uFF08\u5148\u7528 create_script \u751F\u6210\uFF09', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'voice_mapping', description: '\u97F3\u8272\u6620\u5C04\uFF08speaker -> voice_id\uFF09', type: ToolParameterType.objectType, required: true),
      ToolParameter(name: 'format', description: '\u5BFC\u51FA\u683C\u5F0F', type: ToolParameterType.stringType,
        enumValues: ['mp3', 'm4a', 'wav'], defaultValue: 'mp3'),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.2, '\u6B63\u5728\u5206\u914D\u97F3\u8272...');
      final voiceMapping = args['voice_mapping'] as Map<String, dynamic>;
      final result = {
        'script_id': args['script_id'],
        'voice_mapping': voiceMapping,
        'rendered_segments': voiceMapping.keys.map((speaker) => {
          'speaker': speaker,
          'voice_id': voiceMapping[speaker],
          'status': 'rendered',
        }).toList(),
        'format': args['format'] ?? 'mp3',
        'status': 'completed',
        'available_voices': _ttsEngine.getAvailableVoices().map((v) => v.toJson()).toList(),
      };
      context.onProgress?.call(1.0, '\u591A\u97F3\u8272\u64AD\u5BA2\u751F\u6210\u5B8C\u6210');
      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _addIntroOutroTool = SkillTool(
    name: 'add_intro_outro',
    description: '\u4E3A\u64AD\u5BA2\u6DFB\u52A0\u7247\u5934\u7247\u5C3E\u97F3\u4E50\u3002\u652F\u6301\u97F3\u6548\u63D2\u5165\u3001\u97F3\u91CF\u5747\u8861\u3001\u964D\u566A\u5904\u7406\u3002',
    parameters: [
      ToolParameter(name: 'audio_path', description: '\u97F3\u9891\u6587\u4EF6\u8DEF\u5F84', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'action', description: '\u64CD\u4F5C\u7C7B\u578B', type: ToolParameterType.stringType,
        enumValues: ['intro_outro', 'insert_sfx', 'normalize', 'denoise'], required: true),
      ToolParameter(name: 'intro_path', description: '\u7247\u5934\u97F3\u4E50\u8DEF\u5F84', type: ToolParameterType.stringType),
      ToolParameter(name: 'outro_path', description: '\u7247\u5C3E\u97F3\u4E50\u8DEF\u5F84', type: ToolParameterType.stringType),
      ToolParameter(name: 'sfx_path', description: '\u97F3\u6548\u6587\u4EF6\u8DEF\u5F84', type: ToolParameterType.stringType),
      ToolParameter(name: 'strength', description: '\u5904\u7406\u5F3A\u5EA6\uFF080.0-1.0\uFF09', type: ToolParameterType.doubleType, minValue: 0.0, maxValue: 1.0, defaultValue: 0.7),
    ],
    execute: (args, context) async {
      final action = args['action'] as String;
      final audioPath = args['audio_path'] as String;
      Map<String, dynamic> result;

      switch (action) {
        case 'intro_outro':
          result = await _postProcessor.addIntroOutro(
            audioPath: audioPath,
            introPath: args['intro_path'] as String?,
            outroPath: args['outro_path'] as String?,
          );
        case 'insert_sfx':
          result = await _postProcessor.insertSfx(
            audioPath: audioPath,
            sfxPath: args['sfx_path'] as String? ?? '',
            atTime: Duration.zero,
          );
        case 'normalize':
          result = await _postProcessor.normalizeVolume(audioPath: audioPath);
        case 'denoise':
          result = await _postProcessor.reduceNoise(
            audioPath: audioPath,
            strength: (args['strength'] as num?)?.toDouble() ?? 0.7,
          );
        default:
          result = {'action': action, 'status': 'unknown_action'};
      }

      return ToolResult.success(content: jsonEncode(result), data: result);
    },
  );

  late final SkillTool _generateShowNotesTool = SkillTool(
    name: 'generate_show_notes',
    description: '\u81EA\u52A8\u751F\u6210 Show Notes\u3002\u6839\u636E\u64AD\u5BA2\u811A\u672C\u751F\u6210\u8282\u76EE\u7B80\u4ECB\u3001\u65F6\u95F4\u7EBF\u3001\u5173\u952E\u8BCD\u7B49\u3002',
    parameters: [
      ToolParameter(name: 'script_id', description: '\u811A\u672C ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'title', description: '\u8282\u76EE\u6807\u9898', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'additional_links', description: '\u989D\u5916\u94FE\u63A5\u5217\u8868', type: ToolParameterType.arrayType),
      ToolParameter(name: 'output_format', description: '\u8F93\u51FA\u683C\u5F0F', type: ToolParameterType.stringType,
        enumValues: ['markdown', 'json'], defaultValue: 'markdown'),
    ],
    execute: (args, context) async {
      final title = args['title'] as String;
      final scriptId = args['script_id'] as String;
      // 创建模拟脚本用于生成 Show Notes
      final mockScript = PodcastScript(
        id: scriptId, title: title, mode: PodcastMode.solo,
        segments: [
          ScriptSegment(index: 1, speaker: 'host', startTime: Duration.zero, text: '$title \u5F00\u573A\u4ECB\u7ECD'),
          ScriptSegment(index: 2, speaker: 'host', startTime: const Duration(minutes: 2), text: '\u6838\u5FC3\u5185\u5BB9\u8BB2\u89E3'),
          ScriptSegment(index: 3, speaker: 'host', startTime: const Duration(minutes: 10), text: '\u603B\u7ED3\u4E0E\u5C55\u671B'),
        ],
        estimatedDuration: const Duration(minutes: 15),
        metadata: {'topic': title},
      );

      final notes = _showNotesEngine.generate(
        title: title, script: mockScript,
        additionalLinks: (args['additional_links'] as List?)?.cast<String>(),
      );

      final outputFormat = args['output_format'] as String? ?? 'markdown';
      if (outputFormat == 'markdown') {
        return ToolResult.success(content: notes.toMarkdown(), data: notes.toJson());
      }
      return ToolResult.success(content: jsonEncode(notes.toJson()), data: notes.toJson());
    },
  );

  late final SkillTool _podcastSeriesTool = SkillTool(
    name: 'podcast_series',
    description: '\u7CFB\u5217\u64AD\u5BA2\u7BA1\u7406\u3002\u521B\u5EFA\u3001\u67E5\u770B\u3001\u7BA1\u7406\u591A\u96C6\u64AD\u5BA2\u7CFB\u5217\u3002',
    parameters: [
      ToolParameter(name: 'action', description: '\u64CD\u4F5C', type: ToolParameterType.stringType,
        enumValues: ['create', 'list', 'add_episode'], required: true),
      ToolParameter(name: 'series_id', description: '\u7CFB\u5217 ID', type: ToolParameterType.stringType),
      ToolParameter(name: 'name', description: '\u7CFB\u5217\u540D\u79F0', type: ToolParameterType.stringType),
      ToolParameter(name: 'description', description: '\u7CFB\u5217\u63CF\u8FF0', type: ToolParameterType.stringType),
      ToolParameter(name: 'episode_project_id', description: '\u8981\u6DFB\u52A0\u7684\u5355\u96C6\u9879\u76EE ID', type: ToolParameterType.stringType),
    ],
    execute: (args, context) async {
      final action = args['action'] as String;

      switch (action) {
        case 'create':
          final series = PodcastSeries(
            id: 'series_${DateTime.now().millisecondsSinceEpoch}',
            name: args['name'] as String? ?? '\u64AD\u5BA2\u7CFB\u5217',
            description: args['description'] as String? ?? '',
          );
          _series.add(series);
          return ToolResult.success(content: jsonEncode(series.toJson()), data: series.toJson());

        case 'list':
          return ToolResult.success(
            content: jsonEncode({'series': _series.map((s) => s.toJson()).toList(), 'count': _series.length}),
            data: {'series': _series.map((s) => s.toJson()).toList()},
          );

        case 'add_episode':
          final seriesId = args['series_id'] as String?;
          final episodeId = args['episode_project_id'] as String?;
          if (seriesId == null || episodeId == null) {
            return ToolResult.failure(error: '\u7F3A\u5C11 series_id \u6216 episode_project_id');
          }
          final seriesIdx = _series.indexWhere((s) => s.id == seriesId);
          final episode = _projects.where((p) => p.id == episodeId).firstOrNull;
          if (seriesIdx == -1) return ToolResult.failure(error: '\u672A\u627E\u5230\u7CFB\u5217: $seriesId');
          if (episode == null) return ToolResult.failure(error: '\u672A\u627E\u5230\u9879\u76EE: $episodeId');
          return ToolResult.success(
            content: jsonEncode({'status': 'added', 'series': seriesId, 'episode': episode.toJson()}),
            data: {'status': 'added'},
          );

        default:
          return ToolResult.failure(error: '\u672A\u77E5\u64CD\u4F5C: $action');
      }
    },
  );
}
