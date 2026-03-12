// lib/features/admin/teams/presentation/screens/team_roster_screen.dart

import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/teams/data/models/team_model.dart';

// ══════════════════════════════════════════════════════════════════════════════
// TEAM ROSTER SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class TeamRosterScreen extends StatefulWidget {
  final TeamModel                team;
  final List<PlayerRef>          players;
  /// Maps playerId → team name for players assigned in OTHER teams.
  final Map<String, String>      playerTeamMap;
  final void Function(TeamModel) onSave;

  const TeamRosterScreen({
    super.key,
    required this.team,
    required this.players,
    required this.playerTeamMap,
    required this.onSave,
  });

  @override
  State<TeamRosterScreen> createState() => _TeamRosterScreenState();
}

class _TeamRosterScreenState extends State<TeamRosterScreen>
    with SingleTickerProviderStateMixin {
  late TeamModel     _team;
  late TabController _tabs;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _team = widget.team.copyWith();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  PlayerRef? _find(String id) =>
      widget.players.where((p) => p.id == id).cast<PlayerRef?>().firstOrNull;

  List<PlayerRef> get _roster =>
      _team.playerIds.map(_find).whereType<PlayerRef>().toList();

  List<PlayerRef> get _searchResults {
    final q      = _search.toLowerCase().trim();
    final inTeam = _team.playerIds.toSet();
    return widget.players.where((p) {
      if (!p.isActive)                              return false;
      if (inTeam.contains(p.id))                   return false;
      if (widget.playerTeamMap.containsKey(p.id))  return false;
      if (q.isEmpty) return true;
      return p.fullName.toLowerCase().contains(q) ||
             p.email.toLowerCase().contains(q)    ||
             p.phone.contains(q)                  ||
             p.city.toLowerCase().contains(q);
    }).toList();
  }

  /// Returns blocked players paired with the team name they belong to.
  List<({PlayerRef player, String teamName})> get _blockedPlayers =>
      widget.players
          .where((p) => widget.playerTeamMap.containsKey(p.id))
          .map((p) => (
                player:   p,
                teamName: widget.playerTeamMap[p.id]!,
              ))
          .toList();

  void _assign(PlayerRef p) {
    if (_team.isFull)                             return;
    if (_team.playerIds.contains(p.id))          return;
    if (widget.playerTeamMap.containsKey(p.id))  return;
    setState(() => _team = _team.copyWith(
        playerIds: [..._team.playerIds, p.id]));
  }

  void _remove(String id) {
    setState(() {
      final ids = List<String>.from(_team.playerIds)..remove(id);
      _team = _team.copyWith(
          playerIds: ids,
          captainId: _team.captainId == id ? '' : _team.captainId);
    });
  }

  void _toggleCaptain(String id) => setState(() => _team =
      _team.copyWith(captainId: _team.captainId == id ? '' : id));

  void _save() { widget.onSave(_team); Navigator.pop(context); }

  @override
  Widget build(BuildContext context) {
    final isLocked = _team.isLocked;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Container(
        width: 840,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40, offset: const Offset(0, 16))],
        ),
        child: Column(children: [
          _buildHeader(isLocked),
          _buildTabBar(isLocked),
          Expanded(child: TabBarView(controller: _tabs, children: [
            _RosterTab(
              team: _team, roster: _roster, isLocked: isLocked,
              onRemove: _remove, onToggleCaptain: _toggleCaptain,
            ),
            isLocked
                ? _AvailabilityTab(
                    allPlayers: widget.players, teamIds: _team.playerIds)
                : _AssignTab(
                    team: _team, results: _searchResults,
                    blockedPlayers: _blockedPlayers, search: _search,
                    onSearch: (v) => setState(() => _search = v),
                    onAssign: _assign),
          ])),
          _buildFooter(isLocked),
        ]),
      ),
    );
  }

  Widget _buildHeader(bool isLocked) => Container(
    padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
    decoration: BoxDecoration(
      color: isLocked ? const Color(0xFFF0FDF4) : const Color(0xFFF0F5FF),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
    ),
    child: Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: (isLocked ? const Color(0xFF16A34A) : const Color(0xFF0A46D8))
              .withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
            isLocked ? Icons.lock_outlined : Icons.group_outlined,
            color: isLocked ? const Color(0xFF16A34A) : const Color(0xFF0A46D8),
            size: 22),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_team.name, style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold,
              color: Color(0xFF0A1D4A))),
          const SizedBox(width: 10),
          if (isLocked) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outlined, size: 11, color: Color(0xFF16A34A)),
              SizedBox(width: 5),
              Text('PUBLISHED — LOCKED', style: TextStyle(
                  fontSize: 9, color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w800, letterSpacing: 0.4)),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          _InfoChip(label: _team.sport, icon: Icons.sports_outlined),
          const SizedBox(width: 8),
          Row(children: [
            Icon(Icons.tag_rounded, size: 11, color: Colors.grey.shade400),
            Text(_team.id, style: const TextStyle(
                fontSize: 11, color: Color(0xFF0A46D8),
                fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          ]),
          if (_team.coachName.isNotEmpty) ...[
            const SizedBox(width: 8),
            _InfoChip(label: 'Coach: ${_team.coachName}',
                icon: Icons.person_pin_outlined),
          ],
        ]),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: _team.progressColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _team.progressColor.withOpacity(0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${_team.playerCount}/${_team.maxPlayers}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: _team.progressColor)),
          Text('players',
              style: TextStyle(fontSize: 10, color: _team.progressColor)),
        ]),
      ),
      const SizedBox(width: 14),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.close_rounded,
              color: Colors.grey.shade600, size: 20),
        ),
      ),
    ]),
  );

  Widget _buildTabBar(bool isLocked) => Container(
    decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
    child: TabBar(
      controller: _tabs,
      labelColor: const Color(0xFF0A46D8),
      unselectedLabelColor: Colors.grey.shade500,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      indicatorColor: const Color(0xFF0A46D8),
      indicatorWeight: 2.5,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      tabs: [
        Tab(text: 'Current Roster  (${_roster.length}/${_team.maxPlayers})'),
        Tab(text: isLocked ? 'Player Availability' : 'Assign Players'),
      ],
    ),
  );

  Widget _buildFooter(bool isLocked) => Container(
    padding: const EdgeInsets.fromLTRB(28, 14, 28, 18),
    decoration: BoxDecoration(
      color: isLocked ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
      borderRadius:
          const BorderRadius.vertical(bottom: Radius.circular(24)),
      border: Border(top: BorderSide(
        color: isLocked
            ? const Color(0xFF16A34A).withOpacity(0.2)
            : Colors.grey.shade200,
      )),
    ),
    child: Row(children: [
      Icon(isLocked ? Icons.lock_outlined : Icons.info_outline,
          size: 14,
          color: isLocked ? const Color(0xFF16A34A) : Colors.grey.shade400),
      const SizedBox(width: 8),
      Expanded(child: Text(
        isLocked
            ? 'Roster is locked. Unlock the team from the list to make changes.'
            : 'Changes are saved locally until connected to your API.',
        style: TextStyle(fontSize: 11,
            color: isLocked ? Colors.green.shade700 : Colors.grey.shade400),
      )),
      const SizedBox(width: 20),
      if (isLocked)
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 13),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text('Close',
              style: TextStyle(fontWeight: FontWeight.w700)),
        )
      else ...[
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade300)),
          child: Text('Cancel', style: TextStyle(
              color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined, size: 17),
          label: const Text('Save Roster',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A46D8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 26, vertical: 13),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ],
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// ROSTER TAB
// ══════════════════════════════════════════════════════════════════════════════
class _RosterTab extends StatelessWidget {
  final TeamModel team; final List<PlayerRef> roster;
  final bool isLocked;
  final void Function(String) onRemove, onToggleCaptain;
  const _RosterTab({required this.team, required this.roster,
      required this.isLocked, required this.onRemove,
      required this.onToggleCaptain});

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        child: _FullProgressBar(team: team)),
    if (isLocked)
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF16A34A).withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.lock_outlined,
                size: 14, color: Color(0xFF16A34A)),
            const SizedBox(width: 10),
            Expanded(child: Text('Roster is locked. Unlock the team to edit.',
                style: TextStyle(fontSize: 12, color: Colors.green.shade700))),
          ]),
        ),
      ),
    const SizedBox(height: 8),
    Expanded(
      child: roster.isEmpty
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.group_off_outlined,
                size: 44, color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Text('No players in roster yet',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
            if (!isLocked)
              Text("Go to 'Assign Players' tab to add",
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade300)),
          ]))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              itemCount: roster.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (_, i) {
                final p = roster[i]; final isCap = team.captainId == p.id;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: isCap
                            ? const Color(0xFFF59E0B).withOpacity(0.12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: isCap
                          ? const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFF59E0B))
                          : Text('${i + 1}', style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500))),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(radius: 20,
                      backgroundColor: p.avatarColor.withOpacity(0.15),
                      child: Text(p.initials, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: p.avatarColor)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Text(p.fullName, style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: Color(0xFF111827))),
                        const SizedBox(width: 6),
                        if (isCap) _MiniTag(label: 'Captain',
                            color: const Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        _MiniTag(label: p.skillLevel, color: p.skillColor),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.tag_rounded,
                            size: 9, color: Colors.grey.shade400),
                        Text(p.id, style: const TextStyle(
                            fontSize: 9, color: Color(0xFF0A46D8),
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Flexible(child: Text('${p.email}  ·  ${p.city}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500))),
                      ]),
                    ])),
                    if (!isLocked) ...[
                      _ActionBtn(
                        icon: Icons.star_rounded,
                        tooltip: isCap ? 'Remove captain' : 'Set as captain',
                        color: isCap
                            ? const Color(0xFFF59E0B) : Colors.grey.shade400,
                        onTap: () => onToggleCaptain(p.id),
                      ),
                      const SizedBox(width: 4),
                      _ActionBtn(
                        icon: Icons.person_remove_outlined,
                        tooltip: 'Remove from roster',
                        color: const Color(0xFFEF4444),
                        onTap: () => onRemove(p.id),
                      ),
                    ],
                    if (isLocked)
                      Icon(Icons.lock_outlined,
                          size: 13, color: Colors.grey.shade300),
                  ]),
                );
              }),
    ),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// ASSIGN TAB  — ONE ListView containing both available + blocked rows
