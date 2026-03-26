import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

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
  String _alertFrequency = 'Normal';

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

  final List<String> _frequencyOptions = ['Low', 'Normal', 'High'];

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
      // Load preferences and appliances in parallel
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
        setState(() {
          _peakHourWarnings = data['notif_peakHourWarnings'] ?? true;
          _slabBudgetLimits = data['notif_slabBudgetLimits'] ?? true;
          _applianceScheduling = data['notif_applianceScheduling'] ?? false;
          _dailyUsageSummary = data['notif_dailyUsageSummary'] ?? true;
          _summaryDeliveryTime = data['notif_summaryDeliveryTime'] ?? '8:00 AM';
          _alertFrequency = data['notif_alertFrequency'] ?? 'Normal';
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
      // Schedule peak reminder with current appliances
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
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F3),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: _goHome,
          ),
          title: const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── PUSH NOTIFICATIONS ───────────────────────────────
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
                              'charger at 7:00 AM before peak hours',
                          value: _applianceScheduling,
                          onChanged: _onMorningToggle,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── CRITICAL ALERTS ──────────────────────────────────
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
                            // Slab alerts fire from app logic — no schedule needed
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── IN-APP PROMPTS ───────────────────────────────────
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

                    // ── DELIVERY PREFERENCES ─────────────────────────────
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
                              _savePreference('notif_summaryDeliveryTime', v);
                            }
                          },
                        ),
                        _CardDivider(),
                        _DropdownTile(
                          title: 'Alert Frequency',
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
    );
  }
}

// ─────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────

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
          Container(
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
          ),
        ],
      ),
    );
  }
}
