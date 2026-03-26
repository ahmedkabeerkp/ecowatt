import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../firebase_options.dart';

// ── Top-level background handler (must NOT be inside any class) ──────────────
// Called when user taps Done/Ignore on a notification while app is closed.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationAction(
  NotificationResponse notificationResponse,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.handleNotificationAction(notificationResponse);
}
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'ecowatt_alerts';
  static const String _channelName = 'EcoWatt Alerts';

  // Notification IDs
  static const int _peakReminderId = 1001;
  static const int _slabAlertId = 1002;
  static const int _morningTipId = 1003;

  // Appliances excluded from Type 2 morning tip only
  static const Set<String> _morningExclusions = {
    'ac',
    'air conditioner',
    'aircon',
    'split ac',
    'microwave',
    'microwave oven',
    'geyser',
    'water heater',
    'tv',
    'television',
    'fridge',
    'refrigerator',
    'laptop',
    'computer',
    'desktop',
  };

  // Appliances that get a special "use gas stove" message in peak reminder
  static const Set<String> _gasSuggestions = {
    'induction',
    'induction stove',
    'induction cooker',
    'induction hob',
    'microwave',
    'microwave oven',
    'water heater',
    'geyser',
  };

  // ── Initialize ──────────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (r) => handleNotificationAction(r),
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationAction,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'EcoWatt energy alerts and peak-hour reminders',
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // ── Request Permissions ─────────────────────────────────────────────────────
  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ── Handle Done / Ignore action ─────────────────────────────────────────────
  // Called both from foreground (onDidReceiveNotificationResponse)
  // and background (onBackgroundNotificationAction top-level function)
  static Future<void> handleNotificationAction(
    NotificationResponse response,
  ) async {
    final payload = response.payload;
    final actionId = response.actionId; // 'done' or 'ignore' or null (tap)
    if (payload == null) return;

    try {
      // Payload format: "type:applianceName:uid:dateKey"
      final parts = payload.split(':');
      if (parts.length < 4) return;

      final type = parts[0]; // 'peak' or 'morning'
      final applianceName = parts[1];
      final uid = parts[2];
      final dateKey = parts[3];

      // Only act on 'done'; 'ignore' just dismisses
      if (actionId == 'done' || actionId == null) {
        await _processDone(
          type: type,
          applianceName: applianceName,
          uid: uid,
          dateKey: dateKey,
        );
      }
    } catch (e) {
      debugPrint('NotificationService.handleNotificationAction error: $e');
    }
  }

  static Future<void> _processDone({
    required String type,
    required String applianceName,
    required String uid,
    required String dateKey,
  }) async {
    try {
      final logRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('usageLogs')
          .doc(dateKey);

      final logSnap = await logRef.get();
      if (!logSnap.exists) return;

      final data = logSnap.data()!;

      if (type == 'peak') {
        // User shifted appliance to off-peak → add savings to today's log
        final appliances = List<Map<String, dynamic>>.from(
          (data['appliances'] as List? ?? []).map(
            (a) => Map<String, dynamic>.from(a as Map),
          ),
        );

        for (final a in appliances) {
          if ((a['name'] as String?) == applianceName &&
              (a['isPeak'] as bool? ?? false)) {
            a['isPeak'] = false;
            a['shiftedToOffPeak'] = true;
            final dailyKwh = (a['dailyKwh'] as num?)?.toDouble() ?? 0;
            final avgUnitCost =
                (data['avgUnitCost'] as num?)?.toDouble() ?? 6.75;
            final peakPremium = avgUnitCost * 0.30;
            a['dailySavings'] = dailyKwh * peakPremium;
          }
        }

        // Recalculate totals
        double totalSavings = 0;
        double totalPeakKwh = 0;
        double totalKwh = 0;
        for (final a in appliances) {
          final kWh = (a['dailyKwh'] as num?)?.toDouble() ?? 0;
          totalKwh += kWh;
          if (a['isPeak'] as bool? ?? false) totalPeakKwh += kWh;
          totalSavings += (a['dailySavings'] as num?)?.toDouble() ?? 0;
        }

        await logRef.update({
          'appliances': appliances,
          'estimatedSavings': totalSavings,
          'peakKwh': totalPeakKwh,
          'offPeakKwh': totalKwh - totalPeakKwh,
        });
      } else if (type == 'morning') {
        // User confirmed they ran the appliance → boost accuracy factor.
        // Delta is scaled by the user's chosen alert frequency (tracking mode).
        final appRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('applianceSchedules')
            .doc(applianceName);

        // Fetch alert frequency from user doc
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final alertFreq =
            (userSnap.data()?['notif_alertFrequency'] as String?) ?? 'Balanced';
        final double delta = _accuracyDelta(alertFreq);

        final appSnap = await appRef.get();
        if (appSnap.exists) {
          final current =
              (appSnap.data()!['accuracyFactor'] as num?)?.toDouble() ?? 0.7;
          final updated = (current + delta).clamp(0.5, 1.0);
          await appRef.update({'accuracyFactor': updated});
        }
      }
    } catch (e) {
      debugPrint('NotificationService._processDone error: $e');
    }
  }

  // ── Schedule both today's notifications (called from HomeScreen.initState) ──
  static Future<void> scheduleTodayNotifications({
    required String uid,
    required List<Map<String, dynamic>> appliances,
    required bool peakEnabled,
    required bool morningEnabled,
  }) async {
    final todayKey = _dateKey(DateTime.now());

    if (peakEnabled) {
      await _schedulePeakReminder(
        uid: uid,
        appliances: appliances,
        dateKey: todayKey,
      );
    } else {
      await _plugin.cancel(_peakReminderId);
    }

    if (morningEnabled) {
      await _scheduleMorningTip(
        uid: uid,
        appliances: appliances,
        dateKey: todayKey,
      );
    } else {
      await _plugin.cancel(_morningTipId);
    }
  }

  // ── Type 1: 5:00 PM Peak Reminder ──────────────────────────────────────────
  static Future<void> _schedulePeakReminder({
    required String uid,
    required List<Map<String, dynamic>> appliances,
    required String dateKey,
  }) async {
    try {
      // Filter: must be peak-scheduled, wattage ≥ 700W, scheduled type
      final eligible = appliances.where((a) {
        final isPeak = a['isPeak'] as bool? ?? false;
        final wattage = (a['wattage'] as num?)?.toInt() ?? 0;
        final type = a['applianceType'] as String? ?? 'scheduled';
        return isPeak && wattage >= 700 && type == 'scheduled';
      }).toList();

      if (eligible.isEmpty) {
        await _plugin.cancel(_peakReminderId);
        return;
      }

      // Sort by daily kWh (highest first)
      eligible.sort((a, b) => _calcKwh(b).compareTo(_calcKwh(a)));
      final best = eligible.first;
      final name = best['name'] as String? ?? 'appliance';
      final kWh = _calcKwh(best);
      final savings = (kWh * 6.75 * 0.30).toStringAsFixed(0);

      // Check if it needs a gas-stove suggestion
      final nameKey = name.toLowerCase();
      final isGasSuggestion = _gasSuggestions.any(
        (key) => nameKey.contains(key),
      );

      final String title;
      final String body;
      if (isGasSuggestion) {
        title = '💡 Save on Peak Hours';
        body =
            'Your $name is scheduled during peak hours (6–10 PM). '
            'Consider using your gas stove instead to save ₹$savings today.';
      } else {
        title = '⚡ Peak Hours in 1 Hour';
        body =
            'Run your $name now to save ₹$savings — off-peak hours end at 6 PM!';
      }

      final payload = 'peak:$name:$uid:$dateKey';

      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        17, // 5:00 PM — fixed, not user-configurable (contextual value)
        0,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        _peakReminderId,
        title,
        body,
        scheduled,
        _buildActionDetails(payload),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService._schedulePeakReminder error: $e');
    }
  }

  // ── Type 2: Morning Tip ─────────────────────────────────────────────────────
  // Time is user-configurable via Settings → Morning Tip Time (stored as
  // 'morningTipTime' in the user doc, format "HH:mm", default "07:00").
  static Future<void> _scheduleMorningTip({
    required String uid,
    required List<Map<String, dynamic>> appliances,
    required String dateKey,
  }) async {
    try {
      // Only occasional-type appliances, after exclusions
      final eligible = appliances.where((a) {
        final type = a['applianceType'] as String? ?? 'scheduled';
        if (type != 'occasional') return false;
        final nameKey = (a['name'] as String? ?? '').toLowerCase();
        return !_morningExclusions.any((ex) => nameKey.contains(ex));
      }).toList();

      if (eligible.isEmpty) {
        await _plugin.cancel(_morningTipId);
        return;
      }

      // Sort by kWh — highest first
      eligible.sort((a, b) => _calcKwh(b).compareTo(_calcKwh(a)));
      final best = eligible.first;
      final name = best['name'] as String? ?? 'appliance';
      final payload = 'morning:$name:$uid:$dateKey';

      // ── Read user's chosen morning tip time from Firestore ────────────────
      int tipHour = 7;
      int tipMinute = 0;
      try {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final raw = (userSnap.data()?['morningTipTime'] as String?) ?? '07:00';
        final parts = raw.split(':');
        tipHour = int.tryParse(parts[0]) ?? 7;
        tipMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      } catch (_) {
        // Fall back to 7:00 AM on any error
      }
      // ─────────────────────────────────────────────────────────────────────

      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        tipHour,
        tipMinute,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        _morningTipId,
        '🌅 Good Morning — Energy Tip',
        'Great time to run your $name before peak hours begin at 6 PM!',
        scheduled,
        _buildActionDetails(payload),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService._scheduleMorningTip error: $e');
    }
  }

  // ── Slab Alert (unchanged, information only) ────────────────────────────────
  static Future<void> showSlabAlert({
    required int unitsToNextSlab,
    required int nextSlabAt,
  }) async {
    try {
      await _plugin.show(
        _slabAlertId,
        '⚠️ Approaching $nextSlabAt unit slab',
        'Only $unitsToNextSlab units left before your rate jumps.',
        _buildSimpleDetails(),
      );
    } catch (e) {
      debugPrint('NotificationService.showSlabAlert error: $e');
    }
  }

  // ── Cancel helpers ──────────────────────────────────────────────────────────
  static Future<void> cancelPeakWarning() async =>
      _plugin.cancel(_peakReminderId);
  static Future<void> cancelMorningTip() async => _plugin.cancel(_morningTipId);
  static Future<void> cancelAll() async => _plugin.cancelAll();

  // ── NotificationDetails with Done / Ignore action buttons ──────────────────
  static NotificationDetails _buildActionDetails(String payload) {
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'EcoWatt energy alerts and peak-hour reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: const [
        AndroidNotificationAction(
          'done',
          'Done',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'ignore',
          'Ignore',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return NotificationDetails(android: android, iOS: ios);
  }

  static NotificationDetails _buildSimpleDetails() {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'EcoWatt energy alerts and peak-hour reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: android, iOS: ios);
  }

  // ── Alert frequency → accuracyFactor delta ──────────────────────────────────
  // Used by: morning notification Done action (_processDone)
  // Strict  → large jump → app learns habits quickly
  // Balanced → moderate  → default behaviour
  // Relaxed → small jump → estimates stay stable, slow learning
  static double _accuracyDelta(String alertFrequency) {
    switch (alertFrequency) {
      case 'Strict':
        return 0.10;
      case 'Relaxed':
        return 0.02;
      default: // 'Balanced'
        return 0.05;
    }
  }

  // ── Internal kWh calculator (for sorting by impact) ────────────────────────
  static double _calcKwh(Map<String, dynamic> a) {
    final wattage = (a['wattage'] as num?)?.toDouble() ?? 0;
    final quantity = (a['quantity'] as num?)?.toDouble() ?? 1;
    final type = a['applianceType'] as String? ?? 'scheduled';

    switch (type) {
      case 'alwaysOn':
        final duty = (a['dutyCycle'] as num?)?.toDouble() ?? 0.35;
        return (wattage / 1000) * duty * 24 * quantity;
      case 'occasional':
        final dur = (a['avgDurationHours'] as num?)?.toDouble() ?? 0.5;
        return (wattage / 1000) * quantity * dur;
      default: // scheduled
        final start = _parseTime(a['startTime'] as String?);
        final end = _parseTime(a['endTime'] as String?);
        double hours = 1.0;
        if (start != null && end != null) {
          final s = start.$1 * 60 + start.$2;
          var e = end.$1 * 60 + end.$2;
          if (e < s) e += 1440;
          hours = (e - s) / 60.0;
        }
        return (wattage / 1000) * quantity * hours;
    }
  }

  static (int, int)? _parseTime(String? raw) {
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
      return (hour, minute);
    } catch (_) {
      return null;
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
