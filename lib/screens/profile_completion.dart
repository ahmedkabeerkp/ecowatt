import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:eco_watt/screens/meter_setup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileCompletion extends StatefulWidget {
  const ProfileCompletion({super.key});

  @override
  State<ProfileCompletion> createState() => _ProfileCompletionState();
}

class _ProfileCompletionState extends State<ProfileCompletion> {
  final _phoneController = TextEditingController();
  final _goalController = TextEditingController();
  bool _isLoading = false;
  String? _phoneError;
  String? _goalError;

  bool _validatePhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (phone.isEmpty) {
      setState(() => _phoneError = "Phone number is required");
      return false;
    }

    if (phone.length < 10 || phone.length > 10) {
      setState(() => _phoneError = "Enter a valid phone number");
      return false;
    }
    setState(() => _phoneError = null);
    return true;
  }

  bool _validateGoal(String goal) {
    if (goal.isEmpty) {
      setState(() => _goalError = "Goal is required");
      return false;
    }
    final goalValue = double.tryParse(goal);
    if (goalValue == null) {
      setState(() => _goalError = "Enter a valid number");
      return false;
    }

    if (goalValue <= 0) {
      setState(() => _goalError = "Goal must be greater than 0");
      return false;
    }

    if (goalValue > 20000) {
      setState(
        () => _goalError = "Goal seems too high. Enter a realistic value",
      );
      return false;
    }
    setState(() => _goalError = null);
    return true;
  }

  Future<void> _completeProfile() async {
    final phone = _phoneController.text.trim();
    final goal = _goalController.text.trim();

    bool isPhoneValid = _validatePhone(phone);
    bool isGoalValid = _validateGoal(goal);

    if (!isPhoneValid || !isGoalValid) {
      return;
    }

    // if (phone.isEmpty || goal.isEmpty) {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(SnackBar(content: Text("Please fill all fields")));
    //   return;
    // }
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      final goalValue = double.parse(goal);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phone': cleanPhone,
        'goal': goalValue,
        'profileCompleted': true,
      }, SetOptions(merge: true));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MeterSetupScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Complete your Profile"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Let's get to know you better",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Please Provide your details to continue",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 40),

              SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (value) {
                  if (_phoneError != null) {
                    setState(() => _phoneError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _phoneError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  hintText: "Enter phone number",
                ),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _goalController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                onChanged: (value) {
                  if (_goalError != null) {
                    setState(() => _goalError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: "Set Goal to save electricity",
                  prefixIcon: Icon(Icons.add_task_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _goalError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  hintText: "e.g., 500",
                  suffixIcon: Icon(Icons.currency_rupee_sharp),
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Color.fromARGB(255, 0, 0, 0),
                        )
                      : const Text("Continue", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _goalController.dispose();
    super.dispose();
  }
}
