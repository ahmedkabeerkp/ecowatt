import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/screens/home_screen.dart';
import 'package:eco_watt/services/energy_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────
// MeterCalibrationScreen
//
// Shown automatically after the billing cycle ends (from SplashScreen).
// The user enters the 3 unit categories directly from their KSEB bill:
//   KWH/NL/1 — Normal time  (6AM–6PM)
//   KWH/OP/1 — Off-peak time (10PM–6AM)
//   KWH/PK/1 — Peak time    (6PM–10PM)
//
// Calibration logic:
//   totalActual  = nl + op + pk
//   totalEstimated = EnergyService.calculateCycleUnits(...)
//   ratio = totalActual / totalEstimated  (clamped 0.5 – 2.0)
//   newAccuracyFactor = (old × ratio).clamp(0.3, 1.0)  per scheduled appliance
// ─────────────────────────────────────────────────────────────────
class MeterCalibrationScreen extends StatefulWidget {
  /// When true, shows a Skip button instead of a back arrow.
  /// Pass true when navigating from SplashScreen (mandatory popup).
  final bool isMandatoryPopup;

  const MeterCalibrationScreen({super.key, this.isMandatoryPopup = false});

  @override
  State<MeterCalibrationScreen> createState() => _MeterCalibrationScreenState();
}

