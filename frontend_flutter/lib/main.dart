import 'package:flutter/material.dart';
import '/features/admin/events/presentation/screens/event_list_screen.dart';
import 'core/config/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/features/admin/venues/presentation/screens/venue_list_screen.dart';
import 'dart:html' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final token = html.window.localStorage['token'];

  runApp(MyApp(initialRoute: token != null ? AppRoutes.dashboard : AppRoutes.login));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      onGenerateRoute: AppRoutes.generateRoute,
      routes: {
        "/admin/events": (context) => const EventListScreen(), 
        "/admin/venues": (context) => const VenueListScreen(),
      },
        // Define any static routes here if needed
       // AppRoutes.login: (context) => const LoginScreen(), // Example static route
       // AppRoutes.dashboard: (context) => const DashboardScreen(), // Example static route
       // Add more static routes as needed
       // Note: Dynamic routes with parameters should be handled in onGenerateRoute
    );
  }
}