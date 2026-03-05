class ApplianceItem {
  final String name;
  final String wattageLabel;
  final int wattage;
  final String category;
  final String icon;
  int quantity;

  ApplianceItem({
    required this.name,
    required this.wattageLabel,
    required this.wattage,
    required this.category,
    required this.icon,
    this.quantity = 0,
  });
}

List<ApplianceItem> buildApplianceList() => [
  //Cooling
  ApplianceItem(
    name: 'Air Conditioner',
    wattageLabel: '1500',
    wattage: 1500,
    category: 'Cooling',
    icon: 'ac',
  ),
  ApplianceItem(
    name: 'Ceiling Fan',
    wattageLabel: '75',
    wattage: 75,
    category: 'Cooling',
    icon: 'fan',
  ),
  ApplianceItem(
    name: 'Table Fan',
    wattageLabel: '50',
    wattage: 50,
    category: 'Cooling',
    icon: 'fan',
  ),
  ApplianceItem(
    name: 'Air Cooler',
    wattageLabel: '200',
    wattage: 200,
    category: 'Cooling',
    icon: 'cooler',
  ),

  //Heating
  ApplianceItem(
    name: 'Water Heater',
    wattageLabel: '2000',
    wattage: 2000,
    category: 'Heating',
    icon: 'heater',
  ),
  ApplianceItem(
    name: 'Room Heater',
    wattageLabel: '1500',
    wattage: 1500,
    category: 'Heating',
    icon: 'heater',
  ),
  ApplianceItem(
    name: 'Electric Iron',
    wattageLabel: '1000',
    wattage: 1000,
    category: 'Heating',
    icon: 'iron',
  ),

  //Kitchen
  ApplianceItem(
    name: 'Refrigerator',
    wattageLabel: '150 - 250',
    wattage: 200,
    category: 'Kitchen',
    icon: 'fridge',
  ),
  ApplianceItem(
    name: 'Microwave',
    wattageLabel: '1200',
    wattage: 1200,
    category: 'Kitchen',
    icon: 'microwave',
  ),
  ApplianceItem(
    name: 'Mixer / Grinder',
    wattageLabel: '750',
    wattage: 750,
    category: 'Kitchen',
    icon: 'mixer',
  ),
  ApplianceItem(
    name: 'Electric Kettle',
    wattageLabel: '1500',
    wattage: 1500,
    category: 'Kitchen',
    icon: 'kettle',
  ),
  ApplianceItem(
    name: 'Toaster',
    wattageLabel: '800',
    wattage: 800,
    category: 'Kitchen',
    icon: 'toaster',
  ),
  ApplianceItem(
    name: 'Induction Cooktop',
    wattageLabel: '2000',
    wattage: 2000,
    category: 'Kitchen',
    icon: 'induction',
  ),
  ApplianceItem(
    name: 'Dishwasher',
    wattageLabel: '1200',
    wattage: 1200,
    category: 'Kitchen',
    icon: 'dishwasher',
  ),

  //Lighting
  ApplianceItem(
    name: 'LED Bulb',
    wattageLabel: '10',
    wattage: 10,
    category: 'Lighting',
    icon: 'bulb',
  ),
  ApplianceItem(
    name: 'Tube Light',
    wattageLabel: '40',
    wattage: 40,
    category: 'Lighting',
    icon: 'bulb',
  ),
  ApplianceItem(
    name: 'CFL',
    wattageLabel: '25',
    wattage: 25,
    category: 'Lighting',
    icon: 'bulb',
  ),

  //Entertainment
  ApplianceItem(
    name: 'Television',
    wattageLabel: '150',
    wattage: 150,
    category: 'Entertainment',
    icon: 'tv',
  ),
  ApplianceItem(
    name: 'Computer / Desktop',
    wattageLabel: '300',
    wattage: 300,
    category: 'Entertainment',
    icon: 'computer',
  ),
  ApplianceItem(
    name: 'Laptop',
    wattageLabel: '65',
    wattage: 65,
    category: 'Entertainment',
    icon: 'laptop',
  ),

  //Others
  ApplianceItem(
    name: 'Washing Machine',
    wattageLabel: '500 - 1000',
    wattage: 750,
    category: 'Others',
    icon: 'washer',
  ),
  ApplianceItem(
    name: 'Water Pump',
    wattageLabel: '750',
    wattage: 750,
    category: 'Others',
    icon: 'pump',
  ),
  ApplianceItem(
    name: 'EV Charger',
    wattageLabel: '2000',
    wattage: 2000,
    category: 'Others',
    icon: 'ev',
  ),
  ApplianceItem(
    name: 'Vacuum Cleaner',
    wattageLabel: '1000',
    wattage: 1000,
    category: 'Others',
    icon: 'vacuum',
  ),
];
