// ============================================================================
// 小酥 - 图片生成技能
// ============================================================================

import '../../core/skill/skill.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// 图片生成技能 - 调用API生成图片
class ImageGenSkill extends BaseSkill {
  @override
  String get skillId => 'image_gen';
  @override
  String get name => '图片生成';
  @override
  String get description => 'AI生成图片，支持文生图、图生图';

  @override
  Map<String, dynamic> get parameters => {
    'prompt': {'type': 'string', 'required': true, 'description': '图片描述'},
    'size': {'type': 'string', 'default': '1024x1024', 'description': '图片尺寸'},
    'style': {'type': 'string', 'default': 'natural', 'description': '风格: natural/vivid'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final prompt = context.parameters['prompt'] as String? ?? '';
    if (prompt.isEmpty) return SkillResult.fail('请提供图片描述');

    try {
      final response = await ApiGateway.instance.post(
        '/api/image/generate',
        body: {
          'prompt': prompt,
          'size': context.parameters['size'] ?? '1024x1024',
          'style': context.parameters['style'] ?? 'natural',
        },
      );

      if (response.success && response.data != null) {
        final imageUrl = response.data!['url'] as String? ?? '';
        return SkillResult.ok('图片已生成', data: {'url': imageUrl});
      }
      return SkillResult.fail('图片生成失败: ${response.error}');
    } catch (e) {
      return SkillResult.fail('图片生成错误: $e');
    }
  }
}
