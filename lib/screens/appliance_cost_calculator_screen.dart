import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/services/kseb_billing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Convenience import — matches your existing file name
import 'package:eco_watt/services/energy_calculator.dart';

// ─────────────────────────────────────────────────────────────────
// Preset appliances (name → typical wattage)
// ─────────────────────────────────────────────────────────────────
const List<_AppliancePreset> _kPresets = [
  _AppliancePreset('Air Conditioner (1.5 T)', 1500, Icons.ac_unit_rounded),
  _AppliancePreset('Ceiling Fan', 75, Icons.wind_power_rounded),
  _AppliancePreset('Refrigerator', 150, Icons.kitchen_rounded),
  _AppliancePreset('Washing Machine', 500, Icons.local_laundry_service_rounded),
  _AppliancePreset('Water Heater / Geyser', 2000, Icons.water_damage_rounded),
  _AppliancePreset('Induction Cooktop', 1800, Icons.outdoor_grill_rounded),
  _AppliancePreset('Microwave', 1000, Icons.microwave_rounded),
  _AppliancePreset('Television (LED)', 100, Icons.tv_rounded),
  _AppliancePreset('Laptop', 65, Icons.laptop_rounded),
  _AppliancePreset('Desktop + Monitor', 250, Icons.desktop_windows_rounded),
  _AppliancePreset('Iron', 1000, Icons.iron_rounded),
  _AppliancePreset('Mixer / Grinder', 750, Icons.blender_rounded),
  _AppliancePreset('Water Pump', 750, Icons.water_drop_rounded),
  _AppliancePreset('LED Bulb', 10, Icons.light_rounded),
  _AppliancePreset('Custom…', 0, Icons.tune_rounded),
];

class _AppliancePreset {
  final String name;
  final int watts;
  final IconData icon;
  const _AppliancePreset(this.name, this.watts, this.icon);
}

// ─────────────────────────────────────────────────────────────────
// Period options
// ─────────────────────────────────────────────────────────────────
const List<(String label, int days)> _kPeriods = [
  ('1 Day', 1),
  ('1 Week', 7),
  ('1 Month', 30),
  ('2 Months', 60),
];

// ─────────────────────────────────────────────────────────────────
// ApplianceCostCalculatorScreen
// ─────────────────────────────────────────────────────────────────
class ApplianceCostCalculatorScreen extends StatefulWidget {
  const ApplianceCostCalculatorScreen({super.key});

  @override
  State<ApplianceCostCalculatorScreen> createState() =>
      _ApplianceCostCalculatorScreenState();
}

