class EnergyCalculator {
  static double calculateUnits({
    required int watts,
    required int quantity,
    required double hours,
  }) {
    return (watts * quantity * hours) / 1000;
  }

  static double calculateDurationHours(DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    return end.difference(start).inMinutes / 60.0;
  }

  static double calculateDailyUsage(List<Map<String, dynamic>> appliances) {
    double total = 0;

    for (var item in appliances) {
      final watts = item["wattage"];
      final quantity = item["quantity"];

      final start = item["start"];
      final end = item["end"];

      final hours = calculateDurationHours(start, end);

      total += calculateUnits(watts: watts, quantity: quantity, hours: hours);
    }

    return total;
  }
}
