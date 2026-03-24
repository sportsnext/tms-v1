// lib/features/admin/tournaments/presentation/screens/tournament_view_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tms_flutter/features/admin/tournaments/data/models/tournament_model.dart';


class _PadelScoringEngine {
  // ── Set-level: determine set winner ──────────────────────────
  // setIndex 0/1 = normal set, setIndex 2 = super tiebreak
  // Returns 'A', 'B', or null (ongoing)
  static String? setWinner(int gA, int gB, int setIndex) {
    if (setIndex >= 2) {
      // Super Tiebreak: first to 10, win by 2
      if (gA >= 10 && gA - gB >= 2) return 'A';
      if (gB >= 10 && gB - gA >= 2) return 'B';
      return null;
    }
    // Normal set: first to 6, win by 2
    if (gA >= 6 && gB <= 4 && gA - gB >= 2) return 'A';
    if (gB >= 6 && gA <= 4 && gB - gA >= 2) return 'B';
    // Tiebreak at 6-6 (7-6 wins)
    if (gA == 7 && gB == 6) return 'A';
    if (gB == 7 && gA == 6) return 'B';
    return null;
  }

  // Validate a set score — returns error string or null
  static String? validateSet(int gA, int gB, int setIndex) {
    if (gA < 0 || gB < 0) return 'Negative score not allowed';
    if (setIndex >= 2) {
      // Super tiebreak: just needs to reach 10+ win by 2
      if (gA > 30 || gB > 30) return 'Super tiebreak score too high';
      return null;
    }
    // Normal set max = 7 (7-6 tiebreak)
    if (gA > 7 || gB > 7) return 'Max 7 games in a set';
    if (gA == 7 && gB != 6) return '7 games only valid at 7-6 (tiebreak)';
    if (gB == 7 && gA != 6) return '7 games only valid at 7-6 (tiebreak)';
    return null;
  }

  // Match winner from set scores
  static String? matchWinner(List<int> gA, List<int> gB, String idA, String idB) {
    int sA = 0, sB = 0;
    for (int i = 0; i < gA.length; i++) {
      final w = setWinner(gA[i], gB[i], i);
      if (w == 'A') sA++;
      if (w == 'B') sB++;
    }
    if (sA >= 2) return idA;
    if (sB >= 2) return idB;
    return null;
  }

  // Set score display label
  static String setLabel(int setIndex, bool isThirdSet) {
    if (isThirdSet || setIndex >= 2) return 'Super TB';
    return 'Set ${setIndex + 1}';
  }
 
}

// ══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════
class TournamentViewScreen extends StatefulWidget {
  final TournamentModel tournament;
  final VoidCallback? onBack;
  final void Function(TournamentModel) onUpdate;

  const TournamentViewScreen({
    super.key,
    required this.tournament,
    this.onBack,
    required this.onUpdate,
  });

  @override
  State<TournamentViewScreen> createState() => _TournamentViewScreenState();
}

class _TournamentViewScreenState extends State<TournamentViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late TournamentModel _t;
  bool _refreshing = false;
  static const _indigo = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _t = widget.tournament;
    _tabCtrl = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  // ── Update fixture and propagate knockout winner ─────────────
  void _updateFixture(FixtureModel updated) {
    setState(() {
      _t = _t.copyWith(eventGroups: _t.eventGroups.map((g) {
        if (!g.fixtures.any((f) => f.id == updated.id)) return g;
    
        final newFixtures = g.fixtures.map((f) => f.id == updated.id ? updated : f).toList();
        // If knockout and winner set → propagate to next round
        if (g.format == 'knockout' && updated.winnerId.isNotEmpty) {
          _propagateKnockoutWinner(newFixtures, updated);
        }
        return g.copyWith(fixtures: newFixtures);
      }).toList());
    });
    widget.onUpdate(_t);
  }


  void _propagateKnockoutWinner(List<FixtureModel> fixtures, FixtureModel completed) {
    final winnerName = completed.winnerId == completed.teamAId
        ? completed.teamAName : completed.teamBName;
    final winnerId    = completed.winnerId;
    final nextRound   = completed.roundIndex + 1;
    final nextMatch   = completed.matchIndex ~/ 2;
    final isSlotA     = completed.matchIndex % 2 == 0;

    for (int i = 0; i < fixtures.length; i++) {
      final f = fixtures[i];
      if (f.roundIndex == nextRound && f.matchIndex == nextMatch) {
        fixtures[i] = isSlotA
            ? f.copyWith(teamAId: winnerId, teamAName: winnerName)
            : f.copyWith(teamBId: winnerId, teamBName: winnerName);
        return;
      }
    }
  }

  Future<void> _simulateRefresh() async {
    setState(() => _refreshing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _refreshing = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refreshed'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(child: TabBarView(
          controller: _tabCtrl,
          children: [
            _OverviewTab(tournament: _t),
            _ParticipantsTab(tournament: _t),
            _FixtureTab(tournament: _t, onUpdateFixture: _updateFixture),
            _ScheduleTab(tournament: _t, onUpdateFixture: _updateFixture),
            _CalendarTab(tournament: _t),
            _LiveTab(tournament: _t, onUpdateFixture: _updateFixture),
            _StandingsTab(tournament: _t),
          ],
        )),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF4F46E5)],
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            if (widget.onBack != null) { widget.onBack!(); }
            else { Navigator.of(context).pop(); }
          },
          child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          Row(children: [
            _HeaderPill(_t.statusLabel, _t.statusColor),
            if (_t.hasLive) ...[const SizedBox(width: 6), const _HeaderPill('LIVE', Color(0xFF16A34A))],
            const SizedBox(width: 8),
            Flexible(child: Text(_t.effectiveVenue, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11), overflow: TextOverflow.ellipsis)),
          ]),
        ])),
        GestureDetector(
          onTap: _simulateRefresh,
          child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
              child: _refreshing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20)),
        ),
      ]),
    )),
  );

  Widget _buildTabBar() => Container(
    color: const Color(0xFF1E1B4B),
    child: TabBar(
      controller: _tabCtrl, isScrollable: true,
      indicatorColor: Colors.white, indicatorWeight: 3,
      labelColor: Colors.white, unselectedLabelColor: Colors.white.withOpacity(0.45),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      tabs: const [
        Tab(text: 'OVERVIEW'), Tab(text: 'PARTICIPANTS'), Tab(text: 'FIXTURE'),
        Tab(text: 'SCHEDULE'), Tab(text: 'CALENDAR'), Tab(text: 'LIVE'), Tab(text: 'STANDINGS'),
      ],
    ),
  );
}

class _HeaderPill extends StatelessWidget {
  final String label; final Color color;
  const _HeaderPill(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.25), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
    child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
  );
}
// ══════════════════════════════════════════════════════════════
// SHARED: CATEGORY DROPDOWN SELECTOR
// ══════════════════════════════════════════════════════════════
class _CategorySelector extends StatelessWidget {
  final List<EventGroup> groups;
  final int selectedIdx;
  final void Function(int) onChanged;
  final List<Widget> trailing;
  const _CategorySelector({required this.groups, required this.selectedIdx, required this.onChanged, this.trailing = const []});
  static const _indigo = Color(0xFF4F46E5);
  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final idx = selectedIdx.clamp(0, groups.length - 1);
    final sel = groups[idx];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: [
        const Text('Category:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(width: 10),
        Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: _indigo.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: _indigo.withOpacity(0.25))),
          child: DropdownButtonHideUnderline(child: DropdownButton<int>(
            value: idx,
            icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: _indigo),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _indigo),
            items: groups.asMap().entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.displayName))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ))),
        const SizedBox(width: 10),
        _FormatBadge(label: sel.formatLabel, color: sel.formatColor),
        if (sel.gender.isNotEmpty) ...[const SizedBox(width: 6), _FormatBadge(label: sel.gender, color: const Color(0xFF0891B2))],
        const Spacer(),
        ...trailing,
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// OVERVIEW TAB
// ══════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final TournamentModel tournament;
  const _OverviewTab({required this.tournament});
  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: t.hasBanner
              ? Image.memory(base64Decode(t.banner), height: 200, width: double.infinity,
                  fit: BoxFit.cover, filterQuality: FilterQuality.high, gaplessPlayback: true)
              : Container(
                  height: 200, width: double.infinity,
                  decoration: const BoxDecoration(gradient: LinearGradient(
                      colors: [Color(0xFF1E2235), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.emoji_events_rounded, size: 52, color: Colors.white.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text(t.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('No banner — recommended 1960×320px WEBP/JPG', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                  ])),
        ),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tournament Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              Divider(color: Colors.grey.shade200, height: 20),
              Text(t.description.isEmpty ? 'No description.' : t.description,
                  style: TextStyle(fontSize: 14, color: t.description.isEmpty ? Colors.grey.shade400 : Colors.grey.shade700)),
              const SizedBox(height: 16),
              Wrap(spacing: 24, runSpacing: 12, children: [
                _InfoPill(Icons.calendar_today_outlined, '${_fmtDate(t.startDate)}  →  ${_fmtDate(t.endDate)}'),
                _InfoPill(Icons.location_on_outlined, t.effectiveVenue),
                _InfoPill(Icons.people_alt_outlined, '${t.totalParticipants} Participants'),
                _InfoPill(Icons.sports_rounded, '${t.totalMatches} Matches'),
                _InfoPill(Icons.category_outlined, '${t.eventGroups.length} Categories'),
                if (t.hasLive) _InfoPill(Icons.circle, '${t.liveMatches} Live Now', color: const Color(0xFF16A34A)),
              ]),
              if (t.contactName.isNotEmpty || t.contactEmail.isNotEmpty || t.contactPhone.isNotEmpty) ...[
                Divider(color: Colors.grey.shade200, height: 20),
                const Text('Contact', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                const SizedBox(height: 8),
                if (t.contactName.isNotEmpty) _InfoPill(Icons.person_outline, t.contactName),
                const SizedBox(height: 4),
                if (t.contactEmail.isNotEmpty) _InfoPill(Icons.email_outlined, t.contactEmail),
                if (t.contactPhone.isNotEmpty) ...[const SizedBox(height: 4), _InfoPill(Icons.phone_outlined, t.contactPhone)],
              ],
            ]),
          )),
          const SizedBox(width: 20),
          Container(
            width: 220, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2))),
            child: Column(children: [
              _StatRow('Total Matches', '${t.totalMatches}'),
              _StatRow('Completed', '${t.completedMatches}'),
              _StatRow('Participants', '${t.totalParticipants}'),
              _StatRow('Categories', '${t.eventGroups.length}'),
              _StatRow('Sponsors', '${t.sponsors.length}'),
              _StatRow('Status', t.statusLabel, color: t.statusColor),
            ]),
          ),
        ]),
        if (t.sponsors.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Sponsors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 10, children: t.sponsors.map((s) => _SponsorTile(sponsor: s)).toList()),
        ],
      ]),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon; final String label; final Color? color;
  const _InfoPill(this.icon, this.label, {this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: color ?? Colors.grey.shade500),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 13, color: color ?? const Color(0xFF374151))),
  ]);
}

