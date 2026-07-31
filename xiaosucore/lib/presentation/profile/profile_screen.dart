// ============================================================================
// 小酥 v2 - 我的（个人中心 + Token管理）
// Phase 3: 对接真实API，移除假数据
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../app.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/user_model.dart';
import '../../core/gateway/api_gateway.dart';

/// 我的页面
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final UserRepository _userRepo = UserRepository();

  CozeUserInfo? _userInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 优先使用 ApiGateway 中保存的用户信息（Web 版无法调用单独的用户信息 API）
      final currentUser = ApiGateway.instance.currentUser;
      if (currentUser != null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _userInfo = currentUser;
          });
        }
      } else {
        // 回退到调用 API（移动端）
        final result = await _userRepo.getUserInfo();
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (result.success && result.data != null) {
              _userInfo = result.data;
            } else {
              _error = result.error;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),
            // ─── 用户信息（从API获取） ───
            _buildUserInfo(isDark),
            const SizedBox(height: 20),
            // ─── Token 卡片（从API获取） ───
            _buildTokenCard(context, isDark),
            const SizedBox(height: 20),
            // ─── 功能列表（只保留与后端相关的） ───
            _buildMenuSection(context, isDark),
            const SizedBox(height: 20),
            // ─── 其他设置 ───
            _buildSettingsSection(context, isDark),
            const SizedBox(height: 20),
            // ─── 退出登录 ───
            _buildLogoutButton(context, isDark),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// 用户信息区（从API获取真实数据）
  Widget _buildUserInfo(bool isDark) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _userInfo;
    if (user == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary(isDark).withOpacity(0.15),
              child: const Icon(Icons.person, size: 32, color: Colors.white54),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '未登录',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _loadUserInfo,
                    child: Text(
                      _error != null ? '加载失败，点击重试' : '点击加载用户信息',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          // 头像
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary(isDark).withOpacity(0.15),
            backgroundImage: user.avatar != null
                ? NetworkImage(user.avatar!)
                : null,
            child: user.avatar == null
                ? const Icon(Icons.person, size: 32, color: Colors.white54)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                if (user.email != null && user.email!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.email!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.textHint(isDark)),
            onPressed: _loadUserInfo,
          ),
        ],
      ),
    );
  }

  /// Token 卡片（点击跳转到Token余额页）
  Widget _buildTokenCard(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => context.pushNamed('token-balance'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary(isDark),
              AppColors.primary(isDark).withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.diamond, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Token 余额',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '0',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.pushNamed('token-balance'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '充值',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => context.pushNamed('token-balance'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '消费记录',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 功能菜单（只保留与后端相关的）
  Widget _buildMenuSection(BuildContext context, bool isDark) {
    final themeMode = ref.watch(themeModeProvider);
    final currentThemeColor = ref.watch(themeColorProvider);

    return Column(
      children: [
        // 深色模式切换
        _buildDarkModeSwitch(context, themeMode, isDark),
        const SizedBox(height: 1),
        // 主题颜色
        _menuItem(
          Icons.palette_outlined, '主题颜色', _themeColorLabel(currentThemeColor),
          isDark: isDark,
          isTop: false,
          isBottom: true,
          onTap: () {
            _showThemeColorPicker(context, isDark);
          },
        ),
      ],
    );
  }

  /// 设置区（API配置、Token余额、关于等）
  Widget _buildSettingsSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        _menuItem(
          Icons.diamond_outlined, 'Token 余额', '0',
          isDark: isDark,
          isTop: true,
          isBottom: false,
          onTap: () {
            context.pushNamed('token-balance');
          },
        ),
        const SizedBox(height: 1),
        _menuItem(
          Icons.settings_outlined, 'API 配置', '',
          isDark: isDark,
          isTop: false,
          isBottom: false,
          onTap: () {
            context.pushNamed('api-config');
          },
        ),
        const SizedBox(height: 1),
        _menuItem(
          Icons.notifications_outlined, '通知设置', '',
          isDark: isDark,
          isTop: false,
          isBottom: false,
          onTap: () {
            context.pushNamed('notification');
          },
        ),
        const SizedBox(height: 1),
        _menuItem(
          Icons.info_outline, '关于小酥', 'v1.0.0',
          isDark: isDark,
          isTop: false,
          isBottom: true,
          onTap: () {
            context.pushNamed('about');
          },
        ),
      ],
    );
  }

  /// 深色模式切换行
  Widget _buildDarkModeSwitch(BuildContext context, ThemeMode themeMode, bool isDark) {
    final isCurrentlyDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.dark_mode, size: 20, color: AppColors.textSecondary(isDark)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '深色模式',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),
          Switch.adaptive(
            value: isCurrentlyDark,
            activeColor: AppColors.primary(isDark),
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).state =
                  value ? ThemeMode.dark : ThemeMode.light;
            },
          ),
        ],
      ),
    );
  }

  /// 主题颜色标签
  String _themeColorLabel(ThemeColor color) {
    switch (color) {
      case ThemeColor.orange:
        return '橙色';
      case ThemeColor.blue:
        return '蓝色';
      case ThemeColor.green:
        return '绿色';
      case ThemeColor.purple:
        return '紫色';
      case ThemeColor.red:
        return '红色';
    }
  }

  /// 显示主题颜色选择底部弹窗
  void _showThemeColorPicker(BuildContext context, bool isDark) {
    final currentColor = ref.read(themeColorProvider);

    final colorOptions = <_ColorOption>[
      _ColorOption(ThemeColor.orange, '橙色', Colors.deepOrange),
      _ColorOption(ThemeColor.blue, '蓝色', Colors.blue),
      _ColorOption(ThemeColor.green, '绿色', Colors.green),
      _ColorOption(ThemeColor.purple, '紫色', Colors.purple),
      _ColorOption(ThemeColor.red, '红色', Colors.red),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '选择主题颜色',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: colorOptions.map((option) {
                    final isSelected = currentColor == option.color;
                    return GestureDetector(
                      onTap: () {
                        ref.read(themeColorProvider.notifier).state = option.color;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已切换为${option.label}主题'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: option.swatchColor,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: AppColors.textPrimary(isDark), width: 3)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            option.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? AppColors.textPrimary(isDark)
                                  : AppColors.textHint(isDark),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem(
    IconData icon, String title, String subtitle, {
    required bool isDark,
    required VoidCallback onTap,
    bool isTop = false,
    bool isBottom = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: isTop
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : isBottom
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
          border: Border(
            bottom: isBottom
                ? BorderSide.none
                : BorderSide(color: AppColors.divider(isDark), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary(isDark)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint(isDark),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textHint(isDark)),
          ],
        ),
      ),
    );
  }

  /// 退出登录按钮
  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('退出登录'),
            content: const Text('确定要清除当前认证信息吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // 清除认证信息
                  ApiGateway.instance.clearAuth();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已退出登录'), duration: Duration(seconds: 1)),
                  );
                },
                child: Text(
                  '确定',
                  style: TextStyle(color: AppColors.error(isDark)),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.error(isDark).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '退出登录',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.error(isDark),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 颜色选项辅助类
class _ColorOption {
  final ThemeColor color;
  final String label;
  final Color swatchColor;

  const _ColorOption(this.color, this.label, this.swatchColor);
}
/// 主题颜色枚举
enum ThemeColor { orange, blue, green, purple, red }

/// 主题颜色 Provider
final themeColorProvider = StateProvider<ThemeColor>((ref) => ThemeColor.blue);