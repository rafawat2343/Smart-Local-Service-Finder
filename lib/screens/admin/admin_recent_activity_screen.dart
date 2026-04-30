import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';

class AdminRecentActivityScreen extends StatefulWidget {
  const AdminRecentActivityScreen({super.key});

  @override
  State<AdminRecentActivityScreen> createState() =>
      _AdminRecentActivityScreenState();
}

class _AdminRecentActivityScreenState extends State<AdminRecentActivityScreen> {
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await DatabaseService.getRecentActivities(limit: 80);
      if (mounted) setState(() => _activities = items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
        ),
        title: const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (!_loading && _activities.isNotEmpty)
            TextButton(
              onPressed: _load,
              child: const Text(
                'Refresh',
                style: TextStyle(fontSize: 13, color: Color(0xFF6C63FF)),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _activities.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timeline_rounded,
                          size: 48, color: AppColors.textTertiary),
                      SizedBox(height: 12),
                      Text(
                        'No recent activity',
                        style: TextStyle(
                            fontSize: 15, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _activities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ActivityCard(item: _activities[i]),
                  ),
                ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ActivityCard({required this.item});

  static const _typeConfig = {
    'booking': _Config(
        color: Color(0xFF17A589),
        icon: Icons.calendar_today_rounded,
        bg: Color(0xFFE8F8F5)),
    'report': _Config(
        color: Color(0xFFE74C3C),
        icon: Icons.flag_rounded,
        bg: Color(0xFFFAEAEA)),
    'provider': _Config(
        color: Color(0xFF2ECC71),
        icon: Icons.construction_rounded,
        bg: Color(0xFFE9FAF0)),
    'user': _Config(
        color: Color(0xFF4B91F1),
        icon: Icons.person_rounded,
        bg: Color(0xFFEAF2FF)),
    'review': _Config(
        color: Color(0xFFE67E22),
        icon: Icons.star_rounded,
        bg: Color(0xFFFEF3E7)),
  };

  @override
  Widget build(BuildContext context) {
    final type = (item['type'] as String?) ?? 'user';
    final cfg = _typeConfig[type] ?? _typeConfig['user']!;
    final name = (item['name'] as String?) ?? 'Unknown';
    final subtitle = (item['subtitle'] as String?) ?? '';
    final ts = item['timestamp'];
    final timeLabel = ts == null
        ? ''
        : _fmt(ts is Timestamp ? ts.toDate() : ts as DateTime);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: cfg.bg, shape: BoxShape.circle),
            child: Icon(cfg.icon, color: cfg.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Config {
  final Color color, bg;
  final IconData icon;
  const _Config({required this.color, required this.icon, required this.bg});
}
