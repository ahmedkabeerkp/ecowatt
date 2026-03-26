import 'package:eco_watt/screens/appliances_screen.dart';
import 'package:eco_watt/screens/auth_screen.dart';
import 'package:eco_watt/screens/home_screen.dart';
import 'package:eco_watt/screens/meter_calibration_screen.dart';
import 'package:eco_watt/screens/meter_setup_screen.dart';
import 'package:eco_watt/screens/profile_completion.dart';
import 'package:eco_watt/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutBack),
      ),
    );

    FlutterNativeSplash.remove();
    _controller.forward();

    // Wait for first frame before navigating — prevents navigator lock error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('Splash: no user → AuthScreen');
        _navigate(const AuthScreen());
        return;
      }

      // user.reload() with timeout — won't hang forever on slow connection
      try {
        await user.reload().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Splash: user.reload() timed out or failed: $e');
        // Non-fatal — continue with cached state
      }

      final refreshed = FirebaseAuth.instance.currentUser;

      final bool isGoogleUser =
          refreshed?.providerData.any(
            (info) => info.providerId == 'google.com',
          ) ??
          false;

      if (refreshed != null && !refreshed.emailVerified && !isGoogleUser) {
        await FirebaseAuth.instance.signOut();
        debugPrint('Splash: email not verified → AuthScreen');
        _navigate(const AuthScreen());
        return;
      }

      // Firestore fetch with timeout
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      final userData = userDoc.data();
      debugPrint('Splash: userData loaded, routing...');

      if (userData == null || userData['profileCompleted'] != true) {
        _navigate(const ProfileCompletion());
        return;
      }
      if (userData['meterSetupCompleted'] != true) {
        _navigate(const MeterSetupScreen());
        return;
      }
      if (userData['appliancesSetupCompleted'] != true) {
        _navigate(const AppliancesScreen());
        return;
      }
      if (_isCalibrationDue(userData)) {
        _navigate(const MeterCalibrationScreen(isMandatoryPopup: true));
        return;
      }

      debugPrint('Splash: → HomeScreen');
      _navigate(const HomeScreen());
    } catch (e) {
      debugPrint('Splash: error → AuthScreen: $e');
      _navigate(const AuthScreen());
    }
  }

  bool _isCalibrationDue(Map<String, dynamic> userData) {
    final DateTime cycleStart =
        (userData['billingStartDate'] as Timestamp?)?.toDate() ??
        (userData['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final int cycleDays = (userData['billingCycle'] as String?) == '1 Month'
        ? 30
        : 60;
    final DateTime cycleEnd = cycleStart.add(Duration(days: cycleDays));
    if (DateTime.now().isBefore(cycleEnd)) return false;
    final DateTime? lastCalibration =
        (userData['lastCalibrationDate'] as Timestamp?)?.toDate();
    if (lastCalibration == null) return true;
    if (lastCalibration.isBefore(cycleEnd)) return true;
    return false;
  }

  void _navigate(Widget screen) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Image.asset(
              'assets/images/splash_logo.png',
              width: 160,
              height: 160,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
