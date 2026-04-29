import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;
  DateTime? _lastSeen;

  static const _lastSeenKey = 'admin_notif_last_seen';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastSeenKey);
    _lastSeen = ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    await _load();
    // Mark all as read
    await prefs.setInt(_lastSeenKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await DatabaseService.getRecentActivities(limit: 30);
      if (mounted) setState(() => _activities = items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isNew(Map<String, dynamic> item) {
    if (_lastSeen == null) return false;
    final ts = item['timestamp'];
    if (ts == null) return false;
    final dt = ts is Timestamp ? ts.toDate() : ts as DateTime;
    return dt.isAfter(_lastSeen!);
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: const Text(
          'Notifications',
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
                      Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.textTertiary),
                      SizedBox(height: 12),
                      Text(
                        'No notifications yet',
                        style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _activities.length,
                    itemBuilder: (_, i) {
                      final item = _activities[i];
                      final isNew = _isNew(item);
                      return _NotifCard(item: item, isNew: isNew);
                    },
                  ),
                ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isNew;
  const _NotifCard({required this.item, required this.isNew});

  static const _typeConfig = {
    'booking': _Config(color: Color(0xFF17A589), icon: Icons.calendar_today_rounded, bg: Color(0xFFE8F8F5)),
    'report':  _Config(color: Color(0xFFE74C3C), icon: Icons.flag_rounded,           bg: Color(0xFFFAEAEA)),
    'provider':_Config(color: Color(0xFF2ECC71), icon: Icons.construction_rounded,   bg: Color(0xFFE9FAF0)),
    'user':    _Config(color: Color(0xFF4B91F1), icon: Icons.person_rounded,         bg: Color(0xFFEAF2FF)),
    'review':  _Config(color: Color(0xFFE67E22), icon: Icons.star_rounded,           bg: Color(0xFFFEF3E7)),
  };

  @override
  Widget build(BuildContext context) {
    final type = (item['type'] as String?) ?? 'user';
    final cfg = _typeConfig[type] ?? _typeConfig['user']!;
    final name = (item['name'] as String?) ?? 'Unknown';
    final subtitle = (item['subtitle'] as String?) ?? '';
    final ts = item['timestamp'];
    final timeLabel = ts == null ? '' : _fmt(ts is Timestamp ? ts.toDate() : ts as DateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNew ? const Color(0xFFF5F3FF) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNew ? const Color(0xFF6C63FF).withOpacity(0.3) : AppColors.border,
        ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isNew)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C63FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
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
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Config {
  final Color color, bg;
  final IconData icon;
  const _Config({required this.color, required this.icon, required this.bg});
}
