import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/screens/auth_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    _DashboardTab(),
    _UsageTab(),
    _SavingsTab(),
    _ProfileTab(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F5),
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

/*Bottom Nav ______________________________
_______________________________________*/
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.bar_chart_rounded, 'Usage'),
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
            offset: Offset(0, -3),
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

/* App Drawer__________________________________________________
_______________________________________________________*/
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
            onTap: () => Navigator.pop(context),
          ),
          _DrawerItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            iconColor: Colors.blue,
            onTap: () => Navigator.pop(context),
          ),
          _DrawerItem(
            icon: Icons.electrical_services_outlined,
            label: 'Appliances',
            iconColor: Colors.blue,
            onTap: () => Navigator.pop(context),
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
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
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

/*Dashboard__________________________________________
_____________________________________________________*/
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => __DashboardTabState();
}

class __DashboardTabState extends State<_DashboardTab> {
  late Timer _timer;
  late bool _isPeakHours;

  bool _checkPeakHours() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 18 && hour < 22;
  }

  @override
  void initState() {
    super.initState();
    _isPeakHours = _checkPeakHours();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _isPeakHours = _checkPeakHours());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusCard(isPeak: _isPeakHours),
          const SizedBox(height: 16),

          if (uid != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snap) {
                double savings = 0;
                if (snap.hasData && snap.data!.exists) {
                  final data = snap.data!.data() as Map<String, dynamic>;
                  savings = (data['totalSavings'] as num?)?.toDouble() ?? 0;
                }

                return _HeroSavingsCard(savings: savings);
              },
            ),
          const SizedBox(height: 16),
          if (uid != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('usageLogs')
                  .orderBy('date', descending: false)
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                final dailyData = _aggregateDailyUsage(snap.data?.docs ?? []);
                return _WeeklyChartCard(dailyData: dailyData);
              },
            ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.eco_rounded,
                  iconBg: const Color(0xFFE8F5E9),
                  iconColor: Colors.green.shade600,
                  title: 'Eco Mode',
                  subtitle: 'Reduce consumption by 15%',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.schedule_rounded,
                  iconBg: const Color(0xFFE3F2FD),
                  iconColor: Colors.blue.shade600,
                  title: 'Schedule',
                  subtitle: 'Set appliances timer',
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Map<int, double> _aggregateDailyUsage(List<QueryDocumentSnapshot> docs) {
    final Map<int, double> totals = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = data['date'] as Timestamp?;
      final double units = (data['units'] as num?)?.toDouble() ?? 0;
      if (ts != null) {
        final weekday = ts.toDate().weekday;
        totals[weekday] = (totals[weekday] ?? 0) + units;
      }
    }
    return totals;
  }
}

/*Status card______________________________________________
_________________________________________________________*/
class _StatusCard extends StatelessWidget {
  final bool isPeak;
  const _StatusCard({required this.isPeak});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPeak
                    ? const Color(0xFFFFC107)
                    : const Color(0xFF69F0AE),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isPeak
                                ? const Color(0xFFFFC107)
                                : const Color(0xFF69F0AE))
                            .withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isPeak ? 'Peak Hours' : 'Safe Zone',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212121),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.info_outline_rounded,
              color: Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/*Hero Card_________________________________________
___________________________________________________*/
class _HeroSavingsCard extends StatelessWidget {
  final double savings;
  const _HeroSavingsCard({required this.savings});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [AppColors.primary, const Color(0xFF4DB6AC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.savings_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'TOTAL SAVINGS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '₹${savings.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'Great job! You\'ve saved money by reducing usage during peak hours.',
              style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/*Weekly graph card___________________________________
____________________________________________________*/
class _WeeklyChartCard extends StatelessWidget {
  final Map<int, double> dailyData;

  const _WeeklyChartCard({required this.dailyData});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _maxY = 30.0;

  @override
  Widget build(BuildContext context) {
    final total = dailyData.values.fold(0.0, (a, b) => a + b);
    return Card(
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsetsGeometry.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Usage',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF212121),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Current billing week',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFFF5f5f5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${total.toStringAsFixed(0)} kWh',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.trending_down_rounded,
                        size: 16,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: _maxY,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 10,
                        reservedSize: 32,
                        getTitlesWidget: (val, meta) => Text(
                          '${val.toInt()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final i = val.toInt();
                          if (i < 0 || i >= 7) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _days[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                  ),
                  barGroups: List.generate(7, (i) {
                    final weekday = i + 1;
                    final value = dailyData[weekday] ?? 0;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: AppColors.primary,
                          width: 22,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: _maxY,
                            color: const Color(0xFFE0E0E0),
                          ),
                        ),
                      ],
                    );
                  }),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.primary,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toStringAsFixed(1)} kWh',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* Quick Action card__________________________________________
_____________________________________________________________*/
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsetsGeometry.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/*Placeholder tabs_________________________________________________
__________________________________________________________________*/
class _UsageTab extends StatelessWidget {
  const _UsageTab();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Usage - Coming Soon',
      style: TextStyle(color: Colors.grey, fontSize: 16),
    ),
  );
}

class _SavingsTab extends StatelessWidget {
  const _SavingsTab();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Savings - Coming Soon',
      style: TextStyle(color: Colors.grey, fontSize: 16),
    ),
  );
}

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
        final data = snap.hasData && snap.data!.exists
            ? snap.data!.data() as Map
            : {};
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
                (data['name'] as String?) ?? '_',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              Text(
                (data['email'] as String?) ?? '',
                style: TextStyle(fontSize: 13, color: Colors.grey),
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

class _ProfileInfoCard extends StatelessWidget {
  final Map data;
  const _ProfileInfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Phone', (data['phone'] as String?) ?? '_'),
      ('Goal', '${data['goal'] ?? '_'} kWh/month'),
      ('Tariff', (data['tariff'] as String?) ?? '_'),
      ('Purpose', (data['purpose'] as String?) ?? '_'),
      ('Billing Cycle', (data['billingCycle'] as String?) ?? '_'),
      ('Phase', (data['phase'] as String?) ?? '_'),
      ('Consumed Units', '${data['consumedUnits'] ?? '_'} kWh'),
      ('Connected Load', '${data['connectedLoad'] ?? '_'} W'),
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
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      rows[i].$2,
                      style: TextStyle(
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
