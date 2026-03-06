import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tms_flutter/features/admin/players/data/models/player_model.dart';
import 'add_player_screen.dart';
import 'edit_player_screen.dart';

// pubspec.yaml dependency required:
//   file_picker: ^8.0.0
//
// dart:html  → Flutter Web (already available, no extra package needed)
// For mobile/desktop builds, swap _downloadTemplate() with:
//   path_provider + dart:io File write, then open with share_plus

// Place at: lib/features/admin/players/presentation/screens/player_list_screen.dart

class PlayerListScreen extends StatefulWidget {
  const PlayerListScreen({super.key});
  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen>
    with SingleTickerProviderStateMixin {

  // TODO: replace with GET /api/players/all
  final List<PlayerModel> _players = PlayerSeeds.all;

  String _searchQuery  = '';
  String _filterSkill  = 'All';
  String _filterGender = 'All';
  bool   _showInactive = false;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  // ── Filtered list ─────────────────────────────────────────────────────────────
  List<PlayerModel> get _filtered => _players.where((p) {
    if (!_showInactive && !p.isActive) return false;
    final q = _searchQuery.toLowerCase();
    final matchQ = q.isEmpty ||
        p.fullName.toLowerCase().contains(q) ||
        p.email.toLowerCase().contains(q) ||
        p.phone.contains(q) ||
        p.city.toLowerCase().contains(q);
    final matchS = _filterSkill  == 'All' || p.skillLevel == _filterSkill;
    final matchG = _filterGender == 'All' || p.gender     == _filterGender;
    return matchQ && matchS && matchG;
  }).toList();

  // ── Duplicate groups ──────────────────────────────────────────────────────────
  List<List<PlayerModel>> get _duplicateGroups {
    final used   = <String>{};
    final groups = <List<PlayerModel>>[];
    for (final a in _players) {
      if (used.contains(a.id)) continue;
      final group = <PlayerModel>[a];
      for (final b in _players) {
        if (b.id == a.id || used.contains(b.id)) continue;
        if (a.duplicateScore(b) >= 4) group.add(b);
      }
      if (group.length > 1) {
        used.addAll(group.map((p) => p.id));
        groups.add(group);
      }
    }
    return groups;
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────────
  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: error ? Colors.red.shade700 : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Soft delete (deactivate / reactivate) ─────────────────────────────────────
  void _toggleActive(PlayerModel p) {
    setState(() {
      final i = _players.indexWhere((x) => x.id == p.id);
      if (i != -1) _players[i] = _players[i].copyWith(isActive: !p.isActive);
    });
    _snack(p.isActive ? '"${p.fullName}" deactivated' : '"${p.fullName}" reactivated');
  }

  // ── Hard delete ───────────────────────────────────────────────────────────────
  void _confirmDelete(PlayerModel p) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400, padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64, height: 64,
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.person_remove_outlined, color: Colors.red.shade600, size: 30)),
            const SizedBox(height: 16),
            const Text("Delete Player",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Permanently delete "${p.fullName}"?\nAll match history will also be removed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.6)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200)),
              child: Row(children: [
                Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Expanded(child: Text('Tip: Use Deactivate to keep history intact.',
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade800))),
              ]),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: Colors.grey.shade300)),
                child: Text("Cancel",
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  setState(() => _players.removeWhere((x) => x.id == p.id));
                  Navigator.pop(context);
                  _snack('"${p.fullName}" deleted');
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.w600)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Merge dialog ──────────────────────────────────────────────────────────────
  void _showMerge(List<PlayerModel> group) {
    showDialog(
      context: context,
      builder: (_) => _MergeDialog(
        group: group,
        onMerge: (PlayerModel primary, List<PlayerModel> others) {
          // Collect all history from others into primary
          final mergedHistory = [
            ...primary.history,
            ...others.expand((p) => p.history),
          ];
          final merged = primary.copyWith(
            history: mergedHistory,
            updatedAt: DateTime.now().toIso8601String(),
          );
          setState(() {
            _players.removeWhere((p) => group.any((g) => g.id == p.id));
            _players.insert(0, merged);
          });
          _snack('${group.length} records merged → "${merged.fullName}"');
        },
      ),
    );
  }

  // ── Activity history ──────────────────────────────────────────────────────────
  void _showHistory(PlayerModel p) {
    showDialog(context: context, builder: (_) => _HistoryDialog(player: p));
  }

  // ── Bulk upload ───────────────────────────────────────────────────────────────
  void _showBulkUpload() {
    showDialog(
      context: context,
      builder: (_) => _BulkUploadDialog(
        onImport: (List<PlayerModel> imported) {
          setState(() => _players.addAll(imported));
          _snack('${imported.length} players imported successfully!');
        },
      ),
    );
  }

  // ── Add / Edit ────────────────────────────────────────────────────────────────
  void _openAdd() {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AddPlayerScreen(onSave: (PlayerModel p) {
        setState(() => _players.add(p));
        _snack('"${p.fullName}" added successfully!');
      }),
    );
  }

  void _openEdit(PlayerModel p) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => EditPlayerScreen(
        player: p,
        onSave: (PlayerModel updated) {
          setState(() {
            final i = _players.indexWhere((x) => x.id == updated.id);
            if (i != -1) _players[i] = updated;
          });
          _snack('"${updated.fullName}" updated!');
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final active     = _players.where((p) =>  p.isActive).length;
    final inactive   = _players.where((p) => !p.isActive).length;
    final dupGroups  = _duplicateGroups;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Title + action buttons ──────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Player Master",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold,
                    color: Color(0xFF0A46D8))),
            const SizedBox(height: 3),
            Text("Manage player profiles, history and deduplication",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ]),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _showBulkUpload,
            icon: const Icon(Icons.upload_file_outlined, size: 17),
            label: const Text("Bulk Upload",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0A46D8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              side: const BorderSide(color: Color(0xFF0A46D8), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _openAdd,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text("Add Player",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A46D8), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),

        const SizedBox(height: 24),

        // ── Stat cards ──────────────────────────────────────────────────────────
        Row(children: [
          _StatCard(label: "Total Players", value: "${_players.length}",
              icon: Icons.people_outline, color: const Color(0xFF0A46D8)),
          const SizedBox(width: 14),
          _StatCard(label: "Active", value: "$active",
              icon: Icons.check_circle_outline, color: const Color(0xFF16A34A)),
          const SizedBox(width: 14),
          _StatCard(label: "Inactive", value: "$inactive",
              icon: Icons.block_outlined, color: const Color(0xFF6B7280)),
          const SizedBox(width: 14),
          _StatCard(
            label: "Duplicates Found", value: "${dupGroups.length}",
            icon: Icons.content_copy_outlined,
            color: dupGroups.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFF6B7280),
          ),
        ]),

        const SizedBox(height: 22),

        // ── Duplicate warning banner ────────────────────────────────────────────
        if (dupGroups.isNotEmpty) ...[
          _DuplicateBanner(
            count: dupGroups.length,
            onReview: () {
              _tabs.animateTo(1);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
        ],

        // ── Main card (tabs + table) ────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Column(children: [

            // Search + filter row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _SearchBox(
                    onChanged: (v) => setState(() => _searchQuery = v),
                  )),
                  const SizedBox(width: 10),
                  _DropFilter(
                    value: _filterSkill,
                    label: "Skill",
                    items: const ['All','Beginner','Intermediate','Advanced','Professional'],
                    onChanged: (v) => setState(() => _filterSkill = v),
                  ),
                  const SizedBox(width: 8),
                  _DropFilter(
                    value: _filterGender,
                    label: "Gender",
                    items: const ['All','Male','Female','Other'],
                    onChanged: (v) => setState(() => _filterGender = v),
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: "Inactive",
                    icon: Icons.visibility_outlined,
                    active: _showInactive,
                    onTap: () => setState(() => _showInactive = !_showInactive),
                  ),
                ]),
                const SizedBox(height: 14),
                // Tab bar
                TabBar(
                  controller: _tabs,
                  labelColor: const Color(0xFF0A46D8),
                  unselectedLabelColor: Colors.grey.shade500,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  indicatorColor: const Color(0xFF0A46D8),
                  indicatorWeight: 2.5,
                  tabs: [
                    Tab(text: "All Players  (${_filtered.length})"),
                    Tab(text: "Duplicates  (${dupGroups.length})"),
                  ],
                ),
              ]),
            ),

            // Tab views
            SizedBox(
              height: 530,
              child: TabBarView(
                controller: _tabs,
                children: [
                  // ── Tab 1: Players table ───────────────────────────────────────
                  _filtered.isEmpty
                      ? _EmptyState(msg:
                          _searchQuery.isEmpty ? "No players yet. Add one!" :
                          "No players match \"$_searchQuery\"")
                      : _PlayersTable(
                          players:   _filtered,
                          onEdit:    _openEdit,
                          onDelete:  _confirmDelete,
                          onToggle:  _toggleActive,
                          onHistory: _showHistory,
                        ),

                  // ── Tab 2: Duplicates ──────────────────────────────────────────
                  dupGroups.isEmpty
                      ? const _EmptyState(msg: "No duplicate players detected 🎉",
                          icon: Icons.verified_outlined)
                      : _DuplicatesTab(groups: dupGroups, onMerge: _showMerge),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PLAYERS TABLE
// ══════════════════════════════════════════════════════════════════════════════

class _PlayersTable extends StatelessWidget {
  final List<PlayerModel> players;
  final void Function(PlayerModel) onEdit, onDelete, onToggle, onHistory;
  const _PlayersTable({required this.players, required this.onEdit,
      required this.onDelete, required this.onToggle, required this.onHistory});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header row
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(children: [
          const SizedBox(width: 44),
          const SizedBox(width: 12),
          _H("PLAYER",       flex: 3),
          _H("GENDER / AGE", flex: 2),
          _H("SKILL",        flex: 2),
          _H("LOCATION",     flex: 2),
          _H("MATCHES",      flex: 1),
          _H("STATUS",       flex: 1),
          _H("ACTIONS",      flex: 2),
        ]),
      ),
      // Data rows
      Expanded(child: ListView.builder(
        itemCount: players.length,
        itemBuilder: (_, i) => _PlayerRow(
          player: players[i],
          onEdit:    () => onEdit(players[i]),
          onDelete:  () => onDelete(players[i]),
          onToggle:  () => onToggle(players[i]),
          onHistory: () => onHistory(players[i]),
        ),
      )),
    ]);
  }
}

