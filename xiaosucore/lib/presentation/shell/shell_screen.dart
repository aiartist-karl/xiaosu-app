// ============================================================================
// 小酥 v2 - 底部导航栏 Shell 布局（4 Tab）
// 首页 / Bot商店 / 工作台 / 我的
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

/// 底部导航栏 Shell 组件
class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary(isDark);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        indicatorColor: primaryColor.withOpacity(0.1),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppColors.textSecondary(isDark)),
            selectedIcon: Icon(Icons.home, color: primaryColor),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined, color: AppColors.textSecondary(isDark)),
            selectedIcon: Icon(Icons.store, color: primaryColor),
            label: 'Bot商店',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: AppColors.textSecondary(isDark)),
            selectedIcon: Icon(Icons.dashboard, color: primaryColor),
            label: '工作台',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: AppColors.textSecondary(isDark)),
            selectedIcon: Icon(Icons.person, color: primaryColor),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
