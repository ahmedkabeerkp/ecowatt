import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/screens/auth_screen.dart';
import 'package:eco_watt/screens/notification_screen.dart';
import 'package:eco_watt/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────
const String _kAppVersion = '1.0.0'; // Update per release

// ─────────────────────────────────────────────────────────────────
// SettingsScreen
// ─────────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Firestore + Auth ──────────────────────────────────────────
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser!.uid;
  DocumentReference get _userDoc => _firestore.collection('users').doc(_uid);

  // ── Local state ───────────────────────────────────────────────
  String _displayUnit = 'both'; // 'kwh' | 'cost' | 'both'
  String _appearance = 'system'; // 'system' | 'light' | 'dark'  (placeholder)
  String _language = 'en'; // 'en' | 'ml'  (placeholder)
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final snap = await _userDoc.get();
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      setState(() {
        _displayUnit = (data['displayUnit'] as String?) ?? 'both';
        _appearance = (data['appearance'] as String?) ?? 'system';
        _language = (data['language'] as String?) ?? 'en';
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _savePref(String key, dynamic value) async {
    try {
      await _userDoc.update({key: value});
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // Morning Tip time picker
  // ─────────────────────────────────────────────────────────────
  Future<void> _pickMorningTipTime(
    BuildContext context,
    TimeOfDay current,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Morning Tip Time',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await _savePref('morningTipTime', formatted);

    // Re-schedule notifications with the new time
    // NotificationService reads morningTipTime from Firestore on next schedule call.
    // HomeScreen.initState schedules on launch, so change takes effect next app open.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Morning tip time updated to $formatted'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Reset app data
  // ─────────────────────────────────────────────────────────────
  Future<void> _confirmResetData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Reset App Data?',
        body:
            'This will delete all your usage logs and reset accuracy factors. '
            'Your profile, appliances and schedules are kept.',
        confirmLabel: 'Reset',
        confirmColor: Colors.orange,
      ),
    );
    if (confirmed != true) return;

    _showLoadingOverlay(context, 'Resetting data…');

    try {
      // 1. Delete usageLogs subcollection
      final logs = await _userDoc.collection('usageLogs').get();
      for (final doc in logs.docs) {
        await doc.reference.delete();
      }

      // 2. Reset accuracyFactor on all applianceSchedules
      final schedules = await _userDoc.collection('applianceSchedules').get();
      final batch = _firestore.batch();
      for (final doc in schedules.docs) {
        batch.update(doc.reference, {'accuracyFactor': 0.75});
      }
      // 3. Clear confirmation + survey dates
      batch.update(_userDoc, {
        'lastConfirmationDate': FieldValue.delete(),
        'lastWeeklySurveyDate': FieldValue.delete(),
      });
      await batch.commit();

      if (context.mounted) {
        Navigator.of(context).pop(); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('App data reset successfully'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _showError(context, 'Reset failed. Please try again.');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Delete account — re-auth then wipe
  // ─────────────────────────────────────────────────────────────
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    // Step 1: warn
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Delete Account?',
        body:
            'This permanently deletes your EcoWatt account, all usage history, '
            'appliances and billing data. This cannot be undone.',
        confirmLabel: 'Continue',
        confirmColor: Colors.red,
      ),
    );
    if (proceed != true) return;

    // Step 2: re-auth
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ReAuthDialog(),
    );
    if (password == null || password.isEmpty) return;

    _showLoadingOverlay(context, 'Deleting account…');

    try {
      final user = _auth.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);

      // Wipe Firestore — subcollections first
      final collections = ['usageLogs', 'applianceSchedules'];
      for (final col in collections) {
        final snap = await _userDoc.collection(col).get();
        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      await _userDoc.delete();

      // Delete Firebase Auth user
      await user.delete();

      if (context.mounted) {
        Navigator.of(context).pop(); // close loading
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        final msg = e.code == 'wrong-password'
            ? 'Incorrect password. Please try again.'
            : 'Authentication failed: ${e.message}';
        _showError(context, msg);
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _showError(context, 'Deletion failed. Please try again.');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────
  void _showLoadingOverlay(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: _userDoc.snapshots(),
              builder: (context, snap) {
                final data = (snap.hasData && snap.data!.exists)
                    ? (snap.data!.data() as Map<String, dynamic>? ?? {})
                    : <String, dynamic>{};

                final String name = (data['name'] as String?) ?? 'User';
                final String email = _auth.currentUser?.email ?? '';
                final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                final int joinYear =
                    createdAt?.toDate().year ?? DateTime.now().year;

                // Morning tip time
                final String morningTipRaw =
                    (data['morningTipTime'] as String?) ?? '07:00';
                final parts = morningTipRaw.split(':');
                final morningTipTime = TimeOfDay(
                  hour: int.tryParse(parts[0]) ?? 7,
                  minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  children: [
                    // ── Profile card ──────────────────────────
                    _ProfileCard(
                      name: name,
                      email: email,
                      joinYear: joinYear,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Preferences ───────────────────────────
                    const _SectionHeader(label: 'PREFERENCES'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        // Notifications & Alerts
                        _SettingsTile(
                          icon: Icons.notifications_outlined,
                          iconColor: const Color(0xFF1565C0),
                          title: 'Notifications & Alerts',
                          subtitle: 'Peak, morning tips, in-app prompts',
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          ),
                        ),
                        const _Divider(),

                        // Morning Tip Time
                        _SettingsTile(
                          icon: Icons.wb_sunny_outlined,
                          iconColor: const Color(0xFFF57F17),
                          title: 'Morning Tip Time',
                          subtitle: morningTipTime.format(context),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                          onTap: () =>
                              _pickMorningTipTime(context, morningTipTime),
                        ),
                        const _Divider(),

                        // Usage Display
                        _SettingsTile(
                          icon: Icons.bar_chart_rounded,
                          iconColor: AppColors.primary,
                          title: 'Usage Display',
                          subtitle: _displayUnitLabel(_displayUnit),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                          onTap: () => _showDisplayUnitSheet(context),
                        ),
                        const _Divider(),

                        // Appearance (placeholder)
                        _SettingsTile(
                          icon: Icons.palette_outlined,
                          iconColor: const Color(0xFF6A1B9A),
                          title: 'Appearance',
                          subtitle: _appearanceLabel(_appearance),
                          trailing: _PlaceholderBadge(),
                          onTap: () => _showComingSoon(context, 'Appearance'),
                        ),
                        const _Divider(),

                        // Language (placeholder)
                        _SettingsTile(
                          icon: Icons.language_rounded,
                          iconColor: const Color(0xFF00838F),
                          title: 'Language',
                          subtitle: _language == 'ml' ? 'മലയാളം' : 'English',
                          trailing: _PlaceholderBadge(),
                          onTap: () => _showComingSoon(context, 'Language'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Account ───────────────────────────────
                    const _SectionHeader(label: 'ACCOUNT'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          icon: Icons.person_outline_rounded,
                          iconColor: AppColors.primary,
                          title: 'Edit Profile',
                          subtitle: 'Name, phone, house type, billing cycle',
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Help ──────────────────────────────────
                    const _SectionHeader(label: 'HELP'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          icon: Icons.refresh_rounded,
                          iconColor: Colors.orange,
                          title: 'Reset App Data',
                          subtitle: 'Clear usage logs, reset accuracy factors',
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                          onTap: () => _confirmResetData(context),
                        ),
                        const _Divider(),
                        _SettingsTile(
                          icon: Icons.delete_outline_rounded,
                          iconColor: Colors.red,
                          title: 'Delete Account',
                          subtitle:
                              'Permanently remove all data and credentials',
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                          onTap: () => _confirmDeleteAccount(context),
                          titleColor: Colors.red,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── App version footer ────────────────────
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'ECOWATT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Version $_kAppVersion',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Usage Display bottom sheet
  // ─────────────────────────────────────────────────────────────
  void _showDisplayUnitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Usage Display',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how usage data is shown across the app.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ...[
                (
                  'kwh',
                  'Units only',
                  'Show kWh across all screens',
                  Icons.bolt_rounded,
                ),
                (
                  'cost',
                  'Cost only',
                  'Show ₹ estimates across all screens',
                  Icons.currency_rupee_rounded,
                ),
                (
                  'both',
                  'Both',
                  'Show kWh and ₹ together',
                  Icons.swap_horiz_rounded,
                ),
              ].map((opt) {
                final isSelected = _displayUnit == opt.$1;
                return GestureDetector(
                  onTap: () async {
                    setState(() => _displayUnit = opt.$1);
                    await _savePref('displayUnit', opt.$1);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          opt.$4,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade500,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.$2,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFF212121),
                                ),
                              ),
                              Text(
                                opt.$3,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        backgroundColor: Colors.grey.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _displayUnitLabel(String v) {
    switch (v) {
      case 'kwh':
        return 'Units (kWh)';
      case 'cost':
        return 'Cost (₹)';
      default:
        return 'Both (kWh + ₹)';
    }
  }

  String _appearanceLabel(String v) {
    switch (v) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System default';
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Profile card
// ─────────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final int joinYear;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.name,
    required this.email,
    required this.joinYear,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.eco_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Eco-Member since $joinYear',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Settings card container
// ─────────────────────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(children: children),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Settings tile
// ─────────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Divider inside card
// ─────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 70),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// "Coming Soon" badge
// ─────────────────────────────────────────────────────────────────
class _PlaceholderBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Soon',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Generic confirm dialog
// ─────────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      content: Text(
        body,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: confirmColor, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Re-auth dialog (password entry)
// ─────────────────────────────────────────────────────────────────
class _ReAuthDialog extends StatefulWidget {
  const _ReAuthDialog();

  @override
  State<_ReAuthDialog> createState() => _ReAuthDialogState();
}

class _ReAuthDialogState extends State<_ReAuthDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Confirm Identity',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your password to confirm account deletion.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: Text(
            'Delete Account',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
