import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/screens/auth_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _addressController = TextEditingController();
  int _householdCount = 4; // default baseline
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};
      _addressController.text = (data['address'] as String?) ?? '';
      _householdCount = (data['householdCount'] as num?)?.toInt() ?? 4;
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveChanges() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'address': _addressController.text.trim(),
        'householdCount': _householdCount,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _logout() async {
    // Confirm before logging out
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: user != null
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots()
                  : const Stream.empty(),
              builder: (context, snap) {
                final data = (snap.hasData && snap.data!.exists)
                    ? (snap.data!.data() as Map<String, dynamic>? ?? {})
                    : <String, dynamic>{};

                final name = (data['name'] as String?) ?? '—';
                final email = user?.email ?? '—';
                final phone = (data['phone'] as String?) ?? '—';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Avatar + Name ─────────────────────────────
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.30,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A2E20),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Read-Only Info Section ────────────────────
                      _SectionLabel(label: 'ACCOUNT INFO'),
                      const SizedBox(height: 10),
                      _InfoCard(
                        rows: [
                          _InfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Full Name',
                            value: name,
                          ),
                          _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: email,
                          ),
                          _InfoRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: phone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Editable Section ──────────────────────────
                      _SectionLabel(label: 'HOUSEHOLD DETAILS'),
                      const SizedBox(height: 10),

                      // Address
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Address',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A2E20),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _addressController,
                              maxLines: 2,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(150),
                              ],
                              decoration: InputDecoration(
                                hintText: 'Enter your address',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8F9FA),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Household Count
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Number of Household Members',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A2E20),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Helps improve appliance usage estimates',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Decrease button
                                _StepperButton(
                                  icon: Icons.remove_rounded,
                                  onTap: () {
                                    if (_householdCount > 1) {
                                      setState(() => _householdCount--);
                                    }
                                  },
                                  enabled: _householdCount > 1,
                                ),
                                const SizedBox(width: 24),
                                // Count display
                                Column(
                                  children: [
                                    Text(
                                      '$_householdCount',
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                        height: 1,
                                      ),
                                    ),
                                    Text(
                                      _householdCount == 1
                                          ? 'person'
                                          : 'people',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                // Increase button
                                _StepperButton(
                                  icon: Icons.add_rounded,
                                  onTap: () {
                                    if (_householdCount < 15) {
                                      setState(() => _householdCount++);
                                    }
                                  },
                                  enabled: _householdCount < 15,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Visual scale indicator
                            _HouseholdScaleBar(count: _householdCount),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Save Button ───────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
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
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Logout Button ─────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                          label: const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.red,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Section Label
// ─────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Info Card (read-only rows)
// ─────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(row.icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      row.value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2E20),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < rows.length - 1)
                Divider(height: 1, color: Colors.grey.shade100),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
}

// ─────────────────────────────────────────────────────────────────
// Stepper Button (+/-)
// ─────────────────────────────────────────────────────────────────
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.primary : Colors.grey.shade300,
          size: 22,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Household Scale Bar — visual low/med/high indicator
// ─────────────────────────────────────────────────────────────────
class _HouseholdScaleBar extends StatelessWidget {
  final int count;
  const _HouseholdScaleBar({required this.count});

  @override
  Widget build(BuildContext context) {
    // count 1-5: low, 6-10: medium, 11-15: high
    final String label;
    final Color color;
    final double fillRatio = (count - 1) / 14.0;

    if (count <= 4) {
      label = 'Low usage estimate';
      color = AppColors.primary;
    } else if (count <= 9) {
      label = 'Medium usage estimate';
      color = const Color(0xFFF59E0B);
    } else {
      label = 'High usage estimate';
      color = const Color(0xFFE53935);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fillRatio,
            minHeight: 6,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '1                   15',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ],
        ),
      ],
    );
  }
}
