import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Toggle states
  bool _peakHourWarnings = true;
  bool _slabBudgetLimits = true;
  bool _applianceScheduling = false;
  bool _dailyUsageSummary = true;

  // Delivery preferences
  String _summaryDeliveryTime = '8:00 AM';
  // NOTE: must match _accuracyDelta() keys in energy_service + notification_service
  String _alertFrequency = 'Balanced';

  bool _loading = true;

  // Cached appliances for live scheduling
  List<Map<String, dynamic>> _appliances = [];

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _timeOptions = [
    '6:00 AM',
    '7:00 AM',
    '8:00 AM',
    '9:00 AM',
    '10:00 AM',
  ];

  // Matches _accuracyDelta() switch cases in both service files
  final List<String> _frequencyOptions = ['Strict', 'Balanced', 'Relaxed'];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (_uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _firestore.collection('users').doc(_uid).get(),
        _firestore
            .collection('users')
            .doc(_uid)
            .collection('applianceSchedules')
            .get(),
      ]);

      final userDoc = results[0] as DocumentSnapshot;
      final schedSnap = results[1] as QuerySnapshot;

      _appliances = schedSnap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

      if (userDoc.exists) {
        final data = userDoc.data()! as Map<String, dynamic>;
        // Migrate old 'Normal' → 'Balanced' if present from previous version
        String freq = data['notif_alertFrequency'] ?? 'Balanced';
        if (!_frequencyOptions.contains(freq)) freq = 'Balanced';

        setState(() {
          _peakHourWarnings = data['notif_peakHourWarnings'] ?? true;
          _slabBudgetLimits = data['notif_slabBudgetLimits'] ?? true;
          _applianceScheduling = data['notif_applianceScheduling'] ?? false;
          _dailyUsageSummary = data['notif_dailyUsageSummary'] ?? true;
          _summaryDeliveryTime = data['notif_summaryDeliveryTime'] ?? '8:00 AM';
          _alertFrequency = freq;
        });
      }
    } catch (_) {
      // Use defaults on error
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Save preference AND immediately act on it ─────────────────
  Future<void> _onPeakToggle(bool value) async {
    setState(() => _peakHourWarnings = value);
    await _savePreference('notif_peakHourWarnings', value);

    if (value) {
      await NotificationService.scheduleTodayNotifications(
        uid: _uid!,
        appliances: _appliances,
        peakEnabled: true,
        morningEnabled: _applianceScheduling,
      );
    } else {
      await NotificationService.cancelPeakWarning();
    }
  }

  Future<void> _onMorningToggle(bool value) async {
    setState(() => _applianceScheduling = value);
    await _savePreference('notif_applianceScheduling', value);

    if (value) {
      await NotificationService.scheduleTodayNotifications(
        uid: _uid!,
        appliances: _appliances,
        peakEnabled: _peakHourWarnings,
        morningEnabled: true,
      );
    } else {
      await NotificationService.cancelMorningTip();
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    if (_uid == null) return;
    try {
      await _firestore.collection('users').doc(_uid).update({key: value});
    } catch (_) {}
  }

  // ── Reset all notification preferences to defaults ────────────
  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reset Notifications?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: const Text(
          'This will restore all notification settings to their defaults.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Reset',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || _uid == null) return;

    const defaults = {
      'notif_peakHourWarnings': true,
      'notif_slabBudgetLimits': true,
      'notif_applianceScheduling': false,
      'notif_dailyUsageSummary': true,
      'notif_summaryDeliveryTime': '8:00 AM',
      'notif_alertFrequency': 'Balanced',
    };

    await _firestore.collection('users').doc(_uid).update(defaults);

    // Cancel scheduled notifications since morning tip is now off
    await NotificationService.cancelMorningTip();

    // Reschedule peak (still on by default)
    await NotificationService.scheduleTodayNotifications(
      uid: _uid!,
      appliances: _appliances,
      peakEnabled: true,
      morningEnabled: false,
    );

    setState(() {
      _peakHourWarnings = true;
      _slabBudgetLimits = true;
      _applianceScheduling = false;
      _dailyUsageSummary = true;
      _summaryDeliveryTime = '8:00 AM';
      _alertFrequency = 'Balanced';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification settings reset to defaults'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── iOS-style header ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2E20),
                            ),
                          ),
                        ),
                        // Reset button
                        TextButton.icon(
                          onPressed: _resetToDefaults,
                          icon: Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Content ───────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── PUSH NOTIFICATIONS ──────────────────────
                          _SectionHeader(label: 'PUSH NOTIFICATIONS'),
                          const SizedBox(height: 4),
                          _SectionNote(
                            note:
                                'Max 2 per day. Tap Done/Ignore on the notification.',
                          ),
                          const SizedBox(height: 10),
                          _NotifCard(
                            children: [
                              _ToggleTile(
                                title: 'Peak Hour Warning',
                                subtitle:
                                    'Reminds you at 5:00 PM to run high-wattage '
                                    'appliances before peak hours (6–10 PM)',
                                value: _peakHourWarnings,
                                onChanged: _onPeakToggle,
                              ),
                              _CardDivider(),
                              _ToggleTile(
                                title: 'Morning Appliance Tip',
                                subtitle:
                                    'Suggests running your washer, iron or EV '
                                    'charger before peak hours begin',
                                value: _applianceScheduling,
                                onChanged: _onMorningToggle,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── CRITICAL ALERTS ──────────────────────────
                          _SectionHeader(label: 'CRITICAL ALERTS'),
                          const SizedBox(height: 10),
                          _NotifCard(
                            children: [
                              _ToggleTile(
                                title: 'Slab & Budget Limits',
                                subtitle:
                                    'Warn me when approaching the next KSEB unit slab',
                                value: _slabBudgetLimits,
                                onChanged: (v) {
                                  setState(() => _slabBudgetLimits = v);
                                  _savePreference('notif_slabBudgetLimits', v);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── IN-APP PROMPTS ───────────────────────────
                          _SectionHeader(label: 'IN-APP PROMPTS'),
                          const SizedBox(height: 4),
                          _SectionNote(
                            note:
                                'These appear inside the app when you open it. '
                                'They help improve your usage accuracy.',
                          ),
                          const SizedBox(height: 10),
                          _NotifCard(
                            children: [
                              _ToggleTile(
                                title: 'Daily Usage Check',
                                subtitle:
                                    'Asks once a day whether a scheduled appliance ran as planned',
                                value: _dailyUsageSummary,
                                onChanged: (v) {
                                  setState(() => _dailyUsageSummary = v);
                                  _savePreference('notif_dailyUsageSummary', v);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── DELIVERY PREFERENCES ─────────────────────
                          _SectionHeader(label: 'DELIVERY PREFERENCES'),
                          const SizedBox(height: 10),
                          _NotifCard(
                            children: [
                              _DropdownTile(
                                title: 'Summary Time',
                                value: _summaryDeliveryTime,
                                options: _timeOptions,
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _summaryDeliveryTime = v);
                                    _savePreference(
                                      'notif_summaryDeliveryTime',
                                      v,
                                    );
                                  }
                                },
                              ),
                              _CardDivider(),
                              // Alert Frequency with tooltip
                              _DropdownTileWithTooltip(
                                title: 'Alert Frequency',
                                tooltip:
                                    'Controls how fast the app learns your habits.\n\n'
                                    '• Strict — large corrections, adapts quickly\n'
                                    '• Balanced — moderate learning (default)\n'
                                    '• Relaxed — small corrections, stays stable',
                                value: _alertFrequency,
                                options: _frequencyOptions,
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _alertFrequency = v);
                                    _savePreference('notif_alertFrequency', v);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _SectionNote extends StatelessWidget {
  final String note;
  const _SectionNote({required this.note});

  @override
  Widget build(BuildContext context) {
    return Text(
      note,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.4),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final List<Widget> children;
  const _NotifCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
        children: children,
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 16,
      endIndent: 16,
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _DropdownTile({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          _DropdownPill(value: value, options: options, onChanged: onChanged),
        ],
      ),
    );
  }
}

// Alert Frequency with tooltip help icon ───────────────────────────
class _DropdownTileWithTooltip extends StatelessWidget {
  final String title;
  final String tooltip;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _DropdownTileWithTooltip({
    required this.title,
    required this.tooltip,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: tooltip,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 5),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF212121),
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.5,
            ),
            child: Icon(
              Icons.help_outline_rounded,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ),
          const Spacer(),
          _DropdownPill(value: value, options: options, onChanged: onChanged),
        ],
      ),
    );
  }
}

// Shared pill-style dropdown ───────────────────────────────────────
class _DropdownPill extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _DropdownPill({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
