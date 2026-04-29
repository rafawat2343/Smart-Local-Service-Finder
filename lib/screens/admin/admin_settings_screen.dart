import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';
import '../shared/user_type_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  // Notification toggles
  bool _pushNotifications = true;
  bool _emailAlerts = true;
  bool _smsAlerts = false;
  bool _bookingReminders = true;
  bool _promotionalEmails = false;

  // Security
  bool _twoFactorAuth = false;

  // Preferences
  String _language = 'English';

  static const _prefKeys = {
    'push': 'admin_notif_push',
    'email': 'admin_notif_email',
    'sms': 'admin_notif_sms',
    'reminders': 'admin_notif_reminders',
    'promo': 'admin_notif_promo',
    '2fa': 'admin_security_2fa',
    'lang': 'admin_pref_language',
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool(_prefKeys['push']!) ?? true;
      _emailAlerts = prefs.getBool(_prefKeys['email']!) ?? true;
      _smsAlerts = prefs.getBool(_prefKeys['sms']!) ?? false;
      _bookingReminders = prefs.getBool(_prefKeys['reminders']!) ?? true;
      _promotionalEmails = prefs.getBool(_prefKeys['promo']!) ?? false;
      _twoFactorAuth = prefs.getBool(_prefKeys['2fa']!) ?? false;
      _language = prefs.getString(_prefKeys['lang']!) ?? 'English';
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeys[key]!, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeys[key]!, value);
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to ${user.email}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.urgent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent and cannot be undone. Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FirebaseAuth.instance.currentUser?.delete();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UserTypeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: AppColors.urgent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showActiveSessions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Active Sessions'),
        content: const Text('You are currently logged in on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        const languages = ['English', 'Spanish', 'French', 'German', 'Arabic'];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Language',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            ...languages.map(
              (lang) => ListTile(
                title: Text(lang),
                trailing: _language == lang
                    ? const Icon(Icons.check_rounded, color: Color(0xFF6C63FF))
                    : null,
                onTap: () {
                  setState(() => _language = lang);
                  _saveString('lang', lang);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
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
          'Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Notifications
            _SettingsSection(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              children: [
                _ToggleTile(
                  label: 'Push Notifications',
                  subtitle: 'Receive alerts on your device',
                  value: _pushNotifications,
                  onChanged: (v) {
                    setState(() => _pushNotifications = v);
                    _saveBool('push', v);
                  },
                ),
                _ToggleTile(
                  label: 'Email Alerts',
                  subtitle: 'Get updates via email',
                  value: _emailAlerts,
                  onChanged: (v) {
                    setState(() => _emailAlerts = v);
                    _saveBool('email', v);
                  },
                ),
                _ToggleTile(
                  label: 'SMS Alerts',
                  subtitle: 'Receive text messages',
                  value: _smsAlerts,
                  onChanged: (v) {
                    setState(() => _smsAlerts = v);
                    _saveBool('sms', v);
                  },
                ),
                _ToggleTile(
                  label: 'Booking Reminders',
                  subtitle: 'Remind me before appointments',
                  value: _bookingReminders,
                  onChanged: (v) {
                    setState(() => _bookingReminders = v);
                    _saveBool('reminders', v);
                  },
                ),
                _ToggleTile(
                  label: 'Promotional Emails',
                  subtitle: 'Offers and platform news',
                  value: _promotionalEmails,
                  onChanged: (v) {
                    setState(() => _promotionalEmails = v);
                    _saveBool('promo', v);
                  },
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Security
            _SettingsSection(
              icon: Icons.security_outlined,
              title: 'Security',
              children: [
                _ToggleTile(
                  label: 'Two-Factor Authentication',
                  subtitle: 'Add an extra layer of security',
                  value: _twoFactorAuth,
                  onChanged: (v) {
                    setState(() => _twoFactorAuth = v);
                    _saveBool('2fa', v);
                  },
                ),
                _NavTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change Password',
                  onTap: _changePassword,
                ),
                _NavTile(
                  icon: Icons.devices_rounded,
                  label: 'Active Sessions',
                  onTap: _showActiveSessions,
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preferences
            _SettingsSection(
              icon: Icons.tune_rounded,
              title: 'Preferences',
              children: [
                _NavTile(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  trailing: Text(
                    _language,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  onTap: _showLanguagePicker,
                ),
                _NavTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () {},
                ),
                _NavTile(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () {},
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Danger Zone
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.urgentBg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.urgent),
                      SizedBox(width: 8),
                      Text(
                        'Danger Zone',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.urgent,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _deleteAccount,
                    child: const Row(
                      children: [
                        Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Delete Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.red),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Reusable section container ──────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label, subtitle;
  final bool value, showDivider;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF6C63FF),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 2),
          const Divider(height: 16, color: AppColors.divider),
        ],
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool showDivider;
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                trailing ?? const SizedBox.shrink(),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}
