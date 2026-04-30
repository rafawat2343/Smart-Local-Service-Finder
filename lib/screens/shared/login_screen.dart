import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/remember_me_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';
import '../client/client_dashboard.dart';
import '../provider/provider_feed_screen.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isClient;
  const LoginScreen({super.key, required this.isClient});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool showpassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;

  String get _rememberScope => widget.isClient ? 'client' : 'provider';

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final saved = await RememberMeService.load(scope: _rememberScope);
    if (!mounted || !saved.rememberMe) return;
    setState(() {
      _rememberMe = true;
      _phoneController.text = saved.phone;
      _passwordController.text = saved.password;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^\+?[0-9\s\-()]{10,}$').hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _handleSignIn() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.login(
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
      );
      if (user == null) {
        throw Exception('Login failed. Please try again.');
      }

      // Gate: block suspended accounts and providers awaiting approval.
      // Wrong-role logins (client signing in through the provider tab or
      // vice-versa) are bounced here too, with a clear message.
      final gate = await DatabaseService.getLoginGateInfo(user.uid);
      if (gate != null) {
        final type = (gate['userType'] as String? ?? '');
        final isActive = gate['isActive'] as bool? ?? true;
        final isApproved = gate['isApproved'] as bool? ?? true;
        String? blockMessage;
        if (type.isNotEmpty &&
            type != (widget.isClient ? 'client' : 'provider')) {
          blockMessage =
              'This account is registered as a $type. Please use the $type sign-in screen.';
        } else if (!isActive) {
          blockMessage =
              'Your account has been suspended by the administrator. Please contact support for assistance.';
        } else if (type == 'provider' && !isApproved) {
          blockMessage =
              'Your provider account is awaiting administrator approval. You\'ll be able to sign in once an admin approves your listing.';
        }
        if (blockMessage != null) {
          await AuthService.signOut();
          throw Exception(blockMessage);
        }
      }

      // Successful sign-in: clear any prior admin deactivation so the user
      // becomes visible to the opposite role again, per product spec.
      await DatabaseService.activateUserOnLogin(user.uid);

      await RememberMeService.save(
        rememberMe: _rememberMe,
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        scope: _rememberScope,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.isClient
              ? const ClientDashboard()
              : const ProviderFeedScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWatermark(
        child: Column(
          children: [
            Container(
              color: AppColors.navy,
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.of(context).padding.top + 12,
                24,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isClient
                              ? AppColors.navyLight.withOpacity(0.15)
                              : AppColors.accentLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Text(
                          widget.isClient ? 'CLIENT' : 'PROVIDER',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isClient
                        ? 'Access your service requests and bookings.'
                        : 'View available jobs and manage your work.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      AppTextField(
                        label: 'Phone Number',
                        hint: '+880 1XXX-XXXXXX',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        controller: _phoneController,
                        validator: _validatePhoneNumber,
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        label: 'Password',
                        hint: '••••••••',
                        obscure: showpassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              showpassword = !showpassword;
                            });
                          },
                          child: Icon(
                            showpassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textTertiary,
                            size: 18,
                          ),
                        ),
                        controller: _passwordController,
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => setState(
                              () => _rememberMe = !_rememberMe,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(
                                        () => _rememberMe = v ?? false,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      activeColor: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Remember me',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      AppButton(
                        label: 'Sign In',
                        icon: Icons.login_rounded,
                        onTap: _isLoading ? null : _handleSignIn,
                        isLoading: _isLoading,
                        color: widget.isClient ? null : AppColors.accent,
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: AppColors.border),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: AppColors.border),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      AppButton(
                        label: 'Create an Account',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CreateAccountScreen(isClient: widget.isClient),
                          ),
                        ),
                        outlined: true,
                        icon: Icons.person_add_outlined,
                        color: AppColors.navy,
                      ),

                      const SizedBox(height: 32),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.navyLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your data is encrypted and secured. We never share your personal information.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
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
      ),
    );
  }
}
