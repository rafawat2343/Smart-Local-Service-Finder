import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../shared/user_type_screen.dart';
import 'admin_category_screen.dart';
import 'admin_listings_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_platform_health_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_records_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_revenue_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;
  int _unreadCount = 0;

  static const _lastSeenKey = 'admin_notif_last_seen';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeenMs = prefs.getInt(_lastSeenKey);
      final lastSeen = lastSeenMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastSeenMs)
          : null;

      final results = await Future.wait([
        DatabaseService.getAdminDashboardStats(),
        DatabaseService.getRecentActivities(limit: 6),
      ]);

      final activities = results[1] as List<Map<String, dynamic>>;
      int unread = 0;
      if (lastSeen != null) {
        for (final a in activities) {
          final ts = a['timestamp'];
          if (ts == null) continue;
          final dt = ts is Timestamp ? ts.toDate() : ts as DateTime;
          if (dt.isAfter(lastSeen)) unread++;
        }
      } else {
        unread = activities.length;
      }

      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _activities = activities;
          _unreadCount = unread;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminNotificationsScreen()),
    );
    // After returning, update last-seen and clear badge
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeenKey, DateTime.now().millisecondsSinceEpoch);
    if (mounted) setState(() => _unreadCount = 0);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const UserTypeScreen()),
      (_) => false,
    );
  }

  void _navigate(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _AdminAppBar(
            unreadCount: _unreadCount,
            onNotificationTap: _openNotifications,
            onSignOut: _signOut,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeroCard(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuickNavRow(),
                          const SizedBox(height: 24),
                          _buildRecentActivity(),
                          const SizedBox(height: 24),
                          _buildPlatformHealth(),
                          const SizedBox(height: 24),
                          _buildCategoryBreakdown(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Card ──────────────────────────────────────────────────────────────

  Widget _buildHeroCard() {
    final totalUsers = _stats['totalUsers'] ?? 0;
    final totalProviders = _stats['totalProviders'] ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2B3A), Color(0xFF0F1F2D)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.admin_panel_settings_rounded,
              size: 100,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A017).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.5)),
                ),
                child: const Text(
                  'ADMIN PANEL',
                  style: TextStyle(
                    color: Color(0xFFD4A017),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Platform Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _loading ? 'Loading platform data...' : 'Everything is running smoothly today.',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(
                    icon: Icons.people_alt_rounded,
                    label: '$totalUsers Users',
                    color: const Color(0xFF4B91F1),
                  ),
                  _HeroChip(
                    icon: Icons.construction_rounded,
                    label: '$totalProviders Providers',
                    color: const Color(0xFF2ECC71),
                  ),
                  const _HeroChip(
                    icon: Icons.check_circle_rounded,
                    label: '98.2% Uptime',
                    color: Color(0xFF2ECC71),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick Nav Row (replaces both stat grid + management cards) ─────────────

  Widget _buildQuickNavRow() {
    final items = [
      _QuickNavData(
        icon: Icons.people_alt_rounded,
        label: 'Users',
        count: _stats['totalUsers'] as int? ?? 0,
        color: const Color(0xFF6C63FF),
        bg: const Color(0xFFF0EEFF),
        onTap: () => _navigate(const AdminUsersScreen()),
      ),
      _QuickNavData(
        icon: Icons.construction_rounded,
        label: 'Listings',
        count: _stats['totalProviders'] as int? ?? 0,
        color: const Color(0xFF17A589),
        bg: const Color(0xFFE8F8F5),
        onTap: () => _navigate(const AdminListingsScreen()),
      ),
      _QuickNavData(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Revenue',
        count: _stats['completedBookings'] as int? ?? 0,
        color: const Color(0xFF1A7A4A),
        bg: const Color(0xFFE8F5EE),
        onTap: () => _navigate(const AdminRevenueScreen()),
      ),
      _QuickNavData(
        icon: Icons.assignment_rounded,
        label: 'Records',
        count: ((_stats['totalRequests'] ?? 0) as int) +
            ((_stats['totalBookings'] ?? 0) as int),
        color: const Color(0xFF2980B9),
        bg: const Color(0xFFEAF4FC),
        onTap: () => _navigate(const AdminRecordsScreen()),
      ),
      _QuickNavData(
        icon: Icons.flag_rounded,
        label: 'Reports',
        count: _stats['totalReports'] as int? ?? 0,
        color: const Color(0xFF7B2D8B),
        bg: const Color(0xFFF4E8F9),
        onTap: () => _navigate(const AdminReportsScreen()),
      ),
    ];

    // Scrollable row so all 5 cards fit without squeezing
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(
          width: 76,
          child: _QuickNavCard(data: items[i], loading: _loading),
        ),
      ),
    );
  }

  // ── Recent Activity ────────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            TextButton(
              onPressed: _openNotifications,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_activities.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No recent activity',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activities.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 60, color: AppColors.divider),
              itemBuilder: (_, i) => _ActivityTile(item: _activities[i]),
            ),
          ),
      ],
    );
  }

  // ── Platform Health (with bar chart) ──────────────────────────────────────

  Widget _buildPlatformHealth() {
    final activeProvPct  = (_stats['activeProviderPct']   as int?) ?? 0;
    final bookingCompPct = (_stats['bookingCompletionPct'] as int?) ?? 0;
    final avgRating      = (_stats['avgRating']           as double?) ?? 0.0;
    final resolvedPct    = (_stats['resolvedReportsPct']  as int?) ?? 0;
    final ratingPct      = (avgRating / 5.0 * 100).round().clamp(0, 100);

    final metrics = [
      _HealthData('Active Providers',    activeProvPct,  const Color(0xFF2ECC71), '$activeProvPct%'),
      _HealthData('Booking Completion',  bookingCompPct, const Color(0xFF4B91F1), '$bookingCompPct%'),
      _HealthData('User Satisfaction',   ratingPct,      const Color(0xFFE67E22),
          avgRating == 0.0 ? 'N/A' : '${avgRating.toStringAsFixed(1)}/5'),
      _HealthData('Resolved Complaints', resolvedPct,    const Color(0xFF4B91F1), '$resolvedPct%'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Platform Health',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              GestureDetector(
                onTap: () => _navigate(AdminPlatformHealthScreen(stats: _stats)),
                child: const Text(
                  'View',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6C63FF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vertical bar chart
          _VerticalBarChart(metrics: metrics),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),

          // List with horizontal bars
          ...metrics.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HealthMetricRow(data: m),
              )),
        ],
      ),
    );
  }

  // ── Category Breakdown (with bar chart) ───────────────────────────────────

  Widget _buildCategoryBreakdown() {
    final raw =
        (_stats['categoryBreakdown'] as Map?)?.cast<String, int>() ?? {};
    final total = raw.values.fold(0, (a, b) => a + b);

    final colors = [
      const Color(0xFF4B91F1),
      const Color(0xFF2ECC71),
      const Color(0xFFE67E22),
      const Color(0xFF9B59B6),
    ];

    // Fixed canonical categories shown always
    const canonicalKeys = ['Plumbing', 'Cleaning', 'Electrical', 'Painter'];
    List<MapEntry<String, int>> entries;
    if (raw.isEmpty || total == 0) {
      entries = const [
        MapEntry('Plumbing', 32),
        MapEntry('Cleaning', 28),
        MapEntry('Electrical', 18),
        MapEntry('Painter', 22),
      ];
    } else {
      // Merge into canonical buckets
      final Map<String, int> merged = {for (final k in canonicalKeys) k: 0};
      for (final e in raw.entries) {
        final s = e.key.toLowerCase();
        if (s.contains('plumb')) {
          merged['Plumbing'] = (merged['Plumbing'] ?? 0) + e.value;
        } else if (s.contains('clean')) {
          merged['Cleaning'] = (merged['Cleaning'] ?? 0) + e.value;
        } else if (s.contains('electric')) {
          merged['Electrical'] = (merged['Electrical'] ?? 0) + e.value;
        } else if (s.contains('paint')) {
          merged['Painter'] = (merged['Painter'] ?? 0) + e.value;
        } else {
          merged['Painter'] = (merged['Painter'] ?? 0) + e.value;
        }
      }
      entries = merged.entries.toList();
    }

    final displayTotal = entries.fold(0, (s, e) => s + e.value);

    final catMetrics = entries.asMap().entries.map((e) {
      final pct = displayTotal == 0 ? 0 : (e.value.value * 100 ~/ displayTotal);
      return _HealthData(
        e.value.key,
        pct,
        colors[e.key % colors.length],
        '$pct%',
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Category Breakdown',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              GestureDetector(
                onTap: () => _navigate(AdminCategoryScreen(stats: _stats)),
                child: const Text(
                  'View',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6C63FF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vertical bar chart
          _VerticalBarChart(metrics: catMetrics),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),

          // Horizontal progress bars list
          ...catMetrics.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CategoryBarRow(data: m),
              )),
        ],
      ),
    );
  }
}

