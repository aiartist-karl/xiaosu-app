// ============================================================================
// 小酥 (XiaoSu) - 全局主题定义
// ============================================================================

import 'package:flutter/material.dart';

/// 小酥主题配置
class AppTheme {
  AppTheme._();

  // ─── 品牌色 ─────────────────────────────────────────────────
  /// 主色调：温暖的橙黄色（小酥的主题色）
  static const Color primaryColor = Color(0xFFFF9B50);
  /// 次要色
  static const Color secondaryColor = Color(0xFFFF6B6B);
  /// 背景色
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF1A1A2E);

  /// 聊天气泡颜色
  static const Color userBubbleLight = Color(0xFFFF9B50);
  static const Color userBubbleDark = Color(0xFF2D2D44);
  static const Color assistantBubbleLight = Color(0xFFF0F0F5);
  static const Color assistantBubbleDark = Color(0xFF252540);

  // ─── 圆角 ───────────────────────────────────────────────────
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 20;

  // ==========================================================================
  // 亮色主题
  // ==========================================================================
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: primaryColor,
    scaffoldBackgroundColor: backgroundLight,

    // AppBar 样式
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
    ),

    // 输入框样式
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // 卡片样式
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
    ),

    // 浮动按钮
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
  );

  // ==========================================================================
  // 暗色主题
  // ==========================================================================
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: primaryColor,
    scaffoldBackgroundColor: backgroundDark,

    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Color(0xFF1A1A2E),
      foregroundColor: Colors.white,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF252540),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    cardTheme: CardTheme(
      elevation: 0,
      color: const Color(0xFF252540),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
  );
}
