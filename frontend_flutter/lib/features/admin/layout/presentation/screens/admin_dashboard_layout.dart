import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/dashboard/presentation/screens/dashboard_screen.dart';

class AdminDashboardLayout extends StatefulWidget {
  const AdminDashboardLayout({super.key});

  @override
  State<AdminDashboardLayout> createState() => _AdminDashboardLayoutState();
}

class _AdminDashboardLayoutState extends State<AdminDashboardLayout> {
  // Active screen
  Widget currentScreen = const DashboardScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),

      body: Row(
        children: [
          // ---------------------------------------------------------
          // LEFT SIDEBAR
          // ---------------------------------------------------------
          Container(
            width: 240,
            color: const Color(0xFF0D47A1),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // LOGO
                Image.asset(
                  "assets/images/logo.png",
                  height: 70,
                ),

                const SizedBox(height: 40),

                // SIDEBAR BUTTONS
                _sidebarButton("Dashboard", Icons.dashboard, () {
                  setState(() {
                    currentScreen = const DashboardScreen();
                  });
                }),

                _sidebarButton("Tournaments", Icons.sports_cricket, () {}),

                _sidebarButton("Teams", Icons.groups, () {}),

                _sidebarButton("Players", Icons.person, () {}),

                _sidebarButton("Events", Icons.event, () {}),

                _sidebarButton("Venues", Icons.location_on, () {}),

                const Spacer(),

                // LOGOUT
                _sidebarButton("Logout", Icons.logout, () {
                  Navigator.pushReplacementNamed(context, "/login");
                }),
              ],
            ),
          ),

          // ---------------------------------------------------------
          // MAIN SCREEN AREA (HEADER + CONTENT)
          // ---------------------------------------------------------
          Expanded(
            child: Column(
              children: [
                // ---------- HEADER ----------
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "Admin Panel",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.notifications_outlined, size: 28),
                          SizedBox(width: 14),
                          CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text("A"),
                          )
                        ],
                      )
                    ],
                  ),
                ),

                // ---------- MAIN CONTENT ----------
                Expanded(
                  child: currentScreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // SIDEBAR BUTTON WIDGET
  Widget _sidebarButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            )
          ],
        ),
      ),
    );
  }
}