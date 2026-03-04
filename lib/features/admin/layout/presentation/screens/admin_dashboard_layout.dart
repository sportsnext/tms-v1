import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/layout/presentation/widgets/sidebar.dart';
import 'package:tms_flutter/features/admin/layout/presentation/widgets/header.dart';
import 'package:tms_flutter/features/admin/dashboard/presentation/screens/dashboard_screen.dart';

// TODO: uncomment as you build each screen
// import 'package:tms_flutter/features/admin/events/presentation/screens/event_list_screen.dart';
// import 'package:tms_flutter/features/admin/venues/presentation/screens/venue_list_screen.dart';

class AdminDashboardLayout extends StatefulWidget {
  /// Optional — used only when navigating from a route (e.g. /admin/past-tournaments)
  /// Header and sidebar navigation do NOT use this — they use callbacks instead.
  final Widget? initialScreen;

  const AdminDashboardLayout({super.key, this.initialScreen});

  @override
  State<AdminDashboardLayout> createState() => _AdminDashboardLayoutState();
}

class _AdminDashboardLayoutState extends State<AdminDashboardLayout> {
  // Sidebar active highlight
  String _sidebarRoute = SidebarRoutes.dashboard;

  // The widget currently shown in the content area
  late Widget _currentScreen;

  @override
  void initState() {
    super.initState();
    // If a specific screen was passed via route (e.g. past-tournaments),
    // show that — otherwise show dashboard
    _currentScreen = widget.initialScreen ?? const DashboardScreen();
  }

  // ── Called by Sidebar ──────────────────────────────────────
  void _onSidebarRouteChanged(String route) {
    setState(() {
      _sidebarRoute  = route;
      _currentScreen = _screenForSidebarRoute(route);
    });
  }

  // ── Called by Header (My Profile / Settings / Notifications) ─
  // Sidebar highlight stays unchanged — only content area changes
  void _onHeaderNavigation(Widget screen) {
    setState(() => _currentScreen = screen);
  }

  // ── Sidebar route → screen mapping ────────────────────────
  Widget _screenForSidebarRoute(String route) {
    switch (route) {
      case SidebarRoutes.dashboard:
        return const DashboardScreen();
      // TODO: uncomment as you build each screen
      // case SidebarRoutes.eventMaster:
      //   return const EventListScreen();
      // case SidebarRoutes.sportsMaster:
      //   return const SportsListScreen();
      // case SidebarRoutes.playerMaster:
      //   return const PlayerListScreen();
      // case SidebarRoutes.teamManagement:
      //   return const TeamListScreen();
      // case SidebarRoutes.venueMaster:
      //   return const VenueListScreen();
      // case SidebarRoutes.userManagement:
      //   return const UserListScreen();
      // case SidebarRoutes.tournamentModule:
      //   return const TournamentListScreen();
      // case SidebarRoutes.reports:
      //   return const ReportsScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: Row(
        children: [
          // ── LEFT SIDEBAR ─────────────────────────────────
          Sidebar(
            currentRoute: _sidebarRoute,
            onRouteChanged: _onSidebarRouteChanged,
          ),

          // ── RIGHT: Header + Content ───────────────────────
          Expanded(
            child: Column(
              children: [
                Header(
                  userName: "Admin User",
                  profileImage: "",
                  onNavigate: _onHeaderNavigation,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeIn,
                    switchOutCurve: Curves.easeOut,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: KeyedSubtree(
                      key: ValueKey(_currentScreen.runtimeType),
                      child: _currentScreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}