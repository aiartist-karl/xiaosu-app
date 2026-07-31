// ============================================================================
// 小酥 - 自适应布局引擎
// ============================================================================

import 'package:flutter/material.dart';

/// 屏幕断点
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// 布局类型
enum LayoutType { mobile, tablet, desktop }

/// 自适应布局引擎
class AdaptiveLayoutEngine {
  /// 获取当前布局类型
  static LayoutType getLayoutType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Breakpoints.desktop) return LayoutType.desktop;
    if (width >= Breakpoints.tablet) return LayoutType.tablet;
    return LayoutType.mobile;
  }

  /// 是否为手机布局
  static bool isMobile(BuildContext context) => getLayoutType(context) == LayoutType.mobile;

  /// 是否为平板布局
  static bool isTablet(BuildContext context) => getLayoutType(context) == LayoutType.tablet;

  /// 是否为桌面布局
  static bool isDesktop(BuildContext context) => getLayoutType(context) == LayoutType.desktop;

  /// 自适应Widget构建器
  static Widget adaptive({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    final layout = getLayoutType(context);
    switch (layout) {
      case LayoutType.desktop:
        return desktop ?? tablet ?? mobile;
      case LayoutType.tablet:
        return tablet ?? mobile;
      case LayoutType.mobile:
        return mobile;
    }
  }

  /// 自适应列数（用于Grid）
  static int gridColumns(BuildContext context) {
    final layout = getLayoutType(context);
    switch (layout) {
      case LayoutType.desktop: return 4;
      case LayoutType.tablet: return 3;
      case LayoutType.mobile: return 2;
    }
  }

  /// 自适应内边距
  static double padding(BuildContext context) {
    final layout = getLayoutType(context);
    switch (layout) {
      case LayoutType.desktop: return 24;
      case LayoutType.tablet: return 16;
      case LayoutType.mobile: return 12;
    }
  }
}
