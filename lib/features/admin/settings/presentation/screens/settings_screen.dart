import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _emailNotifications = true;
  bool _pushNotifications  = true;
  bool _matchAlerts        = true;
  bool _tournamentUpdates  = true;
  bool _showProfile        = true;
  bool _activityVisible    = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Settings",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A46D8))),
          const SizedBox(height: 4),
          const Text("Manage your preferences",
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 28),

          _sectionCard(
            title: "Notifications",
            icon: Icons.notifications_outlined,
            iconColor: const Color(0xFF0A46D8),
            children: [
              _toggleRow("Email Notifications", "Receive updates via email",
                  _emailNotifications,
                  (v) => setState(() => _emailNotifications = v)),
              _divider(),
              _toggleRow("Push Notifications", "Receive push alerts on device",
                  _pushNotifications,
                  (v) => setState(() => _pushNotifications = v)),
              _divider(),
              _toggleRow("Match Alerts", "Get notified when a match starts or ends",
                  _matchAlerts,
                  (v) => setState(() => _matchAlerts = v)),
              _divider(),
              _toggleRow("Tournament Updates", "Stay updated on tournament changes",
                  _tournamentUpdates,
                  (v) => setState(() => _tournamentUpdates = v)),
            ],
          ),

          const SizedBox(height: 20),

          
          _sectionCard(
            title: "Privacy",
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF10B981),
            children: [
              _toggleRow("Public Profile", "Allow others to see your profile",
                  _showProfile, (v) => setState(() => _showProfile = v)),
              _divider(),
              _toggleRow("Activity Visible", "Show your recent activity to teammates",
                  _activityVisible,
                  (v) => setState(() => _activityVisible = v)),
            ],
          ),

          const SizedBox(height: 20),

          _sectionCard(
            title: "Account",
            icon: Icons.manage_accounts_outlined,
            iconColor: const Color(0xFFEF4444),
            children: [
              _ActionTile(
                title: "Logout",
                subtitle: "Sign out of your account",
                icon: Icons.logout_rounded,
                color: const Color(0xFFEF4444),
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false),
              ),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 700),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A1D4A))),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          ...children,
        ],
      ),
    );
  }

  Widget _toggleRow(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0A1D4A))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF0A46D8),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.grey.shade100, indent: 20, endIndent: 20);
}

class _ActionTile extends StatefulWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withOpacity(0.05) : Colors.transparent,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.color)),
                    Text(widget.subtitle,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: widget.color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}