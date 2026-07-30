// ============================================================================
// 小酥 - 主入口
// Phase 2: 启动时检查登录状态，未登录跳转登录页
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xiaosu/app.dart';
import 'core/gateway/api_gateway.dart';
import 'core/llm/coze_studio_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化认证状态
  await ApiGateway.instance.init();
  await CozeStudioProvider.instance.init();
  
  runApp(
    ProviderScope(
      child: XiaoSuApp(),
    ),
  );
}
