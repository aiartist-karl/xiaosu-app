// ============================================================================
// 小酥 AI 助手 - 社交媒体内容技能
// ============================================================================
// 提供小红书文案、公众号文章、抖音脚本、微博文案等多平台内容生成
// 支持内容日历、批量生成、违禁词预检等功能
// ============================================================================

import 'dart:async';
import 'dart:convert';

import '../../core/skill/skill.dart';

// ============================================================================
// 配置模型
// ============================================================================

/// 社交媒体技能配置
class SocialMediaConfig {
  final int xiaohongshuEmojiDensity;
  final int wechatArticleWordCount;
  final int douyinMaxDuration;
  final int weiboMaxChars;
  final List<String> forbiddenWords;
  final List<String> xhsTitleTemplates;
  final List<int> preferredPublishHours;

  const SocialMediaConfig({
    this.xiaohongshuEmojiDensity = 8,
    this.wechatArticleWordCount = 2000,
    this.douyinMaxDuration = 60,
    this.weiboMaxChars = 140,
    this.forbiddenWords = const [],
    this.xhsTitleTemplates = const [
      '\u9707\u60CA\uFF01{topic}\u7ADF\u7136\u53EF\u4EE5\u8FD9\u6837',
      '{number}\u4E2A{topic}\u5C0F\u6280\u5DE7\uFF0C\u7B2C{highlight}\u4E2A\u7EDD\u4E86',
      '\u540E\u6094\u6CA1\u65E9\u77E5\u9053\u7684{topic}\u79D8\u8BC0',
      '{topic}\u907F\u5751\u6307\u5357\uFF5C\u770B\u5B8C\u5C11\u8D70\u5F2F\u8DEF',
      '\u88AB{topic}\u60CA\u8273\u5230\u4E86\uFF01\u5FCD\u4E0D\u4F4F\u5206\u4EAB\u7ED9\u4F60\u4EEC',
      '\u59D0\u59B9\u4EEC\uFF01{topic}\u8FD9\u6837\u7528\u771F\u7684\u7EDD\u4E86',
      '{emotion}\uFF01{topic}\u7684\u6B63\u786E\u6253\u5F00\u65B9\u5F0F',
      '\u5929\u82B1\u677F\u7EA7\u522B\u7684{topic}\u63A8\u8350',
    ],
    this.preferredPublishHours = const [7, 12, 18, 21, 22],
  });
}

// ============================================================================
// 内容数据模型
// ============================================================================

enum SocialPlatform {
  xiaohongshu('xiaohongshu', '\u5C0F\u7EA2\u4E66'),
  wechat('wechat', '\u5FAE\u4FE1\u516C\u4F17\u53F7'),
  douyin('douyin', '\u6296\u97F3'),
  weibo('weibo', '\u5FAE\u535A');

  final String code;
  final String displayName;
  const SocialPlatform(this.code, this.displayName);
}

class GeneratedContent {
  final SocialPlatform platform;
  final String title;
  final String body;
  final List<String> hashtags;
  final Map<String, dynamic> metadata;

  const GeneratedContent({
    required this.platform,
    required this.title,
    required this.body,
    this.hashtags = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'platform': platform.code,
    'platform_name': platform.displayName,
    'title': title,
    'body': body,
    'hashtags': hashtags,
    'metadata': metadata,
  };
}

class CalendarEntry {
  final DateTime publishDate;
  final SocialPlatform platform;
  final String topic;
  final String contentType;
  final String status;
  final String? contentId;

  const CalendarEntry({
    required this.publishDate,
    required this.platform,
    required this.topic,
    required this.contentType,
    this.status = 'planned',
    this.contentId,
  });

  Map<String, dynamic> toJson() => {
    'publish_date': publishDate.toIso8601String(),
    'platform': platform.code,
    'topic': topic,
    'content_type': contentType,
    'status': status,
    if (contentId != null) 'content_id': contentId,
  };
}

class ComplianceResult {
  final bool passed;
  final List<ComplianceIssue> issues;
  final String summary;

  const ComplianceResult({
    required this.passed,
    this.issues = const [],
    this.summary = '',
  });

  Map<String, dynamic> toJson() => {
    'passed': passed,
    'issues': issues.map((i) => i.toJson()).toList(),
    'summary': summary,
  };
}

class ComplianceIssue {
  final String word;
  final String category;
  final String suggestion;
  final int position;

  const ComplianceIssue({
    required this.word,
    required this.category,
    required this.suggestion,
    this.position = 0,
  });

  Map<String, dynamic> toJson() => {
    'word': word,
    'category': category,
    'suggestion': suggestion,
    'position': position,
  };
}

class TrendingTopic {
  final String keyword;
  final String platform;
  final int heatIndex;
  final String category;
  final DateTime updatedAt;

  const TrendingTopic({
    required this.keyword,
    required this.platform,
    required this.heatIndex,
    this.category = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? const _DefaultDateTime();

  Map<String, dynamic> toJson() => {
    'keyword': keyword,
    'platform': platform,
    'heat_index': heatIndex,
    'category': category,
    'updated_at': updatedAt.toIso8601String(),
  };
}

class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #toIso8601String) return '';
    if (invocation.memberName == #toString) return '';
    return super.noSuchMethod(invocation);
  }
}

class SectionOutline {
  final String title;
  final String content;
  final String? quote;
  const SectionOutline({required this.title, required this.content, this.quote});
}

class ShotDescription {
  final int id;
  final int startTime;
  final int endTime;
  final String shotType;
  final String scene;
  final String dialogue;
  final String cameraMovement;
  final String notes;

  const ShotDescription({
    required this.id, required this.startTime, required this.endTime,
    required this.shotType, required this.scene, required this.dialogue,
    required this.cameraMovement, required this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'start_time': startTime, 'end_time': endTime,
    'shot_type': shotType, 'scene': scene, 'dialogue': dialogue,
    'camera_movement': cameraMovement, 'notes': notes,
  };
}

// ============================================================================
// 小红书文案生成引擎
// ============================================================================

class XiaohongshuEngine {
  final SocialMediaConfig _config;
  XiaohongshuEngine(this._config);

  String generateTitle(String topic, {String? emotion, int? number}) {
    final templates = _config.xhsTitleTemplates;
    final idx = topic.hashCode.abs() % templates.length;
    var title = templates[idx];
    title = title.replaceAll('{topic}', topic);
    title = title.replaceAll('{number}', (number ?? 5).toString());
    title = title.replaceAll('{highlight}', '3');
    title = title.replaceAll('{emotion}', emotion ?? '\u5929\u5450');
    return title;
  }

  String generateBody({
    required String topic,
    required String hook,
    required String painPoint,
    required String solution,
    required String cta,
    int emojiDensity = 0,
  }) {
    final density = emojiDensity > 0 ? emojiDensity : _config.xiaohongshuEmojiDensity;
    final buffer = StringBuffer();
    buffer.writeln(hook);
    buffer.writeln();
    buffer.writeln('${_emoji('pain')} $painPoint');
    buffer.writeln();
    buffer.writeln('${_emoji('solution')} \u89E3\u51B3\u65B9\u6848\uFF1A');
    buffer.writeln(solution);
    buffer.writeln();
    buffer.writeln('${_emoji('cta')} $cta');
    buffer.writeln();
    buffer.writeln('#$topic #\u5E72\u8D27\u5206\u4EAB #\u597D\u7269\u63A8\u8350');
    return _adjustEmojiDensity(buffer.toString(), density);
  }

  String _adjustEmojiDensity(String text, int targetDensity) {
    final charCount = text.length;
    final targetEmojiCount = (charCount * targetDensity / 100).round();
    final currentEmojiCount = _countEmojis(text);
    if (currentEmojiCount >= targetEmojiCount) return text;

    final emojiList = ['\u2728', '\uD83D\uDC95', '\uD83D\uDD25', '\uD83D\uDCA1', '\uD83D\uDC46', '\uD83C\uDFAF', '\u2B50', '\uD83C\uDF1F'];
    final needed = targetEmojiCount - currentEmojiCount;
    final lines = text.split('\n');
    for (var i = 0; i < needed && i < lines.length; i++) {
      final emoji = emojiList[i % emojiList.length];
      if (lines[i].trim().isNotEmpty) {
        lines[i] = '$emoji ${lines[i]}';
      }
    }
    return lines.join('\n');
  }

  int _countEmojis(String text) {
    int count = 0;
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code > 0x1F600 && code < 0x1F9FF) count++;
    }
    return count;
  }

  String _emoji(String type) {
    return switch (type) {
      'pain' => '\uD83D\uDE23',
      'solution' => '\uD83D\uDCA1',
      'cta' => '\uD83D\uDC47',
      'star' => '\u2B50',
      'fire' => '\uD83D\uDD25',
      _ => '\u2728',
    };
  }