class _StatRow extends StatelessWidget {
  final String label, value; final Color? color;
  const _StatRow(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF4F46E5))),
    ]),
  );
}

class _SponsorTile extends StatelessWidget {
  final SponsorModel sponsor;
  const _SponsorTile({required this.sponsor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (sponsor.logoBase64.isNotEmpty)
        Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 8),
            child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(base64Decode(sponsor.logoBase64), fit: BoxFit.contain)))
      else
        Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.business_rounded, size: 16, color: Color(0xFF4F46E5))),
      Text(sponsor.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
// PARTICIPANTS TAB — category dropdown
// ══════════════════════════════════════════════════════════════
class _ParticipantsTab extends StatefulWidget {
  final TournamentModel tournament;
  const _ParticipantsTab({required this.tournament});
  @override
  State<_ParticipantsTab> createState() => _ParticipantsTabState();
}
class _ParticipantsTabState extends State<_ParticipantsTab> {
  int _selIdx = 0;
  static const _indigo = Color(0xFF4F46E5);
  @override
  Widget build(BuildContext context) {
    final groups = widget.tournament.eventGroups;
    if (groups.isEmpty) return _empty('No participants added.');
    if (_selIdx >= groups.length) _selIdx = 0;
    final g = groups[_selIdx];
    return Column(children: [
      _CategorySelector(groups: groups, selectedIdx: _selIdx, onChanged: (i) => setState(() => _selIdx = i),
          trailing: [_FormatBadge(label: '${g.participants.length} registered', color: Colors.grey.shade500)]),
      Expanded(child: g.participants.isEmpty
          ? _empty('No participants for ${g.displayName}.')
          : SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: _indigo.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: _indigo.withOpacity(0.15))),
                  child: const Row(children: [
                    SizedBox(width: 36, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                    Expanded(flex: 3, child: Text('Team / Player', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                    Expanded(flex: 4, child: Text('Players', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                    SizedBox(width: 60, child: Text('Seed', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  ])),
              const SizedBox(height: 4),
              ...g.participants.asMap().entries.map((e) {
                final p = e.value; final i = e.key;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(children: [
                    SizedBox(width: 36, child: Container(width: 24, height: 24,
                        decoration: BoxDecoration(color: _indigo.withOpacity(0.10), shape: BoxShape.circle),
                        child: Center(child: Text('${i+1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _indigo))))),
                    Expanded(flex: 3, child: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)))),
                    Expanded(flex: 4, child: Text(p.playerNames.isEmpty ? '—' : p.playerNames.join(' / '), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                    SizedBox(width: 60, child: p.seed.isNotEmpty
                        ? Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text('S${p.seed}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber.shade800))))
                        : const SizedBox()),
                  ]),
                );
              }),
            ]))),
    ]);
  }
}
// ══════════════════════════════════════════════════════════════
// FIXTURE TAB — knockout bracket with winner propagation
// Only winner names appear in next-round slots (TBD until decided)
// ══════════════════════════════════════════════════════════════
class _FixtureTab extends StatefulWidget {
  final TournamentModel tournament;
  final void Function(FixtureModel) onUpdateFixture;
  const _FixtureTab({required this.tournament, required this.onUpdateFixture});
  @override
  State<_FixtureTab> createState() => _FixtureTabState();
}
class _FixtureTabState extends State<_FixtureTab> {
  int _selIdx = 0;
  @override
  Widget build(BuildContext context) {
    final groups = widget.tournament.eventGroups;
    if (groups.isEmpty) return _empty('No fixtures generated yet.');
    if (_selIdx >= groups.length) _selIdx = 0;
    final g = groups[_selIdx];
    return Column(children: [
      _CategorySelector(groups: groups, selectedIdx: _selIdx, onChanged: (i) => setState(() => _selIdx = i)),
      Expanded(child: g.fixtures.isEmpty
          ? _empty('No fixtures for ${g.displayName}. Generate from Create screen.')
          : g.format == 'knockout'
              ? _KnockoutBracket(group: g, onUpdateFixture: widget.onUpdateFixture)
              : SingleChildScrollView(padding: const EdgeInsets.all(24),
                  child: _RoundRobinTable(group: g, onUpdateFixture: widget.onUpdateFixture))),
    ]);
  }
}

// ── Knockout Bracket ─────────────────────────────────────────
class _KnockoutBracket extends StatelessWidget {
  final EventGroup group;
  final void Function(FixtureModel) onUpdateFixture;
  const _KnockoutBracket({required this.group, required this.onUpdateFixture});

  @override
  Widget build(BuildContext context) {
    final byRound    = group.fixturesByRound;
    final rounds     = group.orderedRounds;
    const cardW      = 220.0;
    const cardH      = 96.0;
    const cardGap    = 20.0;
    const connW      = 52.0;
    final slotH      = cardH + cardGap;
    final firstRound = rounds.isNotEmpty ? (byRound[rounds.first] ?? []) : <FixtureModel>[];
    final totalH     = (firstRound.length * slotH).clamp(slotH, 9999.0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
   
      Padding(padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
          child: Row(children: [
            const Icon(Icons.account_tree_rounded, size: 15, color: Color(0xFF4F46E5)),
            const SizedBox(width: 6),
            Text('${group.participants.length} participants  ·  Single Elimination',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(width: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF16A34A)),
                  SizedBox(width: 4),
                  Text('Winner advances automatically', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                ])),
          ])),
  
      Expanded(child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rounds.asMap().entries.map((colEntry) {
              final roundName     = colEntry.value;
              final matches       = byRound[roundName] ?? [];
              final isLastColumn  = colEntry.key == rounds.length - 1;
              final slotsPerMatch = firstRound.isEmpty ? 1
                  : (firstRound.length ~/ matches.length.clamp(1, 9999));

              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: cardW,
                  height: totalH + 36,
                  child: Column(children: [
                  
                    Container(width: cardW,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(roundName, textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)))),
                    
                    Expanded(child: Stack(
                      children: matches.asMap().entries.map((me) {
                        final slotBandH = slotsPerMatch * slotH;
                        final topOffset = me.key * slotBandH + (slotBandH - cardH) / 2;
                        return Positioned(
                          top: topOffset, left: 0, right: 0,
                          child: _BracketCard(
                            fixture: me.value,
                            width: cardW, height: cardH,
                            participants: group.participants,
                            onEdit: () => showDialog(context: context,
                                builder: (_) => _FixtureEditDialog(
                                    fixture: me.value,
                                    onSave: onUpdateFixture,
                                    participants: group.participants)),
                          ),
                        );
                      }).toList(),
                    )),
                  ]),
                ),
                if (!isLastColumn)
                  SizedBox(width: connW, height: totalH + 36,
                      child: CustomPaint(painter: _ConnectorPainter(
                          matchCount: matches.length,
                          slotsPerMatch: slotsPerMatch,
                          slotH: slotH, cardH: cardH))),
              ]);
            }).toList(),
          ),
        ),
      )),
    ]);
  }
}

class _ConnectorPainter extends CustomPainter {
  final int matchCount, slotsPerMatch;
  final double slotH, cardH;
  const _ConnectorPainter({required this.matchCount, required this.slotsPerMatch, required this.slotH, required this.cardH});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFD1D5DB)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (int i = 0; i < matchCount; i++) {
      final topPad    = (slotsPerMatch - 1) * slotH / 2;
      final centerY   = (i == 0 ? topPad : i * slotsPerMatch * slotH + topPad) + cardH / 2;
      final path      = Path();
      path.moveTo(0, centerY);
      path.lineTo(size.width / 2, centerY);
      if (i % 2 == 0 && i + 1 < matchCount) {
        final partnerY = (i + 1) * slotsPerMatch * slotH + topPad + cardH / 2;
        path.moveTo(size.width / 2, centerY);
        path.lineTo(size.width / 2, partnerY);
        path.moveTo(size.width / 2, (centerY + partnerY) / 2);
        path.lineTo(size.width, (centerY + partnerY) / 2);
      }
      canvas.drawPath(path, paint);
    }
  }
  @override bool shouldRepaint(_ConnectorPainter o) => false;
}

// ── Bracket Card ─────────────────────────────────────────────
class _BracketCard extends StatelessWidget {
  final FixtureModel fixture;
  final double width, height;
  final List<ParticipantModel> participants;
  final VoidCallback onEdit;
  const _BracketCard({required this.fixture, required this.width, required this.height, required this.participants, required this.onEdit});

