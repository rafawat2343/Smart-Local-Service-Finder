import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';
import 'provider_detail_screen.dart';

class BrowsePlumbersScreen extends StatefulWidget {
  const BrowsePlumbersScreen({super.key});

  @override
  State<BrowsePlumbersScreen> createState() => _BrowsePlumbersScreenState();
}

class _BrowsePlumbersScreenState extends State<BrowsePlumbersScreen> {
  int _selectedFilter = 0;
  String _sortBy = 'Rating';
  double _maxPrice = 5000;
  double _maxDistance = 50.0;
  List<Map<String, dynamic>> _allProviders = [];
  bool _loading = true;
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadProviders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    try {
      final providers = await DatabaseService.getProvidersByServiceType(
        'Plumber',
      );
      if (mounted) {
        setState(() {
          _allProviders = providers.map((p) {
            final name = p['displayName'] ?? 'Provider';
            final parts = name.split(' ');
            final initials = parts.length >= 2
                ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
                : name.isNotEmpty
                ? name[0].toUpperCase()
                : 'P';
            return {
              'id': p['id'] ?? p['userId'] ?? '',
              'initials': initials,
              'name': name,
              'specialty': p['serviceType'] ?? p['specialty'] ?? 'Plumber',
              'exp': '${p['experience'] ?? '0'} yrs',
              'rating': (p['ratingAvg'] ?? 0.0) is int
                  ? (p['ratingAvg'] as int).toDouble()
                  : (p['ratingAvg'] ?? 0.0),
              'reviews': p['totalReviews'] ?? 0,
              'distance': 0.0,
              'available': p['isAvailable'] ?? true,
              'price': p['hourlyRate'] ?? '500',
              'jobs': p['totalJobs'] ?? 0,
            };
          }).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _filters = [
    'All',
    'Top Rated',
    'Nearest',
    'Available',
    'Budget',
  ];

  List<Map<String, dynamic>> get _providers {
    var list = List<Map<String, dynamic>>.from(_allProviders);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      list = list
          .where(
            (p) => (p['name'] ?? '').toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }

    if (_selectedFilter == 1) {
      list.sort(
        (a, b) => ((b['rating'] ?? 0.0) as double).compareTo(
          (a['rating'] ?? 0.0) as double,
        ),
      );
    } else if (_selectedFilter == 2) {
      list.sort(
        (a, b) => ((a['distance'] ?? 0.0) as double).compareTo(
          (b['distance'] ?? 0.0) as double,
        ),
      );
    } else if (_selectedFilter == 3) {
      list = list.where((p) => p['available'] == true).toList();
    } else if (_selectedFilter == 4) {
      list.sort(
        (a, b) => int.parse(
          '${a['price'] ?? '0'}',
        ).compareTo(int.parse('${b['price'] ?? '0'}')),
      );
    }

    list = list
        .where((p) => int.parse('${p['price'] ?? '0'}') <= _maxPrice)
        .toList();
    list = list
        .where((p) => ((p['distance'] ?? 0.0) as double) <= _maxDistance)
        .toList();

    if (_sortBy == 'Rating') {
      list.sort(
        (a, b) => ((b['rating'] ?? 0.0) as double).compareTo(
          (a['rating'] ?? 0.0) as double,
        ),
      );
    } else if (_sortBy == 'Distance') {
      list.sort(
        (a, b) => ((a['distance'] ?? 0.0) as double).compareTo(
          (b['distance'] ?? 0.0) as double,
        ),
      );
    } else if (_sortBy == 'Price') {
      list.sort(
        (a, b) => int.parse(
          '${a['price'] ?? '0'}',
        ).compareTo(int.parse('${b['price'] ?? '0'}')),
      );
    }

    return list;
  }

  void _toggleSort() {
    setState(() {
      if (_sortBy == 'Rating') {
        _sortBy = 'Distance';
      } else if (_sortBy == 'Distance') {
        _sortBy = 'Price';
      } else {
        _sortBy = 'Rating';
      }
    });
  }

  void _openFilterSheet() {
    double tempPrice = _maxPrice;
    double tempDistance = _maxDistance;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              MediaQuery.of(context).padding.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
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
                Row(
                  children: [
                    const Text(
                      'Advanced Filters',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setSheetState(() {
                          tempPrice = 5000;
                          tempDistance = 50.0;
                        });
                      },
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 16,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'MAX BUDGET',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '৳${tempPrice.round()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: tempPrice,
                  min: 100,
                  max: 5000,
                  divisions: 49,
                  activeColor: AppColors.accent,
                  inactiveColor: AppColors.border,
                  onChanged: (v) => setSheetState(() => tempPrice = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'MAX DISTANCE',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${tempDistance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: tempDistance,
                  min: 1.0,
                  max: 50.0,
                  divisions: 49,
                  activeColor: AppColors.accent,
                  inactiveColor: AppColors.border,
                  onChanged: (v) => setSheetState(() => tempDistance = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _maxPrice = tempPrice;
                        _maxDistance = tempDistance;
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providers = _providers;
    return Scaffold(
      body: BackgroundWatermark(
        child: Column(
          children: [
            Container(
              color: AppColors.navy,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 12,
                20,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const NavBackButton(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Plumbers',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Near your location',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.54),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _openFilterSheet,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    cursorColor: Colors.white,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by provider name...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.54),
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.white.withOpacity(0.7),
                        size: 18,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () => setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              }),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: 18,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final selected = i == _selectedFilter;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedFilter = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _filters[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.8),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Text(
                    '${providers.length} plumbers found',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toggleSort,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.swap_vert_rounded,
                          size: 15,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _sortBy,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.navy),
                    )
                  : providers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No providers found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'No plumbers registered yet',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProviders,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: providers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final p = providers[i];
                          final available = p['available'] == true;
                          final rating = (p['rating'] ?? 0.0) is int
                              ? (p['rating'] as int).toDouble()
                              : (p['rating'] ?? 0.0) as double;
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProviderDetailScreen(
                                  providerId: '${p['id'] ?? ''}',
                                  name: '${p['name'] ?? 'Provider'}',
                                  initials: '${p['initials'] ?? 'P'}',
                                  specialty: '${p['specialty'] ?? ''}',
                                  exp: '${p['exp'] ?? ''}',
                                  rating: rating,
                                  reviews: (p['reviews'] ?? 0) as int,
                                  distance: (p['distance'] ?? 0.0) as double,
                                  available: available,
                                  price: '${p['price'] ?? '0'}',
                                  jobs: (p['jobs'] ?? 0) as int,
                                ),
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Stack(
                                          children: [
                                            ProviderAvatar(
                                              initials:
                                                  '${p['initials'] ?? 'P'}',
                                              size: 52,
                                              backgroundColor: AppColors.navy,
                                            ),
                                            Positioned(
                                              bottom: 2,
                                              right: 2,
                                              child: Container(
                                                width: 11,
                                                height: 11,
                                                decoration: BoxDecoration(
                                                  color: available
                                                      ? AppColors.success
                                                      : AppColors.textTertiary,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '${p['name'] ?? 'Provider'}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                        color: AppColors
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    '৳${p['price'] ?? '0'}/hr',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors.accent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${p['specialty'] ?? ''} · ${p['exp'] ?? ''} exp',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  starRating(rating, size: 12),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    '$rating (${p['reviews'] ?? 0})',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  const Icon(
                                                    Icons.location_on_outlined,
                                                    size: 12,
                                                    color:
                                                        AppColors.textTertiary,
                                                  ),
                                                  Text(
                                                    '${p['distance'] ?? 0} km',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textTertiary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 9,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(10),
                                      ),
                                      border: Border(
                                        top: BorderSide(
                                          color: AppColors.divider,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          available
                                              ? Icons.check_circle_rounded
                                              : Icons.cancel_outlined,
                                          size: 12,
                                          color: available
                                              ? AppColors.success
                                              : AppColors.textTertiary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          available
                                              ? 'Available now'
                                              : 'Currently busy',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: available
                                                ? AppColors.success
                                                : AppColors.textTertiary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${p['jobs'] ?? 0} jobs completed',
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
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


