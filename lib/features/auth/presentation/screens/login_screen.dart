import 'package:flutter/material.dart';
import 'package:tms_flutter/core/utils/validators.dart';
import 'package:tms_flutter/features/auth/data/fake_auth_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool loading = false;
  String? errorMessage;

  // HOVER EFFECT
  bool isHovering = false;

  Future<void> handleLogin() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    // VALIDATION
    final emailError = Validators.validateEmail(emailCtrl.text.trim());
    final passError = Validators.validatePassword(passwordCtrl.text.trim());

    if (emailError != null || passError != null) {
      setState(() {
        errorMessage = emailError ?? passError;
        loading = false;
      });
      return;
    }

    // FAKE LOGIN API
    final res = await FakeAuthAPI.login(
      email: emailCtrl.text.trim(),
      password: passwordCtrl.text.trim(),
    );

    setState(() => loading = false);

    if (res["success"]) {
      Navigator.pushReplacementNamed(context, "/admin/dashboard");
    } else {
      setState(() => errorMessage = res["message"]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          width: size.width,
          height: size.height,
          padding: const EdgeInsets.symmetric(horizontal: 24),
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

          child: Center(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                  )
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
                  const SizedBox(height: 20),

                  const Text(
                    "Welcome Back",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    "Login to your account",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // EMAIL
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Email",
                      style: TextStyle(color: Colors.white),
                    ),
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
                      hintText: "Enter your email",
                    ),
                  ),

                  const SizedBox(height: 20),

                  // PASSWORD
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Password",
                      style: TextStyle(color: Colors.white),
                    ),
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

                  // ERROR MESSAGE
                  if (errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // LOGIN BUTTON WITH HOVER
                  MouseRegion(
                    onEnter: (_) => setState(() => isHovering = true),
                    onExit: (_) => setState(() => isHovering = false),

                    child: GestureDetector(
                      onTap: loading ? null : handleLogin,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 48,
                        alignment: Alignment.center,
                        transform: isHovering
                            ? (Matrix4.identity()..scale(1.03))
                            : Matrix4.identity(),

                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.pink, Colors.purple],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pink.withOpacity(0.3),
                              blurRadius: isHovering ? 15 : 10,
                            )
                          ],
                        ),

                        child: Text(
                          loading ? "Logging in..." : "Login",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // REGISTER LINK
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, "/register"),
                    child: const Text(
                      "New user? Create an account",
                      style: TextStyle(
                        color: Colors.pinkAccent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
}