  String _playerNames(String teamId) {
    final p = _firstOrNull(participants.where((p) => p.id == teamId));
    return p?.playerNames.join(' / ') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final f     = fixture;
    final aWins = f.winnerId == f.teamAId && f.winnerId.isNotEmpty;
    final bWins = f.winnerId == f.teamBId && f.winnerId.isNotEmpty;
    final aTBD  = f.teamAName.isEmpty || f.teamAName == 'TBD';
    final bTBD  = f.teamBName.isEmpty || f.teamBName == 'TBD';

    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: f.isLive ? const Color(0xFF16A34A)
              : (aWins || bWins) ? const Color(0xFF4F46E5).withOpacity(0.4)
              : Colors.grey.shade300,
          width: f.isLive ? 2 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
      ),
      child: Stack(children: [
        Column(children: [
          // ── Side A ─────────────────────────────────────────
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
                color: aWins ? const Color(0xFF4F46E5).withOpacity(0.06) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9))),
            child: Row(children: [
              if (aWins) const Icon(Icons.emoji_events_rounded, size: 12, color: Color(0xFFF59E0B))
              else const SizedBox(width: 12),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(aTBD ? 'TBD' : f.teamAName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11,
                        fontWeight: aWins ? FontWeight.bold : FontWeight.normal,
                        color: aTBD ? Colors.grey.shade400
                            : aWins ? const Color(0xFF4F46E5)
                            : const Color(0xFF374151))),
                if (!aTBD && _playerNames(f.teamAId).isNotEmpty)
                  Text(_playerNames(f.teamAId), style: TextStyle(fontSize: 9, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
              ])),
              if (f.isCompleted && !aTBD)
                Text('${f.setsWonA}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: aWins ? const Color(0xFF4F46E5) : Colors.grey.shade400)),
            ]),
          )),
          Divider(height: 1, color: Colors.grey.shade200),
          // ── Side B ─────────────────────────────────────────
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
                color: bWins ? const Color(0xFF4F46E5).withOpacity(0.06) : Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9))),
            child: Row(children: [
              if (bWins) const Icon(Icons.emoji_events_rounded, size: 12, color: Color(0xFFF59E0B))
              else const SizedBox(width: 12),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(bTBD ? 'TBD' : f.teamBName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11,
                        fontWeight: bWins ? FontWeight.bold : FontWeight.normal,
                        color: bTBD ? Colors.grey.shade400
                            : bWins ? const Color(0xFF4F46E5)
                            : const Color(0xFF374151))),
                if (!bTBD && _playerNames(f.teamBId).isNotEmpty)
                  Text(_playerNames(f.teamBId), style: TextStyle(fontSize: 9, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
              ])),
              if (f.isCompleted && !bTBD)
                Text('${f.setsWonB}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: bWins ? const Color(0xFF4F46E5) : Colors.grey.shade400)),
            ]),
          )),
        ]),
        // Edit button
        Positioned(top: 3, right: 3, child: GestureDetector(onTap: onEdit,
            child: Container(padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.08), borderRadius: BorderRadius.circular(5)),
                child: const Icon(Icons.edit_rounded, size: 11, color: Color(0xFF4F46E5))))),
        // Live badge
        if (f.isLive) Positioned(bottom: 3, left: 8, child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
          const SizedBox(width: 3),
          const Text('LIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
        ])),
      ]),
    );
  }
}

// ── Round Robin Table ─────────────────────────────────────────
class _RoundRobinTable extends StatelessWidget {
  final EventGroup group;
  final void Function(FixtureModel) onUpdateFixture;
  const _RoundRobinTable({required this.group, required this.onUpdateFixture});
  String _players(String id) {
    final p = _firstOrNull(group.participants.where((p) => p.id == id));
    return p?.playerNames.join(' / ') ?? '';
  }
  @override
  Widget build(BuildContext context) => Column(children: group.fixtures.map((f) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
        color: f.isLive ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: f.isLive ? const Color(0xFF16A34A).withOpacity(0.4) : Colors.grey.shade200)),
    child: Row(children: [
      _FormatBadge(label: f.round),
      const SizedBox(width: 12),
      Expanded(child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(f.teamAName, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          if (_players(f.teamAId).isNotEmpty) Text(_players(f.teamAId), textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(f.isCompleted ? '${f.setsWonA} – ${f.setsWonB}' : 'vs',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                    color: f.isCompleted ? const Color(0xFF4F46E5) : Colors.grey.shade400))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.teamBName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          if (_players(f.teamBId).isNotEmpty) Text(_players(f.teamBId), style: TextStyle(fontSize: 10, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
        ])),
      ])),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (f.date.isNotEmpty) Text(f.date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        if (f.time.isNotEmpty) Text(f.time, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        if (f.court.isNotEmpty) Text(f.court, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      ]),
      const SizedBox(width: 8),
      _StatusPill(label: f.statusLabel, color: f.statusColor),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () => showDialog(context: context, builder: (_) => _FixtureEditDialog(fixture: f, onSave: onUpdateFixture, participants: group.participants)),
        child: Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.edit_rounded, size: 13, color: Color(0xFF4F46E5))),
      ),
    ]),
  )).toList());
}
// ══════════════════════════════════════════════════════════════
// FIXTURE EDIT DIALOG
// ══════════════════════════════════════════════════════════════
class _FixtureEditDialog extends StatefulWidget {
  final FixtureModel fixture;
  final void Function(FixtureModel) onSave;
  final List<ParticipantModel> participants;
  const _FixtureEditDialog({required this.fixture, required this.onSave, required this.participants});
  @override
  State<_FixtureEditDialog> createState() => _FixtureEditDialogState();
}
class _FixtureEditDialogState extends State<_FixtureEditDialog> {
  late FixtureModel _f;
  final _liveCtrl  = TextEditingController();
  final _aCtrl     = TextEditingController();
  final _bCtrl     = TextEditingController();
  static const _indigo = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _f = widget.fixture;
    _liveCtrl.text = _f.liveStreamUrl;
    _aCtrl.text    = _f.teamAName;
    _bCtrl.text    = _f.teamBName;
  }
  @override
  void dispose() { _liveCtrl.dispose(); _aCtrl.dispose(); _bCtrl.dispose(); super.dispose(); }

  String _playersOf(String name) {
    final p = _firstOrNull(widget.participants.where((p) => p.name == name));
    return p?.playerNames.join(' / ') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: EdgeInsets.zero,
      content: Container(width: 520, padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.edit_calendar_rounded, color: _indigo), const SizedBox(width: 10),
            Expanded(child: Text('Edit Fixture — ${_f.round}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))]),
          Divider(height: 20, color: Colors.grey.shade200),
        
          const Text('Participants', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _participantField('Team / Player A', _aCtrl, (v) => setState(() => _f = _f.copyWith(teamAName: v)))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('vs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade500))),
            Expanded(child: _participantField('Team / Player B', _bCtrl, (v) => setState(() => _f = _f.copyWith(teamBName: v)))),
          ]),
          if (widget.participants.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(child: Text(_playersOf(_aCtrl.text), style: TextStyle(fontSize: 10, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 20),
                Expanded(child: Text(_playersOf(_bCtrl.text), style: TextStyle(fontSize: 10, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis)),
              ])),
          Divider(height: 20, color: Colors.grey.shade200),
          
          const Text('Schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FormLabel('Date'),
              InkWell(onTap: () async {
                final d = await showDatePicker(context: context,
                    initialDate: _f.date.isNotEmpty ? (DateTime.tryParse(_f.date) ?? DateTime.now()) : DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime(2035));
                if (d != null) setState(() => _f = _f.copyWith(date: d.toIso8601String().substring(0,10)));
              }, child: _pickerBox(_f.date.isEmpty ? 'Pick date' : _f.date, Icons.calendar_today_outlined, _f.date.isNotEmpty)),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FormLabel('Time'),
              InkWell(onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (t != null) setState(() => _f = _f.copyWith(time: '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}'));
              }, child: _pickerBox(_f.time.isEmpty ? 'Pick time' : _f.time, Icons.access_time_rounded, _f.time.isNotEmpty)),
            ])),
          ]),
          const SizedBox(height: 12),
          _FormLabel('Court / Venue'),
          DropdownButtonFormField<String>(
            value: TournamentSeeds.courts.contains(_f.court) ? _f.court : null,
            decoration: _inputDeco('Select court'),
            items: TournamentSeeds.courts.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _f = _f.copyWith(court: v ?? '')),
          ),
          Divider(height: 20, color: Colors.grey.shade200),
          _FormLabel('Status'),
          Wrap(spacing: 8, runSpacing: 6, children: FixtureModel.statuses.map((s) {
            final dummy = _f.copyWith(status: s); final isSel = _f.status == s;
            return GestureDetector(onTap: () => setState(() => _f = _f.copyWith(status: s, isLive: s == 'live')),
                child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: isSel ? dummy.statusColor : Colors.white, borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSel ? dummy.statusColor : Colors.grey.shade300)),
                    child: Text(dummy.statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSel ? Colors.white : Colors.grey.shade600))));
          }).toList()),
          Divider(height: 20, color: Colors.grey.shade200),
         
          
        ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () {
            widget.onSave(_f.copyWith(
              teamAName: _aCtrl.text.trim().isEmpty ? _f.teamAName : _aCtrl.text.trim(),
              teamBName: _bCtrl.text.trim().isEmpty ? _f.teamBName : _bCtrl.text.trim(),
              liveStreamUrl: _liveCtrl.text.trim(),
            ));
            Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
  }

  Widget _pickerBox(String text, IconData icon, bool hasValue) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
    child: Row(children: [
      Icon(icon, size: 14, color: const Color(0xFF4F46E5)), const SizedBox(width: 8),
      Text(text, style: TextStyle(fontSize: 13, color: hasValue ? const Color(0xFF111827) : Colors.grey.shade400)),
    ]),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    filled: true, fillColor: Colors.grey.shade50,
  );

  Widget _participantField(String label, TextEditingController ctrl, void Function(String) onChange) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FormLabel(label),
      if (widget.participants.isNotEmpty)
        DropdownButtonFormField<String>(
          value: widget.participants.any((p) => p.name == ctrl.text) ? ctrl.text : null,
          decoration: _inputDeco('Select'),
          items: [
            const DropdownMenuItem(value: 'TBD', child: Text('TBD', style: TextStyle(fontSize: 12))),
            ...widget.participants.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name, style: const TextStyle(fontSize: 12)))),
          ],
          onChanged: (v) { if (v != null) { ctrl.text = v; onChange(v); setState(() {}); } })
      else
        TextField(controller: ctrl, onChanged: onChange, style: const TextStyle(fontSize: 12),
            decoration: _inputDeco('Name')),
    ]);
  }
}
// ══════════════════════════════════════════════════════════════
// SCHEDULE TAB — category dropdown + dark match cards
// ══════════════════════════════════════════════════════════════
class _ScheduleTab extends StatefulWidget {
  final TournamentModel tournament; final void Function(FixtureModel) onUpdateFixture;
  const _ScheduleTab({required this.tournament, required this.onUpdateFixture});
  @override State<_ScheduleTab> createState() => _ScheduleTabState();
}
class _ScheduleTabState extends State<_ScheduleTab> {
  int _selIdx = 0;
  @override
  Widget build(BuildContext context) {
    final groups = widget.tournament.eventGroups;
    if (groups.isEmpty) return _empty('No fixtures yet.');
    if (_selIdx >= groups.length) _selIdx = 0;
    final g = groups[_selIdx];
    return Column(children: [
      _CategorySelector(groups: groups, selectedIdx: _selIdx, onChanged: (i) => setState(() => _selIdx = i)),
      Expanded(child: g.fixtures.isEmpty ? _empty('No fixtures for ${g.displayName}.')
          : ListView.builder(padding: const EdgeInsets.all(20), itemCount: g.fixtures.length,
              itemBuilder: (_, i) { final f = g.fixtures[i];
                return _ScheduleMatchCard(fixture: f, group: g, onEdit: () => showDialog(context: context,
                    builder: (_) => _FixtureEditDialog(fixture: f, onSave: widget.onUpdateFixture, participants: g.participants))); })),
    ]);
  }
}

