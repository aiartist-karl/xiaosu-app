// ============================================================================
// 小酥 AI 助手 - 图表生成技能
// ============================================================================
// 基于 fl_chart 引擎生成多种图表：折线图/柱状图/饼图/面积图/散点图/
// 雷达图/热力图/词云/混合图表
// 支持样式自定义、数据清洗、多格式导出、响应式尺寸
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../core/skill/skill.dart';

/// 图表生成技能
class ChartSkill extends Skill {
  final ChartSkillConfig _config;

  /// 生成的图表缓存
  final Map<String, _ChartCache> _chartCache = {};

  /// 默认配色方案
  static const List<int> _defaultColors = [
    0xFF4C78A8, 0xFFF58518, 0xFFE45756, 0xFF54A24B,
    0xFFEECA23, 0xFF72B7B2, 0xFF5C7AEA, 0xFFFF9DA6,
    0xFF9D755D, 0xFFB279A2,
  ];

  ChartSkill({ChartSkillConfig? config})
      : _config = config ?? const ChartSkillConfig();

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'chart', name: '图表生成',
        description: '生成多种数据可视化图表：折线图、柱状图、饼图、面积图、'
            '散点图、雷达图、热力图、词云、混合图表。支持样式自定义和多格式导出。',
        version: '1.0.0', author: '小酥',
        permissions: [SkillPermission.networkAccess, SkillPermission.fileWrite],
        loadStrategy: SkillLoadStrategy.lazy,
      );

  @override
  List<SkillTool> get tools => [
        _lineChartTool, _barChartTool, _pieChartTool, _areaChartTool,
        _scatterChartTool, _radarChartTool, _heatmapTool, _wordCloudTool,
        _mixedChartTool, _customizeStyleTool, _exportChartTool,
      ];

  // ===================== 工具定义 =====================

  late final _lineChartTool = SkillTool(name: 'create_line_chart',
    description: '创建折线图，支持多线/平滑/标记点。',
    parameters: [
      ToolParameter(name: 'data', description: '数据JSON：{labels:[], series:[{name,values:[]}]}',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'title', description: '标题', type: ToolParameterType.stringType),
      ToolParameter(name: 'smooth', description: '平滑曲线', type: ToolParameterType.boolType, defaultValue: false),
      ToolParameter(name: 'show_points', description: '显示标记点', type: ToolParameterType.boolType, defaultValue: true),
      ToolParameter(name: 'width', description: '宽度', type: ToolParameterType.intType, minValue: 200, maxValue: 2000, defaultValue: 800),
      ToolParameter(name: 'height', description: '高度', type: ToolParameterType.intType, minValue: 200, maxValue: 2000, defaultValue: 500),
    ], timeoutMs: 30000, execute: _execLineChart);

  late final _barChartTool = SkillTool(name: 'create_bar_chart',
    description: '创建柱状图，支持堆叠/分组/水平。',
    parameters: [
      ToolParameter(name: 'data', description: '数据JSON', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'title', description: '标题', type: ToolParameterType.stringType),
      ToolParameter(name: 'bar_type', description: '柱状类型', type: ToolParameterType.stringType,
          enumValues: ['grouped', 'stacked', 'horizontal'], defaultValue: 'grouped'),
      ToolParameter(name: 'width', description: '宽度', type: ToolParameterType.intType, defaultValue: 800),
      ToolParameter(name: 'height', description: '高度', type: ToolParameterType.intType, defaultValue: 500),
    ], timeoutMs: 30000, execute: _execBarChart);

  late final _pieChartTool = SkillTool(name: 'create_pie_chart',
    description: '创建饼图，支持环形/标签显示。',
    parameters: [
      ToolParameter(name: 'data', description: '数据JSON：[{label,value}]', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'title', description: '标题', type: ToolParameterType.stringType),
      ToolParameter(name: 'donut', description: '环形图', type: ToolParameterType.boolType, defaultValue: false),
      ToolParameter(name: 'show_labels', description: '显示标签', type: ToolParameterType.boolType, defaultValue: true),
      ToolParameter(name: 'width', description: '宽度', type: ToolParameterType.intType, defaultValue: 600),
      ToolParameter(name: 'height', description: '高度', type: ToolParameterType.intType, defaultValue: 600),
    ], timeoutMs: 30000, execute: _execPieChart);

  late final _areaChartTool = SkillTool(name: 'create_area_chart',
    description: '创建面积图，支持堆叠/透明。',
    parameters: [
      ToolParameter(name: 'data', description: '数据JSON', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'title', description: '标题', type: ToolParameterType.stringType),
      ToolParameter(name: 'stacked', description: '堆叠', type: ToolParameterType.boolType, defaultValue: false),
      ToolParameter(name: 'opacity', description: '透明度', type: ToolParameterType.doubleType, minValue: 0.1, maxValue: 1.0, defaultValue: 0.4),
      ToolParameter(name: 'width', description: '宽度', type: ToolParameterType.intType, defaultValue: 800),
      ToolParameter(name: 'height', description: '高度', type: ToolParameterType.intType, defaultValue: 500),
    ], timeoutMs: 30000, execute: _execAreaChart);

  late final _scatterChartTool = SkillTool(name: 'create_scatter_chart',
    description: '创建散点图，支持气泡/回归线。',
    parameters: [
      ToolParameter(name: 'data', description: '数据JSON：{series:[{name, points:[{x,y,size?}]}]}',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'title', description: '标题', type: ToolParameterType.stringType),
      ToolParameter(name: 'bubble', description: '气泡模式', type: ToolParameterType.boolType, defaultValue: false),
      ToolParameter(name: 'regression', description: '回归线', type: ToolParameterType.boolType, defaultValue: false),
      ToolParameter(name: 'width', description: '宽度', type: ToolParameterType.intType, defaultValue: 800),
      ToolParameter(name: 'height', description: '高度', type: ToolParameterType.intType, defaultValue: 500),
    ], timeoutMs: 30000, execute: _execScatterChart);

  late final _radarChartTool = SkillTool(name: 'create_radar_chart',
    description: '创建雷达图。',
    parameters: [
      ToolParameter(name: 'data', description: '数据JSON：{axes:[], series:[{name,values:[]}]}',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'title', description: '标题', type: ToolParameterType.stringType),
      ToolParameter(name: 'width', description: '宽度', type: ToolParameterType.intType, defaultValue: 600),
      ToolParameter(name: 'height', description: '高度', type: ToolParameterType.intType, defaultValue: 600),
    ], timeoutMs: 30000, execute: _execRadarChart);

  late final _heatmapTool = SkillTool(name: 'create_heatmap',
    description: '创建热力图。',
    parameters: [
      ToolParameter(name: 'data', description: '数据JSON：{xLabels:[], yLabels:[], values:[[...]]}',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'title', description: '标题', type: ToolParameterType.stringType),
      ToolParameter(name: 'color_scheme', description: '配色', type: ToolParameterType.stringType,
          enumValues: ['blue', 'red', 'green', 'viridis', 'plasma'], defaultValue: 'blue'),
      ToolParameter(name: 'width', description: '宽度', type: ToolParameterType.intType, defaultValue: 800),
      ToolParameter(name: 'height', description: '高度', type: ToolParameterType.intType, defaultValue: 500),
    ], timeoutMs: 30000, execute: _execHeatmap);

  late final _wordCloudTool = SkillTool(name: 'create_word_cloud',
    description: '创建词云图。',
    parameters: [
      ToolParameter(name: 'data', description: '数据JSON：[{word, weight}]',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'title', description: '标题', type: ToolParameterType.stringType),
      ToolParameter(name: 'max_words', description: '最大词数', type: ToolParameterType.intType, defaultValue: 100),
      ToolParameter(name: 'width', description: '宽度', type: ToolParameterType.intType, defaultValue: 800),
      ToolParameter(name: 'height', description: '高度', type: ToolParameterType.intType, defaultValue: 500),
    ], timeoutMs: 30000, execute: _execWordCloud);

  late final _mixedChartTool = SkillTool(name: 'create_mixed_chart',
    description: '创建混合图表（如柱状+折线组合）。',
    parameters: [
      ToolParameter(name: 'data', description: '数据JSON：{labels:[], series:[{name,type,values:[]}]}',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'title', description: '标题', type: ToolParameterType.stringType),
      ToolParameter(name: 'dual_axis', description: '双Y轴', type: ToolParameterType.boolType, defaultValue: false),
      ToolParameter(name: 'width', description: '宽度', type: ToolParameterType.intType, defaultValue: 800),
      ToolParameter(name: 'height', description: '高度', type: ToolParameterType.intType, defaultValue: 500),
    ], timeoutMs: 30000, execute: _execMixedChart);

  late final _customizeStyleTool = SkillTool(name: 'customize_style',
    description: '自定义图表样式：颜色/字体/背景/图例/网格线/动画。',
    parameters: [
      ToolParameter(name: 'chart_id', description: '图表ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'background_color', description: '背景色(ARGB)', type: ToolParameterType.stringType),
      ToolParameter(name: 'title_font_size', description: '标题字号', type: ToolParameterType.intType),
      ToolParameter(name: 'show_grid', description: '显示网格', type: ToolParameterType.boolType),
      ToolParameter(name: 'show_legend', description: '显示图例', type: ToolParameterType.boolType),
      ToolParameter(name: 'colors', description: '自定义配色(逗号分隔ARGB)', type: ToolParameterType.stringType),
      ToolParameter(name: 'animation', description: '启用动画', type: ToolParameterType.boolType, defaultValue: true),
    ], timeoutMs: 15000, execute: _execCustomizeStyle);

  late final _exportChartTool = SkillTool(name: 'export_chart',
    description: '导出图表为PNG/SVG/PDF。',
    parameters: [
      ToolParameter(name: 'chart_id', description: '图表ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'format', description: '格式', type: ToolParameterType.stringType,
          enumValues: ['png', 'svg', 'pdf'], defaultValue: 'png'),
      ToolParameter(name: 'scale', description: '缩放倍率', type: ToolParameterType.doubleType,
          minValue: 1.0, maxValue: 4.0, defaultValue: 1.0),
      ToolParameter(name: 'file_name', description: '文件名', type: ToolParameterType.stringType),
    ], timeoutMs: 30000, execute: _execExportChart);

  // ============================================================================
  // 生命周期
  // ============================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('图表生成技能初始化完成');
  }

  @override
  Future<void> onDispose() async { _chartCache.clear(); }

  // ============================================================================
  // 图表执行 — 折线图
  // ============================================================================

  Future<ToolResult> _execLineChart(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final raw = args['data'] as String;
    final title = args['title'] as String? ?? '折线图';
    final smooth = args['smooth'] as bool? ?? false;
    final showPts = args['show_points'] as bool? ?? true;
    final w = args['width'] as int? ?? 800;
    final h = args['height'] as int? ?? 500;

    final data = _parseData(raw);
    if (data == null) return ToolResult.failure(error: '数据解析失败', errorCode: 'PARSE_ERR');
    final labels = (data['labels'] as List? ?? []).cast<String>();
    final series = (data['series'] as List? ?? []).cast<Map<String, dynamic>>();
    if (series.isEmpty) return ToolResult.failure(error: '缺少 series 数据', errorCode: 'NO_DATA');

    ctx.logger.info('折线图: ${series.length}条线, ${labels.length}个标签');
    final chartId = _genChartId();
    final config = _ChartConfig(
      id: chartId, type: 'line', title: title, width: w, height: h,
      data: data, options: {'smooth': smooth, 'show_points': showPts},
    );
    _chartCache[chartId] = _ChartCache(config: config, createdAt: DateTime.now());
    final imgPath = await _renderChart(ctx, config);

    return ToolResult.success(content: '✅ 折线图已生成\n图表ID: $chartId\n尺寸: ${w}x$h',
        data: {'chart_id': chartId, 'type': 'line', 'series_count': series.length},
        attachments: [ToolAttachment(type: AttachmentType.image, uri: imgPath, description: title)]);
  }

  // ============================================================================
  // 图表执行 — 柱状图
  // ============================================================================

  Future<ToolResult> _execBarChart(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final data = _parseData(args['data'] as String);
    if (data == null) return ToolResult.failure(error: '数据解析失败', errorCode: 'PARSE_ERR');
    final barType = args['bar_type'] as String? ?? 'grouped';
    final title = args['title'] as String? ?? '柱状图';
    final w = args['width'] as int? ?? 800;
    final h = args['height'] as int? ?? 500;
    final chartId = _genChartId();
    final config = _ChartConfig(id: chartId, type: 'bar', title: title, width: w, height: h,
        data: data, options: {'bar_type': barType});
    _chartCache[chartId] = _ChartCache(config: config, createdAt: DateTime.now());
    final imgPath = await _renderChart(ctx, config);
    return ToolResult.success(content: '✅ 柱状图已生成\nID: $chartId | 类型: $barType',
        data: {'chart_id': chartId, 'type': 'bar'},
        attachments: [ToolAttachment(type: AttachmentType.image, uri: imgPath, description: title)]);
  }

  // ============================================================================
  // 图表执行 — 饼图
  // ============================================================================

  Future<ToolResult> _execPieChart(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final data = _parseData(args['data'] as String);
    if (data == null) return ToolResult.failure(error: '数据解析失败', errorCode: 'PARSE_ERR');
    final donut = args['donut'] as bool? ?? false;
    final showLabels = args['show_labels'] as bool? ?? true;
    final title = args['title'] as String? ?? '饼图';
    final w = args['width'] as int? ?? 600;
    final h = args['height'] as int? ?? 600;
    final chartId = _genChartId();
    final config = _ChartConfig(id: chartId, type: 'pie', title: title, width: w, height: h,
        data: data, options: {'donut': donut, 'show_labels': showLabels});
    _chartCache[chartId] = _ChartCache(config: config, createdAt: DateTime.now());
    final imgPath = await _renderChart(ctx, config);
    return ToolResult.success(content: '✅ 饼图已生成\nID: $chartId | ${donut ? "环形" : "实心"}',
        data: {'chart_id': chartId, 'type': 'pie'},
        attachments: [ToolAttachment(type: AttachmentType.image, uri: imgPath, description: title)]);
  }

  // ============================================================================
  // 图表执行 — 面积图
  // ============================================================================

  Future<ToolResult> _execAreaChart(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final data = _parseData(args['data'] as String);
    if (data == null) return ToolResult.failure(error: '数据解析失败', errorCode: 'PARSE_ERR');
    final stacked = args['stacked'] as bool? ?? false;
    final opacity = (args['opacity'] as num?)?.toDouble() ?? 0.4;
    final title = args['title'] as String? ?? '面积图';
    final w = args['width'] as int? ?? 800;
    final h = args['height'] as int? ?? 500;
    final chartId = _genChartId();
    final config = _ChartConfig(id: chartId, type: 'area', title: title, width: w, height: h,
        data: data, options: {'stacked': stacked, 'opacity': opacity});
    _chartCache[chartId] = _ChartCache(config: config, createdAt: DateTime.now());
    final imgPath = await _renderChart(ctx, config);
    return ToolResult.success(content: '✅ 面积图已生成\nID: $chartId',
        data: {'chart_id': chartId, 'type': 'area'},
        attachments: [ToolAttachment(type: AttachmentType.image, uri: imgPath, description: title)]);
  }

  // ============================================================================
  // 图表执行 — 散点图
  // ============================================================================

  Future<ToolResult> _execScatterChart(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final data = _parseData(args['data'] as String);
    if (data == null) return ToolResult.failure(error: '数据解析失败', errorCode: 'PARSE_ERR');
    final bubble = args['bubble'] as bool? ?? false;
    final regression = args['regression'] as bool? ?? false;
    final title = args['title'] as String? ?? '散点图';
    final w = args['width'] as int? ?? 800;
    final h = args['height'] as int? ?? 500;
    final chartId = _genChartId();
    final config = _ChartConfig(id: chartId, type: 'scatter', title: title, width: w, height: h,
        data: data, options: {'bubble': bubble, 'regression': regression});
    _chartCache[chartId] = _ChartCache(config: config, createdAt: DateTime.now());
    final imgPath = await _renderChart(ctx, config);
    return ToolResult.success(content: '✅ 散点图已生成\nID: $chartId',
        data: {'chart_id': chartId, 'type': 'scatter'},
        attachments: [ToolAttachment(type: AttachmentType.image, uri: imgPath, description: title)]);
  }

  // ============================================================================
  // 图表执行 — 雷达图
  // ============================================================================

  Future<ToolResult> _execRadarChart(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final data = _parseData(args['data'] as String);
    if (data == null) return ToolResult.failure(error: '数据解析失败', errorCode: 'PARSE_ERR');
    final title = args['title'] as String? ?? '雷达图';
    final w = args['width'] as int? ?? 600;
    final h = args['height'] as int? ?? 600;
    final chartId = _genChartId();
    final config = _ChartConfig(id: chartId, type: 'radar', title: title, width: w, height: h,
        data: data, options: {});
    _chartCache[chartId] = _ChartCache(config: config, createdAt: DateTime.now());
    final imgPath = await _renderChart(ctx, config);
    return ToolResult.success(content: '✅ 雷达图已生成\nID: $chartId',
        data: {'chart_id': chartId, 'type': 'radar'},
        attachments: [ToolAttachment(type: AttachmentType.image, uri: imgPath, description: title)]);
  }

  // ============================================================================
  // 图表执行 — 热力图
  // ============================================================================

  Future<ToolResult> _execHeatmap(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final data = _parseData(args['data'] as String);
    if (data == null) return ToolResult.failure(error: '数据解析失败', errorCode: 'PARSE_ERR');
    final colorScheme = args['color_scheme'] as String? ?? 'blue';
    final title = args['title'] as String? ?? '热力图';
    final w = args['width'] as int? ?? 800;
    final h = args['height'] as int? ?? 500;
    final chartId = _genChartId();
    final config = _ChartConfig(id: chartId, type: 'heatmap', title: title, width: w, height: h,
        data: data, options: {'color_scheme': colorScheme});
    _chartCache[chartId] = _ChartCache(config: config, createdAt: DateTime.now());
    final imgPath = await _renderChart(ctx, config);
    return ToolResult.success(content: '✅ 热力图已生成\nID: $chartId | 配色: $colorScheme',
        data: {'chart_id': chartId, 'type': 'heatmap'},
        attachments: [ToolAttachment(type: AttachmentType.image, uri: imgPath, description: title)]);
  }

  // ============================================================================
  // 图表执行 — 词云
  // ============================================================================

  Future<ToolResult> _execWordCloud(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final data = _parseData(args['data'] as String);
    if (data == null) return ToolResult.failure(error: '数据解析失败', errorCode: 'PARSE_ERR');
    final maxWords = args['max_words'] as int? ?? 100;
    final title = args['title'] as String? ?? '词云';
    final w = args['width'] as int? ?? 800;
    final h = args['height'] as int? ?? 500;
    final chartId = _genChartId();
    final config = _ChartConfig(id: chartId, type: 'wordcloud', title: title, width: w, height: h,
        data: data, options: {'max_words': maxWords});
    _chartCache[chartId] = _ChartCache(config: config, createdAt: DateTime.now());
    final imgPath = await _renderChart(ctx, config);
    return ToolResult.success(content: '✅ 词云已生成\nID: $chartId',
        data: {'chart_id': chartId, 'type': 'wordcloud'},
        attachments: [ToolAttachment(type: AttachmentType.image, uri: imgPath, description: title)]);
  }

  // ============================================================================
  // 图表执行 — 混合图表
  // ============================================================================

  Future<ToolResult> _execMixedChart(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final data = _parseData(args['data'] as String);
    if (data == null) return ToolResult.failure(error: '数据解析失败', errorCode: 'PARSE_ERR');
    final dualAxis = args['dual_axis'] as bool? ?? false;
    final title = args['title'] as String? ?? '混合图表';
    final w = args['width'] as int? ?? 800;
    final h = args['height'] as int? ?? 500;
    final chartId = _genChartId();
    final config = _ChartConfig(id: chartId, type: 'mixed', title: title, width: w, height: h,
        data: data, options: {'dual_axis': dualAxis});
    _chartCache[chartId] = _ChartCache(config: config, createdAt: DateTime.now());
    final imgPath = await _renderChart(ctx, config);
    return ToolResult.success(content: '✅ 混合图表已生成\nID: $chartId${dualAxis ? " (双Y轴)" : ""}',
        data: {'chart_id': chartId, 'type': 'mixed'},
        attachments: [ToolAttachment(type: AttachmentType.image, uri: imgPath, description: title)]);
  }

  // ============================================================================
  // 样式自定义 / 导出
  // ============================================================================

  Future<ToolResult> _execCustomizeStyle(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final chartId = args['chart_id'] as String;
    final cached = _chartCache[chartId];
    if (cached == null) return ToolResult.failure(error: '未找到图表: $chartId', errorCode: 'NOT_FOUND');
    final style = cached.config.style;
    if (args['background_color'] != null) style.backgroundColor = int.tryParse(args['background_color']) ?? style.backgroundColor;
    if (args['title_font_size'] != null) style.titleFontSize = args['title_font_size'] as int;
    if (args['show_grid'] != null) style.showGrid = args['show_grid'] as bool;
    if (args['show_legend'] != null) style.showLegend = args['show_legend'] as bool;
    if (args['animation'] != null) style.animation = args['animation'] as bool;
    if (args['colors'] != null) {
      style.colors = (args['colors'] as String).split(',').map((s) => int.tryParse(s.trim()) ?? 0).where((c) => c != 0).toList();
    }
    ctx.logger.info('样式更新: $chartId');
    return ToolResult.success(content: '✅ 样式已更新\n图表ID: $chartId');
  }

  Future<ToolResult> _execExportChart(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final chartId = args['chart_id'] as String;
    final format = args['format'] as String? ?? 'png';
    final scale = (args['scale'] as num?)?.toDouble() ?? 1.0;
    final fileName = args['file_name'] as String? ?? 'chart_$chartId';
    final cached = _chartCache[chartId];
    if (cached == null) return ToolResult.failure(error: '未找到图表: $chartId', errorCode: 'NOT_FOUND');

    ctx.logger.info('导出图表: $chartId -> $format (${scale}x)');
    try {
      final resp = await ctx.http.post('${_config.renderBaseUrl}/export',
          headers: {'Content-Type': 'application/json'},
          body: {
            'chart_id': chartId, 'format': format, 'scale': scale,
            'width': (cached.config.width * scale).round(),
            'height': (cached.config.height * scale).round(),
            'file_name': '$fileName.$format',
            'config': cached.config.toJson(),
          });
      final result = jsonDecode(resp) as Map<String, dynamic>;
      final filePath = result['file_path'] ?? '$fileName.$format';
      return ToolResult.success(content: '✅ 图表已导出: $filePath',
          data: {'chart_id': chartId, 'format': format, 'file_path': filePath},
          attachments: [ToolAttachment(type: AttachmentType.file, uri: filePath)]);
    } catch (e) {
      return ToolResult.failure(error: '导出失败: $e', errorCode: 'EXPORT_ERR');
    }
  }

  // ============================================================================
  // 内部方法
  // ============================================================================

  Map<String, dynamic>? _parseData(String raw) {
    try {
      // 尝试 JSON 解析
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // 尝试 CSV 解析
      return _parseCsv(raw);
    }
  }

  Map<String, dynamic>? _parseCsv(String csv) {
    final lines = csv.trim().split('\n').map((l) => l.split(',').map((c) => c.trim()).toList()).toList();
    if (lines.length < 2) return null;
    final headers = lines.first;
    final labels = <String>[];
    final seriesMap = <String, List<double>>{};
    for (int i = 1; i < headers.length; i++) seriesMap[headers[i]] = [];
    for (int r = 1; r < lines.length; r++) {
      final row = lines[r];
      if (row.isEmpty) continue;
      labels.add(row.first);
      for (int c = 1; c < headers.length && c < row.length; c++) {
        seriesMap[headers[c]]?.add(double.tryParse(row[c]) ?? 0);
      }
    }
    return {
      'labels': labels,
      'series': seriesMap.entries.map((e) => {'name': e.key, 'values': e.value}).toList(),
    };
  }

  String _genChartId() => 'chart_${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

  Future<String> _renderChart(SkillContext ctx, _ChartConfig config) async {
    final resp = await ctx.http.post('${_config.renderBaseUrl}/render',
        headers: {'Content-Type': 'application/json'},
        body: config.toJson());
    final result = jsonDecode(resp) as Map<String, dynamic>;
    return result['image_path'] as String? ?? '';
  }
}

