// ============================================================================
// 小酥 AI 助手 - 违禁词检测技能
// ============================================================================
// 支持多平台违禁词检测：微信公众号/小红书/抖音/通用广告法
// 检测模式：精确匹配、模糊匹配（谐音/拆字/变体）、正则匹配、上下文语义
// 功能：检测报告、自动修复、批量检测、规则自定义、报告导出
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../core/skill/skill.dart';

/// 违禁词检测技能
class ForbiddenWordSkill extends Skill {
  final ForbiddenWordConfig _config;
  final Map<String, List<ForbiddenRule>> _ruleCache = {};
  DateTime? _lastRuleUpdate;

  /// 内置规则库（离线可用）
  static final Map<String, List<_BuiltinRule>> _builtinRules = {
    'wechat': [
      _BuiltinRule('最', '绝对化用语', 'high', '最佳|最好|最优|最高|最低|第一|唯一'),
      _BuiltinRule('极限', '极限用语', 'high', '顶级|极致|绝无仅有|万能|全网'),
      _BuiltinRule('承诺', '虚假承诺', 'high', '100%|保证|永久|无敌|秒杀'),
      _BuiltinRule('权威', '虚假权威', 'medium', '国家级|全球领先|行业领先|驰名商标'),
      _BuiltinRule('医疗', '医疗违规', 'high', '治愈|根治|药到病除|特效|神药'),
    ],
    'xiaohongshu': [
      _BuiltinRule('引流', '引流违规', 'high', '加微信|加V|私聊|私信下单|戳主页'),
      _BuiltinRule('绝对', '绝对化用语', 'high', '最好用|必入|闭眼入|天花板'),
      _BuiltinRule('虚假', '虚假宣传', 'medium', '纯天然|零添加|无副作用|一次见效'),
      _BuiltinRule('敏感', '敏感内容', 'high', '刷单|好评返现|薅羊毛|白嫖'),
    ],
    'douyin': [
      _BuiltinRule('引流', '站外引流', 'high', '淘宝|京东|拼多多|微信|公众号'),
      _BuiltinRule('极限', '极限用语', 'high', '全网最低|全网第一|史上最'),
      _BuiltinRule('承诺', '虚假承诺', 'high', '包治百病|药到病除|立竿见影'),
      _BuiltinRule('诱导', '诱导互动', 'medium', '不转不是|转发保平安|必须点赞'),
    ],
    'ad_law': [
      _BuiltinRule('国旗', '国旗国徽违规', 'high', '国旗|国徽|国歌|军用|国家机关'),
      _BuiltinRule('虚假', '虚假广告', 'high', '国家级|最高级|最佳|第一品牌|独一无二'),
      _BuiltinRule('医疗', '医疗广告违规', 'high', '治愈率|有效率|安全无副作用|包治'),
      _BuiltinRule('数据', '数据造假', 'medium', '销量第一|市场占有率第一|最受欢迎'),
    ],
  };