//              so there is NEVER an overflow regardless of list length
// ══════════════════════════════════════════════════════════════════════════════
class _AssignTab extends StatelessWidget {
  final TeamModel                team;
  final List<PlayerRef>          results;
  final List<({PlayerRef player, String teamName})> blockedPlayers;
  final String                   search;
  final void Function(String)    onSearch;
  final void Function(PlayerRef) onAssign;

  const _AssignTab({
    required this.team, required this.results,
    required this.blockedPlayers, required this.search,
    required this.onSearch, required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = team.isFull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Fixed header ─────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          if (isFull)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF16A34A).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline,
                    size: 15, color: Color(0xFF16A34A)),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Team is full (${team.maxPlayers}/${team.maxPlayers}). '
                  'Remove a player to add more.',
                  style: const TextStyle(fontSize: 12,
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.w600),
                )),
              ]),
            ),
          if (!isFull)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 13, color: Color(0xFF0A46D8)),
                const SizedBox(width: 6),
                Flexible(child: Text(
                  '${team.maxPlayers - team.playerCount} slot'
                  '${team.maxPlayers - team.playerCount != 1 ? 's' : ''}'
                  ' available  ·  Only active, unassigned players shown',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                )),
              ]),
            ),
          // Search box
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: isFull ? Colors.grey.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              enabled: !isFull,
              onChanged: onSearch,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: isFull
                    ? 'Team full — remove a player to add more'
                    : 'Search by name, email, phone or city...',
                hintStyle: TextStyle(
                    fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search,
                    size: 18, color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ]),
      ),

      // ── Single scrollable body ────────────────────────────────────────────
      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [

          // Empty state for available
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(children: [
                Icon(
                  isFull ? Icons.check_circle_outline
                      : search.isEmpty ? Icons.people_outline
                      : Icons.search_off_rounded,
                  size: 40, color: Colors.grey.shade200,
                ),
                const SizedBox(height: 10),
                Text(
                  isFull ? 'Team is full'
                      : search.isEmpty ? 'Type above to search players'
                      : 'No players match "$search"',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
              ]),
            ),

          // Available player rows
          ...List.generate(results.length, (i) {
            final p = results[i];
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  CircleAvatar(radius: 20,
                    backgroundColor: p.avatarColor.withOpacity(0.15),
                    child: Text(p.initials, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: p.avatarColor)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text(p.fullName, style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: Color(0xFF111827))),
                      const SizedBox(width: 6),
                      _MiniTag(label: p.skillLevel, color: p.skillColor),
                      const SizedBox(width: 4),
                      _MiniTag(label: p.gender,
                          color: Colors.grey.shade500),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.tag_rounded,
                          size: 9, color: Colors.grey.shade400),
                      Text(p.id, style: const TextStyle(
                          fontSize: 9, color: Color(0xFF0A46D8),
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Flexible(child: Text('${p.email}  ·  ${p.city}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500))),
                    ]),
                  ])),
                  ElevatedButton.icon(
                    onPressed: () => onAssign(p),
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Assign', style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A46D8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                ]),
              ),
              if (i < results.length - 1)
                Divider(height: 1, color: Colors.grey.shade100),
            ]);
          }),

          // ── Blocked section (in another team) ────────────────────────────
          if (blockedPlayers.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(children: [
              Icon(Icons.block_rounded,
                  size: 13, color: Colors.orange.shade500),
              const SizedBox(width: 6),
              Text(
                '${blockedPlayers.length} player'
                '${blockedPlayers.length != 1 ? 's' : ''} '
                'already assigned to another team',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700),
              ),
            ]),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200)),
              child: Column(children: List.generate(
                  blockedPlayers.length, (i) {
                final entry    = blockedPlayers[i];
                final p        = entry.player;
                final teamName = entry.teamName;
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(children: [
                      CircleAvatar(radius: 18,
                        backgroundColor: p.avatarColor.withOpacity(0.12),
                        child: Text(p.initials, style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold,
                            color: p.avatarColor)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(p.fullName, style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text('${p.email}  ·  ${p.city}',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade400)),
                      ])),
                      // Show exact team name so admin knows where to look
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.orange.shade200)),
                        child: Row(mainAxisSize: MainAxisSize.min,
                            children: [
                          Icon(Icons.shield_outlined,
                              size: 11, color: Colors.orange.shade600),
                          const SizedBox(width: 5),
                          Text(teamName, style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: Colors.orange.shade700)),
                        ]),
                      ),
                    ]),
                  ),
                  if (i < blockedPlayers.length - 1)
                    Divider(height: 1, color: Colors.orange.shade100),
                ]);
              })),
            ),
          ],
        ],
      )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AVAILABILITY TAB
