import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';

class PointsHistoryScreen extends StatefulWidget {
  const PointsHistoryScreen({super.key});

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  bool _loading = true;
  Map<String, int> _summary = {
    'balance': 0,
    'lifetimeEarned': 0,
    'lifetimeRedeemed': 0,
  };
  List<Map<String, dynamic>> _history = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = AuthService.getCurrentUserId() ?? '';
    final summary = await DatabaseService.getPointsSummary(userId);
    final history = await DatabaseService.getPointsHistory(userId);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _history = history;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final balance = _summary['balance'] ?? 0;
    final discountValue =
        DatabaseService.computeDiscountForPoints(balance);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text('My Points'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _BalanceHero(balance: balance, discountValue: discountValue),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryChip(
                          label: 'Lifetime earned',
                          value: '+${_summary['lifetimeEarned'] ?? 0}',
                          color: AppColors.success,
                          bg: AppColors.successBg,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryChip(
                          label: 'Lifetime redeemed',
                          value: '-${_summary['lifetimeRedeemed'] ?? 0}',
                          color: AppColors.urgent,
                          bg: AppColors.urgentBg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Activity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (_history.isEmpty)
                    _EmptyState()
                  else
                    ..._history.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _LedgerRow(entry: e),
                        )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  final int balance;
  final int discountValue;
  const _BalanceHero({required this.balance, required this.discountValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyMid],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.star.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: AppColors.star,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Reward balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$balance pts',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '≈ ৳$discountValue in discounts • 1 pt = ৳0.5',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _LedgerRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final type = (entry['type'] ?? '').toString();
    final amount = (entry['amount'] is num)
        ? (entry['amount'] as num).toInt()
        : 0;
    final isEarned = type == 'points_earned';
    final color = isEarned ? AppColors.success : AppColors.urgent;
    final bg = isEarned ? AppColors.successBg : AppColors.urgentBg;
    final icon = isEarned
        ? Icons.add_circle_outline_rounded
        : Icons.remove_circle_outline_rounded;
    final desc =
        (entry['description'] ?? '').toString().trim();
    final dateStr = _formatTs(entry['createdAt']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc.isEmpty
                      ? (isEarned ? 'Points earned' : 'Points redeemed')
                      : desc,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isEarned ? '+' : '−'}$amount',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTs(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final dt = ts.toDate();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.stars_outlined,
            size: 44,
            color: AppColors.textTertiary,
          ),
          SizedBox(height: 10),
          Text(
            'No points yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Earn 1 point per ৳100 spent.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
