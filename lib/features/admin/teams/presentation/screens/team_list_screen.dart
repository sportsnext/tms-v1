// lib/features/admin/teams/presentation/screens/team_list_screen.dart

import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/teams/data/models/team_model.dart';
import 'add_team_screen.dart';
import 'team_roster_screen.dart';

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});
  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen>
    with SingleTickerProviderStateMixin {

  // TODO: replace with GET /api/teams  &  GET /api/players
  final List<TeamModel> _teams   = List.from(TeamSeeds.all);
  final List<PlayerRef> _players = List.from(TeamSeeds.allPlayers);

  String _search       = '';
  String _filterStatus = 'All';
  String _filterSport  = 'All';
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
      final mQ = q.isEmpty ||
          t.name.toLowerCase().contains(q)      ||
          t.sport.toLowerCase().contains(q)     ||
          t.coachName.toLowerCase().contains(q) ||
          t.id.toLowerCase().contains(q);
      final mS = _filterStatus == 'All' || t.status == _filterStatus;
      final mP = _filterSport  == 'All' || t.sport  == _filterSport;
      return mQ && mS && mP;
    }).toList();
  }

  List<TeamModel> get _lockedTeams =>
      _filtered.where((t) => t.isLocked).toList();

  int get _totalAssigned  => _teams.fold(0, (s, t) => s + t.playerCount);
  int get _publishedCount => _teams.where((t) => t.isPublished).length;
  int get _draftCount     => _teams.where((t) => t.status == 'draft').length;

  PlayerRef? _findPlayer(String id) =>
      _players.where((p) => p.id == id).cast<PlayerRef?>().firstOrNull;

  // ── Snackbar ─────────────────────────────────────────────────────────────
  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg,
              style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
        backgroundColor:
            error ? Colors.red.shade700 : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));

  // ── Actions ──────────────────────────────────────────────────────────────
  void _openAdd() => showDialog(
    context: context, barrierDismissible: false,
    builder: (_) => AddTeamScreen(
      existingTeams: _teams,
      onSave: (t) {
        setState(() => _teams.add(t));
        _snack('"${t.name}" created successfully!');
      },
    ),
  );

  void _openEdit(TeamModel team) => showDialog(
    context: context, barrierDismissible: false,
    builder: (_) => AddTeamScreen(
      existingTeams: _teams,
      editTeam: team,
      onSave: (updated) {
        setState(() {
          final i = _teams.indexWhere((t) => t.id == updated.id);
          if (i != -1) _teams[i] = updated;
        });
        _snack('"${updated.name}" updated successfully!');
      },
    ),
  );

  void _openRoster(TeamModel team) {
    // Build map of playerId → teamName for all OTHER teams
    // so the roster screen can show exactly which team each blocked player is in
    final Map<String, String> playerTeamMap = {};
    for (final t in _teams) {
      if (t.id == team.id) continue;
      for (final pid in t.playerIds) {
        playerTeamMap[pid] = t.name;
      }
    }

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => TeamRosterScreen(
        team:           team,
        players:        _players,
        playerTeamMap:  playerTeamMap,
        onSave: (updated) {
          setState(() {
            final i = _teams.indexWhere((t) => t.id == updated.id);
            if (i != -1) _teams[i] = updated;
          });
          _snack('"${updated.name}" roster saved!');
        },
      ),
    );
  }

  void _confirmDelete(TeamModel team) {
    if (team.isLocked) {
      _snack('Cannot delete a locked/published team.', error: true);
      return;
    }
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete Team',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Permanently delete "${team.name}"?\nThis cannot be undone.',
            style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${team.playerCount} player assignment'
              '${team.playerCount != 1 ? 's' : ''} will also be removed.',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF92400E)),
            )),
          ]),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            setState(() => _teams.removeWhere((t) => t.id == team.id));
            _snack('"${team.name}" deleted.');
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: const Text('Delete'),
        ),
      ],
    ));
  }

  void _togglePublish(TeamModel team) {
    final newStatus = team.isPublished ? 'active' : 'published';
    final msg = team.isPublished
        ? '"${team.name}" unlocked — roster editable.'
        : '"${team.name}" published & locked.';
    setState(() {
      final i = _teams.indexWhere((t) => t.id == team.id);
      if (i != -1) _teams[i] = team.copyWith(status: newStatus);
    });
    _snack(msg);
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [

        // ── Title + Create button ──────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Team Management', style: TextStyle(
                fontSize: 30, fontWeight: FontWeight.bold,
                color: Color(0xFF0A46D8))),
            const SizedBox(height: 3),
            Text('Create teams, assign players and manage rosters',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ]),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _openAdd,
            icon: const Icon(Icons.group_add_outlined, size: 18),
            label: const Text('Create Team',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A46D8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ]),

        const SizedBox(height: 24),

        // ── Stat cards ─────────────────────────────────────────────────
        Row(children: [
          _StatCard(label: 'Total Teams',       value: '${_teams.length}',
              icon: Icons.shield_outlined,        color: const Color(0xFF0A46D8)),
          const SizedBox(width: 14),
          _StatCard(label: 'Players Assigned',  value: '$_totalAssigned',
              icon: Icons.people_alt_outlined,    color: const Color(0xFF7C3AED)),
          const SizedBox(width: 14),
          _StatCard(label: 'Published',         value: '$_publishedCount',
              icon: Icons.lock_outlined,          color: const Color(0xFF16A34A)),
          const SizedBox(width: 14),
          _StatCard(label: 'In Draft',          value: '$_draftCount',
              icon: Icons.edit_note_outlined,     color: const Color(0xFFF59E0B)),
        ]),

        const SizedBox(height: 22),

        // ── Lock banner ────────────────────────────────────────────────
        if (_publishedCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF16A34A).withOpacity(0.35)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.lock_outlined,
                    size: 18, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    '$_publishedCount published team'
                    '${_publishedCount != 1 ? 's are' : ' is'} locked',
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534))),
                Text('Roster edits disabled. Unlock to make changes.',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // ── Main card ──────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10, offset: const Offset(0, 2))]),
          child: Column(children: [

            // Search + filters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200)),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by name, sport or coach...',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.grey.shade400, size: 18),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  )),
                  const SizedBox(width: 10),
                  _DropFilter(
                    value: _filterStatus,
                    items: const ['All', 'draft', 'active', 'published', 'archived'],
                    display: const {
                      'All':       'Status: All',
                      'draft':     'Draft',
                      'active':    'Active',
                      'published': 'Published',
                      'archived':  'Archived',
                    },
                    onChanged: (v) => setState(() => _filterStatus = v),
                  ),
                  const SizedBox(width: 8),
                  _DropFilter(
                    value: _filterSport,
                    items: ['All', ..._sportOptions],
                    display: const {'All': 'Sport: All'},
                    onChanged: (v) => setState(() => _filterSport = v),
                  ),
                ]),
                const SizedBox(height: 14),
                TabBar(
                  controller: _tabs,
                  labelColor: const Color(0xFF0A46D8),
                  unselectedLabelColor: Colors.grey.shade500,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  indicatorColor: const Color(0xFF0A46D8),
                  indicatorWeight: 2.5,
                  tabs: [
                    Tab(text: 'All Teams  (${filtered.length})'),
                    Tab(text: 'Published / Locked  (${_lockedTeams.length})'),
                  ],
                ),
              ]),
            ),

            SizedBox(
              height: 560,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _TeamListView(
                    teams:          filtered,
                    findPlayer:     _findPlayer,
                    onRoster:       _openRoster,
                    onEdit:         _openEdit,
                    onDelete:       _confirmDelete,
                    onTogglePublish: _togglePublish,
                    emptyMsg: _search.isEmpty
                        ? 'No teams yet. Create one!'
                        : 'No teams match "$_search"',
                  ),
                  _TeamListView(
                    teams:          _lockedTeams,
                    findPlayer:     _findPlayer,
                    onRoster:       _openRoster,
                    onEdit:         _openEdit,
                    onDelete:       _confirmDelete,
                    onTogglePublish: _togglePublish,
                    emptyMsg:       'No published teams yet',
                    emptyIcon:      Icons.lock_open_outlined,
                  ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEAM LIST VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _TeamListView extends StatelessWidget {
  final List<TeamModel>              teams;
  final PlayerRef? Function(String)  findPlayer;
  final void Function(TeamModel)     onRoster;
  final void Function(TeamModel)     onEdit;
  final void Function(TeamModel)     onDelete;
  final void Function(TeamModel)     onTogglePublish;
  final String                       emptyMsg;
  final IconData                     emptyIcon;

  const _TeamListView({
    required this.teams,
    required this.findPlayer,
    required this.onRoster,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublish,
    required this.emptyMsg,
    this.emptyIcon = Icons.shield_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6), shape: BoxShape.circle),
          child: Icon(emptyIcon,
              size: 30, color: const Color(0xFFD1D5DB)),
        ),
        const SizedBox(height: 14),
        Text(emptyMsg, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280))),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: teams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _TeamCard(
        team:            teams[i],
        findPlayer:      findPlayer,
        onRoster:        () => onRoster(teams[i]),
        onEdit:          () => onEdit(teams[i]),
        onDelete:        () => onDelete(teams[i]),
        onTogglePublish: () => onTogglePublish(teams[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEAM CARD  — StatelessWidget, safe in ListView
// ─────────────────────────────────────────────────────────────────────────────
class _TeamCard extends StatelessWidget {
  final TeamModel                   team;
  final PlayerRef? Function(String) findPlayer;
  final VoidCallback                onRoster, onEdit, onDelete, onTogglePublish;

  const _TeamCard({
    required this.team,
    required this.findPlayer,
    required this.onRoster,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublish,
  });

  @override
  Widget build(BuildContext context) {
    final t       = team;
    final captain = findPlayer(t.captainId);
    final roster  = t.playerIds
        .map(findPlayer)
        .whereType<PlayerRef>()
        .toList();

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
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [

        // ── Row 1: Avatar + name + status + actions ────────────────────
        Row(children: [
          // Team initial circle
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: t.statusColor.withOpacity(0.10),
              shape: BoxShape.circle,
              border: Border.all(
                  color: t.statusColor.withOpacity(0.35), width: 2),
            ),
            child: Center(child: Text(
              t.name.isNotEmpty ? t.name[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                  color: t.statusColor),
            )),
          ),
          const SizedBox(width: 14),

          // Name + meta
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(t.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827)))),
              const SizedBox(width: 8),
              if (t.isLocked) Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min,
                    children: [
                  Icon(Icons.lock_outlined,
                      size: 10, color: Color(0xFF16A34A)),
                  SizedBox(width: 4),
                  Text('Locked', style: TextStyle(
                      fontSize: 9, color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: 3),
            // Show ID + sport (NO tournament)
            Row(children: [
              Icon(Icons.tag_rounded, size: 10, color: Colors.grey.shade400),
              const SizedBox(width: 2),
              Text(t.id, style: const TextStyle(
                  fontSize: 10, color: Color(0xFF0A46D8),
                  fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Icon(Icons.sports_outlined,
                  size: 11, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Text(t.sport, style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(width: 10),
              Icon(Icons.people_outline,
                  size: 11, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Text('${t.playerCount}/${t.maxPlayers} players',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ])),
          const SizedBox(width: 12),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: t.statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(t.statusIcon, size: 11, color: t.statusColor),
              const SizedBox(width: 4),
              Text(t.statusLabel, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: t.statusColor)),
            ]),
          ),
          const SizedBox(width: 10),

          // Action buttons — Tooltip + Material + InkWell (proven safe in ListView)
          _ActionBtn(
            icon: t.isLocked
                ? Icons.visibility_outlined
                : Icons.manage_accounts_outlined,
            tooltip: t.isLocked ? 'View Roster' : 'Manage Roster',
            color: const Color(0xFF0A46D8),
            onTap: onRoster,
          ),
          const SizedBox(width: 4),
          // Edit — only when not locked
          if (!t.isLocked) ...[
            _ActionBtn(
              icon: Icons.edit_outlined,
              tooltip: 'Edit Team',
              color: const Color(0xFF7C3AED),
              onTap: onEdit,
            ),
            const SizedBox(width: 4),
          ],
          _ActionBtn(
            icon: t.isLocked
                ? Icons.lock_open_outlined
                : Icons.lock_outlined,
            tooltip: t.isLocked ? 'Unlock Team' : 'Publish & Lock',
            color: t.isLocked
                ? const Color(0xFF6B7280)
                : const Color(0xFF16A34A),
            onTap: onTogglePublish,
          ),
          const SizedBox(width: 4),
          _ActionBtn(
            icon: Icons.delete_outline_rounded,
            tooltip: t.isLocked
                ? 'Cannot delete a locked team'
                : 'Delete Team',
            color: t.isLocked
                ? const Color(0xFFD1D5DB)
                : const Color(0xFFEF4444),
            onTap: t.isLocked ? () {} : onDelete,
          ),
        ]),

        const SizedBox(height: 14),

        // ── Row 2: Progress bar ────────────────────────────────────────
        _ProgressBar(team: t),

        const SizedBox(height: 12),

        // ── Row 3: Avatars + captain + coach ───────────────────────────
        Row(children: [
          if (roster.isEmpty)
            Text('No players assigned yet', style: TextStyle(
                fontSize: 11, color: Colors.grey.shade400,
                fontStyle: FontStyle.italic))
          else
            SizedBox(
              height: 28,
              width: (roster.length > 5 ? 5 : roster.length) * 22.0 +
                  (roster.length > 5 ? 30.0 : 8.0),
              child: Stack(children: [
                ...List.generate(
                  roster.length > 5 ? 5 : roster.length,
                  (i) => Positioned(
                    left: i * 22.0,
                    child: _PlayerAvatar(player: roster[i], size: 28),
                  ),
                ),
                if (roster.length > 5)
                  Positioned(
                    left: 5 * 22.0,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                      child: Center(child: Text('+${roster.length - 5}',
                          style: TextStyle(fontSize: 8,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold))),
                    ),
                  ),
              ]),
            ),

          const SizedBox(width: 14),

          if (captain != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded,
                  size: 11, color: Color(0xFFF59E0B)),
              const SizedBox(width: 4),
              Text('${captain.fullName} (C)',
                  style: const TextStyle(fontSize: 10,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w700)),
            ]),
          ),

          const Spacer(),

          if (t.coachName.isNotEmpty)
            Row(children: [
              Icon(Icons.person_pin_outlined,
                  size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(t.coachName, style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
            ]),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final TeamModel team;
  const _ProgressBar({required this.team});

  @override
  Widget build(BuildContext context) {
    final t     = team;
    final color = t.progressColor;
    final slots = t.maxPlayers - t.playerCount;
    final label = t.isFull
        ? 'Team Full ✓'
        : '$slots slot${slots != 1 ? 's' : ''} remaining';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${t.playerCount} / ${t.maxPlayers} players',
            style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: t.isFull
                ? const Color(0xFF16A34A).withOpacity(0.10)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: t.isFull
                  ? const Color(0xFF16A34A) : Colors.grey.shade500)),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(children: [
          Container(height: 7, color: Colors.grey.shade100),
          FractionallySizedBox(
            widthFactor: t.fillRatio,
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color.withOpacity(0.7), color]),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 5),
      // Segment dots — capped at 20 to avoid overflow
      Row(children: List.generate(
        t.maxPlayers > 20 ? 20 : t.maxPlayers,
        (i) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: i < t.playerCount ? color : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
      )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(width: 40, height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.bold, color: color, height: 1)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11,
              color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
        ]),
      ]),
    ),
  );
}

