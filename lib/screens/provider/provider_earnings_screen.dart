import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';

class ProviderEarningsScreen extends StatefulWidget {
  const ProviderEarningsScreen({super.key});

  @override
  State<ProviderEarningsScreen> createState() =>
      _ProviderEarningsScreenState();
}

class _ProviderEarningsScreenState extends State<ProviderEarningsScreen> {
  bool _loading = true;
  int _lifetimeNet = 0;
  int _lifetimeCommission = 0;
  List<Map<String, dynamic>> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final providerId = AuthService.getCurrentUserId() ?? '';
    if (providerId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final user = await DatabaseService.getUserData(providerId);
    final providerProfile =
        await DatabaseService.getProviderProfile(providerId);
    final src = {...?user, ...?providerProfile};
    final lifetimeNet = _toInt(src['lifetimeEarningsTaka']);
    final lifetimeCommission = _toInt(src['lifetimeCommissionPaidTaka']);
    final entries =
        await DatabaseService.getProviderEarningsHistory(providerId);

    if (!mounted) return;
    setState(() {
      _lifetimeNet = lifetimeNet;
      _lifetimeCommission = lifetimeCommission;
      _entries = entries;
      _loading = false;
    });
  }

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) {
      return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final lifetimeGross = _lifetimeNet + _lifetimeCommission;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text('My Earnings'),
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
                  _NetHero(net: _lifetimeNet),
                  const SizedBox(height: 12),
                  _StatRow(
                    gross: lifetimeGross,
                    commission: _lifetimeCommission,
                    net: _lifetimeNet,
                  ),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Paid jobs',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (_entries.isEmpty)
                    _EmptyState()
                  else
                    ..._entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _EarningRow(entry: e),
                        )),
                  const SizedBox(height: 12),
                  _TotalFooter(net: _lifetimeNet),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _NetHero extends StatelessWidget {
  final int net;
  const _NetHero({required this.net});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.success, Color(0xFF155E48)],
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Total net earnings',
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
            '৳$net',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'After 10% platform fee, all-time',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final int gross;
  final int commission;
  final int net;
  const _StatRow({
    required this.gross,
    required this.commission,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Lifetime gross',
            value: '৳$gross',
            color: AppColors.navy,
            bg: AppColors.navyLight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Platform fee (10%)',
            value: '−৳$commission',
            color: AppColors.urgent,
            bg: AppColors.urgentBg,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Net to you',
            value: '৳$net',
            color: AppColors.success,
            bg: AppColors.successBg,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
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
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
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

class _EarningRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _EarningRow({required this.entry});

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) {
      return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final agreed = _toInt(entry['agreedAmountTaka']);
    final commission = _toInt(entry['amount']);
    final net = _toInt(entry['providerNetTaka']) > 0
        ? _toInt(entry['providerNetTaka'])
        : (agreed - commission);
    final specialty = (entry['specialty'] ?? 'Service').toString();
    final dateStr = _formatTs(entry['createdAt']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  specialty.isEmpty ? 'Service' : specialty,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _miniStat('Agreed', '৳$agreed', AppColors.navy),
              const SizedBox(width: 12),
              _miniStat('Commission', '−৳$commission', AppColors.urgent),
              const Spacer(),
              _miniStat('Net', '৳$net', AppColors.success, bold: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color,
      {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 14 : 12,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatTs(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final dt = ts.toDate();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _TotalFooter extends StatelessWidget {
  final int net;
  const _TotalFooter({required this.net});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Text(
            'Total net',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Text(
            '৳$net',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.success,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
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
            Icons.receipt_long_outlined,
            size: 44,
            color: AppColors.textTertiary,
          ),
          SizedBox(height: 10),
          Text(
            'No paid jobs yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Earnings will appear once a client pays.',
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