  List<String> generateHashtags(String topic, {int count = 8}) {
    final baseTags = [
      topic, '${topic}\u63A8\u8350', '${topic}\u653B\u7565',
      '\u5E72\u8D27\u5206\u4EAB', '\u597D\u7269\u63A8\u8350', '\u751F\u6D3B\u8BB0\u5F55',
      '\u65E5\u5E38\u5206\u4EAB', '\u5B9D\u85CF\u53D1\u73B0', '\u5FC5\u4E70\u6E05\u5355', '\u79CD\u8349\u7B14\u8BB0',
    ];
    return baseTags.where((t) => t.length <= 20 && !t.contains(' '))
        .take(count).map((t) => '#$t').toList();
  }

  GeneratedContent generate({
    required String topic, String? tone, String? hook,
    String? painPoint, String? solution, String? cta,
  }) {
    final title = generateTitle(topic, emotion: tone);
    final body = generateBody(
      topic: topic,
      hook: hook ?? '\u59D0\u59B9\u4EEC\uFF01\u4ECA\u5929\u5FC5\u987B\u7ED9\u4F60\u4EEC\u5B89\u5229\u4E00\u4E0B$topic \uD83D\uDD25',
      painPoint: painPoint ?? '\u662F\u4E0D\u662F\u6BCF\u6B21\u9047\u5230${topic}\u76F8\u5173\u7684\u95EE\u9898\u90FD\u5F88\u5934\u75BC\uFF1F',
      solution: solution ?? '\u7ECF\u8FC7\u6211\u591A\u5E74\u7814\u7A76\uFF0C\u7EC8\u4E8E\u627E\u5230\u4E86\u6700\u4F73\u65B9\u6848\uFF01',
      cta: cta ?? '\u89C9\u5F97\u6709\u7528\u7684\u8BDD\u8BB0\u5F97\u70B9\u8D5E\u6536\u85CF\u54E6\uFF5E\u6709\u95EE\u9898\u8BC4\u8BBA\u533A\u89C1 \uD83D\uDCAC',
    );
    final hashtags = generateHashtags(topic);
    return GeneratedContent(
      platform: SocialPlatform.xiaohongshu, title: title, body: body,
      hashtags: hashtags,
      metadata: {
        'topic': topic, 'tone': tone ?? '\u70ED\u60C5\u5206\u4EAB',
        'emoji_density': _config.xiaohongshuEmojiDensity, 'word_count': body.length,
      },
    );
  }
}

// ============================================================================
// 公众号文章引擎
// ============================================================================

class WechatArticleEngine {
  final SocialMediaConfig _config;
  WechatArticleEngine(this._config);

  String generateArticle({
    required String topic, required String openingHook,
    required List<SectionOutline> sections, required String closingGuide,
    String? goldenQuote,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('## $openingHook');
    buffer.writeln();
    for (final section in sections) {
      buffer.writeln('### ${section.title}');
      buffer.writeln();
      buffer.writeln(section.content);
      buffer.writeln();
      if (section.quote != null) {
        buffer.writeln('> ${section.quote}');
        buffer.writeln();
      }
    }
    if (goldenQuote != null) {
      buffer.writeln('---');
      buffer.writeln();
      buffer.writeln('> "$goldenQuote"');
      buffer.writeln();
    }
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln(closingGuide);
    return buffer.toString();
  }

  String suggestCoverImage(String topic, String articleMood) {
    final moodMap = {
      'professional': '\u7B80\u7EA6\u5546\u52A1\u98CE\u683C\uFF0C\u84DD\u8272\u8C03\uFF0C\u51E0\u4F55\u56FE\u5F62\u5143\u7D20\uFF0C\u5E72\u51C0\u5927\u6C14',
      'warm': '\u6696\u8272\u8C03\uFF0C\u67D4\u548C\u5149\u7EBF\uFF0C\u6E29\u99A8\u573A\u666F\uFF0C\u751F\u6D3B\u611F',
      'tech': '\u79D1\u6280\u611F\uFF0C\u6DF1\u8272\u80CC\u666F\uFF0C\u5149\u6548\u7C92\u5B50\uFF0C\u672A\u6765\u611F',
      'creative': '\u649E\u8272\u642D\u914D\uFF0C\u62BD\u8C61\u56FE\u6848\uFF0C\u827A\u672F\u98CE\u683C\uFF0C\u89C6\u89C9\u51B2\u51FB',
      'minimal': '\u6781\u7B80\u98CE\u683C\uFF0C\u5927\u91CF\u7559\u767D\uFF0C\u5355\u4E00\u4E3B\u8272\u8C03\uFF0C\u9AD8\u7EA7\u611F',
    };
    final style = moodMap[articleMood] ?? moodMap['professional']!;
    return '\u5C01\u9762\u5EFA\u8BAE\uFF1A\u4E3B\u9898\u300C$topic\u300D| \u98CE\u683C\uFF1A$style | \u5C3A\u5BF8\uFF1A900x383\uFF082.35:1\uFF09';
  }

  Map<String, String> getLayoutTemplate(String contentType) {
    return switch (contentType) {
      'tutorial' => {
        'title_style': '\u5927\u53F7\u52A0\u7C97\u5C45\u4E2D\uFF0C\u5E95\u90E8\u88C5\u9970\u7EBF',
        'body_style': '15px\u5B57\u53F7\uFF0C1.75\u500D\u884C\u8DDD\uFF0C\u4E24\u7AEF\u5BF9\u9F50',
        'section_style': '\u5E26\u7F16\u53F7\u7684\u5C0F\u6807\u9898\uFF0C\u5DE6\u4FA7\u8272\u6761\u88C5\u9970',
        'quote_style': '\u7070\u8272\u80CC\u666F\u5361\u7247\uFF0C\u5DE6\u4FA7\u5F15\u7528\u7EBF',
        'image_style': '\u5706\u89D2\u77E9\u5F62\uFF0C\u5E26\u9634\u5F71\uFF0C\u5C45\u4E2D',
      },
      'story' => {
        'title_style': '\u624B\u5199\u4F53\u98CE\u683C\uFF0C\u5DE6\u5BF9\u9F50',
        'body_style': '16px\u5B57\u53F7\uFF0C2\u500D\u884C\u8DDD\uFF0C\u9996\u884C\u7F29\u8FDB',
        'section_style': '\u5206\u9694\u7EBF + \u5C0F\u56FE\u6807',
        'quote_style': '\u5927\u5F15\u53F7\u88C5\u9970\uFF0C\u659C\u4F53',
        'image_style': '\u5168\u5BBD\u65E0\u8FB9\u6846\uFF0C\u7535\u5F71\u611F',
      },
      'list' => {
        'title_style': '\u6570\u5B57\u7A81\u51FA\uFF0C\u5F69\u8272\u80CC\u666F',
        'body_style': '14px\u5B57\u53F7\uFF0C\u6761\u76EE\u5F0F\u6392\u7248',
        'section_style': '\u5E8F\u53F7\u5706\u5708 + \u6807\u9898',
        'quote_style': '\u9AD8\u4EAE\u8272\u5757',
        'image_style': '\u7EDF\u4E00\u5C3A\u5BF8\u7F51\u683C\u6392\u5217',
      },
      _ => {
        'title_style': '\u6807\u51C6\u52A0\u7C97\u5C45\u4E2D',
        'body_style': '15px\u5B57\u53F7\uFF0C1.75\u500D\u884C\u8DDD',
        'section_style': '\u6807\u51C6\u5C0F\u6807\u9898',
        'quote_style': '\u6807\u51C6\u5F15\u7528',
        'image_style': '\u6807\u51C6\u5C45\u4E2D',
      },
    };
  }

  GeneratedContent generate({
    required String topic, String? tone, String? openingHook,
    String? goldenQuote, String? closingGuide,
  }) {
    final effectiveTone = tone ?? 'professional';
    final sections = [
      SectionOutline(
        title: '\u4EC0\u4E48\u662F$topic\uFF1F',
        content: '${topic}\u662F\u5F53\u4E0B\u6700\u53D7\u5173\u6CE8\u7684\u8BDD\u9898\u4E4B\u4E00\u3002\u5F88\u591A\u4EBA\u5BF9\u5B83\u65E2\u597D\u5947\u53C8\u56F0\u60D1\uFF0C\u4ECA\u5929\u6211\u4EEC\u5C31\u6765\u6DF1\u5165\u804A\u804A\u3002',
      ),
      SectionOutline(
        title: '\u4E3A\u4EC0\u4E48$topic\u5982\u6B64\u91CD\u8981\uFF1F',
        content: '\u7406\u89E3${topic}\u7684\u6838\u5FC3\u4EF7\u503C\uFF0C\u80FD\u5E2E\u52A9\u4F60\u505A\u51FA\u66F4\u660E\u667A\u7684\u51B3\u7B56\u3002\u4EE5\u4E0B\u4ECE\u4E09\u4E2A\u7EF4\u5EA6\u6765\u5206\u6790\u3002',
        quote: '\u8BA4\u77E5\u51B3\u5B9A\u884C\u4E3A\uFF0C\u884C\u4E3A\u51B3\u5B9A\u7ED3\u679C\u3002',
      ),
      SectionOutline(
        title: '\u5982\u4F55\u6B63\u786E\u5E94\u5BF9$topic\uFF1F',
        content: '\u638C\u63E1\u4E86\u65B9\u6CD5\u8BBA\uFF0C${topic}\u5C31\u4E0D\u518D\u662F\u96BE\u9898\u3002\u8FD9\u91CC\u6709\u51E0\u4E2A\u7ECF\u8FC7\u9A8C\u8BC1\u7684\u5B9E\u7528\u6280\u5DE7\u3002',
      ),
    ];
    final body = generateArticle(
      topic: topic,
      openingHook: openingHook ?? '\u4F60\u6709\u6CA1\u6709\u60F3\u8FC7\uFF0C\u4E3A\u4EC0\u4E48\u8EAB\u8FB9\u7684\u4EBA\u90FD\u5728\u8BA8\u8BBA$topic\uFF1F',
      sections: sections,
      closingGuide: closingGuide ?? '\u5982\u679C\u8FD9\u7BC7\u6587\u7AE0\u5BF9\u4F60\u6709\u5E2E\u52A9\uFF0C\u6B22\u8FCE\u70B9\u8D5E\u3001\u5728\u770B\u3001\u8F6C\u53D1\u4E09\u8FDE\uFF5E\u4F60\u7684\u652F\u6301\u662F\u6211\u6301\u7EED\u521B\u4F5C\u7684\u52A8\u529B \u2764\uFE0F',
      goldenQuote: goldenQuote,
    );
    final coverSuggestion = suggestCoverImage(topic, effectiveTone);
    return GeneratedContent(
      platform: SocialPlatform.wechat,
      title: '$topic\uFF1A\u4F60\u9700\u8981\u77E5\u9053\u7684\u4E00\u5207',
      body: body, hashtags: [],
      metadata: {
        'topic': topic, 'tone': effectiveTone, 'word_count': body.length,
        'cover_suggestion': coverSuggestion, 'layout': getLayoutTemplate('tutorial'),
        'target_words': _config.wechatArticleWordCount,
      },
    );
  }
}

// ============================================================================
// 抖音脚本引擎
// ============================================================================

class DouyinScriptEngine {
  final SocialMediaConfig _config;
  DouyinScriptEngine(this._config);

