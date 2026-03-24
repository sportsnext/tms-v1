// lib/features/admin/tournaments/presentation/screens/tournament_list_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/tournaments/data/models/tournament_model.dart';
import 'create_tournament_screen.dart';
import 'tournament_view_screen.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});
  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  List<TournamentModel> _tournaments = List.from(TournamentSeeds.all);
  String _search  = '';
  String _filter  = 'All';   // All | draft | published | completed

  List<TournamentModel> get _filtered => _tournaments.where((t) {
    final q = _search.toLowerCase();
    final matchQ = q.isEmpty ||
        t.name.toLowerCase().contains(q) ||
        t.sportName.toLowerCase().contains(q) ||
        t.effectiveVenue.toLowerCase().contains(q);
    final matchF = _filter == 'All' || t.status == _filter;
    return matchQ && matchF;
  }).toList();

  void _openCreate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateTournamentScreen(
        existing: _tournaments,
        onSave: (t) => setState(() {
          final i = _tournaments.indexWhere((x) => x.id == t.id);
          if (i != -1) _tournaments[i] = t; else _tournaments.add(t);
        }),
      ),
    );
  }

  void _openEdit(TournamentModel t) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateTournamentScreen(
        existing: _tournaments,
        editTournament: t,
        onSave: (updated) => setState(() {
          final i = _tournaments.indexWhere((x) => x.id == updated.id);
          if (i != -1) _tournaments[i] = updated;
        }),
      ),
    );
  }

  void _openView(TournamentModel t) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => TournamentViewScreen(
        tournament: t,
        onUpdate: (updated) => setState(() {
          final i = _tournaments.indexWhere((x) => x.id == updated.id);
          if (i != -1) _tournaments[i] = updated;
        }),
        onBack: () => Navigator.of(context, rootNavigator: true).pop(),
      )),
    );
  }

  void _confirmDelete(TournamentModel t) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 380, padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 60, height: 60,
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 30)),
          const SizedBox(height: 16),
          const Text('Delete Tournament', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Are you sure you want to delete "${t.name}"? This cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: Colors.grey.shade300)),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () {
                setState(() => _tournaments.removeWhere((x) => x.id == t.id));
                Navigator.pop(context);
                _snack('"${t.name}" deleted');
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
      ),
    ));
  }

  void _togglePublish(TournamentModel t) {
    final newStatus = t.status == 'published' ? 'draft' : 'published';
    setState(() {
      final i = _tournaments.indexWhere((x) => x.id == t.id);
      if (i != -1) _tournaments[i] = t.copyWith(status: newStatus);
    });
    _snack(newStatus == 'published' ? '"${t.name}" published!' : '"${t.name}" moved to draft');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
    backgroundColor: const Color(0xFF4F46E5),
    behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 3),
  ));

  @override
  Widget build(BuildContext context) {
    final total     = _tournaments.length;
    final published = _tournaments.where((t) => t.isPublished).length;
    final draft     = _tournaments.where((t) => t.isDraft).length;
    final live      = _tournaments.where((t) => t.hasLive).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Title + Create button
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tournament Management',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
            const SizedBox(height: 3),
            Text('Create, manage and track all tournaments',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ]),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _openCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Tournament', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15), elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),

        const SizedBox(height: 22),

        // Stat cards
        Row(children: [
          _StatCard(label: 'Total', value: '$total',     icon: Icons.emoji_events_outlined,  color: const Color(0xFF4F46E5)),
          const SizedBox(width: 14),
          _StatCard(label: 'Published', value: '$published', icon: Icons.public_rounded,         color: const Color(0xFF16A34A)),
          const SizedBox(width: 14),
          _StatCard(label: 'Draft', value: '$draft',    icon: Icons.edit_note_outlined,       color: const Color(0xFF6B7280)),
          const SizedBox(width: 14),
          _StatCard(label: 'Live Now', value: '$live',  icon: Icons.circle,                   color: const Color(0xFFDC2626)),
        ]),

        const SizedBox(height: 22),

        // Search + filter
        Row(children: [
          Expanded(child: Container(
            height: 48,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name, sport or venue...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          )),
          const SizedBox(width: 12),
          ...['All', 'published', 'draft', 'completed'].map((f) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _FilterChip(
              label: f == 'All' ? 'All' : f[0].toUpperCase() + f.substring(1),
              selected: _filter == f,
              color: f == 'published' ? const Color(0xFF16A34A)
                  : f == 'draft' ? const Color(0xFF6B7280)
                  : f == 'completed' ? const Color(0xFF7C3AED)
                  : const Color(0xFF4F46E5),
              onTap: () => setState(() => _filter = f),
            ),
          )),
        ]),

        const SizedBox(height: 22),

        // Cards grid
        _filtered.isEmpty
            ? _EmptyState(onCreateTap: _openCreate)
            : Wrap(
                spacing: 18, runSpacing: 18,
                children: _filtered.map((t) => _TournamentCard(
                  tournament: t,
                  onView:    () => _openView(t),
                  onEdit:    () => _openEdit(t),
                  onDelete:  () => _confirmDelete(t),
                  onTogglePublish: () => _togglePublish(t),
                )).toList(),
              ),
      ]),
    );
  }
}