// ══════════════════════════════════════════════════════════════════════════════
class _AvailabilityTab extends StatelessWidget {
  final List<PlayerRef> allPlayers; final List<String> teamIds;
  const _AvailabilityTab({required this.allPlayers, required this.teamIds});

  @override
  Widget build(BuildContext context) {
    final inTeam    = teamIds.toSet();
    final roster    = allPlayers.where((p) => inTeam.contains(p.id)).toList();
    final available = allPlayers
        .where((p) => !inTeam.contains(p.id) && p.isActive).toList();
    final inactive  = allPlayers.where((p) => !p.isActive).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _AvailGroup(title: 'In This Team', count: roster.length,
            players: roster, icon: Icons.shield_outlined,
            color: const Color(0xFF0A46D8), badge: 'In Roster'),
        const SizedBox(height: 18),
        _AvailGroup(title: 'Available', count: available.length,
            players: available, icon: Icons.check_circle_outline,
            color: const Color(0xFF16A34A), badge: 'Available'),
        if (inactive.isNotEmpty) ...[
          const SizedBox(height: 18),
          _AvailGroup(title: 'Inactive', count: inactive.length,
              players: inactive, icon: Icons.block_outlined,
              color: const Color(0xFF9CA3AF), badge: 'Inactive'),
        ],
      ]),
    );
  }
}

