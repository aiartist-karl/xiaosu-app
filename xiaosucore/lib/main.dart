// ============================================================================
// 小酥 - 主入口
// Phase 2: 启动时检查登录状态，未登录跳转登录页
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xiaosu/app.dart';
import 'core/gateway/api_gateway.dart';
import 'core/llm/coze_studio_provider.dart';
import 'core/skill/skill_registry.dart';
import 'core/skill/skills_demo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化认证状态
  await ApiGateway.instance.init();
  await CozeStudioProvider.instance.init();

  // 注册示例技能
  SkillRegistry.instance.registerAll([
    WebSearchSkill(),
    ImageGenSkill(),
    CodeExecSkill(),
  ]);
  
  runApp(
    ProviderScope(
      child: XiaoSuApp(),
    ),
  );
}
