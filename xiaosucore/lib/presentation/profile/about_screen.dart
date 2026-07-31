// ============================================================================
// 小酥 v2 - 关于页面
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xiaosu/presentation/theme/app_colors.dart';

/// 关于页面
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于小酥'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 24),
          _buildHeader(isDark),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '版本 $_version',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary(isDark)),
            ),
          ),
          const SizedBox(height: 32),
          _buildCheckUpdate(isDark),
          const SizedBox(height: 20),
          _buildLinksSection(context, isDark),
          const SizedBox(height: 20),
          _buildFeedbackSection(context, isDark),
          const SizedBox(height: 40),
          _buildFooter(isDark),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary(isDark).withOpacity(0.3),
                  blurRadius: 20, offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(child: Text('\u{1F9E0}', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 16),
          Text('小酥', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary(isDark))),
          const SizedBox(height: 4),
          Text('你的 AI 智能助手', style: TextStyle(fontSize: 14, color: AppColors.textSecondary(isDark))),
        ],
      ),
    );
  }

  Widget _buildCheckUpdate(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update, size: 20, color: AppColors.primary(isDark)),
          const SizedBox(width: 14),
          Expanded(child: Text('检查更新', style: TextStyle(fontSize: 15, color: AppColors.textPrimary(isDark)))),
          Text('已是最新版本', style: TextStyle(fontSize: 13, color: AppColors.textHint(isDark))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: AppColors.textHint(isDark)),
        ],
      ),
    );
  }

  Widget _buildLinksSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        _linkItem(Icons.description_outlined, '用户协议', isDark: isDark, onTap: () {
          showDialog(context: context, builder: (ctx) => AlertDialog(
            title: const Text('用户协议'),
            content: const SingleChildScrollView(
              child: Text(
                '欢迎使用小酥 AI 助手。\n\n'
                '1. 服务说明\n'
                '小酥是一款 AI 智能助手应用，提供对话、工作流、知识库等功能。'
                '使用本应用即表示您同意遵守以下条款。\n\n'
                '2. 用户行为\n'
                '您不得利用本应用从事违法违规活动，不得生成或传播有害内容。\n\n'
                '3. 知识产权\n'
                '本应用的所有内容（包括但不限于文字、图片、代码）均受知识产权保护。\n\n'
                '4. 免责声明\n'
                'AI 生成的内容仅供参考，可能存在偏差，请自行判断其准确性。\n\n'
                '5. 协议更新\n'
                '我们保留随时修改本协议的权利，修改后的协议将在应用内公布。',
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('我知道了'))],
          ));
        }),
        const SizedBox(height: 1),
        _linkItem(Icons.privacy_tip_outlined, '隐私政策', isDark: isDark, onTap: () {
          showDialog(context: context, builder: (ctx) => AlertDialog(
            title: const Text('隐私政策'),
            content: const SingleChildScrollView(
              child: Text(
                '我们重视您的隐私保护。\n\n'
                '1. 信息收集\n'
                '我们仅收集提供服务和改善体验所必需的信息，包括账号信息、'
                '使用数据和设备信息。\n\n'
                '2. 信息使用\n'
                '您的信息仅用于：提供 AI 服务、优化产品体验、保障账号安全。\n\n'
                '3. 信息存储\n'
                '我们采用加密存储和访问控制等措施保护您的个人信息安全。\n\n'
                '4. 信息共享\n'
                '未经您的同意，我们不会将您的个人信息分享给第三方。\n\n'
                '5. 您的权利\n'
                '您可以随时查看、修改或删除您的个人信息，也可注销账号。',
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('我知道了'))],
          ));
        }),
        const SizedBox(height: 1),
        _linkItem(Icons.code, '开源许可', isDark: isDark, onTap: () {
          showLicensePage(context: context, applicationName: '小酥', applicationVersion: _version);
        }),
      ],
    );
  }

  Widget _buildFeedbackSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        _linkItem(Icons.feedback_outlined, '意见反馈', subtitle: '帮助我们做得更好', isDark: isDark, onTap: () {
          showDialog(context: context, builder: (ctx) => AlertDialog(
            title: const Text('意见反馈'),
            content: const Text(
              '感谢您的反馈！\n\n请发送邮件至 support@xiaosu.app，'
              '详细描述您遇到的问题或改进建议，我们会尽快回复。',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
              TextButton(onPressed: () {
                Clipboard.setData(const ClipboardData(text: 'support@xiaosu.app'));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('邮箱地址已复制到剪贴板'), behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                );
              }, child: const Text('复制邮箱')),
            ],
          ));
        }),
        const SizedBox(height: 1),
        _linkItem(Icons.email_outlined, '联系我们', subtitle: 'support@xiaosu.app', isDark: isDark, onTap: () {
          Clipboard.setData(const ClipboardData(text: 'support@xiaosu.app'));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('邮箱地址 support@xiaosu.app 已复制到剪贴板'), behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          );
        }),
      ],
    );
  }

  Widget _linkItem(IconData icon, String title, {String? subtitle, required bool isDark, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(isDark), width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary(isDark)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 15, color: AppColors.textPrimary(isDark))),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark))),
                ],
              ]),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textHint(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Column(
      children: [
        Text('\u00A9 2025 小酥团队', style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark))),
        const SizedBox(height: 4),
        Text('用心打造，让 AI 更懂你', style: TextStyle(fontSize: 11, color: AppColors.textHint(isDark).withOpacity(0.7))),
      ],
    );
  }
}