// ── Tournament Card ────────────────────────────────────────────
class _TournamentCard extends StatefulWidget {
  final TournamentModel tournament;
  final VoidCallback onView, onEdit, onDelete, onTogglePublish;
  const _TournamentCard({required this.tournament, required this.onView,
      required this.onEdit, required this.onDelete, required this.onTogglePublish});
  @override
  State<_TournamentCard> createState() => _TournamentCardState();
}

class _TournamentCardState extends State<_TournamentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _hovered ? const Color(0xFF4F46E5).withOpacity(0.4) : Colors.grey.shade200,
              width: _hovered ? 1.5 : 1),
          boxShadow: [BoxShadow(
              color: _hovered ? const Color(0xFF4F46E5).withOpacity(0.10) : Colors.black.withOpacity(0.05),
              blurRadius: _hovered ? 20 : 8, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Banner top
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: t.hasBanner
                ? Image.memory(base64Decode(t.banner), height: 110, width: double.infinity, fit: BoxFit.cover)
                : Container(
                    height: 110,
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF1E2235), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight)),
                    child: Stack(children: [
                      Center(child: Icon(Icons.emoji_events_rounded,
                          size: 42, color: Colors.white.withOpacity(0.3))),
                      Positioned(top: 10, left: 12, child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.7),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(t.sportName, style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        if (t.hasLive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(6)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 5, height: 5,
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              const Text('LIVE', style: TextStyle(color: Colors.white,
                                  fontSize: 9, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                      ])),
                    ]),
                  ),
          ),

          Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Status badge row
            Row(children: [
              _StatusBadge(status: t.status),
              const Spacer(),
              Text('${t.eventGroups.length} event${t.eventGroups.length != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 8),

            // Name
            Text(t.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                color: Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),

            // Date
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 5),
              Text('${_fmtDate(t.startDate)} → ${_fmtDate(t.endDate)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 4),

            // Venue
            Row(children: [
              Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 5),
              Expanded(child: Text(t.effectiveVenue,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
            ]),
            const SizedBox(height: 10),

            // Stats row
            Row(children: [
              _MiniStat(Icons.sports_rounded, '${t.totalMatches}', 'Matches'),
              const SizedBox(width: 12),
              _MiniStat(Icons.people_alt_outlined, '${t.totalParticipants}', 'Players'),
              const SizedBox(width: 12),
              _MiniStat(Icons.business_outlined, '${t.sponsors.length}', 'Sponsors'),
            ]),

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 10),

            // Action buttons
            Row(children: [
              // View
              Expanded(child: _CardBtn(
                label: 'View', icon: Icons.visibility_outlined,
                color: const Color(0xFF4F46E5), onTap: widget.onView,
              )),
              const SizedBox(width: 6),
              // Edit
              _IconAction(Icons.edit_outlined, const Color(0xFFF59E0B), 'Edit', widget.onEdit),
              const SizedBox(width: 6),
              // Publish/Unpublish toggle
              _IconAction(
                t.isPublished ? Icons.unpublished_outlined : Icons.publish_rounded,
                t.isPublished ? Colors.orange.shade600 : const Color(0xFF16A34A),
                t.isPublished ? 'Move to Draft' : 'Publish',
                widget.onTogglePublish,
              ),
              const SizedBox(width: 6),
              // Delete
              _IconAction(Icons.delete_outline_rounded, Colors.red.shade400, 'Delete', widget.onDelete),
            ]),
          ])),
        ]),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 70),
    child: Column(children: [
      Container(width: 72, height: 72,
          decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
          child: const Icon(Icons.emoji_events_outlined, size: 34, color: Color(0xFFD1D5DB))),
      const SizedBox(height: 16),
      const Text('No tournaments found', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
      const SizedBox(height: 6),
      const Text('Create your first tournament to get started',
          style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onCreateTap,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Create Tournament'),
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ]),
  );
}

// ── Shared micro widgets ───────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0,2))]),
    child: Row(children: [
      Container(width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color, height: 1)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
      ]),
    ]),
  ));
}

class _FilterChip extends StatelessWidget {
  final String label; final bool selected; final Color color; final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
          color: selected ? color : Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.grey.shade600)),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = status == 'published' ? const Color(0xFF16A34A)
        : status == 'completed' ? const Color(0xFF7C3AED)
        : const Color(0xFF6B7280);
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon; final String value, label;
  const _MiniStat(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: Colors.grey.shade400),
    const SizedBox(width: 3),
    Text('$value ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
    Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
  ]);
}

class _CardBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _CardBtn({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(8), hoverColor: color.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    ),
  );
}

class _IconAction extends StatelessWidget {
  final IconData icon; final Color color; final String tooltip; final VoidCallback onTap;
  const _IconAction(this.icon, this.color, this.tooltip, this.onTap);
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(8), hoverColor: color.withOpacity(0.18),
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: color, size: 16)),
      ),
    ),
  );
}
// ───────────────────────────────────────────────────────────────for the date format in the card ----------------------------------
String _fmtDate(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}-${p[1]}-${p[0]}';
  } catch (_) { return iso; }
}