class _MeterCalibrationScreenState extends State<MeterCalibrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for the 3 TOD readings
  final _nlController = TextEditingController(); // KWH/NL/1 — Normal
  final _opController = TextEditingController(); // KWH/OP/1 — Off-Peak
  final _pkController = TextEditingController(); // KWH/PK/1 — Peak

  bool _isSaving = false;

  @override
  void dispose() {
    _nlController.dispose();
    _opController.dispose();
    _pkController.dispose();
    super.dispose();
  }

  // ── Validation helper ─────────────────────────────────────────
  String? _validateField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final n = double.tryParse(value.trim());
    if (n == null || n < 0) return 'Enter a valid number';
    return null;
  }

  // ── Save reading + recalibrate accuracy factors ───────────────
  Future<void> _saveReading() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    try {
      final nl = double.parse(_nlController.text.trim());
      final op = double.parse(_opController.text.trim());
      final pk = double.parse(_pkController.text.trim());
      final totalActual = nl + op + pk;

      // ── Fetch user data for cycle info ─────────────────────────
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data() ?? {};

      final billingCycle = (userData['billingCycle'] as String?) ?? '2 Month';
      final DateTime cycleStart =
          (userData['billingStartDate'] as Timestamp?)?.toDate() ??
          (userData['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now();

      // ── Fetch appliance schedules ──────────────────────────────
      final schedSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('applianceSchedules')
          .get();

      // ── Calculate estimated total using EnergyService ─────────
      final double totalEstimated = EnergyService.calculateCycleUnits(
        schedSnapshot.docs,
        cycleStart,
        billingCycle,
      );

      // ── Compute calibration ratio ──────────────────────────────
      // ratio > 1 means we underestimated → lower accuracy factors
      // ratio < 1 means we overestimated → raise accuracy factors
      final double ratio = totalEstimated > 0
          ? (totalActual / totalEstimated).clamp(0.5, 2.0)
          : 1.0;

      // ── Batch update all scheduled appliances ─────────────────
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in schedSnapshot.docs) {
        final d = doc.data();
        final type = d['applianceType'] as String? ?? 'scheduled';

        // Only adjust accuracy for scheduled appliances
        if (type != 'scheduled') continue;

        final oldFactor = (d['accuracyFactor'] as num?)?.toDouble() ?? 0.7;

        // If we overestimated (ratio < 1): reduce factor (was using more than scheduled)
        // If we underestimated (ratio > 1): raise factor (was using less than scheduled)
        // The inverse: actual is the truth. If actual > estimated, our accuracy was too high.
        final newFactor = (oldFactor / ratio).clamp(0.3, 1.0);

        batch.update(doc.reference, {'accuracyFactor': newFactor});
      }

      // ── Save calibration record to user doc ───────────────────
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'lastCalibrationDate': Timestamp.now(),
        'lastCalibrationNlUnits': nl,
        'lastCalibrationOpUnits': op,
        'lastCalibrationPkUnits': pk,
        'lastCalibrationTotalActual': totalActual,
        'lastCalibrationEstimated': totalEstimated,
      });

      await batch.commit();

      if (!mounted) return;
      _goHome();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back navigation when shown as mandatory popup
      canPop: !widget.isMandatoryPopup,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.isMandatoryPopup) _goHome();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F3),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: widget.isMandatoryPopup
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
          actions: widget.isMandatoryPopup
              ? [
                  TextButton(
                    onPressed: _goHome,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]
              : null,
          title: const Text(
            'Calibrate Meter',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Icon header ───────────────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.electric_meter_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter Meter Reading',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Update your actual units from your KSEB\nbill to improve EcoWatt\'s accuracy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                // ── Notice card ───────────────────────────────────
                _InfoCard(
                  icon: Icons.info_outline_rounded,
                  title: 'How to read?',
                  body:
                      'Open your KSEB bill and find the section titled "Reading & Consumption (MM)". '
                      'You will see three rows — KWH/NL/1, KWH/OP/1, and KWH/PK/1. '
                      'Enter the value from the "ഉപഭോഗം" (Consumption) column for each row below.',
                ),

                const SizedBox(height: 20),

                // ── Input card ────────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        child: Text(
                          'METER READINGS (UNITS CONSUMED)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey.shade100),

                      // KWH/NL/1 — Normal
                      _ReadingField(
                        label: 'KWH/NL/1',
                        sublabel: 'Normal Time · 6AM – 6PM',
                        hint: 'e.g. 306',
                        controller: _nlController,
                        validator: _validateField,
                        color: const Color(0xFF1565C0),
                        icon: Icons.wb_sunny_rounded,
                      ),
                      Divider(
                        height: 1,
                        color: Colors.grey.shade100,
                        indent: 20,
                        endIndent: 20,
                      ),

                      // KWH/OP/1 — Off-Peak
                      _ReadingField(
                        label: 'KWH/OP/1',
                        sublabel: 'Off-Peak Time · 10PM – 6AM',
                        hint: 'e.g. 240',
                        controller: _opController,
                        validator: _validateField,
                        color: const Color(0xFF00897B),
                        icon: Icons.nightlight_round,
                      ),
                      Divider(
                        height: 1,
                        color: Colors.grey.shade100,
                        indent: 20,
                        endIndent: 20,
                      ),

                      // KWH/PK/1 — Peak
                      _ReadingField(
                        label: 'KWH/PK/1',
                        sublabel: 'Peak Time · 6PM – 10PM',
                        hint: 'e.g. 71',
                        controller: _pkController,
                        validator: _validateField,
                        color: const Color(0xFFE53935),
                        icon: Icons.bolt_rounded,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── TOD rate note ─────────────────────────────────
                _InfoCard(
                  icon: Icons.tips_and_updates_rounded,
                  title: 'KSEB Time-of-Day Rates',
                  body:
                      'Peak (6–10 PM) units are billed at 30% higher rate. '
                      'Off-peak (10 PM–6 AM) units are the cheapest. '
                      'Normal (6 AM–6 PM) units are 20% cheaper than off-peak. '
                      'EcoWatt uses this to calculate your accurate bill estimate.',
                  accentColor: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
        ),

        // ── Update Reading button ─────────────────────────────────
        bottomSheet: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveReading,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Update Reading',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Single reading input row
// ─────────────────────────────────────────────────────────────────
class _ReadingField extends StatelessWidget {
  final String label;
  final String sublabel;
  final String hint;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final Color color;
  final IconData icon;

  const _ReadingField({
    required this.label,
    required this.sublabel,
    required this.hint,
    required this.controller,
    required this.validator,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Icon + labels
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Input field
          SizedBox(
            width: 110,
            child: TextFormField(
              controller: controller,
              validator: validator,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                suffixText: 'kWh',
                suffixStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: color, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
                errorStyle: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Info / tip card
// ─────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color? accentColor;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.5,
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