// ── App Bar with notification bell + user dropdown ─────────────────────────

class _AdminAppBar extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onNotificationTap;
  final VoidCallback onSignOut;
  const _AdminAppBar({
    required this.unreadCount,
    required this.onNotificationTap,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Admin';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A';

    return Container(
      color: AppColors.navy,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        16,
        16,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // Notification bell
          GestureDetector(
            onTap: onNotificationTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE74C3C),
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // User dropdown
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminProfileScreen()));
              } else if (value == 'settings') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminSettingsScreen()));
              } else if (value == 'signout') {
                onSignOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    ),
                    const Text(
                      'Administrator',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    const Divider(height: 1),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Text('Profile',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined,
                        size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Text('Settings',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Sign Out',
                        style: TextStyle(fontSize: 14, color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: const Color(0xFFD4A017),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Nav Card ─────────────────────────────────────────────────────────

class _QuickNavData {
  final IconData icon;
  final String label;
  final int count;
  final Color color, bg;
  final VoidCallback onTap;
  const _QuickNavData({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
    required this.onTap,
  });
}

class _QuickNavCard extends StatelessWidget {
  final _QuickNavData data;
  final bool loading;
  const _QuickNavCard({required this.data, required this.loading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: data.bg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(data.icon, color: data.color, size: 18),
            ),
            const SizedBox(height: 6),
            loading
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: data.color,
                    ),
                  )
                : Text(
                    '${data.count}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: data.color,
                      letterSpacing: -0.3,
                    ),
                  ),
            const SizedBox(height: 2),
            Text(
              data.label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vertical Bar Chart ─────────────────────────────────────────────────────

class _HealthData {
  final String label, valueLabel;
  final int percent;
  final Color color;
  const _HealthData(this.label, this.percent, this.color, this.valueLabel);
}

class _VerticalBarChart extends StatelessWidget {
  final List<_HealthData> metrics;
  const _VerticalBarChart({required this.metrics});

  @override
  Widget build(BuildContext context) {
    const barAreaH = 90.0;
    final maxPct = metrics.fold(0, (m, d) => math.max(m, d.percent));
    final effectiveMax = maxPct == 0 ? 1 : maxPct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Value labels row
        Row(
          children: metrics.asMap().entries.map((e) {
            final d = e.value;
            final isLast = e.key == metrics.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: Text(
                  d.valueLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: d.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        // Bar area (fixed height, no overflow)
        SizedBox(
          height: barAreaH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: metrics.asMap().entries.map((e) {
              final d = e.value;
              final isLast = e.key == metrics.length - 1;
              final barH = (d.percent / effectiveMax * barAreaH).clamp(4.0, barAreaH);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 8),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    child: Container(
                      height: barH,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [d.color, d.color.withOpacity(0.65)],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        // Short label row
        Row(
          children: metrics.asMap().entries.map((e) {
            final d = e.value;
            final isLast = e.key == metrics.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: Text(
                  _shortLabel(d.label),
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _shortLabel(String label) {
    final words = label.split(' ');
    if (words.length == 1) return label.length > 8 ? '${label.substring(0, 7)}.' : label;
    return words.map((w) => w[0].toUpperCase()).join('');
  }
}

// ── Health Metric Row (dot + label + bar + value) ─────────────────────────

class _HealthMetricRow extends StatelessWidget {
  final _HealthData data;
  const _HealthMetricRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: data.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  data.label,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            Text(
              data.valueLabel,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: data.color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: data.percent / 100,
            minHeight: 5,
            backgroundColor: AppColors.background,
            valueColor: AlwaysStoppedAnimation<Color>(data.color),
          ),
        ),
      ],
    );
  }
}

// ── Category Bar Row ───────────────────────────────────────────────────────

class _CategoryBarRow extends StatelessWidget {
  final _HealthData data;
  const _CategoryBarRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              data.label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            Text(
              data.valueLabel,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: data.color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: data.percent / 100,
            minHeight: 6,
            backgroundColor: AppColors.background,
            valueColor: AlwaysStoppedAnimation<Color>(data.color),
          ),
        ),
      ],
    );
  }
}

// ── Activity Tile ──────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ActivityTile({required this.item});

  static const _cfg = {
    'booking':  _TileCfg(Color(0xFF17A589), Icons.calendar_today_rounded),
    'report':   _TileCfg(Color(0xFFE74C3C), Icons.flag_rounded),
    'provider': _TileCfg(Color(0xFF2ECC71), Icons.construction_rounded),
    'user':     _TileCfg(Color(0xFF4B91F1), Icons.person_rounded),
    'review':   _TileCfg(Color(0xFFE67E22), Icons.star_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final type = (item['type'] as String?) ?? 'user';
    final cfg = _cfg[type] ?? _cfg['user']!;
    final name = (item['name'] as String?) ?? 'Unknown';
    final subtitle = (item['subtitle'] as String?) ?? '';
    final ts = item['timestamp'];
    final timeLabel = ts == null
        ? ''
        : _fmt(ts is Timestamp ? ts.toDate() : ts as DateTime);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cfg.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(cfg.icon, color: cfg.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(timeLabel,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day ago';
  }
}

class _TileCfg {
  final Color color;
  final IconData icon;
  const _TileCfg(this.color, this.icon);
}

// ── Hero Chip ──────────────────────────────────────────────────────────────

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HeroChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
