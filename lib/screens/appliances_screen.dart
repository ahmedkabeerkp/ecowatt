import 'package:eco_watt/constants/colors.dart';
import 'package:flutter/material.dart';
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

  static const List<String> _categories = [
    'All',
    'Cooling',
    'Heating',
    'Kitchen',
    'Lighting',
    'Entertainment',
    'Others',
  ];

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
      ),
      body: Column(
        children: [
          AppProgressBar(step: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
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
                      hintText: 'Seach appliances...',
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
                //Appliance Cards----
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

/*Progress Bar _________________________________________________________
_______________________________________________________________________*/
class AppProgressBar extends StatelessWidget {
  final int step;
  const AppProgressBar({required this.step});

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

//Appliance Card____________________________________________________________
class _ApplianceCard extends StatelessWidget {
  final ApplianceItem item;
  final IconData iconData;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ApplianceCard({
    required this.item,
    required this.iconData,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = item.quantity > 0;
    return AnimatedContainer(
      duration: const Duration(microseconds: 200),
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
                  Row(
                    children: [
                      Icon(
                        Icons.electric_bolt_rounded,
                        size: 13,
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${item.wattageLabel} Watts',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? AppColors.primary : Colors.grey,
                        ),
                      ),
                    ],
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

//Stepper__________________________________________________________________
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
