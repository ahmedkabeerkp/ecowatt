// ─────────────────────────────────────────────────────────────────
// Appliance Behavior Types
// ─────────────────────────────────────────────────────────────────

enum ApplianceType {
  /// Runs 24/7 — no schedule needed. Usage estimated via duty cycle.
  /// Example: Refrigerator
  alwaysOn,

  /// Has a fixed daily start/end time. Usage estimated via schedule × accuracy factor.
  /// Example: AC, Fan, TV, Water Heater
  scheduled,

  /// Used a few times per week with no fixed time. Estimated via weekly frequency × duration.
  /// Example: Iron, Washing Machine, Microwave, Mixer
  occasional;

  String get firestoreValue {
    switch (this) {
      case ApplianceType.alwaysOn:
        return 'alwaysOn';
      case ApplianceType.occasional:
        return 'occasional';
      case ApplianceType.scheduled:
        return 'scheduled';
    }
  }

  static ApplianceType fromString(String? s) {
    switch (s) {
      case 'alwaysOn':
        return ApplianceType.alwaysOn;
      case 'occasional':
        return ApplianceType.occasional;
      default:
        return ApplianceType.scheduled;
    }
  }

  String get displayLabel {
    switch (this) {
      case ApplianceType.alwaysOn:
        return 'Always On';
      case ApplianceType.occasional:
        return 'Occasional';
      case ApplianceType.scheduled:
        return 'Scheduled';
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// ApplianceItem Model
// ─────────────────────────────────────────────────────────────────

class ApplianceItem {
  final String name;
  final String category;
  final String icon;
  int wattage; // mutable — user can edit
  int quantity;
  final ApplianceType applianceType;

  /// For [alwaysOn]: fraction of 24h the appliance actually draws power.
  /// e.g. Refrigerator compressor runs ~35% of the time → dutyCycle = 0.35
  final double dutyCycle;

  /// For [occasional]: typical number of uses per week (default estimate).
  /// Used to pre-fill the schedule screen and as fallback when user hasn't confirmed.
  final double defaultWeeklyUses;

  /// For [occasional]: typical duration per single use in hours (default estimate).
  /// e.g. Microwave = 0.17h (10 min), Washing Machine = 1.5h
  final double defaultDurationHours;

  ApplianceItem({
    required this.name,
    required this.category,
    required this.icon,
    required this.wattage,
    this.quantity = 0,
    this.applianceType = ApplianceType.scheduled,
    this.dutyCycle = 1.0,
    this.defaultWeeklyUses = 3.0,
    this.defaultDurationHours = 1.0,
  });

  /// Display label always reflects current wattage
  String get wattageLabel => wattage.toString();
}

// ─────────────────────────────────────────────────────────────────
// Master Appliance Catalog
// ─────────────────────────────────────────────────────────────────

List<ApplianceItem> buildApplianceList() {
  return [
    // ── Cooling ─────────────────────────────────────────────────
    ApplianceItem(
      name: 'Air Conditioner',
      category: 'Cooling',
      icon: 'ac',
      wattage: 1500,
      applianceType: ApplianceType.scheduled,
    ),
    ApplianceItem(
      name: 'Ceiling Fan',
      category: 'Cooling',
      icon: 'fan',
      wattage: 75,
      applianceType: ApplianceType.scheduled,
    ),
    ApplianceItem(
      name: 'Table Fan',
      category: 'Cooling',
      icon: 'fan',
      wattage: 50,
      applianceType: ApplianceType.scheduled,
    ),
    ApplianceItem(
      name: 'Air Cooler',
      category: 'Cooling',
      icon: 'cooler',
      wattage: 200,
      applianceType: ApplianceType.scheduled,
    ),

    // ── Heating ─────────────────────────────────────────────────
    ApplianceItem(
      name: 'Room Heater',
      category: 'Heating',
      icon: 'heater',
      wattage: 1000,
      applianceType: ApplianceType.scheduled,
    ),
    ApplianceItem(
      name: 'Water Heater',
      category: 'Heating',
      icon: 'waterheater',
      wattage: 2000,
      applianceType: ApplianceType.scheduled,
    ),
    ApplianceItem(
      name: 'Clothes Iron',
      category: 'Heating',
      icon: 'iron',
      wattage: 1000,
      applianceType: ApplianceType.occasional,
      defaultWeeklyUses: 2.0,
      defaultDurationHours: 0.5, // ~30 min per session
    ),

    // ── Kitchen ─────────────────────────────────────────────────
    ApplianceItem(
      name: 'Refrigerator',
      category: 'Kitchen',
      icon: 'fridge',
      wattage: 150,
      applianceType: ApplianceType.alwaysOn,
      dutyCycle: 0.35, // compressor runs ~35% of the day
    ),
    ApplianceItem(
      name: 'Microwave',
      category: 'Kitchen',
      icon: 'microwave',
      wattage: 1200,
      applianceType: ApplianceType.occasional,
      defaultWeeklyUses: 14.0, // ~2× per day
      defaultDurationHours: 0.17, // ~10 min per use
    ),
    ApplianceItem(
      name: 'Mixer / Grinder',
      category: 'Kitchen',
      icon: 'mixer',
      wattage: 750,
      applianceType: ApplianceType.occasional,
      defaultWeeklyUses: 14.0,
      defaultDurationHours: 0.17, // ~10 min
    ),
    ApplianceItem(
      name: 'Electric Kettle',
      category: 'Kitchen',
      icon: 'kettle',
      wattage: 1500,
      applianceType: ApplianceType.occasional,
      defaultWeeklyUses: 14.0,
      defaultDurationHours: 0.08, // ~5 min per boil
    ),
    ApplianceItem(
      name: 'Toaster',
      category: 'Kitchen',
      icon: 'toaster',
      wattage: 800,
      applianceType: ApplianceType.occasional,
      defaultWeeklyUses: 7.0, // once daily
      defaultDurationHours: 0.1, // ~6 min
    ),
    ApplianceItem(
      name: 'Induction Stove',
      category: 'Kitchen',
      icon: 'induction',
      wattage: 1800,
      applianceType: ApplianceType.occasional,
      defaultWeeklyUses: 14.0, // ~2 cooking sessions/day
      defaultDurationHours: 0.5, // 30 min per session
    ),
    ApplianceItem(
      name: 'Dishwasher',
      category: 'Kitchen',
      icon: 'dishwasher',
      wattage: 1200,
      applianceType: ApplianceType.occasional,
      defaultWeeklyUses: 7.0,
      defaultDurationHours: 1.5, // full cycle
    ),

    // ── Lighting ────────────────────────────────────────────────
    ApplianceItem(
      name: 'LED Bulb',
      category: 'Lighting',
      icon: 'bulb',
      wattage: 10,
      applianceType: ApplianceType.scheduled,
    ),
    ApplianceItem(
      name: 'Tube Light',
      category: 'Lighting',
      icon: 'bulb',
      wattage: 40,
      applianceType: ApplianceType.scheduled,
    ),
    ApplianceItem(
      name: 'Street Light',
      category: 'Lighting',
      icon: 'bulb',
      wattage: 70,
      applianceType: ApplianceType.scheduled,
    ),

    // ── Entertainment ───────────────────────────────────────────
    ApplianceItem(
      name: 'Television',
      category: 'Entertainment',
      icon: 'tv',
      wattage: 150,
      applianceType: ApplianceType.scheduled,
    ),
    ApplianceItem(
      name: 'Desktop PC',
      category: 'Entertainment',
      icon: 'computer',
      wattage: 300,
      applianceType: ApplianceType.scheduled,
    ),
    ApplianceItem(
      name: 'Laptop',
      category: 'Entertainment',
      icon: 'laptop',
      wattage: 65,
      applianceType: ApplianceType.scheduled,
    ),

    // ── Others ──────────────────────────────────────────────────
    ApplianceItem(
      name: 'Washing Machine',
      category: 'Others',
      icon: 'washer',
      wattage: 500,
      applianceType: ApplianceType.occasional,
      defaultWeeklyUses: 3.0,
      defaultDurationHours: 1.5, // full wash cycle
    ),
    ApplianceItem(
      name: 'Water Pump',
      category: 'Others',
      icon: 'pump',
      wattage: 750,
      applianceType: ApplianceType.scheduled,
    ),
    ApplianceItem(
      name: 'EV Charger',
      category: 'Others',
      icon: 'ev',
      wattage: 2000,
      applianceType: ApplianceType.scheduled,
    ),
    ApplianceItem(
      name: 'Vacuum Cleaner',
      category: 'Others',
      icon: 'vacuum',
      wattage: 1000,
      applianceType: ApplianceType.occasional,
      defaultWeeklyUses: 2.0,
      defaultDurationHours: 0.5,
    ),
  ];
}
