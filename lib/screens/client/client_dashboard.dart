import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';
import 'browse_electricians_screen.dart';
import 'browse_plumbers_screen.dart';
import 'browse_cleaners_screen.dart';
import 'browse_painters_screen.dart';
import '../shared/chat_screen.dart';
import '../shared/rate_review_screen.dart';
import 'client_notifications_screen.dart';
import 'client_profile_screen.dart';
import 'points_history_screen.dart';
import '../shared/location_picker_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  int _idx = 0;

  late final List<Widget> _screens = [
    _DashboardHome(onSwitchTab: (i) => setState(() => _idx = i)),
    const _RequestsScreen(),
    const _BookingsScreen(),
    const _ChatsListScreen(),
    const ClientProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWatermark(
        child: IndexedStack(index: _idx, children: _screens),
      ),
      bottomNavigationBar: _CorpBottomNav(
        selectedIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

class _CorpBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _CorpBottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'Home'),
      (Icons.assignment_outlined, Icons.assignment_rounded, 'Requests'),
      (Icons.event_note_outlined, Icons.event_note_rounded, 'Bookings'),
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chats'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? items[i].$2 : items[i].$1,
                        size: 22,
                        color: selected
                            ? AppColors.navy
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].$3,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected
                              ? AppColors.navy
                              : AppColors.textTertiary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Dashboard Home ───────────────────────────────────────────────────────────

