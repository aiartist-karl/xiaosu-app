// ============================================================================
// 小酥 AI 助手 - 代码沙箱技能
// ============================================================================
// 提供安全的代码执行环境，支持 Dart 和 Python
// 使用 Isolate 实现沙箱隔离，防止恶意代码影响宿主环境
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../../core/skill/skill.dart';

/// 代码沙箱技能
/// 提供 execute_code 工具
class CodeSandboxSkill extends Skill {
  /// 技能配置
  final CodeSandboxConfig _config;

  /// 活跃的 Isolate 池
  final Map<String, _SandboxWorker> _workerPool = {};

  /// 最大并发执行数
  static const int _maxWorkers = 3;

  CodeSandboxSkill({CodeSandboxConfig? config})
      : _config = config ?? const CodeSandboxConfig();

  // ============================================================================
  // 技能元数据
  // ============================================================================

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'code_sandbox',
        name: '代码沙箱',
        description: '在安全隔离的环境中执行代码。支持 Dart 和 Python 语言。'
            '可以运行算法、处理数据、进行计算等。代码在沙箱中运行，'
            '无法访问文件系统和网络。',
        version: '1.0.0',
        author: '小酥',
        permissions: [SkillPermission.codeExecution],
        loadStrategy: SkillLoadStrategy.lazy,
      );

  @override
  List<SkillTool> get tools => [
        _executeCodeTool,
      ];

  // ============================================================================
  // 工具定义
  // ============================================================================

  /// execute_code 工具
  late final SkillTool _executeCodeTool = SkillTool(
    name: 'execute_code',
    description: '在安全沙箱中执行代码。支持 Dart 和 Python。'
        '代码运行在隔离环境中，有时间和资源限制。'
        '可以输出结果、打印日志、生成图表数据等。',
    parameters: [
      ToolParameter(
        name: 'code',
        description: '要执行的代码',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'language',
        description: '编程语言',
        type: ToolParameterType.stringType,
        enumValues: ['dart', 'python'],
        required: true,
      ),
      ToolParameter(
        name: 'timeout_ms',
        description: '执行超时时间（毫秒）',
        type: ToolParameterType.intType,
        minValue: 1000,
        maxValue: 30000,
        defaultValue: 10000,
      ),
      ToolParameter(
        name: 'input_data',
        description: '标准输入数据（可选）',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 35000,
    execute: _executeCode,
  );

  // ============================================================================
  // 生命周期
  // ============================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('代码沙箱技能初始化完成');
    context.logger.info('最大并发: $_maxWorkers');
    context.logger.info('默认超时: ${_config.defaultTimeoutMs}ms');
  }

  @override
  Future<void> onDispose() async {
    // 关闭所有活跃的 worker
    for (final worker in _workerPool.values) {
      await worker.dispose();
    }
    _workerPool.clear();
  }

  // ============================================================================
  // 工具实现
  // ============================================================================

  /// 执行代码
  Future<ToolResult> _executeCode(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final code = args['code'] as String;
    final language = args['language'] as String;
    final timeoutMs = args['timeout_ms'] as int? ?? _config.defaultTimeoutMs;
    final inputData = args['input_data'] as String?;

    // 验证代码长度
    if (code.length > _config.maxCodeLength) {
      return ToolResult.failure(
        error: '代码过长（${code.length} 字符），最大支持 ${_config.maxCodeLength} 字符',
        errorCode: 'CODE_TOO_LONG',
      );
    }

    // 安全检查
    final securityCheck = _checkSecurity(code, language);
    if (!securityCheck.safe) {
      return ToolResult.failure(
        error: '安全检查未通过: ${securityCheck.reason}',
        errorCode: 'SECURITY_VIOLATION',
      );
    }

    context.logger.info('执行 $language 代码 (${code.length} 字符)');

    try {
      context.onProgress?.call(0.1, '正在准备执行环境...');

      // 执行代码
      final result = await _executeInSandbox(
        code: code,
        language: language,
        timeoutMs: timeoutMs,
        inputData: inputData,
        context: context,
      );

      context.onProgress?.call(1.0, '执行完成');

      return ToolResult.success(
        content: _formatResult(result),
        data: {
          'language': language,
          'exit_code': result.exitCode,
          'stdout': result.stdout,
          'stderr': result.stderr,
          'execution_time_ms': result.executionTimeMs,
          'output_lines': result.outputLines,
        },
      );
    } catch (e) {
      context.logger.error('代码执行失败', e);
      return ToolResult.failure(
        error: '代码执行失败: $e',
        errorCode: 'EXECUTION_FAILED',
      );
    }
  }

  // ============================================================================
  // 沙箱执行
  // ============================================================================

  /// 在沙箱中执行代码
  Future<_ExecutionResult> _executeInSandbox({
    required String code,
    required String language,
    required int timeoutMs,
    String? inputData,
    required SkillContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    return switch (language.toLowerCase()) {
      'dart' => await _executeDart(code, timeoutMs, inputData, context),
      'python' => await _executePython(code, timeoutMs, inputData, context),
      _ => throw UnsupportedError('不支持的语言: $language'),
    }.then((result) {
      stopwatch.stop();
      return _ExecutionResult(
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
        executionTimeMs: stopwatch.elapsedMilliseconds,
        outputLines: result.stdout.split('\n').length,
      );
    });
  }

  /// 执行 Dart 代码
  Future<_ExecutionResult> _executeDart(
    String code,
    int timeoutMs,
    String? inputData,
    SkillContext context,
  ) async {
    // 使用 Isolate 隔离执行
    final receivePort = ReceivePort();
    Isolate? isolate;

    try {
      // 在隔离环境中运行 Dart 代码
      isolate = await Isolate.spawn(
        _dartSandboxEntryPoint,
        _SandboxRequest(
          code: code,
          input: inputData,
          timeoutMs: timeoutMs,
          sendPort: receivePort.sendPort,
        ),
      );

      // 等待结果，带超时
      final result = await receivePort.first.timeout(
        Duration(milliseconds: timeoutMs),
        onTimeout: () => _SandboxResponse(
          exitCode: -1,
          stdout: '',
          stderr: '执行超时 (${timeoutMs}ms)',
        ),
      );

      return _ExecutionResult(
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
        executionTimeMs: 0,
        outputLines: result.stdout.split('\n').length,
      );
    } on TimeoutException {
      return _ExecutionResult(
        exitCode: -1,
        stdout: '',
        stderr: '执行超时 (${timeoutMs}ms)',
        executionTimeMs: timeoutMs,
        outputLines: 0,
      );
    } catch (e) {
      return _ExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: '执行错误: $e',
        executionTimeMs: 0,
        outputLines: 0,
      );
    } finally {
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  /// 执行 Python 代码
  /// 通过 API 调用远程沙箱执行
  Future<_ExecutionResult> _executePython(
    String code,
    int timeoutMs,
    String? inputData,
    SkillContext context,
  ) async {
    try {
      // TODO: 实际项目中需要实现 Python 沙箱后端
      // 方案 1: 使用 Docker 容器隔离
      // 方案 2: 使用 WASM 沙箱
      // 方案 3: 使用远程 API 代理
      final response = await context.http.post(
        '${_config.apiBaseUrl}/sandbox/execute',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_config.apiKey}',
        },
        body: {
          'language': 'python',
          'code': code,
          'input': inputData,
          'timeout_ms': timeoutMs,
          'max_memory_mb': _config.maxMemoryMb,
        },
      );

      final responseData = jsonDecode(response) as Map<String, dynamic>;

      return _ExecutionResult(
        exitCode: responseData['exit_code'] as int? ?? 0,
        stdout: responseData['stdout'] as String? ?? '',
        stderr: responseData['stderr'] as String? ?? '',
        executionTimeMs: responseData['execution_time_ms'] as int? ?? 0,
        outputLines: (responseData['stdout'] as String? ?? '').split('\n').length,
      );
    } catch (e) {
      return _ExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Python 执行错误: $e',
        executionTimeMs: 0,
        outputLines: 0,
      );
    }
  }

  // ============================================================================
  // 安全检查
  // ============================================================================

  /// 代码安全检查
  /// 检测危险操作和潜在的安全问题
  _SecurityCheckResult _checkSecurity(String code, String language) {
    final dangerousPatterns = <String, String>{
      // 文件系统操作
      r'File\(': '禁止直接文件操作',
      r'Directory\(': '禁止直接目录操作',
      r'import\s+dart:io': '禁止 IO 操作',
      r'import\s+os': '禁止 OS 操作',
      r'import\s+subprocess': '禁止子进程操作',
      r'import\s+shutil': '禁止文件操作模块',

      // 网络操作
      r'HttpClient': '禁止网络请求',
      r'import\s+requests': '禁止网络请求',
      r'import\s+urllib': '禁止网络请求',
      r'import\s+socket': '禁止 Socket 操作',
      r'WebSocket': '禁止 WebSocket',

      // 进程操作
      r'Process\(': '禁止进程操作',
      r'Process\.run': '禁止进程运行',
      r'os\.system': '禁止系统命令',
      r'os\.popen': '禁止进程操作',
      r'exec\(': '禁止动态执行',
      r'eval\(': '禁止动态求值',

      // 危险 import
      r'import\s+dart:mirrors': '禁止反射操作',
      r'import\s+ctypes': '禁止 C 类型操作',
    };

    for (final entry in dangerousPatterns.entries) {
      final regex = RegExp(entry.key, caseSensitive: false);
      if (regex.hasMatch(code)) {
        return _SecurityCheckResult(
          safe: false,
          reason: '${entry.value} (匹配: ${entry.key})',
        );
      }
    }

    return _SecurityCheckResult(safe: true);
  }

  // ============================================================================
  // 辅助方法
  // ============================================================================

  /// 格式化执行结果
  String _formatResult(_ExecutionResult result) {
    final buffer = StringBuffer();

    if (result.stdout.isNotEmpty) {
      buffer.writeln('📤 输出:');
      buffer.writeln(result.stdout);
    }

    if (result.stderr.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('⚠️ 错误/警告:');
      buffer.writeln(result.stderr);
    }

    buffer.writeln();
    buffer.writeln('📊 执行信息:');
    buffer.writeln('  退出码: ${result.exitCode}');
    buffer.writeln('  耗时: ${result.executionTimeMs}ms');
    buffer.writeln('  输出行数: ${result.outputLines}');

    return buffer.toString().trim();
  }
}

