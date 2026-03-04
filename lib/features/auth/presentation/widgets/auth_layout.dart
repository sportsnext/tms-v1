import 'dart:ui';
import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  final Widget child;
  const AuthLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        /// FULL BACKGROUND GRADIENT
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFDCE3F5),
              Color(0xFF6C8DE8),
              Color(0xFF1E3BB8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: Center(
          child: Stack(
            children: [
              /// BIG ROUNDED GLASS PANEL BEHIND LOGIN BOX
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 650,
                    height: 900,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),

              /// MAIN CONTENT (Login/Register box)
              Center(child: child),
            ],
          ),
        ),
      ),
    );
  }
}