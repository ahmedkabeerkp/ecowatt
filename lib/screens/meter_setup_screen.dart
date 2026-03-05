import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/screens/appliances_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class MeterSetupScreen extends StatefulWidget {
  const MeterSetupScreen({super.key});

  @override
  State<MeterSetupScreen> createState() => _MeterSetupScreenState();
}

class _MeterSetupScreenState extends State<MeterSetupScreen> {
  final _consumedUnitsController = TextEditingController();
  final _connectedLoadController = TextEditingController();

  String? _selectedTariff;
  String? _selectedPurpose;
  String _billingCycle = '2 Month';
  String _phase = 'Single Phase';
  bool _isLoading = false;

  String? _consumedUnitsError;
  String? _connectedLoadError;

  final List<String> _tariffOptions = [
    'Domestic',
    'Commercial',
    'Industrial',
    'Agricultural',
  ];

  final List<String> _purposeOptions = [
    'Residential',
    'Office',
    'Shop',
    'Factory',
    'Farm',
    'Other',
  ];

  bool _validateConsumedUnits(String units) {
    if (units.isEmpty) {
      setState(() => _consumedUnitsError = "Consumption is required");
      return false;
    }

    final unitsValue = double.tryParse(units);
    if (unitsValue == null) {
      setState(() => _consumedUnitsError = "Enter a Valid Number");
      return false;
    }

    if (unitsValue < 0) {
      setState(() => _consumedUnitsError = "Cannot be negative");
      return false;
    }

    if (unitsValue > 100000) {
      setState(() => _consumedUnitsError = "Value seems too high");
      return false;
    }

    setState(() => _consumedUnitsError = null);
    return true;
  }

  bool _validateConnectedLoad(String load) {
    if (load.isEmpty) {
      setState(() => _connectedLoadError = "Load is required");
      return false;
    }

    final loadValue = double.tryParse(load);
    if (loadValue == null) {
      setState(() => _connectedLoadError = "Enter a Valid Number");
      return false;
    }

    if (loadValue < 0) {
      setState(() => _connectedLoadError = "Must be greater than 0");
      return false;
    }

    if (loadValue > 50000) {
      setState(() => _connectedLoadError = "Value seems too high");
      return false;
    }

    setState(() => _connectedLoadError = null);
    return true;
  }

  Future<void> _submitMeterSetup() async {
    final consumedUnits = _consumedUnitsController.text.trim();
    final connectedLoad = _connectedLoadController.text.trim();

    bool isConsumedUnitsValid = _validateConsumedUnits(consumedUnits);
    bool isConnectedLoadValid = _validateConnectedLoad(connectedLoad);

    if (_selectedTariff == null || _selectedPurpose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select Tariff and Purpose"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!isConsumedUnitsValid || !isConnectedLoadValid) {
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("user not logged in")));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'tariff': _selectedTariff,
        'purpose': _selectedPurpose,
        'billingCycle': _billingCycle,
        'consumedUnits': double.parse(consumedUnits),
        'connectedLoad': double.parse(connectedLoad),
        'phase': _phase,
        'meterSetupCompleted': true,
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const AppliancesScreen(),
        ), //changed after
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Meter Setup"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Setup your Electricity Meter",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter your meter details to start tracking",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              const Text(
                "Tariff",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButton<String>(
                  value: _selectedTariff,
                  hint: const Text("Select Tariff"),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _tariffOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() => _selectedTariff = newValue);
                  },
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                "Purpose",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButton<String>(
                  value: _selectedPurpose,
                  hint: const Text("Select Purpose"),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _purposeOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() => _selectedPurpose = newValue);
                  },
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                "Billing Cycle",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildRadioOption(
                      title: '2 Month',
                      value: '2 Month',
                      groupValue: _billingCycle,
                      onChanged: (value) {
                        setState(() => _billingCycle = value!);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildRadioOption(
                      title: '1 Month',
                      value: '1 Month',
                      groupValue: _billingCycle,
                      onChanged: (value) {
                        setState(() => _billingCycle = value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                "Consumed Units",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _consumedUnitsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                onChanged: (value) {
                  if (_consumedUnitsError != null) {
                    setState(() => _consumedUnitsError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: "Enter consumed units",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  errorText: _consumedUnitsError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  suffixText: "kWh",
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Connected Load in Watts",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _connectedLoadController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                onChanged: (value) {
                  if (_connectedLoadError != null) {
                    setState(() => _connectedLoadError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: "Enter connected load",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  errorText: _connectedLoadError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  suffixText: "W",
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Phase",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildRadioOption(
                      title: 'Single Phase',
                      value: 'Single Phase',
                      groupValue: _phase,
                      onChanged: (value) {
                        setState(() => _phase = value!);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildRadioOption(
                      title: 'Three Phase',
                      value: 'Three Phase',
                      groupValue: _phase,
                      onChanged: (value) {
                        setState(() => _phase = value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitMeterSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Submit",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;

    return GestureDetector(
      onTap: () => onChanged(value),

      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _consumedUnitsController.dispose();
    _connectedLoadController.dispose();
    super.dispose();
  }
}
