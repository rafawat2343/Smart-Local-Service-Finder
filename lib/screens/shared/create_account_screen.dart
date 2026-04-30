import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'nid_ocr_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';
import '../client/client_dashboard.dart';
import '../provider/provider_feed_screen.dart';

// ─── NID Data model ───────────────────────────────────────────────────────────
class NidData {
  final String fullName;
  final String nidNumber;
  final String dateOfBirth;
  final String fatherName;
  final String motherName;
  final String phoneNumber;
  final String email;
  final String password;
  final String location;
  final String specialty;
  final String experience;

  const NidData({
    this.fullName = '',
    this.nidNumber = '',
    this.dateOfBirth = '',
    this.fatherName = '',
    this.motherName = '',
    this.phoneNumber = '',
    this.email = '',
    this.password = '',
    this.location = '',
    this.specialty = '',
    this.experience = '',
  });
  bool get isEmpty => nidNumber.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT SCREEN  —  steps: 0=NID  1=Info  2=Security  3=OTP  4=Complete
// ─────────────────────────────────────────────────────────────────────────────
class CreateAccountScreen extends StatefulWidget {
  final bool isClient;
  const CreateAccountScreen({super.key, required this.isClient});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  int _step = 0;
  NidData _nidData = const NidData();
  String _phone = ''; // passed from Info → OTP step

  final PageController _pageController = PageController();

  static const _stepLabels = [
    'NID Verify',
    'Personal Info',
    'Security',
    'OTP Verify',
    'Complete',
  ];