  List<ShotDescription> generateStoryboard({
    required String topic, required int durationSeconds, required String scriptType,
  }) {
    return switch (scriptType) {
      '\u53E3\u64AD' => _generateTalkingHeadShots(topic, durationSeconds),
      '\u5267\u60C5' => _generateDramaShots(topic, durationSeconds),
      '\u6559\u7A0B' => _generateTutorialShots(topic, durationSeconds),
      'vlog' => _generateVlogShots(topic, durationSeconds),
      _ => _generateTalkingHeadShots(topic, durationSeconds),
    };
  }

  List<ShotDescription> _generateTalkingHeadShots(String topic, int d) => [
    ShotDescription(id: 1, startTime: 0, endTime: 3, shotType: '\u8FD1\u666F',
      scene: '\u9762\u5BF9\u955C\u5934\uFF0C\u8868\u60C5\u5174\u594B',
      dialogue: '\u5BB6\u4EBA\u4EEC\uFF01\u4ECA\u5929\u5FC5\u987B\u8DDF\u4F60\u4EEC\u804A\u804A$topic\uFF01',
      cameraMovement: '\u56FA\u5B9A\u673A\u4F4D', notes: '\u5F00\u59343\u79D2\u5FC5\u987B\u6293\u4F4F\u6CE8\u610F\u529B'),
    ShotDescription(id: 2, startTime: 3, endTime: 15, shotType: '\u4E2D\u666F',
      scene: '\u914D\u5408\u624B\u52BF\u8BB2\u89E3',
      dialogue: '\u9996\u5148\u6765\u8BF4\u8BF4\u4EC0\u4E48\u53EB$topic...',
      cameraMovement: '\u7F13\u6162\u63A8\u8FDB', notes: '\u914D\u5408\u6587\u5B57\u8D34\u7EB8\u8F85\u52A9\u8BF4\u660E'),
    ShotDescription(id: 3, startTime: 15, endTime: (d > 45 ? 40 : d - 5), shotType: '\u8FD1\u666F+\u7279\u5199\u4EA4\u66FF',
      scene: '\u6DF1\u5165\u8BB2\u89E3\u6838\u5FC3\u5185\u5BB9',
      dialogue: '\u91CD\u70B9\u6765\u4E86\uFF01\u5173\u4E8E${topic}\u6700\u5173\u952E\u7684\u4E00\u70B9\u662F...',
      cameraMovement: '\u591A\u89D2\u5EA6\u5207\u6362', notes: '\u6B64\u5904\u63D2\u5165\u5173\u952E\u753B\u9762/B-roll'),
    ShotDescription(id: 4, startTime: (d > 45 ? 40 : d - 5), endTime: d, shotType: '\u8FD1\u666F',
      scene: '\u603B\u7ED3 + CTA',
      dialogue: '\u603B\u7ED3\u4E00\u4E0B\uFF01\u5982\u679C\u89C9\u5F97\u6709\u7528\u5C31\u70B9\u4E2A\u5173\u6CE8\u5427\uFF5E',
      cameraMovement: '\u56FA\u5B9A', notes: '\u7ED3\u5C3E\u5F15\u5BFC\u70B9\u8D5E\u5173\u6CE8'),
  ];

  List<ShotDescription> _generateDramaShots(String topic, int d) => [
    ShotDescription(id: 1, startTime: 0, endTime: 5, shotType: '\u5168\u666F',
      scene: '\u573A\u666F\u5EFA\u7ACB', dialogue: '',
      cameraMovement: '\u822A\u62CD/\u6A2A\u79FB', notes: '\u914D\u5408\u60AC\u5FF5\u97F3\u4E50\uFF0C\u5236\u9020\u597D\u5947\u611F'),
    ShotDescription(id: 2, startTime: 5, endTime: 20, shotType: '\u4E2D\u666F',
      scene: '\u77DB\u76FE/\u51B2\u7A81\u5C55\u793A',
      dialogue: '\uFF08\u65C1\u767D\uFF09\u6BCF\u4E2A\u4EBA\u90FD\u9047\u5230\u8FC7\u8FD9\u79CD\u60C5\u51B5...',
      cameraMovement: '\u624B\u6301\u8DDF\u62CD', notes: '\u5236\u9020\u5171\u9E23\u611F'),
    ShotDescription(id: 3, startTime: 20, endTime: (d > 45 ? 45 : d - 5), shotType: '\u7279\u5199',
      scene: '\u8F6C\u6298/\u89E3\u51B3',
      dialogue: '\u76F4\u5230\u6211\u53D1\u73B0\u4E86\u8FD9\u4E2A...',
      cameraMovement: '\u63A8\u8FDB\u7279\u5199', notes: '\u9AD8\u5149\u65F6\u523B\uFF0C\u914D\u5408\u8F6C\u573A\u7279\u6548'),
    ShotDescription(id: 4, startTime: (d > 45 ? 45 : d - 5), endTime: d, shotType: '\u4E2D\u666F',
      scene: '\u7ED3\u5C40 + \u53CD\u8F6C',
      dialogue: '\u4F60\u4EEC\u89C9\u5F97\u7ED3\u679C\u600E\u6837\uFF1F\u8BC4\u8BBA\u533A\u544A\u8BC9\u6211\uFF01',
      cameraMovement: '\u56FA\u5B9A', notes: '\u7559\u60AC\u5FF5\u5F15\u5BFC\u4E92\u52A8'),
  ];