class _DropFilter extends StatelessWidget {
  final String value; final List<String> items;
  final Map<String, String> display; final void Function(String) onChanged;
  const _DropFilter({required this.value, required this.items,
      required this.display, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            size: 16, color: Colors.grey.shade500),
        style: const TextStyle(fontSize: 12,
            color: Color(0xFF374151), fontWeight: FontWeight.w500),
        items: items.map((s) => DropdownMenuItem(
            value: s,
            child: Text(display.containsKey(s) ? display[s]! : s)))
            .toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  );
}

// _ActionBtn — Tooltip + Material + InkWell. Safe in ListView, never in GridView.
class _ActionBtn extends StatelessWidget {
  final IconData icon; final Color color;
  final String tooltip; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color,
      required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(7),
        hoverColor: color.withOpacity(0.18),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(padding: const EdgeInsets.all(6),
            child: Icon(icon, color: color, size: 15)),
      ),
    ),
  );
}

class _PlayerAvatar extends StatelessWidget {
  final PlayerRef player; final double size;
  const _PlayerAvatar({required this.player, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
        color: player.avatarColor, shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2)),
    child: Center(child: Text(player.initials, style: TextStyle(
        color: Colors.white, fontSize: size * 0.32,
        fontWeight: FontWeight.bold))),
  );
}