class _ApplianceCostCalculatorScreenState
    extends State<ApplianceCostCalculatorScreen> {
  // ── Selected preset (null = nothing chosen yet) ───────────────
  int _presetIndex = -1; // index into _kPresets
  bool _isCustom = false;

  // ── Inputs ────────────────────────────────────────────────────
  final _wattageCtrl = TextEditingController();
  final _wattageFocus = FocusNode();

  int _quantity = 1;
  double _hoursPerDay = 1.0; // slider: 0.5 – 12
  int _periodIndex = 0; // index into _kPeriods

  // ── Derived ───────────────────────────────────────────────────
  bool get _hasValidInput {
    final w = _effectiveWatts;
    return w > 0 && _quantity >= 1 && _hoursPerDay > 0;
  }

  int get _effectiveWatts {
    if (_isCustom) {
      return int.tryParse(_wattageCtrl.text.trim()) ?? 0;
    }
    if (_presetIndex >= 0) {
      return _kPresets[_presetIndex].watts;
    }
    return 0;
  }

  int get _periodDays => _kPeriods[_periodIndex].$2;

  double get _totalKwh {
    final perDay = EnergyCalculator.calculateUnits(
      watts: _effectiveWatts,
      quantity: _quantity,
      hours: _hoursPerDay,
    );
    return perDay * _periodDays;
  }

  double get _estimatedCost => KSEBBillingService.calculateTotalBill(_totalKwh);

  // ── Helpers ───────────────────────────────────────────────────
  String _formatHours(double h) {
    if (h < 1) {
      return '${(h * 60).round()} min';
    }
    final whole = h.floor();
    final mins = ((h - whole) * 60).round();
    if (mins == 0) return '$whole hr';
    return '$whole hr $mins min';
  }

  void _selectPreset(int index) {
    final preset = _kPresets[index];
    setState(() {
      _presetIndex = index;
      _isCustom = preset.watts == 0; // "Custom…" has watts == 0
      if (!_isCustom) {
        _wattageCtrl.clear();
        _wattageFocus.unfocus();
      } else {
        // Give focus to custom field after frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _wattageFocus.requestFocus();
        });
      }
    });
  }

  @override
  void dispose() {
    _wattageCtrl.dispose();
    _wattageFocus.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Cost Calculator',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Step 1: Choose appliance ──────────────────────
              _SectionLabel(step: '1', label: 'Select Appliance'),
              const SizedBox(height: 12),
              _ApplianceGrid(
                presets: _kPresets,
                selectedIndex: _presetIndex,
                onSelect: _selectPreset,
              ),

              // ── Custom wattage field ──────────────────────────
              if (_isCustom) ...[
                const SizedBox(height: 16),
                _WattageField(
                  controller: _wattageCtrl,
                  focusNode: _wattageFocus,
                  onChanged: (_) => setState(() {}),
                ),
              ],

              const SizedBox(height: 24),

              // ── Step 2: Quantity ──────────────────────────────
              _SectionLabel(step: '2', label: 'Quantity'),
              const SizedBox(height: 12),
              _QuantityStepper(
                value: _quantity,
                onChanged: (v) => setState(() => _quantity = v),
              ),

              const SizedBox(height: 24),

              // ── Step 3: Hours per day ─────────────────────────
              _SectionLabel(
                step: '3',
                label: 'Usage per Day  —  ${_formatHours(_hoursPerDay)}',
              ),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.primary.withValues(alpha: 0.18),
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.12),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _hoursPerDay,
                  min: 0.25,
                  max: 12,
                  divisions: 47, // 0.25-step increments
                  onChanged: (v) => setState(() => _hoursPerDay = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      '15 min',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      '12 hr',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Step 4: Period ────────────────────────────────
              _SectionLabel(step: '4', label: 'Period'),
              const SizedBox(height: 12),
              _PeriodSelector(
                periods: _kPeriods,
                selectedIndex: _periodIndex,
                onSelect: (i) => setState(() => _periodIndex = i),
              ),

              const SizedBox(height: 28),

              // ── Result card ───────────────────────────────────
              _ResultCard(
                hasInput: _hasValidInput,
                totalKwh: _hasValidInput ? _totalKwh : 0,
                estimatedCost: _hasValidInput ? _estimatedCost : 0,
                periodLabel: _kPeriods[_periodIndex].$1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Section label with step badge
// ─────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String step;
  final String label;
  const _SectionLabel({required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF212121),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Appliance grid
// ─────────────────────────────────────────────────────────────────
class _ApplianceGrid extends StatelessWidget {
  final List<_AppliancePreset> presets;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _ApplianceGrid({
    required this.presets,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: presets.length,
      itemBuilder: (context, i) {
        final preset = presets[i];
        final isSelected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  preset.icon,
                  size: 26,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    preset.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF424242),
                    ),
                  ),
                ),
                if (preset.watts > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${preset.watts} W',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white70 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Custom wattage input field
// ─────────────────────────────────────────────────────────────────
class _WattageField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _WattageField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF212121),
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter wattage',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          suffixText: 'W',
          suffixStyle: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.electrical_services_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Quantity stepper
// ─────────────────────────────────────────────────────────────────
class _QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _QuantityStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Number of units',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          Row(
            children: [
              _StepBtn(
                icon: Icons.remove_rounded,
                onTap: value > 1 ? () => onChanged(value - 1) : null,
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              _StepBtn(
                icon: Icons.add_rounded,
                onTap: value < 20 ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.primary : Colors.grey.shade400,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Period selector chips
// ─────────────────────────────────────────────────────────────────
class _PeriodSelector extends StatelessWidget {
  final List<(String, int)> periods;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _PeriodSelector({
    required this.periods,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(periods.length, (i) {
        final isSelected = i == selectedIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: EdgeInsets.only(right: i < periods.length - 1 ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                periods[i].$1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF424242),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Result card
// ─────────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final bool hasInput;
  final double totalKwh;
  final double estimatedCost;
  final String periodLabel;

  const _ResultCard({
    required this.hasInput,
    required this.totalKwh,
    required this.estimatedCost,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: hasInput
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.80),
                ],
              )
            : null,
        color: hasInput ? null : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: hasInput
                ? AppColors.primary.withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: hasInput
          ? Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Estimated Cost — $periodLabel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ResultFigure(
                      label: 'Energy Used',
                      value: '${totalKwh.toStringAsFixed(2)} kWh',
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    _ResultFigure(
                      label: 'Estimated Bill',
                      value: '₹${estimatedCost.toStringAsFixed(0)}',
                      large: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Charge varies per KSEB slab — this is an average estimate.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calculate_outlined,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Select an appliance to see the estimate',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ResultFigure extends StatelessWidget {
  final String label;
  final String value;
  final bool large;
  const _ResultFigure({
    required this.label,
    required this.value,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: large ? 30 : 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
