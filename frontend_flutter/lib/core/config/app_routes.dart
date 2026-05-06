import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/layout/presentation/screens/admin_dashboard_layout.dart';
import 'package:tms_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:tms_flutter/features/auth/presentation/screens/register_screen.dart';

class AppRoutes {
  static const String login = "/login";
  static const String register = "/register";
  static const String dashboard = "/dashboard";

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

  case dashboard:
    return MaterialPageRoute(builder: (_) => const AdminDashboardLayout());

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text("404 - Page Not Found")),
          ),
        );
    }
  }
}