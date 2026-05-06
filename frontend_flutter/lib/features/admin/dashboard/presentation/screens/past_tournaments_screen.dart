import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tms_flutter/core/session/app_session.dart';

class PastTournamentsScreen extends StatefulWidget {
  const PastTournamentsScreen({super.key});

  @override
  State<PastTournamentsScreen> createState() => _PastTournamentsScreenState();
}

class _PastTournamentsScreenState extends State<PastTournamentsScreen> {
  String _searchQuery = '';

  bool _loading = true;
  List<Map<String, String>> _allTournaments = [];

  static const _base = "https://dev.sports-next.com/api";

  Map<String, String> get _headers => {
    "Accept": "application/json",
    "Authorization": "Bearer ${AppSession.token}",
  };

  @override
  void initState() {
    super.initState();
    _fetchPastTournaments();
  }

  Future<void> _fetchPastTournaments() async {
    try {
      final res = await http.get(
        Uri.parse("$_base/tournaments"),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      final list = data is List ? data : (data['data'] ?? []) as List;

      final pastRaw = list
          .where((e) => e['deleted_at'] == null && e['status'] == 'completed')
          .toList();

      final List<Map<String, String>> past = [];

      for (final e in pastRaw) {
        String winner = '';

        try {
          // fetch full tournament to get event groups and standings
          final tRes = await http.get(
            Uri.parse("$_base/tournaments/${e['id']}"),
            headers: _headers,
          );
          final tData = jsonDecode(tRes.body);
          final eventGroups = tData['data']?['eventGroups'] as List? ?? [];

          if (eventGroups.isNotEmpty) {
            // get stage_id from first event group
            final eventGroupId = eventGroups[0]['id']?.toString() ?? '';

            if (eventGroupId.isNotEmpty) {
              final sRes = await http.get(
                Uri.parse("$_base/standings/$eventGroupId"),
                headers: _headers,
              );

              final sData = jsonDecode(sRes.body);
              final standings = List<Map<String, dynamic>>.from(
                sData['data'] ?? [],
              );

              print("STANDINGS DATA: $sData");

              if (standings.isNotEmpty) {
                standings.sort((a, b) {
                  final aPos =
                      int.tryParse('${a['position'] ?? 999999}') ?? 999999;
                  final bPos =
                      int.tryParse('${b['position'] ?? 999999}') ?? 999999;

                  if (aPos != bPos) return aPos.compareTo(bPos);

                  final aPts = int.tryParse('${a['points'] ?? 0}') ?? 0;
                  final bPts = int.tryParse('${b['points'] ?? 0}') ?? 0;
                  return bPts.compareTo(aPts);
                });

                final top = standings.first;
                final topTeamId = '${top['team_id'] ?? ''}';

                if (topTeamId.isNotEmpty) {
                  final teamRes = await http.get(
                    Uri.parse("$_base/tournaments/${e['id']}/teams"),
                    headers: _headers,
                  );

                  final teamData = jsonDecode(teamRes.body);
                  final teams = List<Map<String, dynamic>>.from(
                    teamData is List ? teamData : (teamData['data'] ?? []),
                  );

                  final matchedTeam = teams
                      .cast<Map<String, dynamic>?>()
                      .firstWhere(
                        (t) => '${t?['id'] ?? ''}' == topTeamId,
                        orElse: () => null,
                      );

                  winner = (matchedTeam?['name'] ?? '').toString().trim();

                  print("TOP TEAM ID: $topTeamId");
                  print("TEAMS DATA: $teams");
                  print("WINNER: $winner");
                }
              }
            }
          }
        } catch (err) {
          print("PAST TOURNAMENT WINNER ERROR: $err");
        }

        past.add({
          "name": e['name'] ?? '',
          "sport": e['sport_name'] ?? '',
          "start": e['start_date'] ?? '',
          "end": e['end_date'] ?? '',
          "teams": "0",
          "matches": "0",
          "winner": winner,
        });
      }

      if (mounted)
        setState(() {
          _allTournaments = past;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, String>> get _filtered {
    return _allTournaments.where((t) {
      return t["name"]!.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // Sport → color map
  Color _sportColor(String sport) {
    switch (sport) {
      case 'Cricket':
        return const Color(0xFF3B82F6);
      case 'Football':
        return const Color(0xFF10B981);
      case 'Badminton':
        return const Color(0xFF8B5CF6);
      case 'Tennis':
        return const Color(0xFFF59E0B);
      case 'Padel':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page Header ──────────────────────────────────
          Row(
            children: [
              // Back button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Color(0xFF0A1D4A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Past Tournaments",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A46D8),
                    ),
                  ),
                  Text(
                    "All completed tournaments",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),

              const Spacer(),

              // Total count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A46D8).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0A46D8).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      size: 18,
                      color: Color(0xFF0A46D8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${_allTournaments.length} Tournaments",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A46D8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Search + Filter Row ──────────────────────────
          Row(
            children: [
              // Search bar
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: "Search tournaments...",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),

          const SizedBox(height: 24),

          // ── Tournament Cards Grid ────────────────────────
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
              ? _emptyState()
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _TournamentCard(
                    t: _filtered[i],
                    color: _sportColor(_filtered[i]["sport"]!),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            "No tournaments found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Try a different search or filter",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────
class _FilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

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
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected || _hovered ? widget.color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected ? widget.color : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.selected || _hovered
                  ? Colors.white
                  : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tournament Card ───────────────────────────────────────────
class _TournamentCard extends StatefulWidget {
  final Map<String, String> t;
  final Color color;

  const _TournamentCard({required this.t, required this.color});

  @override
  State<_TournamentCard> createState() => _TournamentCardState();
}

class _TournamentCardState extends State<_TournamentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? widget.color.withOpacity(0.4)
                : Colors.grey.shade200,
            width: _hovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? widget.color.withOpacity(0.12)
                  : Colors.black.withOpacity(0.06),
              blurRadius: _hovered ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: sport badge + completed badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.t["sport"]!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.color,
                    ),
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
                    border: Border.all(color: Colors.green.shade300),
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

            const SizedBox(height: 10),

            // Tournament name
            Text(
              widget.t["name"]!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF0A1D4A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // Date row
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  "${widget.t["start"]} → ${widget.t["end"]}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Teams + Matches row
            Row(
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  "${widget.t["teams"]} Teams",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.sports_score_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  "${widget.t["matches"]} Matches",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),

            const Spacer(),

            // Winner row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 14,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Winner: ${widget.t["winner"]!}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
