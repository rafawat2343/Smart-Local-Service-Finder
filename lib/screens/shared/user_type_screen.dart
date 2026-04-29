import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';
import '../admin/admin_login_screen.dart';
import 'login_screen.dart';

class UserTypeScreen extends StatefulWidget {
  const UserTypeScreen({super.key});

  @override
  State<UserTypeScreen> createState() => _UserTypeScreenState();
}

class _UserTypeScreenState extends State<UserTypeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation1;
  late Animation<Offset> _slideAnimation2;
  late Animation<Offset> _slideAnimation3;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation1 =
        Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _slideAnimation2 =
        Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    _slideAnimation3 =
        Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Responsive helpers ───────────────────────────────────────────────────
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final topPad = mq.padding.top;      // status-bar height
    final bottomPad = mq.padding.bottom; // nav-bar / home indicator

    // Scale factors — design baseline is 844 px tall (iPhone 14)
    final isSmall = screenH < 680;       // e.g. old budget Androids
    final isCompact = screenH < 750;     // e.g. Pixel 4a, Galaxy A series

    // Derived sizes
    final iconSize    = isSmall ? 46.0  : isCompact ? 54.0  : 62.0;
    final hPad        = screenW * 0.07;
    final headerVPad  = isSmall ? 10.0  : isCompact ? 14.0  : 18.0;
    final titleFSize  = isSmall ? 18.0  : isCompact ? 20.0  : 22.0;
    final cardGap     = isSmall ? 7.0   : 9.0;

    return Scaffold(
      body: BackgroundWatermark(
        child: Stack(
          children: [
            Column(
              children: [
                // ── Header Panel ─────────────────────────────────────────────
                Material(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: EdgeInsets.fromLTRB(
                      hPad,
                      topPad + headerVPad,   // respects status bar
                      hPad,
                      headerVPad,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Wordmark ────────────────────────────────────────
                        Center(
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/app_icon/Icon2.png',
                                width: iconSize,
                                height: iconSize,
                              ),
                              SizedBox(height: isSmall ? 4 : 6),
                              Text(
                                'LOCAL SERVICE',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontSize: isSmall ? 15 : 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3.0,
                                ),
                              ),
                              Text(
                                'PROVIDER',
                                style: TextStyle(
                                  color: const Color(0xFFD4541A),
                                  fontSize: isSmall ? 9 : 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isSmall ? 10 : 14),

                        Text(
                          'How can we\nhelp you today?',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: titleFSize,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select your role to continue.',
                          style: TextStyle(
                            color: AppColors.navy.withOpacity(0.55),
                            fontSize: isSmall ? 11 : 12,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Role Cards ───────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      hPad, 10, hPad,
                      bottomPad + 32,
                    ),
                    child: Column(
                      children: [
                        SlideTransition(
                          position: _slideAnimation1,
                          child: _RoleCard(
                            index: '01',
                            icon: Icons.person_search_rounded,
                            title: 'I need a service',
                            subtitle:
                            'Browse verified local providers, compare ratings, and book on demand.',
                            ctaLabel: 'Continue as Client',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const LoginScreen(isClient: true),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: cardGap),
                        SlideTransition(
                          position: _slideAnimation2,
                          child: _RoleCard(
                            index: '02',
                            icon: Icons.construction_rounded,
                            title: 'I provide services',
                            subtitle:
                            'List your skills, accept local jobs, and grow your client base.',
                            ctaLabel: 'Continue as Provider',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const LoginScreen(isClient: false),
                              ),
                            ),
                            alternate: true,
                          ),
                        ),
                        SizedBox(height: cardGap),
                        SlideTransition(
                          position: _slideAnimation3,
                          child: _AdminCard(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminLoginScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Terms & Privacy ──────────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPad + 8,
              child: Text(
                'By continuing you agree to our Terms of Service\nand Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AdminCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.navy.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 20,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Admin Panel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            Text(
                              '03',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Manage users, approve listings, and oversee all application records.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 8),
                  Text(
                    'Admin Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _RoleCard is unchanged — it already uses Expanded + flexible layout
class _RoleCard extends StatelessWidget {
  final String index;
  final IconData icon;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;
  final bool alternate;

  const _RoleCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
    this.alternate = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: alternate
                          ? AppColors.accentLight
                          : AppColors.navyLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: alternate ? AppColors.accent : AppColors.navy,
                    ),
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
                                title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            Text(
                              index,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: alternate ? AppColors.accent : AppColors.navy,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    ctaLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}