class _ScheduleMatchCard extends StatelessWidget {
  final FixtureModel fixture; final EventGroup group; final VoidCallback onEdit;
  const _ScheduleMatchCard({required this.fixture, required this.group, required this.onEdit});
  String _players(String id) { final p = _firstOrNull(group.participants.where((p) => p.id == id)); return p?.playerNames.join(' / ') ?? ''; }
  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final aWins = f.winnerId == f.teamAId && f.winnerId.isNotEmpty;
    final bWins = f.winnerId == f.teamBId && f.winnerId.isNotEmpty;
    String dateStr = f.date.isEmpty ? 'Unscheduled' : f.date, dayStr = '';
    if (f.date.isNotEmpty) {
      try {
        final d = DateTime.parse(f.date);
        const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        dateStr = '${d.day} ${months[d.month-1]} ${d.year}'; dayStr = days[d.weekday - 1];
      } catch (_) {}
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: f.isLive ? const Color(0xFF16A34A) : Colors.transparent, width: f.isLive ? 2 : 0),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0,4))]),
      child: Padding(padding: const EdgeInsets.fromLTRB(16,14,16,14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          
          SizedBox(width: 88, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dateStr, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            if (dayStr.isNotEmpty) Text(dayStr, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
            const SizedBox(height: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                child: Text(f.time.isEmpty ? '—' : f.time, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
            if (f.court.isNotEmpty) ...[const SizedBox(height: 4),
              Row(children: [const Icon(Icons.sports_tennis, size: 10, color: Color(0xFFF59E0B)), const SizedBox(width: 3),
                Flexible(child: Text(f.court, style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))])],
          ])),
          const SizedBox(width: 12),
        
          Expanded(child: Column(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.emoji_events_outlined, size: 12, color: Color(0xFFF59E0B)), const SizedBox(width: 5),
                  Text('${f.round}  •  M${f.matchNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))])),
            const SizedBox(height: 10),
            Row(children: [
              // Team A
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (aWins) const Icon(Icons.circle, size: 8, color: Color(0xFF16A34A))
                  else if (bWins) const Icon(Icons.circle, size: 8, color: Color(0xFFEF4444)),
                  if (aWins || bWins) const SizedBox(width: 4),
                  Flexible(child: Text(f.teamAName, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: aWins ? Colors.white : Colors.white.withOpacity(0.75)))),
                ]),
                if (_players(f.teamAId).isNotEmpty) Text(_players(f.teamAId), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4))),
                if (f.teamAId.isNotEmpty && f.teamAName != 'TBD')
                  Padding(padding: const EdgeInsets.only(top: 4), child: _AvatarStack(
                      group.participants.where((p) => p.id == f.teamAId).expand((p) => p.playerNames.isEmpty ? [p.name] : p.playerNames).toList())),
              ])),
              // Score
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                child: f.isCompleted
                    ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.20), borderRadius: BorderRadius.circular(8)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('${f.setsWonA}–${f.setsWonB}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('sets', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.5))),
                          ...f.sets.map((s) => Text('${s.scoreA}–${s.scoreB}', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.4)))),
                        ]))
                    : Text('vs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.4)))),
              // Team B
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(f.teamBName, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: bWins ? Colors.white : Colors.white.withOpacity(0.75)))),
                  if (bWins) ...[const SizedBox(width: 4), const Icon(Icons.circle, size: 8, color: Color(0xFF16A34A))]
                  else if (aWins) ...[const SizedBox(width: 4), const Icon(Icons.circle, size: 8, color: Color(0xFFEF4444))],
                ]),
                if (_players(f.teamBId).isNotEmpty) Text(_players(f.teamBId), overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4))),
                if (f.teamBId.isNotEmpty && f.teamBName != 'TBD')
                  Padding(padding: const EdgeInsets.only(top: 4), child: _AvatarStack(
                      group.participants.where((p) => p.id == f.teamBId).expand((p) => p.playerNames.isEmpty ? [p.name] : p.playerNames).toList())),
              ])),
            ]),
          ])),
          const SizedBox(width: 12),
   
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _StatusPill(label: f.statusLabel, color: f.statusColor),
            const SizedBox(height: 8),
            GestureDetector(onTap: onEdit, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.settings_outlined, size: 12, color: Colors.white), SizedBox(width: 4),
                  Text('Edit', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600))]))),
          ]),
        ])),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final List<String> names;
  const _AvatarStack(this.names);
  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final colors = [const Color(0xFF4F46E5), const Color(0xFF16A34A), const Color(0xFFF59E0B), const Color(0xFFEF4444)];
    final list = names.take(4).toList();
    return SizedBox(height: 22, width: list.length * 16.0 + 6,
      child: Stack(children: list.asMap().entries.map((e) => Positioned(left: e.key * 16.0,
          child: Container(width: 22, height: 22,
              decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0D1B2A), width: 1.5)),
              child: Center(child: Text(e.value.isNotEmpty ? e.value[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))))).toList()));
  }
}
// ══════════════════════════════════════════════════════════════
// CALENDAR TAB — CSV downloads as real file

// ══════════════════════════════════════════════════════════════
class _CalendarTab extends StatefulWidget {
  final TournamentModel tournament;
  const _CalendarTab({required this.tournament});
  @override State<_CalendarTab> createState() => _CalendarTabState();
}
class _CalendarTabState extends State<_CalendarTab> {
  bool   _calView     = false;
  String _filterVenue = '', _filterTeam = '', _filterStatus = '';