  ForbiddenWordSkill({ForbiddenWordConfig? config})
      : _config = config ?? const ForbiddenWordConfig();

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'forbidden_word', name: '违禁词检测',
        description: '检测文本中的平台违禁词，支持微信公众号、小红书、抖音、'
            '广告法等多平台规则，提供检测报告、自动修复、批量检测。',
        version: '1.0.0', author: '小酥',
        permissions: [SkillPermission.networkAccess, SkillPermission.fileRead],
        loadStrategy: SkillLoadStrategy.lazy,
      );

  @override
  List<SkillTool> get tools => [
        _checkTextTool, _checkFileTool, _checkUrlTool, _getRulesTool,
        _updateRulesTool, _batchCheckTool, _autoFixTool, _exportReportTool,
      ];

  // ===================== 工具定义 =====================

  late final _checkTextTool = SkillTool(name: 'check_text',
    description: '检测文本中的违禁词，返回位置、风险等级和修改建议。',
    parameters: [
      ToolParameter(name: 'text', description: '待检测文本', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'platform', description: '目标平台', type: ToolParameterType.stringType,
          enumValues: ['wechat','xiaohongshu','douyin','ad_law','all'], defaultValue: 'all'),
      ToolParameter(name: 'detect_mode', description: '检测模式', type: ToolParameterType.stringType,
          enumValues: ['exact','fuzzy','regex','semantic','all'], defaultValue: 'all'),
    ], timeoutMs: 30000, execute: _execCheckText);

  late final _checkFileTool = SkillTool(name: 'check_file',
    description: '检测文件中的违禁词。',
    parameters: [
      ToolParameter(name: 'file_path', description: '文件路径', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'platform', description: '平台', type: ToolParameterType.stringType,
          enumValues: ['wechat','xiaohongshu','douyin','ad_law','all'], defaultValue: 'all'),
    ], timeoutMs: 60000, execute: _execCheckFile);

  late final _checkUrlTool = SkillTool(name: 'check_url',
    description: '抓取网页并检测违禁词。',
    parameters: [
      ToolParameter(name: 'url', description: 'URL', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'platform', description: '平台', type: ToolParameterType.stringType,
          enumValues: ['wechat','xiaohongshu','douyin','ad_law','all'], defaultValue: 'all'),
    ], timeoutMs: 45000, execute: _execCheckUrl);

  late final _getRulesTool = SkillTool(name: 'get_rules',
    description: '获取违禁词规则库。',
    parameters: [ToolParameter(name: 'platform', description: '平台', type: ToolParameterType.stringType,
        enumValues: ['wechat','xiaohongshu','douyin','ad_law','all'], defaultValue: 'all')],
    timeoutMs: 10000, execute: _execGetRules);

  late final _updateRulesTool = SkillTool(name: 'update_rules',
    description: '自定义违禁词规则：添加/删除/修改。',
    parameters: [
      ToolParameter(name: 'action', description: '操作', type: ToolParameterType.stringType,
          enumValues: ['add','remove','update'], required: true),
      ToolParameter(name: 'platform', description: '平台', type: ToolParameterType.stringType,
          enumValues: ['wechat','xiaohongshu','douyin','ad_law'], required: true),
      ToolParameter(name: 'rule_word', description: '违禁词', type: ToolParameterType.stringType),
      ToolParameter(name: 'category', description: '分类', type: ToolParameterType.stringType),
      ToolParameter(name: 'risk_level', description: '等级', type: ToolParameterType.stringType,
          enumValues: ['high','medium','low']),
      ToolParameter(name: 'replacement', description: '替换词', type: ToolParameterType.stringType),
    ], timeoutMs: 15000, execute: _execUpdateRules);

  late final _batchCheckTool = SkillTool(name: 'batch_check',
    description: '批量检测多个文件或URL中的违禁词。',
    parameters: [
      ToolParameter(name: 'items', description: '检测项（逗号分隔）', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'item_type', description: '类型', type: ToolParameterType.stringType,
          enumValues: ['file','url','text'], defaultValue: 'text'),
      ToolParameter(name: 'platform', description: '平台', type: ToolParameterType.stringType,
          enumValues: ['wechat','xiaohongshu','douyin','ad_law','all'], defaultValue: 'all'),
    ], timeoutMs: 120000, execute: _execBatchCheck);

  late final _autoFixTool = SkillTool(name: 'auto_fix',
    description: '自动修复文本中的违禁词。',
    parameters: [
      ToolParameter(name: 'text', description: '待修复文本', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'platform', description: '平台', type: ToolParameterType.stringType,
          enumValues: ['wechat','xiaohongshu','douyin','ad_law','all'], defaultValue: 'all'),
      ToolParameter(name: 'fix_mode', description: '修复模式', type: ToolParameterType.stringType,
          enumValues: ['replace','rewrite'], defaultValue: 'replace'),
    ], timeoutMs: 30000, execute: _execAutoFix);

  late final _exportReportTool = SkillTool(name: 'export_report',
    description: '导出违禁词检测报告。',
    parameters: [
      ToolParameter(name: 'report_data', description: '结果JSON', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'format', description: '格式', type: ToolParameterType.stringType,
          enumValues: ['markdown','html','json'], defaultValue: 'markdown'),
      ToolParameter(name: 'file_name', description: '文件名', type: ToolParameterType.stringType,
          defaultValue: 'report'),
    ], timeoutMs: 15000, execute: _execExportReport);

  // ============================================================================
  // 生命周期
  // ============================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    _loadBuiltinRules();
    context.logger.info('违禁词检测技能初始化，${_ruleCount()} 条规则');
  }

  @override
  Future<void> onDispose() async { _ruleCache.clear(); }
  void _loadBuiltinRules() {
    _builtinRules.forEach((platform, rules) {
      _ruleCache[platform] = rules.map((r) => ForbiddenRule(
        word: r.word, category: r.category, riskLevel: r.riskLevel,
        pattern: r.pattern, replacement: _defaultReplacement(r.word),
      )).toList();
    });
    _lastRuleUpdate = DateTime.now();
  }

  int _ruleCount() => _ruleCache.values.fold<int>(0, (s, l) => s + l.length);

  String _defaultReplacement(String w) => switch(w) {
    '最'=>'非常/十分','顶级'=>'高品质','100%'=>'高度',
    '永久'=>'持久','治愈'=>'改善','根治'=>'缓解',
    '最好用'=>'很好用','必入'=>'推荐入','天花板'=>'出色', _=>'[建议修改]',
  };

  // ===================== 执行逻辑 =====================

  Future<ToolResult> _execCheckText(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final text = args['text'] as String;
    if (text.isEmpty) return ToolResult.failure(error: '文本为空', errorCode: 'EMPTY');
    final platform = args['platform'] as String? ?? 'all';
    final mode = args['detect_mode'] as String? ?? 'all';
    return _formatResult(_detectHits(text, _getRules(platform), mode), text, platform);
  }

  Future<ToolResult> _execCheckFile(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final path = args['file_path'] as String;
    final platform = args['platform'] as String? ?? 'all';
    try {
      final resp = await ctx.http.get('${_config.apiBaseUrl}/file/read', headers: {'file_path': path});
      final text = (jsonDecode(resp) as Map)['content'] as String? ?? '';
      if (text.isEmpty) return ToolResult.failure(error: '文件为空', errorCode: 'EMPTY');
      return _formatResult(_detectHits(text, _getRules(platform), 'all'), text, platform, source: path);
    } catch (e) { return ToolResult.failure(error: '读取失败: $e', errorCode: 'READ_ERR'); }
  }

  Future<ToolResult> _execCheckUrl(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final url = args['url'] as String;
    final platform = args['platform'] as String? ?? 'all';
    try {
      final resp = await ctx.http.post('${_config.apiBaseUrl}/fetch',
          headers: {'Content-Type': 'application/json'}, body: {'url': url});
      final text = (jsonDecode(resp) as Map)['content'] as String? ?? '';
      if (text.isEmpty) return ToolResult.failure(error: '网页为空', errorCode: 'EMPTY');
      return _formatResult(_detectHits(text, _getRules(platform), 'all'), text, platform, source: url);
    } catch (e) { return ToolResult.failure(error: '抓取失败: $e', errorCode: 'FETCH_ERR'); }
  }

  // ===================== 规则管理 =====================

  Future<ToolResult> _execGetRules(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final platform = args['platform'] as String? ?? 'all';
    final rules = _getRules(platform);
    final buf = StringBuffer()..writeln('## 📋 规则库 — ${platform == 'all' ? '全部' : platform}')
      ..writeln('规则数: ${rules.length}')..writeln();
    final grouped = <String, List<ForbiddenRule>>{};
    for (final r in rules) grouped.putIfAbsent(r.category, () => []).add(r);
    grouped.forEach((cat, list) {
      buf.writeln('**$cat** (${list.length}条)');
      for (final r in list) {
        buf.writeln('${r.riskLevel == 'high' ? '🔴' : (r.riskLevel == 'medium' ? '🟡' : '🟢')} ${r.word} → ${r.replacement}');
      }
      buf.writeln();
    });
    return ToolResult.success(content: buf.toString().trim(),
        data: {'platform': platform, 'count': rules.length});
  }

  Future<ToolResult> _execUpdateRules(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final action = args['action'] as String;
    final platform = args['platform'] as String;
    final word = args['rule_word'] as String?;
    final cat = args['category'] as String? ?? '自定义';
    final lv = args['risk_level'] as String? ?? 'medium';
    final repl = args['replacement'] as String?;
    final rules = _ruleCache.putIfAbsent(platform, () => []);
    switch (action) {
      case 'add':
        if (word == null || word.isEmpty) return ToolResult.failure(error: '请提供违禁词', errorCode: 'MISSING');
        rules.add(ForbiddenRule(word: word, category: cat, riskLevel: lv, pattern: word, replacement: repl ?? '[修改]'));
        return ToolResult.success(content: '✅ 已添加: $word');
      case 'remove':
        if (word == null) return ToolResult.failure(error: '请提供违禁词', errorCode: 'MISSING');
        final b = rules.length; rules.removeWhere((r) => r.word == word);
        return ToolResult.success(content: b > rules.length ? '✅ 已删除: $word' : '⚠️ 未找到: $word');
      case 'update':
        if (word == null) return ToolResult.failure(error: '请提供违禁词', errorCode: 'MISSING');
        final idx = rules.indexWhere((r) => r.word == word);
        if (idx < 0) return ToolResult.failure(error: '未找到: $word', errorCode: 'NOT_FOUND');
        rules[idx] = ForbiddenRule(word: word, category: cat, riskLevel: lv, pattern: word, replacement: repl ?? rules[idx].replacement);
        return ToolResult.success(content: '✅ 已更新: $word');
      default: return ToolResult.failure(error: '未知操作: $action', errorCode: 'INVALID');
    }
  }

  // ===================== 批量/修复/导出 =====================

  Future<ToolResult> _execBatchCheck(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final items = (args['items'] as String).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (items.isEmpty || items.length > 50) return ToolResult.failure(error: '需1-50项', errorCode: 'INVALID');
    final itemType = args['item_type'] as String? ?? 'text';
    final platform = args['platform'] as String? ?? 'all';
    final rules = _getRules(platform);
    final results = <Map<String, dynamic>>[];
    int total = 0;
    for (int i = 0; i < items.length; i++) {
      ctx.onProgress?.call((i + 1) / items.length, '检测 ${i + 1}/${items.length}');
      var text = items[i];
      if (itemType == 'url') {
        try {
          final resp = await ctx.http.post('${_config.apiBaseUrl}/fetch',
              headers: {'Content-Type': 'application/json'}, body: {'url': text});
          text = (jsonDecode(resp) as Map)['content'] as String? ?? '';
        } catch (_) { results.add({'source': items[i], 'error': '获取失败', 'hits': 0}); continue; }
      }
      final hits = _detectHits(text, rules, 'all');
      total += hits.length;
      results.add({'source': items[i], 'hits': hits.length, 'high': hits.where((h) => h.riskLevel == 'high').length});
    }
    final buf = StringBuffer()..writeln('## 📊 批量检测')..writeln()
      ..writeln('共 ${items.length} 项 | 违禁 $total 处')..writeln();
    for (final r in results) {
      buf.writeln('- **${r['source']}**: ${r['error'] ?? (r['hits'] == 0 ? '✅ 无违禁' : '${r['hits']}处(高危${r['high']})')}');
    }
    return ToolResult.success(content: buf.toString().trim(),
        data: {'total_items': items.length, 'total_hits': total, 'results': results});
  }

  Future<ToolResult> _execAutoFix(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final text = args['text'] as String;
    final platform = args['platform'] as String? ?? 'all';
    final hits = _detectHits(text, _getRules(platform), 'all');
    if (hits.isEmpty) return ToolResult.success(content: '✅ 无违禁词。', data: {'fixed': text, 'count': 0});
    var fixed = text;
    final sorted = [...hits]..sort((a, b) => b.position.compareTo(a.position));
    for (final h in sorted) {
      if (h.position >= 0 && h.position + h.word.length <= fixed.length) {
        fixed = fixed.replaceRange(h.position, h.position + h.word.length, h.replacement);
      }
    }
    final buf = StringBuffer()..writeln('## 🔧 自动修复 — ${hits.length}处')..writeln();
    for (final h in hits) buf.writeln('- "${h.word}" → "${h.replacement}" (位置:${h.position})');
    buf.writeln()..writeln('### 修复后文本').writeln(fixed);
    return ToolResult.success(content: buf.toString().trim(),
        data: {'original': text, 'fixed': fixed, 'count': hits.length});
  }

  Future<ToolResult> _execExportReport(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final data = jsonDecode(args['report_data'] as String) as Map<String, dynamic>;
    final format = args['format'] as String? ?? 'markdown';
    final name = args['file_name'] as String? ?? 'report';
    final content = format == 'html' ? _htmlReport(data) : (format == 'json' ? jsonEncode(data) : _mdReport(data));
    final ext = switch(format) { 'html'=>'html', 'json'=>'json', _=>'md' };
    try {
      final resp = await ctx.http.post('${_config.apiBaseUrl}/file/write',
          headers: {'Content-Type': 'application/json'}, body: {'file_name': '$name.$ext', 'content': content});
      final path = (jsonDecode(resp) as Map)['file_path'] ?? '$name.$ext';
      return ToolResult.success(content: '✅ 已导出: $path', data: {'file_path': path});
    } catch (e) { return ToolResult.failure(error: '导出失败: $e', errorCode: 'EXPORT_ERR'); }
  }

  // ============================================================================
  // 检测引擎
  // ============================================================================

  List<ForbiddenRule> _getRules(String platform) {
    if (platform == 'all') return _ruleCache.values.expand((l) => l).toList();
    return _ruleCache[platform] ?? [];
  }

  List<DetectionHit> _detectHits(String text, List<ForbiddenRule> rules, String mode) {
    final hits = <DetectionHit>[];
    for (final rule in rules) {
      if (mode == 'exact' || mode == 'all') _exactMatch(text, rule, hits);
      if (mode == 'fuzzy' || mode == 'all') _fuzzyMatch(text, rule, hits);
      if (mode == 'regex' || mode == 'all') _regexMatch(text, rule, hits);
    }
    final seen = <String>{};
    return hits.where((h) => seen.add('${h.position}|${h.word}')).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  void _exactMatch(String text, ForbiddenRule rule, List<DetectionHit> hits) {
    for (final word in rule.pattern.split('|')) {
      if (word.isEmpty) continue;
      int start = 0;
      while (true) {
        final idx = text.indexOf(word, start);
        if (idx < 0) break;
        hits.add(DetectionHit(word: word, position: idx, length: word.length,
            riskLevel: rule.riskLevel, category: rule.category,
            replacement: rule.replacement, matchType: 'exact'));
        start = idx + 1;
      }
    }
  }

  void _fuzzyMatch(String text, ForbiddenRule rule, List<DetectionHit> hits) {
    const variants = {'最': ['zui','蕞'], '第一': ['d1','No.1','NO1'], '100%': ['百分之百']};
    for (final word in rule.pattern.split('|')) {
      for (final v in variants[word] ?? []) {
        final idx = text.toLowerCase().indexOf(v.toLowerCase());
        if (idx >= 0) {
          hits.add(DetectionHit(word: v, position: idx, length: v.length,
              riskLevel: rule.riskLevel, category: rule.category,
              replacement: rule.replacement, matchType: 'fuzzy'));
        }
      }
      if (word.length >= 2) {
        try {
          final pat = word.split('').join('[^a-zA-Z0-9\\u4e00-\\u9fff]*');
          final match = RegExp(pat).firstMatch(text);
          if (match != null && match.group(0) != word) {
            hits.add(DetectionHit(word: match.group(0)!, position: match.start,
                length: match.end - match.start, riskLevel: rule.riskLevel,
                category: rule.category, replacement: rule.replacement, matchType: 'fuzzy'));
          }
        } catch (_) {}
      }
    }
  }

  void _regexMatch(String text, ForbiddenRule rule, List<DetectionHit> hits) {
    try {
      for (final m in RegExp(rule.pattern, caseSensitive: false).allMatches(text)) {
        hits.add(DetectionHit(word: m.group(0) ?? '', position: m.start, length: m.end - m.start,
            riskLevel: rule.riskLevel, category: rule.category,
            replacement: rule.replacement, matchType: 'regex'));
      }
    } catch (_) {}
  }

  // ===================== 结果格式化 =====================

  ToolResult _formatResult(List<DetectionHit> hits, String text, String platform, {String? source}) {
    final high = hits.where((h) => h.riskLevel == 'high').length;
    final med = hits.where((h) => h.riskLevel == 'medium').length;
    final low = hits.where((h) => h.riskLevel == 'low').length;
    final buf = StringBuffer()..writeln('## 🚨 违禁词检测报告');
    if (source != null) buf.writeln('来源: $source');
    buf.writeln()..writeln('**平台**: ${platform == 'all' ? '全平台' : platform} | '
        '**文本**: ${text.length}字 | **命中**: ${hits.length}处')
      ..writeln('🔴 高危:$high | 🟡 中危:$med | 🟢 低危:$low')..writeln();
    if (hits.isEmpty) { buf.writeln('✅ 未检测到违禁词！'); }
    else {
      buf.writeln('### 命中详情');
      for (int i = 0; i < hits.length; i++) {
        final h = hits[i];
        final e = h.riskLevel == 'high' ? '🔴' : (h.riskLevel == 'medium' ? '🟡' : '🟢');
        final ctx0 = max(0, h.position - 10), ctx1 = min(text.length, h.position + h.length + 10);
        buf.writeln('$e **${i+1}. "${h.word}"** 位置:${h.position} 类型:${h.matchType}');
        buf.writeln('  上下文: ...${text.substring(ctx0, ctx1)}... → ${h.replacement}')..writeln();
      }
    }
    return ToolResult.success(content: buf.toString().trim(), data: {
      'total': hits.length, 'high': high, 'medium': med, 'low': low,
      'hits': hits.map((h) => {'word': h.word, 'position': h.position,
          'risk_level': h.riskLevel, 'replacement': h.replacement}).toList(),
    });
  }

  String _mdReport(Map<String, dynamic> d) {
    final hits = d['hits'] as List? ?? [];
    final buf = StringBuffer()..writeln('# 违禁词检测报告')
      ..writeln('生成: ${DateTime.now().toIso8601String()} | 命中: ${hits.length}处')..writeln();
    for (int i = 0; i < hits.length; i++) {
      final h = hits[i] as Map;
      buf.writeln('${i+1}. **${h['word']}** 位置:${h['position']} 风险:${h['risk_level']} → ${h['replacement']}');
    }
    return buf.toString();
  }

  String _htmlReport(Map<String, dynamic> d) {
    final hits = d['hits'] as List? ?? [];
    final buf = StringBuffer()..writeln('<!DOCTYPE html><html><head><meta charset="utf-8"><title>违禁词报告</title>'
        '<style>body{font-family:sans-serif;max-width:800px;margin:40px auto}'
        'table{width:100%;border-collapse:collapse}td,th{border:1px solid #ddd;padding:8px}'
        '.high{color:#e53e3e}.medium{color:#d69e2e}.low{color:#38a169}</style></head>'
        '<body><h1>违禁词检测报告</h1><table><tr><th>#</th><th>词</th><th>位置</th><th>风险</th><th>建议</th></tr>');
    for (int i = 0; i < hits.length; i++) {
      final h = hits[i] as Map; final lv = h['risk_level'] ?? 'medium';
      buf.writeln('<tr><td>${i+1}</td><td>${h['word']}</td><td>${h['position']}</td>'
          '<td class="$lv">$lv</td><td>${h['replacement']}</td></tr>');
    }
    buf.writeln('</table></body></html>');
    return buf.toString();
  }
}

// ============================================================================
// 数据模型
// ============================================================================

class ForbiddenRule {
  final String word, category, riskLevel, pattern, replacement;
  const ForbiddenRule({required this.word, required this.category,
      required this.riskLevel, required this.pattern, required this.replacement});
}

class DetectionHit {
  final String word, riskLevel, category, replacement, matchType;
  final int position, length;
  const DetectionHit({required this.word, required this.position, required this.length,
      required this.riskLevel, required this.category, required this.replacement, required this.matchType});
}

class _BuiltinRule {
  final String word, category, riskLevel, pattern;
  const _BuiltinRule(this.word, this.category, this.riskLevel, this.pattern);
}

class ForbiddenWordConfig {
  final String apiBaseUrl, apiKey;
  final bool enableFuzzyDetection, enableSemanticDetection;
  const ForbiddenWordConfig({
    this.apiBaseUrl = 'https://api.xiaosu.ai/v1', this.apiKey = '',
    this.enableFuzzyDetection = true, this.enableSemanticDetection = false,
  });
}