  List<ShotDescription> _generateTutorialShots(String topic, int d) => [
    ShotDescription(id: 1, startTime: 0, endTime: 3, shotType: '\u8FD1\u666F',
      scene: '\u5F00\u573A\u5C55\u793A\u6210\u54C1',
      dialogue: '\u6559\u4F60$topic\uFF0C\u770B\u5B8C\u5C31\u4F1A\uFF01',
      cameraMovement: '\u56FA\u5B9A', notes: '\u5148\u5C55\u793A\u7ED3\u679C\u5438\u5F15\u89C2\u770B'),
    ShotDescription(id: 2, startTime: 3, endTime: d - 5, shotType: '\u4FEF\u62CD/\u7279\u5199',
      scene: '\u5206\u6B65\u9AA4\u6F14\u793A',
      dialogue: '\u7B2C\u4E00\u6B65...\u7B2C\u4E8C\u6B65...\u7B2C\u4E09\u6B65...',
      cameraMovement: '\u4FEF\u62CD\u4E3A\u4E3B', notes: '\u914D\u5408\u6B65\u9AA4\u7F16\u53F7\u5B57\u5E55'),
    ShotDescription(id: 3, startTime: d - 5, endTime: d, shotType: '\u8FD1\u666F',
      scene: '\u6210\u54C1\u5C55\u793A + CTA',
      dialogue: '\u5B66\u4F1A\u4E86\u5417\uFF1F\u6536\u85CF\u8D77\u6765\u6162\u6162\u7EC3\uFF01',
      cameraMovement: '\u56FA\u5B9A', notes: '\u5F15\u5BFC\u6536\u85CF'),
  ];

  List<ShotDescription> _generateVlogShots(String topic, int d) => [
    ShotDescription(id: 1, startTime: 0, endTime: 5, shotType: '\u81EA\u62CD\u89C6\u89D2',
      scene: '\u5F00\u573A\u95EE\u5019',
      dialogue: '\u4ECA\u5929\u5E26\u5927\u5BB6\u770B\u770B$topic\uFF5E',
      cameraMovement: '\u624B\u6301\u81EA\u62CD', notes: '\u81EA\u7136\u4EB2\u5207'),
    ShotDescription(id: 2, startTime: 5, endTime: d - 10, shotType: '\u591A\u89C6\u89D2\u6DF7\u5408',
      scene: '\u63A2\u7D22/\u4F53\u9A8C\u8FC7\u7A0B',
      dialogue: '\uFF08\u73B0\u573A\u89E3\u8BF4\uFF09',
      cameraMovement: '\u7075\u6D3B\u5207\u6362', notes: '\u591A\u89D2\u5EA6\u5C55\u793A\uFF0C\u914D\u5408BGM'),
    ShotDescription(id: 3, startTime: d - 10, endTime: d, shotType: '\u81EA\u62CD\u89C6\u89D2',
      scene: '\u603B\u7ED3\u611F\u53D7',
      dialogue: '\u4ECA\u5929\u4F53\u9A8C$topic\u771F\u7684\u592A\u597D\u5566\uFF01\u4E0B\u6B21\u8FD8\u6765\uFF5E',
      cameraMovement: '\u56FA\u5B9A', notes: '\u771F\u8BDA\u611F\u53D7\uFF0C\u5F15\u5BFC\u5173\u6CE8'),
  ];

  String generateVoiceoverScript({
    required String topic, required int durationSeconds, String? hookPhrase,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('\u3010\u5F00\u5934 Hook - 0~3s\u3011');
    buffer.writeln(hookPhrase ?? '\u505C\uFF01\u522B\u5212\u8D70\uFF01\u4ECA\u5929\u544A\u8BC9\u4F60\u5173\u4E8E$topic\u7684\u79D8\u5BC6\uFF01');
    buffer.writeln();
    buffer.writeln('\u3010\u6B63\u6587\u5C55\u5F00 - 3~${durationSeconds - 5}s\u3011');
    buffer.writeln('\u9996\u5148\uFF0C\u4EC0\u4E48\u662F$topic\uFF1F\u7B80\u5355\u6765\u8BF4...');
    buffer.writeln('\u7136\u540E\uFF0C\u4E3A\u4EC0\u4E48$topic\u8FD9\u4E48\u706B\uFF1F\u56E0\u4E3A...');
    buffer.writeln('\u6700\u540E\uFF0C\u666E\u901A\u4EBA\u600E\u4E48\u5229\u7528$topic\uFF1F\u8FD9\u91CC\u6709\u4E09\u4E2A\u65B9\u6CD5...');
    buffer.writeln();
    buffer.writeln('\u3010\u7ED3\u5C3E CTA - \u6700\u540E5s\u3011');
    buffer.writeln('\u5B66\u4F1A\u4E86\u5417\uFF1F\u53CC\u51FB\u5173\u6CE8\uFF0C\u4E0B\u671F\u6559\u4F60\u66F4\u591A\uFF01');
    return buffer.toString();
  }

  Map<String, List<String>> suggestTopicsAndMusic(String topic) => {
    'hashtags': ['#$topic', '#\u6BCF\u65E5\u5206\u4EAB', '#\u5E72\u8D27', '#\u6DA8\u77E5\u8BC6', '#${topic}\u6559\u7A0B'],
    'bgm': [
      '\u70ED\u95E8BGM\uFF1A\u300A\u70ED\u7231105\u00B0C\u7684\u4F60\u300B',
      '\u6C1B\u56F4BGM\uFF1A\u8F7B\u5FEB\u8282\u594F\u7EAF\u97F3\u4E50',
      '\u60C5\u611FBGM\uFF1A\u300A\u8D77\u98CE\u4E86\u300B\u94A2\u7434\u7248',
    ],
    'effects': [
      '\u6587\u5B57\u8D34\u7EB8\uFF1A\u5173\u952E\u8BCD\u9AD8\u4EAE',
      '\u8F6C\u573A\uFF1A\u5FEB\u901F\u5207\u6362/\u6A21\u7CCA\u8F6C\u573A',
      '\u6EE4\u955C\uFF1A\u6839\u636E\u4E3B\u9898\u9009\u62E9\u5BF9\u5E94\u6EE4\u955C',
    ],
  };

  GeneratedContent generate({
    required String topic, int? duration, String? scriptType, String? hookPhrase,
  }) {
    final d = duration ?? _config.douyinMaxDuration;
    final type = scriptType ?? '\u53E3\u64AD';
    final storyboard = generateStoryboard(topic: topic, durationSeconds: d, scriptType: type);
    final voiceover = generateVoiceoverScript(topic: topic, durationSeconds: d, hookPhrase: hookPhrase);
    final suggestions = suggestTopicsAndMusic(topic);
    final buf = StringBuffer();
    buf.writeln('=== \u6296\u97F3\u811A\u672C ===');
    buf.writeln('\u4E3B\u9898\uFF1A$topic');
    buf.writeln('\u65F6\u957F\uFF1A${d}\u79D2');
    buf.writeln('\u7C7B\u578B\uFF1A$type');
    buf.writeln();
    buf.writeln('--- \u5206\u955C\u811A\u672C ---');
    for (final shot in storyboard) {
      buf.writeln('[${shot.startTime}s-${shot.endTime}s] ${shot.shotType}');
      buf.writeln('  \u753B\u9762\uFF1A${shot.scene}');
      buf.writeln('  \u53F0\u8BCD\uFF1A${shot.dialogue}');
      buf.writeln('  \u8FD0\u955C\uFF1A${shot.cameraMovement}');
      buf.writeln('  \u5907\u6CE8\uFF1A${shot.notes}');
      buf.writeln();
    }
    buf.writeln('--- \u53E3\u64AD\u6587\u6848 ---');
    buf.writeln(voiceover);
    buf.writeln();
    buf.writeln('--- \u63A8\u8350 ---');
    buf.writeln('\u8BDD\u9898\uFF1A${(suggestions['hashtags'] ?? []).join(' ')}');
    buf.writeln('\u97F3\u4E50\uFF1A${(suggestions['bgm'] ?? []).join('\uFF1B')}');
    return GeneratedContent(
      platform: SocialPlatform.douyin,
      title: '$topic | \u5FC5\u770B\u5E72\u8D27',
      body: buf.toString(),
      hashtags: suggestions['hashtags'] ?? [],
      metadata: {
        'topic': topic, 'duration_seconds': d, 'script_type': type,
        'shot_count': storyboard.length, 'suggestions': suggestions,
      },
    );
  }
}

// ============================================================================
// 微博文案引擎
// ============================================================================

class WeiboEngine {
  final SocialMediaConfig _config;
  WeiboEngine(this._config);

  String generateShortPost({required String topic, String? hotSearchKeyword, String? tone}) {
    final buffer = StringBuffer();
    if (hotSearchKeyword != null) buffer.write('#$hotSearchKeyword# ');
    buffer.write('#$topic# ');
    final templates = [
      '\u521A\u521A\u770B\u5230\u4E00\u4E2A\u5173\u4E8E$topic\u7684\u8BDD\u9898\uFF0C\u5FCD\u4E0D\u4F4F\u60F3\u8BF4\u4E24\u53E5...',
      '\u5173\u4E8E$topic\uFF0C\u6211\u6709\u8BDD\u8981\u8BF4\uFF01',
      '$topic\u771F\u7684\u592A\u592A\u592A\u91CD\u8981\u4E86\uFF0C\u5FC5\u987B\u5206\u4EAB\uFF01',
      '\u4ECA\u65E5\u4EFD$topic\u5FC3\u5F97\uFF0C\u6536\u85CF\u4E0D\u4E8F \uD83D\uDC47',
    ];
    final idx = topic.hashCode.abs() % templates.length;
    buffer.write(templates[idx]);
    final remaining = _config.weiboMaxChars - buffer.length;
    if (remaining > 20) {
      buffer.write(' \u4E00\u53E5\u8BDD\u603B\u7ED3\u5C31\u662F\uFF1A${topic}\u7684\u6838\u5FC3\u5728\u4E8E\u6301\u7EED\u5B66\u4E60\u548C\u5B9E\u8DF5\u3002\u4F60\u600E\u4E48\u770B\uFF1F');
    }
    return buffer.toString();
  }

