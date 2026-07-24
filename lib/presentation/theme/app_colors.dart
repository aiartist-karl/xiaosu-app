import 'package:flutter/material.dart';

/// 小酥 APP 颜色系统
/// 定义了深色/浅色主题下的完整颜色体系
/// 包含主色调、辅助色、语义色、渐变色
class AppColors {
  AppColors._(); // 禁止实例化

  // ==================== 主色调 ====================
  /// 品牌主色 - 温暖的琥珀橙色（体现"酥"的温暖感）
  static const Color primaryLight = Color(0xFFE8895C);
  static const Color primaryDark = Color(0xFFF0A06A);

  /// 主色变体
  static const Color primaryVariantLight = Color(0xFFD4764D);
  static const Color primaryVariantDark = Color(0xFFE0915E);

  /// 第二主色 - 柔和的蓝紫色（与暖橙形成对比）
  static const Color secondaryLight = Color(0xFF6C63FF);
  static const Color secondaryDark = Color(0xFF8B84FF);

  // ==================== 背景色 ====================
  /// 浅色主题背景
  static const Color backgroundLight = Color(0xFFF8F9FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF0F1F5);

  /// 深色主题背景
  static const Color backgroundDark = Color(0xFF0F1117);
  static const Color surfaceDark = Color(0xFF1A1D27);
  static const Color surfaceVariantDark = Color(0xFF242836);

  // ==================== 文字色 ====================
  /// 文字主色
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textPrimaryDark = Color(0xFFE8E8EE);

  /// 文字次色
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  /// 文字辅助色
  static const Color textHintLight = Color(0xFF9CA3AF);
  static const Color textHintDark = Color(0xFF6B7280);

  // ==================== 消息气泡色 ====================
  /// 用户消息气泡
  static const Color userBubbleLight = Color(0xFFE8895C);
  static const Color userBubbleDark = Color(0xFF2D3748);

  /// AI 消息气泡
  static const Color aiBubbleLight = Color(0xFFF0F1F5);
  static const Color aiBubbleDark = Color(0xFF242836);

  /// 用户消息文字（在主题色气泡上的文字）
  static const Color userBubbleTextLight = Color(0xFFFFFFFF);
  static const Color userBubbleTextDark = Color(0xFFE8E8EE);

  // ==================== 语义色 ====================
  /// 成功 - 绿色
  static const Color successLight = Color(0xFF10B981);
  static const Color successDark = Color(0xFF34D399);

  /// 警告 - 琥珀色
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFFBBF24);

  /// 错误 - 红色
  static const Color errorLight = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFF87171);

  /// 信息 - 蓝色
  static const Color infoLight = Color(0xFF3B82F6);
  static const Color infoDark = Color(0xFF60A5FA);

  // ==================== 分割线 & 边框 ====================
  static const Color dividerLight = Color(0xFFE5E7EB);
  static const Color dividerDark = Color(0xFF2D3748);

  static const Color borderLight = Color(0xFFD1D5DB);
  static const Color borderDark = Color(0xFF374151);

  // ==================== 渐变色定义 ====================
  /// 主色渐变（按钮、强调区域）
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE8895C), Color(0xFFF0A06A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 冷色渐变（背景装饰）
  static const LinearGradient coolGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF48C6EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 暖冷渐变（特殊场景）
  static const LinearGradient warmCoolGradient = LinearGradient(
    colors: [Color(0xFFE8895C), Color(0xFF6C63FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// 深色渐变（深色主题卡片背景）
  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1A1D27), Color(0xFF242836)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 发光渐变（AI 思考状态指示）
  static const LinearGradient glowGradient = LinearGradient(
    colors: [Color(0x33E8895C), Color(0x00E8895C)],
    begin: Alignment.center,
    end: Alignment.bottomCenter,
  );

  // ==================== 工具方法 ====================

  /// 根据主题获取对应颜色
  static Color of(bool isDark, {
    required Color light,
    required Color dark,
  }) {
    return isDark ? dark : light;
  }

  /// 获取主色
  static Color primary(bool isDark) =>
      isDark ? primaryDark : primaryLight;

  /// 获取第二主色
  static Color secondary(bool isDark) =>
      isDark ? secondaryDark : secondaryLight;

  /// 获取背景色
  static Color background(bool isDark) =>
      isDark ? backgroundDark : backgroundLight;

  /// 获取表面色
  static Color surface(bool isDark) =>
      isDark ? surfaceDark : surfaceLight;

  /// 获取文字主色
  static Color textPrimary(bool isDark) =>
      isDark ? textPrimaryDark : textPrimaryLight;

  /// 获取文字次色
  static Color textSecondary(bool isDark) =>
      isDark ? textSecondaryDark : textSecondaryLight;

  /// 获取分割线颜色
  static Color divider(bool isDark) =>
      isDark ? dividerDark : dividerLight;

  /// 获取表面变体色
  static Color surfaceVariant({required bool isDark}) =>
      isDark ? surfaceVariantDark : surfaceVariantLight;

  /// 获取文字辅助色
  static Color textHint(bool isDark) =>
      isDark ? textHintDark : textHintLight;

  /// 获取错误色
  static Color error(bool isDark) =>
      isDark ? errorDark : errorLight;

  /// 获取成功色
  static Color success(bool isDark) =>
      isDark ? successDark : successLight;

  /// 获取警告色
  static Color warning(bool isDark) =>
      isDark ? warningDark : warningLight;

  /// 获取信息色
  static Color info(bool isDark) =>
      isDark ? infoDark : infoLight;

  /// 获取边框色
  static Color border(bool isDark) =>
      isDark ? borderDark : borderLight;

  /// 获取用户气泡色
  static Color userBubble(bool isDark) =>
      isDark ? userBubbleDark : userBubbleLight;

  /// 获取AI气泡色
  static Color aiBubble(bool isDark) =>
      isDark ? aiBubbleDark : aiBubbleLight;
}