class _H extends StatelessWidget {
  final String text; final int flex;
  const _H(this.text, {required this.flex});
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(text, style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: Color(0xFF9CA3AF), letterSpacing: 0.8)),
  );
}

class _PlayerRow extends StatefulWidget {
  final PlayerModel player;
  final VoidCallback onEdit, onDelete, onToggle, onHistory;
  const _PlayerRow({required this.player, required this.onEdit,
      required this.onDelete, required this.onToggle, required this.onHistory});
  @override
  State<_PlayerRow> createState() => _PlayerRowState();
}

class _PlayerRowState extends State<_PlayerRow> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: _hov ? const Color(0xFF0A46D8).withOpacity(0.03) : Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(children: [
          _Avatar(player: p, radius: 22),
          const SizedBox(width: 12),
          // Name + email
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(p.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: p.isActive ? const Color(0xFF111827) : Colors.grey.shade400))),
              if (!p.isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text("Inactive", style: TextStyle(
                      fontSize: 9, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(p.email, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          // Gender / Age
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.gender, style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
            Text(p.ageGroup, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          // Skill badge
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: p.skillColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(p.skillLevel, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: p.skillColor)),
            ),
          )),
          // Location
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.city, style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
            Text(p.state, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          // Matches / Wins
          Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${p.totalMatches}", style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A46D8))),
            Text("${p.wins}W", style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ])),
          // Status dot
          Expanded(flex: 1, child: Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(
                    color: p.isActive ? const Color(0xFF16A34A) : Colors.grey.shade400,
                    shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(p.isActive ? "Active" : "Off",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: p.isActive ? const Color(0xFF16A34A) : Colors.grey.shade400)),
          ])),
          // Action buttons
          Expanded(flex: 2, child: Row(children: [
            _ActionBtn(icon: Icons.history_outlined,
                tooltip: "Match History", color: const Color(0xFF7C3AED), onTap: widget.onHistory),
            const SizedBox(width: 4),
            _ActionBtn(icon: Icons.edit_outlined,
                tooltip: "Edit", color: const Color(0xFFF59E0B), onTap: widget.onEdit),
            const SizedBox(width: 4),
            _ActionBtn(
              icon: p.isActive ? Icons.block_outlined : Icons.check_circle_outline,
              tooltip: p.isActive ? "Deactivate" : "Reactivate",
              color: p.isActive ? const Color(0xFF6B7280) : const Color(0xFF16A34A),
              onTap: widget.onToggle,
            ),
            const SizedBox(width: 4),
            _ActionBtn(icon: Icons.delete_outline_rounded,
                tooltip: "Delete", color: const Color(0xFFEF4444), onTap: widget.onDelete),
          ])),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DUPLICATES TAB
