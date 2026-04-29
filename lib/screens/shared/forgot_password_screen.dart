import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 0; // 0=phone, 1=OTP, 2=new password, 3=success
  final PageController _pageController = PageController();

  void _nextStep() {
    if (_step < 3) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const _stepLabels = ['Phone', 'Verify', 'Reset', 'Done'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWatermark(
        child: Column(
          children: [
            // ── Navy Header ──────────────────────────────────────────────────
            Container(
              color: AppColors.navy,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    _step == 3 ? 20 : 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button — hidden on success step
                      if (_step < 3) ...[
                        GestureDetector(
                          onTap: _prevStep,
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
                        const SizedBox(height: 24),
                      ],

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          key: ValueKey(_step),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _step == 0
                                  ? 'Forgot Password'
                                  : _step == 1
                                  ? 'Enter OTP'
                                  : _step == 2
                                  ? 'New Password'
                                  : 'Password Reset',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _step == 0
                                  ? "Enter your phone number and we'll send a verification code."
                                  : _step == 1
                                  ? 'Enter the 4-digit code sent to your phone.'
                                  : _step == 2
                                  ? 'Create a new secure password for your account.'
                                  : 'Your password has been successfully updated.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Progress dots (only for steps 0-2)
                      if (_step < 3) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: List.generate(3, (i) {
                            final done = i < _step;
                            final active = i == _step;
                            return Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: done
                                          ? AppColors.success
                                          : active
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: done
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 12,
                                              color: Colors.white,
                                            )
                                          : Text(
                                              '${i + 1}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: active
                                                    ? AppColors.navy
                                                    : Colors.white.withOpacity(
                                                        0.5,
                                                      ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _stepLabels[i],
                                          style: TextStyle(
                                            color: active
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.4),
                                            fontSize: 10,
                                            fontWeight: active
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                          ),
                                        ),
                                        if (i < 2)
                                          Container(
                                            height: 1.5,
                                            margin: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            color: done
                                                ? AppColors.success
                                                : Colors.white.withOpacity(
                                                    0.12,
                                                  ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Step Pages ───────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepPhone(onNext: _nextStep),
                  _StepOTP(onNext: _nextStep),
                  _StepNewPassword(onNext: _nextStep),
                  _StepSuccess(onBack: () => Navigator.pop(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 0: Phone Number ─────────────────────────────────────────────────────

class _StepPhone extends StatelessWidget {
  final VoidCallback onNext;
  const _StepPhone({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Illustration tile
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.navyLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 32,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Account Recovery',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'We\'ll send a code to verify your identity',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const AppTextField(
            label: 'Registered Phone Number',
            hint: '+880 1XXX-XXXXXX',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.starBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.star.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.star,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Use the phone number registered with your account.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          AppButton(
            label: 'Send Verification Code',
            icon: Icons.send_rounded,
            onTap: onNext,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Step 1: OTP ─────────────────────────────────────────────────────────────

class _StepOTP extends StatefulWidget {
  final VoidCallback onNext;
  const _StepOTP({required this.onNext});

  @override
  State<_StepOTP> createState() => _StepOTPState();
}

class _StepOTPState extends State<_StepOTP> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  int _resendSeconds = 30;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() async {
    while (_resendSeconds > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resendSeconds--);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Phone hint
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
                  Icons.phone_outlined,
                  size: 16,
                  color: AppColors.navy,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Code sent to',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const Text(
                      '+880 1712-345678',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // OTP boxes
          const Text(
            'VERIFICATION CODE',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) {
              return SizedBox(
                width: 68,
                height: 68,
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.navy,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 3) {
                      _focusNodes[i + 1].requestFocus();
                    } else if (v.isEmpty && i > 0) {
                      _focusNodes[i - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),

          const SizedBox(height: 20),

          // Resend row
          Row(
            children: [
              const Text(
                "Didn't receive the code? ",
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              _resendSeconds > 0
                  ? Text(
                      'Resend in ${_resendSeconds}s',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : GestureDetector(
                      onTap: () {
                        setState(() => _resendSeconds = 30);
                        _startCountdown();
                      },
                      child: const Text(
                        'Resend Code',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ],
          ),

          const SizedBox(height: 32),

          AppButton(
            label: 'Verify Code',
            icon: Icons.verified_outlined,
            onTap: widget.onNext,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Step 2: New Password ─────────────────────────────────────────────────────

class _StepNewPassword extends StatelessWidget {
  final VoidCallback onNext;
  const _StepNewPassword({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const AppTextField(
            label: 'New Password',
            hint: 'Minimum 8 characters',
            obscure: true,
            prefixIcon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 20),
          const AppTextField(
            label: 'Confirm New Password',
            hint: 'Re-enter your new password',
            obscure: true,
            prefixIcon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 16),

          // Requirements list
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navyLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PASSWORD REQUIREMENTS',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                ...[
                  'At least 8 characters',
                  'One uppercase letter',
                  'One number',
                  'One special character',
                ].map(
                  (req) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle_outlined,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          req,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          AppButton(
            label: 'Reset Password',
            icon: Icons.lock_reset_rounded,
            onTap: onNext,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Step 3: Success ──────────────────────────────────────────────────────────

class _StepSuccess extends StatelessWidget {
  final VoidCallback onBack;
  const _StepSuccess({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              size: 40,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Password Updated!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your password has been successfully reset.\nYou can now sign in with your new password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
          AppButton(
            label: 'Back to Sign In',
            icon: Icons.login_rounded,
            onTap: onBack,
          ),
        ],
      ),
    );
  }
}
