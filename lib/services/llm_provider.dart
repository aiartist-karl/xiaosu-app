// ============================================================================
// 小酥 (XiaoSu) - LLM 提供者（大模型调用封装）
//
// 职责：
// 1. 封装与大模型 API 的通信（OpenAI 兼容接口）
// 2. 支持流式和非流式调用
// 3. 管理 API Key、模型选择、请求参数
// 4. 处理 Token 计数与限流
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:xiaosu_core/main.dart' show appLogger;

/// ============================================================================
/// LLM 提供者 —— 封装大模型 API 调用
/// ============================================================================
class LLMProvider {
  LLMProvider._internal();
  static final LLMProvider instance = LLMProvider._internal();

  /// ─── 日志器 ─────────────────────────────────────────────────
  final Logger _logger = appLogger;

  /// ─── HTTP 客户端 ────────────────────────────────────────────
  late final Dio _dio;

  /// ─── 安全存储（存放 API Key）────────────────────────────────
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// ─── 配置 ───────────────────────────────────────────────────
  String? _apiKey;
  String _baseUrl = 'https://api.openai.com/v1';
  String _model = 'gpt-4o';
  int _maxTokens = 4096;
  double _temperature = 0.7;

  /// ─── 是否已初始化 ───────────────────────────────────────────
  bool _initialized = false;

  // ==========================================================================
  // 初始化
  // ==========================================================================

  /// 初始化 LLM 提供者
  /// 从安全存储加载 API Key，配置 HTTP 客户端
  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化 Dio HTTP 客户端
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      headers: {'Content-Type': 'application/json'},
    ));

    // 添加请求拦截器（添加 Authorization Header）
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_apiKey != null) {
          options.headers['Authorization'] = 'Bearer $_apiKey';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        _logger.e('🌐 HTTP 请求错误: ${error.message}');
        handler.next(error);
      },
    ));

    // 从安全存储加载 API Key
    try {
      _apiKey = await _secureStorage.read(key: 'llm_api_key');
      _baseUrl = await _secureStorage.read(key: 'llm_base_url') ?? _baseUrl;
      _model = await _secureStorage.read(key: 'llm_model') ?? _model;
    } catch (e) {
      _logger.w('⚠️ 加载 API Key 失败: $e');
    }

    _initialized = true;
    _logger.i('🧠 LLM 提供者初始化完成 (model=$_model)');
  }

  /// 更新配置
  Future<void> updateConfig({
    String? apiKey,
    String? baseUrl,
    String? model,
    int? maxTokens,
    double? temperature,
  }) async {
    if (apiKey != null) {
      _apiKey = apiKey;
      await _secureStorage.write(key: 'llm_api_key', value: apiKey);
    }
    if (baseUrl != null) {
      _baseUrl = baseUrl;
      await _secureStorage.write(key: 'llm_base_url', value: baseUrl);
    }
    if (model != null) {
      _model = model;
      await _secureStorage.write(key: 'llm_model', value: model);
    }
    if (maxTokens != null) _maxTokens = maxTokens;
    if (temperature != null) _temperature = temperature;
  }

  // ==========================================================================
  // 流式对话
  // ==========================================================================

  /// 发送流式对话请求
  ///
  /// 返回 Stream<LLMStreamChunk>，逐步输出 token 和 tool_call 信息
  Stream<LLMStreamChunk> streamChat(LLMRequest request) async* {
    final requestBody = _buildRequestBody(request, stream: true);

    try {
      // 使用 SSE（Server-Sent Events）流式接收
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        data: requestBody,
        options: Options(responseType: ResponseType.stream),
      );

      // 解析 SSE 数据流
      await for (final chunk in _parseSSEStream(response.data)) {
        yield chunk;
      }
    } on DioException catch (e) {
      _logger.e('❌ LLM 流式请求失败: ${e.message}');
      yield LLMStreamChunk(
        error: '请求失败: ${e.message}',
      );
    } catch (e) {
      _logger.e('❌ LLM 流式请求异常: $e');
      yield LLMStreamChunk(error: '未知错误: $e');
    }
  }

  /// 发送非流式对话请求（一次性返回完整结果）
  Future<LLMResponse> chat(LLMRequest request) async {
    final requestBody = _buildRequestBody(request, stream: false);

    try {
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        data: requestBody,
      );

      return LLMResponse.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('❌ LLM 请求失败: ${e.message}');
      rethrow;
    }
  }

  // ==========================================================================
  // 内部方法
  // ==========================================================================

  /// 构建请求体
  Map<String, dynamic> _buildRequestBody(LLMRequest request, {required bool stream}) {
    final body = <String, dynamic>{
      'model': _model,
      'messages': [
        {'role': 'system', 'content': request.systemPrompt},
        ...request.messages,
      ],
      'max_tokens': _maxTokens,
      'temperature': _temperature,
      'stream': stream,
    };

    // 如果有工具定义（Function Calling）
    if (request.tools.isNotEmpty) {
      body['tools'] = request.tools;
      body['tool_choice'] = 'auto';
    }

    return body;
  }

  /// 解析 SSE 流数据
  Stream<LLMStreamChunk> _parseSSEStream(dynamic streamData) async* {
    // 将流数据逐行解析为 SSE 事件
    // 格式：data: {"choices": [{"delta": {"content": "..."}}]}
    if (streamData is Stream) {
      String buffer = '';
      await for (final data in streamData) {
        final text = String.fromCharCodes(data);
        buffer += text;

        // 按行分割
        while (buffer.contains('\n')) {
          final lineEnd = buffer.indexOf('\n');
          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);

          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            if (jsonStr == '[DONE]') {
              return; // 流结束
            }

            try {
              final json = jsonDecode(jsonStr) as Map<String, dynamic>;
              yield LLMStreamChunk.fromJson(json);
            } catch (e) {
              // 跳过无效 JSON
              _logger.d('⚠️ 跳过无效 SSE 数据: $jsonStr');
            }
          }
        }
      }
    }
  }
}

