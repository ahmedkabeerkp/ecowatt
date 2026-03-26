import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/screens/meter_setup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileCompletion extends StatefulWidget {
  const ProfileCompletion({super.key});

  @override
  State<ProfileCompletion> createState() => _ProfileCompletionState();
}

class _ProfileCompletionState extends State<ProfileCompletion> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _phoneError;
  String? _targetError;

  String _selectedHouseType = 'Small House';
  final List<Map<String, dynamic>> _houseTypes = [
    {'label': 'Apartment', 'icon': Icons.apartment_rounded},
    {'label': 'Small House', 'icon': Icons.home_rounded},
    {'label': 'Large House', 'icon': Icons.villa_rounded},
    {'label': 'Villa', 'icon': Icons.holiday_village_rounded},
  ];

  double _targetUnits = 0;

  bool _validatePhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.isEmpty) {
      setState(() => _phoneError = "Phone number is required");
      return false;
    }
    if (phone.length != 10) {
      setState(() => _phoneError = "Enter a valid 10-digit phone number");
      return false;
    }
    setState(() => _phoneError = null);
    return true;
  }

  bool _validateTarget() {
    if (_targetUnits <= 0) {
      setState(() => _targetError = "Please set a monthly target");
      return false;
    }
    if (_targetUnits < 50) {
      setState(() => _targetError = "Target must be at least 50 units");
      return false;
    }
    setState(() => _targetError = null);
    return true;
  }

  Future<void> _saveProfile() async {
    final phone = _phoneController.text.trim();
    final isPhoneValid = _validatePhone(phone);
    final isTargetValid = _validateTarget();

    if (!isPhoneValid || !isTargetValid) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phone': cleanPhone,
        'houseType': _selectedHouseType,
        'goal': _targetUnits,
        'profileCompleted': true,
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MeterSetupScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Complete Profile',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Phone Number ──────────────────────────────────
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PhoneField(
                      controller: _phoneController,
                      errorText: _phoneError,
                      onChanged: (_) {
                        if (_phoneError != null) {
                          setState(() => _phoneError = null);
                        }
                      },
                    ),

                    const SizedBox(height: 32),

                    // ── House Type ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'House Type',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Slide to select',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: _houseTypes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final type = _houseTypes[i];
                          final isSelected =
                              _selectedHouseType == type['label'];
                          return GestureDetector(
                            onTap: () => setState(
                              () => _selectedHouseType = type['label'],
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 110,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.10)
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    type['icon'] as IconData,
                                    size: 36,
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    type['label'] as String,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Monthly Target Card ───────────────────────────
                    _MonthlyTargetCard(
                      targetUnits: _targetUnits,
                      hasError: _targetError != null,
                      onChanged: (v) => setState(() {
                        _targetUnits = v;
                        // Clear error as soon as user moves slider past 50
                        if (v >= 50 && _targetError != null) {
                          _targetError = null;
                        }
                      }),
                    ),

                    // Error text below the card
                    if (_targetError != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 14,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _targetError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Save Profile Button ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Save Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────
// Phone Field — +91 prefix + "XXXXX XXXXX" live formatter
// ─────────────────────────────────────────────────────────────────
class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;

  const _PhoneField({
    required this.controller,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null ? Colors.red : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    _PhoneSpaceFormatter(),
                  ],
                  onChanged: onChanged,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: '00000 00000',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

class _PhoneSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 5) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Monthly Target Card
// ─────────────────────────────────────────────────────────────────
class _MonthlyTargetCard extends StatelessWidget {
  final double targetUnits;
  final bool hasError;
  final ValueChanged<double> onChanged;

  const _MonthlyTargetCard({
    required this.targetUnits,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError ? Colors.red.shade300 : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: hasError
                ? Colors.red.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MONTHLY TARGET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: hasError ? Colors.red.shade400 : Colors.grey.shade500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Eco Goal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Value display
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                targetUnits <= 0 ? '—' : targetUnits.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: hasError ? Colors.red.shade300 : Colors.black87,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  targetUnits <= 0 ? 'Not set' : 'Units',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: hasError ? Colors.red.shade300 : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _SliderWithKsebMarker(value: targetUnits, onChanged: onChanged),

          const SizedBox(height: 24),

          Text(
            'Adjusting your target helps us optimize your energy saving notifications.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Slider with KSEB 250-unit slab-jump marker (centered correctly)
// ─────────────────────────────────────────────────────────────────
class _SliderWithKsebMarker extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  static const double _min = 0;
  static const double _max = 500;
  static const double _kseb = 250;

  const _SliderWithKsebMarker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const sliderPad = 24.0;
        final trackWidth = constraints.maxWidth - sliderPad * 2;
        final fraction = (_kseb - _min) / (_max - _min);
        final markerOffsetX = sliderPad + trackWidth * fraction;
        final alignX = (markerOffsetX / constraints.maxWidth) * 2 - 1;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: Colors.grey.shade200,
                thumbColor: AppColors.primary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayColor: AppColors.primary.withValues(alpha: 0.15),
                trackHeight: 5,
              ),
              child: Slider(
                value: value,
                min: _min,
                max: _max,
                divisions: 100,
                onChanged: onChanged,
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                // 0 / 500 labels
                Padding(
                  padding: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0 UNITS',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '500 UNITS',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // KSEB marker — centered precisely using Align
                Positioned(
                  top: -10,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment(alignX, 0),
                    child: Column(
                      children: [
                        Container(
                          width: 2,
                          height: 18,
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFF59E0B),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 12,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '250: KSEB Slab Jump',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
