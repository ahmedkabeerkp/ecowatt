import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}

// Future<void> _logout() async {
//   await FirebaseAuth.instance.signOut();

//   if (!mounted) return;

//   Navigator.pushReplacement(
//     context,
//     MaterialPageRoute(builder: (context) => const AuthScreen()),
//   );
// }