// ============================================================================
/// LLM 请求参数
/// ============================================================================
class LLMRequest {
  final String systemPrompt;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> tools;
  final bool stream;

  const LLMRequest({
    required this.systemPrompt,
    required this.messages,
    this.tools = const [],
    this.stream = false,
  });
}

// ============================================================================
/// LLM 流式响应片段
/// ============================================================================
class LLMStreamChunk {
  /// 文本内容片段
  final String content;

  /// 工具调用列表
  final List<ToolCall> toolCalls;

  /// 错误信息
  final String? error;

  /// 是否还有内容
  bool get hasContent => content.isNotEmpty;

  /// 是否有工具调用
  bool get hasToolCalls => toolCalls.isNotEmpty;

  const LLMStreamChunk({
    this.content = '',
    this.toolCalls = const [],
    this.error,
  });

  factory LLMStreamChunk.fromJson(Map<String, dynamic> json) {
    final choices = json['choices'] as List? ?? [];
    if (choices.isEmpty) {
      return const LLMStreamChunk();
    }

    final delta = choices[0]['delta'] as Map<String, dynamic>? ?? {};

    // 解析文本内容
    final content = delta['content'] as String? ?? '';

    // 解析工具调用
    final toolCallsList = <ToolCall>[];
    if (delta.containsKey('tool_calls')) {
      final rawToolCalls = delta['tool_calls'] as List? ?? [];
      for (final tc in rawToolCalls) {
        final function = tc['function'] as Map<String, dynamic>? ?? {};
        toolCallsList.add(ToolCall(
          id: tc['id'] as String? ?? '',
          function: ToolCallFunction(
            name: function['name'] as String? ?? '',
            arguments: function['arguments'] as String? ?? '{}',
          ),
        ));
      }
    }

    return LLMStreamChunk(
      content: content,
      toolCalls: toolCallsList,
    );
  }
}

// ============================================================================
/// LLM 完整响应
/// ============================================================================
class LLMResponse {
  final String content;
  final List<ToolCall> toolCalls;
  final int? totalTokens;

  const LLMResponse({
    this.content = '',
    this.toolCalls = const [],
    this.totalTokens,
  });

  factory LLMResponse.fromJson(Map<String, dynamic> json) {
    final choices = json['choices'] as List? ?? [];
    final message = choices.isNotEmpty
        ? choices[0]['message'] as Map<String, dynamic>? ?? {}
        : <String, dynamic>{};

    final toolCallsList = <ToolCall>[];
    if (message.containsKey('tool_calls')) {
      final rawToolCalls = message['tool_calls'] as List? ?? [];
      for (final tc in rawToolCalls) {
        final function = tc['function'] as Map<String, dynamic>? ?? {};
        toolCallsList.add(ToolCall(
          id: tc['id'] as String? ?? '',
          function: ToolCallFunction(
            name: function['name'] as String? ?? '',
            arguments: function['arguments'] as String? ?? '{}',
          ),
        ));
      }
    }

    final usage = json['usage'] as Map<String, dynamic>?;

    return LLMResponse(
      content: message['content'] as String? ?? '',
      toolCalls: toolCallsList,
      totalTokens: usage?['total_tokens'] as int?,
    );
  }
}

// ============================================================================
/// 工具调用（Function Calling）
/// ============================================================================
class ToolCall {
  final String id;
  final ToolCallFunction function;

  const ToolCall({
    required this.id,
    required this.function,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': 'function',
    'function': {
      'name': function.name,
      'arguments': function.arguments,
    },
  };
}

/// 工具调用中的函数信息
class ToolCallFunction {
  final String name;
  final String arguments;

  const ToolCallFunction({
    required this.name,
    required this.arguments,
  });
}
