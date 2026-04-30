import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';
import '../shared/chat_screen.dart';
import 'report_provider_screen.dart';

class ProviderDetailScreen extends StatefulWidget {
  final String providerId;
  final String name;
  final String initials;
  final String specialty;
  final String exp;
  final double rating;
  final int reviews;
  final double distance;
  final bool available;
  final String price;
  final int jobs;

  const ProviderDetailScreen({
    super.key,
    this.providerId = '',
    required this.name,
    required this.initials,
    required this.specialty,
    required this.exp,
    required this.rating,
    required this.reviews,
    required this.distance,
    required this.available,
    required this.price,
    required this.jobs,
  });

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  bool _isBookmarked = false;
  String _clientId = '';
  late Future<Map<String, dynamic>> _detailFuture;

  @override
  void initState() {
    super.initState();
    _clientId = AuthService.getCurrentUserId() ?? '';
    _detailFuture = _loadProviderDetail();
    _loadBookmarkState();
  }

  Future<void> _loadBookmarkState() async {
    if (_clientId.isEmpty || widget.providerId.isEmpty) return;
    final bookmarked = await DatabaseService.isBookmarked(
      _clientId,
      widget.providerId,
    );
    if (mounted) setState(() => _isBookmarked = bookmarked);
  }

  Future<void> _toggleBookmark() async {
    if (_clientId.isEmpty || widget.providerId.isEmpty) return;
    setState(() => _isBookmarked = !_isBookmarked);
    try {
      await DatabaseService.toggleBookmark(_clientId, widget.providerId);
    } catch (_) {
      if (mounted) setState(() => _isBookmarked = !_isBookmarked);
    }
  }

  Future<Map<String, dynamic>> _loadProviderDetail() async {
    final baseProfile = {
      'id': widget.providerId,
      'displayName': widget.name,
      'name': widget.name,
      'initials': widget.initials,
      'specialty': widget.specialty,
      'serviceType': widget.specialty,
      'exp': widget.exp,
      'experience': widget.exp,
      'rating': widget.rating,
      'ratingAvg': widget.rating,
      'reviews': widget.reviews,
      'totalReviews': widget.reviews,
      'distance': widget.distance,
      'available': widget.available,
      'isAvailable': widget.available,
      'price': widget.price,
      'hourlyRate': widget.price,
      'jobs': widget.jobs,
      'jobsCompleted': widget.jobs,
      'about': '',
      'services': const <String>[],
      'availabilityText': '',
    };

    if (widget.providerId.isEmpty) {
      return {'profile': baseProfile, 'reviews': <Map<String, dynamic>>[]};
    }

    Map<String, dynamic>? providerData;
    Map<String, dynamic>? userData;
    List<Map<String, dynamic>> providerReviews = const [];

    try {
      providerData =
          await DatabaseService.getProviderProfile(widget.providerId);
    } catch (_) {}
    try {
      userData = await DatabaseService.getUserData(widget.providerId);
    } catch (_) {}
    try {
      providerReviews =
          await DatabaseService.getProviderReviews(widget.providerId);
    } catch (_) {}

    final merged = {...baseProfile, ...?userData, ...?providerData};

    final liveName =
        (merged['displayName'] ?? merged['name'] ?? widget.name).toString();
    final liveSpecialty =
        (merged['serviceType'] ?? merged['specialty'] ?? widget.specialty)
            .toString();
    final liveExp =
        (merged['experience'] ?? merged['exp'] ?? widget.exp).toString();
    final liveInitials = (merged['initials'] ?? widget.initials).toString();
    final liveAbout =
        (merged['about'] ?? merged['aboutText'] ?? '').toString();
    final liveAvailabilityText =
        (merged['availabilityText'] ?? merged['availableText'] ?? '')
            .toString();
    final liveServices = _normalizeServices(
      merged['services'] ?? merged['servicesOffered'],
    );
    final liveRating = _toDouble(
      merged['ratingAvg'] ?? merged['rating'],
      fallback: widget.rating,
    );
    final liveReviewCount = providerReviews.isNotEmpty
        ? providerReviews.length
        : _toInt(
            merged['totalReviews'] ?? merged['reviews'],
            fallback: widget.reviews,
          );
    final livePriceValue =
        (merged['hourlyRate'] ?? merged['price'] ?? widget.price).toString();
    final liveAvailable =
        (merged['isAvailable'] ?? merged['available'] ?? widget.available) ==
        true;
    final liveJobs = _toInt(
      merged['jobsCompleted'] ?? merged['jobs'],
      fallback: widget.jobs,
    );

    return {
      'profile': {
        ...merged,
        'id': widget.providerId,
        'displayName': liveName,
        'name': liveName,
        'initials': liveInitials,
        'specialty': liveSpecialty,
        'serviceType': liveSpecialty,
        'exp': liveExp,
        'experience': liveExp,
        'rating': liveRating,
        'ratingAvg': liveRating,
        'reviews': liveReviewCount,
        'totalReviews': liveReviewCount,
        'available': liveAvailable,
        'isAvailable': liveAvailable,
        'price': livePriceValue,
        'hourlyRate': livePriceValue,
        'jobs': liveJobs,
        'jobsCompleted': liveJobs,
        'about': liveAbout,
        'aboutText': liveAbout,
        'services': liveServices,
        'servicesOffered': liveServices,
        'availabilityText': liveAvailabilityText,
      },
      'reviews': providerReviews,
    };
  }

