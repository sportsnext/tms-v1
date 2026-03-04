import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'All';
  final List<String> _filters = ['All', 'Tournament', 'Player', 'Team', 'Venue', 'Match', 'Event'];

  final List<Map<String, dynamic>> _notifications = [
    {"text": "New tournament created: Champions League 2025", "time": "2 min ago",  "type": "Tournament", "read": false, "icon": Icons.emoji_events_outlined,  "color": 0xFF0A46D8},
    {"text": "Player registration approved: John Smith",     "time": "1 hour ago", "type": "Player",     "read": false, "icon": Icons.person_add_outlined,     "color": 0xFF10B981},
    {"text": "Team added to league: Delhi Lions",            "time": "Yesterday",  "type": "Team",       "read": true,  "icon": Icons.groups_outlined,         "color": 0xFF8B5CF6},
    {"text": "Venue updated: Wankhede Stadium",              "time": "2 days ago", "type": "Venue",      "read": true,  "icon": Icons.location_on_outlined,    "color": 0xFFF59E0B},
    {"text": "Match score updated: MI vs CSK",               "time": "3 days ago", "type": "Match",      "read": true,  "icon": Icons.sports_cricket_outlined, "color": 0xFFEF4444},
    {"text": "New event created: Mumbai City Games",         "time": "4 days ago", "type": "Event",      "read": true,  "icon": Icons.event_outlined,          "color": 0xFF0A46D8},
    {"text": "Fixture generated: National Football Cup",     "time": "5 days ago", "type": "Tournament", "read": true,  "icon": Icons.emoji_events_outlined,   "color": 0xFF0A46D8},
    {"text": "Player bulk upload completed: 45 players",     "time": "1 week ago", "type": "Player",     "read": true,  "icon": Icons.upload_outlined,         "color": 0xFF10B981},
  ];

  List<Map<String, dynamic>> get _filtered => _filter == 'All'
      ? _notifications
      : _notifications.where((n) => n["type"] == _filter).toList();

  int get _unreadCount => _notifications.where((n) => !(n["read"] as bool)).length;

  void _markAllRead() => setState(() {
    for (var n in _notifications) n["read"] = true;
  });

  void _markRead(Map<String, dynamic> n) => setState(() => n["read"] = true);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Notifications",
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A46D8))),
                  Text("Stay updated with latest activity",
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              if (_unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text("$_unreadCount Unread",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700)),
                ),
              _MarkAllBtn(onTap: _markAllRead),
            ],
          ),

          const SizedBox(height: 24),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: f,
                  selected: _filter == f,
                  onTap: () => setState(() => _filter = f),
                ),
              )).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // List
          Container(
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
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text("No notifications",
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (_, i) {
                      final n = _filtered[i];
                      return _NotifTile(
                        notification: n,
                        onTap: () => _markRead(n),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatefulWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  const _NotifTile({required this.notification, required this.onTap});
  @override
  State<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends State<_NotifTile> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final n      = widget.notification;
    final isRead = n["read"] as bool;
    final color  = Color(n["color"] as int);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: _hovered ? Colors.grey.shade50 : (isRead ? Colors.white : color.withOpacity(0.04)),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(n["icon"] as IconData, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n["text"] as String,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                            color: const Color(0xFF0A1D4A))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(n["type"] as String,
                              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Text(n["time"] as String,
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF0A46D8), shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected || _hovered ? const Color(0xFF0A46D8) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: widget.selected ? const Color(0xFF0A46D8) : Colors.grey.shade200),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: widget.selected || _hovered ? Colors.white : Colors.grey.shade700)),
        ),
      ),
    );
  }
}

class _MarkAllBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _MarkAllBtn({required this.onTap});
  @override
  State<_MarkAllBtn> createState() => _MarkAllBtnState();
}

class _MarkAllBtnState extends State<_MarkAllBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF0A46D8) : const Color(0xFF0A46D8).withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0A46D8).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.done_all_rounded, size: 16,
                  color: _hovered ? Colors.white : const Color(0xFF0A46D8)),
              const SizedBox(width: 6),
              Text("Mark All Read",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _hovered ? Colors.white : const Color(0xFF0A46D8))),
            ],
          ),
        ),
      ),
    );
  }
}