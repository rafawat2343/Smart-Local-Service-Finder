import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/theme_notifier.dart';
import '../../widgets/shared_widgets.dart';
import '../shared/user_type_screen.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen>
    with WidgetsBindingObserver {
  String? _profileImagePath;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  String _themeMode = 'System';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload data when the app comes back to foreground
      _loadProfile();
    }
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent) {
      if (mounted) {
        setState(() => _isLoading = true);
      }
    }

    final userId = AuthService.getCurrentUserId();
    if (userId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    Map<String, dynamic>? data;
    try {
      data = await DatabaseService.getProviderProfile(userId);
    } catch (e) {
      print('Failed to load provider profile: $e');
    }

    // Reviews can fail independently (e.g. missing composite index).
    // Don't let a reviews failure clobber the profile fields.
    List<Map<String, dynamic>> reviews = const [];
    try {
      reviews = await DatabaseService.getProviderReviews(userId);
    } catch (e) {
      print('Failed to load provider reviews: $e');
    }

    if (mounted) {
      setState(() {
        if (data != null) _profileData = data;
        _reviews = reviews;
        _isLoading = false;
      });
    }
  }

  String get _displayName =>
      (_profileData?['displayName'] ??
              _profileData?['name'] ??
              AuthService.getCurrentUserDisplayName() ??
              'Provider')
          .toString();
  String get _initials {
    final parts = _displayName.split(' ');
    if (parts.length >= 2)
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
  }

  String get _specialty =>
      _profileData?['serviceType'] ??
      _profileData?['specialty'] ??
      'Service Provider';
  String get _experience =>
      (_profileData?['experience'] ?? _profileData?['exp'] ?? '').toString();
  bool get _isAvailable =>
      _profileData?['isAvailable'] == true ||
      _profileData?['available'] == true;
  String get _availabilityText =>
      (_profileData?['availabilityText'] ??
              _profileData?['availableText'] ??
              '')
          .toString()
          .trim();
  double get _rating =>
      (_profileData?['ratingAvg'] ?? _profileData?['rating'] ?? 0.0).toDouble();
  int get _totalReviews =>
      _toInt(_profileData?['totalReviews'] ?? _profileData?['reviews'] ?? 0);
  int get _totalJobs => _toInt(
    _profileData?['totalJobs'] ??
        _profileData?['jobsCompleted'] ??
        _profileData?['jobs'] ??
        0,
  );
  double get _totalEarnings =>
      (_profileData?['totalEarnings'] ?? 0).toDouble();
  String get _earningsDisplay {
    final e = _totalEarnings;
    if (e >= 1000) return '৳${(e / 1000).toStringAsFixed(1)}k';
    return '৳${e.toStringAsFixed(0)}';
  }
  String get _hourlyRate =>
      (_profileData?['hourlyRate'] ?? _profileData?['price'] ?? '')
          .toString()
          .trim();
  String get _about =>
      (_profileData?['aboutText'] ?? _profileData?['about'] ?? '')
          .toString()
          .trim();
  List<String> get _services {
    final s = _profileData?['services'] ?? _profileData?['servicesOffered'];
    if (s is List) {
      return s
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
    }
    return 0;
  }

  void _showEditProfileSheet() {
    final aboutCtrl = TextEditingController(text: _about);
    final rateCtrl = TextEditingController(text: _hourlyRate);
    final servicesCtrl = TextEditingController(text: _services.join(', '));
    final availabilityCtrl = TextEditingController(text: _availabilityText);
    bool isAvailable = _isAvailable;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
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
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'AVAILABILITY',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                isAvailable ? 'Available' : 'Unavailable',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isAvailable
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: isAvailable,
                              onChanged: (v) =>
                                  setSheetState(() => isAvailable = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: availabilityCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Today, 9AM-6PM',
                          hintStyle: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 13,
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 14, right: 8),
                            child: Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(),
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
                      const SizedBox(height: 16),

                      const Text(
                        'ABOUT',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: aboutCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Describe yourself...',
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
                      const SizedBox(height: 16),

                      const Text(
                        'HOURLY RATE (৳)',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: rateCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '500',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 14, right: 8),
                            child: Icon(
                              Icons.payments_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(),
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
                      const SizedBox(height: 16),

                      const Text(
                        'SERVICES (comma separated)',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: servicesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Wiring, Fan Installation, Emergency Callout',
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
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final userId = AuthService.getCurrentUserId();
                            if (userId == null) return;
                            final newAbout = aboutCtrl.text.trim();
                            final newRate = rateCtrl.text.trim();
                            final newAvailabilityText = availabilityCtrl.text
                                .trim();
                            final servicesList = servicesCtrl.text
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toList();

                            // Write to Firestore first, then close sheet
                            try {
                              await DatabaseService.updateProviderProfile(
                                userId: userId,
                                updates: {
                                  'isAvailable': isAvailable,
                                  'available': isAvailable,
                                  'availabilityText': newAvailabilityText,
                                  'availableText': newAvailabilityText,
                                  'aboutText': newAbout,
                                  'about': newAbout,
                                  'hourlyRate': newRate,
                                  'price': newRate,
                                  'services': servicesList,
                                  'servicesOffered': servicesList,
                                  'jobsCompleted': _totalJobs,
                                  'totalJobs': _totalJobs,
                                },
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save: $e')),
                                );
                              }
                              return;
                            }

                            // Close sheet after successful save
                            if (mounted) Navigator.pop(context);

                            // Update local state and reload from Firestore
                            if (mounted) {
                              setState(() {
                                _profileData = {
                                  ...?_profileData,
                                  'isAvailable': isAvailable,
                                  'available': isAvailable,
                                  'availabilityText': newAvailabilityText,
                                  'availableText': newAvailabilityText,
                                  'aboutText': newAbout,
                                  'about': newAbout,
                                  'hourlyRate': newRate,
                                  'price': newRate,
                                  'services': servicesList,
                                  'servicesOffered': servicesList,
                                };
                              });
                              // Reload from server to confirm
                              await _loadProfile(silent: true);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
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
                            'Save Changes',
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
            );
          },
        );
      },
    );
  }

  Future<void> _pickProfileImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
              'Change Profile Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _PhotoOption(
              icon: Icons.camera_alt_rounded,
              label: 'Take Photo',
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                );
                if (image != null && mounted) {
                  setState(() => _profileImagePath = image.path);
                }
              },
            ),
            const SizedBox(height: 10),
            _PhotoOption(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null && mounted) {
                  setState(() => _profileImagePath = image.path);
                }
              },
            ),
            if (_profileImagePath != null) ...[
              const SizedBox(height: 10),
              _PhotoOption(
                icon: Icons.delete_outline_rounded,
                label: 'Remove Photo',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _profileImagePath = null);
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showThemeSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            const Text(
              'Select Theme',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _ThemeOption(
              icon: Icons.light_mode_rounded,
              label: 'Light',
              isSelected: _themeMode == 'Light',
              onTap: () {
                Navigator.pop(context);
                setState(() => _themeMode = 'Light');
                themeNotifier.value = ThemeMode.light;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Theme changed to Light'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ThemeOption(
              icon: Icons.dark_mode_rounded,
              label: 'Dark',
              isSelected: _themeMode == 'Dark',
              onTap: () {
                Navigator.pop(context);
                setState(() => _themeMode = 'Dark');
                themeNotifier.value = ThemeMode.dark;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Theme changed to Dark'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ThemeOption(
              icon: Icons.brightness_auto_rounded,
              label: 'System',
              isSelected: _themeMode == 'System',
              onTap: () {
                Navigator.pop(context);
                setState(() => _themeMode = 'System');
                themeNotifier.value = ThemeMode.system;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Theme set to System default'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, size: 20, color: Color(0xFFD94040)),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of your provider account?',
          style: TextStyle(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
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
              final userId = AuthService.getCurrentUserId();
              if (userId != null) {
                await DatabaseService.signOutCleanup(userId);
              }
              await AuthService.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const UserTypeScreen()),
                (r) => false,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFD94040),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(
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
    // Show loading indicator while fetching profile
    if (_isLoading && _profileData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.navy)),
      );
    }

    final hasAvailability = _availabilityText.isNotEmpty;
    final hasRate = _hourlyRate.isNotEmpty;

    return Scaffold(
      body: BackgroundWatermark(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ───────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              leading: const SizedBox.shrink(),
              leadingWidth: 0,
              actions: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 4, 8),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 17,
                        color: Colors.black,
                      ),
                      onPressed: _showEditProfileSheet,
                      padding: EdgeInsets.zero,
                      tooltip: 'Edit Profile',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD94040).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        size: 17,
                        color: Colors.black,
                      ),
                      onPressed: _confirmLogout,
                      padding: EdgeInsets.zero,
                      tooltip: 'Sign Out',
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.accent,
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

                          // ── Profile Picture ─────────────────────────
                          GestureDetector(
                            onTap: _pickProfileImage,
                            child: Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.navy,
                                    borderRadius: BorderRadius.circular(
                                      80 * 0.22,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 3,
                                    ),
                                    image: _profileImagePath != null
                                        ? DecorationImage(
                                            image: FileImage(
                                              File(_profileImagePath!),
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: _profileImagePath == null
                                      ? Text(
                                          _initials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 27,
                                            letterSpacing: 0.5,
                                          ),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppColors.navy,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _displayName,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: Color(0xFF1976D2),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '$_specialty${_experience.isNotEmpty ? " · $_experience years experience" : ""}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              title: const Text(
                'Provider Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stats ─────────────────────────────────────────────
                    CorpCard(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: StatItem(
                              value: _rating.toStringAsFixed(1),
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
                              value: '$_totalReviews',
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
                              value: '$_totalJobs',
                              label: 'JOBS',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppColors.divider,
                          ),
                          Expanded(
                            child: StatItem(
                              value: _earningsDisplay,
                              label: 'EARNED',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Info strip ───────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: _isAvailable
                                  ? AppColors.successBg
                                  : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isAvailable
                                    ? AppColors.success.withOpacity(0.25)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isAvailable
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.remove_circle_outline_rounded,
                                  size: 15,
                                  color: _isAvailable
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 7),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isAvailable
                                          ? 'Available'
                                          : 'Unavailable',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _isAvailable
                                            ? AppColors.success
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      hasAvailability
                                          ? _availabilityText
                                          : 'Set in Edit Profile',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _isAvailable
                                            ? AppColors.success
                                            : AppColors.textTertiary,
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
                              border: Border.all(color: AppColors.border),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hasRate
                                          ? 'From ৳$_hourlyRate'
                                          : 'Rate not set',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    Text(
                                      hasRate
                                          ? 'Per hour'
                                          : 'Update in Edit Profile',
                                      style: const TextStyle(
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
                    const SizedBox(height: 20),

                    // ── About ─────────────────────────────────────────────
                    const SectionHeader(title: 'About'),
                    const SizedBox(height: 10),
                    CorpCard(
                      child: _about.isNotEmpty
                          ? Text(
                              _about,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.65,
                              ),
                            )
                          : const Text(
                              'Not added yet. Update from Edit Profile.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                                height: 1.65,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // ── Services ──────────────────────────────────────────
                    const SectionHeader(title: 'Services Offered'),
                    const SizedBox(height: 10),
                    if (_services.isEmpty)
                      const CorpCard(
                        child: Text(
                          'No services added yet. Update from Edit Profile.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                            height: 1.5,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _services
                            .map(
                              (s) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.navyLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border),
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

                    // ── Reviews ───────────────────────────────────────────
                    SectionHeader(
                      title: 'Client Reviews',
                      action: 'See all $_totalReviews',
                      onAction: () {},
                    ),
                    const SizedBox(height: 10),
                    ..._reviews.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CorpCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ProviderAvatar(
                                    initials: r['initials'] as String,
                                    size: 34,
                                    backgroundColor: AppColors.navyMid,
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
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        r['date'] as String,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  starRating(r['rating'] as double, size: 12),
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

                    // ── Settings ─────────────────────────────────────────
                    const CorpDivider(),
                    const SizedBox(height: 16),
                    const SectionHeader(title: 'Settings'),
                    const SizedBox(height: 10),
                    CorpCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.navyLight,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.palette_outlined,
                            size: 16,
                            color: AppColors.navy,
                          ),
                        ),
                        title: const Text(
                          'Theme',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          _themeMode,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        onTap: _showThemeSelection,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Sign Out ──────────────────────────────────────────
                    GestureDetector(
                      onTap: _confirmLogout,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFD0D0)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              size: 17,
                              color: Color(0xFFD94040),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Sign Out',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD94040),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Theme Option ────────────────────────────────────────────────────────────

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accentLight : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.accent : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : AppColors.navyLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.navy,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (isSelected)
            const Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: AppColors.accent,
            ),
        ],
      ),
    ),
  );
}

// ─── Photo Option ────────────────────────────────────────────────────────────

class _PhotoOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _PhotoOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFD94040) : AppColors.navy;
    final bg = isDestructive ? const Color(0xFFFAEAEA) : AppColors.navyLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}
