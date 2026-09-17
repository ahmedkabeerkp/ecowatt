import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'energy_service.dart';
import 'kseb_billing_service.dart';

/// Freezes each day's appliance configuration into usageLogs/{YYYY-MM-DD}.
///
/// v7 changes:
/// - backfillMissingDays(): fills in gaps for last 7 days with default accuracy
///   (only called once per session from HomeScreen.initState)
/// - Weekend weighting for occasional appliances:
///   Weekend days (Sat/Sun) use 1.5× average daily rate
///   Weekdays use 0.8× average daily rate
///   Weekly total remains identical — just redistributed realistically.
class DailySnapshotService {
  // ── Date key ───────────────────────────────────────────────────
  static String dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────────────────────
  // Core: Freeze Today's Config
  // ─────────────────────────────────────────────────────────────
  static Future<void> ensureTodaySnapshot(String uid) async {
    final today = DateTime.now();
    final todayKey = dateKey(today);

    final logRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('usageLogs')
        .doc(todayKey);

    final existing = await logRef.get();
    if (existing.exists) return;

    await _createSnapshot(uid: uid, date: today, logRef: logRef);
  }

  static Future<void> checkAndRollBillingCycle(String uid) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      final snap = await userRef.get();
      if (!snap.exists) return;

      final data = snap.data()!;

      final Timestamp? ts = data['billingStartDate'] as Timestamp?;
      if (ts == null) return; // no billing date set yet — skip

      DateTime cycleStart = ts.toDate();
      final String billingCycle =
          (data['billingCycle'] as String?) ?? '2 Month';
      final int cycleDays = billingCycle == '1 Month' ? 30 : 60;

      final DateTime today = DateTime.now();
      DateTime cycleEnd = cycleStart.add(Duration(days: cycleDays));

      // If still within the current cycle, nothing to do
      if (today.isBefore(cycleEnd)) return;

      // Roll forward until cycleStart is the most recent past start
      while (today.isAfter(cycleStart.add(Duration(days: cycleDays))) ||
          today.isAtSameMomentAs(cycleStart.add(Duration(days: cycleDays)))) {
        cycleStart = cycleStart.add(Duration(days: cycleDays));
      }

      // Persist the new cycle start — logs untouched
      await userRef.update({
        'billingStartDate': Timestamp.fromDate(cycleStart),
      });