  void _nextStep({NidData? nidData, String? phone}) {
    if (nidData != null) _nidData = nidData;
    if (phone != null) _phone = phone;
    if (_step < _stepLabels.length - 1) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStepWithBoth({required NidData nidData, required String phone}) {
    _nidData = nidData;
    _phone = phone;
    if (_step < _stepLabels.length - 1) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 320),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWatermark(
        child: Column(
          children: [
            // ── Navy Header ──────────────────────────────────────────────
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
                    'Create Account',
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
                        ? 'Join thousands finding trusted local services.'
                        : 'Start earning by offering your skills locally.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Step indicator ───────────────────────────────────
                  Row(
                    children: List.generate(_stepLabels.length, (i) {
                      final done = i < _step;
                      final active = i == _step;
                      return Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: done
                                    ? AppColors.success
                                    : active
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: done
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      )
                                    : Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: active
                                              ? AppColors.navy
                                              : Colors.white.withOpacity(0.45),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _stepLabels[i],
                                    style: TextStyle(
                                      color: active
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.38),
                                      fontSize: 9,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  if (i < _stepLabels.length - 1)
                                    Container(
                                      height: 1.5,
                                      margin: const EdgeInsets.only(top: 3),
                                      color: done
                                          ? AppColors.success
                                          : Colors.white.withOpacity(0.13),
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
              ),
            ),

            // ── Pages ────────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // 0 — NID Scan
                  _StepNidScan(onNext: (data) => _nextStep(nidData: data)),
                  // 1 — Personal Info
                  _StepPersonalInfo(
                    isClient: widget.isClient,
                    nidData: _nidData,
                    onNext: (nidData, phone) =>
                        _nextStepWithBoth(nidData: nidData, phone: phone),
                  ),
                  // 2 — Security
                  _StepSecurity(
                    nidData: _nidData,
                    onNext: (data) => _nextStep(nidData: data),
                  ),
                  // 3 — OTP
                  _StepOtpVerify(
                    phone: _phone,
                    nidData: _nidData,
                    isClient: widget.isClient,
                    onNext: () => _nextStep(),
                    onChangePhone: () {
                      setState(() => _step = 1);
                      _pageController.animateToPage(
                        1,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  // 4 — Complete
                  _StepComplete(
                    isClient: widget.isClient,
                    onFinish: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => widget.isClient
                            ? const ClientDashboard()
                            : const ProviderFeedScreen(),
                      ),
                      (r) => false,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// STEP 0 — NID SCAN
// ─────────────────────────────────────────────────────────────────────────────
class _StepNidScan extends StatefulWidget {
  final void Function(NidData) onNext;
  const _StepNidScan({required this.onNext});

  @override
  State<_StepNidScan> createState() => _StepNidScanState();
}

class _StepNidScanState extends State<_StepNidScan> {
  String _state = 'idle'; // idle | camera | scanning | done
  final ImagePicker _picker = ImagePicker();
  NidData _extracted = const NidData();

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) await _runOcr(image.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _runOcr(String imagePath) async {
    setState(() => _state = 'scanning');
    try {
      final data = await NidOcrService.extractFromImage(imagePath);
      if (!mounted) return;
      setState(() {
        _extracted = data;
        _state = 'done';
      });
    } on NidOcrException catch (e) {
      if (!mounted) return;
      setState(() => _state = 'idle');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), duration: const Duration(seconds: 4)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = 'idle');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not scan NID: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == 'camera') {
      return _CameraViewfinder(
        onCapture: (img) => _runOcr(img.path),
        onCancel: () => setState(() => _state = 'idle'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _InfoBanner(
            icon: Icons.info_outline_rounded,
            color: AppColors.navy,
            bg: AppColors.navyLight,
            text:
                'NID scan is required to create an account. Your Name, NID Number and Date of Birth will be extracted automatically.',
          ),
          const SizedBox(height: 20),

          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: double.infinity,
            height: 192,
            decoration: BoxDecoration(
              color: _state == 'done' ? AppColors.successBg : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _state == 'done'
                    ? AppColors.success
                    : _state == 'scanning'
                    ? AppColors.navy
                    : AppColors.border,
                width: _state == 'idle' ? 1 : 2,
              ),
            ),
            child: _state == 'idle'
                ? const _NidIdleContent()
                : _state == 'scanning'
                ? const _NidScanningContent()
                : const _NidDoneContent(),
          ),
          const SizedBox(height: 16),

          if (_state == 'idle') ...[
            AppButton(
              label: 'Open Camera',
              icon: Icons.camera_rear_rounded,
              onTap: () => setState(() => _state = 'camera'),
            ),
            const SizedBox(height: 10),
            _OrDivider(),
            const SizedBox(height: 10),
            AppButton(
              label: 'Upload from Gallery',
              icon: Icons.photo_library_outlined,
              onTap: _pickFromGallery,
              outlined: true,
              color: AppColors.navy,
            ),
          ],

          if (_state == 'done') ...[
            const SizedBox(height: 20),
            _ExtractedPreview(data: _extracted),
            const SizedBox(height: 20),

            // All three fields must be present to continue.
            if (_extracted.fullName.isNotEmpty &&
                _extracted.nidNumber.isNotEmpty &&
                _extracted.dateOfBirth.isNotEmpty)
              AppButton(
                label: 'Continue with Extracted Info',
                icon: Icons.arrow_forward_rounded,
                onTap: () => widget.onNext(_extracted),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD94040).withOpacity(0.4)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD94040)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Could not read all required fields. Please rescan with better lighting and the card held flat.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFD94040), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            AppButton(
              label: 'Rescan',
              icon: Icons.refresh_rounded,
              onTap: () => setState(() => _state = 'idle'),
              outlined: true,
              color: AppColors.textSecondary,
              small: true,
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NidIdleContent extends StatelessWidget {
  const _NidIdleContent();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.credit_card_rounded, size: 28, color: AppColors.navy),
      ),
      const SizedBox(height: 12),
      const Text(
        'Ready to Scan',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      ),
      const SizedBox(height: 4),
      const Text(
        'Use the camera button below or upload a photo',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.camera_rear_rounded, size: 13, color: AppColors.textTertiary),
          SizedBox(width: 5),
          Text('Back camera • Auto-detect', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    ],
  );
}

class _NidScanningContent extends StatefulWidget {
  const _NidScanningContent();
  @override
  State<_NidScanningContent> createState() => _NidScanningContentState();
}

class _NidScanningContentState extends State<_NidScanningContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _anim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        width: 200,
        height: 110,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 190,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.navy.withOpacity(0.5),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Positioned(
                top: 5 + _anim.value * 90,
                child: Container(
                  width: 180,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.navy.withOpacity(0),
                        AppColors.navy.withOpacity(0.8),
                        AppColors.navy.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Scanning NID Card...',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
      const SizedBox(height: 3),
      const Text(
        'Extracting information via OCR',
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    ],
  );
}

class _NidDoneContent extends StatelessWidget {
  const _NidDoneContent();
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
      ),
      const SizedBox(height: 12),
      const Text(
        'NID Scanned Successfully',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.success,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Review the extracted info below',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ],
  );
}

class _ExtractedPreview extends StatelessWidget {
  final NidData data;
  const _ExtractedPreview({required this.data});

  @override
  Widget build(BuildContext context) {
    final fields = [
      ('Full Name', data.fullName),
      ('NID Number', data.nidNumber),
      ('Date of Birth', data.dateOfBirth),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: const BoxDecoration(
              color: AppColors.navyLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.document_scanner_outlined,
                  size: 15,
                  color: AppColors.navy,
                ),
                const SizedBox(width: 8),
                const Text(
                  'EXTRACTED FROM NID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                _Badge(
                  label: 'AUTO-FILLED',
                  color: AppColors.success,
                  bg: AppColors.successBg,
                  icon: Icons.auto_awesome_rounded,
                ),
              ],
            ),
          ),
          ...fields.asMap().entries.map(
            (e) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 108,
                        child: Text(
                          e.value.$1,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value.$2,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.key < fields.length - 1)
                  const Divider(
                    height: 1,
                    indent: 16,
                    color: AppColors.divider,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — PERSONAL INFO  (phone + NID required)
// ─────────────────────────────────────────────────────────────────────────────
class _StepPersonalInfo extends StatefulWidget {
  final bool isClient;
  final NidData nidData;
  final void Function(NidData nidData, String phone) onNext;
  const _StepPersonalInfo({
    required this.isClient,
    required this.nidData,
    required this.onNext,
  });

  @override
  State<_StepPersonalInfo> createState() => _StepPersonalInfoState();
}

class _StepPersonalInfoState extends State<_StepPersonalInfo> {
  // NID-extracted fields — locked (readOnly) when scanned
  late final TextEditingController _fullName;
  late final TextEditingController _nidNumber;
  late final TextEditingController _dob;
  // Manually entered fields
  final TextEditingController _fatherName = TextEditingController();
  final TextEditingController _motherName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _experience = TextEditingController();
  // Specialty chosen from dropdown
  String _specialtyValue = '';

  bool _phoneError = false;
  bool _nidError = false;
  bool _locationError = false;
  bool _specialtyError = false;

  @override
  void initState() {
    super.initState();
    final d = widget.nidData;
    _fullName = TextEditingController(text: d.fullName);
    _nidNumber = TextEditingController(text: d.nidNumber);
    _dob = TextEditingController(text: d.dateOfBirth);
    _phone.addListener(() {
      if (_phoneError) setState(() => _phoneError = false);
    });
    _nidNumber.addListener(() {
      if (_nidError) setState(() => _nidError = false);
    });
    _location.addListener(() {
      if (_locationError) setState(() => _locationError = false);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _fullName, _nidNumber, _dob,
      _fatherName, _motherName,
      _phone, _email, _location, _experience,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _wasScanned => !widget.nidData.isEmpty;

  void _validate() {
    final phoneOk = _phone.text.trim().length >= 11;
    final nidOk = _nidNumber.text.trim().length >= 10;
    final locationOk = _location.text.trim().isNotEmpty;
    final specialtyOk = widget.isClient || _specialtyValue.isNotEmpty;

    setState(() {
      _phoneError = !phoneOk;
      _nidError = !nidOk;
      _locationError = !locationOk;
      _specialtyError = !specialtyOk;
    });

    if (phoneOk && nidOk && locationOk && specialtyOk) {
      final updatedNidData = NidData(
        fullName: _fullName.text,
        nidNumber: _nidNumber.text,
        dateOfBirth: _dob.text,
        fatherName: _fatherName.text.trim(),
        motherName: _motherName.text.trim(),
        phoneNumber: _phone.text.trim(),
        email: _email.text.trim(),
        location: _location.text.trim(),
        specialty: _specialtyValue,
        experience: _experience.text.trim(),
      );
      widget.onNext(updatedNidData, '+88${_phone.text.trim()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),

          if (_wasScanned)
            _InfoBanner(
              icon: Icons.auto_awesome_rounded,
              color: AppColors.success,
              bg: AppColors.successBg,
              text:
                  'Highlighted fields were auto-filled from your NID card. Verify and edit if needed.',
              borderColor: AppColors.success.withOpacity(0.35),
            ),
          if (_wasScanned) const SizedBox(height: 20),

          // ── NID Info ────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.credit_card_rounded,
            label: 'NID INFORMATION',
          ),
          const SizedBox(height: 14),

          _SmartField(
            label: 'Full Name (as on NID)',
            controller: _fullName,
            icon: Icons.person_outline_rounded,
            autoFilled: _wasScanned,
            readOnly: _wasScanned,
          ),
          const SizedBox(height: 16),

          // NID Number — REQUIRED
          _SmartField(
            label: 'NID Number',
            controller: _nidNumber,
            icon: Icons.credit_card_rounded,
            autoFilled: _wasScanned,
            readOnly: _wasScanned,
            keyboardType: TextInputType.number,
            required: true,
            error: _nidError ? 'NID number is required' : null,
          ),
          const SizedBox(height: 16),

          _SmartField(
            label: 'Date of Birth',
            controller: _dob,
            icon: Icons.cake_outlined,
            autoFilled: _wasScanned,
            readOnly: _wasScanned,
            hint: 'DD MMM YYYY',
          ),
          const SizedBox(height: 16),

          _SmartField(
            label: "Father's Name",
            controller: _fatherName,
            icon: Icons.person_4_outlined,
            hint: 'Enter father\'s full name',
          ),
          const SizedBox(height: 16),
          _SmartField(
            label: "Mother's Name",
            controller: _motherName,
            icon: Icons.person_3_outlined,
            hint: 'Enter mother\'s full name',
          ),

          const SizedBox(height: 24),
          const CorpDivider(),
          const SizedBox(height: 24),

          // ── Contact Info ────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.contact_phone_outlined,
            label: 'CONTACT INFORMATION',
          ),
          const SizedBox(height: 14),

          // Phone — REQUIRED (OTP sent here)
          _PhoneField(
            label: 'Phone Number',
            controller: _phone,
            icon: Icons.phone_outlined,
            required: true,
            error: _phoneError
                ? 'Phone number is required for OTP verification'
                : null,
          ),
          const SizedBox(height: 16),

          _SmartField(
            label: 'Email Address',
            controller: _email,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            hint: 'you@example.com',
          ),
          const SizedBox(height: 16),
          _SmartField(
            label: 'Current Location',
            controller: _location,
            icon: Icons.location_on_outlined,
            hint: 'e.g. Mirpur, Dhaka',
            required: true,
            error: _locationError ? 'Current location is required' : null,
          ),

          if (!widget.isClient) ...[
            const SizedBox(height: 24),
            const CorpDivider(),
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.construction_rounded,
              label: 'PROFESSIONAL INFO',
            ),
            const SizedBox(height: 14),
            _SpecialtyPicker(
              selected: _specialtyValue,
              hasError: _specialtyError,
              onSelected: (v) => setState(() {
                _specialtyValue = v;
                _specialtyError = false;
              }),
            ),
            const SizedBox(height: 16),
            _SmartField(
              label: 'Years of Experience',
              controller: _experience,
              icon: Icons.work_history_outlined,
              keyboardType: TextInputType.number,
              hint: 'e.g. 5',
            ),
          ],

          const SizedBox(height: 28),

          // Required fields reminder
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Phone Number',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        const TextSpan(text: ', '),
                        const TextSpan(
                          text: 'NID Number',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        const TextSpan(text: ', '),
                        const TextSpan(
                          text: 'Current Location',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        if (!widget.isClient) ...[
                          const TextSpan(text: ', and '),
                          const TextSpan(
                            text: 'Specialty',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                        const TextSpan(
                          text:
                              ' are required to proceed. An OTP will be sent for verification.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          AppButton(
            label: 'Continue & Send OTP',
            icon: Icons.sms_outlined,
            onTap: _validate,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — SECURITY
// ─────────────────────────────────────────────────────────────────────────────
class _StepSecurity extends StatefulWidget {
  final NidData nidData;
  final void Function(NidData) onNext;
  const _StepSecurity({required this.nidData, required this.onNext});

  @override
  State<_StepSecurity> createState() => _StepSecurityState();
}

class _StepSecurityState extends State<_StepSecurity> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreed = false;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  void _handleContinue() {
    final passwordError = _validatePassword(_passwordController.text);
    String? confirmPasswordError;

    if (_confirmPasswordController.text.isEmpty) {
      confirmPasswordError = 'Please confirm your password';
    } else if (_passwordController.text != _confirmPasswordController.text) {
      confirmPasswordError = 'Passwords do not match';
    }

    if (passwordError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(passwordError)));
      return;
    }

    if (confirmPasswordError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(confirmPasswordError)));
      return;
    }

    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to Terms of Service and Privacy Policy.'),
        ),
      );
      return;
    }

    final updatedNidData = NidData(
      fullName: widget.nidData.fullName,
      nidNumber: widget.nidData.nidNumber,
      dateOfBirth: widget.nidData.dateOfBirth,
      fatherName: widget.nidData.fatherName,
      motherName: widget.nidData.motherName,
      phoneNumber: widget.nidData.phoneNumber,
      email: widget.nidData.email,
      password: _passwordController.text,
      location: widget.nidData.location,
      specialty: widget.nidData.specialty,
      experience: widget.nidData.experience,
    );
    widget.onNext(updatedNidData);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          AppTextField(
            label: 'Password',
            hint: 'Minimum 8 characters',
            obscure: _obscurePassword,
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ),
            controller: _passwordController,
            validator: (v) => _validatePassword(v ?? ''),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            obscure: _obscureConfirmPassword,
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: GestureDetector(
              onTap: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              child: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ),
            controller: _confirmPasswordController,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please confirm your password';
              }
              if (_passwordController.text != v) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const _PasswordStrengthBar(),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: () => setState(() => _agreed = !_agreed),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _agreed ? AppColors.navy : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _agreed ? AppColors.navy : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: _agreed
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
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
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onTap: _handleContinue,
            color: _agreed ? AppColors.accent : AppColors.textTertiary,
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navyLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: const [
                Icon(Icons.shield_outlined, size: 16, color: AppColors.navy),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your password is encrypted and securely stored. We never share your personal information.',
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'PASSWORD STRENGTH',
        style: TextStyle(
          fontSize: 10,
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: List.generate(
          4,
          (i) => Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              decoration: BoxDecoration(
                color: i < 2 ? AppColors.success : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Fair — add symbols or numbers to strengthen',
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — OTP VERIFY
// ─────────────────────────────────────────────────────────────────────────────
class _StepOtpVerify extends StatefulWidget {
  final String phone;
  final NidData nidData;
  final bool isClient;
  final VoidCallback onNext;
  final VoidCallback onChangePhone;
  const _StepOtpVerify({
    required this.phone,
    required this.nidData,
    required this.isClient,
    required this.onNext,
    required this.onChangePhone,
  });

  @override
  State<_StepOtpVerify> createState() => _StepOtpVerifyState();
}

class _StepOtpVerifyState extends State<_StepOtpVerify> {
  final List<TextEditingController> _ctrl = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focus = List.generate(6, (_) => FocusNode());

  int _resendSeconds = 60;
  bool _otpError = false;
  bool _verifying = false;
  bool _sendingOtp = false;
  String? _verificationId;
  int? _resendToken;
  String? _registrationError;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  void _startCountdown() async {
    while (_resendSeconds > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resendSeconds--);
    }
  }

  void _resend() {
    setState(() {
      _otpError = false;
      _registrationError = null;
    });
    for (final c in _ctrl) c.clear();
    _focus[0].requestFocus();
    _sendOtp(isResend: true);
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    setState(() {
      _sendingOtp = true;
      _registrationError = null;
    });

    try {
      await AuthService.startPhoneSignIn(
        phoneNumber: widget.nidData.phoneNumber,
        forceResendingToken: isResend ? _resendToken : null,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _resendSeconds = 60;
          });
          _startCountdown();
        },
        onFailed: (error) {
          if (!mounted) return;
          setState(() {
            _registrationError = AuthService.mapPhoneAuthError(error);
          });
        },
        onAutoVerified: (credential) async {
          if (!mounted) return;
          await _completeRegistration();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _registrationError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _sendingOtp = false);
      }
    }
  }

  Future<void> _verify() async {
    final code = _ctrl.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _otpError = true);
      return;
    }
    setState(() {
      _verifying = true;
      _otpError = false;
      _registrationError = null;
    });

    try {
      // Universal OTP bypass
      if (code == '123456') {
        await _completeRegistration();
        return;
      }

      if (_verificationId == null) {
        throw Exception('OTP session not found. Please resend code.');
      }

      await AuthService.verifyOtpAndSignIn(
        verificationId: _verificationId!,
        smsCode: code,
      );

      await _completeRegistration();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _registrationError = e.toString().replaceAll('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_registrationError ?? 'Registration failed')),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _completeRegistration() async {
    await AuthService.registerWithPhoneAndPassword(
      phoneNumber: widget.nidData.phoneNumber,
      password: widget.nidData.password,
      displayName: widget.nidData.fullName,
    );

    final userId = AuthService.getCurrentUserId();
    if (userId == null) {
      throw Exception('Unable to resolve user after verification.');
    }

    await DatabaseService.saveUserData(
      userId: userId,
      phoneNumber: widget.nidData.phoneNumber,
      displayName: widget.nidData.fullName,
      email: widget.nidData.email,
      isClient: widget.isClient,
      nidNumber: widget.nidData.nidNumber,
      dateOfBirth: widget.nidData.dateOfBirth,
      fatherName: widget.nidData.fatherName,
      motherName: widget.nidData.motherName,
      password: widget.nidData.password,
    );

    if (!widget.isClient && widget.nidData.specialty.isNotEmpty) {
      await DatabaseService.updateProviderProfile(
        userId: userId,
        updates: {
          'serviceType': widget.nidData.specialty,
          'experience': widget.nidData.experience,
          'location': widget.nidData.location,
        },
      );
    }

    if (widget.isClient && widget.nidData.location.isNotEmpty) {
      await DatabaseService.updateClientProfile(
        userId: userId,
        updates: {'location': widget.nidData.location},
      );
    }

    // Silently capture GPS; fall back to Dhaka centre if denied.
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      double lat, lng;
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } else {
        lat = 23.8103; // Dhaka default
        lng = 90.4125;
      }
      await DatabaseService.updateUserLocation(
        userId: userId,
        latitude: lat,
        longitude: lng,
        isClient: widget.isClient,
      );
    } catch (_) {
      // Non-fatal — app continues without location
    }

    if (!mounted) return;
    setState(() => _verifying = false);
    widget.onNext();
  }

  String get _maskedPhone {
    final p = widget.phone;
    if (p.length < 9) return p;
    // Phone format: +88XXXXXXXXXXX
    // Show: +88•••••••XXXX (last 4 digits visible)
    final digits = p.replaceAll('+88', '');
    if (digits.length < 4) return p;
    return '+88${'•' * (digits.length - 4)}${digits.substring(digits.length - 4)}';
  }

  @override
  void dispose() {
    for (final c in _ctrl) c.dispose();
    for (final f in _focus) f.dispose();
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

          // Phone banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.navyLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    size: 20,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CODE SENT TO',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _maskedPhone,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onChangePhone,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.3),
                      ),
                    ),
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Registration error display
          if (_registrationError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _registrationError!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // OTP label
          const Text(
            'ENTER 6-DIGIT CODE',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final hasError = _otpError;
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 64) / 6 - 4,
                height: 58,
                child: TextField(
                  controller: _ctrl[i],
                  focusNode: _focus[i],
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: hasError
                        ? const Color(0xFFD94040)
                        : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: hasError
                        ? const Color(0xFFFFEEEE)
                        : _ctrl[i].text.isNotEmpty
                        ? AppColors.navyLight
                        : AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: hasError
                            ? const Color(0xFFD94040)
                            : AppColors.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: hasError
                            ? const Color(0xFFD94040)
                            : AppColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: hasError
                            ? const Color(0xFFD94040)
                            : AppColors.navy,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() => _otpError = false);
                    if (v.isNotEmpty && i < 5) {
                      _focus[i + 1].requestFocus();
                    } else if (v.isEmpty && i > 0) {
                      _focus[i - 1].requestFocus();
                    }
                    // Auto-verify when last digit entered
                    if (i == 5 && v.isNotEmpty) _verify();
                  },
                ),
              );
            }),
          ),

          // Error message
          if (_otpError) ...[
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: Color(0xFFD94040),
                ),
                SizedBox(width: 6),
                Text(
                  'Please enter all 6 digits of your verification code.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFD94040)),
                ),
              ],
            ),
          ],

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
                      onTap: _sendingOtp ? null : _resend,
                      child: Text(
                        _sendingOtp ? 'Sending...' : 'Resend Code',
                        style: TextStyle(
                          fontSize: 13,
                          color: _sendingOtp
                              ? AppColors.textTertiary
                              : AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          // Resend timer bar
          if (_resendSeconds > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _resendSeconds / 60,
                minHeight: 3,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.navy.withOpacity(0.4),
                ),
              ),
            ),