  String generateWithTrending(String topic, TrendingTopic trending) {
    return '#${trending.keyword}# #${topic}# '
        '${trending.keyword}\u548C$topic\u6709\u4EC0\u4E48\u5173\u7CFB\uFF1F\u5176\u5B9E\u5B83\u4EEC\u90FD\u6307\u5411\u540C\u4E00\u4E2A\u8D8B\u52BF\u2014\u2014'
        '\u5728\u8FD9\u4E2A\u5FEB\u901F\u53D8\u5316\u7684\u65F6\u4EE3\uFF0C\u6293\u4F4F\u6838\u5FC3\u624D\u662F\u5173\u952E\u3002\u4F60\u600E\u4E48\u770B\uFF1F';
  }

  GeneratedContent generate({required String topic, String? hotSearchKeyword, String? tone}) {
    final body = generateShortPost(topic: topic, hotSearchKeyword: hotSearchKeyword, tone: tone);
    return GeneratedContent(
      platform: SocialPlatform.weibo, title: '', body: body,
      hashtags: ['#$topic#', if (hotSearchKeyword != null) '#$hotSearchKeyword#'],
      metadata: {
        'topic': topic, 'char_count': body.length,
        'max_chars': _config.weiboMaxChars, 'hot_search': hotSearchKeyword,
      },
    );
  }
}

// ============================================================================
// 违禁词预检模块
// ============================================================================

class ComplianceChecker {
  static const List<String> _defaultForbiddenWords = [
    '\u6700', '\u7B2C\u4E00', '\u552F\u4E00', '\u9876\u7EA7', '\u6781\u81F4', '\u7EDD\u5BF9', '\u5168\u7F51\u6700\u4F4E',
    '\u56FD\u5BB6\u7EA7', '\u4E16\u754C\u7EA7', '\u6700\u4F73', '\u6700\u597D', '\u6700\u4F18', '\u6700\u9AD8\u7EA7',
    '\u6C38\u4E45', '\u4E07\u80FD', '100%', '\u65E0\u654C', '\u79F0\u9738',
    '\u5305\u6CBB\u767E\u75C5', '\u836F\u5230\u75C5\u9664', '\u7956\u4F20\u79D8\u65B9', '\u7ACB\u7AFF\u89C1\u5F71',
    '\u4FDD\u8BC1\u6548\u679C', '\u65E0\u6548\u9000\u6B3E', '\u96F6\u98CE\u9669',
    '\u79D2\u6740', '\u62A2\u8D2D\u4E00\u7A7A', '\u9650\u65F6\u7591\u62A2',
    '\u6839\u6CBB', '\u7279\u6548\u836F', '\u4FDD\u672C\u4FDD\u6536\u76CA', '\u7A33\u8D5A\u4E0D\u8D54',
  ];

  static const Map<String, List<String>> _platformForbidden = {
    'xiaohongshu': ['\u52A0\u5FAE\u4FE1', '\u52A0V', '\u79C1\u6211', '\u95F2\u9C7C', '\u62FC\u591A\u591A', '\u6DD8\u5B9D\u641C', '\u70B9\u51FB\u94FE\u63A5'],
    'wechat': ['\u70B9\u51FB\u539F\u6587', '\u8BC6\u522B\u56FE\u7247\u4E8C\u7EF4\u7801', '\u8F6C\u53D1\u52303\u4E2A\u7FA4'],
    'douyin': ['\u52A0\u6211', '\u79C1\u4FE1\u6211', '\u4E3B\u9875\u6709', '\u5C0F\u9EC4\u8F66'],
    'weibo': ['\u8F6C\u53D1\u62BD\u5956', '\u5173\u6CE8\u5E76\u8F6C\u53D1'],
  };

  ComplianceResult check(String text, {String? platform}) {
    final issues = <ComplianceIssue>[];
    for (final word in _defaultForbiddenWords) {
      final idx = text.indexOf(word);
      if (idx != -1) {
        issues.add(ComplianceIssue(word: word, category: '\u5E7F\u544A\u6CD5/\u901A\u7528', suggestion: _getSuggestion(word), position: idx));
      }
    }
    if (platform != null) {
      for (final word in (_platformForbidden[platform] ?? <String>[])) {
        final idx = text.indexOf(word);
        if (idx != -1) {
          issues.add(ComplianceIssue(word: word, category: '${_platformName(platform)}\u5E73\u53F0\u89C4\u5219', suggestion: '\u5EFA\u8BAE\u5220\u9664\u6216\u66FF\u6362\u4E3A\u5E73\u53F0\u5141\u8BB8\u7684\u5F15\u5BFC\u65B9\u5F0F', position: idx));
        }
      }
    }
    final passed = issues.isEmpty;
    return ComplianceResult(
      passed: passed, issues: issues,
      summary: passed
          ? '\u2705 \u5185\u5BB9\u901A\u8FC7\u8FDD\u7981\u8BCD\u68C0\u6D4B\uFF0C\u53EF\u4EE5\u5B89\u5168\u53D1\u5E03'
          : '\u26A0\uFE0F \u53D1\u73B0 ${issues.length} \u5904\u8FDD\u7981\u8BCD\uFF0C\u5EFA\u8BAE\u4FEE\u6539\u540E\u518D\u53D1\u5E03',
    );
  }

  String _getSuggestion(String word) {
    return switch (word) {
      '\u6700' => '\u53EF\u6539\u4E3A\u201C\u975E\u5E38\u201D\u201C\u6781\u5176\u201D\u201C\u5341\u5206\u201D',
      '\u7B2C\u4E00' => '\u53EF\u6539\u4E3A\u201C\u9886\u5148\u201D\u201C\u524D\u5217\u201D\u201C\u5934\u90E8\u201D',
      '\u552F\u4E00' => '\u53EF\u6539\u4E3A\u201C\u5C11\u6709\u7684\u201D\u201C\u72EC\u7279\u7684\u201D',
      '\u9876\u7EA7' => '\u53EF\u6539\u4E3A\u201C\u9AD8\u7AEF\u201D\u201C\u4F18\u8D28\u201D\u201C\u7CBE\u9009\u201D',
      '\u6781\u81F4' => '\u53EF\u6539\u4E3A\u201C\u7CBE\u5FC3\u201D\u201C\u7528\u5FC3\u201D\u201C\u8FFD\u6C42\u201D',
      '\u7EDD\u5BF9' => '\u53EF\u6539\u4E3A\u201C\u5927\u6982\u7387\u201D\u201C\u57FA\u672C\u201D\u201C\u5F88\u5927\u7A0B\u5EA6\u4E0A\u201D',
      '100%' => '\u53EF\u6539\u4E3A\u201C\u9AD8\u6BD4\u4F8B\u201D\u201C\u7EDD\u5927\u591A\u6570\u201D',
      '\u6C38\u4E45' => '\u53EF\u6539\u4E3A\u201C\u957F\u671F\u201D\u201C\u6301\u4E45\u201D',
      '\u4E07\u80FD' => '\u53EF\u6539\u4E3A\u201C\u591A\u7528\u9014\u201D\u201C\u591A\u529F\u80FD\u201D',
      '\u65E0\u654C' => '\u53EF\u6539\u4E3A\u201C\u51FA\u8272\u201D\u201C\u4F18\u79C0\u201D',
      _ => '\u5EFA\u8BAE\u5220\u9664\u6216\u66FF\u6362\u4E3A\u66F4\u6E29\u548C\u7684\u8868\u8FF0',
    };
  }

  String _platformName(String code) => switch (code) {
    'xiaohongshu' => '\u5C0F\u7EA2\u4E66', 'wechat' => '\u5FAE\u4FE1\u516C\u4F17\u53F7',
    'douyin' => '\u6296\u97F3', 'weibo' => '\u5FAE\u535A', _ => '\u901A\u7528',
  };
}

// ============================================================================
// 社交媒体技能主类
// ============================================================================

class SocialMediaSkill extends Skill {
  final SocialMediaConfig _config;
  late final XiaohongshuEngine _xhsEngine;
  late final WechatArticleEngine _wechatEngine;
  late final DouyinScriptEngine _douyinEngine;
  late final WeiboEngine _weiboEngine;
  late final ComplianceChecker _complianceChecker;
  final List<CalendarEntry> _calendar = [];
  final List<GeneratedContent> _contentCache = [];

