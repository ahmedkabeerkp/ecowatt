import 'package:eco_watt/screens/auth_screen.dart';
import 'package:eco_watt/screens/home_screen.dart';
import 'package:eco_watt/screens/profile_completion.dart';
import 'package:eco_watt/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SplashScreen(),

      debugShowCheckedModeBanner: false,

      routes: {
        '/signup': (context) => const AuthScreen(),
        '/home': (context) => HomeScreen(),
        '/complete_profile': (context) => ProfileCompletion(),
      },
    );
  }
}
