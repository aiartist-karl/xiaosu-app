// ============================================================================
// 小酥 - P1技能注册表
// ============================================================================

import '../core/skill/skill_registry.dart';
import 'image_gen/image_gen_skill.dart';
import 'tts/tts_skill.dart';
import 'web_search/web_search_skill.dart';
import 'email/email_skill.dart';
import 'lark/lark_skill.dart';
import 'social/social_skill.dart';
import 'video/video_skill.dart';
import 'podcast/podcast_skill.dart';
import 'pro_domain/pro_domain_skill.dart';
import 'forbidden_word/forbidden_word_skill.dart';
import 'cloud_sync/cloud_sync_skill.dart';
import 'tracking/tracking_skill.dart';
import 'browser/browser_skill.dart';
import 'chart/chart_skill.dart';
import 'doc_gen/doc_gen_skill.dart';
import 'code_sandbox/code_sandbox_skill.dart';

/// P1技能批量注册
class P1SkillRegistry {
  static void registerAll(SkillRegistry registry) {
    registry.registerAll([
      ImageGenSkill(),
      TtsSkill(),
      WebSearchSkill(),
      EmailSkill(),
      LarkSkill(),
      SocialSkill(),
      VideoSkill(),
      PodcastSkill(),
      ProDomainSkill(),
      ForbiddenWordSkill(),
      CloudSyncSkill(),
      TrackingSkill(),
      BrowserSkill(),
      ChartSkill(),
      DocGenSkill(),
      CodeSandboxSkill(),
    ]);
  }
}
