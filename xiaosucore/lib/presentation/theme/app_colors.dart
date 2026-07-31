import 'package:flutter/material.dart';

/// 小酥 APP 颜色系统
/// 对标扣子 APP 视觉风格：蓝紫渐变主色 + 清爽卡片布局
class AppColors {
  AppColors._();

  // ==================== 主色调 ====================
  static const Color primaryLight = Color(0xFF667EEA);
  static const Color primaryDark = Color(0xFF8B9CF7);

  static const Color primaryVariantLight = Color(0xFF764BA2);
  static const Color primaryVariantDark = Color(0xFF9B6FC0);

  static const Color secondaryLight = Color(0xFF764BA2);
  static const Color secondaryDark = Color(0xFF9B6FC0);

  // ==================== 背景色 ====================
  static const Color backgroundLight = Color(0xFFF8F9FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF0F1F5);

  static const Color backgroundDark = Color(0xFF0F1117);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceVariantDark = Color(0xFF2C2C2C);

  // ==================== 文字色 ====================
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textPrimaryDark = Color(0xFFE8E8EE);

  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  static const Color textHintLight = Color(0xFF9CA3AF);
  static const Color textHintDark = Color(0xFF6B7280);

  // ==================== 卡片色 ====================
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E1E1E);

  // ==================== 消息气泡色 ====================
  static const Color userBubbleLight = Color(0xFF667EEA);
  static const Color userBubbleDark = Color(0xFF2D3748);

  static const Color aiBubbleLight = Color(0xFFF0F1F5);
  static const Color aiBubbleDark = Color(0xFF2C2C2C);

  static const Color userBubbleTextLight = Color(0xFFFFFFFF);
  static const Color userBubbleTextDark = Color(0xFFE8E8EE);

  // ==================== 语义色 ====================
  static const Color successLight = Color(0xFF10B981);
  static const Color successDark = Color(0xFF34D399);

  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFFBBF24);

  static const Color errorLight = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFF87171);

  static const Color infoLight = Color(0xFF3B82F6);
  static const Color infoDark = Color(0xFF60A5FA);

  // ==================== 分割线 & 边框 ====================
  static const Color dividerLight = Color(0xFFF0F0F0);
  static const Color dividerDark = Color(0xFF2C2C2C);

  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF374151);

  // ==================== 卡片阴影 ====================
  static const BoxShadow cardShadow = BoxShadow(
    color: Colors.black12,
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const BoxShadow cardShadowDark = BoxShadow(
    color: Colors.black26,
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  // ==================== 渐变色定义 ====================
  /// 主色渐变（Token 卡片、按钮）蓝紫渐变
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Token 卡片专用渐变
  static const LinearGradient tokenCardGradient = LinearGradient(
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coolGradient = LinearGradient(
    colors: [Color(0xFF667EEA), Color(0xFF48C6EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== 工具方法 ====================
  static Color of(bool isDark, {required Color light, required Color dark}) =>
      isDark ? dark : light;

  static Color primary(bool isDark) => isDark ? primaryDark : primaryLight;
  static Color primaryVariant(bool isDark) => isDark ? primaryVariantDark : primaryVariantLight;
  static Color secondary(bool isDark) => isDark ? secondaryDark : secondaryLight;
  static Color background(bool isDark) => isDark ? backgroundDark : backgroundLight;
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color card(bool isDark) => isDark ? cardDark : cardLight;
  static Color textPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color divider(bool isDark) => isDark ? dividerDark : dividerLight;
  static Color surfaceVariant({required bool isDark}) => isDark ? surfaceVariantDark : surfaceVariantLight;
  static Color textHint(bool isDark) => isDark ? textHintDark : textHintLight;
  static Color error(bool isDark) => isDark ? errorDark : errorLight;
  static Color success(bool isDark) => isDark ? successDark : successLight;
  static Color warning(bool isDark) => isDark ? warningDark : warningLight;
  static Color info(bool isDark) => isDark ? infoDark : infoLight;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;
  static Color userBubble(bool isDark) => isDark ? userBubbleDark : userBubbleLight;
  static Color aiBubble(bool isDark) => isDark ? aiBubbleDark : aiBubbleLight;
  static BoxShadow shadow(bool isDark) => isDark ? cardShadowDark : cardShadow;
}
