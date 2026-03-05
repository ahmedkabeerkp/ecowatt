import 'package:eco_watt/screens/appliances_screen.dart';
import 'package:eco_watt/screens/auth_screen.dart';
import 'package:eco_watt/screens/home_screen.dart';
import 'package:eco_watt/screens/meter_setup_screen.dart';
import 'package:eco_watt/screens/profile_completion.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  void _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final userData = userDoc.data();

      if (userData == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileCompletion()),
        );
        return;
      }

      if (userData['profileCompleted'] != true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileCompletion()),
        );
        return;
      }

      if (userData['meterSetupCompleted'] != true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MeterSetupScreen()),
        );
        return;
      }
      if (userData['appliancesSetupScreen'] != true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AppliancesScreen()),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: SizedBox.expand(
          child: Image.asset('lib/assets/images/splash.png', fit: BoxFit.cover),
        ),
      ),
    );
  }
}
