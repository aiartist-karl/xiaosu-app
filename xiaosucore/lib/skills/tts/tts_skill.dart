// ============================================================================
// 小酥 - 语音合成技能
// ============================================================================

import '../../core/skill/skill.dart';
import '../../core/gateway/api_gateway.dart';

/// 语音合成技能 - TTS
class TtsSkill extends BaseSkill {
  @override
  String get skillId => 'tts';
  @override
  String get name => '语音合成';
  @override
  String get description => '将文字转换为语音音频';

  @override
  Map<String, dynamic> get parameters => {
    'text': {'type': 'string', 'required': true, 'description': '要转换的文字'},
    'voice': {'type': 'string', 'default': 'female_1', 'description': '音色'},
    'speed': {'type': 'double', 'default': 1.0, 'description': '语速'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final text = context.parameters['text'] as String? ?? '';
    if (text.isEmpty) return SkillResult.fail('请提供要转换的文字');

    try {
      final response = await ApiGateway.instance.post(
        '/api/tts/synthesize',
        body: {
          'text': text,
          'voice': context.parameters['voice'] ?? 'female_1',
          'speed': context.parameters['speed'] ?? 1.0,
        },
      );

      if (response.success && response.data != null) {
        final audioUrl = response.data!['url'] as String? ?? '';
        return SkillResult.ok('语音已生成', data: {'url': audioUrl});
      }
      return SkillResult.fail('语音合成失败');
    } catch (e) {
      return SkillResult.fail('语音合成错误: $e');
    }
  }
}