  List<FixtureModel> get _allFixtures => [for (final g in widget.tournament.eventGroups) ...g.fixtures];
  List<FixtureModel> get _filtered => _allFixtures.where((f) {
    if (_filterVenue.isNotEmpty  && f.court  != _filterVenue)   return false;
    if (_filterStatus.isNotEmpty && f.status != _filterStatus)  return false;
    if (_filterTeam.isNotEmpty   &&
        !f.teamAName.toLowerCase().contains(_filterTeam.toLowerCase()) &&
        !f.teamBName.toLowerCase().contains(_filterTeam.toLowerCase())) return false;
    return true;
  }).toList();
  Map<String, List<FixtureModel>> get _byDate {
    final map = <String, List<FixtureModel>>{};
    for (final f in _filtered) map.putIfAbsent(f.date.isEmpty ? 'Unscheduled' : f.date, () => []).add(f);
    return Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  // ── CSV export —
  void _exportCsv() {
    final sb = StringBuffer();
    sb.writeln('Category,Round,Match No,Team A,Team B,Date,Time,Court,Status,Sets A,Sets B,Set Scores');
    for (final g in widget.tournament.eventGroups) {
      for (final f in g.fixtures) {
        final setScores = f.sets.map((s) => '${s.scoreA}-${s.scoreB}').join(' | ');
        sb.writeln('"${g.displayName}","${f.round}","${f.matchNumber}","${f.teamAName}","${f.teamBName}",'
            '"${f.date}","${f.time}","${f.court}","${f.statusLabel}","${f.setsWonA}","${f.setsWonB}","$setScores"');
      }
    }
    final csvContent = sb.toString();
    final fileName   = '${widget.tournament.name.replaceAll(' ', '_')}_schedule.csv';

    try {
     
      final dynamic html = _tryImportHtml();
      if (html != null) {
        final bytes  = utf8.encode(csvContent);
        final blob   = html['Blob']([bytes], {'type': 'text/csv'});
        final url    = html['Url'].createObjectUrlFromBlob(blob);
        final anchor = html['document'].createElement('a');
        anchor['href']     = url;
        anchor['download'] = fileName;
        html['document']['body'].append(anchor);
        anchor.click();
        anchor.remove();
        html['Url'].revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(_csvSnack('Downloaded: $fileName', const Color(0xFF16A34A)));
        return;
      }
    } catch (_) {}


    Clipboard.setData(ClipboardData(text: csvContent));
    ScaffoldMessenger.of(context).showSnackBar(
        _csvSnack('CSV copied to clipboard! Paste into Excel / Google Sheets', const Color(0xFF16A34A)));
  }

  dynamic _tryImportHtml() => null; 

  SnackBar _csvSnack(String msg, Color color) => SnackBar(
    content: Row(children: [const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16), const SizedBox(width: 8), Expanded(child: Text(msg))]),
    backgroundColor: color, behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 4));

  @override
  Widget build(BuildContext context) {
    final venues = _allFixtures.map((f) => f.court).where((c) => c.isNotEmpty).toSet().toList();
    return Column(children: [
      // Toolbar
      Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: Row(children: [
            Container(decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _ToggleBtn(icon: Icons.view_list_rounded,      label: 'List',     active: !_calView, onTap: () => setState(() => _calView = false)),
                  _ToggleBtn(icon: Icons.calendar_month_rounded, label: 'Calendar', active: _calView,  onTap: () => setState(() => _calView = true)),
                ])),
            const SizedBox(width: 12),
            Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _CalFilter(label: 'Status', value: _filterStatus, options: ['', ...FixtureModel.statuses], onChanged: (v) => setState(() => _filterStatus = v)),
              const SizedBox(width: 8),
              if (venues.isNotEmpty) _CalFilter(label: 'Venue', value: _filterVenue, options: ['', ...venues], onChanged: (v) => setState(() => _filterVenue = v)),
              const SizedBox(width: 8),
              SizedBox(width: 160, height: 36, child: TextField(
                onChanged: (v) => setState(() => _filterTeam = v), style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(hintText: 'Filter team...', hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey.shade400), contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    filled: true, fillColor: Colors.grey.shade50))),
            ]))),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.file_download_rounded, size: 15),
              label: const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ])),
      // Stats bar
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(children: [
            Text('${_filtered.length} of ${_allFixtures.length} matches', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(width: 16),
            ...FixtureModel.statuses.map((s) {
              final col = s == 'live' ? const Color(0xFF16A34A) : s == 'completed' ? const Color(0xFF374151) : s == 'cancelled' ? const Color(0xFFEF4444) : const Color(0xFF6366F1);
              final count = _allFixtures.where((f) => f.status == s).length;
              if (count == 0) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(right: 10), child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                const SizedBox(width: 3),
                Text('$count ${s[0].toUpperCase()}${s.substring(1)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ]));
            }),
          ])),
      Expanded(child: _calView ? _CalGridView(byDate: _byDate) : _CalListView(byDate: _byDate)),
    ]);
  }
}

class _CalListView extends StatelessWidget {
  final Map<String, List<FixtureModel>> byDate;
  const _CalListView({required this.byDate});
  @override
  Widget build(BuildContext context) {
    if (byDate.isEmpty) return _empty('No fixtures match filters.');
    return SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: byDate.entries.map((e) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                    child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)))),
                const SizedBox(width: 10), Expanded(child: Divider(color: Colors.grey.shade200))])),
              ...e.value.map((f) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: f.statusColor.withOpacity(0.35), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
                  child: Row(children: [
                    Container(width: 4, height: 44, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: f.statusColor, borderRadius: BorderRadius.circular(4))),
                    if (f.time.isNotEmpty) SizedBox(width: 42, child: Text(f.time, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${f.teamAName}  vs  ${f.teamBName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                      Row(children: [_FormatBadge(label: f.round),
                        if (f.court.isNotEmpty) ...[const SizedBox(width: 6), Text('· ${f.court}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500))]]),
                    ])),
                    if (f.isCompleted) ...[Text('${f.setsWonA}–${f.setsWonB}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))), const SizedBox(width: 8)],
                    _StatusPill(label: f.statusLabel, color: f.statusColor),
                  ]))),
              const SizedBox(height: 12),
            ])).toList()));
  }
}

class _CalGridView extends StatelessWidget {
  final Map<String, List<FixtureModel>> byDate;
  const _CalGridView({required this.byDate});
  @override
  Widget build(BuildContext context) {
    if (byDate.isEmpty) return _empty('No fixtures match filters.');
    return SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Wrap(spacing: 12, runSpacing: 12,
            children: byDate.entries.map((e) => Container(width: 200, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                      child: Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)))),
                  const SizedBox(height: 8),
                  ...e.value.map((f) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
                    Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: f.statusColor, shape: BoxShape.circle)),
                    Expanded(child: Text('${f.teamAName} vs ${f.teamBName}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                  ]))),
                ]))).toList()));
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  const _ToggleBtn({required this.icon, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(6),
              boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)] : []),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF4F46E5) : Colors.grey.shade500),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? const Color(0xFF4F46E5) : Colors.grey.shade500)),
          ])));
}

class _CalFilter extends StatelessWidget {
  final String label, value; final List<String> options; final void Function(String) onChanged;
  const _CalFilter({required this.label, required this.value, required this.options, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: value.isNotEmpty ? const Color(0xFF4F46E5) : Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value,
          hint: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey.shade400),
          style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? 'All $label' : o[0].toUpperCase() + o.substring(1), style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => onChanged(v ?? ''))));
}
// ══════════════════════════════════════════════════════════════
// LIVE TAB 
// ══════════════════════════════════════════════════════════════
class _LiveTab extends StatefulWidget {
  final TournamentModel tournament; final void Function(FixtureModel) onUpdateFixture;
  const _LiveTab({required this.tournament, required this.onUpdateFixture});
  @override State<_LiveTab> createState() => _LiveTabState();
}
class _LiveTabState extends State<_LiveTab> {
  int    _selCatIdx  = 0;
  String _selFixId   = '';
  static const _indigo = Color(0xFF4F46E5);

  List<EventGroup>  get _groups   => widget.tournament.eventGroups;
  EventGroup?       get _selGroup => _selCatIdx < _groups.length ? _groups[_selCatIdx] : null;
  List<FixtureModel> get _matches => _selGroup?.fixtures ?? [];
  FixtureModel? get _selFix {
    if (_selFixId.isEmpty) return _firstOrNull(_matches.where((f) => f.isLive)) ?? _firstOrNull(_matches);
    return _firstOrNull(_matches.where((f) => f.id == _selFixId));
  }

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _groups.length; i++) { if (_groups[i].fixtures.any((f) => f.isLive)) { _selCatIdx = i; break; } }
  }

  void _toggleLive(FixtureModel f) {
    widget.onUpdateFixture(f.copyWith(isLive: !f.isLive, status: f.isLive ? 'scheduled' : 'live'));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_groups.isEmpty) return _empty('No categories found.');
    if (_selCatIdx >= _groups.length) _selCatIdx = 0;
    return Row(children: [
      // LEFT SIDEBAR
      Container(width: 280, decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.grey.shade200))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('CATEGORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: _indigo.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: _indigo.withOpacity(0.2))),
                      child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: _selCatIdx, isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF4F46E5)),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                          items: _groups.asMap().entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.displayName, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() { _selCatIdx = v!; _selFixId = ''; })))),
                ])),
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: const Text('MATCHES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5))),
            Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), itemCount: _matches.length,
                itemBuilder: (_, i) {
                  final f = _matches[i]; final isSel = f.id == (_selFix?.id ?? '');
                  return GestureDetector(onTap: () => setState(() => _selFixId = f.id),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: isSel ? _indigo.withOpacity(0.08) : Colors.transparent, borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSel ? _indigo.withOpacity(0.3) : Colors.transparent)),
                          child: Row(children: [
                            if (f.isLive) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6), decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('M${f.matchNumber}  •  ${f.round}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                              const SizedBox(height: 2),
                              Text(f.teamAName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                              Text(f.teamBName, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ])),
                            if (f.isCompleted) Text('${f.setsWonA}–${f.setsWonB}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                          ])));
                })),
          ])),
      // RIGHT PANEL
      Expanded(child: _selFix == null
          ? _empty('Select a match from the left panel')
          : _LiveMatchPanel(fixture: _selFix!, group: _selGroup!, onToggleLive: () => _toggleLive(_selFix!),
              onEnterScore: () => showDialog(context: context,
                  builder: (_) => _PadelScoreDialog(fixture: _selFix!, group: _selGroup!, onSave: (upd) { widget.onUpdateFixture(upd); setState(() {}); })))),
    ]);
  }
}

