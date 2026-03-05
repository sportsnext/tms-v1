import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/layout/presentation/widgets/sidebar.dart';
import 'package:tms_flutter/features/admin/layout/presentation/widgets/header.dart';
import 'package:tms_flutter/features/admin/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:tms_flutter/features/admin/venues/presentation/screens/venue_list_screen.dart';
import 'package:tms_flutter/features/admin/events/presentation/screens/event_list_screen.dart';
// TODO: uncomment as you build each screen
// import 'package:tms_flutter/features/admin/venues/presentation/screens/venue_list_screen.dart';

class AdminDashboardLayout extends StatefulWidget {
  final Widget? initialScreen;
  const AdminDashboardLayout({super.key, this.initialScreen});

  @override
  State<AdminDashboardLayout> createState() => _AdminDashboardLayoutState();
}

class _AdminDashboardLayoutState extends State<AdminDashboardLayout> {
  String _sidebarRoute = SidebarRoutes.dashboard;
  late Widget _currentScreen;

  @override
  void initState() {
    super.initState();
    _currentScreen = widget.initialScreen ?? _buildDashboard();
  }

  // ── Build Dashboard with onNavigate wired ─────────────────
  // Always build via this method so onNavigate is always fresh
  Widget _buildDashboard() {
    return DashboardScreen(
      onNavigate: _navigateTo,
    );
  }

  // ── Single navigation method used by EVERYONE ─────────────
  // Header passes screen only (no sidebarRoute change)
  // Dashboard quick actions pass both screen + sidebarRoute
  void _navigateTo(Widget screen, String sidebarRoute) {
    setState(() {
      _sidebarRoute  = sidebarRoute;
      _currentScreen = screen;
    });
  }

  // ── Called by Sidebar ─────────────────────────────────────
  void _onSidebarRouteChanged(String route) {
    setState(() {
      _sidebarRoute  = route;
      _currentScreen = _screenForRoute(route);
    });
  }

  // ── Called by Header ──────────────────────────────────────
  // Sidebar highlight stays, only content changes
  void _onHeaderNavigation(Widget screen) {
    setState(() => _currentScreen = screen);
  }

  // ── Route → Screen map ────────────────────────────────────
  Widget _screenForRoute(String route) {
    switch (route) {
      case SidebarRoutes.dashboard:
        return _buildDashboard();
      case SidebarRoutes.eventMaster:
        return const EventListScreen();
      // TODO: uncomment as you build each screen
      case SidebarRoutes.venueMaster:
        return const VenueListScreen();
      // case SidebarRoutes.sportsMaster:
      //   return const SportsListScreen();
      // case SidebarRoutes.playerMaster:
      //   return const PlayerListScreen();
      // case SidebarRoutes.userManagement:
      //   return const UserListScreen();
      // case SidebarRoutes.teamManagement:
      //   return const TeamListScreen();
      // case SidebarRoutes.tournamentModule:
      //   return const TournamentListScreen();
      // case SidebarRoutes.reports:
      //   return const ReportsScreen();
      default:
        return _buildDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: Row(
        children: [
          // ── Sidebar ───────────────────────────────────────
          Sidebar(
            currentRoute: _sidebarRoute,
            onRouteChanged: _onSidebarRouteChanged,
          ),

          // ── Header + Content ──────────────────────────────
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
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: KeyedSubtree(
                      key: ValueKey(_sidebarRoute + _currentScreen.runtimeType.toString()),
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