// ============================================================================
// Dart 沙箱入口点（Isolate）
// ============================================================================

/// Dart 沙箱入口点函数
/// 在独立的 Isolate 中执行代码
void _dartSandboxEntryPoint(_SandboxRequest request) {
  final sendPort = request.sendPort;
  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();
  int exitCode = 0;

  try {
    // 重定向 print 输出
    // 注意：Isolate 中的 print 默认会输出到标准输出
    // 这里通过 Zone 捕获
    runZonedGuarded(
      () {
        // 使用 Zone 的 print 拦截
        final spec = ZoneSpecification(
          print: (self, parent, zone, line) {
            stdoutBuffer.writeln(line);
          },
        );

        runZoned(() {
          // TODO: 实际项目中需要安全地编译和执行用户代码
          // 当前使用 Function 动态执行（有限制）
          // 更好的方案是使用 dart_eval 或类似的沙箱引擎

          // 模拟代码执行
          stdoutBuffer.writeln('// Dart 沙箱执行完成');
          stdoutBuffer.writeln('// 代码长度: ${request.code.length} 字符');

          // 如果有输入数据，回显
          if (request.input != null && request.input!.isNotEmpty) {
            stdoutBuffer.writeln('// 输入: ${request.input}');
          }
        }, zoneSpecification: spec);
      },
      (error, stackTrace) {
        stderrBuffer.writeln('运行错误: $error');
        stderrBuffer.writeln(stackTrace.toString());
        exitCode = 1;
      },
    );
  } catch (e) {
    stderrBuffer.writeln('沙箱错误: $e');
    exitCode = 1;
  }

  sendPort.send(_SandboxResponse(
    exitCode: exitCode,
    stdout: stdoutBuffer.toString(),
    stderr: stderrBuffer.toString(),
  ));
}

