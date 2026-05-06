import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tms_flutter/core/session/app_session.dart';
import 'package:tms_flutter/features/admin/layout/presentation/widgets/sidebar.dart';
import '/features/admin/events/presentation/screens/event_list_screen.dart';
import '/features/admin/layout/presentation/screens/admin_dashboard_layout.dart';
import '/features/admin/venues/presentation/screens/venue_list_screen.dart';
import '/features/admin/sports/presentation/screens/sport_list_screen.dart';
import '/features/admin/players/presentation/screens/player_list_screen.dart';
import '/features/admin/tournaments/data/models/tournament_model.dart';
import '/features/admin/tournaments/data/services/tournament_service.dart';
import '/features/admin/tournaments/presentation/screens/tournament_view_screen.dart';
import '/features/admin/tournaments/presentation/screens/tournament_list_screen.dart';
import '/features/admin/teams/presentation/screens/team_list_screen.dart';
import '/features/admin/dashboard/presentation/screens/past_tournaments_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? roleId;

  // ── Real counts ──────────────────────────────────────────────
  int _totalPlayers = 0;
  int _totalTeams = 0;
  int _totalVenues = 0;
  int _activeTournaments = 0;

  // ── Real tournament lists ────────────────────────────────────
  List<TournamentModel> _liveTournaments = [];
  List<TournamentModel> _pastTournaments = [];

  bool _loading = true;

  static const _base = "https://dev.sports-next.com/api";

  @override
  void initState() {
    super.initState();
    _loadRole();
    _fetchDashboardData();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => roleId = prefs.getInt('role_id'));
  }

  Map<String, String> get _headers => {
    "Accept": "application/json",
    "Authorization": "Bearer ${AppSession.token}",
  };

  Future<void> _fetchDashboardData() async {
    try {
      // Fire all requests in parallel
      final results = await Future.wait([
        http.get(Uri.parse("$_base/players"), headers: _headers),
        http.get(Uri.parse("$_base/venues"), headers: _headers),
        http.get(Uri.parse("$_base/teams/count"), headers: _headers),
        http.get(Uri.parse("$_base/tournaments"), headers: _headers),
      ]);

      if (!mounted) return;

      // Players count
      final playersData = jsonDecode(results[0].body);
      final playersList = playersData is List
          ? playersData
          : (playersData['data'] ?? []) as List;

      // Venues count
      final venuesData = jsonDecode(results[1].body);
      final venuesList = venuesData is List
          ? venuesData
          : (venuesData['data'] ?? []) as List;

      // Teams count
      final teamsData = jsonDecode(results[2].body);
      print(
        "TEAMS RAW RESPONSE: ${results[2].statusCode} → ${results[2].body}",
      );
      final teamsTotal =
          teamsData['total'] ??
          (teamsData['data'] is List ? (teamsData['data'] as List).length : 0);

      // Tournaments — parse and split into live vs past
      final tournamentsData = jsonDecode(results[3].body);
      final rawList = tournamentsData is List
          ? tournamentsData
          : (tournamentsData['data'] ?? []) as List;

      final allTournaments = rawList
          .where((e) => e['deleted_at'] == null)
          .map((e) => TournamentModel.fromJson(e))
          .toList();

      final live = allTournaments
          .where((t) => t.status == 'published' || t.status == 'draft')
          .toList();

      final past = allTournaments
          .where((t) => t.status == 'completed')
          .toList();

      List<TournamentModel> detailedLive = [];

      try {
        if (live.isNotEmpty) {
          final detailResponses = await Future.wait(
            live.map((t) => TournamentService.getTournamentById(t.id)),
          );

          detailedLive = detailResponses
              .map((res) => TournamentModel.fromJson(res['data']))
              .toList();
        }
      } catch (e) {
        print("Live tournament detail fetch error: $e");
        detailedLive = live;
      }

      setState(() {
        _totalPlayers = playersList.length;
        _totalVenues = venuesList.length;
        _totalTeams = teamsTotal is int
            ? teamsTotal
            : int.tryParse(teamsTotal.toString()) ?? 0;
        _activeTournaments = live.length;
        _liveTournaments = detailedLive;
        _pastTournaments = past;
        _loading = false;
      });
    } catch (e) {
      print("Dashboard fetch error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Navigate to tournament view ──────────────────────────────
  Future<void> _openTournamentView(TournamentModel t) async {
    try {
      final res = await TournamentService.getTournamentById(t.id);
      if (!mounted) return;
      final updated = TournamentModel.fromJson(res['data']);
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => TournamentViewScreen(
            tournament: updated,
            isUser: AppSession.roleId == 5,
            onUpdate: (_) {},
            onBack: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ),
      );
    } catch (e) {
      print("Open tournament error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Dashboard Overview",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A46D8),
            ),
          ),

          const SizedBox(height: 20),

          // ── STAT CARDS ─────────────────────────────────────────
          _loading
              ? const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Row(
                  children: [
                    statCard(
                      "Total Players",
                      "$_totalPlayers",
                      Icons.people_outline,
                      const Color(0xFF3B82F6),
                    ),
                    statCard(
                      "Total Teams",
                      "$_totalTeams",
                      Icons.groups_outlined,
                      const Color(0xFF8B5CF6),
                    ),
                    statCard(
                      "Total Venues",
                      "$_totalVenues",
                      Icons.location_on_outlined,
                      const Color(0xFF10B981),
                    ),
                    statCard(
                      "Active Tournaments",
                      "$_activeTournaments",
                      Icons.emoji_events_outlined,
                      const Color(0xFFF59E0B),
                    ),
                  ],
                ),

          const SizedBox(height: 30),

          // ── ROW 2 — Live + Past Tournaments ───────────────────
          SizedBox(
            height: 420,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _liveTournamentsWidget()),
                const SizedBox(width: 20),
                SizedBox(width: 350, child: _pastTournamentsWidget(context)),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // ── ROW 3 — Upcoming Matches + Quick Actions ───────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _upcomingMatches()),
              const SizedBox(width: 20),
              SizedBox(width: 350, child: _quickActions(context)),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Stat Card ──────────────────────────────────────────────
  Widget statCard(
    String title,
    String value,
    IconData icon,
    Color accentColor,
  ) {
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
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Live Tournaments (real data + clickable) ───────────────
  Widget _liveTournamentsWidget() {
    return Container(
      decoration: _boxDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Text("Live Tournaments", style: _sectionTitle()),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Live",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _liveTournaments.isEmpty
                ? Center(
                    child: Text(
                      "No active tournaments",
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _liveTournaments.length,
                    itemBuilder: (_, i) {
                      final t = _liveTournaments[i];
                      return GestureDetector(
                        // ✅ CLICKABLE → opens tournament view
                        onTap: () => _openTournamentView(t),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0A1D4A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_outlined,
                                            size: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${t.startDate} → ${t.endDate}",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    // Status badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.status == 'published'
                                            ? Colors.green.shade50
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: t.status == 'published'
                                              ? Colors.green.shade300
                                              : Colors.orange.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        t.status == 'published'
                                            ? 'Published'
                                            : 'Draft',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: t.status == 'published'
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Arrow hint
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 13,
                                      color: Colors.blue.shade400,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime12h(String time) {
    try {
      final parts = time.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];

      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;

      return "$hour:$minute $period";
    } catch (e) {
      return time; // fallback
    }
  }

  // ── Past Tournaments (real data) ───────────────────────────
  Widget _pastTournamentsWidget(BuildContext context) {
    return Container(
      decoration: _boxDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text("Past Tournaments", style: _sectionTitle()),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _pastTournaments.isEmpty
                ? Center(
                    child: Text(
                      "No completed tournaments",
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _pastTournaments.length,
                    itemBuilder: (_, i) {
                      final t = _pastTournaments[i];
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    t.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF0A1D4A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    "Completed",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 12,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${t.startDate} → ${t.endDate}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            if (t.effectiveVenue.isNotEmpty &&
                                t.effectiveVenue != 'No venue') ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      t.effectiveVenue,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ── View All button ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: _ViewAllButton(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminDashboardLayout(
                    initialScreen: PastTournamentsScreen(),
                    initialSidebarRoute: SidebarRoutes.tournamentModule,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Upcoming Matches (kept as-is for now) ──────────────────
  Widget _upcomingMatches() {
    final matches = <Map<String, String>>[];

    for (final t in _liveTournaments) {
      for (final g in t.eventGroups) {
        for (final f in g.fixtures) {
          final teamA = f.teamAName.trim();
          final teamB = f.teamBName.trim();

          if (f.status == 'scheduled' &&
              teamA.isNotEmpty &&
              teamB.isNotEmpty &&
              teamA != 'TBD' &&
              teamB != 'TBD') {
            matches.add({
              "match": "$teamA vs $teamB",
              "venue": f.court.isNotEmpty ? f.court : t.effectiveVenue,
              "time": f.date.isNotEmpty
                  ? "${f.date}${f.time.isNotEmpty ? ' ${_formatTime12h(f.time)}' : ''}"
                  : "TBD",
            });
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _boxDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Upcoming Matches", style: _sectionTitle()),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (matches.isEmpty)
            Center(
              child: Text(
                "No upcoming matches",
                style: TextStyle(color: Colors.grey.shade400),
              ),
            )
          else
            ...matches
                .take(5)
                .map(
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
                                color: const Color(
                                  0xFF0A46D8,
                                ).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.sports_tennis,
                                color: Color(0xFF0A46D8),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m["match"]!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A1D4A),
                                  ),
                                ),
                                Text(
                                  m["venue"]!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            m["time"]!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Quick Actions (all wired up) ───────────────────────────
  Widget _quickActions(BuildContext context) {
    final actions = [
      {
        "label": "Create New Tournament",
        "route": "/admin/tournaments",
        "icon": Icons.emoji_events_outlined,
        "color": const Color(0xFF0A46D8),
      },
      {
        "label": "Add Team",
        "route": "/admin/teams",
        "icon": Icons.groups_outlined,
        "color": const Color(0xFF8B5CF6),
      },
      {
        "label": "Add Player",
        "route": "/admin/players",
        "icon": Icons.person_add_outlined,
        "color": const Color(0xFF10B981),
      },
      {
        "label": "Create Event",
        "route": "/admin/events",
        "icon": Icons.event_outlined,
        "color": const Color(0xFFF59E0B),
      },
      {
        "label": "Add Venue",
        "route": "/admin/venues",
        "icon": Icons.location_on_outlined,
        "color": const Color(0xFFEF4444),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _boxDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quick Actions", style: _sectionTitle()),
          const SizedBox(height: 20),
          ...actions.map(
            (a) => _QuickActionButton(
              label: a["label"] as String,
              route: a["route"] as String,
              icon: a["icon"] as IconData,
              color: a["color"] as Color,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDeco() => BoxDecoration(
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

  static TextStyle _sectionTitle() => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Color(0xFF0A1D4A),
  );
}

// ── Quick Action Button ───────────────────────────────────────
class _QuickActionButton extends StatefulWidget {
  final String label;
  final String route;
  final IconData icon;
  final Color color;

  const _QuickActionButton({
    required this.label,
    required this.route,
    required this.icon,
    required this.color,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _hovered = false;

  void _navigate() {
    switch (widget.route) {
      case "/admin/tournaments":
        // ✅ FIXED: Navigate to Tournament List screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminDashboardLayout(
              initialScreen: TournamentListScreen(),
              initialSidebarRoute: SidebarRoutes.tournamentModule,
            ),
          ),
        );
        break;

      case "/admin/teams":
        // ✅ FIXED: Navigate to Team Management screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminDashboardLayout(
              initialScreen: TeamListScreen(),
              initialSidebarRoute: SidebarRoutes.teamManagement,
            ),
          ),
        );
        break;

      case "/admin/players":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminDashboardLayout(
              initialScreen: PlayerListScreen(),
              initialSidebarRoute: SidebarRoutes.playerMaster,
            ),
          ),
        );
        break;

      case "/admin/events":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminDashboardLayout(
              initialScreen: EventListScreen(),
              initialSidebarRoute: SidebarRoutes.eventMaster,
            ),
          ),
        );
        break;

      case "/admin/venues":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminDashboardLayout(
              initialScreen: VenueListScreen(),
              initialSidebarRoute: SidebarRoutes.venueMaster,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _navigate,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color
                  : widget.color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? widget.color
                    : widget.color.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
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
      onExit: (_) => setState(() => _hovered = false),
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