// ============================================================================
// 数据模型
// ============================================================================

class _ChartConfig {
  final String id, type, title;
  final int width, height;
  final Map<String, dynamic> data, options;
  final ChartStyle style;

  _ChartConfig({required this.id, required this.type, required this.title,
      required this.width, required this.height, required this.data,
      required this.options}) : style = ChartStyle();

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'title': title, 'width': width, 'height': height,
    'data': data, 'options': options, 'style': style.toJson(),
  };
}

class ChartStyle {
  int backgroundColor = 0xFFFFFFFF;
  int titleFontSize = 18;
  bool showGrid = true;
  bool showLegend = true;
  bool animation = true;
  List<int> colors = [...ChartSkill._defaultColors];

  Map<String, dynamic> toJson() => {
    'bg_color': backgroundColor, 'title_font_size': titleFontSize,
    'show_grid': showGrid, 'show_legend': showLegend,
    'animation': animation, 'colors': colors,
  };
}

class _ChartCache {
  final _ChartConfig config;
  final DateTime createdAt;
  _ChartCache({required this.config, required this.createdAt});
}

class ChartSkillConfig {
  final String renderBaseUrl;
  final String apiKey;
  final Duration cacheExpiry;
  const ChartSkillConfig({
    this.renderBaseUrl = 'https://api.xiaosu.ai/v1/chart',
    this.apiKey = '',
    this.cacheExpiry = const Duration(hours: 1),
  });
}
