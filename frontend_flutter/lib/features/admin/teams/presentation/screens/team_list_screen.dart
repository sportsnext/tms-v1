// lib/features/admin/teams/presentation/screens/team_list_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/features/admin/teams/data/models/team_model.dart';
import '/features/admin/players/data/models/player_model.dart';
import '/core/session/app_session.dart';
import 'add_team_screen.dart';
import 'team_roster_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});
  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen>
    with SingleTickerProviderStateMixin {
  List<TeamModel> _teams = [];
  List<PlayerModel> _players = [];

  int _selectedTab = 0; // ✅ NEW

  String token = AppSession.token;
  String tournamentId = AppSession.tournamentId;

  int _currentPage = 1;
  int _lastPage = 1;

  final String baseUrl = "https://dev.sports-next.com/api";

  String _search = '';
  String _filterStatus = 'All';
  String _filterSport = 'All';
  late TabController _tabs;

  List<Map<String, dynamic>> _tournaments = [];
  String? _selectedTournamentId;

  @override
  void initState() {
    super.initState();

    token = AppSession.token;

    tournamentId = AppSession.tournamentId;

    print("Tournament ID: $tournamentId");

    _tabs = TabController(length: 3, vsync: this);

    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() {
          _selectedTab = _tabs.index; // ✅ STORE FINAL TAB
        });
      }
    });

    initData();
  }

  Future<void> initData() async {
    await loadTournament(); // 🔥 LOAD LIST FIRST

    tournamentId = AppSession.tournamentId;

    _selectedTournamentId = tournamentId.isNotEmpty ? tournamentId : null;

    if (_selectedTournamentId != null) {
      await loadTeams(page: 1);
      await loadPlayersAndSet();
    }
  }

  void movePlayerLocally({
    required String playerId,
    required String fromTeamId,
    required String toTeamId,
  }) {
    setState(() {
      final fromIndex = _teams.indexWhere(
        (t) => t.id.toString() == fromTeamId.toString(),
      );

      final toIndex = _teams.indexWhere(
        (t) => t.id.toString() == toTeamId.toString(),
      );

      if (fromIndex == -1 || toIndex == -1) return;

      final fromTeam = _teams[fromIndex];
      final toTeam = _teams[toIndex];

      // REMOVE FROM OLD
      final updatedFrom = fromTeam.copyWith(
        playerIds: List<String>.from(fromTeam.playerIds)
          ..removeWhere((id) => id.toString() == playerId),
      );

      // ADD TO NEW
      final updatedTo = toTeam.copyWith(
        playerIds: List<String>.from(toTeam.playerIds)..add(playerId),
      );

      // 🔥 NAME UPDATE FUNCTION
      String getName(List<String> ids) {
        if (ids.isEmpty) return "Player";

        if (ids.length == 1) {
          final p = _players.firstWhere(
            (pl) => pl.id.toString() == ids[0].toString(),
            orElse: () => PlayerModel(
              id: ids[0],
              firstName: "Unknown",
              lastName: "",
              email: "",
              phone: "",
              gender: "",
              ageGroup: "",
              skillLevel: "",
              city: "",
              state: "",
              country: "",
              notes: "",
              isActive: true,
              createdAt: "",
              updatedAt: "",
              history: [],
              isPlaying: true,
              eventId: 0,
              type: "individual",
            ),
          );
          return p.fullName;
        }

        final p1 = _players.firstWhere(
          (pl) => pl.id.toString() == ids[0].toString(),
          orElse: () => PlayerModel(
            id: ids[0],
            firstName: "P1",
            lastName: "",
            email: "",
            phone: "",
            gender: "",
            ageGroup: "",
            skillLevel: "",
            city: "",
            state: "",
            country: "",
            notes: "",
            isActive: true,
            createdAt: "",
            updatedAt: "",
            history: [],
            isPlaying: true,
            eventId: 0,
            type: "individual",
          ),
        );

        final p2 = _players.firstWhere(
          (pl) => pl.id.toString() == ids[1].toString(),
          orElse: () => PlayerModel(
            id: ids[1],
            firstName: "P2",
            lastName: "",
            email: "",
            phone: "",
            gender: "",
            ageGroup: "",
            skillLevel: "",
            city: "",
            state: "",
            country: "",
            notes: "",
            isActive: true,
            createdAt: "",
            updatedAt: "",
            history: [],
            isPlaying: true,
            eventId: 0,
            type: "individual",
          ),
        );

        return "${p1.fullName} & ${p2.fullName}";
      }

      // 🔥 APPLY NAME CHANGE (ONLY FOR INDIVIDUAL)
      final finalFrom = updatedFrom.type == "individual"
          ? updatedFrom.copyWith(name: getName(updatedFrom.playerIds))
          : updatedFrom;

      final finalTo = updatedTo.type == "individual"
          ? updatedTo.copyWith(name: getName(updatedTo.playerIds))
          : updatedTo;

      // 🔥 UPDATE LIST
      _teams[fromIndex] = finalFrom;
      _teams[toIndex] = finalTo;
    });
  }

  Future<void> loadTeams({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/tournaments/$tournamentId/teams?page=$page"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        print("TEAM API RESPONSE: $decoded");

        List teamData = decoded;

        final teams = teamData.map((team) => TeamModel.fromJson(team)).toList();
        final players = await loadPlayers();

        final updatedTeams = teams.map((t) {
          if (t.type == "individual") {
            if (t.playerIds.isEmpty) return t;

            PlayerModel getPlayer(String id) {
              return players.firstWhere(
                (p) => p.id.toString() == id.toString(),
                orElse: () => PlayerModel(
                  id: id,
                  firstName: "Unknown",
                  lastName: "",
                  email: "",
                  phone: "",
                  gender: "",
                  ageGroup: "",
                  skillLevel: "",
                  city: "",
                  state: "",
                  country: "",
                  notes: "",
                  isActive: true,
                  createdAt: "",
                  updatedAt: "",
                  history: [],
                  isPlaying: true,
                  eventId: 0,
                  type: "individual",
                ),
              );
            }

            if (t.playerIds.length == 1) {
              final p = getPlayer(t.playerIds[0]);
              return t.copyWith(name: p.fullName);
            }

            final p1 = getPlayer(t.playerIds[0]);
            final p2 = getPlayer(t.playerIds[1]);

            return t.copyWith(name: "${p1.fullName} & ${p2.fullName}");
          }

          return t;
        }).toList();

        if (!mounted) return;

        setState(() {
          _teams = updatedTeams;
          _players = players;

          _currentPage = 1;
          _lastPage = 1;
        });

        _snack("Teams loaded successfully");

        print("Teams Loaded: ${_teams.length}");

        for (var team in _teams) {
          print(
            "RAW → id:${team.id}, locked:${team.locked}, isLocked:${team.isLocked}, published:${team.isPublished}",
          );
        }
      } else if (response.statusCode == 401) {
        _snack("Session expired. Please login again", error: true);
      } else if (response.statusCode == 404) {
        _snack("Tournament not found", error: true);
      } else {
        print("ERROR BODY: ${response.body}");
        _snack("Failed to load teams. Try again", error: true);
      }
    } catch (e) {
      print("TEAM FETCH ERROR: $e");
    }
  }

  // THIS IS THE CHANGE
  Future<List<PlayerModel>> loadPlayers() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/players"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        List playerData;

        if (decoded is List) {
          playerData = decoded;
        } else {
          playerData = decoded['data'] ?? [];
        }

        return playerData.map((p) => PlayerModel.fromJson(p)).toList();
      } else {
        print("Failed to load players");
        return [];
      }
    } catch (e) {
      print("PLAYER FETCH ERROR: $e");
      return [];
    }
  }

  Future<void> loadTournament() async {
    final response = await http.get(
      Uri.parse("$baseUrl/tournaments"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _tournaments = List<Map<String, dynamic>>.from(data);
        });
      }
    }
  }

  Future<void> _deleteTeam(TeamModel team) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/teams/${team.id}"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _teams.removeWhere((t) => t.id == team.id);
        });

        _snack('"${team.name}" deleted successfully');
      } else {
        _snack("Failed to delete team", error: true);
      }
    } catch (e) {
      print("Delete error: $e");
    }
  }

  Future<void> loadPlayersAndSet() async {
    final players = await loadPlayers();

    if (!mounted) return;
    setState(() {
      _players = players;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Computed ─────────────────────────────────────────────────────────────
  List<String> get _sportOptions =>
      _teams.map((t) => t.sport).toSet().toList()..sort();

  List<TeamModel> get _filtered {
    final q = _search.toLowerCase();

    return _teams.where((t) {
      final mQ =
          q.isEmpty ||
          t.name.toLowerCase().contains(q) ||
          t.sport.toLowerCase().contains(q) ||
          t.coachName.toLowerCase().contains(q) ||
          t.id.toLowerCase().contains(q);

      final mS = _filterStatus == 'All' || t.status == _filterStatus;
      final mP = _filterSport == 'All' || t.sport == _filterSport;

      return mQ && mS && mP;
    }).toList();
  }

  List<TeamModel> get _individualTeams =>
      _teams.where((t) => t.type == "individual").toList();

  List<TeamModel> get _teamEventTeams =>
      _teams.where((t) => t.type == "team_event").toList();

  List<TeamModel> get _lockedTeams =>
      _teams.where((t) => t.locked == 1).toList();

  int get _totalAssigned => _teams.fold(0, (s, t) => s + t.playerCount);
  int get _publishedCount => _teams.where((t) => t.isPublished).length;
  int get _draftCount => _teams.where((t) => t.status == 'draft').length;

  // ── Snackbar ─────────────────────────────────────────────────────────────
  void _snack(
    String msg, {
    bool error = false,
  }) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: error ? Colors.red.shade700 : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ),
  );

  // ── Actions ──────────────────────────────────────────────────────────────
  // THIS IS THE CHANGE
  void _openAdd(String type) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddTeamScreen(
        type: type,
        existingTeams: _teams,
        onSave: (t) {}, // backend handles save
      ),
    );

    await loadTeams(); // THIS IS THE CHANGE → reload teams from backend
  }

  // THIS IS THE CHANGE
  Future<void> _openEdit(TeamModel team) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddTeamScreen(
        type: team.type,
        existingTeams: _teams,
        editTeam: team,
        onSave: (updated) {},
      ),
    );

    await loadTeams(page: _currentPage);

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openRoster(TeamModel team) async {
    final players = await loadPlayers();

    final Map<String, TeamModel> playerTeamMap = {};
    for (final t in _teams) {
      if (t.id == team.id) continue;
      for (final pid in t.playerIds) {
        playerTeamMap[pid] = t;
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TeamRosterScreen(
        team: team,
        players: players,
        teams: _teams,
        playerTeamMap: playerTeamMap,
        onSave: (updated) async {
          await Future.delayed(Duration(milliseconds: 300));

          final updatedPlayers = await loadPlayers();

          await loadTeams(page: _currentPage);

          if (!mounted) return;
          setState(() {
            _players = updatedPlayers; // 🔥 IMPORTANT
          });
        },
      ),
    );
  }

  void _confirmDelete(TeamModel team) {
    if (team.isLocked) {
      _snack('Cannot delete a locked/published team.', error: true);
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Team',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permanently delete "${team.name}"?\nThis cannot be undone.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${team.playerCount} player assignment'
                      '${team.playerCount != 1 ? 's' : ''} will also be removed.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTeam(team);
              _snack('"${team.name}" deleted.');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePublish(TeamModel team) async {
    print("━━━━━━━━━━━━━━━━━━━━━━━");

    print("👉 CLICKED TEAM: ${team.id}");
    print("👉 LOCKED INT: ${team.locked}");

    try {
      http.Response response;

      if (team.locked == 1) {
        print("🔓 UNLOCK CLICKED");

        print("🔓 CALLING: $baseUrl/teams/${team.id}/unlock");

        response = await http.post(
          Uri.parse("$baseUrl/teams/${team.id}/unlock"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        );
      } else {
        print("🔒 PUBLISH CLICKED");

        print("🔒 CALLING: $baseUrl/teams/${team.id}/publish");

        response = await http.put(
          Uri.parse("$baseUrl/teams/${team.id}/publish"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        );
      }

      print("📡 STATUS: ${response.statusCode}");
      print("📡 BODY: ${response.body}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print("✅ SUCCESS");

        await loadTeams(page: _currentPage);

        final updatedPlayers = await loadPlayers();

        if (!mounted) return;
        setState(() {
          _players = updatedPlayers;
        });
        _tabs.animateTo(0);
      } else {
        print("❌ FAILED RESPONSE");
        print("❌ STATUS: ${response.statusCode}");
        print("❌ BODY: ${response.body}");
      }
    } catch (e) {
      print("❌ ERROR: $e");
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title + Create button ──────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Team Management',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A46D8),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Create teams, assign players and manage rosters',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {
                        final currentIndex = _tabs.index;

                        if (_selectedTab == 0) {
                          _openAdd("individual");
                        } else if (_selectedTab == 1) {
                          _openAdd("team_event");
                        } else {
                          _snack("Create not allowed here", error: true);
                        }
                      },
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      label: const Text(
                        'Create Team',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A46D8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 15,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Tournament',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedTournamentId,
                        hint: const Text("Select Tournament"),
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _tournaments.map((t) {
                          return DropdownMenuItem<String>(
                            value: t["id"].toString(),
                            child: Text(t["name"]),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          if (value == null) return;

                          setState(() {
                            _selectedTournamentId = value;
                          });

                          AppSession.setTournament(value);

                          print("✅ SELECTED TOURNAMENT: $value");

                          tournamentId = value;

                          await loadTeams(page: 1);
                          await loadPlayersAndSet();
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Stat cards ─────────────────────────────────────────────────
                Row(
                  children: [
                    _StatCard(
                      label: 'Total Teams',
                      value: '${_teams.length}',
                      icon: Icons.shield_outlined,
                      color: const Color(0xFF0A46D8),
                    ),
                    const SizedBox(width: 14),
                    _StatCard(
                      label: 'Players Assigned',
                      value: '$_totalAssigned',
                      icon: Icons.people_alt_outlined,
                      color: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 14),
                    _StatCard(
                      label: 'Published',
                      value: '$_publishedCount',
                      icon: Icons.lock_outlined,
                      color: const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 14),
                    _StatCard(
                      label: 'In Draft',
                      value: '$_draftCount',
                      icon: Icons.edit_note_outlined,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // ── Lock banner ────────────────────────────────────────────────
                if (_publishedCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF16A34A).withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.lock_outlined,
                            size: 18,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_publishedCount published team'
                                '${_publishedCount != 1 ? 's are' : ' is'} locked',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              Text(
                                'Roster edits disabled. Unlock to make changes.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Main card ──────────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      // Search + filters
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: TextField(
                                      onChanged: (v) =>
                                          setState(() => _search = v),
                                      decoration: InputDecoration(
                                        hintText: 'Search...',
                                        border: InputBorder.none,
                                        prefixIcon: Icon(Icons.search),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            TabBar(
                              controller: _tabs,
                              tabs: [
                                Tab(
                                  text:
                                      'Individual (${_individualTeams.length})',
                                ),
                                Tab(
                                  text:
                                      'Team Events (${_teamEventTeams.length})',
                                ),
                                Tab(text: 'Locked (${_lockedTeams.length})'),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                        height: 560,
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _TeamListView(
                              teams: _individualTeams,
                              players: _players,
                              onRoster: _openRoster,
                              onEdit: _openEdit,
                              onDelete: _confirmDelete,
                              onTogglePublish: _togglePublish,
                              emptyMsg: 'No teams',
                            ),
                            _TeamListView(
                              teams: _teamEventTeams,
                              players: _players,
                              onRoster: _openRoster,
                              onEdit: _openEdit,
                              onDelete: _confirmDelete,
                              onTogglePublish: _togglePublish,
                              emptyMsg: 'No team events',
                            ),
                            _TeamListView(
                              teams: _lockedTeams,
                              players: _players,
                              onRoster: _openRoster,
                              onEdit: _openEdit,
                              onDelete: _confirmDelete,
                              onTogglePublish: _togglePublish,
                              emptyMsg: 'No locked teams',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEAM LIST VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _TeamListView extends StatelessWidget {
  final List<TeamModel> teams;
  final void Function(TeamModel) onRoster;
  final void Function(TeamModel) onEdit;
  final void Function(TeamModel) onDelete;
  final void Function(TeamModel) onTogglePublish;
  final String emptyMsg;
  final IconData emptyIcon;
  final List<PlayerModel> players;

  const _TeamListView({
    required this.teams,
    required this.onRoster,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublish,
    required this.emptyMsg,
    required this.players,
    this.emptyIcon = Icons.shield_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon, size: 30, color: const Color(0xFFD1D5DB)),
            ),
            const SizedBox(height: 14),
            Text(
              emptyMsg,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: teams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _TeamCard(
        team: teams[i],
        players: players,
        onRoster: () => onRoster(teams[i]),
        onEdit: () => onEdit(teams[i]),
        onDelete: () => onDelete(teams[i]),
        onTogglePublish: onTogglePublish,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEAM CARD  — StatelessWidget, safe in ListView
// ─────────────────────────────────────────────────────────────────────────────
class _TeamCard extends StatelessWidget {
  final TeamModel team;
  final VoidCallback onRoster, onEdit, onDelete;
  final Function(TeamModel team) onTogglePublish;
  final List<PlayerModel> players;

  const _TeamCard({
    required this.team,
    required this.onRoster,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublish,
    required this.players,
  });

  Widget _buildCardUI(BuildContext context, TeamModel t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: t.isLocked
              ? const Color(0xFF16A34A).withOpacity(0.4)
              : const Color(0xFFE5E7EB),
          width: t.isLocked ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Avatar + name + status + actions ────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SIDE (Avatar + Info)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: t.statusColor.withOpacity(0.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: t.statusColor.withOpacity(0.35),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          t.name.isNotEmpty ? t.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: t.statusColor,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Name + meta (SAFE)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (t.isLocked)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF16A34A,
                                    ).withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Locked',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          Text(
                            '${t.playerCount}/${t.maxPlayers} players • ${t.sport}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // RIGHT SIDE (Buttons)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionBtn(
                    icon: t.locked == 1
                        ? Icons.visibility_outlined
                        : Icons.manage_accounts_outlined,
                    tooltip: 'Roster',
                    color: const Color(0xFF0A46D8),
                    onTap: onRoster,
                  ),

                  const SizedBox(width: 4),

                  if (!t.isLocked)
                    _ActionBtn(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      color: const Color(0xFF7C3AED),
                      onTap: onEdit,
                    ),

                  const SizedBox(width: 4),

                  _ActionBtn(
                    icon: t.locked == 1
                        ? Icons.lock_open_outlined
                        : Icons.lock_outlined,

                    tooltip: t.locked == 1 ? 'Unlock' : 'Publish/Lock',

                    color: t.locked == 1
                        ? Colors.orange
                        : (t.playerCount == t.maxPlayers
                              ? Colors.green
                              : Colors.grey),

                    onTap: () async {
                      print("Toggle clicked for team ${t.id}");

                      // ALWAYS allow toggle (lock/unlock)
                      await onTogglePublish(t);
                    },
                  ),

                  const SizedBox(width: 4),

                  _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete',
                    color: t.isLocked
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFFEF4444),
                    onTap: t.isLocked ? () {} : onDelete,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Row 2: Progress bar ────────────────────────────────────────
          _ProgressBar(team: t, players: players),

          const SizedBox(height: 12),

          Row(
            children: [
              const Spacer(),
              if (t.coachName.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.person_pin_outlined,
                      size: 13,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      t.coachName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = team;

    return DragTarget<Map<String, String>>(
      onAcceptWithDetails: (details) async {
        final data = details.data;

        print("DROP DETECTED: $data");

        if (team.isLocked) {
          print("🚫 Drag blocked (team locked)");
          return;
        }

        final playerId = data["playerId"];
        final fromTeamId = data["fromTeamId"];

        if (playerId == null || fromTeamId == null) return;
        if (fromTeamId == team.id) return;

        final response = await http.post(
          Uri.parse("https://dev.sports-next.com/api/players/transfer"),
          headers: {
            "Authorization": "Bearer ${AppSession.token}",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "player_id": playerId,
            "team_id": team.id,
            "tournament_id": AppSession.tournamentId,
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print("Player transferred successfully");

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Transferring player...")),
            );
            ;
          }

          final parent = context
              .findAncestorStateOfType<_TeamListScreenState>();

          if (parent != null) {
            await parent.loadTeams();
            await parent.loadPlayersAndSet(); // 🔥 ADD THIS LINE
          }
        } else {
          print("Transfer failed: ${response.body}");
        }
      },

      builder: (context, candidateData, rejectedData) {
        return _buildCardUI(context, t);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final TeamModel team;
  final List<PlayerModel> players;

  const _ProgressBar({required this.team, required this.players});

  @override
  Widget build(BuildContext context) {
    final t = team;
    final color = t.progressColor;
    final slots = t.maxPlayers - t.playerCount;
    final label = t.isFull
        ? 'Team Full ✓'
        : '$slots slot${slots != 1 ? 's' : ''} remaining';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${t.playerCount} / ${t.maxPlayers} players',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: t.isFull
                    ? const Color(0xFF16A34A).withOpacity(0.10)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: t.isFull
                      ? const Color(0xFF16A34A)
                      : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 7, color: Colors.grey.shade100),
              FractionallySizedBox(
                widthFactor: t.fillRatio,
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.7), color],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: List.generate(t.maxPlayers, (i) {
            if (i < t.playerIds.length && t.playerIds.isNotEmpty) {
              final id = t.playerIds[i];

              print("Looking for player id: $id");
              print("Available players: ${players.map((e) => e.id).toList()}");

              final player = players.firstWhere(
                (p) => p.id.toString() == id.toString(),
                orElse: () => PlayerModel(
                  id: id.toString(),
                  firstName: "P$id",
                  lastName: "",
                  email: "",
                  phone: "",
                  gender: "Male",
                  ageGroup: "18–30",
                  skillLevel: "Beginner",
                  city: "",
                  state: "",
                  country: "India",
                  notes: "",
                  isActive: true,
                  createdAt: "",
                  updatedAt: "",
                  history: [],
                  isPlaying: true,
                  eventId: 0,
                  type: "individual",
                ),
              );

              final initials = player.fullName
                  .split(' ')
                  .map((e) => e[0])
                  .take(2)
                  .join()
                  .toUpperCase();

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: team.isLocked
                    ? Opacity(
                        opacity: 0.5, // 🔥 faded look
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: player.avatarColor,
                          child: Text(initials),
                        ),
                      )
                    : Draggable<Map<String, String>>(
                        data: {
                          "playerId": player.id.toString(),
                          "fromTeamId": team.id,
                        },

                        feedback: Material(
                          color: Colors.transparent,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: player.avatarColor,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: player.avatarColor,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: player.avatarColor,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              );
            }

            /// EMPTY SLOT
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.grey.shade200,
                child: Icon(
                  Icons.person_outline,
                  size: 10,
                  color: Colors.grey.shade400,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DropFilter extends StatelessWidget {
  final String value;
  final List<String> items;
  final Map<String, String> display;
  final void Function(String) onChanged;
  const _DropFilter({
    required this.value,
    required this.items,
    required this.display,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 16,
          color: Colors.grey.shade500,
        ),
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF374151),
          fontWeight: FontWeight.w500,
        ),
        items: items
            .map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(display.containsKey(s) ? display[s]! : s),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ),
  );
}

// _ActionBtn — Tooltip + Material + InkWell. Safe in ListView, never in GridView.
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        hoverColor: color.withOpacity(0.18),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 15),
        ),
      ),
    ),
  );
}