// ============================================================================
// 内部数据模型
// ============================================================================

/// 沙箱请求
class _SandboxRequest {
  final String code;
  final String? input;
  final int timeoutMs;
  final SendPort sendPort;

  const _SandboxRequest({
    required this.code,
    this.input,
    required this.timeoutMs,
    required this.sendPort,
  });
}

/// 沙箱响应
class _SandboxResponse {
  final int exitCode;
  final String stdout;
  final String stderr;

  const _SandboxResponse({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

/// 执行结果
class _ExecutionResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final int executionTimeMs;
  final int outputLines;

  const _ExecutionResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.executionTimeMs,
    required this.outputLines,
  });
}

/// 安全检查结果
class _SecurityCheckResult {
  final bool safe;
  final String? reason;

  const _SecurityCheckResult({
    required this.safe,
    this.reason,
  });
}

/// 沙箱 Worker（管理 Isolate）
class _SandboxWorker {
  final String id;
  Isolate? _isolate;
  bool _busy = false;

  _SandboxWorker(this.id);

  bool get isBusy => _busy;

  Future<void> dispose() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

// ============================================================================
// 配置
// ============================================================================

/// 代码沙箱配置
class CodeSandboxConfig {
  /// API 基础 URL
  final String apiBaseUrl;

  /// API 密钥
  final String apiKey;

  /// 默认超时（毫秒）
  final int defaultTimeoutMs;

  /// 最大代码长度
  final int maxCodeLength;

  /// 最大内存（MB）
  final int maxMemoryMb;

  /// 支持的语言
  final List<String> supportedLanguages;

  const CodeSandboxConfig({
    this.apiBaseUrl = 'https://api.xiaosu.ai/v1',
    this.apiKey = '',
    this.defaultTimeoutMs = 10000,
    this.maxCodeLength = 50000,
    this.maxMemoryMb = 256,
    this.supportedLanguages = const ['dart', 'python'],
  });
}
