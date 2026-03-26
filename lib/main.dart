import 'package:eco_watt/screens/auth_screen.dart';
import 'package:eco_watt/screens/home_screen.dart';
import 'package:eco_watt/screens/profile_completion.dart';
import 'package:eco_watt/screens/splash_screen.dart';
import 'package:eco_watt/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:eco_watt/services/notification_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  tz.initializeTimeZones();
  await NotificationService.initialize();
  await NotificationService.requestPermissions();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/signup': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
        '/complete_profile': (context) => const ProfileCompletion(),
      },
    );
  }
}
