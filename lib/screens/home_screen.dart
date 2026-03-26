import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/screens/appliances_screen.dart';
import 'package:eco_watt/screens/auth_screen.dart';
import 'package:eco_watt/screens/meter_calibration_screen.dart';
import 'package:eco_watt/screens/meter_setup_screen.dart';
import 'package:eco_watt/screens/notification_screen.dart';
import 'package:eco_watt/screens/schedule_appliance_screen.dart';
import 'package:eco_watt/screens/profile_screen.dart';
import 'package:eco_watt/services/daily_snapshot_service.dart';
import 'package:eco_watt/services/energy_service.dart';
import 'package:eco_watt/services/kseb_billing_service.dart';
import 'package:eco_watt/services/notification_service.dart';
import 'package:eco_watt/services/prediction_service.dart';
import 'package:eco_watt/screens/appliance_cost_calculator_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eco_watt/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:eco_watt/screens/savings_screen.dart';
import 'package:eco_watt/screens/usage_screen.dart';

// ──────────────────────────────────────
// Data model for a recommended action
// ────────────────────────────────────
class _RecommendedAction {
  final String applianceName;
  final String suggestion;
  final double savingsRupees;
  final IconData icon;

  const _RecommendedAction({
    required this.applianceName,
    required this.suggestion,
    required this.savingsRupees,
    required this.icon,
  });
}

// ─────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const _DashboardTab(),
    const UsageTab(),
    const SavingsTab(),
    const _ProfileTab(),
  ];

  // ── NEW: Freeze today's appliance config once per session ─────
  // Safe to call multiple times — skips if today's snapshot exists.
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      DailySnapshotService.ensureTodaySnapshot(uid);
      DailySnapshotService.backfillMissingDays(uid);
      _scheduleNotifications(uid);
    }
  }

  // ── Schedule today's push notifications using current prefs + appliances ──
  Future<void> _scheduleNotifications(String uid) async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('applianceSchedules')
            .get(),
      ]);

      final userData =
          (results[0] as DocumentSnapshot).data() as Map<String, dynamic>? ??
          {};
      final schedSnap = results[1] as QuerySnapshot;
      final appliances = schedSnap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

      await NotificationService.scheduleTodayNotifications(
        uid: uid,
        appliances: appliances,
        peakEnabled: userData['notif_peakHourWarnings'] as bool? ?? true,
        morningEnabled: userData['notif_applianceScheduling'] as bool? ?? false,
      );
    } catch (e) {
      // Non-fatal
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.electric_bolt_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'EcoWatt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          // ── Profile avatar → opens ProfileScreen ─────────────
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseAuth.instance.currentUser != null
                ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .snapshots()
                : const Stream.empty(),
            builder: (context, snap) {
              final data = (snap.hasData && snap.data!.exists)
                  ? (snap.data!.data() as Map<String, dynamic>? ?? {})
                  : <String, dynamic>{};
              final name = (data['name'] as String?) ?? '';
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 26),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: const _AppDrawer(),
      body: _pages[_selectedIndex],
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Bottom Nav
// ─────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.donut_large_rounded, 'Insights'),
      (Icons.currency_rupee_rounded, 'Savings'),
      (Icons.person_rounded, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = i == selectedIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[i].$1,
                      color: isActive
                          ? AppColors.primary
                          : Colors.grey.shade400,
                      size: 26,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i].$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isActive
                            ? AppColors.primary
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// App Drawer — now includes Calibrate Meter option
// ─────────────────────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: AppColors.primary),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.electric_bolt_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'EcoWatt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _DrawerItem(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            iconColor: Colors.blue,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.electric_meter_rounded,
            label: 'Calibrate Meter',
            iconColor: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MeterCalibrationScreen(isMandatoryPopup: false),
                ),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.tune_rounded,
            label: 'Meter Settings',
            iconColor: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MeterSetupScreen(isEditMode: true),
                ),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            iconColor: Colors.blue,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.electrical_services_outlined,
            label: 'Appliances',
            iconColor: Colors.blue,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppliancesScreen()),
              );
            },
          ),
          const Spacer(),
          const Divider(),
          _DrawerItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            iconColor: Colors.red,
            onTap: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.primary),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Dashboard Tab