class _LiveMatchPanel extends StatelessWidget {
  final FixtureModel fixture; final EventGroup group;
  final VoidCallback onToggleLive, onEnterScore;
  const _LiveMatchPanel({required this.fixture, required this.group, required this.onToggleLive, required this.onEnterScore});
  String _players(String id) { final p = _firstOrNull(group.participants.where((p) => p.id == id)); return p?.playerNames.join(' / ') ?? ''; }
  @override
  Widget build(BuildContext context) {
    final f = fixture; final aWins = f.winnerId == f.teamAId && f.winnerId.isNotEmpty; final bWins = f.winnerId == f.teamBId && f.winnerId.isNotEmpty;
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
     
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${f.teamAName}  vs  ${f.teamBName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          if (_players(f.teamAId).isNotEmpty || _players(f.teamBId).isNotEmpty)
            Text('${_players(f.teamAId)}   vs   ${_players(f.teamBId)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ])),
        ElevatedButton(onPressed: onEnterScore,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Enter Score', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: onToggleLive,
            style: ElevatedButton.styleFrom(backgroundColor: f.isLive ? Colors.orange.shade600 : const Color(0xFF16A34A), foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(f.isLive ? 'Stop Live' : 'Go Live', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
      ]),
      Divider(color: Colors.grey.shade200, height: 24),
      Row(children: [
        _StatusPill(label: f.isLive ? '🔴 LIVE' : f.statusLabel, color: f.statusColor),
        const SizedBox(width: 12),
        Text('${f.round}  •  Match ${f.matchNumber}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        if (f.court.isNotEmpty) ...[const SizedBox(width: 10), Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade400), const SizedBox(width: 2), Text(f.court, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))],
      ]),
      const SizedBox(height: 20),
      // Scoreboard
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0,6))]),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(children: [
                Text(f.teamAName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                if (_players(f.teamAId).isNotEmpty) Text(_players(f.teamAId), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('${f.setsWonA}', style: TextStyle(color: aWins ? const Color(0xFF4ADE80) : Colors.white, fontSize: 60, fontWeight: FontWeight.bold, height: 1)),
              ])),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(':', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 44, fontWeight: FontWeight.bold))),
              Expanded(child: Column(children: [
                Text(f.teamBName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                if (_players(f.teamBId).isNotEmpty) Text(_players(f.teamBId), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('${f.setsWonB}', style: TextStyle(color: bWins ? const Color(0xFF4ADE80) : Colors.white, fontSize: 60, fontWeight: FontWeight.bold, height: 1)),
              ])),
            ]),
            if (f.sets.isNotEmpty) ...[
              const SizedBox(height: 18),
              Divider(color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 12),
              // Per-set scores
              ...f.sets.asMap().entries.map((e) {
                final sw = e.value.scoreA > e.value.scoreB ? 'A' : e.value.scoreB > e.value.scoreA ? 'B' : '';
                return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                  Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: sw=='A' ? const Color(0xFF4F46E5).withOpacity(0.3) : Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                      child: Text('${e.value.scoreA}', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: sw=='A' ? Colors.white : Colors.white.withOpacity(0.6))))),
                  SizedBox(width: 40, child: Text(e.key >= 2 ? 'S.TB' : 'Set ${e.key+1}', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.3)))),
                  Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: sw=='B' ? const Color(0xFF4F46E5).withOpacity(0.3) : Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                      child: Text('${e.value.scoreB}', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: sw=='B' ? Colors.white : Colors.white.withOpacity(0.6))))),
                ]));
              }),
            ] else Padding(padding: const EdgeInsets.only(top: 16),
                child: Text('No scores yet. Use "Enter Score" to record.', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12), textAlign: TextAlign.center)),
            if (f.winnerId.isNotEmpty) ...[
              const SizedBox(height: 14), Divider(color: Colors.white.withOpacity(0.1)), const SizedBox(height: 10),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 16), const SizedBox(width: 8),
                    Text('Winner: ${f.winnerId == f.teamAId ? f.teamAName : f.teamBName}', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13))])),
            ],
          ])),
    ]));
  }
}
// ══════════════════════════════════════════════════════════════
// PADEL SCORE DIALOG — Enhanced Score Entry (SCR-001)
// ══════════════════════════════════════════════════════════════
class _PadelScoreDialog extends StatefulWidget {
  final FixtureModel fixture;
  final EventGroup group;
  final void Function(FixtureModel) onSave;
  final String userRole; // 'admin' | 'scorer' | 'viewer'
  const _PadelScoreDialog({
    required this.fixture,
    required this.group,
    required this.onSave,
    this.userRole = 'admin',
  });
  @override State<_PadelScoreDialog> createState() => _PadelScoreDialogState();
}

class _PadelScoreDialogState extends State<_PadelScoreDialog> {
  List<int> _gA = [], _gB = [];
  String _winnerId   = '';
  String _resultType = 'normal';
  List<String> _errors = [];
  int _bestOf = 3; // Best of 2 | 3 | 5
  bool _published = false;
  bool _submitting = false;
  static const _indigo = Color(0xFF4F46E5);
  static const _green  = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    _gA = widget.fixture.sets.map((s) => s.scoreA).toList();
    _gB = widget.fixture.sets.map((s) => s.scoreB).toList();
   
    if (_gA.length >= 5) _bestOf = 5;
    else if (_gA.length >= 3) _bestOf = 3;
    else _bestOf = 3;
    _ensureSetCount();
    _published = widget.fixture.isCompleted;
    _recalc();
  }

  int get _setsNeeded => (_bestOf / 2).ceil(); 

  void _ensureSetCount() {
  
    while (_gA.length < _bestOf) { _gA.add(0); _gB.add(0); }
    while (_gA.length > _bestOf) { _gA.removeLast(); _gB.removeLast(); }
  }

  void _setBestOf(int val) {
    setState(() {
      _bestOf = val;
      _ensureSetCount();
      _recalc();
    });
  }

  void _recalc() {
    final errors = <String>[];
    int sA = 0, sB = 0;
    for (int i = 0; i < _gA.length; i++) {
      
      final isLast = i == _gA.length - 1;
      final isSuperTb = (_bestOf == 3 && i == 2) || (_bestOf == 5 && i == 4);
      if (_gA[i] > 0 || _gB[i] > 0) {
        final err = _PadelScoringEngine.validateSet(_gA[i], _gB[i], isSuperTb ? 2 : i);
        if (err != null) errors.add('Set ${isSuperTb ? "S.TB" : i + 1}: $err');
      }
      final w = _PadelScoringEngine.setWinner(_gA[i], _gB[i], isSuperTb ? 2 : i);
      if (w == 'A') sA++;
      if (w == 'B') sB++;
    }
    String winner = '';
    switch (_resultType) {
      case 'walkover_a': winner = widget.fixture.teamAId; break;
      case 'walkover_b': winner = widget.fixture.teamBId; break;
     
      default:
        if (sA >= _setsNeeded) winner = widget.fixture.teamAId;
        else if (sB >= _setsNeeded) winner = widget.fixture.teamBId;
    }
    setState(() { _errors = errors; _winnerId = winner; });
  }

  int get _setsWonA {
    int s = 0;
    for (int i = 0; i < _gA.length; i++) {
      final isSuperTb = (_bestOf == 3 && i == 2) || (_bestOf == 5 && i == 4);
      if (_PadelScoringEngine.setWinner(_gA[i], _gB[i], isSuperTb ? 2 : i) == 'A') s++;
    }
    return s;
  }
  int get _setsWonB {
    int s = 0;
    for (int i = 0; i < _gA.length; i++) {
      final isSuperTb = (_bestOf == 3 && i == 2) || (_bestOf == 5 && i == 4);
      if (_PadelScoringEngine.setWinner(_gA[i], _gB[i], isSuperTb ? 2 : i) == 'B') s++;
    }
    return s;
  }

  void _submit({required bool publish}) {
    if (_errors.isNotEmpty) {
      _showToast('Fix errors before submitting', isError: true);
      return;
    }
    setState(() => _submitting = true);
 
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final sets = List.generate(_gA.length, (i) => SetScore(scoreA: _gA[i], scoreB: _gB[i]));
      widget.onSave(widget.fixture.copyWith(
        sets: sets, setsWonA: _setsWonA, setsWonB: _setsWonB,
        winnerId: _winnerId,
        status: publish ? 'completed' : 'live',
        isLive: !publish,
      ));
      setState(() { _submitting = false; _published = publish; });
      _showToast(publish ? '✓ Score published successfully' : '✓ Score saved as draft', isError: false);
      if (publish) Navigator.pop(context);
    });
  }

  void _showToast(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: isError ? Colors.red.shade700 : _green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {

    if (widget.userRole == 'viewer') {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Container(width: 360, padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Access Restricted', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Score entry is only available to Scorers and Admins.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Close'),
            ),
          ]),
        ),
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 560,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
         
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              const Icon(Icons.sports_tennis, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Score Entry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('${widget.fixture.teamAName}  vs  ${widget.fixture.teamBName}',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)), overflow: TextOverflow.ellipsis),
              ])),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(widget.userRole.toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20)),
            ]),
          ),

         
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: const Color(0xFFF8F9FE),
            child: Row(children: [
              _FormatBadge(label: widget.fixture.round),
              const SizedBox(width: 8),
              _FormatBadge(label: 'M${widget.fixture.matchNumber}', color: Colors.grey.shade500),
              if (widget.fixture.court.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.sports_tennis_rounded, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text(widget.fixture.court, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
              const Spacer(),
              // Best-of selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _indigo.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Best of:', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  ...[2, 3, 5].map((n) => GestureDetector(
                    onTap: () => _setBestOf(n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 26, height: 26,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: _bestOf == n ? _indigo : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(child: Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: _bestOf == n ? Colors.white : Colors.grey.shade500))),
                    ),
                  )),
                ]),
              ),
            ]),
          ),

       
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            
              const Text('Result Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _resultChip('normal',     'Normal Match'),
                _resultChip('walkover_a', 'W/O: ${_aN} wins'),
                _resultChip('walkover_b', 'W/O: ${_bN} wins'),
               
              ]),
              const SizedBox(height: 16),

              if (_resultType == 'normal') ...[
                
                Row(children: [
                  const SizedBox(width: 70),
                  Expanded(child: Text(_aN, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(_bN, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 24),
                ]),
                const SizedBox(height: 10),

                ...List.generate(_gA.length, (i) {
                  final isSuperTb = (_bestOf == 3 && i == 2) || (_bestOf == 5 && i == 4);
                  final label = isSuperTb ? 'Super\nTB' : 'Set ${i + 1}';
                  final hint  = isSuperTb ? ' ' : ' ';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _setRow(i, label, hint, isSuperTb),
                  );
                }),
              ],

            
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: _indigo.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10), border: Border.all(color: _indigo.withOpacity(0.2))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(child: Text(_aN, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 12),
                  Text('$_setsWonA', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _indigo)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('SETS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400))),
                  Text('$_setsWonB', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _indigo)),
                  const SizedBox(width: 12),
                  Flexible(child: Text(_bN, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis)),
                ]),
              ),

              // Winner banner
              if (_winnerId.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 8),
                    Text('Winner: ${_winnerId == widget.fixture.teamAId ? _aN : _bN}',
                        style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
                    if (_resultType != 'normal') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text(_resultType.contains('walkover') ? 'Walkover' : 'Retirement',
                            style: const TextStyle(fontSize: 10, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                ),
              ],
              const SizedBox(height: 14),
            ]),
          )),

          // ── Validation errors ─────────────────────────────────
          if (_errors.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: _errors.map((e) => Row(children: [
                    Icon(Icons.error_outline, size: 12, color: Colors.red.shade600),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e, style: TextStyle(fontSize: 11, color: Colors.red.shade700))),
                  ])).toList()),
            ),

          // ── Actions: Cancel | Save Draft | Publish ─────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
              ),
              const Spacer(),
              // Edit / Save Draft button (saves without publishing)
              OutlinedButton.icon(
                onPressed: (_submitting || _errors.isNotEmpty) ? null : () => _submit(publish: false),
                icon: _submitting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Save Draft', style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _indigo,
                  side: BorderSide(color: _errors.isNotEmpty ? Colors.grey.shade300 : _indigo),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 10),
              // Publish button
              ElevatedButton.icon(
                onPressed: (_submitting || _errors.isNotEmpty || _winnerId.isEmpty) ? null : () => _submit(publish: true),
                icon: _submitting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.publish_rounded, size: 15),
                label: const Text('Publish Score', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _errors.isNotEmpty || _winnerId.isEmpty ? Colors.grey.shade400 : _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String get _aN => widget.fixture.teamAName;
  String get _bN => widget.fixture.teamBName;

  Widget _resultChip(String value, String label) {
    final sel = _resultType == value;
    return GestureDetector(
      onTap: () => setState(() { _resultType = value; _recalc(); }),
      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? _indigo : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? _indigo : Colors.grey.shade300),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: sel ? Colors.white : Colors.grey.shade700))),
    );
  }

  Widget _setRow(int setIdx, String label, String hint, bool isSuperTb) {
    if (setIdx >= _gA.length) return const SizedBox.shrink();
    final w   = _PadelScoringEngine.setWinner(_gA[setIdx], _gB[setIdx], isSuperTb ? 2 : setIdx);
    final hasErr = _errors.any((e) => e.startsWith('Set ${isSuperTb ? "S.TB" : setIdx + 1}'));
    final maxScore = isSuperTb ? 25 : 7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hasErr ? Colors.red.shade50 : w != null ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasErr ? Colors.red.shade300 : w != null ? _green.withOpacity(0.4) : Colors.grey.shade200,
          width: (hasErr || w != null) ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        SizedBox(width: 70, child: Column(children: [
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(hint, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
          if (w != null)
            Padding(padding: const EdgeInsets.only(top: 3),
                child: Text(w == 'A' ? '✓ $_aN' : '✓ $_bN', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, color: _green, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis)),
        ])),
        Expanded(child: _counter(_gA[setIdx], maxScore, w == 'A',
            dec: () { if (_gA[setIdx] > 0) setState(() { _gA[setIdx]--; _recalc(); }); },
            inc: () => setState(() { _gA[setIdx]++; _recalc(); }))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('–', style: TextStyle(fontSize: 18, color: Colors.grey.shade400, fontWeight: FontWeight.bold))),
        Expanded(child: _counter(_gB[setIdx], maxScore, w == 'B',
            dec: () { if (_gB[setIdx] > 0) setState(() { _gB[setIdx]--; _recalc(); }); },
            inc: () => setState(() { _gB[setIdx]++; _recalc(); }))),
      ]),
    );
  }

  Widget _counter(int value, int maxVal, bool winner, {required VoidCallback dec, required VoidCallback inc}) =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _counterBtn(Icons.remove_rounded, value > 0, dec),
        const SizedBox(width: 8),
        Container(width: 48, height: 48,
            decoration: BoxDecoration(
                color: winner ? _green.withOpacity(0.10) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: winner ? _green : Colors.grey.shade300, width: winner ? 2 : 1)),
            child: Center(child: Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: winner ? _green : const Color(0xFF111827))))),
        const SizedBox(width: 8),
        _counterBtn(Icons.add_rounded, value < maxVal, inc),
      ]);

  Widget _counterBtn(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(width: 32, height: 32,
          decoration: BoxDecoration(
              color: enabled ? _indigo.withOpacity(0.08) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: enabled ? _indigo : Colors.grey.shade300)));
}
// ══════════════════════════════════════════════════════════════
// STANDINGS TAB 
// ══════════════════════════════════════════════════════════════
class _StandingsTab extends StatefulWidget {
  final TournamentModel tournament;
  const _StandingsTab({required this.tournament});
  @override State<_StandingsTab> createState() => _StandingsTabState();
}
class _StandingsTabState extends State<_StandingsTab> {
  int _selIdx = 0;
  bool _showTiebreakerInfo = false;
  static const _indigo = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    final groups = widget.tournament.eventGroups;
    if (groups.isEmpty) return _empty('No categories yet.');
    if (_selIdx >= groups.length) _selIdx = 0;
    final g = groups[_selIdx];

