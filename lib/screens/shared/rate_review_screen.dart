import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';

class RateReviewScreen extends StatefulWidget {
  final String bookingId;
  final String providerId;
  final String providerName;
  final String providerInitials;
  final String providerSpecialty;

  const RateReviewScreen({
    super.key,
    this.bookingId = '',
    this.providerId = '',
    this.providerName = 'Provider',
    this.providerInitials = 'P',
    this.providerSpecialty = 'Service Provider',
  });

  @override
  State<RateReviewScreen> createState() => _RateReviewScreenState();
}

class _RateReviewScreenState extends State<RateReviewScreen> {
  int _rating = 5;
  final TextEditingController _reviewCtrl = TextEditingController();
  bool _submitting = false;
  int _pendingPoints = 0;

  static const _labels = ['Poor', 'Below Average', 'Average', 'Good', 'Excellent'];
  static const _labelColors = [
    AppColors.urgent, Color(0xFFD47A1A), Color(0xFFC8880A), AppColors.success, AppColors.success,
  ];

  @override
  void initState() {
    super.initState();
    _reviewCtrl.addListener(() => setState(() {}));
    _loadPendingPoints();
  }

  Future<void> _loadPendingPoints() async {
    if (widget.bookingId.isEmpty) return;
    final pts =
        await DatabaseService.getPendingReviewPoints(widget.bookingId);
    if (mounted) setState(() => _pendingPoints = pts);
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmStarsOnly() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip the written review?'),
        content: Text(
          _pendingPoints > 0
              ? 'You\'ll lose $_pendingPoints reward points if you submit without a written review.'
              : 'Adding a written review helps other clients pick the right provider.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Add review'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit anyway'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _submitReview() async {
    final hasText = _reviewCtrl.text.trim().isNotEmpty;
    if (!hasText) {
      final ok = await _confirmStarsOnly();
      if (!ok) return;
    }

    setState(() => _submitting = true);

    final hasNet = await ConnectivityService.hasInternet();
    if (!hasNet) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection. Please try again.')),
        );
      }
      return;
    }

    try {
      final clientId = AuthService.getCurrentUserId() ?? '';

      await DatabaseService.createReview(
        bookingId: widget.bookingId,
        clientId: clientId,
        providerId: widget.providerId,
        rating: _rating,
        reviewText: _reviewCtrl.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true); // return true = review submitted
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit review: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy, foregroundColor: Colors.white,
        title: const Text('Rate Service'),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
            ),
          ),
        ),
      ),
      body: BackgroundWatermark(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_pendingPoints > 0) ...[
                _PointsBanner(
                  pendingPoints: _pendingPoints,
                  hasText: _reviewCtrl.text.trim().isNotEmpty,
                  rating: _rating,
                ),
                const SizedBox(height: 16),
              ],
              // Provider card
              CorpCard(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  ProviderAvatar(initials: widget.providerInitials, size: 52),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.providerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3)),
                    const SizedBox(height: 3),
                    Text(widget.providerSpecialty, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    StatusBadge(label: 'JOB COMPLETED', color: AppColors.success, bgColor: AppColors.successBg, icon: Icons.check_rounded),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),

              // Rating
              CorpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _SectionLabel(label: 'OVERALL RATING'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => GestureDetector(
                      onTap: () => setState(() => _rating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: i < _rating ? AppColors.star : AppColors.border, size: 42,
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 12),
                  Center(child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(_labels[_rating - 1], key: ValueKey(_rating),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _labelColors[_rating - 1], letterSpacing: 0.2)),
                  )),
                ]),
              ),
              const SizedBox(height: 16),

              // Written review
              CorpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _SectionLabel(label: 'WRITTEN REVIEW'),
                  const SizedBox(height: 12),
                  Container(
                    height: 110,
                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                    child: TextField(
                      controller: _reviewCtrl,
                      maxLines: null, expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: 'Describe your experience with ${widget.providerName}...',
                        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        border: InputBorder.none, contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Photos (placeholder)
              CorpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const _SectionLabel(label: 'ATTACH PHOTOS'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.navyLight, borderRadius: BorderRadius.circular(4)),
                      child: const Text('Optional', style: TextStyle(fontSize: 10, color: AppColors.navy, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    height: 80, width: double.infinity,
                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 28, color: AppColors.textTertiary),
                      SizedBox(height: 5),
                      Text('Tap to upload photos', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              AppButton(
                label: 'Submit Review',
                icon: Icons.check_rounded,
                onTap: _submitting ? null : _submitReview,
                isLoading: _submitting,
              ),
              const SizedBox(height: 10),
              AppButton(label: 'Skip', onTap: () => Navigator.pop(context), outlined: true, color: AppColors.textSecondary),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w700, letterSpacing: 1.0));
}

class _PointsBanner extends StatelessWidget {
  final int pendingPoints;
  final bool hasText;
  final int rating;

  const _PointsBanner({
    required this.pendingPoints,
    required this.hasText,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final qualifies = hasText && rating > 0;
    final color = qualifies ? AppColors.success : AppColors.star;
    final bg = qualifies ? AppColors.successBg : AppColors.starBg;
    final icon =
        qualifies ? Icons.check_circle_rounded : Icons.stars_rounded;
    final headline = qualifies
        ? 'Earn $pendingPoints points on submit'
        : 'Earn $pendingPoints points for this booking';
    final detail = qualifies
        ? 'Stars + written review — points will be credited.'
        : 'Submit BOTH a star rating AND a written review to earn points. Stars alone won\'t add points.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
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
