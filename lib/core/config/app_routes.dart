import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/layout/presentation/screens/admin_dashboard_layout.dart';
import 'package:tms_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:tms_flutter/features/auth/presentation/screens/register_screen.dart';
import 'package:tms_flutter/features/admin/dashboard/presentation/screens/past_tournaments_screen.dart';

class AppRoutes {
  static const String login           = '/login';
  static const String register        = '/register';
  static const String dashboard       = '/admin/dashboard';
  static const String pastTournaments = '/admin/past-tournaments';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return _fade(const LoginScreen());
      case register:
        return _fade(const RegisterScreen());
      case dashboard:
        return _fade(const AdminDashboardLayout());
      case pastTournaments:
        return _fade(const AdminDashboardLayout(
          initialScreen: PastTournamentsScreen(),
        ));
      default:
        return _fade(
          const Scaffold(
            body: Center(
              child: Text("404 - Page Not Found",
                  style: TextStyle(fontSize: 20, color: Colors.grey)),
            ),
          ),
        );
    }
  }

  static PageRouteBuilder _fade(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      );
}