class _DashboardHome extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;
  const _DashboardHome({this.onSwitchTab});

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  int _active = 0;
  int _completed = 0;
  int _providerCount = 0;
  int _pointsBalance = 0;
  String _userName = 'User';
  String _searchQuery = '';
  bool _isLoading = true;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _recentRequests = [];

  static final _categories = [
    (
      Icons.bolt_rounded,
      'Electrician',
      Color(0xFFC8880A),
      Color(0xFFFAF3E0),
      () => const BrowseElectriciansScreen(),
    ),
    (
      Icons.plumbing_rounded,
      'Plumber',
      Color(0xFF1A5A7A),
      Color(0xFFE6F1F7),
      () => const BrowsePlumbersScreen(),
    ),
    (
      Icons.cleaning_services_rounded,
      'Cleaner',
      Color(0xFF4A1A7A),
      Color(0xFFEFE6F7),
      () => const BrowseCleanersScreen(),
    ),
    (
      Icons.format_paint_rounded,
      'Painter',
      Color(0xFF7A1A1A),
      Color(0xFFF7E6E6),
      () => const BrowsePaintersScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  List<(IconData, String, Color, Color, Widget Function())>
  get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    return _categories
        .where((c) => c.$2.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _isLoading = true);
    final hasNet = await ConnectivityService.hasInternet();
    if (!hasNet) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final userId = AuthService.getCurrentUserId();
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Load profile from Firestore for the real name
      final clientProfile = await DatabaseService.getClientProfile(userId);
      final name =
          clientProfile?['displayName'] ??
          AuthService.getCurrentUserDisplayName() ??
          'User';

      final stats = await DatabaseService.getClientStats(userId);
      final provCount = await DatabaseService.getUserCountByType('provider');
      final pointsBalance = await DatabaseService.getPointsBalance(userId);

      // Load requests — may fail if composite index not yet created
      List<Map<String, dynamic>> requests = [];
      try {
        requests = await DatabaseService.getClientRequests(userId);
      } catch (_) {
        // Index might not exist yet — will show empty list
      }

      // Count unread notifications (admin-feedback with notificationRead = false)
      int notifCount = 0;
      try {
        final reports = await DatabaseService.getClientReports(userId);
        notifCount = reports
            .where(
              (r) =>
                  ((r['adminFeedback'] ?? '').toString().trim().isNotEmpty ||
                      r['status'] == 'reviewed') &&
                  (r['notificationRead'] != true),
            )
            .length;
      } catch (_) {}
      // Add app notifications (booking accepted/rejected, payment_due, etc.)
      try {
        final appUnread =
            await DatabaseService.getUnreadNotificationCount(userId);
        notifCount += appUnread;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _active = stats['active'] ?? 0;
          _completed = stats['completed'] ?? 0;
          _providerCount = provCount;
          _pointsBalance = pointsBalance;
          _userName = name;
          _recentRequests = requests.take(5).toList();
          _unreadNotifications = notifCount;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openNotifications() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const ClientNotificationsScreen()),
    );
    _loadStats();
    if (result == null) return;
    final type = (result['type'] ?? '').toString();
    if (type == 'booking_accepted' ||
        type == 'booking_rejected' ||
        type == 'payment_due') {
      widget.onSwitchTab?.call(2); // Bookings tab
    }
  }

  void _showCreateRequestSheet() {
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    String selectedCategory = 'Electrician';
    bool isUrgent = false;
    double? detectedLat;
    double? detectedLng;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              MediaQuery.of(ctx).padding.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Create Service Request',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'CATEGORY',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      items: ['Electrician', 'Plumber', 'Cleaner', 'Painter']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setSheetState(
                        () => selectedCategory = v ?? 'Electrician',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'DESCRIPTION *',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe what you need...',
                      hintStyle: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.navy,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'LOCATION *',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Mirpur, Dhaka',
                      hintStyle: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 8),
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.map_rounded,
                          size: 18,
                          color: AppColors.navy,
                        ),
                        tooltip: 'Pick on map',
                        onPressed: () async {
                          final picked = await LocationPickerScreen.pick(
                            ctx,
                            initialLatitude: detectedLat,
                            initialLongitude: detectedLng,
                          );
                          if (picked != null) {
                            setSheetState(() {
                              locationCtrl.text = picked.address;
                              detectedLat = picked.latitude;
                              detectedLng = picked.longitude;
                            });
                          }
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.navy,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BUDGET (৳)',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: budgetCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '500',
                                hintStyle: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceAlt,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.navy,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'URGENT',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () =>
                                setSheetState(() => isUrgent = !isUrgent),
                            child: Container(
                              width: 52,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isUrgent
                                    ? AppColors.urgentBg
                                    : AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isUrgent
                                      ? AppColors.urgent
                                      : AppColors.border,
                                ),
                              ),
                              child: Icon(
                                Icons.bolt_rounded,
                                color: isUrgent
                                    ? AppColors.urgent
                                    : AppColors.textTertiary,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (descCtrl.text.trim().isEmpty ||
                            locationCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please fill description and location',
                              ),
                            ),
                          );
                          return;
                        }
                        final userId = AuthService.getCurrentUserId();
                        if (userId == null) return;
                        await DatabaseService.createServiceRequest(
                          clientId: userId,
                          category: selectedCategory,
                          description: descCtrl.text.trim(),
                          location: locationCtrl.text.trim(),
                          budget: budgetCtrl.text.trim(),
                          isUrgent: isUrgent,
                          latitude: detectedLat,
                          longitude: detectedLng,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _loadStats(); // Refresh
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Request created!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.navy),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.navy,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 14,
                20,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good morning,',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openNotifications,
                        child: Stack(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            if (_unreadNotifications > 0)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.navy,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _unreadNotifications > 9
                                        ? '9+'
                                        : '$_unreadNotifications',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Search bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: const InputDecoration(
                        hintText: 'Search services or providers...',
                        hintStyle: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Stats strip ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.navyDark,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  _StatChip(label: 'Active', value: '$_active'),
                  Container(
                    width: 1,
                    height: 28,
                    color: Colors.white.withOpacity(0.12),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  _StatChip(label: 'Completed', value: '$_completed'),
                  Container(
                    width: 1,
                    height: 28,
                    color: Colors.white.withOpacity(0.12),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  _StatChip(label: 'Providers', value: '$_providerCount'),
                ],
              ),
            ),
          ),

          // ── Points reward card ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _PointsCard(
                balance: _pointsBalance,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PointsHistoryScreen(),
                    ),
                  );
                  _loadStats();
                },
              ),
            ),
          ),

          // ── Categories ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: SectionHeader(
                title: 'Service Categories',
                action: _searchQuery.isNotEmpty ? 'View all' : '',
                onAction: () => setState(() => _searchQuery = ''),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, i) {
                final cat = _filteredCategories[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => cat.$5()),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cat.$4,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(cat.$1, size: 22, color: cat.$3),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          cat.$2,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: _filteredCategories.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
            ),
          ),

          // ── Recent Requests ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'Recent Requests',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showCreateRequestSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'New Request',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_recentRequests.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Center(
                  child: Text(
                    'No requests yet. Tap "New Request" to create one.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final r = _recentRequests[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: _RequestCard(
                    category: r['category'] ?? 'Service',
                    icon: Icons.bolt_rounded,
                    iconColor: const Color(0xFFC8880A),
                    iconBg: const Color(0xFFFAF3E0),
                    description: r['description'] ?? '',
                    location: r['location'] ?? '',
                    isUrgent: r['isUrgent'] == true,
                    status: (r['status'] ?? 'open').toString().toUpperCase(),
                    timeAgo: '',
                  ),
                );
              }, childCount: _recentRequests.length),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─── Points Card ──────────────────────────────────────────────────────────────