  static List<String> _normalizeServices(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      return raw
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? fallback;
    }
    return fallback;
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? fallback;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            ),
          );
        }

        final data =
            snapshot.data ??
            {'profile': {}, 'reviews': <Map<String, dynamic>>[]};
        final profile = Map<String, dynamic>.from(
          data['profile'] as Map? ?? {},
        );
        final reviewItems = List<Map<String, dynamic>>.from(
          (data['reviews'] as List<dynamic>? ?? <Map<String, dynamic>>[]).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );

        final providerId =
            (profile['id'] ?? widget.providerId).toString();
        final name =
            (profile['displayName'] ?? profile['name'] ?? widget.name)
                .toString();
        final initials =
            (profile['initials'] ?? widget.initials).toString();
        final specialty =
            (profile['specialty'] ?? profile['serviceType'] ?? widget.specialty)
                .toString();
        final exp =
            (profile['exp'] ?? profile['experience'] ?? widget.exp).toString();
        final rating = _toDouble(
          profile['ratingAvg'] ?? profile['rating'],
          fallback: widget.rating,
        );
        final reviews = _toInt(
          profile['totalReviews'] ?? profile['reviews'],
          fallback: widget.reviews,
        );
        final distance = _toDouble(
          profile['distance'],
          fallback: widget.distance,
        );
        final available =
            (profile['isAvailable'] ??
                profile['available'] ??
                widget.available) ==
            true;
        final price =
            (profile['hourlyRate'] ?? profile['price'] ?? widget.price)
                .toString();
        final jobs = _toInt(
          profile['jobsCompleted'] ?? profile['jobs'],
          fallback: widget.jobs,
        );
        final aboutText = (profile['about'] ?? profile['aboutText'] ?? '')
            .toString()
            .trim();
        final availabilityText =
            (profile['availabilityText'] ?? profile['availableText'] ?? '')
                .toString()
                .trim();
        final services = _normalizeServices(
          profile['services'] ?? profile['servicesOffered'],
        );

        return Scaffold(
          body: BackgroundWatermark(
            child: Column(
              children: [
                // ── Scrollable Content ─────────────────────────────────────
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // ── App Bar ────────────────────────────────────────────
                      SliverAppBar(
                        expandedHeight: 220,
                        pinned: true,
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        leading: Padding(
                          padding: const EdgeInsets.all(8),
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        actions: [
                          // Report
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 4, 8),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.flag_rounded,
                                  size: 17,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportProviderScreen(
                                      providerId: providerId,
                                      providerName: name,
                                    ),
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                                tooltip: 'Report Provider',
                              ),
                            ),
                          ),
                          // Bookmark
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _isBookmarked
                                    ? Colors.white.withOpacity(0.22)
                                    : Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isBookmarked
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_outline_rounded,
                                  size: 17,
                                  color: Colors.white,
                                ),
                                onPressed: () async {
                                  await _toggleBookmark();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _isBookmarked
                                              ? 'Saved to bookmarks'
                                              : 'Removed from bookmarks',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                padding: EdgeInsets.zero,
                                tooltip: _isBookmarked ? 'Unsave' : 'Save',
                              ),
                            ),
                          ),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            color: AppColors.navy,
                            child: Stack(
                              children: [
                                Positioned(
                                  top: -20,
                                  right: -20,
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.04),
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 56),
                                    ProviderAvatar(
                                      initials: initials,
                                      size: 76,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.verified_rounded,
                                          size: 16,
                                          color: Color(0xFF64B5F6),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '$specialty · $exp experience',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Stats ───────────────────────────────────────
                              CorpCard(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: StatItem(
                                        value: '$rating',
                                        label: 'RATING',
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: AppColors.divider,
                                    ),
                                    Expanded(
                                      child: StatItem(
                                        value: '$reviews',
                                        label: 'REVIEWS',
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: AppColors.divider,
                                    ),
                                    Expanded(
                                      child: StatItem(
                                        value: '$jobs',
                                        label: 'JOBS',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ── Info Strip ──────────────────────────────────
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 11,
                                      ),
                                      decoration: BoxDecoration(
                                        color: available
                                            ? AppColors.successBg
                                            : AppColors.urgentBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: available
                                              ? AppColors.success.withOpacity(
                                                  0.25,
                                                )
                                              : AppColors.urgent.withOpacity(
                                                  0.25,
                                                ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            available
                                                ? Icons
                                                      .check_circle_outline_rounded
                                                : Icons.cancel_outlined,
                                            size: 15,
                                            color: available
                                                ? AppColors.success
                                                : AppColors.urgent,
                                          ),
                                          const SizedBox(width: 7),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                available
                                                    ? 'Available'
                                                    : 'Unavailable',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: available
                                                      ? AppColors.success
                                                      : AppColors.urgent,
                                                ),
                                              ),
                                              Text(
                                                availabilityText.isNotEmpty
                                                    ? availabilityText
                                                    : available
                                                    ? 'Today'
                                                    : 'Try again later',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: available
                                                      ? AppColors.success
                                                      : AppColors.urgent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 11,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.navyLight,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.payments_outlined,
                                            size: 15,
                                            color: AppColors.navy,
                                          ),
                                          const SizedBox(width: 7),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'From ৳$price',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.navy,
                                                ),
                                              ),
                                              const Text(
                                                'Per hour',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.navy,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Distance chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.accent.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 15,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      '$distance km away from your location',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // ── About ───────────────────────────────────────
                              const SectionHeader(title: 'About'),
                              const SizedBox(height: 10),
                              CorpCard(
                                child: Text(
                                  aboutText.isNotEmpty
                                      ? aboutText
                                      : 'No about information has been added yet for this provider.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.65,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // ── Services ────────────────────────────────────
                              const SectionHeader(title: 'Services Offered'),
                              const SizedBox(height: 10),
                              services.isEmpty
                                  ? CorpCard(
                                      child: Text(
                                        'No services have been added yet.',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          height: 1.55,
                                        ),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: services
                                          .map(
                                            (s) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 7,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.navyLight,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: AppColors.border,
                                                ),
                                              ),
                                              child: Text(
                                                s,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.navy,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                              const SizedBox(height: 20),

                              // ── Reviews ─────────────────────────────────────
                              SectionHeader(
                                title: 'Client Reviews',
                                action: 'See all $reviews',
                                onAction: () {},
                              ),
                              const SizedBox(height: 10),
                              ...reviewItems.map(
                                (r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: CorpCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            ProviderAvatar(
                                              initials: r['initials'] as String,
                                              size: 34,
                                              backgroundColor:
                                                  AppColors.navyMid,
                                            ),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r['name'] as String,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  r['date'] as String,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.textTertiary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Spacer(),
                                            starRating(
                                              r['rating'] as double,
                                              size: 12,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        const Divider(
                                          height: 1,
                                          color: AppColors.divider,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          r['text'] as String,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                            height: 1.55,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Bottom Action Bar ──────────────────────────────────────
                Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    MediaQuery.of(context).padding.bottom + 12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      // Price display
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Starting from',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '৳$price/hr',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Chat button
                      GestureDetector(
                        onTap: () async {
                          final clientId = AuthService.getCurrentUserId();
                          if (clientId == null || providerId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Unable to start chat'),
                              ),
                            );
                            return;
                          }
                          final hasNet =
                              await ConnectivityService.hasInternet();
                          if (!hasNet) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No internet connection'),
                                ),
                              );
                            }
                            return;
                          }
                          final convId =
                              await DatabaseService.getOrCreateConversation(
                                clientId: clientId,
                                providerId: providerId,
                              );
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  conversationId: convId,
                                  otherUserName: name,
                                  otherUserInitials: initials,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.navyLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 20,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Book Now button
                      Expanded(
                        child: GestureDetector(
                          onTap: available
                              ? () => _showBookingSheet(
                                    context,
                                    providerName: name,
                                    providerId: providerId,
                                    defaultPrice: price,
                                    specialty: specialty,
                                  )
                              : null,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: available
                                  ? AppColors.accent
                                  : AppColors.textTertiary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  available
                                      ? Icons.calendar_today_rounded
                                      : Icons.block_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  available ? 'Book Now' : 'Unavailable',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
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
      },
    );
  }

  void _showBookingSheet(
    BuildContext context, {
    required String providerName,
    required String providerId,
    required String defaultPrice,
    String specialty = '',
  }) {
    final priceController = TextEditingController(
      text: defaultPrice.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    final descController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
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
                    Text(
                      'Book $providerName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Set your offer rate and describe the task',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Hourly rate (\$)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        hintText: 'e.g. 35',
                        filled: true,
                        fillColor: AppColors.navyLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Task description',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe what you need help with...',
                        filled: true,
                        fillColor: AppColors.navyLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: submitting
                            ? null
                            : () async {
                                final clientId = AuthService.getCurrentUserId();
                                if (clientId == null || providerId.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Unable to create booking',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final rate = priceController.text.trim();
                                final desc = descController.text.trim();
                                if (rate.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter a rate'),
                                    ),
                                  );
                                  return;
                                }
                                if (desc.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please describe the task',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final hasNet =
                                    await ConnectivityService.hasInternet();
                                if (!hasNet) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No internet connection',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                setSt(() => submitting = true);
                                try {
                                  await DatabaseService.createBooking(
                                    requestId: '',
                                    clientId: clientId,
                                    providerId: providerId,
                                    agreedPrice: '\$$rate',
                                    description: desc,
                                    specialty: specialty,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Booking request sent to $providerName',
                                        ),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setSt(() => submitting = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Booking failed: ${e.toString().replaceAll("Exception: ", "")}',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Text(
                                'Send Booking Request',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
  }
}
