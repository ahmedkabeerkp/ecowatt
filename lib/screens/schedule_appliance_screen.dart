//Time slot _______________________
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/models/appliance_item.dart';
import 'package:eco_watt/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eco_watt/screens/appliances_screen.dart' show AppProgressBar;

class TimeSlot {
  final String label;
  final String timeRange;
  final bool isPeak;

  const TimeSlot({
    required this.label,
    required this.timeRange,
    this.isPeak = false,
  });
}

const List<TimeSlot> kTimeSlots = [
  TimeSlot(label: 'Morning', timeRange: '6am - 10am'),
  TimeSlot(label: 'Afternoon', timeRange: '10am - 4pm'),
  TimeSlot(label: 'Evening', timeRange: '4pm - 6pm'),
  TimeSlot(label: 'Night', timeRange: '6pm - 10pm', isPeak: true),
  TimeSlot(label: 'Late Night', timeRange: '10pm+'),
];

const List<String> kDurations = [
  '15 min',
  '30 mins',
  '1 hr',
  '1.5 hr',
  '2 hrs',
  '3 hrs',
  '4 hrs',
  'All day',
];

class _ApplianceSchedule {
  String? selectedSlot;
  String duration;

  _ApplianceSchedule({this.selectedSlot, this.duration = '1 hr'});
}

class ScheduleApplianceScreen extends StatefulWidget {
  final List<ApplianceItem> selectedAppliances;
  const ScheduleApplianceScreen({super.key, required this.selectedAppliances});

  @override
  State<ScheduleApplianceScreen> createState() =>
      _ScheduleApplianceScreenState();
}

class _ScheduleApplianceScreenState extends State<ScheduleApplianceScreen> {
  late final Map<String, _ApplianceSchedule> _schedules;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _schedules = {
      for (final a in widget.selectedAppliances) a.name: _ApplianceSchedule(),
    };
  }

  bool get _allScheduled =>
      _schedules.values.every((s) => s.selectedSlot != null);
  Future<void> _completeSetup() async {
    if (!_allScheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot for every appliance.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final appliance in widget.selectedAppliances) {
        final sched = _schedules[appliance.name]!;
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('applianceSchedules')
            .doc(appliance.name);

        batch.set(docRef, {
          'name': appliance.name,
          'wattage': appliance.wattage,
          'quantity': appliance.quantity,
          'category': appliance.category,
          'slot': sched.selectedSlot,
          'duration': sched.duration,
          'isPeak': kTimeSlots
              .firstWhere((t) => t.label == sched.selectedSlot)
              .isPeak,
        });
      }

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      batch.update(userRef, {'appliancesSetupCompleted': true});

      await batch.commit();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
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
    // } catch (e, stackTrace) {
    //   print('ERROR: $e');
    //   print('STACK: $stackTrace');
    //   if (!mounted) return;
    //   setState(() => _isLoading = false);
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text('Error: ${e.toString()}'),
    //       backgroundColor: Colors.red,
    //     ),
    //   );
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
        ),
        title: const Text(
          'Schedule Appliances',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          AppProgressBar(step: 2),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _PeakWarningBanner(),
                const SizedBox(height: 16),

                ...widget.selectedAppliances.map(
                  (a) => _ScheduleCard(
                    appliance: a,
                    schedule: _schedules[a.name]!,
                    onSlotChanged: (slot) =>
                        setState(() => _schedules[a.name]!.selectedSlot = slot),
                    onDurationChanged: (dur) =>
                        setState(() => _schedules[a.name]!.duration = dur),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _completeSetup,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded, color: Colors.white),
            label: const Text(
              'Complete Setup',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

//Peak hours warning____________________________________________
class _PeakWarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFF59e0b), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peak Hours Warning',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF92400E),
                  ),
                ),

                SizedBox(height: 3),
                Text(
                  'Peak slots (6pm - 10pm) indicate 3x pricing. Schedule wisely.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
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

//Schedule Card_________________________________________________
class _ScheduleCard extends StatelessWidget {
  final ApplianceItem appliance;
  final _ApplianceSchedule schedule;

  final ValueChanged<String> onSlotChanged;
  final ValueChanged<String> onDurationChanged;

  const _ScheduleCard({
    required this.appliance,
    required this.schedule,
    required this.onSlotChanged,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(appliance.icon),
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appliance.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Text(
                          'Duration: ',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        DropdownButton<String>(
                          value: schedule.duration,
                          isDense: true,
                          underline: const SizedBox(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          items: kDurations
                              .map(
                                (d) =>
                                    DropdownMenuItem(value: d, child: Text(d)),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) onDurationChanged(v);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${appliance.quantity}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kTimeSlots.map((slot) {
              final isSelected = schedule.selectedSlot == slot.label;
              final isPeak = slot.isPeak;

              Color bgColor;
              Color borderColor;
              Color textColor;

              if (isSelected && isPeak) {
                bgColor = const Color(0xFFF59E0b);
                borderColor = const Color(0xFFF59E0B);
                textColor = Colors.white;
              } else if (isSelected) {
                bgColor = AppColors.primary;
                borderColor = AppColors.primary;
                textColor = Colors.white;
              } else if (isPeak) {
                bgColor = Colors.white;
                borderColor = const Color(0xFFF59E0B);
                textColor = const Color(0xFFF59E0B);
              } else {
                bgColor = const Color(0xFFF5F5F5);
                borderColor = Colors.grey.shade300;
                textColor = Colors.grey.shade700;
              }

              return GestureDetector(
                onTap: () => onSlotChanged(slot.label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        slot.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        slot.timeRange,
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          if (schedule.selectedSlot == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Please select a time slot',
                style: TextStyle(fontSize: 11, color: Colors.red.shade400),
              ),
            ),
        ],
      ),
    );
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