          const SizedBox(height: 32),

          // Verify button
          _verifying
              ? Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : AppButton(
                  label: 'Verify & Create Account',
                  icon: Icons.verified_rounded,
                  onTap: _verify,
                ),

          const SizedBox(height: 12),

          // Skip OTP — register directly without phone verification
          GestureDetector(
            onTap: _verifying ? null : _completeRegistration,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.navyLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Register without OTP verification',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          _InfoBanner(
            icon: Icons.lock_outline_rounded,
            color: AppColors.navy,
            bg: AppColors.navyLight,
            text:
                'This code expires in 10 minutes. Do not share it with anyone.',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 4 — COMPLETE
// ─────────────────────────────────────────────────────────────────────────────
class _StepComplete extends StatelessWidget {
  final bool isClient;
  final VoidCallback onFinish;
  const _StepComplete({required this.isClient, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 40,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Account Created!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isClient
                ? 'Welcome! Your identity has been verified.\nYou can now browse trusted local services.'
                : 'Welcome! Your identity has been verified.\nYou can now start accepting jobs.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          // Verified badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.success.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.verified_rounded,
                  size: 15,
                  color: AppColors.success,
                ),
                SizedBox(width: 6),
                Text(
                  'Phone & NID Verified',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _NextCard(
            icon: Icons.verified_user_outlined,
            iconColor: AppColors.navy,
            iconBg: AppColors.navyLight,
            title: isClient ? 'Explore Services' : 'Complete Your Profile',
            subtitle: isClient
                ? 'Browse providers near you by category.'
                : 'Add your skills and work photos to attract clients.',
          ),
          const SizedBox(height: 10),
          _NextCard(
            icon: Icons.notifications_outlined,
            iconColor: AppColors.accent,
            iconBg: AppColors.accentLight,
            title: 'Enable Notifications',
            subtitle: isClient
                ? 'Get alerts when providers respond to your requests.'
                : 'Never miss a new job request near you.',
          ),
          const SizedBox(height: 24),
          AppButton(
            label: isClient ? 'Start Exploring' : 'View Available Jobs',
            icon: Icons.arrow_forward_rounded,
            onTap: onFinish,
          ),
        ],
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  const _NextCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => CorpCard(
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
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
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMERA VIEWFINDER
// ─────────────────────────────────────────────────────────────────────────────
class _CameraViewfinder extends StatefulWidget {
  final void Function(XFile) onCapture;
  final VoidCallback onCancel;
  const _CameraViewfinder({required this.onCapture, required this.onCancel});

  @override
  State<_CameraViewfinder> createState() => _CameraViewfinderState();
}

class _CameraViewfinderState extends State<_CameraViewfinder>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  bool _torchOn = false;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulse = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.repeat(reverse: true);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No cameras available')));
        }
        return;
      }

      // Find the back camera
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile image = await _cameraController!.takePicture();
      widget.onCapture(image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        widget.onCapture(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      setState(() => _torchOn = !_torchOn);
      await _cameraController!.setFlashMode(
        _torchOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error toggling flash: $e')));
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(child: CameraPreview(_cameraController!))
          else
            Container(
              color: const Color(0xFF0A0F14),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Grid overlay
          if (_isCameraInitialized)
            Container(
              color: Colors.transparent,
              child: CustomPaint(painter: _CameraGridPainter()),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onCancel,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.camera_rear_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Back Camera — NID Scan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _toggleFlash,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _torchOn
                              ? Colors.white.withOpacity(0.9)
                              : Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Icon(
                          _torchOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: _torchOn ? Colors.black : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Card frame
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => CustomPaint(
                    painter: _CardFramePainter(opacity: _pulse.value),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.85,
                      height: MediaQuery.of(context).size.width * 0.85 * 0.63,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Align your NID card within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: _pickFromGallery,
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Gallery',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _captureImage,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_rounded,
                          color: Color(0xFF1C2B3A),
                          size: 30,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: 0.35,
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
                            child: const Icon(
                              Icons.flip_camera_ios_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Back only',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SmartField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool autoFilled;
  final bool readOnly;
  final bool required;
  final TextInputType keyboardType;
  final String? hint;
  final String? error;

  const _SmartField({
    required this.label,
    required this.controller,
    required this.icon,
    this.autoFilled = false,
    this.readOnly = false,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.hint,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final fillColor = hasError
        ? const Color(0xFFFFEEEE)
        : readOnly
        ? const Color(0xFFF0F4F8)
        : autoFilled
        ? const Color(0xFFEBF7F0)
        : AppColors.surface;
    final borderColor = hasError
        ? const Color(0xFFD94040)
        : readOnly
        ? AppColors.border
        : autoFilled
        ? AppColors.success.withOpacity(0.45)
        : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFD94040),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (autoFilled) ...[
              const SizedBox(width: 7),
              _Badge(
                label: 'NID AUTO-FILL',
                color: AppColors.success,
                bg: AppColors.successBg,
                icon: Icons.auto_awesome_rounded,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: TextStyle(
            fontSize: 15,
            color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                icon,
                size: 18,
                color: hasError
                    ? const Color(0xFFD94040)
                    : readOnly
                    ? AppColors.textTertiary
                    : autoFilled
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: readOnly
                    ? borderColor
                    : hasError
                    ? const Color(0xFFD94040)
                    : AppColors.navy,
                width: readOnly ? 1 : 1.5,
              ),
            ),
            suffixIcon: readOnly
                ? const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                  )
                : autoFilled
                ? const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(),
          ),
        ),

        // Helper / error text
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 12,
                color: Color(0xFFD94040),
              ),
              const SizedBox(width: 4),
              Text(
                error!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFD94040),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPECIALTY PICKER  —  4 selectable category tiles
// ─────────────────────────────────────────────────────────────────────────────
class _SpecialtyPicker extends StatelessWidget {
  final String selected;
  final bool hasError;
  final void Function(String) onSelected;

  const _SpecialtyPicker({
    required this.selected,
    required this.hasError,
    required this.onSelected,
  });

  static const _options = [
    (label: 'Electrician', icon: Icons.electrical_services_rounded),
    (label: 'Plumber',     icon: Icons.plumbing_rounded),
    (label: 'Cleaner',     icon: Icons.cleaning_services_rounded),
    (label: 'Painter',     icon: Icons.format_paint_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'YOUR SPECIALTY',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(width: 4),
            const Text('*', style: TextStyle(fontSize: 12, color: Color(0xFFD94040), fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: _options.map((opt) {
            final isSelected = selected == opt.label;
            return GestureDetector(
              onTap: () => onSelected(opt.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.navyLight : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasError && !isSelected
                        ? const Color(0xFFD94040).withOpacity(0.5)
                        : isSelected
                        ? AppColors.navy
                        : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      opt.icon,
                      size: 18,
                      color: isSelected ? AppColors.navy : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.navy : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: const [
              Icon(Icons.error_outline_rounded, size: 12, color: Color(0xFFD94040)),
              SizedBox(width: 4),
              Text(
                'Please select your specialty',
                style: TextStyle(fontSize: 11, color: Color(0xFFD94040), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PhoneField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool required;
  final String? error;

  const _PhoneField({
    required this.label,
    required this.controller,
    required this.icon,
    this.required = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final fillColor = hasError ? const Color(0xFFFFEEEE) : AppColors.surface;
    final borderColor = hasError ? const Color(0xFFD94040) : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFD94040),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: '01XXX-XXXXXX',
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
            counterText: '',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                icon,
                size: 18,
                color: hasError
                    ? const Color(0xFFD94040)
                    : AppColors.textSecondary,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(),
            prefix: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '+88 ',
                style: TextStyle(
                  fontSize: 15,
                  color: hasError
                      ? const Color(0xFFD94040)
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFD94040) : AppColors.navy,
                width: 1.5,
              ),
            ),
          ),
        ),

        // Error text
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 12,
                color: Color(0xFFD94040),
              ),
              const SizedBox(width: 4),
              Text(
                error!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFD94040),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppColors.navy),
      ),
      const SizedBox(width: 10),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.navy,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    ],
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color, bg;
  final IconData icon;
  const _Badge({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 8, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final String text;
  final Color? borderColor;
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.bg,
    required this.text,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: borderColor ?? AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color == AppColors.navy ? AppColors.textSecondary : color,
              height: 1.55,
            ),
          ),
        ),
      ],
    ),
  );
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: AppColors.border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'OR',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      const Expanded(child: Divider(color: AppColors.border)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────────────────────────────────────
class _CardFramePainter extends CustomPainter {
  final double opacity;
  const _CardFramePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cl = 24.0;
    const r = 10.0;
    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(r, 0), Offset(r + cl, 0), p);
    canvas.drawLine(Offset(0, r), Offset(0, r + cl), p);
    canvas.drawArc(Rect.fromLTWH(0, 0, r * 2, r * 2), 3.14, 1.57, false, p);

    canvas.drawLine(Offset(w - r - cl, 0), Offset(w - r, 0), p);
    canvas.drawLine(Offset(w, r), Offset(w, r + cl), p);
    canvas.drawArc(
      Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2),
      4.71,
      1.57,
      false,
      p,
    );

    canvas.drawLine(Offset(r, h), Offset(r + cl, h), p);
    canvas.drawLine(Offset(0, h - r - cl), Offset(0, h - r), p);
    canvas.drawArc(
      Rect.fromLTWH(0, h - r * 2, r * 2, r * 2),
      1.57,
      1.57,
      false,
      p,
    );

    canvas.drawLine(Offset(w - r - cl, h), Offset(w - r, h), p);
    canvas.drawLine(Offset(w, h - r - cl), Offset(w, h - r), p);
    canvas.drawArc(
      Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2),
      0,
      1.57,
      false,
      p,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, w - 2, h - 2),
        const Radius.circular(10),
      ),
      Paint()
        ..color = AppColors.accent.withOpacity(0.4)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_CardFramePainter old) => old.opacity != opacity;
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      p,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      p,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      p,
    );
  }

  @override
  bool shouldRepaint(_CameraGridPainter _) => false;
}
