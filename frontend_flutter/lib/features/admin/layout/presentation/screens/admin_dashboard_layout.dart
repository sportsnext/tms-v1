import 'package:flutter/material.dart';
import '/features/admin/events/presentation/screens/event_list_screen.dart';
import '../widgets/sidebar.dart';
import '../widgets/header.dart';
import '/features/admin/dashboard/presentation/screens/dashboard_screen.dart';
import '/features/admin/venues/presentation/screens/venue_list_screen.dart';
import '/features/admin/sports/presentation/screens/sport_list_screen.dart';
import '/features/admin/players/presentation/screens/player_list_screen.dart';
import '/features/admin/teams/presentation/screens/team_list_screen.dart';
import '/features/admin/tournaments/presentation/screens/tournament_list_screen.dart';
import 'dart:html' as html;

class AdminDashboardLayout extends StatefulWidget {
  /// Optional — used only when navigating from a route (e.g. /admin/past-tournaments)
  /// Header and sidebar navigation do NOT use this — they use callbacks instead.
  final Widget? initialScreen;
  final String? initialSidebarRoute;

  const AdminDashboardLayout({super.key, this.initialScreen, this.initialSidebarRoute});

  @override
  State<AdminDashboardLayout> createState() => _AdminDashboardLayoutState();
}

class _AdminDashboardLayoutState extends State<AdminDashboardLayout> {

  int? roleId;

  // Sidebar active highlight
  String _sidebarRoute = SidebarRoutes.dashboard;

  // The widget currently shown in the content area
  late Widget _currentScreen;

  @override
  void initState() {
    super.initState();

    if(widget.initialScreen != null) {
      _currentScreen = widget.initialScreen!;
    } else {
       _currentScreen = const DashboardScreen();
    }

    if(widget.initialSidebarRoute != null) {
      _sidebarRoute = widget.initialSidebarRoute!;
    }

    loadRole();
  }

  Future<void> loadRole() async {
    final storedRole = html.window.localStorage['role_id'];

    setState(() {
      roleId = storedRole != null ? int.parse(storedRole) : null;
    });

    print("Loaded Role ID: $roleId");
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
      
      case SidebarRoutes.eventMaster:
        return const EventListScreen();

      case SidebarRoutes.sportsMaster:
        return const SportsListScreen();

      case SidebarRoutes.playerMaster:
        return const PlayerListScreen();

      case SidebarRoutes.teamManagement:
        return const TeamListScreen();

      case SidebarRoutes.venueMaster:
        return const VenueListScreen();

      // case SidebarRoutes.userManagement:
      //   return const UserListScreen();

      case SidebarRoutes.tournamentModule:
        return const TournamentListScreen();

      // case SidebarRoutes.reports:
      //   return const ReportsScreen();

      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if(roleId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: Row(
        children: [
          // ── LEFT SIDEBAR ─────────────────────────────────
          Sidebar(
            roleId: roleId!,
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