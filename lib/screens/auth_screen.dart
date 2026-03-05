import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_watt/screens/appliances_screen.dart';
import 'package:eco_watt/screens/home_screen.dart';
import 'package:eco_watt/screens/meter_setup_screen.dart';
import 'package:eco_watt/screens/profile_completion.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eco_watt/constants/colors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String? _errorMessage;
  bool _isLogin = true;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  Future<void> _submitForm() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Please fill all fields";
        _isLoading = false;
      });
      return;
    }
    if (!_isLogin && name.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your name";
        _isLoading = false;
      });
    }

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;
        await _navigateAfterLogin();
      } else {
        print("Creating user account...");
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        print("user created: ${userCredential.user!.uid}");

        print("Creating firestore document...");
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'uid': userCredential.user!.uid,
              'email': email,
              'name': _nameController.text.trim(),
              'profileCompleted': false,
              'meterSetupCompleted': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
        print("Firestore document created successfully");
        if (!mounted) {
          print("Widget not mounted");
          return;
        }

        print("Navigating to profileCompletion...");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileCompletion()),
        );
        print("Navigation completed!");
      }
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException: ${e.code} - ${e.message}");
      if (!mounted) return;

      // print("FIREBASE ERROR CODE: ${e.code}");
      // print("FIREBASE ERROR MESSAGE: ${e.message}");

      setState(() {
        _isLoading = false;
        if (e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'INVALID_LOGIN_CREDENTIALS') {
          _errorMessage = "User does not exist. Please Sign Up.";
        } else if (e.code == 'weak-password') {
          _errorMessage = "Password should be at least 6 characters.";
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = "This email is already registered";
        } else {
          _errorMessage = e.message;
        }
      });
    } catch (e) {
      print("General error: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "An error occured: ${e.toString()}";
      });
    }
  }

  Future<void> _navigateAfterLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
      if (userData['appliancesSetupCompleted'] != true) {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.bolt_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Welcome to EcoWatt",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Monitor your electricity usage and savings",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildToggleSwitch(),
                      const SizedBox(height: 25),

                      AnimatedSwitcher(
                        duration: const Duration(microseconds: 300),
                        child: _isLogin
                            ? _buildLoginForm()
                            : _buildSignUpForm(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(25),
      ),

      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isLogin = false;
                  _errorMessage = null;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: !_isLogin ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Sign up",
                  style: TextStyle(
                    color: !_isLogin ? Colors.white : AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isLogin = true;
                  _errorMessage = null;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _isLogin ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Login",
                  style: TextStyle(
                    color: _isLogin ? Colors.white : AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey("Login"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _emailController,
          hint: "Enter your email",
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _passwordController,
          hint: "Enter your password",
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        SizedBox(height: 20),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  //fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Sign In", style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      key: const ValueKey("signup"),
      children: [
        _buildTextField(
          controller: _nameController,
          hint: "Full Name",
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _emailController,
          hint: "Enter your email",
          icon: Icons.email_outlined,
        ),
        SizedBox(height: 20),
        _buildTextField(
          controller: _passwordController,
          hint: "Create Password",
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        SizedBox(height: 20),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  //fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Create Account", style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? !_isPasswordVisible : false,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Colors.grey),
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                )
              : null,
        ),
      ),
    );
  }
}
