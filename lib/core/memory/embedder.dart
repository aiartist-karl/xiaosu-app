// ============================================================================
// 小酥 - 文本向量化器（TF-IDF + 简单语义）
// ============================================================================

import 'dart:math';

/// 文本向量化器
class Embedder {
  static final Embedder instance = Embedder._();
  Embedder._();

  // 词汇表（简化版TF-IDF）
  final Map<String, double> _idf = {};
  int _docCount = 0;
  static const int _vectorDim = 128;

  /// 获取向量维度
  int get vectorDimension => _vectorDim;

  /// 将文本转换为向量（基于hash的简化方法）
  List<double> embed(String text) {
    final vector = List<double>.filled(_vectorDim, 0.0);
    final tokens = _tokenize(text);

    for (final token in tokens) {
      // 使用hash映射到向量维度
      final hash = token.hashCode;
      final idx = (hash % _vectorDim).abs();
      final sign = (hash % 2 == 0) ? 1.0 : -1.0;
      vector[idx] += sign * _tfWeight(token, tokens);
    }

    // 归一化
    return _normalize(vector);
  }

  /// 批量嵌入
  List<List<double>> embedBatch(List<String> texts) {
    // 构建IDF
    _docCount += texts.length;
    for (final text in texts) {
      final tokens = _tokenize(text).toSet();
      for (final token in tokens) {
        _idf[token] = (_idf[token] ?? 0) + 1;
      }
    }

    return texts.map(embed).toList();
  }

  /// 计算余弦相似度
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0.0 : dot / denom;
  }

  /// 分词（中英文混合支持）
  List<String> _tokenize(String text) {
    // 简单分词：按空格、标点分割，中文按字分割
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final code = char.codeUnitAt(0);

      // 中文字符（按字切分）
      if (code >= 0x4E00 && code <= 0x9FFF) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString().toLowerCase());
          buffer.clear();
        }
        tokens.add(char); // 单字
        // 双字组合
        if (i + 1 < text.length) {
          final nextCode = text[i + 1].codeUnitAt(0);
          if (nextCode >= 0x4E00 && nextCode <= 0x9FFF) {
            tokens.add(text.substring(i, i + 2));
          }
        }
      } else if (RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
        buffer.write(char);
      } else {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString().toLowerCase());
          buffer.clear();
        }
      }
    }
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString().toLowerCase());
    }

    return tokens.where((t) => t.length > 0).toList();
  }

  /// TF权重
  double _tfWeight(String token, List<String> tokens) {
    if (tokens.isEmpty) return 0;
    final count = tokens.where((t) => t == token).length;
    return count / tokens.length;
  }

  /// L2归一化
  List<double> _normalize(List<double> vector) {
    double norm = 0;
    for (final v in vector) {
      norm += v * v;
    }
    norm = sqrt(norm);
    if (norm == 0) return vector;
    return vector.map((v) => v / norm).toList();
  }

  /// 重置
  void reset() {
    _idf.clear();
    _docCount = 0;
  }
}
