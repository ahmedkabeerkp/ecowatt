import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/services/daily_snapshot_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SavingsTab extends StatefulWidget {
  const SavingsTab({super.key});

  @override
  State<SavingsTab> createState() => _SavingsTabState();
}

class _SavingsTabState extends State<SavingsTab> {
  // ── State ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> _recentLogs = [];
  double _cycleSavings = 0;
  bool _logsLoading = true;

  // Tracks last loaded cycle start to avoid redundant Firestore fetches
  DateTime? _lastCycleStart;

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadRecentLogs();
  }

  Future<void> _loadRecentLogs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _logsLoading = false);
      return;
    }
    final logs = await DailySnapshotService.getRecentDailyLogs(uid, 7);
    if (mounted) {
      setState(() {
        _recentLogs = logs;
        _logsLoading = false;
      });
    }
  }

  Future<void> _loadCycleSavings(String uid, DateTime cycleStart) async {
    // Skip if we already loaded for this cycle start
    if (_lastCycleStart == cycleStart) return;
    _lastCycleStart = cycleStart;

    final savings = await DailySnapshotService.getCycleSavings(uid, cycleStart);
    if (mounted) setState(() => _cycleSavings = savings);
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Not logged in'));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnap) {
        final userData = (userSnap.hasData && userSnap.data!.exists)
            ? (userSnap.data!.data() as Map<String, dynamic>? ?? {})
            : <String, dynamic>{};

        // ── Billing cycle start ───────────────────────────────────
        DateTime cycleStart = DateTime.now().subtract(const Duration(days: 30));
        final rawBillingStart = userData['billingStartDate'];
        if (rawBillingStart != null) {
          try {
            cycleStart = (rawBillingStart as dynamic).toDate() as DateTime;
          } catch (_) {}
        }

        // Trigger cycle savings load after build (avoids calling async in build)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadCycleSavings(uid, cycleStart);
        });

        // ── Goal & targets ────────────────────────────────────────
        final goalKwh = (userData['goal'] as num?)?.toDouble() ?? 0.0;

        // Savings target: 20% of estimated monthly bill at goal consumption
        // This gives a meaningful, achievable target linked to real cost.
        final estimatedMonthlyBill = goalKwh > 0
            ? _estimateMonthlyBill(goalKwh)
            : 0.0;
        final savingsTarget = estimatedMonthlyBill * 0.20;

        final progress = savingsTarget > 0
            ? (_cycleSavings / savingsTarget).clamp(0.0, 1.0)
            : 0.0;

        // ── Account age for badges ────────────────────────────────
        final createdAt = userData['createdAt'];
        final accountAgeDays = createdAt != null
            ? DateTime.now()
                  .difference((createdAt as dynamic).toDate() as DateTime)
                  .inDays
            : 0;

        // ── Badge unlock conditions ───────────────────────────────
        final has7DayStreak = accountAgeDays >= 7;
        final isEcoWarriorUnlocked = _cycleSavings >= 500;

        // ── Smart actions from today's frozen log ─────────────────
        // We read from the snapshot — NOT from live applianceSchedules.
        final todayLog = _recentLogs.isNotEmpty ? _recentLogs.last : null;
        final smartActions = todayLog != null
            ? (todayLog['appliances'] as List? ?? [])
                  .cast<Map<String, dynamic>>()
                  .where(
                    (a) =>
                        (a['applianceType'] as String? ?? '') == 'scheduled' &&
                        (a['isPeak'] as bool? ?? false) == false &&
                        ((a['dailySavings'] as num?)?.toDouble() ?? 0) > 0,
                  )
                  .toList()
            : <Map<String, dynamic>>[];

        final hasOffPeakAppliances = smartActions.isNotEmpty;

        return ScrollConfiguration(
          behavior: _HiddenScrollbarBehavior(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 16),
                  child: Text(
                    'My Savings',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2E20),
                    ),
                  ),
                ),

                // ── Savings Summary Card ──────────────────────────────
                _SavingsSummaryCard(
                  cycleSavings: _cycleSavings,
                  savingsTarget: savingsTarget,
                  progress: progress,
                  daysLogged: _recentLogs.length,
                ),
                const SizedBox(height: 24),

                // ── 7-Day Savings Chart ───────────────────────────────
                const Text(
                  '7-Day Savings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2E20),
                  ),
                ),
                const SizedBox(height: 14),
                _logsLoading
                    ? _chartSkeleton()
                    : _SavingsBarChart(recentLogs: _recentLogs),
                const SizedBox(height: 24),

                // ── Badges & Streaks ──────────────────────────────────
                const Text(
                  'Badges & Streaks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2E20),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _BadgeCard(
                        icon: Icons.military_tech_rounded,
                        iconColor: const Color(0xFFF59E08),
                        bgColor: const Color(0xFFFFFBEB),
                        title: 'Peak Master',
                        subtitle: hasOffPeakAppliances
                            ? 'Unlocked'
                            : 'Schedule off-peak',
                        isLocked: !hasOffPeakAppliances,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BadgeCard(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: const Color(0xFFEF4444),
                        bgColor: const Color(0xFFFEF2F2),
                        title: '7-Day Streak',
                        subtitle: has7DayStreak
                            ? 'Unlocked'
                            : '$accountAgeDays/7 days',
                        isLocked: !has7DayStreak,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BadgeCard(
                        icon: Icons.eco_rounded,
                        iconColor: Colors.green.shade600,
                        bgColor: const Color(0xFFF0FDF4),
                        title: 'Eco Warrior',
                        subtitle: isEcoWarriorUnlocked
                            ? 'Unlocked'
                            : '₹${_cycleSavings.toStringAsFixed(0)}/₹500',
                        isLocked: !isEcoWarriorUnlocked,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Recent Smart Actions ──────────────────────────────
                const Text(
                  'Recent Smart Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2E20),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Appliances scheduled outside peak hours (6–10 PM)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 14),

                if (_logsLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (smartActions.isEmpty)
                  _EmptyActionCard()
                else
                  ...smartActions.map(
                    (a) => _SmartActionCard(
                      applianceName: a['name'] as String? ?? '',
                      slot:
                          '${a['startTime'] ?? '--:--'} – ${a['endTime'] ?? '--:--'}',
                      dailySavings:
                          (a['dailySavings'] as num?)?.toDouble() ?? 0,
                    ),
                  ),

                // ── Disclaimer ────────────────────────────────────────
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Savings are estimated based on your appliance schedules '
                          'and KSEB peak hour rates. Actual savings may vary with '
                          'real usage patterns.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Rough monthly bill estimate for savings target calculation
  double _estimateMonthlyBill(double monthlyKwh) {
    // Simple slab average: 0-250 units telescopic, above non-telescopic
    if (monthlyKwh <= 250) {
      return monthlyKwh * 6.0; // ~avg telescopic rate
    }
    return monthlyKwh * 7.5; // ~avg non-telescopic rate
  }

  Widget _chartSkeleton() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Savings Summary Card — big hero card at top
// ─────────────────────────────────────────────────────────────────
class _SavingsSummaryCard extends StatelessWidget {
  final double cycleSavings;
  final double savingsTarget;
  final double progress;
  final int daysLogged;

  const _SavingsSummaryCard({
    required this.cycleSavings,
    required this.savingsTarget,
    required this.progress,
    required this.daysLogged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            'SAVED THIS BILLING CYCLE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // Amount + context
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${cycleSavings.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 14),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  daysLogged > 0
                      ? 'from $daysLogged days of\nsmart scheduling'
                      : 'savings will appear\nafter first day of use',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),

          // Goal progress bar (only shown if goal is set)
          if (savingsTarget > 0) ...[
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly savings goal',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '₹${savingsTarget.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.20),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              progress >= 1.0
                  ? '🎉 Goal reached! Great work this cycle!'
                  : '₹${(savingsTarget - cycleSavings).clamp(0, savingsTarget).toStringAsFixed(0)} '
                        'more to reach your goal',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontStyle: progress >= 1.0
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// 7-Day Savings Bar Chart
// ─────────────────────────────────────────────────────────────────
class _SavingsBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> recentLogs;

  const _SavingsBarChart({required this.recentLogs});

  @override
  Widget build(BuildContext context) {
    if (recentLogs.isEmpty) {
      return Container(
        height: 160,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 40,
                color: Colors.grey.shade200,
              ),
              const SizedBox(height: 10),
              Text(
                'Savings history will appear here\nafter your first day of use',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build last 7 days slots (some may have no data)
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final logMap = {for (var l in recentLogs) l['date'] as String: l};

    // Max savings value for chart Y-axis
    double maxSavings = 1.0;
    for (final log in recentLogs) {
      final s = (log['estimatedSavings'] as num?)?.toDouble() ?? 0;
      if (s > maxSavings) maxSavings = s;
    }

    final barGroups = days.asMap().entries.map((entry) {
      final i = entry.key;
      final d = entry.value;
      final key = DailySnapshotService.dateKey(d);
      final savings =
          (logMap[key]?['estimatedSavings'] as num?)?.toDouble() ?? 0;
      final isToday = i == 6;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: savings > 0 ? savings : 0.3, // tiny stub for empty days
            color: savings > 0
                ? (isToday
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.55))
                : Colors.grey.shade100,
            width: 26,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    }).toList();

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 160,
        child: BarChart(
          BarChartData(
            maxY: maxSavings * 1.35,
            minY: 0,
            barGroups: barGroups,
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: Colors.grey.shade100, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final savings = rod.toY;
                  if (savings < 0.5) return null;
                  return BarTooltipItem(
                    '₹${savings.toStringAsFixed(1)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (val, _) {
                    if (val == 0) return const SizedBox.shrink();
                    return Text(
                      '₹${val.toInt()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, _) {
                    final idx = val.toInt();
                    if (idx < 0 || idx >= days.length) {
                      return const SizedBox.shrink();
                    }
                    final weekday = days[idx].weekday - 1;
                    final isToday = idx == 6;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        dayLabels[weekday],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isToday
                              ? AppColors.primary
                              : Colors.grey.shade500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Badge Card
// ─────────────────────────────────────────────────────────────────
class _BadgeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final bool isLocked;

  const _BadgeCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
        children: [
          Opacity(
            opacity: isLocked ? 0.35 : 1.0,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isLocked ? Colors.grey.shade100 : bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLocked ? Icons.lock_rounded : icon,
                color: isLocked ? Colors.grey : iconColor,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isLocked ? Colors.grey.shade400 : const Color(0xFF1A2E20),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isLocked ? Colors.grey.shade400 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Smart Action Card — reads from frozen snapshot, not live data
// ─────────────────────────────────────────────────────────────────
class _SmartActionCard extends StatelessWidget {
  final String applianceName;
  final String slot;
  final double dailySavings;

  const _SmartActionCard({
    required this.applianceName,
    required this.slot,
    required this.dailySavings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade500,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$applianceName — off-peak schedule',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1A2E20),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  slot,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Text(
            '+₹${dailySavings.toStringAsFixed(1)}/day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Empty Action Card
// ─────────────────────────────────────────────────────────────────
class _EmptyActionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bolt_rounded, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(
              'No smart actions yet.\nSchedule appliances outside peak hours\nto start earning savings!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Hidden Scrollbar Behavior
// ─────────────────────────────────────────────────────────────────
class _HiddenScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
