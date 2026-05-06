import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/profile/presentation/screens/profile_screen.dart';
import 'package:tms_flutter/features/admin/settings/presentation/screens/settings_screen.dart';
import 'package:tms_flutter/features/admin/notifications/presentation/screens/notifications_screen.dart';

class Header extends StatefulWidget {
  final String userName;
  final String profileImage;

  /// Called when user taps My Profile / Settings / Notifications
  /// The layout swaps the content area to show that screen —
  /// NO Navigator.push, so sidebar stays intact and back button works normally.
  final void Function(Widget screen) onNavigate;

  const Header({
    super.key,
    required this.userName,
    required this.profileImage,
    required this.onNavigate,
  });

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  OverlayEntry? _notificationOverlay;
  OverlayEntry? _profileOverlay;

  final GlobalKey _notifKey   = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();

  final List<Map<String, String>> notifications = [
    {"text": "New tournament created",       "time": "2 min ago"},
    {"text": "Player registration approved", "time": "1 hour ago"},
    {"text": "Team added to league",         "time": "Yesterday"},
  ];

  // ── Overlay helpers ────────────────────────────────────────
  void _closeAll() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
    _profileOverlay?.remove();
    _profileOverlay = null;
  }

  Offset _getOffset(GlobalKey key) {
    final box = key.currentContext!.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset.zero);
  }

  Size _getSize(GlobalKey key) {
    final box = key.currentContext!.findRenderObject() as RenderBox;
    return box.size;
  }

  // ── Notification overlay ───────────────────────────────────
  void _toggleNotifications() {
    if (_notificationOverlay != null) { _closeAll(); return; }
    _closeAll();

    final offset = _getOffset(_notifKey);
    final size   = _getSize(_notifKey);

    _notificationOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
                onTap: _closeAll,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand()),
          ),
          Positioned(
            top:   offset.dy + size.height + 8,
            right: MediaQuery.of(context).size.width -
                   offset.dx - size.width - 10,
            child: Material(
              color: Colors.transparent,
              child: _notificationDropdown(),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_notificationOverlay!);
  }

  // ── Profile overlay ────────────────────────────────────────
  void _toggleProfile() {
    if (_profileOverlay != null) { _closeAll(); return; }
    _closeAll();

    final offset = _getOffset(_profileKey);
    final size   = _getSize(_profileKey);

    _profileOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
                onTap: _closeAll,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand()),
          ),
          Positioned(
            top:   offset.dy + size.height + 8,
            right: MediaQuery.of(context).size.width -
                   offset.dx - size.width,
            child: Material(
              color: Colors.transparent,
              child: _profileDropdown(),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_profileOverlay!);
  }

  // ── Navigation actions — use callback, NOT Navigator.push ──
  void _goToProfile() {
    _closeAll();
    widget.onNavigate(const ProfileScreen());
  }

  void _goToSettings() {
    _closeAll();
    widget.onNavigate(const SettingsScreen());
  }

  void _goToNotifications() {
    _closeAll();
    widget.onNavigate(const NotificationsScreen());
  }

  void _logout() {
    _closeAll();
    Navigator.pushNamedAndRemoveUntil(
        context, '/login', (route) => false);
  }

  @override
  void dispose() {
    _closeAll();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [

          // NOTIFICATION ICON
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: _notifKey,
              onTap: _toggleNotifications,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_none,
                      size: 28, color: Colors.grey.shade700),
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text("${notifications.length}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 25),

          // SETTINGS ICON — direct tap, no dropdown needed
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _goToSettings,
              child: Icon(Icons.settings,
                  size: 26, color: Colors.grey.shade700),
            ),
          ),

          const SizedBox(width: 25),

          // PROFILE SECTION
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: _profileKey,
              onTap: _toggleProfile,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        const Color(0xFF0A46D8).withOpacity(0.1),
                    backgroundImage: widget.profileImage.isNotEmpty
                        ? AssetImage(widget.profileImage)
                        : null,
                    child: widget.profileImage.isEmpty
                        ? const Icon(Icons.person,
                            color: Color(0xFF0A46D8))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(widget.userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down,
                      color: Colors.grey.shade700),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Notification dropdown ──────────────────────────────────
  Widget _notificationDropdown() {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Notifications",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...notifications.map((n) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n["text"]!,
                        style: const TextStyle(color: Colors.black)),
                    Text(n["time"]!,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )),
          const SizedBox(height: 6),
          // View All → swaps content area to NotificationsScreen
          GestureDetector(
            onTap: _goToNotifications,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(10)),
              child: const Center(
                child: Text("View All",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile dropdown ───────────────────────────────────────
  Widget _profileDropdown() {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DropdownTile(
              text: "My Profile",
              icon: Icons.person_outline,
              onTap: _goToProfile),
          _DropdownTile(
              text: "Settings",
              icon: Icons.settings_outlined,
              onTap: _goToSettings),
          Divider(height: 1, color: Colors.grey.shade200),
          _DropdownTile(
              text: "Logout",
              icon: Icons.logout_rounded,
              onTap: _logout,
              red: true),
        ],
      ),
    );
  }
}

// ── Dropdown tile with hover ──────────────────────────────────
class _DropdownTile extends StatefulWidget {
  final String   text;
  final IconData icon;
  final VoidCallback onTap;
  final bool     red;

  const _DropdownTile({
    required this.text,
    required this.icon,
    required this.onTap,
    this.red = false,
  });

  @override
  State<_DropdownTile> createState() => _DropdownTileState();
}

class _DropdownTileState extends State<_DropdownTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.red ? Colors.red : const Color(0xFF0A1D4A);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.red
                    ? Colors.red.withOpacity(0.07)
                    : Colors.grey.shade50)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 17, color: color),
              const SizedBox(width: 10),
              Text(widget.text,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}