      debugPrint('BillingCycle rolled forward → new start: $cycleStart');
    } catch (e) {
      // Non-fatal — dashboard will still work with stale date
      debugPrint('checkAndRollBillingCycle error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Backfill: Fill missing days (last 7 days only)
  // ─────────────────────────────────────────────────────────────
  /// Silently fills in any missing usageLog entries for the past 7 days.
  /// Uses default accuracy for all appliances — no prompts shown to user.
  /// Only the most recent day's notification/confirmation is shown.
  /// Older entries are calculated silently and never bother the user.
  static Future<void> backfillMissingDays(String uid) async {
    final today = DateTime.now();

    try {
      // Fetch existing keys for the past 7 days
      final startDate = today.subtract(const Duration(days: 7));
      final startKey = dateKey(startDate);
      final todayKey = dateKey(today);

      final logsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('usageLogs')
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThanOrEqualTo: todayKey)
          .get();

      final existingKeys = logsSnap.docs.map((d) => d.id).toSet();

      // Fetch current appliance schedules once (reused for all missing days)
      final schedSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('applianceSchedules')
          .get();

      if (schedSnap.docs.isEmpty) return;

      // Fill gaps — skip today (handled by ensureTodaySnapshot)
      for (int i = 1; i <= 7; i++) {
        final date = today.subtract(Duration(days: i));
        final key = dateKey(date);
        if (existingKeys.contains(key)) continue;

        final logRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('usageLogs')
            .doc(key);

        await _createSnapshotFromDocs(
          uid: uid,
          date: date,
          logRef: logRef,
          schedDocs: schedSnap.docs,
        );
      }
    } catch (e) {
      // Non-fatal — backfill failure should never crash the app
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Internal: Create snapshot for a specific date
  // ─────────────────────────────────────────────────────────────
  static Future<void> _createSnapshot({
    required String uid,
    required DateTime date,
    required DocumentReference logRef,
  }) async {
    final schedSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('applianceSchedules')
        .get();

    if (schedSnap.docs.isEmpty) return;

    await _createSnapshotFromDocs(
      uid: uid,
      date: date,
      logRef: logRef,
      schedDocs: schedSnap.docs,
    );
  }

  static Future<void> _createSnapshotFromDocs({
    required String uid,
    required DateTime date,
    required DocumentReference logRef,
    required List<QueryDocumentSnapshot> schedDocs,
  }) async {
    // Pass 1: Calculate projected monthly kWh for average unit rate
    double monthlyKwh = 0;
    for (final doc in schedDocs) {
      monthlyKwh += _calcDailyKwh(doc.data() as Map<String, dynamic>) * 30;
    }

    final double avgUnitCost = monthlyKwh > 0
        ? KSEBBillingService.calculateEnergyCharge(monthlyKwh) / monthlyKwh
        : 6.75;

    final double peakPremiumPerKwh = avgUnitCost * 0.30;

    // Pass 2: Build per-appliance snapshot with date-aware weighting
    double totalKwh = 0;
    double peakKwh = 0;
    double estimatedSavings = 0;
    final List<Map<String, dynamic>> applianceSnapshots = [];

    for (final doc in schedDocs) {
      final d = doc.data() as Map<String, dynamic>;
      // ── Weekend weighting applied here ──
      final double dailyKwh = _calcDailyKwh(d, date: date);
      final bool isPeak = d['isPeak'] as bool? ?? false;
      final String type = d['applianceType'] as String? ?? 'scheduled';

      totalKwh += dailyKwh;
      if (isPeak) peakKwh += dailyKwh;

      double dailySavings = 0;
      if (type == 'scheduled' && !isPeak) {
        dailySavings = dailyKwh * peakPremiumPerKwh;
        estimatedSavings += dailySavings;
      }

      final Map<String, dynamic> snapshot = {
        'name': d['name'] ?? '',
        'wattage': d['wattage'] ?? 0,
        'quantity': d['quantity'] ?? 1,
        'category': d['category'] ?? 'Others',
        'applianceType': type,
        'isPeak': isPeak,
        'dailyKwh': dailyKwh,
        'dailySavings': dailySavings,
      };

      if (type == 'scheduled') {
        snapshot['startTime'] = d['startTime'] ?? '';
        snapshot['endTime'] = d['endTime'] ?? '';
        snapshot['accuracyFactor'] = d['accuracyFactor'] ?? 0.7;
      } else if (type == 'occasional') {
        snapshot['weeklyFrequency'] = d['weeklyFrequency'] ?? 3.0;
        snapshot['avgDurationHours'] = d['avgDurationHours'] ?? 0.5;
      } else if (type == 'alwaysOn') {
        snapshot['dutyCycle'] = d['dutyCycle'] ?? 0.35;
      }

      applianceSnapshots.add(snapshot);
    }

    await logRef.set({
      'date': dateKey(date),
      'totalKwh': totalKwh,
      'peakKwh': peakKwh,
      'offPeakKwh': totalKwh - peakKwh,
      'estimatedSavings': estimatedSavings,
      'avgUnitCost': avgUnitCost,
      'appliances': applianceSnapshots,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Query: Cycle Savings
  // ─────────────────────────────────────────────────────────────
  static Future<double> getCycleSavings(String uid, DateTime cycleStart) async {
    final startKey = dateKey(cycleStart);
    final todayKey = dateKey(DateTime.now());

    try {
      final logsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('usageLogs')
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThanOrEqualTo: todayKey)
          .get();

      double total = 0;
      for (final doc in logsSnap.docs) {
        total += (doc.data()['estimatedSavings'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Query: Recent Logs for Chart
  // ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRecentDailyLogs(
    String uid,
    int days,
  ) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));
    final startKey = dateKey(startDate);
    final todayKey = dateKey(now);

    try {
      final logsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('usageLogs')
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThanOrEqualTo: todayKey)
          .orderBy('date')
          .get();

      return logsSnap.docs.map((d) => d.data()).toList();
    } catch (e) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Internal: Daily kWh Calculator (with weekend weighting)
  // ─────────────────────────────────────────────────────────────
  /// [date] parameter enables weekend weighting for occasional appliances.
  /// Weekend days (Sat/Sun): 1.5× multiplier
  /// Weekdays: 0.8× multiplier
  /// Weekly total is preserved: 5 × 0.8 + 2 × 1.5 = 7.0 ✓
  static double _calcDailyKwh(Map<String, dynamic> d, {DateTime? date}) {
    final wattage = (d['wattage'] as num?)?.toDouble() ?? 0;
    final quantity = (d['quantity'] as num?)?.toDouble() ?? 1;
    final type = d['applianceType'] as String? ?? 'scheduled';

    switch (type) {
      case 'alwaysOn':
        final dutyCycle = (d['dutyCycle'] as num?)?.toDouble() ?? 0.35;
        return (wattage / 1000) * dutyCycle * 24 * quantity;

      case 'occasional':
        final weeklyFreq = (d['weeklyFrequency'] as num?)?.toDouble() ?? 3.0;
        final avgDur = (d['avgDurationHours'] as num?)?.toDouble() ?? 0.5;
        // Weekend weighting (option B): heavier on weekends
        double dayMultiplier = 1.0;
        if (date != null) {
          final isWeekend =
              date.weekday == DateTime.saturday ||
              date.weekday == DateTime.sunday;
          dayMultiplier = isWeekend ? 1.5 : 0.8;
        }
        return (wattage / 1000) *
            quantity *
            avgDur *
            weeklyFreq *
            dayMultiplier /
            7.0;

      default: // scheduled
        final accuracyFactor = (d['accuracyFactor'] as num?)?.toDouble() ?? 0.7;
        final start = EnergyService.parseTime(d['startTime'] as String?);
        final end = EnergyService.parseTime(d['endTime'] as String?);
        double hours = 1.0;
        if (start != null && end != null) {
          final s = start.hour * 60 + start.minute;
          var e = end.hour * 60 + end.minute;
          if (e < s) e += 1440;
          hours = (e - s) / 60.0;
        }
        return (wattage / 1000) * quantity * hours * accuracyFactor;
    }
  }
}