class _PointsCard extends StatelessWidget {
  final int balance;
  final VoidCallback onTap;
  const _PointsCard({required this.balance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final discountValue = DatabaseService.computeDiscountForPoints(balance);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.starBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: AppColors.star,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$balance points',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '≈ ৳$discountValue in discounts • Tap for history',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Request Card ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final String category;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String description;
  final String location;
  final bool isUrgent;
  final String status;
  final String timeAgo;

  const _RequestCard({
    required this.category,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.description,
    required this.location,
    required this.isUrgent,
    required this.status,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUrgent
              ? AppColors.urgent.withOpacity(0.35)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      category,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (isUrgent)
                      StatusBadge(
                        label: 'URGENT',
                        color: AppColors.urgent,
                        bgColor: AppColors.urgentBg,
                        icon: Icons.bolt_rounded,
                      ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: status.toUpperCase(),
                      color: AppColors.success,
                      bgColor: AppColors.successBg,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  timeAgo,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Requests Screen ──────────────────────────────────────────────────────────

class _RequestsScreen extends StatefulWidget {
  const _RequestsScreen();

  @override
  State<_RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<_RequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final userId = AuthService.getCurrentUserId();
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final reqs = await DatabaseService.getClientRequests(userId);
      if (mounted)
        setState(() {
          _requests = reqs;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Requests'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            )
          : _requests.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 52,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'No requests yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your service requests will appear here',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = _requests[i];
                  final status = r['status'] ?? 'open';
                  return _RequestCard(
                    category: r['category'] ?? 'Service',
                    icon: Icons.work_outline_rounded,
                    iconColor: AppColors.navy,
                    iconBg: AppColors.navyLight,
                    description: r['description'] ?? '',
                    location: r['location'] ?? '',
                    isUrgent: r['isUrgent'] == true,
                    status: status,
                    timeAgo: '',
                  );
                },
              ),
            ),
    );
  }
}

// ─── Chats List ───────────────────────────────────────────────────────────────

class _ChatsListScreen extends StatefulWidget {
  const _ChatsListScreen();

  @override
  State<_ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<_ChatsListScreen> {
  final Map<String, Map<String, dynamic>> _providerCache = {};

  Future<Map<String, String>> _resolveName(String providerId) async {
    if (providerId.isEmpty) return {'name': 'Provider', 'initials': 'P'};
    Map<String, dynamic>? prof = _providerCache[providerId];
    if (prof == null) {
      prof = await DatabaseService.getProviderProfile(providerId);
      if (prof != null) _providerCache[providerId] = prof;
    }
    final name = (prof?['displayName'] ?? prof?['name'] ?? 'Provider')
        .toString();
    final parts = name.split(' ');
    final initials = parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
        ? name[0].toUpperCase()
        : 'P';
    return {'name': name, 'initials': initials};
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.getCurrentUserId();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: userId == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: DatabaseService.streamUserConversations(userId, true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.navy),
                  );
                }
                final convs = snapshot.data ?? [];
                if (convs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 52,
                          color: AppColors.textTertiary,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Start chatting with a provider',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: convs.length,
                  itemBuilder: (context, i) {
                    final c = convs[i];
                    final providerId = (c['providerId'] ?? '') as String;
                    final lastMessage = (c['lastMessage'] ?? '').toString();
                    return FutureBuilder<Map<String, String>>(
                      future: _resolveName(providerId),
                      builder: (ctx, snap) {
                        final name = snap.data?['name'] ?? 'Provider';
                        final initials = snap.data?['initials'] ?? 'P';
                        return _ChatRow(
                          initials: initials,
                          name: name,
                          preview: lastMessage.isEmpty
                              ? 'Tap to continue chat'
                              : lastMessage,
                          time: '',
                          unread: 0,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: c['id'] ?? '',
                                otherUserName: name,
                                otherUserInitials: initials,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final String initials;
  final String name;
  final String preview;
  final String time;
  final int unread;
  final VoidCallback onTap;

  const _ChatRow({
    required this.initials,
    required this.name,
    required this.preview,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ProviderAvatar(initials: initials, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 5),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bookings Screen ──────────────────────────────────────────────────────────

class _BookingsScreen extends StatefulWidget {
  const _BookingsScreen();

  @override
  State<_BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<_BookingsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  final Map<String, Map<String, dynamic>> _providerCache = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = AuthService.getCurrentUserId();
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final list = await DatabaseService.getClientBookings(userId);
      for (final b in list) {
        final pid = (b['providerId'] ?? '') as String;
        if (pid.isNotEmpty && !_providerCache.containsKey(pid)) {
          final p = await DatabaseService.getProviderProfile(pid);
          if (p != null) _providerCache[pid] = p;
        }
      }
      if (mounted) {
        setState(() {
          _bookings = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  ({Color bg, Color fg, String label, IconData icon}) _statusStyle(String s) {
    switch (s) {
      case 'confirmed':
      case 'accepted':
        return (
          bg: AppColors.successBg,
          fg: AppColors.success,
          label: 'Accepted',
          icon: Icons.check_circle_rounded,
        );
      case 'rejected':
        return (
          bg: const Color(0xFFFBE9E7),
          fg: const Color(0xFFC62828),
          label: 'Rejected',
          icon: Icons.cancel_rounded,
        );
      case 'in_progress':
        return (
          bg: AppColors.navyLight,
          fg: AppColors.navy,
          label: 'In Progress',
          icon: Icons.play_circle_rounded,
        );
      case 'awaiting_payment':
        return (
          bg: const Color(0xFFFFF4E5),
          fg: const Color(0xFFB26A00),
          label: 'Payment Due',
          icon: Icons.payments_outlined,
        );
      case 'completed':
        return (
          bg: AppColors.successBg,
          fg: AppColors.success,
          label: 'Completed',
          icon: Icons.task_alt_rounded,
        );
      default:
        return (
          bg: const Color(0xFFFFF4E5),
          fg: const Color(0xFFB26A00),
          label: 'Pending',
          icon: Icons.hourglass_top_rounded,
        );
    }
  }

  Future<void> _editRate(Map<String, dynamic> booking) async {
    final current = (booking['agreedPrice'] ?? '').toString();
    final controller = TextEditingController(text: current);
    final newRate = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Edit Hourly Rate',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Propose a new hourly rate. The provider will be notified.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '৳ ',
                suffixText: '/ hr',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newRate == null || newRate.isEmpty || newRate == current) return;

    final hasNet = await ConnectivityService.hasInternet();
    if (!hasNet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
      return;
    }

    try {
      await DatabaseService.updateBookingRate(
        bookingId: booking['id'],
        newRate: newRate,
      );
      final providerId = (booking['providerId'] ?? '').toString();
      final clientId = AuthService.getCurrentUserId() ?? '';
      String clientName = 'Client';
      if (clientId.isNotEmpty) {
        final c = await DatabaseService.getClientProfile(clientId);
        clientName = (c?['displayName'] ?? c?['name'] ?? 'Client').toString();
      }
      if (providerId.isNotEmpty) {
        await DatabaseService.createNotification(
          userId: providerId,
          type: 'rate_change',
          title: 'Rate updated',
          message:
              '$clientName changed the hourly rate from ৳$current to ৳$newRate.',
          bookingId: (booking['id'] ?? '').toString(),
          extra: {'oldRate': current, 'newRate': newRate},
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rate updated. Provider has been notified.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update rate: ${e.toString().replaceAll("Exception: ", "")}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _makePayment(Map<String, dynamic> booking) async {
    final total = booking['totalAmount'];
    final hours = booking['hoursWorked'];
    final totalInt = total is num ? total.toInt() : 0;
    final totalStr = totalInt > 0
        ? totalInt.toString()
        : (total == null ? '0' : total.toString());

    // Existing booking-time redemption (already locked in at createBooking).
    int existingDiscount = 0;
    int existingPointsRedeemed = 0;
    final ed = booking['discountTaka'];
    if (ed is num) existingDiscount = ed.toInt();
    final ep = booking['pointsRedeemed'];
    if (ep is num) existingPointsRedeemed = ep.toInt();

    final clientId = AuthService.getCurrentUserId() ?? '';
    final balance = clientId.isEmpty
        ? 0
        : await DatabaseService.getPointsBalance(clientId);
    if (!mounted) return;

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        int payNowPoints = 0;
        bool useRedemption = false;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            // Cap the slider so the new discount can't exceed the bill.
            final maxNewDiscount =
                (totalInt - existingDiscount).clamp(0, totalInt);
            final sliderMax =
                (maxNewDiscount * 2).clamp(0, balance);
            if (payNowPoints > sliderMax) {
              payNowPoints = sliderMax;
            }
            final payNowDiscount =
                DatabaseService.computeDiscountForPoints(payNowPoints);
            final totalDiscount = existingDiscount + payNowDiscount;
            final dueNow =
                (totalInt - totalDiscount).clamp(0, totalInt);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Confirm Payment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.navyLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hours != null)
                            Text(
                              'Hours worked: $hours',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (hours != null) const SizedBox(height: 4),
                          Text(
                            'Total bill: ৳$totalStr',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                          if (existingPointsRedeemed > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Booking discount: −৳$existingDiscount '
                              '($existingPointsRedeemed pts)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (balance > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.starBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.star.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  color: AppColors.star,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You have $balance points',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                                if (balance >=
                                        DatabaseService
                                            .minPointsRedemption &&
                                    sliderMax >= 1)
                                  Switch.adaptive(
                                    value: useRedemption,
                                    activeColor: AppColors.accent,
                                    onChanged: (v) {
                                      setSt(() {
                                        useRedemption = v;
                                        payNowPoints = v
                                            ? DatabaseService
                                                .minPointsRedemption
                                                .clamp(0, sliderMax)
                                            : 0;
                                      });
                                    },
                                  )
                                else
                                  const SizedBox.shrink(),
                              ],
                            ),
                            if (useRedemption && sliderMax >= 1) ...[
                              Slider(
                                value: payNowPoints
                                    .toDouble()
                                    .clamp(1, sliderMax.toDouble()),
                                min: 1,
                                max: sliderMax.toDouble(),
                                divisions:
                                    (sliderMax - 1).clamp(1, sliderMax),
                                activeColor: AppColors.accent,
                                label: '$payNowPoints pts',
                                onChanged: (v) {
                                  setSt(() {
                                    payNowPoints = v.round();
                                  });
                                },
                              ),
                              Text(
                                'Use $payNowPoints pts → save ৳$payNowDiscount',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (balance > 0) const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Due now',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '৳$dueNow',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.success,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Navigator.pop(
                              ctx,
                              useRedemption ? payNowPoints : 0,
                            ),
                            child: Text(
                              'Pay ৳$dueNow now',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return; // user cancelled
    final paymentTimePoints = result;

    final hasNet = await ConnectivityService.hasInternet();
    if (!hasNet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
      return;
    }

    try {
      await DatabaseService.markBookingPaid(
        bookingId: booking['id'],
        paymentTimePointsToRedeem: paymentTimePoints,
      );
      final providerId = (booking['providerId'] ?? '').toString();
      final paid = (totalInt - existingDiscount -
              DatabaseService.computeDiscountForPoints(paymentTimePoints))
          .clamp(0, totalInt);
      if (providerId.isNotEmpty) {
        await DatabaseService.createNotification(
          userId: providerId,
          type: 'payment_received',
          title: 'Payment received',
          message: 'Client has paid ৳$paid. Booking marked as completed.',
          bookingId: (booking['id'] ?? '').toString(),
          extra: {'totalAmount': total},
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paymentTimePoints > 0
                  ? 'Payment complete. $paymentTimePoints pts redeemed.'
                  : 'Payment complete. Thank you!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment failed: ${e.toString().replaceAll("Exception: ", "")}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sent Booking Requests'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            )
          : _bookings.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    size: 52,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'No bookings yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Booking requests you send will appear here',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final b = _bookings[i];
                  final pid = (b['providerId'] ?? '') as String;
                  final prof = _providerCache[pid];
                  final name =
                      (prof?['displayName'] ??
                              prof?['name'] ??
                              'Provider')
                          .toString();
                  final specialty =
                      (prof?['serviceType'] ?? prof?['specialty'] ?? '')
                          .toString();
                  final desc = (b['description'] ?? '').toString();
                  final price = (b['agreedPrice'] ?? '').toString();
                  final style = _statusStyle((b['status'] ?? 'pending').toString());
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.navyLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  if (specialty.isNotEmpty)
                                    Text(
                                      specialty,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: style.bg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(style.icon, size: 13, color: style.fg),
                                  const SizedBox(width: 4),
                                  Text(
                                    style.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: style.fg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            desc,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (price.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.attach_money_rounded,
                                size: 16,
                                color: AppColors.accent,
                              ),
                              Text(
                                '$price / hr',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                              const Spacer(),
                              if (_canEditRate(b))
                                GestureDetector(
                                  onTap: () => _editRate(b),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentLight,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.accent.withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit_rounded,
                                          size: 12,
                                          color: AppColors.accent,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Edit Rate',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if ((b['pointsRedeemed'] is num
                                ? (b['pointsRedeemed'] as num).toInt()
                                : 0) >
                            0) ...[
                          const SizedBox(height: 10),
                          _RedemptionBreakdown(booking: b),
                        ],
                        if ((b['status'] ?? '') == 'awaiting_payment') ...[
                          const SizedBox(height: 12),
                          _PaymentCallout(
                            booking: b,
                            onPay: () => _makePayment(b),
                          ),
                        ],
                        if ((b['status'] ?? '') == 'completed' &&
                            b['totalAmount'] != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.task_alt_rounded,
                                  size: 14,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Paid ৳${_formatAmount(b['totalAmount'])}'
                                  '${b['hoursWorked'] != null ? ' • ${b['hoursWorked']} hrs' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if ((b['status'] ?? '') == 'completed') ...[
                          const SizedBox(height: 10),
                          if (b['reviewed'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.navyLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: AppColors.navy,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'You rated ${b['reviewRating'] ?? ''} / 5',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            if ((b['paid'] == true) &&
                                (b['pointsRecorded'] != true) &&
                                ((b['pointsEarnedByClient'] is num
                                        ? (b['pointsEarnedByClient'] as num)
                                            .toInt()
                                        : 0) >
                                    0))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.starBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.star.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.stars_rounded,
                                        size: 13,
                                        color: AppColors.star,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Earn ${(b['pointsEarnedByClient'] as num).toInt()} pts when you rate AND review',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.navy,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              height: 36,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _giveReview(b, name),
                                icon: const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Give Review',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _giveReview(
    Map<String, dynamic> booking,
    String providerName,
  ) async {
    final providerId = (booking['providerId'] ?? '').toString();
    final prof = _providerCache[providerId];
    final specialty =
        (prof?['serviceType'] ?? prof?['specialty'] ?? 'Service Provider')
            .toString();
    final parts = providerName.split(' ');
    final initials =
        parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : providerName.isNotEmpty
        ? providerName[0].toUpperCase()
        : 'P';
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RateReviewScreen(
          bookingId: (booking['id'] ?? '').toString(),
          providerId: providerId,
          providerName: providerName,
          providerInitials: initials,
          providerSpecialty: specialty,
        ),
      ),
    );
    if (submitted == true) _load();
  }

  bool _canEditRate(Map<String, dynamic> b) {
    final status = (b['status'] ?? 'pending').toString();
    return status == 'pending' ||
        status == 'confirmed' ||
        status == 'accepted' ||
        status == 'in_progress';
  }

  String _formatAmount(dynamic value) {
    if (value is num) return value.toStringAsFixed(0);
    return value.toString();
  }
}

class _RedemptionBreakdown extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _RedemptionBreakdown({required this.booking});

  int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) {
      return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final pointsRedeemed = _toInt(booking['pointsRedeemed']);
    final discount = _toInt(booking['discountTaka']) > 0
        ? _toInt(booking['discountTaka'])
        : DatabaseService.computeDiscountForPoints(pointsRedeemed);
    final agreed = _toInt(booking['agreedAmountTaka']) > 0
        ? _toInt(booking['agreedAmountTaka'])
        : _toInt(booking['agreedPrice']);
    final paid = _toInt(booking['paidAmountTaka']) > 0
        ? _toInt(booking['paidAmountTaka'])
        : (agreed - discount).clamp(0, agreed);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.starBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.star.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, size: 14, color: AppColors.star),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Agreed: ৳$agreed   Discount: −৳$discount   You paid: ৳$paid ($pointsRedeemed pts used)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCallout extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onPay;
  const _PaymentCallout({required this.booking, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final total = booking['totalAmount'];
    final hours = booking['hoursWorked'];
    final totalStr = total == null
        ? '0'
        : (total is num ? total.toStringAsFixed(0) : total.toString());
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.payments_rounded,
                size: 16,
                color: Color(0xFFB26A00),
              ),
              SizedBox(width: 6),
              Text(
                'Payment required',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB26A00),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hours != null
                ? 'Provider worked $hours hrs. Total due: ৳$totalStr'
                : 'Total due: ৳$totalStr',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onPay,
              icon: const Icon(Icons.payments_rounded, size: 16),
              label: const Text(
                'Make Payment',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