// ─────────────────────────────────────────────────────────────────
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  bool _isSameIsoWeek(DateTime a, DateTime b) {
    final aMonday = a.subtract(Duration(days: a.weekday - 1));
    final bMonday = b.subtract(Duration(days: b.weekday - 1));
    return aMonday.year == bMonday.year &&
        aMonday.month == bMonday.month &&
        aMonday.day == bMonday.day;
  }

  //
  late Timer _timer;
  late bool _isPeakHours;
  late bool _isPrePeak;

  // ── In-app confirmation banner state ─────────────────────────
  bool _confirmationBannerDismissed = false;

  // ── Weekly check-in state ────────────────────────────────────
  bool _weeklyCheckInDone = false;

  bool _checkPeakHours() {
    final hour = DateTime.now().hour;
    return hour >= 18 && hour < 22;
  }

  bool _checkPrePeak() {
    final hour = DateTime.now().hour;
    return hour >= 14 && hour < 18;
  }

  @override
  void initState() {
    super.initState();
    _isPeakHours = _checkPeakHours();
    _isPrePeak = _checkPrePeak();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _isPeakHours = _checkPeakHours();
          _isPrePeak = _checkPrePeak();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // ── Recommended actions ───────────────────────────────────────
  List<_RecommendedAction> _buildRecommendations(
    List<QueryDocumentSnapshot> docs,
    bool isPeak,
    bool isPrePeak,
  ) {
    final List<_RecommendedAction> actions = [];

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final bool isPeakAppliance = d['isPeak'] as bool? ?? false;
      if (!isPeakAppliance) continue;

      final String name = d['name'] as String? ?? '';
      final int wattage = (d['wattage'] as num?)?.toInt() ?? 0;
      final int quantity = (d['quantity'] as num?)?.toInt() ?? 1;

      final start = EnergyService.parseTime(d['startTime'] as String?);
      final end = EnergyService.parseTime(d['endTime'] as String?);

      double durationHours = 2.0;
      if (start != null && end != null) {
        final s = start.hour * 60 + start.minute;
        var e = end.hour * 60 + end.minute;
        if (e < s) e += 1440;
        durationHours = (e - s) / 60.0;
      }

      final units = (wattage / 1000.0) * quantity * durationHours;
      final savings = units * 6.0;

      String suggestion;
      if (isPeak) {
        suggestion = 'Delay $name after 10 PM';
      } else if (isPrePeak) {
        suggestion = 'Run $name before 6 PM';
      } else {
        suggestion = 'Schedule $name for off-peak hours';
      }

      actions.add(
        _RecommendedAction(
          applianceName: name,
          suggestion: suggestion,
          savingsRupees: savings,
          icon: _iconFor(d['icon'] as String? ?? name),
        ),
      );
    }

    actions.sort((a, b) => b.savingsRupees.compareTo(a.savingsRupees));
    return actions.take(3).toList();
  }

  static IconData _iconFor(String key) {
    switch (key) {
      case 'ac':
        return Icons.ac_unit_rounded;
      case 'fan':
        return Icons.wind_power_rounded;
      case 'cooler':
        return Icons.water_rounded;
      case 'heater':
        return Icons.local_fire_department_rounded;
      case 'waterheater':
        return Icons.water_damage_rounded;
      case 'iron':
        return Icons.iron_rounded;
      case 'fridge':
        return Icons.kitchen_rounded;
      case 'microwave':
        return Icons.microwave_rounded;
      case 'mixer':
        return Icons.blender_rounded;
      case 'kettle':
        return Icons.coffee_maker_rounded;
      case 'toaster':
        return Icons.breakfast_dining_rounded;
      case 'induction':
        return Icons.outdoor_grill_rounded;
      case 'dishwasher':
        return Icons.local_laundry_service_rounded;
      case 'bulb':
        return Icons.light_rounded;
      case 'tv':
        return Icons.tv_rounded;
      case 'computer':
        return Icons.desktop_windows_rounded;
      case 'laptop':
        return Icons.laptop_rounded;
      case 'washer':
        return Icons.local_laundry_service_rounded;
      case 'pump':
        return Icons.water_drop_rounded;
      case 'ev':
        return Icons.electric_car_rounded;
      case 'vacuum':
        return Icons.cleaning_services_rounded;
      default:
        return Icons.electrical_services_rounded;
    }
  }

  // ── Handle usage confirmation (Yes / No) ──────────────────────
  Future<void> _handleConfirmation(
    String uid,
    String applianceName,
    bool confirmed,
  ) async {
    setState(() => _confirmationBannerDismissed = true);

    await EnergyService.updateAccuracyFactor(
      uid: uid,
      applianceName: applianceName,
      userConfirmedUsage: confirmed,
    );

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'lastConfirmationDate': Timestamp.now(),
    });
  }

  // ── Handle weekly check-in submission ─────────────────────────
  Future<void> _handleWeeklyCheckIn(
    String uid,
    Map<String, Map<String, double>> answers,
  ) async {
    setState(() => _weeklyCheckInDone = true);

    final batch = FirebaseFirestore.instance.batch();

    for (final entry in answers.entries) {
      final applianceName = entry.key;
      final freq = entry.value['frequency'] ?? 3.0;
      final dur = entry.value['duration'] ?? 0.5;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('applianceSchedules')
          .doc(applianceName);

      batch.update(docRef, {'weeklyFrequency': freq, 'avgDurationHours': dur});
    }

    batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
      'lastWeeklySurveyDate': Timestamp.now(),
    });

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Not logged in'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnap) {
        final userData = (userSnap.hasData && userSnap.data!.exists)
            ? (userSnap.data!.data() as Map<String, dynamic>? ?? {})
            : <String, dynamic>{};

        final double slabLimit = () {
          final g = (userData['goal'] as num?)?.toDouble() ?? 0;
          return g > 0 ? g : 250.0;
        }();

        final String billingCycle =
            (userData['billingCycle'] as String?) ?? '2 Month';

        final DateTime cycleStart =
            (userData['billingStartDate'] as Timestamp?)?.toDate() ??
            (userData['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.now();

        // ── Confirmation banner logic ─────────────────────────────
        final DateTime? lastConfirmationDate =
            (userData['lastConfirmationDate'] as Timestamp?)?.toDate();
        final bool isConfirmationDue =
            !_confirmationBannerDismissed &&
            (userData['notif_dailyUsageSummary'] as bool? ?? true) &&
            PredictionService.isConfirmationDue(lastConfirmationDate);

        // Time-aware question: before noon = ask about yesterday,
        // afternoon/evening = ask about this morning
        final bool isAfternoon = DateTime.now().hour >= 12;

        // ── Weekly check-in: Saturday OR Sunday, once per week ────
        final DateTime? lastWeeklySurveyDate =
            (userData['lastWeeklySurveyDate'] as Timestamp?)?.toDate();
        final int weekday = DateTime.now().weekday;
        final bool isWeekend =
            weekday == DateTime.saturday || weekday == DateTime.sunday;
        final bool isWeeklyCheckInDue =
            isWeekend &&
            !_weeklyCheckInDone &&
            (lastWeeklySurveyDate == null ||
                !_isSameIsoWeek(lastWeeklySurveyDate, DateTime.now()));

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('applianceSchedules')
              .snapshots(),
          builder: (context, schedSnap) {
            final scheduleDocs = schedSnap.hasData
                ? schedSnap.data!.docs
                : <QueryDocumentSnapshot>[];

            final int householdCount =
                (userData['householdCount'] as num?)?.toInt() ?? 4;

            final double consumedUnits = EnergyService.calculateCycleUnits(
              scheduleDocs,
              cycleStart,
              billingCycle,
              householdCount: householdCount,
            );

            final double estimatedBill = KSEBBillingService.calculateTotalBill(
              consumedUnits,
            );

            final double unitsToNextSlab = PredictionService.unitsRemaining(
              consumedUnits,
            );
            final double nextSlabAt = PredictionService.nextSlab(consumedUnits);

            final double percent = (consumedUnits / slabLimit).clamp(0.0, 1.0);
            final double unitsLeft = max(0.0, slabLimit - consumedUnits);

            final bool isNearSlab = unitsToNextSlab <= 25;

            // ── Find best appliance for confirmation banner ────────
            // Pick highest-kWh scheduled (non-alwaysOn) appliance
            String? confirmationApplianceName;
            if (isConfirmationDue) {
              QueryDocumentSnapshot? best;
              double bestKwh = 0;
              for (final doc in scheduleDocs) {
                final d = doc.data() as Map<String, dynamic>;
                final type = d['applianceType'] as String? ?? 'scheduled';
                if (type != 'scheduled') continue;
                // Calculate kWh
                final w = (d['wattage'] as num?)?.toDouble() ?? 0;
                final qty = (d['quantity'] as num?)?.toDouble() ?? 1;
                final start = EnergyService.parseTime(
                  d['startTime'] as String?,
                );
                final end = EnergyService.parseTime(d['endTime'] as String?);
                double hours = 1.0;
                if (start != null && end != null) {
                  final s = start.hour * 60 + start.minute;
                  var e = end.hour * 60 + end.minute;
                  if (e < s) e += 1440;
                  hours = (e - s) / 60.0;
                }
                final kWh = (w / 1000) * qty * hours;
                if (kWh > bestKwh) {
                  bestKwh = kWh;
                  best = doc;
                }
              }
              if (best != null) {
                final d = best.data() as Map<String, dynamic>;
                confirmationApplianceName = d['name'] as String?;
              }
            }

            // ── Filter occasional appliances for weekly check-in ───
            final List<Map<String, dynamic>> occasionalAppliances = [];
            if (isWeeklyCheckInDue) {
              for (final doc in scheduleDocs) {
                final d = doc.data() as Map<String, dynamic>;
                if ((d['applianceType'] as String?) == 'occasional') {
                  occasionalAppliances.add(d);
                }
              }
            }

            final recommendations = _buildRecommendations(
              scheduleDocs,
              _isPeakHours,
              _isPrePeak,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── P2: In-app usage confirmation banner ──────────
                  if (isConfirmationDue &&
                      confirmationApplianceName != null) ...[
                    _UsageConfirmationBanner(
                      applianceName: confirmationApplianceName,
                      isAfternoon: isAfternoon,
                      onYes: () => _handleConfirmation(
                        uid,
                        confirmationApplianceName!,
                        true,
                      ),
                      onNo: () => _handleConfirmation(
                        uid,
                        confirmationApplianceName!,
                        false,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── P1: Slab predictor alert ──────────────────────
                  if (isNearSlab) ...[
                    _SlabPredictorAlert(
                      unitsToNextSlab: unitsToNextSlab.toInt(),
                      nextSlabAt: nextSlabAt.toInt(),
                      onActNow: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScheduleApplianceScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Current usage period card ─────────────────────
                  _CurrentUsagePeriodCard(
                    consumedUnits: consumedUnits,
                    slabLimit: slabLimit,
                    percent: percent,
                    unitsLeft: unitsLeft,
                    unitsToNextSlab: unitsToNextSlab,
                  ),
                  const SizedBox(height: 14),

                  // ── Estimated bill card ───────────────────────────
                  _EstimatedBillCard(
                    estimatedBill: estimatedBill,
                    consumedUnits: consumedUnits,
                    isOverSlab: consumedUnits > 250,
                  ),
                  const SizedBox(height: 20),

                  // ── Weekly check-in (Sunday) OR Recommended Actions ─
                  if (isWeeklyCheckInDue &&
                      occasionalAppliances.isNotEmpty) ...[
                    _WeeklyCheckInCard(
                      appliances: occasionalAppliances,
                      onDone: (answers) => _handleWeeklyCheckIn(uid, answers),
                    ),
                    const SizedBox(height: 20),
                  ] else if (recommendations.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.electric_bolt_rounded,
                      label: 'Recommended Actions',
                    ),
                    const SizedBox(height: 12),
                    ...recommendations.map(
                      (a) => _RecommendedActionCard(action: a),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Quick actions ─────────────────────────────────
                  const _SectionHeader(
                    icon: null,
                    label: 'QUICK ACTIONS',
                    isUpperCase: true,
                    small: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.calculate_rounded,
                          iconBg: const Color(0xFFDCF5E4),
                          iconColor: const Color(0xFF2E7D32),
                          title: 'Cost Calculator',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ApplianceCostCalculatorScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.schedule_rounded,
                          iconBg: const Color(0xFFDCEEFB),
                          iconColor: const Color(0xFF1565C0),
                          title: 'Schedule',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ScheduleApplianceScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// In-App Usage Confirmation Banner (Priority 2 — no push, in-app only)
// ─────────────────────────────────────────────────────────────────
class _UsageConfirmationBanner extends StatelessWidget {
  final String applianceName;
  final bool isAfternoon; // true = afternoon/evening, false = morning
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _UsageConfirmationBanner({
    required this.applianceName,
    required this.isAfternoon,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    // Time-aware question
    final question = isAfternoon
        ? 'Did your $applianceName run as scheduled this morning?'
        : 'Did your $applianceName run as scheduled yesterday?';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'USAGE CHECK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  question,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onYes,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Yes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onNo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'No',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Weekly Check-In Card — Swipeable, one appliance per page
// Shows on Saturday/Sunday, asks "How many times this week?"
// ─────────────────────────────────────────────────────────────────
class _WeeklyCheckInCard extends StatefulWidget {
  final List<Map<String, dynamic>> appliances;
  final void Function(Map<String, Map<String, double>> answers) onDone;

  const _WeeklyCheckInCard({required this.appliances, required this.onDone});

  @override
  State<_WeeklyCheckInCard> createState() => _WeeklyCheckInCardState();
}

class _WeeklyCheckInCardState extends State<_WeeklyCheckInCard> {
  late final PageController _pageController;
  int _currentPage = 0;
  late final Map<String, double> _selectedFreq;

  // Options: label → value used in weekly frequency
  static const List<(String, double)> _freqOptions = [
    ('1–2 times', 1.5),
    ('2–3 times', 2.5),
    ('3–4 times', 3.5),
    ('5–6 times', 5.5),
    ('Daily', 7.0),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _selectedFreq = {
      for (final a in widget.appliances)
        (a['name'] as String? ?? ''):
            (a['weeklyFrequency'] as num?)?.toDouble() ?? 3.5,
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _closestOptionIndex(double freq) {
    int best = 2;
    double minDiff = double.infinity;
    for (int i = 0; i < _freqOptions.length; i++) {
      final diff = (_freqOptions[i].$2 - freq).abs();
      if (diff < minDiff) {
        minDiff = diff;
        best = i;
      }
    }
    return best;
  }

  void _goNext() {
    if (_currentPage < widget.appliances.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Last page — submit
      final answers = <String, Map<String, double>>{
        for (final a in widget.appliances)
          (a['name'] as String? ?? ''): {
            'frequency': _selectedFreq[a['name'] as String? ?? ''] ?? 3.5,
            'duration': (a['avgDurationHours'] as num?)?.toDouble() ?? 0.5,
          },
      };
      widget.onDone(answers);
    }
  }

  void _goPrev() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.appliances.length;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B1FA2).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_view_week_rounded,
                    color: Color(0xFF7B1FA2),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WEEKLY CHECK-IN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7B1FA2),
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'How often did you use this week?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // Page indicator
                Text(
                  '${_currentPage + 1} / $totalPages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),

          // ── Swipeable Pages ─────────────────────────────────────
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: totalPages,
              itemBuilder: (context, index) {
                final a = widget.appliances[index];
                final name = a['name'] as String? ?? '';
                final selectedIdx = _closestOptionIndex(
                  _selectedFreq[name] ?? 3.5,
                );

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How many times did you use it this week?',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_freqOptions.length, (i) {
                          final isSelected = i == selectedIdx;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFreq[name] = _freqOptions[i].$2;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF7B1FA2)
                                    : const Color(0xFFF3E5F5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _freqOptions[i].$1,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF7B1FA2),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Page dots ───────────────────────────────────────────
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalPages, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentPage ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? const Color(0xFF7B1FA2)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

          // ── Navigation buttons ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goPrev,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7B1FA2),
                        side: const BorderSide(color: Color(0xFF7B1FA2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        '← Back',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B1FA2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _currentPage < totalPages - 1
                          ? 'Next →'
                          : 'Done — Update Estimates',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────
// Slab Predictor Alert
// ─────────────────────────────────────────────────────────────────
class _SlabPredictorAlert extends StatelessWidget {
  final int unitsToNextSlab;
  final int nextSlabAt;
  final VoidCallback onActNow;

  const _SlabPredictorAlert({
    required this.unitsToNextSlab,
    required this.nextSlabAt,
    required this.onActNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE53935), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SLAB PREDICTOR ALERT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE53935),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Approaching $nextSlabAt unit slab',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212121),
                  ),
                ),
                Text(
                  'Rates jump in $unitsToNextSlab more units.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF757575),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onActNow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'ACT NOW',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Current Usage Period Card
// ─────────────────────────────────────────────────────────────────
class _CurrentUsagePeriodCard extends StatelessWidget {
  final double consumedUnits;
  final double slabLimit;
  final double percent;
  final double unitsLeft;
  final double unitsToNextSlab;

  const _CurrentUsagePeriodCard({
    required this.consumedUnits,
    required this.slabLimit,
    required this.percent,
    required this.unitsLeft,
    required this.unitsToNextSlab,
  });

  Color get _barColor {
    if (percent >= 0.9) return const Color(0xFFE53935);
    if (percent >= 0.7) return const Color(0xFFF59E0B);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final percentInt = (percent * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'CURRENT USAGE PERIOD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    consumedUnits.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: _barColor,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'UNITS CONSUMED',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Container(width: 1, height: 48, color: Colors.grey.shade200),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slabLimit.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFBDBDBD),
                      height: 1,
                    ),
                  ),
                  const Text(
                    'SLAB LIMIT',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_barColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$percentInt% CONSUMED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _barColor,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${unitsLeft.toStringAsFixed(1)} UNITS LEFT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: unitsLeft <= 30
                      ? const Color(0xFFE53935)
                      : Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (unitsToNextSlab < 50) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 14,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${unitsToNextSlab.toStringAsFixed(0)} units to next tariff slab',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Estimated Bill Card
// ─────────────────────────────────────────────────────────────────
class _EstimatedBillCard extends StatelessWidget {
  final double estimatedBill;
  final double consumedUnits;
  final bool isOverSlab;

  const _EstimatedBillCard({
    required this.estimatedBill,
    required this.consumedUnits,
    required this.isOverSlab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTIMATED BILL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${estimatedBill.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: isOverSlab
                        ? const Color(0xFFE53935)
                        : AppColors.primary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOverSlab
                      ? 'Non-telescopic rates applied'
                      : 'Based on telescopic KSEB rates',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverSlab
                        ? const Color(0xFFE53935).withValues(alpha: 0.8)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (isOverSlab)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE53935).withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                '250+ slab',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE53935),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool isUpperCase;
  final bool small;

  const _SectionHeader({
    this.icon,
    required this.label,
    this.isUpperCase = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = isUpperCase ? label.toUpperCase() : label;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.primary, size: small ? 16 : 20),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: small ? 12 : 16,
            fontWeight: FontWeight.w800,
            color: small ? Colors.grey.shade600 : const Color(0xFF212121),
            letterSpacing: small ? 1.3 : 0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Recommended Action Card
// ─────────────────────────────────────────────────────────────────
class _RecommendedActionCard extends StatelessWidget {
  final _RecommendedAction action;
  const _RecommendedActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(action.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.suggestion,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action.applianceName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${action.savingsRupees.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const Text(
                'SAVING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Quick Action Card
// ─────────────────────────────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF212121),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Profile Tab
// ─────────────────────────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: uid != null
          ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
          : const Stream.empty(),
      builder: (context, snap) {
        final data = (snap.hasData && snap.data!.exists)
            ? (snap.data!.data() as Map<String, dynamic>? ?? {})
            : <String, dynamic>{};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  ((data['name'] as String?) ?? 'U')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                (data['name'] as String?) ?? '—',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                (data['email'] as String?) ?? '',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _ProfileInfoCard(data: data),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Profile Info Card
// ─────────────────────────────────────────────────────────────────
class _ProfileInfoCard extends StatelessWidget {
  final Map data;
  const _ProfileInfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final String goalDisplay = () {
      final g = (data['goal'] as num?)?.toDouble() ?? 0;
      return g > 0 ? '${g.toInt()} kWh/month' : '—';
    }();

    final rows = [
      ('Phone', (data['phone'] as String?) ?? '—'),
      ('Monthly Target', goalDisplay),
      ('House Type', (data['houseType'] as String?) ?? '—'),
      ('Tariff', (data['tariff'] as String?) ?? '—'),
      ('Purpose', (data['purpose'] as String?) ?? '—'),
      ('Billing Cycle', (data['billingCycle'] as String?) ?? '—'),
      ('Phase', (data['phase'] as String?) ?? '—'),
    ];

    return Card(
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Column(
        children: List.generate(rows.length, (i) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Text(
                      rows[i].$1,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      rows[i].$2,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < rows.length - 1)
                Divider(height: 1, color: Colors.grey.shade100),
            ],
          );
        }),
      ),
    );
  }
}
