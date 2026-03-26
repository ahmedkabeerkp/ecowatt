import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/models/appliance_item.dart';
import 'package:eco_watt/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
// Per-appliance schedule state
// Holds time data for scheduled types + frequency data for occasional
// ─────────────────────────────────────────────────────────────────
class _ApplianceSchedule {
  // For ApplianceType.scheduled
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  // For ApplianceType.occasional
  double weeklyFrequency;
  double avgDurationHours;

  _ApplianceSchedule({
    this.startTime,
    this.endTime,
    this.weeklyFrequency = 3.0,
    this.avgDurationHours = 0.5,
  });

  // Peak hours: 18:00 – 22:00
  static const int _peakStart = 18 * 60;
  static const int _peakEnd = 22 * 60;

  bool get overlapsPeak {
    if (startTime == null || endTime == null) return false;
    final start = startTime!.hour * 60 + startTime!.minute;
    final end = endTime!.hour * 60 + endTime!.minute;
    if (end >= start) {
      return start < _peakEnd && end > _peakStart;
    } else {
      // Crosses midnight
      return start < _peakEnd || end > _peakStart;
    }
  }

  bool get isComplete => startTime != null && endTime != null;
}

// ─────────────────────────────────────────────────────────────────
// Frequency & Duration option maps (for occasional appliances)
// ─────────────────────────────────────────────────────────────────
class _FreqOption {
  final String label;
  final double value;
  const _FreqOption(this.label, this.value);
}

class _DurOption {
  final String label;
  final double value;
  const _DurOption(this.label, this.value);
}

const _freqOptions = [
  _FreqOption('Never', 0.0),
  _FreqOption('1–2×/wk', 1.5),
  _FreqOption('3–5×/wk', 4.0),
  _FreqOption('Daily', 7.0),
  _FreqOption('2×/day', 14.0),
];

const _durOptions = [
  _DurOption('5 min', 0.08),
  _DurOption('15 min', 0.25),
  _DurOption('30 min', 0.5),
  _DurOption('1 hour', 1.0),
  _DurOption('2 hours', 2.0),
];

// ─────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────
class ScheduleApplianceScreen extends StatefulWidget {
  final List<ApplianceItem> selectedAppliances;
  const ScheduleApplianceScreen({
    super.key,
    this.selectedAppliances = const [],
  });

  @override
  State<ScheduleApplianceScreen> createState() =>
      _ScheduleApplianceScreenState();
}

class _ScheduleApplianceScreenState extends State<ScheduleApplianceScreen> {
  late final Map<String, _ApplianceSchedule> _schedules;
  late List<ApplianceItem> _displayAppliances;
  bool _loadingExisting = true;
  bool _isSaving = false;

  // Track which appliances already had saved data (for UI badge)
  final Set<String> _prefilledNames = {};

  @override
  void initState() {
    super.initState();
    _displayAppliances = List.from(widget.selectedAppliances);
    // Initialise schedules with per-appliance defaults
    _schedules = {
      for (final a in widget.selectedAppliances)
        a.name: _ApplianceSchedule(
          weeklyFrequency: a.defaultWeeklyUses,
          avgDurationHours: a.defaultDurationHours,
        ),
    };
    _loadExistingSchedules();
  }

