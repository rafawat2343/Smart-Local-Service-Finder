import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';
import '../shared/chat_screen.dart';
import 'provider_notifications_screen.dart';
import 'provider_profile_screen.dart';

class ProviderFeedScreen extends StatefulWidget {
  const ProviderFeedScreen({super.key});

  @override
  State<ProviderFeedScreen> createState() => _ProviderFeedScreenState();
}

class _ProviderFeedScreenState extends State<ProviderFeedScreen> {
  int _idx = 0;

  late final List<Widget> _screens = [
    _FeedHome(onSwitchTab: (i) => setState(() => _idx = i)),
    const _BookingRequestsScreen(),
    const _MyJobsScreen(),
    const _ChatsScreen(),
    const ProviderProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWatermark(
        child: IndexedStack(index: _idx, children: _screens),
      ),
      bottomNavigationBar: _CorpNav(
        selectedIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

class _CorpNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _CorpNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.work_outline_rounded, Icons.work_rounded, 'Jobs'),
      (Icons.inbox_outlined, Icons.inbox_rounded, 'Requests'),
      (
        Icons.check_circle_outline_rounded,
        Icons.check_circle_rounded,
        'My Jobs',
      ),
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
                            ? AppColors.accent
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
                              ? AppColors.accent
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

// ─── Feed Home ────────────────────────────────────────────────────────────────

class _FeedHome extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;
  const _FeedHome({this.onSwitchTab});

  @override
  State<_FeedHome> createState() => _FeedHomeState();
}

class _FeedHomeState extends State<_FeedHome> {
  bool _isOnline = true;
  bool _isLoading = true;
  List<Map<String, dynamic>> _jobs = [];
  String _providerName = 'Provider';
  String _providerInitials = 'P';
  String _providerLocation = '';
  String _providerSpecialty = '';
  double? _providerLat;
  double? _providerLng;
  int _providerHourlyRate = 0;
  int _todayJobs = 0;
  int _monthJobs = 0;
  String _earnings = '৳0';
  int _selectedFilter = 0;

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  List<Map<String, dynamic>> get _filteredJobs {
    if (_selectedFilter == 0) return _jobs; // All Jobs
    if (_selectedFilter == 1) {
      // Nearby — GPS 2 km radius when coords available, else string match
      final pLat = _providerLat;
      final pLng = _providerLng;
      if (pLat != null && pLng != null) {
        return _jobs.where((j) {
          final jLat = j['latitude'];
          final jLng = j['longitude'];
          if (jLat is num && jLng is num) {
            return _haversineKm(pLat, pLng, jLat.toDouble(), jLng.toDouble()) <=
                2.0;
          }
          // Fall back to string match for older requests without coords
          final jobLoc = (j['location'] ?? '').toString().toLowerCase();
          final provLoc = _providerLocation.toLowerCase();
          return provLoc.isNotEmpty &&
              (jobLoc.contains(provLoc) || provLoc.contains(jobLoc));
        }).toList();
      }
      // No provider coords — string match
      if (_providerLocation.trim().isEmpty) return _jobs;
      return _jobs.where((j) {
        final jobLoc = (j['location'] ?? '').toString().toLowerCase();
        final provLoc = _providerLocation.toLowerCase();
        return jobLoc.contains(provLoc) || provLoc.contains(jobLoc);
      }).toList();
    }
    if (_selectedFilter == 2) {
      // Urgent only
      return _jobs.where((j) => j['isUrgent'] == true).toList();
    }
    if (_selectedFilter == 3) {
      // High Pay — budget > provider's hourly rate
      if (_providerHourlyRate > 0) {
        return _jobs
            .where((j) => _parseBudget(j['budget']) > _providerHourlyRate)
            .toList();
      }
      // If provider rate unknown, sort by budget descending
      final sorted = List<Map<String, dynamic>>.from(_jobs);
      sorted.sort((a, b) =>
          _parseBudget(b['budget']).compareTo(_parseBudget(a['budget'])));
      return sorted;
    }
    return _jobs;
  }

