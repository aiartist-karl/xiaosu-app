// ============================================================================
// 小酥 AI 助手 - 联网搜索技能
// ============================================================================
// 提供网页搜索和网页内容抓取功能
// 支持多搜索引擎（通用搜索、学术搜索、图片搜索等）
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../core/skill/skill.dart';

/// 联网搜索技能
/// 提供 search_web 和 fetch_web 两个核心工具
class WebSearchSkill extends Skill {
  /// 搜索引擎配置
  final WebSearchConfig _config;

  /// 搜索结果缓存（避免重复搜索）
  final Map<String, _CachedSearchResult> _cache = {};

  /// 缓存过期时间
  static const Duration _cacheDuration = Duration(minutes: 10);

  WebSearchSkill({WebSearchConfig? config})
      : _config = config ?? const WebSearchConfig();

  // ============================================================================
  // 技能元数据
  // ============================================================================

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'web_search',
        name: '联网搜索',
        description: '搜索互联网信息，抓取网页内容。'
            '支持通用搜索、学术搜索、图片搜索等多种搜索引擎。'
            '可以获取最新资讯、验证事实、查找参考资料。',
        version: '1.0.0',
        author: '小酥',
        permissions: [SkillPermission.networkAccess],
        loadStrategy: SkillLoadStrategy.lazy,
      );

  @override
  List<SkillTool> get tools => [
        _searchWebTool,
        _fetchWebTool,
      ];

  // ============================================================================
  // 工具定义
  // ============================================================================

  /// search_web 工具
  /// 在互联网上搜索信息
  late final SkillTool _searchWebTool = SkillTool(
    name: 'search_web',
    description: '在互联网上搜索信息。支持通用搜索、学术搜索、电商搜索、'
        '图片搜索等。返回搜索结果标题、摘要和链接。'
        '适用于查找最新资讯、验证事实、获取参考资料等场景。',
    parameters: [
      ToolParameter(
        name: 'query',
        description: '搜索关键词，建议使用简洁的互联网检索词',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'engine',
        description: '搜索引擎类型',
        type: ToolParameterType.stringType,
        enumValues: [
          'general',
          'scholar',
          'ecom',
          'image',
          'visual',
        ],
        defaultValue: 'general',
      ),
      ToolParameter(
        name: 'freshness',
        description: '时间范围（天），仅返回最近 N 天内的结果',
        type: ToolParameterType.intType,
        minValue: 1,
        maxValue: 365,
      ),
      ToolParameter(
        name: 'max_results',
        description: '最大返回结果数',
        type: ToolParameterType.intType,
        minValue: 1,
        maxValue: 20,
        defaultValue: 10,
      ),
      ToolParameter(
        name: 'response_length',
        description: '结果摘要长度',
        type: ToolParameterType.stringType,
        enumValues: ['short', 'medium', 'long'],
        defaultValue: 'medium',
      ),
    ],
    timeoutMs: 30000,
    execute: _executeSearchWeb,
  );

  /// fetch_web 工具
  /// 抓取指定 URL 的网页内容
  late final SkillTool _fetchWebTool = SkillTool(
    name: 'fetch_web',
    description: '获取指定 URL 网页的文本内容。'
        '用于深入阅读搜索结果、获取网页完整信息。'
        '支持提取正文内容，自动过滤广告和无关元素。',
    parameters: [
      ToolParameter(
        name: 'url',
        description: '要抓取的网页 URL',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'response_length',
        description: '返回内容长度',
        type: ToolParameterType.stringType,
        enumValues: ['short', 'medium', 'long'],
        defaultValue: 'long',
      ),
      ToolParameter(
        name: 'extract_mode',
        description: '提取模式',
        type: ToolParameterType.stringType,
        enumValues: ['text', 'markdown', 'html'],
        defaultValue: 'markdown',
      ),
    ],
    timeoutMs: 20000,
    execute: _executeFetchWeb,
  );

  // ============================================================================
  // 生命周期
  // ============================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('联网搜索技能初始化完成');
  }

  @override
  Future<void> onDispose() async {
    _cache.clear();
  }

  // ============================================================================
  // 工具实现
  // ============================================================================

  /// 执行搜索
  Future<ToolResult> _executeSearchWeb(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final query = args['query'] as String;
    final engine = args['engine'] as String? ?? 'general';
    final freshness = args['freshness'] as int?;
    final maxResults = args['max_results'] as int? ?? 10;
    final responseLength = args['response_length'] as String? ?? 'medium';

    // 检查缓存
    final cacheKey = '$query|$engine|$freshness';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      context.logger.info('使用缓存结果: $query');
      return ToolResult.success(content: cached.content);
    }

    context.logger.info('搜索: $query (引擎: $engine)');

    try {
      // 构建搜索 API 请求
      final url = _buildSearchUrl(
        query: query,
        engine: engine,
        freshness: freshness,
        maxResults: maxResults,
      );

      // 发起搜索请求
      final response = await context.http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_config.apiKey}',
        },
        body: {
          'query': query,
          'engine': engine,
          if (freshness != null) 'freshness': freshness,
          'max_results': maxResults,
          'response_length': responseLength,
        },
      );

      final responseData = jsonDecode(response) as Map<String, dynamic>;
      final results = responseData['results'] as List? ?? [];

      if (results.isEmpty) {
        return ToolResult.success(
          content: '未找到与 "$query" 相关的搜索结果。',
          data: {'query': query, 'result_count': 0},
        );
      }

      // 格式化搜索结果
      final formatted = _formatSearchResults(results, responseLength);

      // 缓存结果
      _cache[cacheKey] = _CachedSearchResult(
        content: formatted,
        cachedAt: DateTime.now(),
      );

      return ToolResult.success(
        content: formatted,
        data: {
          'query': query,
          'engine': engine,
          'result_count': results.length,
        },
      );
    } catch (e) {
      context.logger.error('搜索失败', e);
      return ToolResult.failure(
        error: '搜索请求失败: $e',
        errorCode: 'SEARCH_FAILED',
      );
    }
  }

  /// 执行网页抓取
  Future<ToolResult> _executeFetchWeb(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final url = args['url'] as String;
    final responseLength = args['response_length'] as String? ?? 'long';
    final extractMode = args['extract_mode'] as String? ?? 'markdown';

    context.logger.info('抓取网页: $url');

    // 验证 URL 格式
    if (!_isValidUrl(url)) {
      return ToolResult.failure(
        error: '无效的 URL 格式: $url',
        errorCode: 'INVALID_URL',
      );
    }

    try {
      // 发起网页抓取请求
      final response = await context.http.post(
        '${_config.apiBaseUrl}/fetch',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_config.apiKey}',
        },
        body: {
          'url': url,
          'response_length': responseLength,
          'extract_mode': extractMode,
        },
      );

      final responseData = jsonDecode(response) as Map<String, dynamic>;

      // 检查是否成功
      if (responseData['error'] != null) {
        return ToolResult.failure(
          error: '网页抓取失败: ${responseData['error']}',
          errorCode: 'FETCH_FAILED',
        );
      }

      final title = responseData['title'] as String? ?? '';
      final content = responseData['content'] as String? ?? '';

      if (content.isEmpty) {
        return ToolResult.success(
          content: '网页内容为空或无法提取: $url',
        );
      }

      // 根据 response_length 截取内容
      final truncatedContent = _truncateContent(
        content,
        responseLength,
      );

      final result = StringBuffer();
      if (title.isNotEmpty) {
        result.writeln('# $title');
        result.writeln();
      }
      result.write(truncatedContent);

      return ToolResult.success(
        content: result.toString().trim(),
        data: {
          'url': url,
          'title': title,
          'content_length': content.length,
        },
      );
    } catch (e) {
      context.logger.error('网页抓取失败', e);
      return ToolResult.failure(
        error: '网页抓取请求失败: $e',
        errorCode: 'FETCH_ERROR',
      );
    }
  }

  // ============================================================================
  // 辅助方法
  // ============================================================================

  /// 构建搜索 API URL
  String _buildSearchUrl({
    required String query,
    required String engine,
    int? freshness,
    required int maxResults,
  }) {
    return '${_config.apiBaseUrl}/search';
  }

  /// 格式化搜索结果
  String _formatSearchResults(List<dynamic> results, String responseLength) {
    final buffer = StringBuffer();
    buffer.writeln('找到 ${results.length} 条相关结果：');
    buffer.writeln();

    for (int i = 0; i < results.length; i++) {
      final result = results[i] as Map<String, dynamic>;
      final title = result['title'] ?? '无标题';
      final url = result['url'] ?? '';
      final snippet = result['snippet'] ?? result['description'] ?? '';

      buffer.writeln('**${i + 1}. $title**');
      if (url.isNotEmpty) buffer.writeln('   链接: $url');
      if (snippet.isNotEmpty) buffer.writeln('   $snippet');
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// 根据长度截取内容
  String _truncateContent(String content, String responseLength) {
    final maxLength = switch (responseLength) {
      'short' => 500,
      'medium' => 2000,
      'long' => 8000,
      _ => 8000,
    };

    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}\n\n[内容已截断，共 ${content.length} 字符]';
  }

  /// 验证 URL 格式
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'http' || uri.scheme == 'https';
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// 配置与缓存
// ============================================================================

/// 搜索技能配置
class WebSearchConfig {
  /// API 基础 URL
  final String apiBaseUrl;

  /// API 密钥
  final String apiKey;

  /// 默认搜索引擎
  final String defaultEngine;

  /// 默认结果数量
  final int defaultMaxResults;

  /// 缓存过期时间
  final Duration cacheDuration;

  const WebSearchConfig({
    this.apiBaseUrl = 'https://api.xiaosu.ai/v1',
    this.apiKey = '',
    this.defaultEngine = 'general',
    this.defaultMaxResults = 10,
    this.cacheDuration = const Duration(minutes: 10),
  });
}

/// 搜索结果缓存项
class _CachedSearchResult {
  final String content;
  final DateTime cachedAt;

  _CachedSearchResult({
    required this.content,
    required this.cachedAt,
  });

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > const Duration(minutes: 10);
}