    return Column(children: [
      _CategorySelector(
        groups: groups,
        selectedIdx: _selIdx,
        onChanged: (i) => setState(() => _selIdx = i),
        trailing: [
        
          GestureDetector(
            onTap: () => setState(() => _showTiebreakerInfo = !_showTiebreakerInfo),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _showTiebreakerInfo ? _indigo.withOpacity(0.1) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _showTiebreakerInfo ? _indigo.withOpacity(0.4) : Colors.blue.shade200),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.info_outline_rounded, size: 12,
                    color: _showTiebreakerInfo ? _indigo : Colors.blue.shade700),
                const SizedBox(width: 5),
                Text('Tiebreaker Rules', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: _showTiebreakerInfo ? _indigo : Colors.blue.shade700)),
              ]),
            ),
          ),
        ],
      ),

     
      if (_showTiebreakerInfo)
        _TiebreakerInfoPanel(format: g.format),

      Expanded(child: g.format == 'round_robin'
          ? _RoundRobinStandings(group: g)
          : g.format == 'knockout'
              ? _KnockoutStandings(group: g)
              : _empty('Standings not available for custom format.')),
    ]);
  }
}


class _TiebreakerInfoPanel extends StatelessWidget {
  final String format;
  const _TiebreakerInfoPanel({required this.format});
  static const _indigo = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    if (format != 'round_robin') return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _indigo.withOpacity(0.03),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: _indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.sort_rounded, size: 14, color: _indigo)),
          const SizedBox(width: 8),
          const Text('Ranking Calculation & Tiebreaker Order',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        ]),
        const SizedBox(height: 10),
        ...[
          _tbRow('1', Icons.stars_rounded, 'Points', 'Win = 3 pts  ·  Loss = 0 pts  ·  Teams sorted by total points first', const Color(0xFF4F46E5)),
          _tbRow('2', Icons.compare_arrows_rounded, 'Head to Head', 'If equal points: direct result between tied teams decides rank', const Color(0xFF0891B2)),
          _tbRow('3', Icons.sports_tennis_rounded, 'Set Difference', 'If H2H tied: Sets Won − Sets Lost across all matches', const Color(0xFF16A34A)),
          _tbRow('4', Icons.calculate_outlined, 'Game / Point Difference', 'If set diff tied: Total Games Won − Total Games Lost', const Color(0xFFF59E0B)),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200)),
          child: Row(children: [
            Icon(Icons.info_outline, size: 12, color: Colors.amber.shade700),
            const SizedBox(width: 6),
            Expanded(child: Text('If all tiebreakers are equal, teams share the same rank.',
                style: TextStyle(fontSize: 10, color: Colors.amber.shade800))),
          ]),
        ),
      ]),
    );
  }

  Widget _tbRow(String step, IconData icon, String title, String desc, Color color) =>
    Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 20, height: 20,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(child: Text(step, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)))),
      const SizedBox(width: 10),
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        Text(desc, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ])),
    ]));
}

// ── Standing entry data model ─────────────────────────────────
class _SE {
  final String id, name;
  final int pl, w, l, sf, sa, gf, ga, pts;
  final Map<String, int> h2h;
  const _SE({required this.id, required this.name, this.pl=0, this.w=0, this.l=0, this.sf=0, this.sa=0, this.gf=0, this.ga=0, this.pts=0, this.h2h=const {}});
  _SE upd({int? pl, int? w, int? l, int? sf, int? sa, int? gf, int? ga, int? pts, Map<String,int>? h2h}) =>
      _SE(id:id,name:name,pl:pl??this.pl,w:w??this.w,l:l??this.l,sf:sf??this.sf,sa:sa??this.sa,gf:gf??this.gf,ga:ga??this.ga,pts:pts??this.pts,h2h:h2h??this.h2h);
}

// ── Round Robin Standings ──────────────────────────────────────
class _RoundRobinStandings extends StatelessWidget {
  final EventGroup group;
  const _RoundRobinStandings({required this.group});
  static const _indigo = Color(0xFF4F46E5);

  List<_SE> _compute() {
    final map = <String, _SE>{ for (final p in group.participants) p.id: _SE(id:p.id,name:p.name) };
    for (final f in group.fixtures) {
      if (!f.isCompleted || f.teamAId.isEmpty || f.teamBId.isEmpty) continue;
      final a = map[f.teamAId]; final b = map[f.teamBId];
      if (a == null || b == null) continue;
      final aWon = f.winnerId == f.teamAId;
      int gA = 0, gB = 0;
      for (final s in f.sets) { gA += s.scoreA; gB += s.scoreB; }
      map[f.teamAId] = a.upd(pl:a.pl+1, w:aWon?a.w+1:a.w, l:aWon?a.l:a.l+1,
          sf:a.sf+f.setsWonA, sa:a.sa+f.setsWonB, gf:a.gf+gA, ga:a.ga+gB,
          pts:a.pts+(aWon?3:0), h2h:{...a.h2h, f.teamBId: aWon?1:-1});
      map[f.teamBId] = b.upd(pl:b.pl+1, w:aWon?b.w:b.w+1, l:aWon?b.l+1:b.l,
          sf:b.sf+f.setsWonB, sa:b.sa+f.setsWonA, gf:b.gf+gB, ga:b.ga+gA,
          pts:b.pts+(aWon?0:3), h2h:{...b.h2h, f.teamAId: aWon?-1:1});
    }
    final rows = map.values.toList();
 
    rows.sort((a, b) {
      // 1. Points
      if (b.pts != a.pts) return b.pts.compareTo(a.pts);
      // 2. Head-to-Head
      final h2hA = a.h2h[b.id] ?? 0; final h2hB = b.h2h[a.id] ?? 0;
      if (h2hA != h2hB) return h2hB.compareTo(h2hA);
      // 3. Set Difference
      final sdA = a.sf - a.sa; final sdB = b.sf - b.sa;
      if (sdA != sdB) return sdB.compareTo(sdA);
      // 4. Game / Point Difference
      return (b.gf - b.ga).compareTo(a.gf - a.ga);
    });
    return rows;
  }

