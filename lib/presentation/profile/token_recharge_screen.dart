// ============================================================================
// 小酥 v2 - Token 充值页面
// ============================================================================

import 'package:flutter/material.dart';
import 'package:xiaosu/presentation/theme/app_colors.dart';

/// 充值套餐模型
class _RechargePackage {
  final int price;
  final int tokens;
  final String? tag;

  const _RechargePackage({
    required this.price,
    required this.tokens,
    this.tag,
  });
}

/// Token 充值页面
class TokenRechargeScreen extends StatefulWidget {
  const TokenRechargeScreen({super.key});

  @override
  State<TokenRechargeScreen> createState() => _TokenRechargeScreenState();
}

class _TokenRechargeScreenState extends State<TokenRechargeScreen> {
  int _selectedPackage = 0;
  int _selectedPayment = 0; // 0=支付宝 1=微信 2=Apple Pay

  static const List<_RechargePackage> _packages = [
    _RechargePackage(price: 9, tokens: 500, tag: '推荐'),
    _RechargePackage(price: 29, tokens: 1800),
    _RechargePackage(price: 99, tokens: 7000),
    _RechargePackage(price: 299, tokens: 25000),
  ];

  static const List<_PaymentMethod> _payments = [
    _PaymentMethod(name: '支付宝', icon: Icons.account_balance_wallet),
    _PaymentMethod(name: '微信', icon: Icons.chat),
    _PaymentMethod(name: 'Apple Pay', icon: Icons.apple),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Token 充值'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const SizedBox(height: 8),
          // ─── 余额卡片 ───
          _buildBalanceCard(isDark),
          const SizedBox(height: 28),
          // ─── 充值套餐 ───
          _buildSectionTitle('选择套餐', isDark),
          const SizedBox(height: 12),
          _buildPackageList(isDark),
          const SizedBox(height: 28),
          // ─── 支付方式 ───
          _buildSectionTitle('支付方式', isDark),
          const SizedBox(height: 12),
          _buildPaymentMethods(isDark),
          const SizedBox(height: 40),
          // ─── 确认按钮 ───
          _buildConfirmButton(isDark),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary(isDark),
            AppColors.primary(isDark).withOpacity(0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.diamond, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          const Text(
            '—',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Token 余额',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(isDark),
      ),
    );
  }

  Widget _buildPackageList(bool isDark) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _packages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final pkg = _packages[index];
          final selected = _selectedPackage == index;
          return _buildPackageCard(pkg, selected, isDark, index);
        },
      ),
    );
  }

  Widget _buildPackageCard(
    _RechargePackage pkg, bool selected, bool isDark, int index,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary(isDark).withOpacity(0.1)
              : AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary(isDark)
                : AppColors.divider(isDark),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 推荐标签
            if (pkg.tag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pkg.tag!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (pkg.tag != null) const SizedBox(height: 8),
            // Token 数量
            Text(
              '${pkg.tokens}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.primary(isDark)
                    : AppColors.textPrimary(isDark),
              ),
            ),
            Text(
              'Token',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            // 价格
            Text(
              '¥${pkg.price}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.primary(isDark)
                    : AppColors.textPrimary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethods(bool isDark) {
    return Column(
      children: List.generate(_payments.length, (index) {
        final payment = _payments[index];
        final selected = _selectedPayment == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedPayment = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.primary(isDark)
                    : AppColors.divider(isDark),
                width: selected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary(isDark).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    payment.icon,
                    color: AppColors.primary(isDark),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    payment.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected
                      ? AppColors.primary(isDark)
                      : AppColors.textHint(isDark),
                  size: 22,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildConfirmButton(bool isDark) {
    final pkg = _packages[_selectedPackage];
    return GestureDetector(
      onTap: () {
        // TODO: 接入支付 SDK
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('即将支付 ¥${pkg.price} 获取 ${pkg.tokens} Token'),
            backgroundColor: AppColors.primary(isDark),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '确认支付 ¥${pkg.price}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 支付方式模型
class _PaymentMethod {
  final String name;
  final IconData icon;

  const _PaymentMethod({required this.name, required this.icon});
}
