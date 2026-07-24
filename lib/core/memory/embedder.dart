/// ============================================================================
/// 小酥 AI 助手 — Embedding 接口与实现
/// ============================================================================
/// 定义文本向量化的抽象接口，提供两种实现：
///   - OnDeviceEmbedder：基于 ONNX Runtime 的端侧模型
///   - CloudEmbedder：基于云端 API 的向量化
/// 支持自动降级：云端失败 → 端侧
/// ============================================================================

import 'dart:async';
import 'dart:typed_data';

import '../common/models.dart';

// ———————————————————————————————— Embedding 接口 ————————————————————————————————

/// Embedding 抽象接口
///
/// 将文本转换为固定维度的浮点向量，用于语义搜索和相似度计算。
abstract class Embedder {
  /// Embedder 标识
  String get embedderId;

  /// 输出向量维度
  int get dimension;

  /// 最大输入 token 数
  int get maxTokens;

  /// 是否可用
  bool get isAvailable;

  /// 单条文本向量化
  ///
  /// [text] 输入文本
  /// 返回浮点向量
  Future<List<double>> embed(String text);

  /// 批量文本向量化
  ///
  /// [texts] 输入文本列表
  /// 返回对应的向量列表，顺序与输入一致
  Future<List<List<double>>> embedBatch(List<String> texts);

  /// 释放资源
  Future<void> dispose();
}

// ———————————————————————————————— ONNX 端侧 Embedder ————————————————————————————————

/// 端侧 ONNX Embedder
///
/// 使用 ONNX Runtime 在设备本地运行轻量级 Embedding 模型。
/// 优点：无需网络、延迟低、保护隐私。
/// 缺点：模型较小，语义理解能力有限。
///
/// 推荐使用模型：
///   - all-MiniLM-L6-v2 (384 维，80MB)
///   - bge-small-zh-v1.5 (512 维，100MB)
///
/// TODO: 实际集成需要依赖 onnxruntime_flutter 包
class OnDeviceEmbedder extends Embedder {
  @override
  final String embedderId = 'onnx_device';

  @override
  final int dimension;

  @override
  final int maxTokens;

  /// ONNX 模型文件路径
  final String modelPath;

  /// 是否已加载模型
  bool _modelLoaded = false;

  OnDeviceEmbedder({
    required this.modelPath,
    this.dimension = 384,
    this.maxTokens = 256,
  });

  @override
  bool get isAvailable => _modelLoaded;

  /// 加载 ONNX 模型到内存
  ///
  /// 应在 App 启动时异步调用，避免阻塞 UI。
  Future<void> loadModel() async {
    // TODO: 实际实现需要调用 onnxruntime_flutter 的 API
    // 示例：
    // final session = await OrtSession.fromFile(modelPath);
    // _ortSession = session;
    _modelLoaded = true;
  }

  @override
  Future<List<double>> embed(String text) async {
    if (!_modelLoaded) {
      throw MemoryException('ONNX 模型未加载，请先调用 loadModel()');
    }

    // TODO: 实际实现
    // 1. 分词 (tokenize)
    // 2. 构造输入 tensor
    // 3. 调用 ORT session.run()
    // 4. 提取输出向量并归一化
    // 当前返回占位向量
    return _generatePlaceholderVector(text);
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    if (!_modelLoaded) {
      throw MemoryException('ONNX 模型未加载，请先调用 loadModel()');
    }

    // TODO: 实际实现 — 批量推理以提高吞吐
    final results = <List<double>>[];
    for (final text in texts) {
      results.add(await embed(text));
    }
    return results;
  }

  /// 生成占位向量（实际实现中替换为 ONNX 推理）
  List<double> _generatePlaceholderVector(String text) {
    // 基于文本哈希生成伪随机向量，保证同一文本输出一致
    final hash = text.hashCode;
    final rng = _SeededRandom(hash);
    final vector = List<double>.generate(dimension, (_) => rng.nextDouble());

    // L2 归一化
    final norm = _l2Norm(vector);
    if (norm > 0) {
      for (int i = 0; i < vector.length; i++) {
        vector[i] /= norm;
      }
    }
    return vector;
  }

  @override
  Future<void> dispose() async {
    _modelLoaded = false;
    // TODO: 释放 ORT session
  }
}

// ———————————————————————————————— 云端 Embedder ————————————————————————————————

/// 云端 API Embedder
///
/// 通过 HTTP 调用云端 Embedding API，支持多种后端：
///   - OpenAI text-embedding-3-small / large
///   - 通义千问 text-embedding-v2
///   - 其他兼容 API
///
/// 使用 Dio 作为 HTTP 客户端。
/// TODO: 实际集成需要依赖 dio 包
class CloudEmbedder extends Embedder {
  @override
  final String embedderId;

