import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class UsageTab extends StatefulWidget {
  const UsageTab({super.key});

  @override
  State<UsageTab> createState() => _UsageTabState();
}

class _UsageTabState extends State<UsageTab> {
  int _selectedPeriod = 1; // 0=Today, 1=Week, 2=Month

  // ── Gemini AI Insight state ────────────────────────────────────
  String? _aiInsight;
  bool _aiInsightLoading = true;
  bool _aiInsightError = false;

  static const _periodLabels = ['Today', 'This Week', 'This Month'];
  static const _periodDays = [1, 7, 30];

  static const Map<String, Color> _categoryColors = {
    'Cooling': Color(0xFF00897B),
    'Heating': Color(0xFFFF7043),
    'Kitchen': Color(0xFF26C6DA),
    'Lighting': Color(0xFFFFC107),
    'Entertainment': Color(0xFF5C6BC0),
    'Others': Color(0xFF78909C),
  };

  @override
  void initState() {
    super.initState();
    _loadAiInsight();
  }

  // ── Gemini AI Insight loading logic ───────────────────────────
  // Cache: check Firestore → if older than 7 days, call Vercel → Gemini
  Future<void> _loadAiInsight() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _aiInsightLoading = false);
      return;
    }

    try {
      // 1. Check Firestore cache
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = userDoc.data() ?? {};

      final cachedInsight = data['aiInsight'] as String?;
      final cachedAt =
          (data['aiInsightGeneratedAt'] as dynamic)?.toDate() as DateTime?;

      final bool cacheIsFresh =
          cachedAt != null && DateTime.now().difference(cachedAt).inDays < 7;

      if (cachedInsight != null && cacheIsFresh) {
        if (mounted) {
          setState(() {
            _aiInsight = cachedInsight;
            _aiInsightLoading = false;
          });
        }
        return;
      }

      // 2. Gather usage data for the prompt
      final schedSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('applianceSchedules')
          .get();

      if (schedSnap.docs.isEmpty) {
        if (mounted) setState(() => _aiInsightLoading = false);
        return;
      }

      // Calculate weekly totals per category
      double totalWeeklyKwh = 0;
      String topApplianceName = '';
      double topApplianceKwh = 0;
      double peakKwh = 0;
      double totalKwh = 0;

      for (final doc in schedSnap.docs) {
        final d = doc.data();
        final kWh = _calculateDailyKwh(d) * 7;
        final isPeak = d['isPeak'] as bool? ?? false;
        totalWeeklyKwh += kWh;
        totalKwh += kWh;
        if (isPeak) peakKwh += kWh;
        if (kWh > topApplianceKwh) {
          topApplianceKwh = kWh;
          topApplianceName = d['name'] as String? ?? 'appliance';
        }
      }

      final peakPercent = totalKwh > 0
          ? ((peakKwh / totalKwh) * 100).toStringAsFixed(0)
          : '0';

      // 3. Build personalized Gemini prompt
      final prompt =
          'You are an energy saving advisor for a home in Kerala, India. '
          'The user consumed ${totalWeeklyKwh.toStringAsFixed(1)} kWh this week. '
          'Their highest consuming appliance was the $topApplianceName at ${topApplianceKwh.toStringAsFixed(1)} kWh. '
          '$peakPercent% of their energy was used during KSEB peak hours (6–10 PM), '
          'which costs 30% more per unit. '
          'Give exactly 2 short, encouraging, specific sentences of advice to help them '
          'save money next week. Be friendly and practical. '
          'Do not use markdown, bullet points, or asterisks. Plain text only.';

      // 4. Call Gemini via Vercel backend
      final insight = await _callGemini(prompt);

      if (insight != null && mounted) {
        // 5. Save to Firestore cache
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'aiInsight': insight,
          'aiInsightGeneratedAt': DateTime.now(),
        });

        setState(() {
          _aiInsight = insight;
          _aiInsightLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _aiInsightLoading = false;
            _aiInsightError = true;
          });
        }
      }
    } catch (e) {
      debugPrint('AI Insight error: $e');
      if (mounted) {
        setState(() {
          _aiInsightLoading = false;
          _aiInsightError = true;
        });
      }
    }
  }

  // ── Calls Vercel backend → Gemini (key never exposed to client) ──
  Future<String?> _callGemini(String prompt) async {
    try {
      const vercelUrl =
          'https://gemini-backend-ecowattenergytrackers-projects.vercel.app/api/insight';

      final response = await http
          .post(
            Uri.parse(vercelUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception('Request timed out'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['insight'] as String?;
        if (text == null || text.trim().isEmpty) return null;
        return text.trim();
      } else {
        debugPrint('Vercel API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Vercel call error: $e');
      return null;
    }
  }

  // ── kWh calculation for a single appliance doc ────────────────
  double _calculateDailyKwh(Map<String, dynamic> d) {
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
        return (wattage / 1000) * quantity * avgDur * weeklyFreq / 7.0;

      default: // scheduled
        final accuracyFactor = (d['accuracyFactor'] as num?)?.toDouble() ?? 0.7;
        final start = _parseTime(d['startTime'] as String?);
        final end = _parseTime(d['endTime'] as String?);
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

  IconData _iconFor(String? key) {
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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Not logged in'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('applianceSchedules')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Error loading data'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart_rounded, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No appliances scheduled yet.',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          );
        }

        final int multiplierDays = _periodDays[_selectedPeriod];

        // ── Build appliance usage list ─────────────────────────
        final applianceUsage = docs.map((d) {
          final a = d.data() as Map<String, dynamic>;
          final dailyKwh = _calculateDailyKwh(a);
          final kWh = dailyKwh * multiplierDays;
          final type = a['applianceType'] as String? ?? 'scheduled';
          final isPeak = a['isPeak'] as bool? ?? false;

          String usageLabel;
          if (type == 'alwaysOn') {
            usageLabel = 'Always On · Off-peak';
          } else if (type == 'occasional') {
            final freq = (a['weeklyFrequency'] as num?)?.toDouble() ?? 3.0;
            final dur = (a['avgDurationHours'] as num?)?.toDouble() ?? 0.5;
            final durLabel = dur < 0.5
                ? '${(dur * 60).toInt()} min'
                : '${dur.toStringAsFixed(1)} hr';
            usageLabel = '~${freq.toStringAsFixed(0)}×/wk · $durLabel/use';
          } else {
            final start = a['startTime'] as String? ?? '--:--';
            final end = a['endTime'] as String? ?? '--:--';
            usageLabel = '$start – $end · ${isPeak ? 'Peak' : 'Off-peak'}';
          }

          return {
            'name': a['name'] as String? ?? 'Unknown',
            'category': a['category'] as String? ?? 'Others',
            'icon': a['icon'] as String? ?? '',
            'kWh': kWh,
            'isPeak': isPeak,
            'usageLabel': usageLabel,
          };
        }).toList();

        applianceUsage.sort(
          (a, b) => (b['kWh'] as double).compareTo(a['kWh'] as double),
        );

        final totalKwh = applianceUsage.fold(
          0.0,
          (acc, a) => acc + (a['kWh'] as double),
        );

        final Map<String, double> categoryUsage = {};
        for (final a in applianceUsage) {
          final cat = a['category'] as String;
          categoryUsage[cat] = (categoryUsage[cat] ?? 0) + (a['kWh'] as double);
        }

        final topConsumer = applianceUsage.take(5).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── iOS-style large title ─────────────────────────────
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Insights',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2E20),
                  ),
                ),
              ),

              // ── AI Insights Card ─────────────────────────────────
              _AiInsightCard(
                insight: _aiInsight,
                isLoading: _aiInsightLoading,
                hasError: _aiInsightError,
                onRetry: () {
                  setState(() {
                    _aiInsightLoading = true;
                    _aiInsightError = false;
                    _aiInsight = null;
                  });
                  _loadAiInsight();
                },
              ),
              const SizedBox(height: 20),

              // ── Period switcher ───────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: List.generate(_periodLabels.length, (i) {
                    final isActive = i == _selectedPeriod;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPeriod = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            _periodLabels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isActive
                                  ? AppColors.primary
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),

              // ── Donut chart card ──────────────────────────────────
              Card(
                elevation: 1.5,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sections: categoryUsage.entries.map((e) {
                                  final color =
                                      _categoryColors[e.key] ?? Colors.grey;
                                  final pct = totalKwh > 0
                                      ? (e.value / totalKwh * 100)
                                      : 0.0;
                                  return PieChartSectionData(
                                    value: e.value,
                                    color: color,
                                    radius: 50,
                                    title: pct > 5
                                        ? '${pct.toStringAsFixed(0)}%'
                                        : '',
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  );
                                }).toList(),
                                centerSpaceRadius: 60,
                                sectionsSpace: 3,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  totalKwh.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A2E20),
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'KWH TOTAL',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: categoryUsage.keys.map((cat) {
                          final color = _categoryColors[cat] ?? Colors.grey;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Top consumers ─────────────────────────────────────
              Row(
                children: [
                  const Text(
                    'Top Consumers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2E20),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Detailed View',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              ...topConsumer.map((a) {
                final kWh = a['kWh'] as double;
                final percent = totalKwh > 0 ? (kWh / totalKwh) : 0.0;
                final cat = a['category'] as String;
                final color = _categoryColors[cat] ?? AppColors.primary;

                return _TopConsumerCard(
                  name: a['name'] as String,
                  icon: _iconFor(a['icon'] as String?),
                  iconColor: color,
                  kWh: kWh,
                  percent: percent,
                  barColor: color,
                  usageLabel: a['usageLabel'] as String,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// AI Insight Card
// ─────────────────────────────────────────────────────────────────
class _AiInsightCard extends StatelessWidget {
  final String? insight;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  const _AiInsightCard({
    required this.insight,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI WEEKLY INSIGHT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (!isLoading && !hasError && insight != null)
                Text(
                  'Updated weekly',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Content
          if (isLoading)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white.withValues(alpha: 0.8),
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Generating your personalised tip…',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            )
          else if (hasError || insight == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load insight. Tap to retry.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              insight!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Top Consumer Card
// ─────────────────────────────────────────────────────────────────
class _TopConsumerCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color iconColor;
  final double kWh;
  final double percent;
  final Color barColor;
  final String usageLabel;

  const _TopConsumerCard({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.kWh,
    required this.percent,
    required this.barColor,
    required this.usageLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1A2E20),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      usageLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${kWh.toStringAsFixed(1)} kWh',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                  Text(
                    '${(percent * 100).toStringAsFixed(0)}% OF TOTAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
