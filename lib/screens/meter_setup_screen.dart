import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/screens/appliances_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MeterSetupScreen extends StatefulWidget {
  // ── isEditMode: true  → accessed from drawer, pre-filled, back on save
  // ── isEditMode: false → onboarding flow, navigates to AppliancesScreen
  final bool isEditMode;

  const MeterSetupScreen({super.key, this.isEditMode = false});

  @override
  State<MeterSetupScreen> createState() => _MeterSetupScreenState();
}

class _MeterSetupScreenState extends State<MeterSetupScreen> {
  String? _selectedTariff;
  String? _selectedPurpose;
  String _billingCycle = '2 Month';
  String _phase = 'Single Phase';
  DateTime? _billingStartDate;
  bool _isLoading = false;
  bool _isLoadingData = false; // pre-filling in edit mode

  final List<String> _tariffOptions = [
    'Domestic',
    'Commercial',
    'Industrial',
    'Agricultural',
  ];

  final List<String> _purposeOptions = [
    'Residential',
    'Office',
    'Shop',
    'Factory',
    'Farm',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill fields when opened in edit mode
    if (widget.isEditMode) _loadExistingData();
  }

  // ── Pre-fill existing Firestore data in edit mode ─────────────
  Future<void> _loadExistingData() async {
    setState(() => _isLoadingData = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoadingData = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};

      setState(() {
        _selectedTariff = data['tariff'] as String?;
        _selectedPurpose = data['purpose'] as String?;
        _billingCycle = (data['billingCycle'] as String?) ?? '2 Month';
        _phase = (data['phase'] as String?) ?? 'Single Phase';
        final ts = data['billingStartDate'] as Timestamp?;
        _billingStartDate = ts?.toDate();
      });
    } catch (_) {}
    if (mounted) setState(() => _isLoadingData = false);
  }

  // ── Date picker ───────────────────────────────────────────────
  Future<void> _pickBillingStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billingStartDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
      helpText: 'Select billing cycle start date',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _billingStartDate = picked);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ── Submit ────────────────────────────────────────────────────
  Future<void> _submitMeterSetup() async {
    if (_selectedTariff == null || _selectedPurpose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Tariff and Purpose'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_billingStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your billing cycle start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'tariff': _selectedTariff,
        'purpose': _selectedPurpose,
        'billingCycle': _billingCycle,
        'phase': _phase,
        'billingStartDate': Timestamp.fromDate(_billingStartDate!),
        'meterSetupCompleted': true,
      }, SetOptions(merge: true));

      if (!mounted) return;

      if (widget.isEditMode) {
        // Edit mode: show success and go back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Meter settings updated successfully'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        // Onboarding mode: continue to next screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppliancesScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Meter Settings' : 'Meter Setup'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        // Show back button in edit mode, hide in onboarding
        automaticallyImplyLeading: widget.isEditMode,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ───────────────────────────────────
                    Text(
                      widget.isEditMode
                          ? 'Update Meter Settings'
                          : 'Setup your Electricity Meter',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isEditMode
                          ? 'Update your connection type and billing cycle'
                          : 'Tell us about your connection type and billing cycle',
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // ── Tariff ───────────────────────────────────
                    const _FieldLabel(label: 'Tariff'),
                    const SizedBox(height: 8),
                    _StyledDropdown<String>(
                      value: _selectedTariff,
                      hint: 'Select Tariff',
                      items: _tariffOptions,
                      onChanged: (v) => setState(() => _selectedTariff = v),
                    ),
                    const SizedBox(height: 20),

                    // ── Purpose ──────────────────────────────────
                    const _FieldLabel(label: 'Purpose'),
                    const SizedBox(height: 8),
                    _StyledDropdown<String>(
                      value: _selectedPurpose,
                      hint: 'Select Purpose',
                      items: _purposeOptions,
                      onChanged: (v) => setState(() => _selectedPurpose = v),
                    ),
                    const SizedBox(height: 20),

                    // ── Billing Cycle ─────────────────────────────
                    const _FieldLabel(label: 'Billing Cycle'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _RadioOption(
                            title: '2 Month',
                            value: '2 Month',
                            groupValue: _billingCycle,
                            onChanged: (v) =>
                                setState(() => _billingCycle = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _RadioOption(
                            title: '1 Month',
                            value: '1 Month',
                            groupValue: _billingCycle,
                            onChanged: (v) =>
                                setState(() => _billingCycle = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Billing Start Date ────────────────────────
                    const _FieldLabel(label: 'Billing Cycle Start Date'),
                    const SizedBox(height: 6),
                    Text(
                      'Check your last KSEB bill for the cycle start date.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickBillingStartDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _billingStartDate != null
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            width: _billingStartDate != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: _billingStartDate != null
                                  ? AppColors.primary
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _billingStartDate != null
                                  ? _formatDate(_billingStartDate!)
                                  : 'Select billing start date',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: _billingStartDate != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _billingStartDate != null
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                              ),
                            ),
                            const Spacer(),
                            if (_billingStartDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Phase ─────────────────────────────────────
                    const _FieldLabel(label: 'Phase'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _RadioOption(
                            title: 'Single Phase',
                            value: 'Single Phase',
                            groupValue: _phase,
                            onChanged: (v) => setState(() => _phase = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _RadioOption(
                            title: 'Three Phase',
                            value: 'Three Phase',
                            groupValue: _phase,
                            onChanged: (v) => setState(() => _phase = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // ── Submit ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitMeterSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
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
                            : Text(
                                // Different label per mode
                                widget.isEditMode
                                    ? 'Save Changes'
                                    : 'Continue →',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Field label
// ─────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Styled dropdown
// ─────────────────────────────────────────────────────────────────
class _StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _StyledDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint),
        isExpanded: true,
        underline: const SizedBox(),
        items: items
            .map(
              (v) => DropdownMenuItem<T>(value: v, child: Text(v.toString())),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Radio option card
// ─────────────────────────────────────────────────────────────────
class _RadioOption extends StatelessWidget {
  final String title;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _RadioOption({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