  @override
  final int dimension;

  @override
  final int maxTokens;

  /// API 地址
  final String apiUrl;

  /// API Key
  final String apiKey;

  /// 模型名称
  final String modelName;

  /// 批量请求大小（每次最多发送多少条）
  final int batchSize;

  CloudEmbedder({
    required this.apiUrl,
    required this.apiKey,
    this.modelName = 'text-embedding-3-small',
    this.embedderId = 'cloud_api',
    this.dimension = 1536,
    this.maxTokens = 8191,
    this.batchSize = 20,
  });

  @override
  bool get isAvailable => apiKey.isNotEmpty;

  @override
  Future<List<double>> embed(String text) async {
    final results = await embedBatch([text]);
    return results.first;
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    if (!isAvailable) {
      throw MemoryException('CloudEmbedder 不可用：API Key 未配置');
    }

    final allVectors = <List<double>>[];

    // 分批请求
    for (int i = 0; i < texts.length; i += batchSize) {
      final batch = texts.sublist(
        i,
        i + batchSize > texts.length ? texts.length : i + batchSize,
      );
      final vectors = await _requestEmbeddings(batch);
      allVectors.addAll(vectors);
    }

    return allVectors;
  }

  /// 请求云端 API 获取 Embedding
  ///
  /// TODO: 实际实现需要 Dio HTTP 客户端
  Future<List<List<double>>> _requestEmbeddings(List<String> texts) async {
    // TODO: 实际实现
    // final dio = Dio();
    // final response = await dio.post(
    //   apiUrl,
    //   options: Options(headers: {
    //     'Authorization': 'Bearer $apiKey',
    //     'Content-Type': 'application/json',
    //   }),
    //   data: {
    //     'model': modelName,
    //     'input': texts,
    //   },
    // );
    // return (response.data['data'] as List)
    //     .map((d) => (d['embedding'] as List).cast<double>())
    //     .toList();

    // 占位：返回随机向量
    return texts.map((t) {
      final hash = t.hashCode;
      final rng = _SeededRandom(hash);
      return List<double>.generate(dimension, (_) => rng.nextDouble());
    }).toList();
  }

  @override
  Future<void> dispose() async {
    // 释放 Dio 客户端
    // TODO: dio.close();
  }
}

// ———————————————————————————————— 降级策略 ————————————————————————————————

/// 带降级的 Embedder
///
/// 优先使用云端 Embedder，失败时自动降级到端侧。
/// 端侧模型精度较低，但始终可用。
class FallbackEmbedder extends Embedder {
  /// 主 Embedder（云端）
  final Embedder primary;

  /// 备用 Embedder（端侧）
  final Embedder fallback;

  /// 当前是否在使用降级模式
  bool _usingFallback = false;

  FallbackEmbedder({
    required this.primary,
    required this.fallback,
  });

  @override
  String get embedderId =>
      _usingFallback ? fallback.embedderId : primary.embedderId;

  @override
  int get dimension =>
      _usingFallback ? fallback.dimension : primary.dimension;

  @override
  int get maxTokens =>
      _usingFallback ? fallback.maxTokens : primary.maxTokens;

  @override
  bool get isAvailable => primary.isAvailable || fallback.isAvailable;

  /// 当前是否处于降级模式
  bool get isUsingFallback => _usingFallback;

  @override
  Future<List<double>> embed(String text) async {
    try {
      final result = await primary.embed(text);
      _usingFallback = false;
      return result;
    } catch (e) {
      // 云端失败，降级到端侧
      _usingFallback = true;
      return fallback.embed(text);
    }
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    try {
      final result = await primary.embedBatch(texts);
      _usingFallback = false;
      return result;
    } catch (e) {
      _usingFallback = true;
      return fallback.embedBatch(texts);
    }
  }

  @override
  Future<void> dispose() async {
    await primary.dispose();
    await fallback.dispose();
  }
}

// ———————————————————————————————— 工具类 ————————————————————————————————

/// 简易种子随机数生成器（用于占位向量生成）
///
/// 实际项目中应使用 dart:math 的 Random，此处仅为演示。
class _SeededRandom {
  int _seed;

  _SeededRandom(this._seed);

  /// 生成 [0, 1) 范围的浮点数
  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return (_seed & 0xfffffff) / 0x10000000;
  }
}

/// 计算向量的 L2 范数
double _l2Norm(List<double> vector) {
  double sum = 0;
  for (final v in vector) {
    sum += v * v;
  }
  return _sqrt(sum);
}

/// 简易平方根（牛顿法）
double _sqrt(double x) {
  if (x <= 0) return 0;
  double guess = x / 2;
  for (int i = 0; i < 20; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}
