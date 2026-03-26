import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/appliance_item.dart';

class EnergyService {
  // ─────────────────────────────────────────────────────────────
  // Household Multiplier
  // ─────────────────────────────────────────────────────────────

  /// Converts household count into a usage multiplier.
  ///
  /// Baseline = 4 people → multiplier = 1.0
  /// Formula: 0.6 + (count / 10.0)
  ///
  /// Examples:
  ///   1 person  → 0.70  (low usage)
  ///   4 people  → 1.00  (baseline)
  ///   8 people  → 1.40  (above average)
  ///   15 people → 2.10  (high usage)
  ///
  /// Applied to scheduled + occasional appliances only.
  /// alwaysOn (e.g. fridge) is unaffected — it runs regardless of people.
  static double householdMultiplier(int householdCount) {
    return (0.6 + (householdCount / 10.0)).clamp(0.6, 2.2);
  }

  // ─────────────────────────────────────────────────────────────
  // Time Parsing
  // ─────────────────────────────────────────────────────────────

  /// Parses "07:30 PM" → TimeOfDay. Returns null on invalid input.
  static TimeOfDay? parseTime(String? raw) {
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

  // ─────────────────────────────────────────────────────────────
  // Cycle-Level Consumption (used by HomeScreen dashboard)
  // ─────────────────────────────────────────────────────────────

  /// Calculates total units consumed since [cycleStart] using the hybrid model.
  ///
  /// Three estimation paths:
  /// • [ApplianceType.alwaysOn]  — watts × dutyCycle × 24h × daysElapsed
  ///   (household count does NOT affect this — fridge runs regardless)
  /// • [ApplianceType.occasional] — watts × qty × avgDurationHours × weeklyFreq × weeksElapsed
  ///   (scaled by householdMultiplier)
  /// • [ApplianceType.scheduled]  — watts × qty × scheduledHours × accuracyFactor × daysElapsed
  ///   (scaled by householdMultiplier)
  ///
  /// [householdCount] defaults to 4 (baseline, multiplier = 1.0).
  static double calculateCycleUnits(
    List<QueryDocumentSnapshot> docs,
    DateTime cycleStart,
    String billingCycle, {
    int householdCount = 4,
  }) {
    final int cycleDays = billingCycle == '1 Month' ? 30 : 60;
    final int daysElapsed = DateTime.now()
        .difference(cycleStart)
        .inDays
        .clamp(0, cycleDays);

    final double hMultiplier = householdMultiplier(householdCount);
    double total = 0;

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;

      final wattage = (d['wattage'] as num?)?.toDouble() ?? 0;
      final quantity = (d['quantity'] as num?)?.toDouble() ?? 1;
      final type = ApplianceType.fromString(d['applianceType'] as String?);

      switch (type) {
        case ApplianceType.alwaysOn:
          // Runs 24/7 — not affected by household count
          final dutyCycle = (d['dutyCycle'] as num?)?.toDouble() ?? 0.35;
          final dailyUnits = (wattage / 1000) * dutyCycle * 24 * quantity;
          total += dailyUnits * daysElapsed;

        case ApplianceType.occasional:
          // Usage scales with number of people using the appliance
          final weeklyFrequency =
              (d['weeklyFrequency'] as num?)?.toDouble() ?? 3.0;
          final avgDurationHours =
              (d['avgDurationHours'] as num?)?.toDouble() ?? 0.5;
          if (weeklyFrequency > 0) {
            final weeksElapsed = daysElapsed / 7.0;
            final units =
                (wattage / 1000) *
                quantity *
                avgDurationHours *
                weeklyFrequency *
                weeksElapsed *
                hMultiplier;
            total += units;
          }

        case ApplianceType.scheduled:
          // More people = longer actual usage within the schedule window
          final accuracyFactor =
              (d['accuracyFactor'] as num?)?.toDouble() ?? 0.7;
          final start = parseTime(d['startTime'] as String?);
          final end = parseTime(d['endTime'] as String?);
          double hours = 1.0;
          if (start != null && end != null) {
            final s = start.hour * 60 + start.minute;
            var e = end.hour * 60 + end.minute;
            if (e < s) e += 1440;
            hours = (e - s) / 60;
          }
          final dailyUnits =
              (wattage / 1000) *
              quantity *
              hours *
              accuracyFactor *
              hMultiplier;
          total += dailyUnits * daysElapsed;
      }
    }

    return total;
  }

  // ─────────────────────────────────────────────────────────────
  // Daily Breakdown (used by UsageTab insights)
  // ─────────────────────────────────────────────────────────────

