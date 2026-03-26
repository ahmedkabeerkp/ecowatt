import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eco_watt/models/appliance_item.dart';
import 'package:eco_watt/screens/schedule_appliance_screen.dart';

class AppliancesScreen extends StatefulWidget {
  const AppliancesScreen({super.key});

  @override
  State<AppliancesScreen> createState() => _AppliancesScreenState();
}

class _AppliancesScreenState extends State<AppliancesScreen> {
  final List<ApplianceItem> _allAppliances = buildApplianceList();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // Loading state while fetching existing data from Firestore
  bool _loadingExisting = true;

  static const List<String> _categories = [
    'All',
    'Cooling',
    'Heating',
    'Kitchen',
    'Lighting',
    'Entertainment',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  // ── Load existing schedules from Firestore and pre-fill list ──
  Future<void> _loadExistingData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _loadingExisting = false);
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('applianceSchedules')
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _loadingExisting = false);
        return;
      }

      // Build a map: applianceName → {wattage, quantity}
      final Map<String, Map<String, dynamic>> existing = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        existing[doc.id] = {
          'wattage': (data['wattage'] as num?)?.toInt(),
          'quantity': (data['quantity'] as num?)?.toInt() ?? 1,
        };
      }

      // Pre-fill matching appliances
      setState(() {
        for (final appliance in _allAppliances) {
          final saved = existing[appliance.name];
          if (saved != null) {
            appliance.quantity = saved['quantity'] as int;
            if (saved['wattage'] != null) {
              appliance.wattage = saved['wattage'] as int;
            }
          }
        }
        _loadingExisting = false;
      });
    } catch (_) {
      setState(() => _loadingExisting = false);
    }
  }

  List<ApplianceItem> get _filtered {
    return _allAppliances.where((a) {
      final matchesCategory =
          _selectedCategory == 'All' || a.category == _selectedCategory;
      final matchesSearch = a.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return matchesCategory && matchesSearch;
    }).toList();
  }

  int get _totalSelected => _allAppliances.where((a) => a.quantity > 0).length;

  void _increment(ApplianceItem item) => setState(() => item.quantity++);

  void _decrement(ApplianceItem item) {
    if (item.quantity > 0) setState(() => item.quantity--);
  }

  //Edit Watts Bottom Sheet ─────────────────────────────────
  void _showEditWatts(ApplianceItem item) {
    final controller = TextEditingController(text: item.wattage.toString());
    double sliderValue = item.wattage.clamp(0, 5000).toDouble();
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(
                          Icons.electric_bolt_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Edit Wattage — ${item.name}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Set the actual wattage of your appliance (0 – 5000 W)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null) {
                          setSheetState(() {
                            sliderValue = parsed.clamp(0, 5000).toDouble();
                            error = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Watts',
                        suffixText: 'W',
                        errorText: error,
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.grey.shade200,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.15),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: sliderValue,
                        min: 0,
                        max: 5000,
                        divisions: 100,
                        label: '${sliderValue.toInt()} W',
                        onChanged: (v) {
                          setSheetState(() {
                            sliderValue = v;
                            controller.text = v.toInt().toString();
                            controller.selection = TextSelection.collapsed(
                              offset: controller.text.length,
                            );
                            error = null;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '0 W',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '5000 W',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          final parsed = int.tryParse(controller.text.trim());
                          if (parsed == null || parsed < 0 || parsed > 5000) {
                            setSheetState(
                              () => error = 'Enter a value between 0 and 5000',
                            );
                            return;
                          }
                          setState(() => item.wattage = parsed);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Save Wattage',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onContinue() {
    final selected = _allAppliances.where((a) => a.quantity > 0).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one appliance.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleApplianceScreen(selectedAppliances: selected),
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

  static IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Cooling':
        return Icons.ac_unit_rounded;
      case 'Heating':
        return Icons.local_fire_department_rounded;
      case 'Kitchen':
        return Icons.kitchen_rounded;
      case 'Lighting':
        return Icons.light_rounded;
      case 'Entertainment':
        return Icons.tv_rounded;
      case 'Others':
        return Icons.electrical_services_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loader while fetching existing Firestore data
    if (_loadingExisting) {
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
            'My Appliances',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final filtered = _filtered;

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
          'My Appliances',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        // Show "Edit Mode" badge if user already has saved data
        actions: [
          if (_allAppliances.any((a) => a.quantity > 0))
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Edit Mode',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          AppProgressBar(step: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search appliances...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Category chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isActive = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive
                                    ? AppColors.primary
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _categoryIcon(cat),
                                  size: 15,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Appliance cards
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'No appliance found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...filtered.map(
                    (item) => _ApplianceCard(
                      item: item,
                      iconData: _iconFor(item.icon),
                      onIncrement: () => _increment(item),
                      onDecrement: () => _decrement(item),
                      onEditWatts: () => _showEditWatts(item),
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
            onPressed: _onContinue,
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            label: Text(
              _totalSelected > 0
                  ? 'Continue ($_totalSelected selected)'
                  : 'Continue',
              style: const TextStyle(
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

// ─────────────────────────────────────────────────────────────────
// Progress Bar (public — imported by ScheduleApplianceScreen)
// ─────────────────────────────────────────────────────────────────
class AppProgressBar extends StatelessWidget {
  final int step;
  const AppProgressBar({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: step / 2,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Step $step of 2',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Appliance Card
// ─────────────────────────────────────────────────────────────────
class _ApplianceCard extends StatelessWidget {
  final ApplianceItem item;
  final IconData iconData;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEditWatts;

  const _ApplianceCard({
    required this.item,
    required this.iconData,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditWatts,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = item.quantity > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                iconData,
                color: isSelected ? AppColors.primary : Colors.grey.shade500,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onEditWatts,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.electric_bolt_rounded,
                          size: 13,
                          color: isSelected ? AppColors.primary : Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${item.wattageLabel} W',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? AppColors.primary : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.10)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 10,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Stepper(
              value: item.quantity,
              onIncrement: onIncrement,
              onDecrement: onDecrement,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Stepper
// ─────────────────────────────────────────────────────────────────
class _Stepper extends StatelessWidget {
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _Stepper({
    required this.onIncrement,
    required this.onDecrement,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepButton(
          icon: Icons.remove,
          onTap: onDecrement,
          active: value > 0,
          filled: false,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: onIncrement,
          active: true,
          filled: true,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool filled;

  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.active,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.primary : Colors.transparent,
          border: filled
              ? null
              : Border.all(
                  color: active ? Colors.grey.shade400 : Colors.grey.shade200,
                ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled
              ? Colors.white
              : active
              ? Colors.grey.shade600
              : Colors.grey.shade300,
        ),
      ),
    );
  }
}