// ══════════════════════════════════════════════════════════════════════════════

class _DuplicatesTab extends StatelessWidget {
  final List<List<PlayerModel>> groups;
  final void Function(List<PlayerModel>) onMerge;
  const _DuplicatesTab({required this.groups, required this.onMerge});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (_, gi) {
        final group = groups[gi];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Group header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
              child: Row(children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFF59E0B))),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("${group.length} Possible Duplicates",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E))),
                  Text("Email & phone match — likely the same person",
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                ]),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.merge_outlined, size: 15),
                  label: const Text("Merge Records",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () => onMerge(group),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ),
            Divider(height: 1, color: Colors.amber.shade100),
            // Players in group
            ...group.map((p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                _Avatar(player: p, radius: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(p.fullName, style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: p.skillColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(p.skillLevel, style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: p.skillColor)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text('${p.email}  ·  ${p.phone}  ·  ${p.city}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text("${p.totalMatches} matches",
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0A46D8),
                          fontWeight: FontWeight.w600)),
                  Text("Added ${p.createdAt}",
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ]),
              ]),
            )),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MERGE DIALOG 
// ══════════════════════════════════════════════════════════════════════════════

class _MergeDialog extends StatefulWidget {
  final List<PlayerModel> group;
  final void Function(PlayerModel primary, List<PlayerModel> others) onMerge;
  const _MergeDialog({required this.group, required this.onMerge});
  @override
  State<_MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<_MergeDialog> {
  late int _primaryIdx;

  @override
  void initState() {
    super.initState();
    // Default primary = record with more history
    int best = 0;
    for (int i = 1; i < widget.group.length; i++) {
      if (widget.group[i].totalMatches > widget.group[best].totalMatches) best = i;
    }
    _primaryIdx = best;
  }

  PlayerModel get _primary => widget.group[_primaryIdx];
  List<PlayerModel> get _others =>
      widget.group.where((p) => p.id != _primary.id).toList();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 680,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18),
                blurRadius: 40, offset: const Offset(0, 16))]),
        child: Column(children: [

          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.merge_outlined, color: Color(0xFFF59E0B), size: 22)),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Merge Duplicate Players",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: Color(0xFF0A1D4A))),
                Text("Select the primary record to keep. Match history will be combined.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ])),
              MouseRegion(cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 20)),
                )),
            ]),
          ),

          // Body
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Step label
              Row(children: [
                Container(width: 24, height: 24,
                    decoration: const BoxDecoration(
                        color: Color(0xFF0A46D8), shape: BoxShape.circle),
                    child: const Center(child: Text("1",
                        style: TextStyle(color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.bold)))),
                const SizedBox(width: 10),
                const Text("Choose the primary record to keep",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: Color(0xFF0A1D4A))),
              ]),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text("The primary record's profile data is preserved. "
                    "All match histories are merged together.",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
              const SizedBox(height: 16),

              // Selectable player cards
              ...List.generate(widget.group.length, (i) {
                final p    = widget.group[i];
                final isSel = _primaryIdx == i;
                return GestureDetector(
                  onTap: () => setState(() => _primaryIdx = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0xFF0A46D8).withOpacity(0.05)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSel ? const Color(0xFF0A46D8) : Colors.grey.shade200,
                        width: isSel ? 2 : 1,
                      ),
                    ),
                    child: Row(children: [
                      // Selection indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel ? const Color(0xFF0A46D8) : Colors.white,
                          border: Border.all(
                              color: isSel ? const Color(0xFF0A46D8) : Colors.grey.shade300,
                              width: 2),
                        ),
                        child: isSel ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14) : null,
                      ),
                      const SizedBox(width: 14),
                      _Avatar(player: p, radius: 24),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(p.fullName, style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold,
                              color: Color(0xFF0A1D4A))),
                          if (isSel) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF0A46D8),
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Text("PRIMARY",
                                  style: TextStyle(fontSize: 9, color: Colors.white,
                                      fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.email_outlined, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(p.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ]),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.phone_outlined, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(p.phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(p.city, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ]),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                              color: p.skillColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(p.skillLevel, style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: p.skillColor)),
                        ),
                        const SizedBox(height: 6),
                        Text("${p.totalMatches} matches",
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        Text("Added ${p.createdAt.length > 10 ? p.createdAt.substring(0,10) : p.createdAt}",
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                      ]),
                    ]),
                  ),
                );
              }),

              const SizedBox(height: 20),

              // What happens info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0F5FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF93C5FD))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF0A46D8)),
                    const SizedBox(width: 8),
                    const Text("What will happen after merge",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                            color: Color(0xFF0A1D4A))),
                  ]),
                  const SizedBox(height: 10),
                  _MergePoint(icon: Icons.check_circle_outline, color: const Color(0xFF16A34A),
                      text: 'Primary record "${_primary.fullName}" is kept with its profile data'),
                  _MergePoint(icon: Icons.merge_outlined, color: const Color(0xFF0A46D8),
                      text: 'All ${widget.group.fold(0, (s, p) => s + p.totalMatches)} match history records are combined under the primary'),
                  _MergePoint(icon: Icons.delete_outline, color: const Color(0xFFEF4444),
                      text: '${_others.length} duplicate record${_others.length > 1 ? "s" : ""} will be permanently removed'),
                ]),
              ),
            ]),
          )),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300)),
                child: Text("Cancel",
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 14),
              Expanded(child: ElevatedButton.icon(
                icon: const Icon(Icons.merge_outlined, size: 18),
                label: Text("Merge ${widget.group.length} Records",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onMerge(_primary, _others);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MergePoint extends StatelessWidget {
  final IconData icon; final Color color; final String text;
  const _MergePoint({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// HISTORY DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class _HistoryDialog extends StatelessWidget {
  final PlayerModel player;
  const _HistoryDialog({required this.player});

  Color _resultColor(String r) {
    switch (r) {
      case 'Winner':     return const Color(0xFF16A34A);
      case 'Runner-up':  return const Color(0xFF0A46D8);
      case 'Semi-Final': return const Color(0xFF7C3AED);
      default:           return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 540, constraints: const BoxConstraints(maxHeight: 580),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              _Avatar(player: player, radius: 26),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(player.fullName, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A1D4A))),
                const SizedBox(height: 3),
                Row(children: [
                  _Mini(label: "${player.totalMatches} Matches",
                      color: const Color(0xFF0A46D8)),
                  const SizedBox(width: 6),
                  _Mini(label: "${player.wins} Wins",
                      color: const Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  _Mini(label: player.skillLevel, color: player.skillColor),
                ]),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500)),
              ),
            ]),
          ),
          // History list
          Expanded(child: player.history.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.history_outlined, size: 40, color: Color(0xFFD1D5DB)),
                  SizedBox(height: 10),
                  Text("No tournament history yet",
                      style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: player.history.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (_, i) {
                    final h = player.history[i];
                    final rc = _resultColor(h.result);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        Container(width: 40, height: 40,
                            decoration: BoxDecoration(color: rc.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(
                              h.result == 'Winner' ? Icons.emoji_events_outlined
                                  : Icons.sports_score_outlined,
                              size: 20, color: rc)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(h.tournamentName, style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${h.sport}  ·  ${h.venue}  ·  ${h.date}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: rc.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(h.result, style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: rc)),
                        ),
                      ]),
                    );
                  },
                )),
        ]),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label; final Color color;
  const _Mini({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// BULK UPLOAD DIALOG — real file-pick flow + download sample
// ══════════════════════════════════════════════════════════════════════════════

class _BulkUploadDialog extends StatefulWidget {
  final void Function(List<PlayerModel>) onImport;
  const _BulkUploadDialog({required this.onImport});
  @override
  State<_BulkUploadDialog> createState() => _BulkUploadDialogState();
}

enum _UploadStep { idle, fileSelected, previewing, error }

class _BulkUploadDialogState extends State<_BulkUploadDialog> {
  _UploadStep _step       = _UploadStep.idle;
  String      _fileName   = '';
  String      _rawContent = '';
  List<PlayerModel> _preview = [];
  List<String>      _errors  = [];

  // Paste mode is an optional fallback (user clicks "paste instead")
  bool _showPasteMode = false;
  final _pasteCtrl    = TextEditingController();

  // Downloads a CSV file containing ONLY the header row (no data).
  // Uses dart:html anchor-click trick — works on Flutter Web.
  // For mobile/desktop: swap with path_provider + dart:io + share_plus.
  void _downloadTemplate() {
    try {
      // Only the header — no data rows
      final csvContent = '${PlayerModel.csvHeader}\n';
      final bytes      = utf8.encode(csvContent);
      final blob       = html.Blob([bytes], 'text/csv');
      final url        = html.Url.createObjectUrlFromBlob(blob);

      // Programmatically click a hidden <a download="..."> element
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'players_template.csv')
        ..click();

      // Clean up the object URL immediately after triggering download
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text(
            'players_template.csv downloaded — fill it in and upload below.',
            style: TextStyle(fontWeight: FontWeight.w500),
          )),
        ]),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Download failed: ${e.toString()}'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _parseContent(String content, String fname) {
    final lines = content.trim().split('\n')
        .map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) {
      setState(() { _step = _UploadStep.error; _errors = ['File is empty']; });
      return;
    }
    // Detect and skip header row
    final startRow = lines[0].toLowerCase().contains('firstname') ? 1 : 0;
    final players  = <PlayerModel>[];
    final errors   = <String>[];
    for (int i = startRow; i < lines.length; i++) {
      final p = PlayerModel.fromCsvRow(lines[i], i);
      if (p == null) {
        errors.add('Row ${i + 1}: skipped — "${lines[i]}" (not enough columns)');
      } else if (p.firstName.isEmpty) {
        errors.add('Row ${i + 1}: skipped — first name is empty');
      } else {
        players.add(p);
      }
    }
    setState(() {
      _fileName  = fname;
      _rawContent= content;
      _preview   = players;
      _errors    = errors;
      _step      = players.isEmpty ? _UploadStep.error : _UploadStep.previewing;
    });
  }

  void _loadFromPaste() {
    final text = _pasteCtrl.text.trim();
    if (text.isEmpty) return;
    _parseContent(text, 'pasted content');
    setState(() => _showPasteMode = false);
  }

  // Opens the native OS file picker, reads the selected .csv file as a string,
  // then passes the content straight into the CSV parser.
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,   // reads bytes immediately (works on web + mobile + desktop)
      );

      if (result == null || result.files.isEmpty) return; // user cancelled

      final file  = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _step   = _UploadStep.error;
          _errors = ['Could not read file — please try again.'];
        });
        return;
      }

      final content = String.fromCharCodes(bytes);
      _parseContent(content, file.name);

    } catch (e) {
      setState(() {
        _step   = _UploadStep.error;
        _errors = ['Error reading file: ${e.toString()}'];
      });
    }
  }

  void _reset() => setState(() {
    _step = _UploadStep.idle; _fileName = '';
    _rawContent = ''; _preview = []; _errors = [];
    _showPasteMode = false; _pasteCtrl.clear();
  });

  @override
  void dispose() { _pasteCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        width: 680,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.16),
                blurRadius: 40, offset: const Offset(0, 14))]),
        child: Column(children: [

          // ── Dialog header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FFF4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.upload_file_outlined,
                    color: Color(0xFF16A34A), size: 22)),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Bulk Upload Players",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: Color(0xFF0A1D4A))),
                Text("Upload a CSV file to import multiple players at once",
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ])),
              MouseRegion(cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 20)),
                )),
            ]),
          ),

          // ── Body ───────────────────────────────────────────────────────────────
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Step 1 — Download sample
              _StepRow(number: "1", title: "Download the sample CSV template"),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Column headers preview
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0A46D8).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF93C5FD))),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(PlayerModel.csvColumns.join('  |  '),
                          style: const TextStyle(fontSize: 11,
                              fontFamily: 'monospace', color: Color(0xFF1E40AF),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Sample row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200)),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(PlayerModel.csvSample1,
                          style: TextStyle(fontSize: 11, fontFamily: 'monospace',
                              color: Colors.grey.shade600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text("Download Sample CSV",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: _downloadTemplate,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0A46D8),
                      backgroundColor: const Color(0xFF0A46D8).withOpacity(0.07),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 22),
              Divider(color: Colors.grey.shade100),
              const SizedBox(height: 18),

              // Step 2 — Upload file
              _StepRow(number: "2", title: "Upload your filled CSV file"),
              const SizedBox(height: 12),

              if (!_showPasteMode && _step == _UploadStep.idle) ...[
                // Drop zone / file picker
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF93C5FD), width: 1.5,
                          style: BorderStyle.solid),
                    ),
                    child: Column(children: [
                      Container(width: 56, height: 56,
                          decoration: BoxDecoration(
                              color: const Color(0xFF0A46D8).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.upload_file_outlined,
                              color: Color(0xFF0A46D8), size: 28)),
                      const SizedBox(height: 14),
                      const Text("Click to browse your computer",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                              color: Color(0xFF0A46D8))),
                      const SizedBox(height: 4),
                      Text("Opens your file explorer — select a .csv file",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      Text(".csv files only",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ]),
                  ),
                ),
              ],

              if (_showPasteMode) ...[
                // Paste area
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 1.5)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                      child: Row(children: [
                        Icon(Icons.content_paste_outlined, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text("Paste CSV content",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600)),
                        const Spacer(),
                        GestureDetector(onTap: () => setState(() => _showPasteMode = false),
                          child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade400)),
                      ]),
                    ),
                    TextField(
                      controller: _pasteCtrl, maxLines: 7,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: '${PlayerModel.csvHeader}\n${PlayerModel.csvSample1}\n...',
                        hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 11),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          border: Border(top: BorderSide(color: Colors.grey.shade200))),
                      child: Row(children: [
                        TextButton(
                          onPressed: () {
                            _pasteCtrl.text =
                                '${PlayerModel.csvHeader}\n${PlayerModel.csvSample1}\n${PlayerModel.csvSample2}';
                          },
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade500,
                              padding: EdgeInsets.zero),
                          child: const Text("Load sample data",
                              style: TextStyle(fontSize: 11)),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _loadFromPaste,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A46D8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                          child: const Text("Preview", style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ],

              // Errors
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded, size: 15, color: Colors.red.shade600),
                      const SizedBox(width: 6),
                      Text("${_errors.length} row${_errors.length > 1 ? 's' : ''} skipped",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                              color: Colors.red.shade700)),
                    ]),
                    const SizedBox(height: 6),
                    ..._errors.take(3).map((e) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(e, style: TextStyle(fontSize: 11, color: Colors.red.shade600)))),
                    if (_errors.length > 3)
                      Text("...and ${_errors.length - 3} more",
                          style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
                  ]),
                ),
              ],

              // Preview table
              if (_step == _UploadStep.previewing && _preview.isNotEmpty) ...[
                const SizedBox(height: 20),
                Divider(color: Colors.grey.shade100),
                const SizedBox(height: 16),
                _StepRow(number: "3", title: "Review & confirm import"),
                const SizedBox(height: 12),
                // Summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF4), borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC))),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                    const SizedBox(width: 10),
                    Text("${_preview.length} players ready to import",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: Color(0xFF166534))),
                    if (_errors.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text("(${_errors.length} rows skipped)",
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
                    ],
                    const Spacer(),
                    TextButton(
                      onPressed: _reset,
                      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade500),
                      child: const Text("Clear", style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                // Preview rows (first 5)
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Column(children: [
                    // Table header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text("NAME", style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.grey.shade400, letterSpacing: 0.6))),
                        Expanded(flex: 2, child: Text("EMAIL", style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.grey.shade400, letterSpacing: 0.6))),
                        Expanded(flex: 2, child: Text("SKILL / GENDER", style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.grey.shade400, letterSpacing: 0.6))),
                        Expanded(flex: 2, child: Text("CITY", style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.grey.shade400, letterSpacing: 0.6))),
                      ]),
                    ),
                    ..._preview.take(5).map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(
                              color: Colors.grey.shade100))),
                      child: Row(children: [
                        Expanded(flex: 3, child: Row(children: [
                          _Avatar(player: p, radius: 14),
                          const SizedBox(width: 8),
                          Flexible(child: Text(p.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        ])),
                        Expanded(flex: 2, child: Text(p.email, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
                        Expanded(flex: 2, child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: p.skillColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(p.skillLevel, style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700, color: p.skillColor)),
                          ),
                          const SizedBox(width: 6),
                          Text(p.gender, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ])),
                        Expanded(flex: 2, child: Text(p.city, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
                      ]),
                    )),
                    if (_preview.length > 5)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text("...and ${_preview.length - 5} more players",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      ),
                  ]),
                ),
              ],

            ]),
          )),

          // ── Footer ─────────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300)),
                child: Text("Cancel",
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 14),
              Expanded(child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: Text(
                  _step == _UploadStep.previewing
                      ? "Import ${_preview.length} Players"
                      : "Import",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onPressed: _step == _UploadStep.previewing && _preview.isNotEmpty
                    ? () {
                        widget.onImport(_preview);
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                    disabledBackgroundColor: Colors.grey.shade200,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number, title;
  const _StepRow({required this.number, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 26, height: 26,
        decoration: const BoxDecoration(color: Color(0xFF0A46D8), shape: BoxShape.circle),
        child: Center(child: Text(number, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)))),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
        color: Color(0xFF0A1D4A))),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED MICRO WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  final PlayerModel player;
  final double radius;
  const _Avatar({required this.player, required this.radius});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: player.avatarColor.withOpacity(0.15),
    child: Text(player.initials, style: TextStyle(
        fontSize: radius * 0.6, fontWeight: FontWeight.bold,
        color: player.avatarColor)),
  );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
              color: color, height: 1)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(
              fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
        ]),
      ]),
    ),
  );
}

