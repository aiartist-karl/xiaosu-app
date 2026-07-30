// ============================================================================
// 小酥 v2 - Token余额页
// 显示Token余额、消费记录、充值入口
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/repositories/user_repository.dart';
import '../theme/app_colors.dart';

/// Token余额页
class TokenBalanceScreen extends StatefulWidget {
  const TokenBalanceScreen({super.key});

  @override
  State<TokenBalanceScreen> createState() => _TokenBalanceScreenState();
}

class _TokenBalanceScreenState extends State<TokenBalanceScreen>
    with SingleTickerProviderStateMixin {
  final UserRepository _repo = UserRepository();
  late TabController _tabController;

  bool _isLoading = true;
  int _balance = 0;
  int _totalUsed = 0;
  String? _error;

  // 模拟消费记录
  final List<_ConsumptionRecord> _records = [
    _ConsumptionRecord(
      title: 'Bot 对话消耗',
      amount: -50,
      time: DateTime.now().subtract(const Duration(hours: 1)),
      type: '对话',
    ),
    _ConsumptionRecord(
      title: '工作流运行',
      amount: -120,
      time: DateTime.now().subtract(const Duration(hours: 3)),
      type: '工作流',
    ),
    _ConsumptionRecord(
      title: 'Token 充值',
      amount: 500,
      time: DateTime.now().subtract(const Duration(days: 1)),
      type: '充值',
    ),
    _ConsumptionRecord(
      title: '知识库检索',
      amount: -30,
      time: DateTime.now().subtract(const Duration(days: 1)),
      type: '知识库',
    ),
    _ConsumptionRecord(
      title: '插件调用',
      amount: -15,
      time: DateTime.now().subtract(const Duration(days: 2)),
      type: '插件',
    ),
    _ConsumptionRecord(
      title: 'Bot 对话消耗',
      amount: -80,
      time: DateTime.now().subtract(const Duration(days: 3)),
      type: '对话',
    ),
    _ConsumptionRecord(
      title: 'Token 充值',
      amount: 1000,
      time: DateTime.now().subtract(const Duration(days: 5)),
      type: '充值',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBalance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 尝试获取用户信息（包含余额）
    try {
      // 这里使用模拟数据，因为 API 可能不直接返回余额
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _isLoading = false;
        _balance = 1500;
        _totalUsed = 4295;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '获取余额失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Token 管理'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 余额卡片
                _buildBalanceCard(isDark),
                const SizedBox(height: 20),
                // Tab
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(isDark: isDark),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.textPrimary(isDark),
                    unselectedLabelColor: AppColors.textSecondary(isDark),
                    tabs: const [
                      Tab(text: '消费记录'),
                      Tab(text: '充值方案'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tab 内容
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRecordsList(isDark),
                      _buildRechargeOptions(isDark),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBalanceCard(bool isDark) {
    const maxBalance = 2000;
    final progress = _balance / maxBalance;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary(isDark),
            AppColors.primary(isDark).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.diamond, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Token 余额',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadBalance,
                child: const Icon(Icons.refresh, color: Colors.white54, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$_balance',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '累计消费: $_totalUsed',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('0', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('$maxBalance',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _tabController.index = 1;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '立即充值',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList(bool isDark) {
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text(
              '暂无消费记录',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _records.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: AppColors.divider(isDark),
      ),
      itemBuilder: (context, index) {
        final record = _records[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: record.amount > 0
                      ? AppColors.success(isDark).withOpacity(0.1)
                      : AppColors.error(isDark).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  record.amount > 0 ? Icons.add : Icons.remove,
                  size: 18,
                  color: record.amount > 0
                      ? AppColors.success(isDark)
                      : AppColors.error(isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.type} · ${_formatTime(record.time)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${record.amount > 0 ? '+' : ''}${record.amount}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: record.amount > 0
                      ? AppColors.success(isDark)
                      : AppColors.error(isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRechargeOptions(bool isDark) {
    final options = [
      _RechargeOption(tokens: 500, price: 5, bonus: ''),
      _RechargeOption(tokens: 1000, price: 9, bonus: '推荐'),
      _RechargeOption(tokens: 2000, price: 16, bonus: '最划算'),
      _RechargeOption(tokens: 5000, price: 35, bonus: '企业首选'),
    ];

    return GridView.count(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: options.map((opt) => GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('充值功能需对接支付SDK，当前使用卡密充值'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: opt.bonus == '推荐'
                  ? AppColors.primary(isDark)
                  : AppColors.divider(isDark),
              width: opt.bonus == '推荐' ? 2 : 0.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (opt.bonus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary(isDark).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    opt.bonus,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                ),
              Text(
                '${opt.tokens}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary(isDark),
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
              Text(
                '¥${opt.price}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}

class _ConsumptionRecord {
  final String title;
  final int amount;
  final DateTime time;
  final String type;

  _ConsumptionRecord({
    required this.title,
    required this.amount,
    required this.time,
    required this.type,
  });
}

class _RechargeOption {
  final int tokens;
  final int price;
  final String bonus;

  _RechargeOption({required this.tokens, required this.price, required this.bonus});
}