  SocialMediaSkill({SocialMediaConfig? config})
      : _config = config ?? const SocialMediaConfig() {
    _xhsEngine = XiaohongshuEngine(_config);
    _wechatEngine = WechatArticleEngine(_config);
    _douyinEngine = DouyinScriptEngine(_config);
    _weiboEngine = WeiboEngine(_config);
    _complianceChecker = ComplianceChecker();
  }

  @override
  SkillManifest get manifest => const SkillManifest(
    id: 'social_media', name: '\u793E\u4EA4\u5A92\u4F53\u5185\u5BB9',
    description: '\u751F\u6210\u591A\u5E73\u53F0\u793E\u4EA4\u5A92\u4F53\u5185\u5BB9\u3002\u652F\u6301\u5C0F\u7EA2\u4E66\u7206\u6B3E\u7B14\u8BB0\u3001\u5FAE\u4FE1\u516C\u4F17\u53F7\u6587\u7AE0\u3001'
        '\u6296\u97F3\u77ED\u89C6\u9891\u811A\u672C\u3001\u5FAE\u535A\u6587\u6848\u7684\u751F\u6210\u3002\u8FD8\u63D0\u4F9B\u5185\u5BB9\u65E5\u5386\u6392\u671F\u3001\u6279\u91CF\u751F\u6210\u3001\u8FDD\u7981\u8BCD\u9884\u68C0\u7B49\u529F\u80FD\u3002',
    version: '1.0.0', author: '\u5C0F\u9165',
    permissions: [SkillPermission.networkAccess, SkillPermission.localStorage],
    loadStrategy: SkillLoadStrategy.lazy,
  );

  @override
  List<SkillTool> get tools => [
    _createXiaohongshuTool, _createWechatArticleTool, _createDouyinScriptTool,
    _createWeiboTool, _analyzeTrendingTool, _generateHashtagsTool,
    _contentCalendarTool, _batchCreateTool, _checkComplianceTool,
  ];

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('\u793E\u4EA4\u5A92\u4F53\u6280\u80FD\u521D\u59CB\u5316\u5B8C\u6210');
  }

  @override
  Future<void> onDispose() async {
    _contentCache.clear();
    _calendar.clear();
  }

  // ======================== 工具定义 ========================

  late final SkillTool _createXiaohongshuTool = SkillTool(
    name: 'create_xiaohongshu',
    description: '\u751F\u6210\u5C0F\u7EA2\u4E66\u7206\u6B3E\u7B14\u8BB0\u3002\u5305\u62EC\u5438\u775B\u6807\u9898\u3001\u6B63\u6587\u7ED3\u6784\uFF08hook\u2192\u75DB\u70B9\u2192\u65B9\u6848\u2192CTA\uFF09\u3001emoji \u6392\u7248\u3001\u8BDD\u9898\u6807\u7B7E\u63A8\u8350\u3002',
    parameters: [
      ToolParameter(name: 'topic', description: '\u7B14\u8BB0\u4E3B\u9898/\u5173\u952E\u8BCD', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'tone', description: '\u8BED\u6C14\u98CE\u683C', type: ToolParameterType.stringType,
        enumValues: ['\u70ED\u60C5\u5206\u4EAB', '\u4E13\u4E1A\u5E72\u8D27', '\u79CD\u8349\u5B89\u5229', '\u907F\u96F7\u5410\u69FD', '\u6E29\u67D4\u6CBB\u6108'], defaultValue: '\u70ED\u60C5\u5206\u4EAB'),
      ToolParameter(name: 'hook', description: '\u81EA\u5B9A\u4E49\u5F00\u5934 hook\uFF08\u53EF\u9009\uFF09', type: ToolParameterType.stringType),
      ToolParameter(name: 'pain_point', description: '\u7528\u6237\u75DB\u70B9\u63CF\u8FF0\uFF08\u53EF\u9009\uFF09', type: ToolParameterType.stringType),
      ToolParameter(name: 'solution', description: '\u89E3\u51B3\u65B9\u6848\u63CF\u8FF0\uFF08\u53EF\u9009\uFF09', type: ToolParameterType.stringType),
      ToolParameter(name: 'cta', description: '\u884C\u52A8\u53F7\u53EC\u6587\u6848\uFF08\u53EF\u9009\uFF09', type: ToolParameterType.stringType),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.3, '\u6B63\u5728\u751F\u6210\u5C0F\u7EA2\u4E66\u7B14\u8BB0...');
      final content = _xhsEngine.generate(
        topic: args['topic'] as String, tone: args['tone'] as String?,
        hook: args['hook'] as String?, painPoint: args['pain_point'] as String?,
        solution: args['solution'] as String?, cta: args['cta'] as String?,
      );
      _contentCache.add(content);
      context.onProgress?.call(1.0, '\u5C0F\u7EA2\u4E66\u7B14\u8BB0\u751F\u6210\u5B8C\u6210');
      return ToolResult.success(content: jsonEncode(content.toJson()), data: content.toJson());
    },
  );

  late final SkillTool _createWechatArticleTool = SkillTool(
    name: 'create_wechat_article',
    description: '\u751F\u6210\u5FAE\u4FE1\u516C\u4F17\u53F7\u957F\u6587\u3002\u5305\u62EC\u5F00\u5934\u94A9\u5B50\u3001\u5C0F\u6807\u9898\u7ED3\u6784\u3001\u91D1\u53E5\u3001\u7ED3\u5C3E\u5F15\u5BFC\u5173\u6CE8\u3002\u652F\u6301\u6392\u7248\u6A21\u677F\u548C\u5C01\u9762\u56FE\u5EFA\u8BAE\u3002',
    parameters: [
      ToolParameter(name: 'topic', description: '\u6587\u7AE0\u4E3B\u9898', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'tone', description: '\u6587\u7AE0\u8C03\u6027', type: ToolParameterType.stringType,
        enumValues: ['professional', 'warm', 'tech', 'creative', 'minimal'], defaultValue: 'professional'),
      ToolParameter(name: 'opening_hook', description: '\u81EA\u5B9A\u4E49\u5F00\u5934\u94A9\u5B50\uFF08\u53EF\u9009\uFF09', type: ToolParameterType.stringType),
      ToolParameter(name: 'golden_quote', description: '\u91D1\u53E5\uFF08\u53EF\u9009\uFF09', type: ToolParameterType.stringType),
      ToolParameter(name: 'closing_guide', description: '\u7ED3\u5C3E\u5F15\u5BFC\u6587\u6848\uFF08\u53EF\u9009\uFF09', type: ToolParameterType.stringType),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.3, '\u6B63\u5728\u751F\u6210\u516C\u4F17\u53F7\u6587\u7AE0...');
      final content = _wechatEngine.generate(
        topic: args['topic'] as String, tone: args['tone'] as String?,
        openingHook: args['opening_hook'] as String?, goldenQuote: args['golden_quote'] as String?,
        closingGuide: args['closing_guide'] as String?,
      );
      _contentCache.add(content);
      context.onProgress?.call(1.0, '\u516C\u4F17\u53F7\u6587\u7AE0\u751F\u6210\u5B8C\u6210');
      return ToolResult.success(content: jsonEncode(content.toJson()), data: content.toJson());
    },
  );