class _DuplicateBanner extends StatelessWidget {
  final int count;
  final VoidCallback onReview;
  const _DuplicateBanner({required this.count, required this.onReview});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4))),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
      const SizedBox(width: 12),
      Expanded(child: RichText(text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
        children: [
          TextSpan(text: "$count duplicate group${count > 1 ? 's' : ''} found. ",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: "Review and merge them to keep your player data clean."),
        ],
      ))),
      const SizedBox(width: 16),
      TextButton.icon(
        icon: const Icon(Icons.merge_outlined, size: 14),
        label: const Text("Review Duplicates",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        onPressed: onReview,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFF59E0B),
          backgroundColor: const Color(0xFFF59E0B).withOpacity(0.12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ]),
  );
}

class _SearchBox extends StatelessWidget {
  final void Function(String) onChanged;
  const _SearchBox({required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    decoration: BoxDecoration(
        color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200)),
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: "Search by name, email, phone or city...",
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 18),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
      ),
    ),
  );
}

class _DropFilter extends StatelessWidget {
  final String value, label;
  final List<String> items;
  final void Function(String) onChanged;
  const _DropFilter({required this.value, required this.label,
      required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    height: 44, padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
        color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey.shade500),
        style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w500),
        items: items.map((i) => DropdownMenuItem(
            value: i,
            child: Text(i == 'All' ? '$label: All' : i))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  );
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.icon,
      required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: active ? const Color(0xFF6B7280).withOpacity(0.10) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? const Color(0xFF6B7280) : Colors.grey.shade200)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14,
            color: active ? const Color(0xFF374151) : Colors.grey.shade400),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? const Color(0xFF374151) : Colors.grey.shade400)),
      ]),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final String msg;
  final IconData icon;
  const _EmptyState({required this.msg, this.icon = Icons.people_outline});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 64, height: 64,
          decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
          child: Icon(icon, size: 30, color: const Color(0xFFD1D5DB))),
      const SizedBox(height: 14),
      Text(msg, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280))),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final Color color;
  final String tooltip; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color,
      required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(7),
        hoverColor: color.withOpacity(0.18),
        splashColor: Colors.transparent, highlightColor: Colors.transparent,
        child: Padding(padding: const EdgeInsets.all(6),
            child: Icon(icon, color: color, size: 15)),
      ),
    ),
  );
}