  int _parseBudget(dynamic value) {
    final cleaned = value.toString().replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
      final profile = await DatabaseService.getProviderProfile(userId);
      final name =
          profile?['displayName'] ??
          AuthService.getCurrentUserDisplayName() ??
          'Provider';
      final parts = name.split(' ');
      final initials = parts.length >= 2
          ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
          : name.isNotEmpty
          ? name[0].toUpperCase()
          : 'P';
      final specialty =
          profile?['serviceType'] ?? profile?['specialty'] ?? '';
      final location = profile?['location'] ?? profile?['address'] ?? '';

      // Load jobs filtered by this provider's specialty
      final jobs = specialty.isNotEmpty
          ? await DatabaseService.getOpenRequests(category: specialty)
          : await DatabaseService.getOpenRequests();

      // Load real stats
      final stats = await DatabaseService.getProviderStats(userId);
      final totalEarnings = (stats['totalEarnings'] ?? 0).toDouble();
      final earningsStr = totalEarnings >= 1000
          ? '৳${(totalEarnings / 1000).toStringAsFixed(1)}k'
          : '৳${totalEarnings.toInt()}';

      if (mounted) {
        setState(() {
          _providerName = name;
          _providerInitials = initials;
          _providerLocation = location.toString();
          _providerSpecialty = specialty.toString();
          _jobs = jobs;
          _todayJobs = stats['activeJobs'] ?? 0;
          _monthJobs = stats['totalJobs'] ?? 0;
          _earnings = earningsStr;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electrician':
        return Icons.bolt_rounded;
      case 'plumber':
        return Icons.plumbing_rounded;
      case 'cleaner':
        return Icons.cleaning_services_rounded;
      case 'painter':
        return Icons.format_paint_rounded;
      default:
        return Icons.work_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'electrician':
        return const Color(0xFFC8880A);
      case 'plumber':
        return const Color(0xFF1A5A7A);
      case 'cleaner':
        return const Color(0xFF4A1A7A);
      case 'painter':
        return const Color(0xFF7A1A1A);
      default:
        return AppColors.navy;
    }
  }

  Color _categoryBg(String category) {
    switch (category.toLowerCase()) {
      case 'electrician':
        return const Color(0xFFFAF3E0);
      case 'plumber':
        return const Color(0xFFE6F1F7);
      case 'cleaner':
        return const Color(0xFFEFE6F7);
      case 'painter':
        return const Color(0xFFF7E6E6);
      default:
        return AppColors.navyLight;
    }
  }

  void _toggleOnline() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isOnline
                    ? const Color(0xFFFFEEEE)
                    : AppColors.successBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isOnline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                size: 18,
                color: _isOnline ? const Color(0xFFD94040) : AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isOnline ? 'Go Offline?' : 'Go Online?',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          _isOnline
              ? 'You will stop receiving new job requests while offline. You can go back online anytime.'
              : 'You will start receiving job requests from clients near you.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.navyLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final newStatus = !_isOnline;
              setState(() => _isOnline = newStatus);
              Navigator.pop(context);
              // Save online status to Firestore
              final userId = AuthService.getCurrentUserId();
              if (userId != null) {
                try {
                  await DatabaseService.setUserStatus(
                    userId: userId,
                    isOnline: newStatus,
                  );
                } catch (_) {}
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: _isOnline ? const Color(0xFFD94040) : AppColors.success,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isOnline ? 'Go Offline' : 'Go Online',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.accent,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 14,
                20,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProviderAvatar(initials: _providerInitials, size: 40),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.55),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            _providerName,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (_providerSpecialty.trim().isNotEmpty)
                            Text(
                              _providerSpecialty,
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.65),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      _NotificationBell(
                        userId: AuthService.getCurrentUserId(),
                        onOpenRequests: () => widget.onSwitchTab?.call(1),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _toggleOnline,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _isOnline
                                ? AppColors.success
                                : AppColors.textTertiary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 7,
                                color: _isOnline
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.7),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isOnline ? 'ONLINE' : 'OFFLINE',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // KPI strip
                  Row(
                    children: [
                      _KpiTile(label: "Today's Jobs", value: '$_todayJobs'),
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.black.withOpacity(0.1),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      _KpiTile(label: 'This Month', value: '$_monthJobs'),
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.black.withOpacity(0.1),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      _KpiTile(label: 'Earnings', value: _earnings),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Filter tabs
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['All Jobs', 'Nearby', 'Urgent', 'High Pay']
                          .asMap()
                          .entries
                          .map(
                            (e) => GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedFilter = e.key),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: e.key == _selectedFilter
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: e.key == _selectedFilter
                                        ? Colors.white
                                        : Colors.black.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: e.key == _selectedFilter
                                        ? AppColors.accent
                                        : Colors.black.withOpacity(0.75),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Offline banner
          if (!_isOnline)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'You are offline. Tap OFFLINE to go back online and receive job requests.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A4500),
                          height: 1.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleOnline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Go Online',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Section label
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: SectionHeader(
                title: 'Available Requests (${_filteredJobs.length})',
                action: 'Refresh',
                onAction: () => _loadData(),
              ),
            ),
          ),

          // Job cards
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final job = _filteredJobs[i];
                final isUrgent = job['isUrgent'] == true;
                final category = (job['category'] ?? '') as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isUrgent
                            ? AppColors.urgent.withOpacity(0.4)
                            : AppColors.border,
                        width: isUrgent ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _categoryBg(category),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _categoryIcon(category),
                                      color: _categoryColor(category),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Posted by ${job['clientId'] ?? 'Client'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isUrgent)
                                    StatusBadge(
                                      label: 'URGENT',
                                      color: AppColors.urgent,
                                      bgColor: AppColors.urgentBg,
                                      icon: Icons.bolt_rounded,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                (job['description'] ?? '') as String,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(10),
                            ),
                            border: Border(
                              top: BorderSide(color: AppColors.divider),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${job['location'] ?? 'Location not set'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '৳${job['budget'] ?? '0'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 30,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final providerId =
                                        AuthService.getCurrentUserId();
                                    if (providerId == null) return;
                                    final requestId = job['id'] ?? '';
                                    final clientId = job['clientId'] ?? '';
                                    final budget = job['budget'] ?? '';
                                    final jobSpecialty = (job['category'] ??
                                            job['categoryKey'] ??
                                            job['serviceType'] ??
                                            '')
                                        .toString();

                                    final hasNet =
                                        await ConnectivityService.hasInternet();
                                    if (!hasNet) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'No internet connection',
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    try {
                                      await DatabaseService.createBooking(
                                        requestId: requestId,
                                        clientId: clientId,
                                        providerId: providerId,
                                        agreedPrice: budget,
                                        status: 'confirmed',
                                        specialty: jobSpecialty,
                                      );
                                      String providerName = _providerName;
                                      if (providerName.isEmpty) {
                                        try {
                                          final p = await DatabaseService
                                              .getProviderProfile(providerId);
                                          providerName = (p?['displayName'] ??
                                                  p?['name'] ??
                                                  'Provider')
                                              .toString();
                                        } catch (_) {}
                                      }
                                      if (clientId.isNotEmpty) {
                                        await DatabaseService
                                            .createNotification(
                                          userId: clientId,
                                          type: 'booking_accepted',
                                          title: 'Request accepted',
                                          message:
                                              '$providerName accepted your service request. Open Bookings to track progress.',
                                          bookingId: requestId,
                                        );
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Accepted. Client notified — check My Jobs.',
                                            ),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                        // Refresh the jobs list
                                        _loadData();
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to accept: ${e.toString().replaceAll("Exception: ", "")}',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isUrgent
                                        ? AppColors.urgent
                                        : AppColors.accent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                  ),
                                  child: Text(
                                    isUrgent ? 'Accept Now' : 'Accept',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: _filteredJobs.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final String? userId;
  final VoidCallback? onOpenRequests;
  const _NotificationBell({required this.userId, this.onOpenRequests});

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox.shrink();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService.streamUserNotifications(userId!),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        final unread = items.where((n) => n['read'] != true).length;
        return GestureDetector(
          onTap: () async {
            final result = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(
                builder: (_) => const ProviderNotificationsScreen(),
              ),
            );
            if (result == null) return;
            final type = (result['type'] ?? '').toString();
            if (type == 'rate_change' || type == 'new_booking') {
              onOpenRequests?.call();
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  size: 18,
                  color: Colors.black,
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD94040),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      textAlign: TextAlign.center,
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
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  const _KpiTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.black.withOpacity(0.5),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

// ─── My Jobs ──────────────────────────────────────────────────────────────────

class _MyJobsScreen extends StatefulWidget {
  const _MyJobsScreen();
  @override
  State<_MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<_MyJobsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (mounted) setState(() => _loading = true);
    final userId = AuthService.getCurrentUserId();
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final raw = await DatabaseService.getProviderBookings(userId);
      // Show only bookings the provider has accepted (exclude pending).
      final accepted = raw
          .where((b) => (b['status'] ?? '') != 'pending')
          .toList();

      final enriched = <Map<String, dynamic>>[];
      for (final b in accepted) {
        final requestId = (b['requestId'] ?? '').toString();
        final clientId = (b['clientId'] ?? '').toString();

        Map<String, dynamic>? request;
        if (requestId.isNotEmpty) {
          request = await DatabaseService.getServiceRequest(requestId);
        }

        String clientName = 'Client';
        if (clientId.isNotEmpty) {
          final clientData = await DatabaseService.getClientProfile(clientId);
          clientName = (clientData?['displayName'] ?? 'Client').toString();
        }

        enriched.add({
          ...b,
          'category': request?['category'] ?? '',
          'description': request?['description'] ?? '',
          'location': request?['location'] ?? '',
          'isUrgent': request?['isUrgent'] ?? false,
          'clientName': clientName,
        });
      }

      if (mounted) {
        setState(() {
          _bookings = enriched;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electrician':
        return Icons.bolt_rounded;
      case 'plumber':
        return Icons.plumbing_rounded;
      case 'cleaner':
        return Icons.cleaning_services_rounded;
      case 'painter':
        return Icons.format_paint_rounded;
      default:
        return Icons.work_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('My Jobs'),
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.black,
      automaticallyImplyLeading: false,
    ),
    body: _loading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          )
        : _bookings.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.work_outline_rounded,
                  size: 52,
                  color: AppColors.textTertiary,
                ),
                SizedBox(height: 14),
                Text(
                  'No active jobs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Accepted jobs will appear here',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadBookings,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final b = _bookings[i];
                final status = (b['status'] ?? 'pending').toString();
                final price = (b['agreedPrice'] ?? '').toString();
                final category = (b['category'] ?? '').toString();
                final clientName = (b['clientName'] ?? 'Client').toString();
                final location = (b['location'] ?? '').toString();
                final description = (b['description'] ?? '').toString();
                final isUrgent = b['isUrgent'] == true;
                final displayTitle = category.isNotEmpty
                    ? category
                    : 'Booking #${(b['id'] ?? '').toString().substring(0, 6)}';
                final statusColor = status == 'completed'
                    ? AppColors.success
                    : status == 'in_progress'
                    ? AppColors.accent
                    : AppColors.navy;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isUrgent
                          ? AppColors.urgent.withOpacity(0.4)
                          : AppColors.border,
                      width: isUrgent ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _categoryIcon(category),
                              size: 20,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Client: $clientName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isUrgent)
                            const StatusBadge(
                              label: 'URGENT',
                              color: AppColors.urgent,
                              bgColor: AppColors.urgentBg,
                              icon: Icons.bolt_rounded,
                            ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (location.isNotEmpty) ...[
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ] else
                            const Spacer(),
                          if (price.isNotEmpty)
                            Text(
                              '৳$price',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (status == 'pending' || status == 'confirmed')
                            SizedBox(
                              height: 30,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final newStatus = status == 'pending'
                                      ? 'confirmed'
                                      : 'in_progress';
                                  await DatabaseService.updateBookingStatus(
                                    bookingId: b['id'],
                                    status: newStatus,
                                  );
                                  _loadBookings();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                child: Text(
                                  status == 'pending' ? 'Confirm' : 'Start',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          if (status == 'in_progress')
                            SizedBox(
                              height: 30,
                              child: ElevatedButton(
                                onPressed: () => _promptHoursWorked(b),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          if (status == 'awaiting_payment')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4E5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFFB74D),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.hourglass_top_rounded,
                                    size: 12,
                                    color: Color(0xFFB26A00),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Awaiting payment${b['totalAmount'] != null ? ' • ৳${_formatAmount(b['totalAmount'])}' : ''}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB26A00),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (status == 'completed' &&
                              b['totalAmount'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.task_alt_rounded,
                                    size: 12,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Paid ৳${_formatAmount(b['totalAmount'])}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
  );

  String _formatAmount(dynamic value) {
    if (value is num) return value.toStringAsFixed(0);
    return value.toString();
  }

  Future<void> _promptHoursWorked(Map<String, dynamic> booking) async {
    final rateStr = (booking['agreedPrice'] ?? '0').toString();
    final rate = double.tryParse(rateStr.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;
    final controller = TextEditingController();
    double preview = 0.0;

    final hours = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Hours Worked',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rate: ৳${rate.toStringAsFixed(0)} / hr',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Hours',
                  suffixText: 'hrs',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (v) {
                  final h = double.tryParse(v.trim()) ?? 0.0;
                  setLocal(() => preview = h * rate);
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.navyLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '৳${preview.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
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
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () {
                final h = double.tryParse(controller.text.trim()) ?? 0.0;
                if (h <= 0) return;
                Navigator.pop(ctx, h);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (hours == null || hours <= 0) return;

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
      await DatabaseService.submitHoursWorked(
        bookingId: booking['id'],
        hours: hours,
      );
      final total = rate * hours;
      final clientId = (booking['clientId'] ?? '').toString();
      final providerId = AuthService.getCurrentUserId();
      String providerName = 'Provider';
      if (providerId != null) {
        try {
          final p = await DatabaseService.getProviderProfile(providerId);
          providerName =
              (p?['displayName'] ?? p?['name'] ?? 'Provider').toString();
        } catch (_) {}
      }
      if (clientId.isNotEmpty) {
        await DatabaseService.createNotification(
          userId: clientId,
          type: 'payment_due',
          title: 'Job completed • Payment due',
          message:
              '$providerName logged ${hours.toStringAsFixed(1)} hrs. Total: ৳${total.toStringAsFixed(0)}. Please make the payment.',
          bookingId: (booking['id'] ?? '').toString(),
          extra: {'hours': hours, 'total': total},
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Submitted. Total ৳${total.toStringAsFixed(0)} — waiting for client payment.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadBookings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit: ${e.toString().replaceAll("Exception: ", "")}',
            ),
          ),
        );
      }
    }
  }
}

// ─── Chats ────────────────────────────────────────────────────────────────────

class _ChatsScreen extends StatefulWidget {
  const _ChatsScreen();
  @override
  State<_ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<_ChatsScreen> {
  final Map<String, Map<String, dynamic>> _clientCache = {};

  Future<Map<String, String>> _resolveName(String clientId) async {
    if (clientId.isEmpty) return {'name': 'Client', 'initials': 'C'};
    Map<String, dynamic>? prof = _clientCache[clientId];
    if (prof == null) {
      prof = await DatabaseService.getClientProfile(clientId);
      if (prof != null) _clientCache[clientId] = prof;
    }
    final name =
        (prof?['displayName'] ?? prof?['name'] ?? 'Client').toString();
    final parts = name.split(' ');
    final initials =
        parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
        ? name[0].toUpperCase()
        : 'C';
    return {'name': name, 'initials': initials};
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.getCurrentUserId();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: userId == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: DatabaseService.streamUserConversations(userId, false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
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
                          'Client messages will appear here',
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
                    final clientId = (c['clientId'] ?? '') as String;
                    final lastMessage = (c['lastMessage'] ?? '').toString();
                    return FutureBuilder<Map<String, String>>(
                      future: _resolveName(clientId),
                      builder: (ctx, snap) {
                        final name = snap.data?['name'] ?? 'Client';
                        final initials = snap.data?['initials'] ?? 'C';
                        return GestureDetector(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        lastMessage.isEmpty
                                            ? 'Tap to continue chat'
                                            : lastMessage,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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

// ─── Booking Requests Screen (Provider) ───────────────────────────────────────

class _BookingRequestsScreen extends StatefulWidget {
  const _BookingRequestsScreen();

  @override
  State<_BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<_BookingRequestsScreen> {
  List<Map<String, dynamic>> _pending = [];
  final Map<String, Map<String, dynamic>> _clientCache = {};
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
      final all = await DatabaseService.getProviderBookings(userId);
      final pending = all
          .where((b) => (b['status'] ?? '') == 'pending')
          .toList();
      for (final b in pending) {
        final cid = (b['clientId'] ?? '') as String;
        if (cid.isNotEmpty && !_clientCache.containsKey(cid)) {
          final c = await DatabaseService.getClientProfile(cid);
          if (c != null) _clientCache[cid] = c;
        }
      }
      if (mounted) {
        setState(() {
          _pending = pending;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(Map<String, dynamic> booking, String clientName) async {
    final providerId = AuthService.getCurrentUserId();
    final clientId = (booking['clientId'] ?? '').toString();
    if (providerId == null || clientId.isEmpty) return;

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
      final convId = await DatabaseService.getOrCreateConversation(
        clientId: clientId,
        providerId: providerId,
      );
      if (!mounted) return;
      final parts = clientName.split(' ');
      final initials =
          parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty
          ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
          : clientName.isNotEmpty
          ? clientName[0].toUpperCase()
          : 'C';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convId,
            otherUserName: clientName,
            otherUserInitials: initials,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to open chat: ${e.toString().replaceAll("Exception: ", "")}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _respond(Map<String, dynamic> booking, bool accept) async {
    final ok = await _confirm(
      title: accept ? 'Accept Booking?' : 'Reject Booking?',
      message: accept
          ? 'Confirm you want to accept this booking request. The client will be notified.'
          : 'Confirm you want to reject this booking request. The client will be notified.',
      confirmLabel: accept ? 'Accept' : 'Reject',
      confirmColor: accept ? AppColors.success : const Color(0xFFC62828),
    );
    if (ok != true) return;
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
      await DatabaseService.updateBookingStatus(
        bookingId: booking['id'],
        status: accept ? 'confirmed' : 'rejected',
      );
      final providerId = AuthService.getCurrentUserId();
      final clientId = (booking['clientId'] ?? '') as String;
      if (accept) {
        if (providerId != null && clientId.isNotEmpty) {
          await DatabaseService.getOrCreateConversation(
            clientId: clientId,
            providerId: providerId,
          );
        }
      }
      if (clientId.isNotEmpty && providerId != null) {
        String providerName = 'Provider';
        try {
          final p = await DatabaseService.getProviderProfile(providerId);
          providerName =
              (p?['displayName'] ?? p?['name'] ?? 'Provider').toString();
        } catch (_) {}
        await DatabaseService.createNotification(
          userId: clientId,
          type: accept ? 'booking_accepted' : 'booking_rejected',
          title: accept ? 'Booking accepted' : 'Booking rejected',
          message: accept
              ? '$providerName accepted your booking request. You can now chat or make payment when the job is done.'
              : '$providerName rejected your booking request.',
          bookingId: (booking['id'] ?? '').toString(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Booking accepted' : 'Booking rejected',
            ),
            backgroundColor: accept
                ? AppColors.success
                : const Color(0xFFC62828),
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Action failed: ${e.toString().replaceAll("Exception: ", "")}',
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
        title: const Text('Booking Requests'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _pending.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 52,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'No pending requests',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Incoming booking requests will appear here',
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
                itemCount: _pending.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final b = _pending[i];
                  final cid = (b['clientId'] ?? '') as String;
                  final cp = _clientCache[cid];
                  final name = (cp?['displayName'] ?? cp?['name'] ?? 'Client')
                      .toString();
                  final desc = (b['description'] ?? '').toString();
                  final price = (b['agreedPrice'] ?? '').toString();
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
                                color: AppColors.accentLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _openChat(b, name),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.navyLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            if (price.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$price / hr',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.navySubtle,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFC62828),
                                  side: const BorderSide(
                                    color: Color(0xFFC62828),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _respond(b, false),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Reject',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _respond(b, true),
                                icon: const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Accept',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