  // ── Parse "07:30 PM" string back into TimeOfDay ───────────────
  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final parts = raw.trim().split(' ');
      if (parts.length != 2) return null;
      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;
      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final bool isPm = parts[1].toUpperCase() == 'PM';
      if (hour == 12) {
        hour = isPm ? 12 : 0;
      } else {
        hour = isPm ? hour + 12 : hour;
      }
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  // ── Load existing schedules from Firestore ────────────────────
  Future<void> _loadExistingSchedules() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingExisting = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('applianceSchedules')
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) setState(() => _loadingExisting = false);
        return;
      }

      if (_schedules.isEmpty) {
        // ── Quick Action / direct navigation path ─────────────
        // Rebuild everything from Firestore.
        // Use master list for type/defaults; override wattage/qty/icon from Firestore.
        final masterList = buildApplianceList();
        final newAppliances = <ApplianceItem>[];

        for (final doc in snapshot.docs) {
          final d = doc.data();
          final name = d['name'] as String? ?? doc.id;

          // Look up appliance in master catalog for correct type + defaults
          ApplianceItem? master;
          try {
            master = masterList.firstWhere((a) => a.name == name);
          } catch (_) {
            master = null;
          }

          // Determine type: prefer master catalog, fall back to Firestore, then scheduled
          final applianceType =
              master?.applianceType ??
              ApplianceType.fromString(d['applianceType'] as String?);

          final item = ApplianceItem(
            name: name,
            category: d['category'] as String? ?? '',
            icon: d['icon'] as String? ?? name,
            wattage: (d['wattage'] as num?)?.toInt() ?? 0,
            quantity: (d['quantity'] as num?)?.toInt() ?? 1,
            applianceType: applianceType,
            dutyCycle:
                master?.dutyCycle ??
                (d['dutyCycle'] as num?)?.toDouble() ??
                0.35,
            defaultWeeklyUses:
                master?.defaultWeeklyUses ??
                (d['weeklyFrequency'] as num?)?.toDouble() ??
                3.0,
            defaultDurationHours:
                master?.defaultDurationHours ??
                (d['avgDurationHours'] as num?)?.toDouble() ??
                0.5,
          );

          newAppliances.add(item);

          _schedules[name] = _ApplianceSchedule(
            // Only restore times for scheduled type
            startTime: applianceType == ApplianceType.scheduled
                ? _parseTime(d['startTime'] as String?)
                : null,
            endTime: applianceType == ApplianceType.scheduled
                ? _parseTime(d['endTime'] as String?)
                : null,
            // Restore saved frequency/duration (or fall back to model defaults)
            weeklyFrequency:
                (d['weeklyFrequency'] as num?)?.toDouble() ??
                item.defaultWeeklyUses,
            avgDurationHours:
                (d['avgDurationHours'] as num?)?.toDouble() ??
                item.defaultDurationHours,
          );

          _prefilledNames.add(name);
        }

        if (mounted) {
          setState(() {
            _displayAppliances = newAppliances;
            _loadingExisting = false;
          });
        }
        return;
      }

      // ── Normal flow: selectedAppliances were passed ───────────
      // Fill in saved times / frequencies only
      for (final doc in snapshot.docs) {
        final d = doc.data();
        final name = d['name'] as String?;
        if (name == null || !_schedules.containsKey(name)) continue;

        // Find the ApplianceItem to know its type
        ApplianceItem? appItem;
        try {
          appItem = _displayAppliances.firstWhere((a) => a.name == name);
        } catch (_) {
          appItem = null;
        }
        final type = appItem?.applianceType ?? ApplianceType.scheduled;

        if (type == ApplianceType.scheduled) {
          _schedules[name]!.startTime = _parseTime(d['startTime'] as String?);
          _schedules[name]!.endTime = _parseTime(d['endTime'] as String?);
        }

        // Always restore frequency/duration if present (for occasional, and as future data)
        final savedFreq = (d['weeklyFrequency'] as num?)?.toDouble();
        final savedDur = (d['avgDurationHours'] as num?)?.toDouble();
        if (savedFreq != null) _schedules[name]!.weeklyFrequency = savedFreq;
        if (savedDur != null) _schedules[name]!.avgDurationHours = savedDur;

        // Mark as pre-filled (doc existed in Firestore regardless of type)
        _prefilledNames.add(name);
      }

      if (mounted) setState(() => _loadingExisting = false);
    } catch (e) {
      debugPrint('Error loading schedules: $e');
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  // ── Validation: all appliances must be "configured" ──────────
  // alwaysOn → always valid
  // occasional → always valid (has defaults)
  // scheduled → must have start + end time
  bool get _allScheduled => _displayAppliances.every((a) {
    switch (a.applianceType) {
      case ApplianceType.alwaysOn:
      case ApplianceType.occasional:
        return true;
      case ApplianceType.scheduled:
        return _schedules[a.name]?.isComplete == true;
    }
  });

  // Format TimeOfDay → "07:30 PM"
  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Future<void> _pickTime(
    BuildContext context,
    String applianceName,
    bool isStart,
  ) async {
    final sched = _schedules[applianceName]!;
    final initial = isStart
        ? (sched.startTime ?? const TimeOfDay(hour: 8, minute: 0))
        : (sched.endTime ?? const TimeOfDay(hour: 10, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
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

    if (picked != null) {
      setState(() {
        if (isStart) {
          sched.startTime = picked;
        } else {
          sched.endTime = picked;
        }
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (!_allScheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set start and end time for every appliance.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final appliance in _displayAppliances) {
        final sched = _schedules[appliance.name]!;
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('applianceSchedules')
            .doc(appliance.name);

        final baseFields = {
          'name': appliance.name,
          'wattage': appliance.wattage,
          'quantity': appliance.quantity,
          'category': appliance.category,
          'icon': appliance.icon,
          'applianceType': appliance.applianceType.firestoreValue,
        };

        switch (appliance.applianceType) {
          case ApplianceType.alwaysOn:
            batch.set(docRef, {
              ...baseFields,
              'dutyCycle': appliance.dutyCycle,
              'isPeak': false,
            });

          case ApplianceType.occasional:
            batch.set(docRef, {
              ...baseFields,
              'weeklyFrequency': sched.weeklyFrequency,
              'avgDurationHours': sched.avgDurationHours,
              'isPeak': false,
            });

          case ApplianceType.scheduled:
            batch.set(docRef, {
              ...baseFields,
              'startTime': _formatTime(sched.startTime!),
              'endTime': _formatTime(sched.endTime!),
              'isPeak': sched.overlapsPeak,
              'accuracyFactor':
                  0.7, // initial confidence — improves via confirmations
            });
        }
      }

      batch.update(
        FirebaseFirestore.instance.collection('users').doc(user.uid),
        {'appliancesSetupCompleted': true},
      );

      await batch.commit();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
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
    if (_loadingExisting) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4F3),
        appBar: _buildAppBar(),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final newCount = _displayAppliances
        .where((a) => !_prefilledNames.contains(a.name))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          if (_prefilledNames.isNotEmpty && newCount > 0)
            _EditModeBanner(newCount: newCount),
          if (_prefilledNames.isNotEmpty && newCount > 0)
            const SizedBox(height: 12),

          ..._displayAppliances.map(
            (a) => _ScheduleCard(
              appliance: a,
              schedule: _schedules[a.name]!,
              isNew: !_prefilledNames.contains(a.name),
              formatTime: _formatTime,
              onPickTime: (isStart) => _pickTime(context, a.name, isStart),
              onFrequencyChanged: (freq) {
                setState(() => _schedules[a.name]!.weeklyFrequency = freq);
              },
              onDurationChanged: (dur) {
                setState(() => _schedules[a.name]!.avgDurationHours = dur);
              },
            ),
          ),
          const SizedBox(height: 8),
          _OptimizationTip(),
        ],
      ),
      bottomSheet: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSchedule,
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
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save Schedule',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Schedule',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            'Set typical usage times',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Edit Mode Info Banner
// ─────────────────────────────────────────────────────────────────
class _EditModeBanner extends StatelessWidget {
  final int newCount;
  const _EditModeBanner({required this.newCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$newCount new appliance${newCount > 1 ? 's' : ''} added — '
              'please set ${newCount > 1 ? 'their' : 'its'} schedule below.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Schedule Card — renders differently based on ApplianceType
// ─────────────────────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final ApplianceItem appliance;
  final _ApplianceSchedule schedule;
  final bool isNew;
  final String Function(TimeOfDay) formatTime;
  final void Function(bool isStart) onPickTime;
  final void Function(double frequency) onFrequencyChanged;
  final void Function(double duration) onDurationChanged;

  const _ScheduleCard({
    required this.appliance,
    required this.schedule,
    required this.isNew,
    required this.formatTime,
    required this.onPickTime,
    required this.onFrequencyChanged,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final showPeakWarning =
        appliance.applianceType == ApplianceType.scheduled &&
        schedule.overlapsPeak;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isNew
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
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
          // ── Header row ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _iconBgColor(appliance.applianceType),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _iconFor(appliance.icon),
                    color: _iconColor(appliance.applianceType),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appliance.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${appliance.wattage}W · qty ${appliance.quantity}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TypeBadge(type: appliance.applianceType),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Peak overlap warning (scheduled only) ─────────────
          if (showPeakWarning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFFF8E1),
              child: Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'OVERLAPS WITH PEAK HOURS (6 PM – 10 PM)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Bottom content: type-specific ─────────────────────
          switch (appliance.applianceType) {
            ApplianceType.alwaysOn => _AlwaysOnSection(
              wattage: appliance.wattage,
              dutyCycle: appliance.dutyCycle,
              quantity: appliance.quantity,
            ),
            ApplianceType.occasional => _OccasionalSection(
              schedule: schedule,
              onFrequencyChanged: onFrequencyChanged,
              onDurationChanged: onDurationChanged,
            ),
            ApplianceType.scheduled => _ScheduledSection(
              schedule: schedule,
              formatTime: formatTime,
              onPickTime: onPickTime,
            ),
          },
        ],
      ),
    );
  }

  Color _iconBgColor(ApplianceType type) {
    switch (type) {
      case ApplianceType.alwaysOn:
        return const Color(0xFFFFF3E0);
      case ApplianceType.occasional:
        return const Color(0xFFF3E5F5);
      case ApplianceType.scheduled:
        return AppColors.primary.withValues(alpha: 0.10);
    }
  }

  Color _iconColor(ApplianceType type) {
    switch (type) {
      case ApplianceType.alwaysOn:
        return const Color(0xFFF57C00);
      case ApplianceType.occasional:
        return const Color(0xFF7B1FA2);
      case ApplianceType.scheduled:
        return AppColors.primary;
    }
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
}

// ─────────────────────────────────────────────────────────────────
// Type Badge — small colored pill shown next to wattage info
// ─────────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final ApplianceType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    if (type == ApplianceType.scheduled) return const SizedBox.shrink();

    final Color bg;
    final Color fg;
    final IconData icon;

    if (type == ApplianceType.alwaysOn) {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFF57C00);
      icon = Icons.all_inclusive_rounded;
    } else {
      bg = const Color(0xFFF3E5F5);
      fg = const Color(0xFF7B1FA2);
      icon = Icons.repeat_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            type.displayLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Always-On Section — auto-calculated info, no input needed
// ─────────────────────────────────────────────────────────────────
class _AlwaysOnSection extends StatelessWidget {
  final int wattage;
  final double dutyCycle;
  final int quantity;

  const _AlwaysOnSection({
    required this.wattage,
    required this.dutyCycle,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    final dailyUnits = (wattage / 1000) * dutyCycle * 24 * quantity;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.all_inclusive_rounded,
            color: Color(0xFFF57C00),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AUTO-CALCULATED · RUNS 24/7',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF57C00),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Estimated ${dailyUnits.toStringAsFixed(2)} units/day — no schedule needed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
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
}

// ─────────────────────────────────────────────────────────────────
// Occasional Section — weekly frequency + avg duration selectors
// ─────────────────────────────────────────────────────────────────
class _OccasionalSection extends StatelessWidget {
  final _ApplianceSchedule schedule;
  final void Function(double) onFrequencyChanged;
  final void Function(double) onDurationChanged;

  const _OccasionalSection({
    required this.schedule,
    required this.onFrequencyChanged,
    required this.onDurationChanged,
  });

  /// Find the closest option index for a given value
  int _closestFreqIndex() {
    int closest = 1;
    double minDiff = double.infinity;
    for (int i = 0; i < _freqOptions.length; i++) {
      final diff = (_freqOptions[i].value - schedule.weeklyFrequency).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = i;
      }
    }
    return closest;
  }

  int _closestDurIndex() {
    int closest = 2;
    double minDiff = double.infinity;
    for (int i = 0; i < _durOptions.length; i++) {
      final diff = (_durOptions[i].value - schedule.avgDurationHours).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = i;
      }
    }
    return closest;
  }

  @override
  Widget build(BuildContext context) {
    final selFreq = _closestFreqIndex();
    final selDur = _closestDurIndex();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Frequency ──────────────────────────────────────────
          Text(
            'HOW OFTEN DO YOU USE THIS?',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_freqOptions.length, (i) {
              final opt = _freqOptions[i];
              final selected = i == selFreq;
              return GestureDetector(
                onTap: () => onFrequencyChanged(opt.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF7B1FA2)
                        : const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF7B1FA2),
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 14),

          // ── Duration ───────────────────────────────────────────
          Text(
            'HOW LONG PER USE?',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_durOptions.length, (i) {
              final opt = _durOptions[i];
              final selected = i == selDur;
              return GestureDetector(
                onTap: () => onDurationChanged(opt.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF7B1FA2)
                        : const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF7B1FA2),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Scheduled Section — start/end time pickers (unchanged logic)
// ─────────────────────────────────────────────────────────────────
class _ScheduledSection extends StatelessWidget {
  final _ApplianceSchedule schedule;
  final String Function(TimeOfDay) formatTime;
  final void Function(bool isStart) onPickTime;

  const _ScheduledSection({
    required this.schedule,
    required this.formatTime,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _TimePicker(
              label: 'START TIME',
              time: schedule.startTime != null
                  ? formatTime(schedule.startTime!)
                  : null,
              onTap: () => onPickTime(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TimePicker(
              label: 'END TIME',
              time: schedule.endTime != null
                  ? formatTime(schedule.endTime!)
                  : null,
              onTap: () => onPickTime(false),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Time Picker Field
// ─────────────────────────────────────────────────────────────────
class _TimePicker extends StatelessWidget {
  final String label;
  final String? time;
  final VoidCallback onTap;

  const _TimePicker({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade400,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: time != null
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time ?? '--:-- --',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: time != null ? Colors.black87 : Colors.grey.shade400,
                  ),
                ),
                Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: time != null
                      ? AppColors.primary
                      : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Optimization Tip Card
// ─────────────────────────────────────────────────────────────────
class _OptimizationTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Optimization Tip',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scheduling heavy appliances between 11 PM and 6 AM could save you up to 30% on your monthly bill.',
                  style: TextStyle(
                    fontSize: 12,
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
