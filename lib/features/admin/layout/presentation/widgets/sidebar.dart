import 'package:flutter/material.dart';

// ── Route constants (will wire to real routes later) ──────────
class SidebarRoutes {
  static const String dashboard       = '/admin/dashboard';
  static const String eventMaster     = '/admin/events';
  static const String venueMaster     = '/admin/venues';
  static const String sportsMaster    = '/admin/sports';
  static const String playerMaster    = '/admin/players';
  static const String userManagement  = '/admin/users';
  static const String teamManagement  = '/admin/teams';
  static const String tournamentModule= '/admin/tournaments';
  static const String reports         = '/admin/reports';
}

// ── Menu item model ───────────────────────────────────────────
class _SidebarItem {
  final String label;
  final IconData icon;
  final String route;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

// ── Sidebar Widget ────────────────────────────────────────────
class Sidebar extends StatefulWidget {
  final String currentRoute;
  final ValueChanged<String>? onRouteChanged;

  const Sidebar({
    super.key,
    this.currentRoute = SidebarRoutes.dashboard,
    this.onRouteChanged,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  late String _activeRoute;
  String? _hoveredRoute;

  static const List<_SidebarItem> _items = [
    _SidebarItem(
      label: 'Dashboard',
      icon:  Icons.dashboard_outlined,
      route: SidebarRoutes.dashboard,
    ),
    _SidebarItem(
      label: 'Event Master',
      icon:  Icons.event_outlined,
      route: SidebarRoutes.eventMaster,
    ),
    _SidebarItem(
      label: 'Venue Master',
      icon:  Icons.location_on_outlined,
      route: SidebarRoutes.venueMaster,
    ),
    _SidebarItem(
      label: 'Sports Master',
      icon:  Icons.sports_outlined,
      route: SidebarRoutes.sportsMaster,
    ),
    _SidebarItem(
      label: 'Player Master',
      icon:  Icons.person_outlined,
      route: SidebarRoutes.playerMaster,
    ),
    _SidebarItem(
      label: 'User Management',
      icon:  Icons.manage_accounts_outlined,
      route: SidebarRoutes.userManagement,
    ),
    _SidebarItem(
      label: 'Team Management',
      icon:  Icons.groups_outlined,
      route: SidebarRoutes.teamManagement,
    ),
    _SidebarItem(
      label: 'Tournament Module',
      icon:  Icons.emoji_events_outlined,
      route: SidebarRoutes.tournamentModule,
    ),
    _SidebarItem(
      label: 'Reports (CSV / PDF)',
      icon:  Icons.bar_chart_outlined,
      route: SidebarRoutes.reports,
    ),
  ];

  // Colors matching screenshot
  static const Color _navyDark    = Color(0xFF0D1B4B); // dark navy bg
  static const Color _navyMid     = Color(0xFF102060); // slightly lighter
  static const Color _activeWhite = Colors.white;
  static const Color _activeBlue  = Color(0xFF1A3A8F); // active text blue
  static const Color _textNormal  = Color(0xFFCDD6F4); // soft white-blue
  static const Color _hoverBg     = Color(0xFF1A2E6B); // hover bg

  @override
  void initState() {
    super.initState();
    _activeRoute = widget.currentRoute;
  }

  void _onTap(_SidebarItem item) {
    setState(() => _activeRoute = item.route);
    widget.onRouteChanged?.call(item.route);
    // Navigator routing will be wired later
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: _navyDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── LOGO SECTION ─────────────────────────────────
          _buildLogoSection(),

          // ── DIVIDER ───────────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.white.withOpacity(0.12),
          ),

          const SizedBox(height: 10),

          // ── MENU ITEMS ────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              itemCount: _items.length,
              itemBuilder: (_, i) => _buildMenuItem(_items[i]),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────
  Widget _buildLogoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 130,
          height: 70,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
            'SPORTS NEXT\nINDIA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  // ── Single menu item ─────────────────────────────────────
  Widget _buildMenuItem(_SidebarItem item) {
    final bool isActive  = _activeRoute == item.route;
    final bool isHovered = _hoveredRoute == item.route;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredRoute = item.route),
        onExit:  (_) => setState(() => _hoveredRoute = null),
        child: GestureDetector(
          onTap: () => _onTap(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isActive
                  ? _activeWhite
                  : isHovered
                      ? _hoverBg
                      : Colors.transparent,
              borderRadius: isActive
                  ? const BorderRadius.only(
                      topRight:    Radius.circular(30),
                      bottomRight: Radius.circular(30),
                      topLeft:     Radius.circular(6),
                      bottomLeft:  Radius.circular(6),
                    )
                  : BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Icon
                Icon(
                  item.icon,
                  size: 20,
                  color: isActive
                      ? _activeBlue
                      : _textNormal,
                ),
                const SizedBox(width: 12),

                // Label
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isActive
                          ? _activeBlue
                          : _textNormal,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ),

                // Active indicator dot
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _activeBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}