import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/events/presentation/screens/event_list_screen.dart';
import 'package:tms_flutter/features/admin/layout/presentation/widgets/sidebar.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(Widget, String)? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TITLE
          const Text(
            "Dashboard Overview",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A46D8),
            ),
          ),

          const SizedBox(height: 20),

          // STAT CARDS
          Row(
            children: [
              statCard("Total Players",      "1240", Icons.people_outline,        const Color(0xFF3B82F6)),
              statCard("Total Teams",        "98",   Icons.groups_outlined,        const Color(0xFF8B5CF6)),
              statCard("Total Venues",       "36",   Icons.location_on_outlined,   const Color(0xFF10B981)),
              statCard("Active Tournaments", "12",   Icons.emoji_events_outlined,  const Color(0xFFF59E0B)),
            ],
          ),

          const SizedBox(height: 30),


          // ROW 2 — Live Tournaments + Past Tournaments (fixed height = no stretch crash)
          SizedBox(
            height: 420,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: liveTournaments()),
                const SizedBox(width: 20),
                SizedBox(width: 350, child: pastTournaments(context)),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // ROW 3 — Matches + Quick Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: upcomingMatches()),
              const SizedBox(width: 20),
              SizedBox(width: 350, child: quickActions(context)),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Stat Card ──────────────────────────────────────────────
  Widget statCard(String title, String value, IconData icon, Color accentColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Text(value,
                    style: TextStyle(
                        fontSize: 26,
                        color: accentColor,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Ongoing Tournaments ────────────────────────────────────
  // ── Live Tournaments (scrollable list, stretches to match Past height) ──
  Widget liveTournaments() {
    final data = [
      {"name": "Champions Cricket League", "teams": "16 Teams", "start": "Feb 12", "end": "Mar 28", "sport": "Cricket"},
      {"name": "National Football Cup",    "teams": "12 Teams", "start": "Jan 5",  "end": "Feb 20", "sport": "Football"},
      {"name": "All India Badminton Open", "teams": "32 Teams", "start": "Mar 2",  "end": "Apr 9",  "sport": "Badminton"},
    ];

    return Container(
      decoration: boxDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fixed header ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Text("Live Tournaments", style: sectionTitle()),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text("Live",
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Scrollable list (fills remaining space) ───────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: data.length,
              itemBuilder: (_, i) {
                final t = data[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t["name"]!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A1D4A))),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 11, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text("${t["start"]} → ${t["end"]}",
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A46D8).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t["teams"]!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0A46D8),
                                fontSize: 12)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }




  // ── Past Tournaments (fixed header+button, scrollable list) ──
  Widget pastTournaments(BuildContext context) {
    final past = [
      {"name": "Winter Cricket Cup",   "start": "Nov 1",  "end": "Nov 28", "teams": "8 Teams",  "winner": "Mumbai Lions"},
      {"name": "City Football League", "start": "Oct 5",  "end": "Oct 30", "teams": "10 Teams", "winner": "Delhi FC"},
      {"name": "State Badminton Open", "start": "Sep 12", "end": "Sep 25", "teams": "16 Teams", "winner": "Rahul Sharma"},
    ];

    return Container(
      decoration: boxDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── FIXED HEADER ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text("Past Tournaments", style: sectionTitle()),
          ),

          // ── SCROLLABLE LIST ───────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: past.length,
              itemBuilder: (_, i) {
                final t = past[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + Completed badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(t["name"]!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0A1D4A))),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text("Completed",
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Date + Teams row
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text("${t["start"]} → ${t["end"]}",
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(width: 12),
                          Icon(Icons.groups_outlined,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(t["teams"]!,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Winner
                      Row(
                        children: [
                          const Icon(Icons.emoji_events,
                              size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text("Winner: ${t["winner"]!}",
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF59E0B))),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── FIXED BOTTOM BUTTON ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: _ViewAllButton(
              onTap: () =>
                  Navigator.pushNamed(context, '/admin/past-tournaments'),
            ),
          ),
        ],
      ),
    );
  }


  // ── Upcoming Matches ───────────────────────────────────────
  Widget upcomingMatches() {
    final matches = [
      {"match": "MI vs CSK",  "venue": "Wankhede",              "time": "Tomorrow 7:00 PM"},
      {"match": "RCB vs KKR", "venue": "Chinnaswamy",           "time": "Feb 12, 5:30 PM"},
      {"match": "GT vs SRH",  "venue": "Narendra Modi Stadium", "time": "Feb 14, 8:00 PM"},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: boxDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Upcoming Matches", style: sectionTitle()),
          const SizedBox(height: 20),
          ...matches.map(
            (m) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A46D8).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.sports_cricket,
                            color: Color(0xFF0A46D8), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m["match"]!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A1D4A))),
                          Text(m["venue"]!,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(m["time"]!,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ──────────────────────────────────────────
  Widget quickActions(BuildContext context) {
    final actions = [
      {"label": "Create New Tournament", "route": "/admin/tournaments", "icon": Icons.emoji_events_outlined, "color": const Color(0xFF0A46D8)},
      {"label": "Add Team",              "route": "/admin/teams",       "icon": Icons.groups_outlined,       "color": const Color(0xFF8B5CF6)},
      {"label": "Add Player",            "route": "/admin/players",     "icon": Icons.person_add_outlined,   "color": const Color(0xFF10B981)},
      {"label": "Create Event", "sidebarRoute": SidebarRoutes.eventMaster, "screen": const EventListScreen(), "icon": Icons.event_outlined, "color": const Color(0xFFF59E0B),},
      {"label": "Add Venue",             "route": "/admin/venues",      "icon": Icons.location_on_outlined,  "color": const Color(0xFFEF4444)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: boxDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quick Actions", style: sectionTitle()),
          const SizedBox(height: 20),
          ...actions.map(
           (a) => _QuickActionButton(
           label:        a["label"]        as String,
           icon:         a["icon"]         as IconData,
           color:        a["color"]        as Color,
           sidebarRoute: a["sidebarRoute"] as String?,
           route:        a["route"]        as String?,
           screen:       a["screen"]       as Widget?,
           onNavigate:   onNavigate,
          ),
          ).toList(),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────
  BoxDecoration boxDeco() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static TextStyle sectionTitle() {
    return const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0A1D4A));
  }
}

// ── Quick Action Button — stateful for hover effect ───────────
class _QuickActionButton extends StatefulWidget {
  final String   label;
  final String?  sidebarRoute;
  final String?  route;
  final Widget?  screen;
  final IconData icon;
  final Color    color;
  final void Function(Widget, String)? onNavigate;

  const _QuickActionButton({
    required this.label,
    this.sidebarRoute,
    this.route,
    required this.icon,
    required this.color,
    this.screen,
    this.onNavigate,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () {
            if (widget.route != null) {
              Navigator.pushNamed(context, widget.route!);
            } else if (widget.screen != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => widget.screen!));
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color
                  : widget.color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? widget.color
                    : widget.color.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // Icon container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? Colors.white.withOpacity(0.2)
                        : widget.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 18,
                    color: _hovered ? Colors.white : widget.color,
                  ),
                ),
                const SizedBox(width: 12),

                // Label
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _hovered ? Colors.white : widget.color,
                    ),
                  ),
                ),

                // Arrow
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _hovered ? 1.0 : 0.35,
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: _hovered ? Colors.white : widget.color,
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

// ── View All Button ───────────────────────────────────────────
class _ViewAllButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ViewAllButton({required this.onTap});

  @override
  State<_ViewAllButton> createState() => _ViewAllButtonState();
}

class _ViewAllButtonState extends State<_ViewAllButton> {
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
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF0A46D8)
                : const Color(0xFF0A46D8).withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFF0A46D8)
                  : const Color(0xFF0A46D8).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "View All Tournaments",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? Colors.white : const Color(0xFF0A46D8),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: _hovered ? Colors.white : const Color(0xFF0A46D8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}