  String _sign(int v) => v > 0 ? '+$v' : '$v';
  Color _signColor(int v) => v >= 0 ? const Color(0xFF16A34A) : const Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final rows = _compute();
    final completed = group.fixtures.where((f) => f.isCompleted).length;
    final total     = group.fixtures.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Progress bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Match Progress', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const Spacer(),
              Text('$completed / $total completed', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? completed / total : 0,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(_indigo),
                )),
          ]),
        ),

      
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200)),
          child: Wrap(spacing: 16, runSpacing: 4, children: [
            _legend('Pl', 'Played'), _legend('W', 'Won'), _legend('L', 'Lost'),
            _legend('H2H', 'Head to Head result'), _legend('SD', 'Set Diff'),
            _legend('GD', 'Game Diff'), _legend('Pts', 'Points (W=3)'),
          ]),
        ),

      
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
          child: Column(children: [
        
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(children: [
                const SizedBox(width: 32, child: Text('#', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                const SizedBox(width: 8),
                const Expanded(flex: 5, child: Text('Team / Player',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                _hCell('Pl'), _hCell('W'), _hCell('L'),
                _hCell('H2H', color: const Color(0xFF0891B2)),
                _hCell('SD',  color: const Color(0xFF16A34A)),
                _hCell('GD',  color: const Color(0xFFF59E0B)),
                _hCell('Pts', flex: 2, color: _indigo),
              ]),
            ),

            if (rows.isEmpty)
              Padding(padding: const EdgeInsets.all(32),
                  child: Text('No matches completed yet.', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)))
            else
              ...rows.asMap().entries.map((e) {
                final r = e.value; final idx = e.key; final isTop = idx == 0;
                final medal = idx == 0 ? '🥇' : idx == 1 ? '🥈' : idx == 2 ? '🥉' : null;
                final h2hVal = r.h2h.values.fold(0, (sum, v) => sum + v);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: isTop ? _indigo.withOpacity(0.04) : idx.isEven ? Colors.white : Colors.grey.shade50,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    borderRadius: idx == rows.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(12))
                        : BorderRadius.zero,
                  ),
                  child: Row(children: [
                    SizedBox(width: 32, child: medal != null
                        ? Text(medal, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15))
                        : Text('${idx+1}', textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
                    const SizedBox(width: 8),
                    Expanded(flex: 5, child: Row(children: [
                      Expanded(child: Text(r.name, style: TextStyle(fontSize: 13,
                          fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                          color: const Color(0xFF111827)))),
                      if (isTop && r.pts > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('Leader', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A))),
                        ),
                    ])),
                    _dCell('${r.pl}'),
                    _dCell('${r.w}', color: r.w > 0 ? const Color(0xFF16A34A) : null, bold: r.w > 0),
                    _dCell('${r.l}', color: r.l > 0 ? const Color(0xFFEF4444) : null, bold: r.l > 0),
                 
                    Expanded(child: Center(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: h2hVal > 0 ? const Color(0xFF0891B2).withOpacity(0.1)
                            : h2hVal < 0 ? Colors.red.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(h2hVal > 0 ? '+${h2hVal}' : '$h2hVal',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: h2hVal > 0 ? const Color(0xFF0891B2)
                                  : h2hVal < 0 ? Colors.red.shade500
                                  : Colors.grey.shade500)),
                    ))),
                    _dCell(_sign(r.sf - r.sa), color: _signColor(r.sf - r.sa)),
                    _dCell(_sign(r.gf - r.ga), color: _signColor(r.gf - r.ga)),
                    _ptsCell(r.pts, flex: 2),
                  ]),
                );
              }),
          ]),
        ),

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 13, color: Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Expanded(child: Text('Win = 3 pts  ·  Loss = 0 pts  ·  Tiebreaker order: Points → H2H → Set Diff → Game Diff',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
          ]),
        ),
      ]),
    );
  }

  Widget _legend(String key, String desc) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: _indigo.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
        child: Text(key, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _indigo))),
    const SizedBox(width: 4),
    Text(desc, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
  ]);

  Widget _hCell(String t, {int flex = 1, Color? color}) => Expanded(flex: flex,
      child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: color ?? const Color(0xFF6B7280))));
  Widget _dCell(String t, {Color? color, bool bold = false}) => Expanded(
      child: Text(t, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? const Color(0xFF374151))));
  Widget _ptsCell(int pts, {int flex = 1}) => Expanded(flex: flex,
      child: Container(margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _indigo.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
          child: Text('$pts pts', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _indigo))));
}


class _KnockoutStandings extends StatelessWidget {
  final EventGroup group;
  const _KnockoutStandings({required this.group});
  static const _indigo = Color(0xFF4F46E5);

  List<Map<String, dynamic>> _compute() {
 
    final reached = <String, int>{ for (final p in group.participants) p.id: 0 };

    for (final f in group.fixtures) {
      if (f.winnerId.isEmpty) continue;
    
      final wCurrent = reached[f.winnerId] ?? 0;
      if (f.roundIndex + 1 > wCurrent) reached[f.winnerId] = f.roundIndex + 1;
    
      final loserId = f.winnerId == f.teamAId ? f.teamBId : f.teamAId;
      if (loserId.isNotEmpty) {
        final lCurrent = reached[loserId] ?? 0;
        if (f.roundIndex > lCurrent) reached[loserId] = f.roundIndex;
      }
    }

    final orderedRounds = group.orderedRounds; 

    final rows = group.participants.map((p) {
      final r     = reached[p.id] ?? 0;
      final isCh  = group.fixtures.any((f) => f.isCompleted && f.round == 'Final' && f.winnerId == p.id);
     
      String progress;
      if (isCh) {
        progress = '🏆 Champion';
      } else if (r <= 0) {
        progress = 'Round 1';
      } else if (r <= orderedRounds.length) {
        progress = orderedRounds[r - 1];
      } else {
        progress = orderedRounds.last;
      }
      return {'id': p.id, 'name': p.name, 'reached': r, 'isChamp': isCh, 'progress': progress};
    }).toList();

    rows.sort((a, b) {
      if ((b['isChamp'] as bool) && !(a['isChamp'] as bool)) return 1;
      if ((a['isChamp'] as bool) && !(b['isChamp'] as bool)) return -1;
      return (b['reached'] as int).compareTo(a['reached'] as int);
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _compute();
    if (rows.isEmpty) return _empty('No participants in this category.');
    return SingleChildScrollView(padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(children: [
          // Header
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(children: [
                const SizedBox(width: 36, child: Text('#', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                const Expanded(flex: 5, child: Text('Team / Player', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                const Expanded(flex: 3, child: Text('Progress', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
              ])),
          // Rows
          ...rows.asMap().entries.map((e) {
            final row   = e.value; final idx = e.key;
            final isChamp  = row['isChamp'] as bool;
            final progress = row['progress'] as String;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                  color: isChamp ? const Color(0xFFFFFBEB) : idx.isEven ? Colors.white : Colors.grey.shade50,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  borderRadius: idx == rows.length - 1 ? const BorderRadius.vertical(bottom: Radius.circular(12)) : BorderRadius.zero),
              child: Row(children: [
                SizedBox(width: 36, child: Center(child: isChamp
                    ? const Text('🏆', style: TextStyle(fontSize: 16))
                    : Text('${idx+1}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)))),
                Expanded(flex: 5, child: Text(row['name'] as String,
                    style: TextStyle(fontSize: 13, fontWeight: isChamp ? FontWeight.bold : FontWeight.w500, color: const Color(0xFF111827)))),
                Expanded(flex: 3, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: isChamp ? const Color(0xFFF59E0B).withOpacity(0.12) : _indigo.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(progress, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: isChamp ? 11 : 10, fontWeight: FontWeight.w700,
                          color: isChamp ? const Color(0xFFF59E0B) : _indigo)),
                )),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED MICRO WIDGETS + HELPERS
// ══════════════════════════════════════════════════════════════
class _FormatBadge extends StatelessWidget {
  final String label; final Color? color;
  const _FormatBadge({required this.label, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: (color ?? const Color(0xFF4F46E5)).withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color ?? const Color(0xFF4F46E5))),
  );
}

class _StatusPill extends StatelessWidget {
  final String label; final Color color;
  const _StatusPill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

Widget _FormLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))));

Widget _empty(String msg) => Center(child: Padding(padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(fontSize: 14, color: Colors.grey.shade400), textAlign: TextAlign.center),
    ])));

T? _firstOrNull<T>(Iterable<T> iter) { final it = iter.iterator; return it.moveNext() ? it.current : null; }


String _fmtDate(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}-${p[1]}-${p[0]}';
  } catch (_) { return iso; }
}


String _fmt12hr(String t) {
  if (t.isEmpty) return '';
  try {
    final p = t.split(':');
    int h = int.parse(p[0]);
    final m = p[1];
    final ap = h >= 12 ? 'PM' : 'AM';
    if (h == 0) h = 12; else if (h > 12) h -= 12;
    return '${h.toString().padLeft(2, '0')}:$m $ap';
  } catch (_) { return t; }
}