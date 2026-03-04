import 'package:flutter/material.dart';
import 'package:tms_flutter/core/utils/validators.dart';
import 'package:tms_flutter/features/auth/data/fake_auth_api.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool loading = false;
  String? errorMessage;

  Future<void> handleRegister() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    // VALIDATION
    final nameError = Validators.validateName(nameCtrl.text.trim());
    final emailError = Validators.validateEmail(emailCtrl.text.trim());
    final passError = Validators.validatePassword(passwordCtrl.text.trim());

    if (nameError != null || emailError != null || passError != null) {
      setState(() {
        errorMessage = nameError ?? emailError ?? passError;
        loading = false;
      });
      return;
    }

    // FAKE API
    final res = await FakeAuthAPI.register(
      fullName: nameCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      password: passwordCtrl.text.trim(),
      role: 'user',
    );

    setState(() => loading = false);

    if (res["success"]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful! Please login.")),
      );
      Navigator.pushReplacementNamed(context, "/login");
    } else {
      setState(() => errorMessage = res["message"]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0D47A1),
                Color(0xFF1976D2),
                Color(0xFF42A5F5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),

          // FIXED: SingleChildScrollView prevents overflow
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),

            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),

                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 18,
                      ),
                    ],
                  ),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Image.asset(
                        "assets/images/logo.png",
                        height: 70,
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        "Create Account",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        "Register to continue",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 25),

                      // FULL NAME
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Full Name",
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 6),

                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: "Enter full name",
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Email",
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 6),

                      TextField(
                        controller: emailCtrl,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: "Enter email",
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Password",
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 6),

                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: "Enter password",
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // FIX: No overflow even on small screens
                      GestureDetector(
                        onTap: loading ? null : handleRegister,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.yellow, Colors.orange],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            loading ? "Registering..." : "Register",
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, "/login");
                        },
                        child: const Text(
                          "Already have an account? Login",
                          style: TextStyle(
                            color: Colors.yellowAccent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}