class _AvailGroup extends StatelessWidget {
  final String title, badge; final int count;
  final IconData icon; final Color color; final List<PlayerRef> players;
  const _AvailGroup({required this.title, required this.count,
      required this.players, required this.icon,
      required this.color, required this.badge});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 30, height: 30,
          decoration: BoxDecoration(color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: color)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 13,
          fontWeight: FontWeight.bold, color: Color(0xFF111827))),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20)),
        child: Text('$count', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    ]),
    const SizedBox(height: 8),
    if (players.isEmpty)
      Padding(padding: const EdgeInsets.only(left: 40),
          child: Text('None', style: TextStyle(
              fontSize: 12, fontStyle: FontStyle.italic,
              color: Colors.grey.shade300)))
    else
      Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15))),
        child: Column(children: List.generate(players.length, (i) =>
            Column(children: [
          Padding(padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
            child: Row(children: [
              CircleAvatar(radius: 18,
                backgroundColor: players[i].avatarColor.withOpacity(0.15),
                child: Text(players[i].initials, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold,
                    color: players[i].avatarColor)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(players[i].fullName, style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
                Row(children: [
                  Icon(Icons.tag_rounded, size: 9, color: Colors.grey.shade400),
                  Text(players[i].id, style: const TextStyle(
                      fontSize: 9, color: Color(0xFF0A46D8),
                      fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text(players[i].skillLevel, style: TextStyle(
                      fontSize: 9, color: players[i].skillColor,
                      fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text(players[i].city, style: TextStyle(
                      fontSize: 9, color: Colors.grey.shade400)),
                ]),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(badge, style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
          ),
          if (i < players.length - 1)
            Divider(height: 1, color: color.withOpacity(0.10)),
        ]))),
      ),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// FULL PROGRESS BAR
// ══════════════════════════════════════════════════════════════════════════════
class _FullProgressBar extends StatelessWidget {
  final TeamModel team;
  const _FullProgressBar({required this.team});

  @override
  Widget build(BuildContext context) {
    final color = team.progressColor;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Roster Size', style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
        const Spacer(),
        Text('${team.playerCount} / ${team.maxPlayers}'
            '  (${(team.fillRatio * 100).round()}%)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: color)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(children: [
          Container(height: 10, color: Colors.grey.shade100),
          FractionallySizedBox(widthFactor: team.fillRatio,
            child: Container(height: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color.withOpacity(0.6), color]),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: List.generate(
        team.maxPlayers > 20 ? 20 : team.maxPlayers,
        (i) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Container(height: 4,
            decoration: BoxDecoration(
              color: i < team.playerCount ? color : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
      )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED TINY WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
class _ActionBtn extends StatelessWidget {
  final IconData icon; final Color color;
  final String tooltip; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color,
      required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(7),
        hoverColor: color.withOpacity(0.18),
        splashColor: Colors.transparent, highlightColor: Colors.transparent,
        child: Padding(padding: const EdgeInsets.all(6),
            child: Icon(icon, color: color, size: 15))),
    ),
  );
}

class _MiniTag extends StatelessWidget {
  final String label; final Color color;
  const _MiniTag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(
        fontSize: 9, fontWeight: FontWeight.w700, color: color)),
  );
}

class _InfoChip extends StatelessWidget {
  final String label; final IconData icon;
  const _InfoChip({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.grey.shade500),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11,
          color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
    ]),
  );
}