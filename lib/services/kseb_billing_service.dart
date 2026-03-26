class KSEBBillingService {
  static double calculateEnergyCharge(double units) {
    if (units <= 250) {
      return _telescopic(units);
    } else {
      return _nonTelescopic(units);
    }
  }

  static double _telescopic(double units) {
    double cost = 0;

    if (units > 200) {
      cost += (units - 200) * 8.50;
      units = 200;
    }

    if (units > 150) {
      cost += (units - 150) * 7.20;
      units = 150;
    }

    if (units > 100) {
      cost += (units - 100) * 5.35;
      units = 100;
    }

    if (units > 50) {
      cost += (units - 50) * 4.25;
      units = 50;
    }

    cost += units * 3.35;

    return cost;
  }

  static double _nonTelescopic(double units) {
    if (units <= 300) {
      return units * 6.75;
    }

    if (units <= 350) {
      return units * 7.60;
    }

    return units * 9.20;
  }

  static double calculateTotalBill(double units) {
    final energyCharge = calculateEnergyCharge(units);

    final duty = energyCharge * 0.10;

    final fuel = units * 0.08;

    final fixed = _fixedCharge(units);

    final meterRent = 6;

    return energyCharge + duty + fuel + fixed + meterRent;
  }

  static double _fixedCharge(double units) {
    if (units <= 50) return 50;
    if (units <= 100) return 85;
    if (units <= 150) return 105;
    if (units <= 200) return 140;
    if (units <= 250) return 160;
    if (units <= 300) return 220;
    if (units <= 350) return 240;

    return 310;
  }
}