  /// Returns each appliance's average daily unit consumption.
  /// Key = appliance name, Value = daily kWh estimate.
  ///
  /// [householdCount] defaults to 4 (baseline, multiplier = 1.0).
  static Map<String, double> calculateDailyBreakdown(
    List<QueryDocumentSnapshot> docs, {
    int householdCount = 4,
  }) {
    final Map<String, double> breakdown = {};
    final double hMultiplier = householdMultiplier(householdCount);

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;

      final name = d['name'] as String? ?? doc.id;
      final wattage = (d['wattage'] as num?)?.toDouble() ?? 0;
      final quantity = (d['quantity'] as num?)?.toDouble() ?? 1;
      final type = ApplianceType.fromString(d['applianceType'] as String?);

      double dailyUnits = 0;

      switch (type) {
        case ApplianceType.alwaysOn:
          // Not affected by household count
          final dutyCycle = (d['dutyCycle'] as num?)?.toDouble() ?? 0.35;
          dailyUnits = (wattage / 1000) * dutyCycle * 24 * quantity;

        case ApplianceType.occasional:
          final weeklyFrequency =
              (d['weeklyFrequency'] as num?)?.toDouble() ?? 3.0;
          final avgDurationHours =
              (d['avgDurationHours'] as num?)?.toDouble() ?? 0.5;
          dailyUnits = weeklyFrequency > 0
              ? (wattage / 1000) *
                    quantity *
                    avgDurationHours *
                    weeklyFrequency /
                    7.0 *
                    hMultiplier
              : 0;

        case ApplianceType.scheduled:
          final accuracyFactor =
              (d['accuracyFactor'] as num?)?.toDouble() ?? 0.7;
          final start = parseTime(d['startTime'] as String?);
          final end = parseTime(d['endTime'] as String?);
          double hours = 1.0;
          if (start != null && end != null) {
            final s = start.hour * 60 + start.minute;
            var e = end.hour * 60 + end.minute;
            if (e < s) e += 1440;
            hours = (e - s) / 60;
          }
          dailyUnits =
              (wattage / 1000) *
              quantity *
              hours *
              accuracyFactor *
              hMultiplier;
      }

      breakdown[name] = dailyUnits;
    }

    return breakdown;
  }

  // ─────────────────────────────────────────────────────────────
  // Accuracy Factor Update (called after in-app usage confirmation)
  // ─────────────────────────────────────────────────────────────

  /// Nudges the accuracy factor for a scheduled appliance up or down
  /// based on whether the user confirmed actual usage.
  ///
  /// The step size is controlled by the user's chosen alert frequency
  /// (Tracking Mode) stored as 'notif_alertFrequency' in the user doc:
  ///
  ///   Strict   → ±0.15  (aggressive learning, converges quickly)
  ///   Balanced → ±0.10  (moderate — default)
  ///   Relaxed  → ±0.05  (slow learning, estimates stay stable)
  ///
  /// Confirmed → accuracy rises (max 1.0)
  /// Denied    → accuracy falls (min 0.3)
  static Future<void> updateAccuracyFactor({
    required String uid,
    required String applianceName,
    required bool userConfirmedUsage,
  }) async {
    try {
      // Fetch user's tracking mode preference
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final alertFreq =
          (userSnap.data()?['notif_alertFrequency'] as String?) ?? 'Balanced';
      final double delta = _accuracyDelta(alertFreq);

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('applianceSchedules')
          .doc(applianceName);

      final doc = await docRef.get();
      if (!doc.exists) return;

      final current =
          (doc.data()?['accuracyFactor'] as num?)?.toDouble() ?? 0.7;

      final updated = userConfirmedUsage
          ? (current + delta).clamp(0.5, 1.0)
          : (current - delta).clamp(0.3, 0.8);

      await docRef.update({'accuracyFactor': updated});
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // Alert frequency → accuracyFactor delta
  // ─────────────────────────────────────────────────────────────
  //
  // Shared logic — mirrors NotificationService._accuracyDelta.
  // Used here for in-app Yes/No confirmation banner.
  // Used in notification_service.dart for morning Done action.
  //
  // Strict   → 0.15 → estimates converge to reality after ~5 confirmations
  // Balanced → 0.10 → ~10 confirmations (default)
  // Relaxed  → 0.05 → ~20 confirmations (stable, slow)
  static double _accuracyDelta(String alertFrequency) {
    switch (alertFrequency) {
      case 'Strict':
        return 0.15;
      case 'Relaxed':
        return 0.05;
      default: // 'Balanced'
        return 0.10;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Weekly Frequency Update (called after weekly survey)
  // ─────────────────────────────────────────────────────────────

  /// Updates the weekly frequency for an occasional appliance
  /// after user fills in the weekly usage survey.
  static Future<void> updateWeeklyFrequency({
    required String uid,
    required String applianceName,
    required double confirmedWeeklyUses,
    required double confirmedDurationHours,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('applianceSchedules')
          .doc(applianceName)
          .update({
            'weeklyFrequency': confirmedWeeklyUses,
            'avgDurationHours': confirmedDurationHours,
          });
    } catch (_) {}
  }
}
