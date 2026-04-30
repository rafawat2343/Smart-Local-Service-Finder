import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';
import 'provider_detail_screen.dart';

class SavedProvidersScreen extends StatefulWidget {
  const SavedProvidersScreen({super.key});

  @override
  State<SavedProvidersScreen> createState() => _SavedProvidersScreenState();
}

class _SavedProvidersScreenState extends State<SavedProvidersScreen> {
  List<Map<String, dynamic>> _providers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final clientId = AuthService.getCurrentUserId() ?? '';
    try {
      final list = await DatabaseService.getBookmarkedProviders(clientId);
      if (mounted) setState(() => _providers = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeBookmark(String providerId) async {
    final clientId = AuthService.getCurrentUserId() ?? '';
    await DatabaseService.toggleBookmark(clientId, providerId);
    setState(() => _providers.removeWhere((p) => p['id'] == providerId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saved Providers'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.navy))
          : _providers.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_outline_rounded,
                    size: 52,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'No saved providers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap the bookmark icon on a provider to save them here',
                    textAlign: TextAlign.center,
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
                itemCount: _providers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final p = _providers[i];
                  final id = (p['id'] ?? '').toString();
                  final name = (p['displayName'] ?? p['name'] ?? 'Provider')
                      .toString();
                  final parts = name.split(' ');
                  final initials = parts.length >= 2 &&
                          parts.first.isNotEmpty &&
                          parts.last.isNotEmpty
                      ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
                      : name.isNotEmpty
                      ? name[0].toUpperCase()
                      : 'P';
                  final specialty =
                      (p['serviceType'] ?? p['specialty'] ?? '').toString();
                  final rate = (p['hourlyRate'] ?? p['price'] ?? '').toString();
                  final rating = _toDouble(p['ratingAvg'] ?? p['rating']);
                  final jobs = _toInt(p['jobsCompleted'] ?? p['jobs']);
                  final available =
                      (p['isAvailable'] ?? p['available'] ?? false) == true;

                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderDetailScreen(
                          providerId: id,
                          name: name,
                          initials: initials,
                          specialty: specialty,
                          exp: (p['experience'] ?? p['exp'] ?? '').toString(),
                          rating: rating,
                          reviews: _toInt(p['totalReviews'] ?? p['reviews']),
                          distance: _toDouble(p['distance']),
                          available: available,
                          price: rate,
                          jobs: jobs,
                        ),
                      ),
                    ).then((_) => _load()),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          ProviderAvatar(initials: initials, size: 48),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (specialty.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    specialty,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 13,
                                      color: Color(0xFFF9A825),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.circle,
                                      size: 5,
                                      color: available
                                          ? AppColors.success
                                          : AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      available ? 'Available' : 'Unavailable',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: available
                                            ? AppColors.success
                                            : AppColors.textTertiary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (rate.isNotEmpty) ...[
                                      const SizedBox(width: 10),
                                      Text(
                                        '৳$rate/hr',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.bookmark_rounded,
                              color: AppColors.navy,
                              size: 22,
                            ),
                            onPressed: () => _removeBookmark(id),
                            tooltip: 'Remove bookmark',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    return 0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 0;
  }
}
