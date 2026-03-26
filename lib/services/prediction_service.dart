// ─────────────────────────────────────────────────────────────────
// Notification Priority Types (Section 4 of the hybrid model spec)
// ─────────────────────────────────────────────────────────────────

/// The four categories of notifications, in strict priority order.
enum NotificationPriority {
  /// P1 — User is within 25 units of a KSEB slab boundary. Fire immediately.
  slabRisk,

  /// P2 — Peak hours (18:00–22:00) starting soon. Remind user to delay heavy appliances.
  peakHour,

  /// P3 — 3+ days since last usage confirmation for a scheduled appliance.
  usageConfirmation,

  /// P4 — 7+ days since last occasional-appliance (iron/washer) usage survey.
  weeklySurvey,
}

// ─────────────────────────────────────────────────────────────────
// PredictionService
// ─────────────────────────────────────────────────────────────────

class PredictionService {
  // ── Slab calculation ──────────────────────────────────────────

  /// Returns the next KSEB billing slab boundary above [units].
  static double nextSlab(double units) {
    if (units < 50) return 50;
    if (units < 100) return 100;
    if (units < 150) return 150;
    if (units < 200) return 200;
    if (units < 250) return 250;
    if (units < 300) return 300;
    if (units < 350) return 350;
    return 500;
  }

  /// How many units remain before the next slab is crossed.
  static double unitsRemaining(double units) {
    return nextSlab(units) - units;
  }

  // ── Notification engine ───────────────────────────────────────

  /// Returns the ordered list of notifications to fire today.
  /// **Capped at 2 per day** — the top 2 from the priority queue are returned.
  ///
  /// Parameters:
  /// - [isNearSlab]         : units remaining ≤ 25 (from unitsRemaining)
  /// - [isPeakHourSoon]     : current time is within 30 min before 18:00
  /// - [isConfirmationDue]  : ≥3 days since user last confirmed a scheduled appliance
  /// - [isSurveyDue]        : ≥7 days since user filled in the weekly occasional survey
  ///
  /// Respects user preferences — pass false for any notification the user has disabled.
  static List<NotificationPriority> getDailyNotifications({
    required bool isNearSlab,
    required bool isPeakHourSoon,
    required bool isConfirmationDue,
    required bool isSurveyDue,
  }) {
    final queue = <NotificationPriority>[];

    // Build priority queue in strict order
    if (isNearSlab) queue.add(NotificationPriority.slabRisk);
    if (isPeakHourSoon) queue.add(NotificationPriority.peakHour);
    if (isConfirmationDue) queue.add(NotificationPriority.usageConfirmation);
    if (isSurveyDue) queue.add(NotificationPriority.weeklySurvey);

    // Hard cap: never send more than 2 notifications per day
    return queue.take(2).toList();
  }

  // ── Timing helpers ─────────────────────────────────────────────

  /// True if peak hours start within the next 30 minutes.
  /// Peak hours: 18:00 – 22:00.
  static bool isPeakApproaching() {
    final now = DateTime.now();
    final peakStart = DateTime(now.year, now.month, now.day, 18, 0);
    final diffMinutes = peakStart.difference(now).inMinutes;
    return diffMinutes >= 0 && diffMinutes <= 30;
  }

  /// True if current time is within peak hours (18:00 – 22:00).
  static bool isCurrentlyPeak() {
    final now = DateTime.now();
    return now.hour >= 18 && now.hour < 22;
  }

  /// True if a usage confirmation should be sent today.
  /// Rule: at least 3 days must have passed since [lastConfirmationDate].
  static bool isConfirmationDue(DateTime? lastConfirmationDate) {
    if (lastConfirmationDate == null) return true;
    return DateTime.now().difference(lastConfirmationDate).inDays >= 3;
  }

  /// True if a weekly survey should be sent today.
  /// Rule: at least 7 days must have passed since [lastSurveyDate].
  static bool isSurveyDue(DateTime? lastSurveyDate) {
    if (lastSurveyDate == null) return true;
    return DateTime.now().difference(lastSurveyDate).inDays >= 7;
  }

  /// True if a monthly meter reading reminder should be sent.
  /// Rule: at least 25 days since [lastMeterReadingDate].
  static bool isMeterReadingDue(DateTime? lastMeterReadingDate) {
    if (lastMeterReadingDate == null) return true;
    return DateTime.now().difference(lastMeterReadingDate).inDays >= 25;
  }
}