  late final SkillTool _createDouyinScriptTool = SkillTool(
    name: 'create_douyin_script',
    description: '\u751F\u6210\u6296\u97F3\u77ED\u89C6\u9891\u811A\u672C\u3002\u5305\u62EC\u5206\u955C\u811A\u672C\u3001\u53E3\u64AD\u6587\u6848\u3001\u8BDD\u9898\u548C\u97F3\u4E50\u63A8\u8350\u3002\u652F\u6301\u53E3\u64AD/\u5267\u60C5/\u6559\u7A0B/vlog\u7C7B\u578B\u3002',
    parameters: [
      ToolParameter(name: 'topic', description: '\u89C6\u9891\u4E3B\u9898', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'duration', description: '\u89C6\u9891\u65F6\u957F\uFF08\u79D2\uFF09', type: ToolParameterType.intType, minValue: 15, maxValue: 180, defaultValue: 60),
      ToolParameter(name: 'script_type', description: '\u811A\u672C\u7C7B\u578B', type: ToolParameterType.stringType,
        enumValues: ['\u53E3\u64AD', '\u5267\u60C5', '\u6559\u7A0B', 'vlog'], defaultValue: '\u53E3\u64AD'),
      ToolParameter(name: 'hook_phrase', description: '\u5F00\u5934 hook \u6587\u6848\uFF08\u53EF\u9009\uFF09', type: ToolParameterType.stringType),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.3, '\u6B63\u5728\u751F\u6210\u6296\u97F3\u811A\u672C...');
      final content = _douyinEngine.generate(
        topic: args['topic'] as String, duration: args['duration'] as int?,
        scriptType: args['script_type'] as String?, hookPhrase: args['hook_phrase'] as String?,
      );
      _contentCache.add(content);
      context.onProgress?.call(1.0, '\u6296\u97F3\u811A\u672C\u751F\u6210\u5B8C\u6210');
      return ToolResult.success(content: jsonEncode(content.toJson()), data: content.toJson());
    },
  );

  late final SkillTool _createWeiboTool = SkillTool(
    name: 'create_weibo',
    description: '\u751F\u6210\u5FAE\u535A\u77ED\u6587\u6848\u3002\u652F\u6301\u7ED3\u5408\u70ED\u641C\u8BDD\u9898\uFF0C140\u5B57\u4EE5\u5185\u7CBE\u70BC\u8868\u8FBE\u3002',
    parameters: [
      ToolParameter(name: 'topic', description: '\u5FAE\u535A\u4E3B\u9898', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'hot_search_keyword', description: '\u7ED3\u5408\u7684\u70ED\u641C\u5173\u952E\u8BCD\uFF08\u53EF\u9009\uFF09', type: ToolParameterType.stringType),
      ToolParameter(name: 'tone', description: '\u8BED\u6C14', type: ToolParameterType.stringType,
        enumValues: ['\u65E5\u5E38', '\u5410\u69FD', '\u5B89\u5229', '\u79D1\u666E', '\u4E92\u52A8'], defaultValue: '\u65E5\u5E38'),
    ],
    execute: (args, context) async {
      final content = _weiboEngine.generate(
        topic: args['topic'] as String, hotSearchKeyword: args['hot_search_keyword'] as String?,
        tone: args['tone'] as String?,
      );
      _contentCache.add(content);
      return ToolResult.success(content: jsonEncode(content.toJson()), data: content.toJson());
    },
  );

  late final SkillTool _analyzeTrendingTool = SkillTool(
    name: 'analyze_trending',
    description: '\u5206\u6790\u5F53\u524D\u70ED\u641C\u8BDD\u9898\u8D8B\u52BF\u3002\u83B7\u53D6\u5404\u5E73\u53F0\u70ED\u95E8\u8BDD\u9898\uFF0C\u5206\u6790\u70ED\u5EA6\u548C\u8D8B\u52BF\u8D70\u5411\u3002',
    parameters: [
      ToolParameter(name: 'platform', description: '\u76EE\u6807\u5E73\u53F0', type: ToolParameterType.stringType,
        enumValues: ['xiaohongshu', 'weibo', 'douyin', 'all'], defaultValue: 'all'),
      ToolParameter(name: 'category', description: '\u8BDD\u9898\u5206\u7C7B', type: ToolParameterType.stringType,
        enumValues: ['\u5A31\u4E50', '\u79D1\u6280', '\u751F\u6D3B', '\u8D22\u7ECF', '\u4F53\u80B2', '\u5168\u90E8']),
      ToolParameter(name: 'limit', description: '\u8FD4\u56DE\u6570\u91CF', type: ToolParameterType.intType, minValue: 5, maxValue: 50, defaultValue: 20),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.2, '\u6B63\u5728\u83B7\u53D6\u70ED\u641C\u6570\u636E...');
      final platform = args['platform'] as String? ?? 'all';
      final limit = args['limit'] as int? ?? 20;
      final category = args['category'] as String?;
      final trending = _generateTrendingData(platform, limit, category);
      context.onProgress?.call(1.0, '\u70ED\u641C\u5206\u6790\u5B8C\u6210');
      return ToolResult.success(
        content: jsonEncode({
          'platform': platform, 'count': trending.length,
          'trending': trending.map((t) => t.toJson()).toList(),
          'analysis': _analyzeTrends(trending),
        }),
        data: {'trending': trending.map((t) => t.toJson()).toList()},
      );
    },
  );

  late final SkillTool _generateHashtagsTool = SkillTool(
    name: 'generate_hashtags',
    description: '\u6839\u636E\u4E3B\u9898\u751F\u6210\u8BDD\u9898\u6807\u7B7E\u3002\u652F\u6301\u591A\u5E73\u53F0\u6807\u7B7E\u63A8\u8350\u3002',
    parameters: [
      ToolParameter(name: 'topic', description: '\u5185\u5BB9\u4E3B\u9898', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'platform', description: '\u76EE\u6807\u5E73\u53F0', type: ToolParameterType.stringType,
        enumValues: ['xiaohongshu', 'wechat', 'douyin', 'weibo', 'all'], defaultValue: 'all'),
      ToolParameter(name: 'count', description: '\u6807\u7B7E\u6570\u91CF', type: ToolParameterType.intType, minValue: 3, maxValue: 20, defaultValue: 10),
    ],
    execute: (args, context) async {
      final topic = args['topic'] as String;
      final count = args['count'] as int? ?? 10;
      final hashtags = _generateHashtagsForTopic(topic, count);
      return ToolResult.success(
        content: jsonEncode({'topic': topic, 'hashtags': hashtags, 'count': hashtags.length}),
        data: {'hashtags': hashtags},
      );
    },
  );

  late final SkillTool _contentCalendarTool = SkillTool(
    name: 'content_calendar',
    description: '\u5185\u5BB9\u65E5\u5386\u89C4\u5212\u3002\u6839\u636E\u4E3B\u9898\u548C\u5E73\u53F0\u751F\u6210\u53D1\u5E03\u6392\u671F\u8868\uFF0C\u5305\u542B\u6700\u4F73\u53D1\u5E03\u65F6\u95F4\u5EFA\u8BAE\u3002',
    parameters: [
      ToolParameter(name: 'topic', description: '\u5185\u5BB9\u4E3B\u9898\u7CFB\u5217', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'platforms', description: '\u76EE\u6807\u5E73\u53F0\u5217\u8868', type: ToolParameterType.arrayType, required: true),
      ToolParameter(name: 'duration_days', description: '\u89C4\u5212\u5929\u6570', type: ToolParameterType.intType, minValue: 7, maxValue: 90, defaultValue: 30),
      ToolParameter(name: 'frequency', description: '\u53D1\u5E03\u9891\u7387', type: ToolParameterType.stringType,
        enumValues: ['daily', 'every_other_day', 'three_per_week', 'weekly'], defaultValue: 'three_per_week'),
    ],
    execute: (args, context) async {
      context.onProgress?.call(0.2, '\u6B63\u5728\u89C4\u5212\u5185\u5BB9\u65E5\u5386...');
      final topic = args['topic'] as String;
      final platforms = (args['platforms'] as List).cast<String>();
      final days = args['duration_days'] as int? ?? 30;
      final frequency = args['frequency'] as String? ?? 'three_per_week';
      final calendar = _generateCalendar(topic: topic, platforms: platforms, days: days, frequency: frequency);
      _calendar.addAll(calendar);
      context.onProgress?.call(1.0, '\u5185\u5BB9\u65E5\u5386\u89C4\u5212\u5B8C\u6210');
      return ToolResult.success(
        content: jsonEncode({
          'topic': topic, 'duration_days': days,
          'entries': calendar.map((e) => e.toJson()).toList(),
          'summary': _calendarSummary(calendar),
        }),
        data: {'entries': calendar.map((e) => e.toJson()).toList()},
      );
    },
  );

  late final SkillTool _batchCreateTool = SkillTool(
    name: 'batch_create',
    description: '\u6279\u91CF\u751F\u6210\u591A\u5E73\u53F0\u5185\u5BB9\u3002\u8F93\u5165\u4E00\u4E2A\u4E3B\u9898\uFF0C\u81EA\u52A8\u751F\u6210\u9002\u914D\u591A\u4E2A\u5E73\u53F0\u7684\u5185\u5BB9\u7248\u672C\u3002',
    parameters: [
      ToolParameter(name: 'topic', description: '\u5185\u5BB9\u4E3B\u9898', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'platforms', description: '\u76EE\u6807\u5E73\u53F0\u5217\u8868', type: ToolParameterType.arrayType, required: true),
      ToolParameter(name: 'tone', description: '\u7EDF\u4E00\u8BED\u6C14\u98CE\u683C', type: ToolParameterType.stringType),
    ],
    execute: (args, context) async {
      final topic = args['topic'] as String;
      final platforms = (args['platforms'] as List).cast<String>();
      final tone = args['tone'] as String?;
      final results = <Map<String, dynamic>>[];
      for (var i = 0; i < platforms.length; i++) {
        final p = platforms[i];
        context.onProgress?.call((i + 1) / platforms.length, '\u6B63\u5728\u751F\u6210${_platformDisplayName(p)}\u5185\u5BB9...');
        final content = _generateForPlatform(topic, p, tone);
        _contentCache.add(content);
        results.add(content.toJson());
      }
      final complianceResults = <Map<String, dynamic>>[];
      for (final c in results) {
        final check = _complianceChecker.check(c['body'] as String, platform: c['platform'] as String?);
        complianceResults.add({'platform': c['platform'], ...check.toJson()});
      }
      return ToolResult.success(
        content: jsonEncode({
          'topic': topic, 'platforms': results, 'compliance': complianceResults, 'total_count': results.length,
        }),
        data: {'platforms': results, 'compliance': complianceResults},
      );
    },
  );

  late final SkillTool _checkComplianceTool = SkillTool(
    name: 'check_compliance',
    description: '\u53D1\u5E03\u524D\u8FDD\u7981\u8BCD\u9884\u68C0\u3002\u68C0\u6D4B\u6587\u672C\u4E2D\u7684\u8FDD\u7981\u8BCD\u3001\u654F\u611F\u8BCD\uFF0C\u7ED9\u51FA\u66FF\u6362\u5EFA\u8BAE\u3002',
    parameters: [
      ToolParameter(name: 'text', description: '\u5F85\u68C0\u6D4B\u7684\u6587\u672C\u5185\u5BB9', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'platform', description: '\u76EE\u6807\u53D1\u5E03\u5E73\u53F0', type: ToolParameterType.stringType,
        enumValues: ['xiaohongshu', 'wechat', 'douyin', 'weibo']),
    ],
    execute: (args, context) async {
      final text = args['text'] as String;
      final platform = args['platform'] as String?;
      final result = _complianceChecker.check(text, platform: platform);
      return ToolResult.success(content: jsonEncode(result.toJson()), data: result.toJson());
    },
  );

  // ======================== 内部方法 ========================

  List<TrendingTopic> _generateTrendingData(String platform, int limit, String? category) {
    final sample = [
      ('\u4EBA\u5DE5\u667A\u80FD', '\u79D1\u6280', 9800), ('\u6625\u65E5\u7A7F\u642D', '\u751F\u6D3B', 8500),
      ('\u57FA\u91D1\u7406\u8D22', '\u8D22\u7ECF', 7200), ('\u5065\u8EAB\u6253\u5361', '\u751F\u6D3B', 6800),
      ('\u65B0\u7247\u63A8\u8350', '\u5A31\u4E50', 9200), ('\u804C\u573A\u5E72\u8D27', '\u79D1\u6280', 5500),
      ('\u7F8E\u98DF\u63A2\u5E97', '\u751F\u6D3B', 7800), ('\u4E16\u754C\u676F', '\u4F53\u80B2', 9500),
      ('\u62A4\u80A4\u5FC3\u5F97', '\u751F\u6D3B', 6200), ('\u8BFB\u4E66\u5206\u4EAB', '\u751F\u6D3B', 4800),
      ('\u65C5\u884C\u653B\u7565', '\u751F\u6D3B', 7000), ('\u7F16\u7A0B\u5165\u95E8', '\u79D1\u6280', 5200),
      ('\u5BB6\u5C45\u88C5\u4FEE', '\u751F\u6D3B', 6000), ('\u5BA0\u7269\u65E5\u5E38', '\u751F\u6D3B', 8000),
      ('\u6570\u7801\u8BC4\u6D4B', '\u79D1\u6280', 5800),
    ];
    var filtered = sample;
    if (category != null && category != '\u5168\u90E8') {
      filtered = sample.where((t) => t.$2 == category).toList();
    }
    return filtered.take(limit).map((t) => TrendingTopic(
      keyword: t.$1, platform: platform, heatIndex: t.$3, category: t.$2,
    )).toList();
  }

  String _analyzeTrends(List<TrendingTopic> trending) {
    if (trending.isEmpty) return '\u6682\u65E0\u70ED\u641C\u6570\u636E';
    final avgHeat = trending.map((t) => t.heatIndex).reduce((a, b) => a + b) ~/ trending.length;
    final topCat = _groupByCategory(trending).entries.reduce((a, b) => a.value > b.value ? a : b);
    return '\u5171\u5206\u6790 ${trending.length} \u6761\u70ED\u641C\uFF0C\u5E73\u5747\u70ED\u5EA6 $avgHeat\u3002'
        '\u6700\u70ED\u95E8\u5206\u7C7B\uFF1A${topCat.key}\uFF08${topCat.value}\u6761\uFF09\u3002'
        '\u6700\u9AD8\u70ED\u5EA6\uFF1A${trending.first.keyword}\uFF08${trending.first.heatIndex}\uFF09\u3002';
  }

  Map<String, int> _groupByCategory(List<TrendingTopic> topics) {
    final map = <String, int>{};
    for (final t in topics) { map[t.category] = (map[t.category] ?? 0) + 1; }
    return map;
  }

  List<String> _generateHashtagsForTopic(String topic, int count) {
    return [
      '#$topic', '#${topic}\u63A8\u8350', '#${topic}\u653B\u7565', '#${topic}\u5206\u4EAB',
      '#\u5E72\u8D27\u5206\u4EAB', '#\u6BCF\u65E5\u63A8\u8350', '#\u751F\u6D3B\u8BB0\u5F55',
      '#\u597D\u7269\u5206\u4EAB', '#\u5B9D\u85CF\u53D1\u73B0', '#\u5FC5\u6536\u85CF',
      '#\u6DA8\u77E5\u8BC6', '#\u5B66\u4E60\u7B14\u8BB0', '#${topic}\u7231\u597D\u8005',
      '#${topic}\u8FBE\u4EBA', '#\u4ECA\u65E5\u4EFD\u5206\u4EAB',
    ].take(count).toList();
  }

  List<CalendarEntry> _generateCalendar({
    required String topic, required List<String> platforms,
    required int days, required String frequency,
  }) {
    final entries = <CalendarEntry>[];
    final now = DateTime.now();
    final interval = switch (frequency) {
      'daily' => 1, 'every_other_day' => 2, 'three_per_week' => 2, 'weekly' => 7, _ => 2,
    };
    final contentTypes = ['\u56FE\u6587', '\u89C6\u9891', '\u95EE\u7B54', '\u5E72\u8D27', '\u79CD\u8349'];
    var dayOffset = 0;
    var typeIndex = 0;
    while (dayOffset < days) {
      for (final p in platforms) {
        final publishDate = now.add(Duration(days: dayOffset));
        final hour = _config.preferredPublishHours[dayOffset % _config.preferredPublishHours.length];
        final scheduledTime = DateTime(publishDate.year, publishDate.month, publishDate.day, hour, 0);
        final platformEnum = SocialPlatform.values.where((pp) => pp.code == p).firstOrNull;
        if (platformEnum != null) {
          entries.add(CalendarEntry(
            publishDate: scheduledTime, platform: platformEnum, topic: topic,
            contentType: contentTypes[typeIndex % contentTypes.length],
          ));
        }
      }
      typeIndex++;
      dayOffset += interval;
    }
    return entries;
  }

  String _calendarSummary(List<CalendarEntry> calendar) {
    final counts = <String, int>{};
    for (final e in calendar) { counts[e.platform.displayName] = (counts[e.platform.displayName] ?? 0) + 1; }
    final buf = StringBuffer('\u5185\u5BB9\u65E5\u5386\u6458\u8981\uFF1A\n');
    buf.writeln('\u603B\u6392\u671F\uFF1A${calendar.length} \u6761\u5185\u5BB9');
    for (final e in counts.entries) { buf.writeln('  ${e.key}\uFF1A${e.value} \u6761'); }
    if (calendar.isNotEmpty) {
      buf.writeln('\u65F6\u95F4\u8DE8\u5EA6\uFF1A${calendar.first.publishDate.toIso8601String().split('T').first}'
          ' ~ ${calendar.last.publishDate.toIso8601String().split('T').first}');
    }
    return buf.toString();
  }

  GeneratedContent _generateForPlatform(String topic, String platform, String? tone) {
    return switch (platform) {
      'xiaohongshu' => _xhsEngine.generate(topic: topic, tone: tone),
      'wechat' => _wechatEngine.generate(topic: topic, tone: tone),
      'douyin' => _douyinEngine.generate(topic: topic),
      'weibo' => _weiboEngine.generate(topic: topic, tone: tone),
      _ => _xhsEngine.generate(topic: topic, tone: tone),
    };
  }

  String _platformDisplayName(String code) => switch (code) {
    'xiaohongshu' => '\u5C0F\u7EA2\u4E66', 'wechat' => '\u516C\u4F17\u53F7',
    'douyin' => '\u6296\u97F3', 'weibo' => '\u5FAE\u535A', _ => code,
  };
}
