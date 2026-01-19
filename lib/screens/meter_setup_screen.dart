import 'package:eco_watt/constants/colors.dart';
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
  Future<void> _submitMeterSetup() async {
    final consumedUnits = _consumedUnitsController.text.trim();
    final connectedLoad = _connectedLoadController.text.trim();
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
}

Widget _buildRadioOption({
  required String title,
  required String value,
  required String groupValue,
  required ValueChanged<String?> onChanged,
}) {
  final isSelected = value == groupValue;

  return GestureDetector(onTap: () => onChanged(value));
}
