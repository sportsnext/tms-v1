// lib/features/admin/tournaments/presentation/screens/tournament_view_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/features/admin/tournaments/data/models/tournament_model.dart';
import '../../data/services/tournament_service.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'dart:io';
import 'package:file_picker/file_picker.dart';

class _PadelScoringEngine {
  // ── Set-level: determine set winner ──────────────────────────
  // setIndex 0/1 = normal set, setIndex 2 = super tiebreak
  // Returns 'A', 'B', or null (ongoing)
  static String? setWinner(int gA, int gB, int setIndex) {
    if (setIndex >= 2) {
      // 🔥 FIX: treat like deciding set (simple winner)
      if (gA > gB) return 'A';
      if (gB > gA) return 'B';
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
  static String? matchWinner(
    List<int> gA,
    List<int> gB,
    String idA,
    String idB,
  ) {
    int sA = 0, sB = 0;
    for (int i = 0; i < gA.length; i++) {
      final w = setWinner(gA[i], gB[i], i);
      if (w == 'A') sA++;
      if (w == 'B') sB++;
    }
    // 🔥 If super TB exists → decide from last set
    if (gA.length >= 3) {
      final last = setWinner(gA[2], gB[2], 2);
      if (last == 'A') return idA;
      if (last == 'B') return idB;
    }

    // Normal best of 3
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
  final bool isUser;

  const TournamentViewScreen({
    super.key,
    required this.tournament,
    this.onBack,
    required this.onUpdate,
    this.isUser = false,
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
  String? originalBanner;

  @override
  void initState() {
    super.initState();
    print("IS USER: ${widget.isUser}");
    _t = widget.tournament.copyWith(banner: widget.tournament.banner ?? '');

    originalBanner = _t.banner;
    _fetchLatest(); // 🔥 ADD THIS

    print("TOTAL GROUPS: ${_t.eventGroups.length}");

    for (var g in _t.eventGroups) {
      print("GROUP: ${g.eventName}");
      print("MATCHES: ${g.fixtures.length}");
    }

    _tabCtrl = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLatest() async {
    try {
      final updated = await TournamentService.getTournamentById(_t.id);

      if (!mounted) return;

      final fresh = TournamentModel.fromJson(updated['data']);

      // 🔥 PRESERVE OLD GROUPS IF NEW IS EMPTY
      if (fresh.eventGroups.isEmpty) {
        print("⚠️ Fresh groups empty — but still updating UI");
      }

      final updatedGroups = fresh.eventGroups.map((g) async {
        print("🔥 FETCHING GROUP ID: ${g.id}");
        print("🔥 STAGE ID: ${g.stageId}");
        if (g.format == "custom") {
          final res = await TournamentService.getManualMatches(
            g.id?.toString() ?? "",
          );

          final List data = res['data'] ?? [];

          print("🔥 API DATA LENGTH: ${data.length}");

          final manualFixtures = data.map<FixtureModel>((m) {
            final status = (m["status"] ?? "scheduled").toString();

            final homeScore = m["home_score"] ?? 0;
            final awayScore = m["away_score"] ?? 0;

            return FixtureModel(
              id: m["id"].toString(),
              eventGroupId: g.id,

              round: (m["round"] ?? "").isEmpty
                  ? "Manual"
                  : m["round"], // not needed for custom
              matchNumber: 0,

              teamAId: m["team_a_id"]?.toString() ?? "",
              teamAName: m["team_a_name"] ?? "TBD",

              teamBId: m["team_b_id"]?.toString() ?? "",
              teamBName: m["team_b_name"] ?? "TBD",

              date: m["match_date"] ?? "",
              time: m["match_time"] ?? "",

              court: m["court"] ?? "",

              status: status,

              // 🔥 REQUIRED FIELDS FIX
              sets: const [],
              setsWonA: m["home_score"] ?? 0,
              setsWonB: m["away_score"] ?? 0,
              winnerId: m["winner_team_id"]?.toString() ?? "",
              isLive: status == "live",
            );
          }).toList();

          print("✅ CUSTOM FIXTURES: ${manualFixtures.length}");

          return g.copyWith(
            fixtures: manualFixtures,
            manualFixtures: manualFixtures, // 🔥 ADD THIS LINE
          );
        }

        if (g.format == "round_robin" && g.id != null) {
          print("🔥 RR + MANUAL LOAD");

          // =========================
          // 1️⃣ NORMAL RR FIXTURES
          // =========================
          final rrRes = await TournamentService.getFixtures(
            _t.id.toString(),
            g.id.toString(),
          );

          final List rrData = rrRes['data'] ?? [];

          final rrFixtures = rrData.map<FixtureModel>((m) {
            final status = (m["status"] ?? "scheduled").toString();

            final teamAId = m["team_a_id"]?.toString() ?? "";
            final teamBId = m["team_b_id"]?.toString() ?? "";

            String getName(String id) {
              final p = g.participants.firstWhere(
                (e) => e.id.toString() == id,
                orElse: () =>
                    ParticipantModel(id: '', name: 'Team $id', playerNames: []),
              );
              return p.name;
            }

            return FixtureModel(
              id: m["id"].toString(),
              eventGroupId: g.id,

              round: m["round"] ?? "",
              matchNumber: m["match_number"] ?? 0,

              teamAId: teamAId,
              teamAName: getName(teamAId),

              teamBId: teamBId,
              teamBName: getName(teamBId),

              date: m["match_date"] ?? "",
              time: m["match_time"] ?? "",
              court: m["court"] ?? "",

              status: status,
              sets: const [],
              setsWonA: m["home_score"] ?? 0,
              setsWonB: m["away_score"] ?? 0,

              winnerId: m["winner_team_id"]?.toString() ?? "",
              isLive: status == "live",
            );
          }).toList();

          // =========================
          // 2️⃣ RR MANUAL MATCHES
          // =========================
          final manualRes = await TournamentService.getManualMatches(
            g.id.toString(),
          );

          final List manualData = manualRes['data'] ?? [];

          final manualFixtures = manualData.map<FixtureModel>((m) {
            print("🔥 RAW MANUAL: $m"); // ✅ DEBUG

            return FixtureModel(
              id: m["id"].toString(),
              eventGroupId: g.id,

              round: (m["round"] ?? "").toString(),
              matchNumber: m["match_order"] ?? 0,

              // ✅ FIX (IMPORTANT)
              teamAId: m["team_a_id"]?.toString() ?? "",
              teamAName: (m["team_a_name"] ?? "TBD").toString(),

              teamBId: m["team_b_id"]?.toString() ?? "",
              teamBName: (m["team_b_name"] ?? "TBD").toString(),

              // ✅ FIX (IMPORTANT)
              date: (m["match_date"] ?? "").toString(),
              time: (m["match_time"] ?? "").toString(),
              court: (m["court"] ?? "").toString(),

              status: (m["status"] ?? "scheduled").toString(),

              sets: const [],
              setsWonA: 0,
              setsWonB: 0,

              winnerId: m["winner_team_id"]?.toString() ?? "",
              isLive: m["status"] == "live",
            );
          }).toList();

          print("✅ MANUAL FIXTURES AFTER MAP:");
          for (var f in manualFixtures) {
            print("👉 ${f.id} | ${f.teamAName} vs ${f.teamBName}");
          }

          print("RR: ${rrFixtures.length}");
          print("MANUAL: ${manualFixtures.length}");

          final combinedFixtures = [...rrFixtures, ...manualFixtures];

          // 🔥 DO NOT OVERRIDE IF EMPTY
          if (combinedFixtures.isEmpty) {
            print("⚠️ SKIPPING EMPTY FIXTURE OVERRIDE");
            return g; // keep old data
          }

          return g.copyWith(
            fixtures: combinedFixtures,
            manualFixtures: manualFixtures,
          );
        }

        return g;
      }).toList();

      final resolvedGroups = await Future.wait(updatedGroups);

      setState(() {
        _t = fresh.copyWith(
          banner: fresh.banner,
          fixtureImage: fresh.fixtureImage,
          eventGroups: resolvedGroups,
        );
      });

      print("AFTER FETCH: ${_t.fixtureImage}");

      // widget.onUpdate(_t);
    } catch (e) {
      print("REFRESH ERROR: $e");
    }
  }

  Future<void> _completeMatch(String matchId) async {
    try {
      await TournamentService.completeMatch(matchId);

      await _fetchLatest(); // ✅ use same logic
    } catch (e) {
      print("Complete Match Error: $e");
    }
  }

  // ── Update fixture and propagate knockout winner ─────────────
  Future<void> _updateFixture(FixtureModel updated) async {
    try {
      await TournamentService.updateManualMatch(
        updated.id, // ✅ MANUAL MATCH ID
        {
          "team_a_id": int.tryParse(updated.teamAId ?? ""),
          "team_b_id": int.tryParse(updated.teamBId ?? ""),

          "team_a_name": updated.teamAName,
          "team_b_name": updated.teamBName,

          "match_date": updated.date,
          "match_time": updated.time,
          "court": updated.court,

          "status": updated.status,

          "winner_team_id":
              updated.winnerId != null && updated.winnerId!.isNotEmpty
              ? int.tryParse(updated.winnerId!)
              : null,
        },
      );

      await _fetchLatest();
    } catch (e) {
      print("❌ UPDATE ERROR: $e");
    }
  }

  Future<void> _simulateRefresh() async {
    setState(() => _refreshing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _refreshing = false);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refreshed'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _OverviewTab(tournament: _t),
                _ParticipantsTab(tournament: _t),
                _FixtureTab(
                  tournament: _t,
                  onUpdateFixture: _updateFixture,
                  onCompleteMatch: _completeMatch,
                  isUser: widget.isUser,
                ),
                _ScheduleTab(tournament: _t, onUpdateFixture: _updateFixture),
                _CalendarTab(tournament: _t),
                _LiveTab(
                  tournament: _t,
                  onUpdateFixture: _updateFixture,
                  isUser: widget.isUser,
                ),
                _StandingsTab(tournament: _t, isUser: widget.isUser),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1E1B4B), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      _HeaderPill(_t.statusLabel, _t.statusColor),
                      if (_t.hasLive) ...[
                        const SizedBox(width: 6),
                        const _HeaderPill('LIVE', Color(0xFF16A34A)),
                      ],
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _t.effectiveVenue,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _fetchLatest,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildTabBar() => Container(
    color: const Color(0xFF1E1B4B),
    child: TabBar(
      controller: _tabCtrl,
      isScrollable: true,
      indicatorColor: Colors.white,
      indicatorWeight: 3,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withOpacity(0.45),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      tabs: const [
        Tab(text: 'OVERVIEW'),
        Tab(text: 'PARTICIPANTS'),
        Tab(text: 'FIXTURE'),
        Tab(text: 'SCHEDULE'),
        Tab(text: 'CALENDAR'),
        Tab(text: 'LIVE'),
        Tab(text: 'STANDINGS'),
      ],
    ),
  );
}

class _HeaderPill extends StatelessWidget {
  final String label;
  final Color color;
  const _HeaderPill(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.25),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
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
  const _CategorySelector({
    required this.groups,
    required this.selectedIdx,
    required this.onChanged,
    this.trailing = const [],
  });
  static const _indigo = Color(0xFF4F46E5);
  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final idx = selectedIdx.clamp(0, groups.length - 1);
    final sel = groups[idx];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Text(
            'Category:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _indigo.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _indigo.withOpacity(0.25)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: idx,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: _indigo,
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _indigo,
                ),
                items: groups
                    .asMap()
                    .entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FormatBadge(label: sel.formatLabel, color: sel.formatColor),
          if (sel.gender.isNotEmpty) ...[
            const SizedBox(width: 6),
            _FormatBadge(label: sel.gender, color: const Color(0xFF0891B2)),
          ],
          const Spacer(),
          ...trailing,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// OVERVIEW TAB
// ══════════════════════════════════════════════════════════════
class _OverviewTab extends StatefulWidget {
  final TournamentModel tournament;
  const _OverviewTab({required this.tournament});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  List<dynamic> _sponsors = [];

  @override
  void initState() {
    super.initState();
    _loadSponsors();
  }

  Future<void> _loadSponsors() async {
    final res = await TournamentService.getSponsors(widget.tournament.id);

    if (!mounted) return;

    setState(() {
      _sponsors = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;

    print("BANNER: ${t.banner}");
    print("LIST SCREEN → BANNER: ${t.banner}");
    print("OVERVIEW → FINAL BANNER URL: ${t.banner}");

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔥 BANNER (NO CHANGE)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                /// ✅ YOUR ORIGINAL BANNER (UNCHANGED)
                (t.banner?.isNotEmpty ?? false)
                    ? Builder(
                        builder: (context) {
                          final viewId = 'banner-${t.id}';

                          final bannerUrl =
                              (t.banner?.startsWith('http') ?? false)
                              ? t.banner!
                              : "https://dev.sports-next.com/storage/${t.banner!.replaceAll("\\", "/")}";

                          // ignore: undefined_prefixed_name
                          ui.platformViewRegistry.registerViewFactory(viewId, (
                            int viewId,
                          ) {
                            final img = html.ImageElement()
                              ..src = bannerUrl
                              ..style.width = '100%'
                              ..style.height = '200px'
                              ..style.objectFit = 'cover';

                            return img;
                          });

                          return SizedBox(
                            height: 200,
                            width: double.infinity,
                            child: HtmlElementView(viewType: viewId),
                          );
                        },
                      )
                    : Container(
                        height: 200,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E2235), Color(0xFF4F46E5)],
                          ),
                        ),
                      ),

                /// ✅ DARK OVERLAY (NEW)
                Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.black.withOpacity(0.35),
                ),

                /// ✅ TEXT ON BANNER (NEW)
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(height: 6),

                        Text(
                          t.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          "${t.venueName ?? 'No venue'}${t.startDate != null && t.startDate!.isNotEmpty ? ' • ${t.startDate}' : ''}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          /// 🔥 INFO SECTION (NO CHANGE)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Color(0xFF4F46E5),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Tournament Information',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey.shade200, height: 1),
                      const SizedBox(height: 12),

                      /// DESCRIPTION (TOP)
                      if (t.description.isNotEmpty)
                        Text(
                          t.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),

                      const SizedBox(height: 12),

                      /// 🔥 HORIZONTAL META ROW
                      Wrap(
                        spacing: 20,
                        runSpacing: 10,
                        children: [
                          /// 🔥 FIXED DATE ROW
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _InfoPill(
                                Icons.calendar_today,
                                t.startDate ?? "-",
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_right_alt,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                t.endDate ?? "-",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),

                          _InfoPill(
                            Icons.location_on,
                            t.venueName ?? "No venue",
                          ),
                          _InfoPill(
                            Icons.people,
                            "${t.totalParticipants} Participants",
                          ),
                          _InfoPill(
                            Icons.sports_tennis,
                            "${t.totalMatches} Matches",
                          ),
                          _InfoPill(
                            Icons.category,
                            "${t.eventGroups.length} Categories",
                          ),

                          _InfoPill(
                            Icons.circle,
                            t.statusLabel,
                            color: t.statusColor,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Divider(color: Colors.grey.shade200),

                      const SizedBox(height: 12),

                      /// 🔥 CONTACT SECTION
                      const Text(
                        "Contact",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 8),

                      if ((t.contactName ?? '').isNotEmpty)
                        _InfoPill(Icons.person, t.contactName!),

                      if ((t.contactEmail ?? '').isNotEmpty)
                        _InfoPill(Icons.email, t.contactEmail!),

                      if ((t.contactPhone ?? '').isNotEmpty)
                        _InfoPill(Icons.phone, t.contactPhone!),
                      const SizedBox(height: 10),

                      if (t.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          t.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              /// 🔥 SIDE STATS (UPDATED COUNT)
              Container(
                width: 220,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _StatRow('Total Matches', '${t.totalMatches}'),
                    _StatRow('Completed', '${t.completedMatches}'),
                    _StatRow('Participants', '${t.totalParticipants}'),
                    _StatRow('Categories', '${t.eventGroups.length}'),
                    _StatRow('Sponsors', '${_sponsors.length}'),
                    _StatRow('Status', t.statusLabel, color: t.statusColor),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// 🔥 NEW SPONSOR UI
          if (_sponsors.isNotEmpty) ...[
            const Text(
              'Sponsors',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: _sponsors.map((s) {
                return SizedBox(
                  width: 150,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Builder(
                      builder: (context) {
                        final viewId = 'sponsor-img-${s['id']}';

                        // ignore: undefined_prefixed_name
                        ui.platformViewRegistry.registerViewFactory(viewId, (
                          int viewId,
                        ) {
                          final container = html.AnchorElement()
                            ..href =
                                (s['url'] != null &&
                                    s['url'].toString().isNotEmpty)
                                ? s['url']
                                : '#'
                            ..target = '_blank'
                            ..style.display = 'block'
                            ..style.width = '100%'
                            ..style.height = '100%';

                          final img = html.ImageElement()
                            ..src =
                                "https://dev.sports-next.com/storage/${s['logo'].toString().replaceAll("\\", "/")}"
                            ..style.width = '100%'
                            ..style.height = '100%'
                            ..style.objectFit = 'cover';

                          container.append(img);

                          return container;
                        });

                        return HtmlElementView(viewType: viewId);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoPill(this.icon, this.label, {this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color ?? Colors.grey.shade500),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(fontSize: 13, color: color ?? const Color(0xFF374151)),
      ),
    ],
  );
}

class _StatRow extends StatelessWidget {
  final String title;
  final String value;
  final Color? color;

  const _StatRow(this.title, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SponsorTile extends StatelessWidget {
  final SponsorModel sponsor;
  const _SponsorTile({required this.sponsor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sponsor.logoBase64.isNotEmpty)
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                sponsor.logoBase64.startsWith('http')
                    ? sponsor.logoBase64
                    : "https://dev.sports-next.com/storage/${sponsor.logoBase64.replaceAll("\\", "/")}",
                fit: BoxFit.contain,
              ),
            ),
          )
        else
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.business_rounded,
              size: 16,
              color: Color(0xFF4F46E5),
            ),
          ),
        Text(
          sponsor.name,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ],
    ),
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

    final teams = g.participants.map((p) => p.name).toList();

    print("===== DEBUG START =====");

    print("FIXTURE IDS:");
    for (var f in g.fixtures.whereType<FixtureModel>()) {
      print("A: ${f.teamAId} (${f.teamAName})");
      print("B: ${f.teamBId} (${f.teamBName})");
    }

    print("===== DEBUG END =====");

    String _getPlayers(String teamName, dynamic g) {
      // 1. Try from participants (NEW tournaments)
      try {
        final p = g.participants.firstWhere(
          (p) => p.name.trim() == teamName.trim(),
        );

        if (p.playerNames.isNotEmpty) {
          return p.playerNames.join(' / ');
        }
      } catch (e) {}

      // 2. Fallback for old tournaments (split name)
      if (teamName.contains('&')) {
        return teamName.split('&').map((e) => e.trim()).join(' / ');
      }

      // 3. Final fallback
      return '-';
    }

    return Column(
      children: [
        _CategorySelector(
          groups: groups,
          selectedIdx: _selIdx,
          onChanged: (i) => setState(() => _selIdx = i),
          trailing: [
            _FormatBadge(
              label: '${g.participants.length} registered',
              color: Colors.grey.shade500,
            ),
          ],
        ),
        Expanded(
          child: teams.isEmpty
              ? _empty('No participants for ${g.displayName}.')
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Teams: ${teams.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Type: ${g.participantType}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _indigo.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _indigo.withOpacity(0.15)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                '#',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Team / Player',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'Players',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                'Seed',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...teams.asMap().entries.map((e) {
                        final teamName = e.value;
                        final i = e.key;

                        // 🔥 find teamId from fixtures
                        String teamId = '';

                        for (var f in g.fixtures) {
                          if (f is! FixtureModel) continue;

                          if (f.teamAName == teamName) {
                            teamId = f.teamAId;
                            break;
                          }
                          if (f.teamBName == teamName) {
                            teamId = f.teamBId;
                            break;
                          }
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 36,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _indigo.withOpacity(0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _indigo,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  teamName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  _getPlayers(teamName, g),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 60),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FIXTURE TAB — knockout bracket with winner propagation
// Only winner names appear in next-round slots (TBD until decided)
// ══════════════════════════════════════════════════════════════
class _FixtureTab extends StatefulWidget {
  final TournamentModel tournament;
  final void Function(FixtureModel) onUpdateFixture;
  final Function(String) onCompleteMatch;
  final bool isUser;

  const _FixtureTab({
    required this.tournament,
    required this.onUpdateFixture,
    required this.onCompleteMatch,
    required this.isUser,
  });
  @override
  State<_FixtureTab> createState() => _FixtureTabState();
}

class _FixtureTabState extends State<_FixtureTab> {
  int _selIdx = 0;
  Uint8List? _imageBytes;
  bool _removeNetworkImage = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null && result.files.single.bytes != null) {
      print("IMAGE BYTES RECEIVED");

      setState(() {
        _imageBytes = result.files.single.bytes!;
      });

      final parent = context
          .findAncestorStateOfType<_TournamentViewScreenState>();

      if (parent != null && _imageBytes != null) {
        await TournamentService.uploadFixtureImage(
          parent._t.id.toString(),
          _imageBytes!,
          "fixture.png",
        );

        await parent._fetchLatest(); // 🔥 refresh UI
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.tournament.eventGroups;

    if (groups.isEmpty) return _empty('No fixtures generated yet.');
    if (_selIdx >= groups.length) _selIdx = 0;

    final g = groups[_selIdx];

    // 🔥 ADD HERE (EXACT PLACE)
    print("Participants count: ${g.participants.length}");
    print("Participants names: ${g.participants.map((p) => p.name)}");

    print("FIXTURES RAW: ${g.fixtures}");
    print("FIXTURE COUNT: ${g.fixtures.length}");

    for (var f in g.fixtures) {
      print("TYPE: ${f.runtimeType}");
    }

    final grouped = <String, List<FixtureModel>>{};

    for (var f in g.fixtures) {
      final round = (f.round.isEmpty) ? "Manual" : f.round;
      grouped.putIfAbsent(round, () => []).add(f);
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _CategorySelector(
            groups: groups,
            selectedIdx: _selIdx,
            onChanged: (i) => setState(() => _selIdx = i),
          ),
          (g.format != 'custom' && g.fixtures.isEmpty)
              ? _empty(
                  'No fixtures for ${g.displayName}. Generate from Create screen.',
                )
              : g.format == 'knockout'
              ? _KnockoutBracket(
                  group: g,
                  onUpdateFixture: widget.onUpdateFixture,
                  onCompleteMatch: widget.onCompleteMatch,
                  isUser: widget.isUser,
                )
              : g.format == 'round_robin'
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ ROUND ROBIN TABLE
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT SIDE (FIXTURES)
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),

                            // ✅ IMPORTANT: WRAPPED WITH COLUMN
                            child: Column(
                              children: [
                                // 🔒 FIXED AREA (RR + BUTTONS)
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.55,
                                  child: Column(
                                    children: [
                                      // ✅ FIXTURES
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: _RoundRobinTable(
                                            group: g.copyWith(
                                              fixtures: g.fixtures
                                                  .where(
                                                    (f) =>
                                                        f.round ==
                                                        "Round Robin",
                                                  )
                                                  .toList(),
                                            ),
                                            onUpdateFixture:
                                                widget.onUpdateFixture,
                                            onCompleteMatch:
                                                widget.onCompleteMatch,
                                            isUser: widget.isUser,
                                          ),
                                        ),
                                      ),

                                      // ✅ BUTTONS
                                      if (!widget.isUser)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: _pickImage,
                                                icon: const Icon(Icons.image),
                                                label: const Text(
                                                  "Upload Image",
                                                ),
                                              ),

                                              const SizedBox(width: 12),

                                              if (_imageBytes != null ||
                                                  (widget
                                                              .tournament
                                                              .fixtureImage !=
                                                          null &&
                                                      !_removeNetworkImage))
                                                ElevatedButton.icon(
                                                  onPressed: () {
                                                    setState(() {
                                                      _imageBytes = null;
                                                      _removeNetworkImage =
                                                          true;
                                                    });
                                                  },
                                                  icon: const Icon(
                                                    Icons.delete,
                                                  ),
                                                  label: const Text(
                                                    "Remove Image",
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                ),

                                              const SizedBox(width: 12),

                                              ElevatedButton(
                                                onPressed: () {},
                                                child: const Text(
                                                  "🧩 Create RR Bracket",
                                                ),
                                              ),

                                              const SizedBox(width: 16),

                                              ElevatedButton(
                                                onPressed: () {},
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text(
                                                  "🗑 Delete RR Bracket",
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                (_imageBytes != null ||
                                        (widget.tournament.fixtureImage !=
                                                null &&
                                            !_removeNetworkImage))
                                    ? Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          10,
                                          8,
                                          0,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: _imageBytes != null
                                              ? Image.memory(
                                                  _imageBytes!,
                                                  fit: BoxFit.cover,
                                                )
                                              : Builder(
                                                  builder: (context) {
                                                    final t = widget.tournament;

                                                    if (t.fixtureImage ==
                                                            null ||
                                                        t
                                                            .fixtureImage!
                                                            .isEmpty) {
                                                      return const SizedBox();
                                                    }

                                                    final imageUrl =
                                                        t.fixtureImage!;

                                                    final viewId =
                                                        'fixture-${t.id}-${imageUrl.hashCode}-${DateTime.now().millisecondsSinceEpoch}';

                                                    // ignore: undefined_prefixed_name
                                                    ui.platformViewRegistry
                                                        .registerViewFactory(
                                                          viewId,
                                                          (int viewId) {
                                                            final img = html.ImageElement()
                                                              ..src =
                                                                  "$imageUrl?v=${DateTime.now().millisecondsSinceEpoch}"
                                                              ..style.width =
                                                                  '100%'
                                                              ..style.height =
                                                                  'auto'
                                                              ..style.objectFit =
                                                                  'contain';

                                                            return img;
                                                          },
                                                        );

                                                    return SizedBox(
                                                      height:
                                                          400, // or 350–500 as you like
                                                      width: double.infinity,
                                                      child:
                                                          SingleChildScrollView(
                                                            child:
                                                                HtmlElementView(
                                                                  viewType:
                                                                      viewId,
                                                                ),
                                                          ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      )
                                    : const SizedBox(),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        // RIGHT SIDE (STANDINGS)
                        _RRStandingsSide(group: g, isUser: widget.isUser),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // 🔥 RR MANUAL BRACKET
                    if (g.manualFixtures.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 450,
                          child: _KnockoutBracket(
                            group: g,
                            fixturesOverride: g.manualFixtures,

                            // 🔥 FIX START
                            onUpdateFixture: (fixture) async {
                              final parent = context
                                  .findAncestorStateOfType<
                                    _TournamentViewScreenState
                                  >();

                              await TournamentService.updateManualMatch(
                                fixture.id,
                                {
                                  "team_a_id": int.tryParse(
                                    fixture.teamAId ?? "",
                                  ),
                                  "team_b_id": int.tryParse(
                                    fixture.teamBId ?? "",
                                  ),

                                  "team_a_name": fixture.teamAName,
                                  "team_b_name": fixture.teamBName,

                                  "match_date": fixture.date,
                                  "match_time": fixture.time,
                                  "court": fixture.court,

                                  "status": fixture.status,

                                  "winner_team_id":
                                      fixture.winnerId != null &&
                                          fixture.winnerId!.isNotEmpty
                                      ? int.tryParse(fixture.winnerId!)
                                      : null,
                                },
                              );

                              // 🔥 LOCAL UI UPDATE (THIS FIXES YOUR ISSUE)
                              if (parent != null) {
                                parent.setState(() {
                                  final groupIndex = parent._t.eventGroups
                                      .indexWhere((e) => e.id == g.id);

                                  if (groupIndex != -1) {
                                    final group =
                                        parent._t.eventGroups[groupIndex];

                                    final updatedList = group.manualFixtures.map((
                                      f,
                                    ) {
                                      if (f.id == fixture.id) {
                                        return fixture; // ✅ DIRECT UPDATED DATA
                                      }
                                      return f;
                                    }).toList();

                                    parent._t.eventGroups[groupIndex] = group
                                        .copyWith(manualFixtures: updatedList);
                                  }
                                });

                                await parent._fetchLatest();
                              }
                            },

                            // 🔥 FIX END
                            onCompleteMatch: widget.onCompleteMatch,
                            isUser: widget.isUser,
                          ),
                        ),
                      ),
                  ],
                )
              : g.format == 'custom'
              ? Column(
                  children: [
                    // 🔴 BUTTON ROW
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!widget.isUser) ...[
                          ElevatedButton(
                            onPressed: () async {
                              final parent = context
                                  .findAncestorStateOfType<
                                    _TournamentViewScreenState
                                  >();

                              if (parent == null) return;

                              final confirm = await showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Delete Brackets"),
                                  content: const Text("Delete all brackets?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm != true) return;

                              await TournamentService.deleteAllManualMatches(
                                g.id.toString(),
                              );
                              await parent._fetchLatest();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text("🗑 Delete Bracket"),
                          ),

                          const SizedBox(width: 10),

                          ElevatedButton(
                            onPressed: () async {
                              int? selectedSize;

                              final parent = context
                                  .findAncestorStateOfType<
                                    _TournamentViewScreenState
                                  >();

                              await showDialog(
                                context: context,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: const Text("Create Bracket"),
                                    content: DropdownButtonFormField<int>(
                                      hint: const Text("Select Round"),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 16,
                                          child: Text("Pre-Quarter (16)"),
                                        ),
                                        DropdownMenuItem(
                                          value: 8,
                                          child: Text("Quarter-Final (8)"),
                                        ),
                                        DropdownMenuItem(
                                          value: 4,
                                          child: Text("Semi-Final (4)"),
                                        ),
                                        DropdownMenuItem(
                                          value: 2,
                                          child: Text("Final (2)"),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        selectedSize = value;
                                      },
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext),
                                        child: const Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          if (selectedSize == null ||
                                              parent == null)
                                            return;

                                          await TournamentService.createBracket(
                                            g.id.toString(),
                                            selectedSize!,
                                            parent._t.id.toString(),
                                          );

                                          Navigator.pop(dialogContext);
                                          await parent._fetchLatest();
                                        },
                                        child: const Text("Create"),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: const Text("🧩 Create Bracket"),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 🔥 BRACKET VIEW (OUTSIDE ROW)
                    g.manualFixtures.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Text(
                              "No brackets created",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : _KnockoutBracket(
                            group: g,
                            fixturesOverride: g.manualFixtures, // 🔥 IMPORTANT
                            onUpdateFixture: widget.onUpdateFixture,
                            onCompleteMatch: widget.onCompleteMatch,
                            isUser: widget.isUser,
                          ),
                  ],
                )
              : const SizedBox(),
        ],
      ),
    );
  }
}

class _RRStandingsSide extends StatefulWidget {
  final EventGroup group;
  final bool isUser;

  const _RRStandingsSide({required this.group, required this.isUser});

  @override
  State<_RRStandingsSide> createState() => _RRStandingsSideState();
}

class _RRStandingsSideState extends State<_RRStandingsSide> {
  double width = 350;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: MediaQuery.of(context).size.height * 0.48,
      child: Row(
        children: [
          // DRAG HANDLE
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              final screenWidth = MediaQuery.of(context).size.width;

              setState(() {
                width = (width - details.delta.dx).clamp(
                  300.0,
                  screenWidth * 0.85,
                );
              });
            },
            child: Container(
              width: 14,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),

          // STANDINGS PANEL
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Colors.grey.shade300)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: _RoundRobinStandings(
                group: widget.group,
                isUser: widget.isUser,
                hideH2H: true,
                hideProgress: true,
                hideFooter: true,
                hideLegend: true,
                isCompact: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleMatchCard extends StatelessWidget {
  final FixtureModel fixture;
  final EventGroup group;
  final Function(FixtureModel) onUpdateFixture;
  final bool isUser;

  const _SimpleMatchCard({
    required this.fixture,
    required this.group,
    required this.onUpdateFixture,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 🔵 LEFT SIDE (Format tag)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text("Custom", style: TextStyle(fontSize: 12)),
          ),

          // 🔥 CENTER (Teams VS)
          Expanded(
            child: Column(
              children: [
                Text(
                  fixture.teamAName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text("VS", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  fixture.teamBName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // 🔴 RIGHT SIDE (Time + Status + Court)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (fixture.time.isNotEmpty)
                Text(
                  fixture.time,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

              if (fixture.date.isNotEmpty)
                Text(
                  fixture.date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),

              const SizedBox(height: 4),

              // 🔥 STATUS BADGE
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: fixture.statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  fixture.statusLabel,
                  style: TextStyle(
                    color: fixture.statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              if (fixture.court.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Court: ${fixture.court}",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

              const SizedBox(height: 6),

              // ✏️ EDIT BUTTON
              // ✏️ EDIT + 🗑️ DELETE
              if (!isUser)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✏️ EDIT
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => _FixtureEditDialog(
                            fixture: fixture,
                            participants: group.participants,
                            tournamentId: int.parse(
                              context
                                  .findAncestorStateOfType<
                                    _TournamentViewScreenState
                                  >()!
                                  ._t
                                  .id
                                  .toString(),
                            ),
                            format: 'custom',
                            eventGroupId: group.id.toString(),
                            onRefresh: () async {
                              final parentState = context
                                  .findAncestorStateOfType<
                                    _TournamentViewScreenState
                                  >();

                              if (parentState == null) return;

                              await parentState._fetchLatest();
                            },
                          ),
                        );
                      },
                      child: const Icon(Icons.edit, size: 18),
                    ),

                    const SizedBox(width: 10),

                    // 🗑️ DELETE
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Delete Match"),
                            content: const Text(
                              "Are you sure you want to delete this match?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Delete"),
                              ),
                            ],
                          ),
                        );

                        if (confirm != true) return;

                        try {
                          await TournamentService.deleteManualMatch(fixture.id);

                          final parent = context
                              .findAncestorStateOfType<
                                _TournamentViewScreenState
                              >();

                          if (parent != null) {
                            await parent._fetchLatest(); // 🔥 refresh
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Delete failed")),
                          );
                        }
                      },
                      child: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
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
}

// ── Knockout Bracket ─────────────────────────────────────────
class _KnockoutBracket extends StatelessWidget {
  final EventGroup group;
  final void Function(FixtureModel) onUpdateFixture;
  final Function(String) onCompleteMatch;
  final List<FixtureModel>? fixturesOverride;
  final bool isUser;
  static final ValueNotifier<Map<String, String>> stageNamesNotifier =
      ValueNotifier({});

  const _KnockoutBracket({
    required this.group,
    required this.onUpdateFixture,
    required this.onCompleteMatch,
    this.fixturesOverride,
    required this.isUser,
  });

  void _editStageName(BuildContext context, String roundName) {
    final controller = TextEditingController(
      text: stageNamesNotifier.value[roundName] ?? roundName,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Stage Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final updated = Map<String, String>.from(
                stageNamesNotifier.value,
              );

              updated[roundName] = controller.text;

              stageNamesNotifier.value = updated;

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final byRound = <String, List<FixtureModel>>{};

    final source = fixturesOverride ?? group.fixtures;

    for (var f in source) {
      byRound.putIfAbsent(f.round, () => []).add(f);
    }

    final rounds = byRound.keys.toList()
      ..sort((a, b) {
        int getOrder(String r) {
          if (r == 'Final') return 3;
          if (r == 'Semi-Final') return 2;
          if (r == 'Quarter-Final') return 1;

          final match = RegExp(r'Round (\\d+)').firstMatch(r);
          if (match != null) {
            return int.parse(match.group(1)!);
          }

          return 0;
        }

        return getOrder(a).compareTo(getOrder(b));
      });

    print("======== FIXTURE DEBUG ========");
    print("ROUNDS: $rounds");

    byRound.forEach((key, value) {
      print("ROUND: $key -> MATCHES: ${value.length}");
    });
    print("================================");
    const cardW = 220.0;
    const cardH = 120.0;
    const extraH = 50.0;
    const cardGap = 50.0;
    const connW = 52.0;
    final slotH = cardH + cardGap;
    final firstRound = rounds.isNotEmpty
        ? (byRound[rounds.first] ?? [])
        : <FixtureModel>[];
    final totalH = (firstRound.length * slotH).clamp(slotH, 9999.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
          child: Row(
            children: [
              const Icon(
                Icons.account_tree_rounded,
                size: 15,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(width: 6),
              Text(
                '${group.participants.length} participants  ·  Single Elimination',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF16A34A).withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Winners Selected Manually',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          height: 500,
          child: SingleChildScrollView(
            // ✅ vertical scroll
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, // ✅ horizontal scroll
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rounds.asMap().entries.map((colEntry) {
                    final roundName = colEntry.value;
                    final matches = byRound[roundName] ?? [];
                    print("👉 ROUND: $roundName");
                    for (var m in matches) {
                      print(
                        "MATCH -> A: ${m.teamAName} (${m.teamAId}) vs B: ${m.teamBName} (${m.teamBId})",
                      );
                    }
                    final isLastColumn = colEntry.key == rounds.length - 1;
                    final slotsPerMatch = matches.isEmpty
                        ? 1
                        : (firstRound.length / matches.length).ceil();

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: cardW,
                          height: totalH + 36,
                          child: Column(
                            children: [
                              Container(
                                width: cardW,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 12,
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4F46E5,
                                  ).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child:
                                    ValueListenableBuilder<Map<String, String>>(
                                      valueListenable: stageNamesNotifier,
                                      builder: (context, stageNames, _) {
                                        final displayName =
                                            stageNames[roundName] ?? roundName;

                                        return Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF4F46E5),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () => _editStageName(
                                                context,
                                                roundName,
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                size: 14,
                                                color: Color(0xFF4F46E5),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                              ),

                              Expanded(
                                child: Stack(
                                  children: matches.asMap().entries.map((me) {
                                    final totalItemH = cardH + extraH;

                                    final slotBandH = slotsPerMatch * slotH;
                                    final topOffset =
                                        me.key * slotBandH +
                                        (slotBandH - totalItemH) / 2;

                                    final latest = me.value;

                                    print("MATCH ID: ${me.value.id}");
                                    print("OLD COURT: ${me.value.court}");
                                    print("LATEST COURT: ${latest.court}");

                                    return Positioned(
                                      top: topOffset,
                                      left: 0,
                                      right: 0,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // 🔥 TIME ABOVE CARD
                                          if (latest.time.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 6,
                                                bottom: 4,
                                              ),
                                              child: SizedBox(
                                                width: cardW,
                                                child: Text(
                                                  _fmt12hr(latest.time),
                                                  softWrap: true,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 2,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                            ),

                                          _BracketCard(
                                            fixture: latest,
                                            width: cardW,
                                            height: cardH,
                                            participants: group.participants,
                                            onCompleteMatch: onCompleteMatch,
                                            onEdit: isUser
                                                ? null
                                                : () => showDialog(
                                                    context: context,
                                                    builder: (_) {
                                                      print("🧠 EDIT CLICKED");
                                                      print(
                                                        "👉 MATCH ID: ${latest.id}",
                                                      );
                                                      print(
                                                        "👉 GROUP ID: ${group.id}",
                                                      );
                                                      final allTeams =
                                                          <
                                                            String,
                                                            ParticipantModel
                                                          >{};

                                                      for (var fx
                                                          in (fixturesOverride ??
                                                              group.fixtures)) {
                                                        if (fx
                                                                .teamAName
                                                                .isNotEmpty &&
                                                            fx.teamAName !=
                                                                'TBD') {
                                                          allTeams[fx.teamAId] =
                                                              ParticipantModel(
                                                                id: fx.teamAId,
                                                                name: fx
                                                                    .teamAName,
                                                                playerNames: [],
                                                              );
                                                        }

                                                        if (fx
                                                                .teamBName
                                                                .isNotEmpty &&
                                                            fx.teamBName !=
                                                                'TBD') {
                                                          allTeams[fx.teamBId] =
                                                              ParticipantModel(
                                                                id: fx.teamBId,
                                                                name: fx
                                                                    .teamBName,
                                                                playerNames: [],
                                                              );
                                                        }
                                                      }

                                                      return _FixtureEditDialog(
                                                        fixture: latest,
                                                        participants: group
                                                            .participants, // ✅ FIXED
                                                        tournamentId: int.parse(
                                                          context
                                                              .findAncestorStateOfType<
                                                                _TournamentViewScreenState
                                                              >()!
                                                              ._t
                                                              .id
                                                              .toString(),
                                                        ),
                                                        format: group.format,
                                                        eventGroupId: group.id
                                                            .toString(),
                                                        onRefresh: () async {
                                                          final parentState = context
                                                              .findAncestorStateOfType<
                                                                _TournamentViewScreenState
                                                              >();

                                                          if (parentState ==
                                                              null)
                                                            return;

                                                          await parentState
                                                              ._fetchLatest(); // ✅ FIX
                                                        },
                                                      );
                                                    },
                                                  ),
                                          ),
                                          // 🔥 COURT BELOW CARD
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 6,
                                              top: 4,
                                            ),
                                            child: SizedBox(
                                              width:
                                                  cardW, // 🔥 IMPORTANT (same as bracket width)
                                              child: Text(
                                                latest.court,
                                                softWrap: true,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLastColumn)
                          SizedBox(
                            width: connW,
                            height: totalH + 36,
                            child: CustomPaint(
                              painter: _ConnectorPainter(
                                matchCount: matches.length,
                                slotsPerMatch: slotsPerMatch,
                                slotH: slotH,
                                cardH: cardH,
                              ),
                            ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final int matchCount, slotsPerMatch;
  final double slotH, cardH;
  const _ConnectorPainter({
    required this.matchCount,
    required this.slotsPerMatch,
    required this.slotH,
    required this.cardH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < matchCount; i++) {
      final slotBandH = slotsPerMatch * slotH;

      final topOffset = i * slotBandH + (slotBandH - cardH) / 2;

      const centerAdjust = 0.0; // 🔥 key fix

      final centerY = topOffset + (cardH / 2) + centerAdjust;

      final path = Path();

      const startX = 6.0;

      // Horizontal line from card
      path.moveTo(startX, centerY);
      path.lineTo(size.width / 2, centerY);

      if (i % 2 == 0 && i + 1 < matchCount) {
        final partnerTopOffset = (i + 1) * slotBandH + (slotBandH - cardH) / 2;

        final partnerY = partnerTopOffset + (cardH / 2) + centerAdjust;

        // Vertical connector
        path.moveTo(size.width / 2, centerY);
        path.lineTo(size.width / 2, partnerY);

        // Middle connection to next round
        final midY = (centerY + partnerY) / 2 - 4;

        final endX = size.width - 6;

        path.moveTo(size.width / 2, midY);
        path.lineTo(endX, midY);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter o) => false;
}

// ── Bracket Card ─────────────────────────────────────────────
class _BracketCard extends StatelessWidget {
  final FixtureModel fixture;
  final double width, height;
  final List<ParticipantModel> participants;
  final VoidCallback? onEdit;
  final Function(String) onCompleteMatch;

  const _BracketCard({
    required this.fixture,
    required this.width,
    required this.height,
    required this.participants,
    this.onEdit,
    required this.onCompleteMatch,
  });

  String cleanName(String name) {
    if (name.isEmpty || name == '-' || name == '—') return "BYE";
    return name;
  }

  String _playerNames(String teamId) {
    final p = _firstOrNull(participants.where((p) => p.id == teamId));
    return p?.playerNames.join(' / ') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final f = fixture;

    final isCompleted = f.status.toLowerCase() == "completed";
    final isLive = f.status.toLowerCase() == "live";
    final isScheduled = f.status.toLowerCase() == "scheduled";

    final isByeMatch = f.teamAName == "BYE" || f.teamBName == "BYE";

    print("FINAL CHECK -> round: ${f.round}, winner: ${f.winnerId}");
    print("TIME: ${fixture.time}, COURT: ${fixture.court}");
    print("FINAL DEBUG -> status: ${f.status}, winner: ${f.winnerId}");

    final aWins =
        isCompleted &&
        f.winnerId.isNotEmpty &&
        f.teamAId.isNotEmpty &&
        f.winnerId.trim() == f.teamAId.trim();
    final bWins =
        isCompleted &&
        f.winnerId.isNotEmpty &&
        f.teamBId.isNotEmpty &&
        f.winnerId.trim() == f.teamBId.trim();

    final aTBD = f.teamAName.isEmpty || f.teamAName == 'TBD';
    final bTBD = f.teamBName.isEmpty || f.teamBName == 'TBD';

    final isFinal = f.round.toLowerCase() == 'final';

    final isChampion = isCompleted && isFinal && f.winnerId.isNotEmpty;

    const gold = Color(0xFFF59E0B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🏆 Champion Badge (OUTSIDE CARD)
        if (isChampion)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFFFD700)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: gold.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.emoji_events, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  "WINNER",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

        // 🎯 MAIN CARD
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: isChampion
                ? const LinearGradient(
                    colors: [Color(0xFFFFF7CC), Color(0xFFFFE8A3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isChampion ? null : Colors.white,

            borderRadius: BorderRadius.circular(10),

            border: Border.all(
              color: isChampion
                  ? gold
                  : isLive
                  ? const Color(0xFF16A34A)
                  : (aWins || bWins)
                  ? const Color(0xFF4F46E5).withOpacity(0.4)
                  : Colors.grey.shade300,
              width: isChampion ? 3 : (isLive ? 2 : 1),
            ),

            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6),
            ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Side A ──
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: 6, right: 10),
                      decoration: BoxDecoration(
                        color: isChampion && aWins
                            ? const Color(0xFFFFF3C4)
                            : aWins
                            ? const Color(0xFF4F46E5).withOpacity(0.12)
                            : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(9),
                        ),
                        border: (aWins && !isChampion)
                            ? const Border(
                                left: BorderSide(
                                  color: Color(0xFF4F46E5),
                                  width: 3,
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          if (isChampion && aWins)
                            const Icon(
                              Icons.emoji_events,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            )
                          else if (aWins)
                            const Icon(
                              Icons.emoji_events_rounded,
                              size: 12,
                              color: Color(0xFFF59E0B),
                            )
                          else
                            const SizedBox(width: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  aTBD ? 'TBD' : cleanName(f.teamAName),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: aWins
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: aTBD
                                        ? Colors.grey.shade400
                                        : isChampion && aWins
                                        ? gold
                                        : aWins
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFF374151),
                                  ),
                                ),
                                if (!aTBD && _playerNames(f.teamAId).isNotEmpty)
                                  Text(
                                    _playerNames(f.teamAId),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if ((f.setsWonA > 0 ||
                                  f.setsWonB > 0 ||
                                  aWins ||
                                  bWins) &&
                              !aTBD)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                '${f.setsWonA}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: aWins
                                      ? const Color(0xFF4F46E5)
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  Divider(height: 1, color: Colors.grey.shade200),

                  // ── Side B ──
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isChampion && bWins
                            ? const Color(0xFFFFF3C4)
                            : bWins
                            ? const Color(0xFF4F46E5).withOpacity(0.12)
                            : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(9),
                        ),
                        border: (bWins && !isChampion)
                            ? const Border(
                                left: BorderSide(
                                  color: Color(0xFF4F46E5),
                                  width: 3,
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          if (isChampion && bWins)
                            const Icon(
                              Icons.emoji_events,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            )
                          else if (bWins)
                            const Icon(
                              Icons.emoji_events_rounded,
                              size: 12,
                              color: Color(0xFFF59E0B),
                            )
                          else
                            const SizedBox(width: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  bTBD ? 'TBD' : cleanName(f.teamBName),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: bWins
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: bTBD
                                        ? Colors.grey.shade400
                                        : isChampion && bWins
                                        ? gold
                                        : bWins
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFF374151),
                                  ),
                                ),
                                if (!bTBD && _playerNames(f.teamBId).isNotEmpty)
                                  Text(
                                    _playerNames(f.teamBId),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if ((f.setsWonA > 0 ||
                                  f.setsWonB > 0 ||
                                  aWins ||
                                  bWins) &&
                              !bTBD)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                '${f.setsWonB}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: bWins
                                      ? const Color(0xFF4F46E5)
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ✏️ Edit Button
              if (onEdit != null)
                Positioned(
                  top: 3,
                  right: 3,
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 11,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ),

              // 🔴 LIVE
              if (isLive)
                Positioned(
                  bottom: 3,
                  right: 8,
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 5,
                        height: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SizedBox(width: 3),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Round Robin Table ─────────────────────────────────────────
class _RoundRobinTable extends StatelessWidget {
  final EventGroup group;
  final void Function(FixtureModel) onUpdateFixture;
  final Function(String) onCompleteMatch;
  final bool isUser;

  const _RoundRobinTable({
    required this.group,
    required this.onUpdateFixture,
    required this.onCompleteMatch,
    required this.isUser,
  });

  String _players(String id) {
    final p = _firstOrNull(group.participants.where((p) => p.id == id));
    return p?.playerNames.join(' / ') ?? '';
  }

  @override
  Widget build(BuildContext context) => Column(
    children: group.fixtures.map((f) {
      if (f is! FixtureModel) return const SizedBox(); // 🔥 ONLY ADD THIS

      final aWins =
          f.winnerId.isNotEmpty &&
          f.teamAId.isNotEmpty &&
          f.winnerId.trim() == f.teamAId.trim();
      final bWins =
          f.winnerId.isNotEmpty &&
          f.teamBId.isNotEmpty &&
          f.winnerId.trim() == f.teamBId.trim();

      final isByeMatch = f.teamAName == "BYE" || f.teamBName == "BYE";

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: f.status == 'live'
              ? const Color(0xFFF0FDF4)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: f.status == 'live'
                ? const Color(0xFF16A34A)
                : f.status == 'cancelled'
                ? Colors.red
                : (!isByeMatch && (aWins || bWins))
                ? const Color(0xFF4F46E5).withOpacity(0.4)
                : Colors.grey.shade300,

            width: f.status == 'live' ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            _FormatBadge(label: f.round),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  // 🔵 TEAM A
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (f.status == "completed" &&
                                f.winnerId.isNotEmpty)
                              if (f.winnerId == f.teamAId)
                                const Icon(
                                  Icons.emoji_events,
                                  color: Colors.amber,
                                  size: 16,
                                )
                              else
                                Container(
                                  margin: const EdgeInsets.only(right: 5),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red,
                                  ),
                                ),

                            const SizedBox(width: 4),

                            Flexible(
                              child: Text(
                                f.teamAName,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_players(f.teamAId).isNotEmpty)
                          Text(
                            _players(f.teamAId),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // 🔥 SCORE
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      f.status == "scheduled"
                          ? "0 - 0"
                          : (f.setsWonA > 0 || f.setsWonB > 0)
                          ? '${f.setsWonA} – ${f.setsWonB}'
                          : "0 - 0",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: f.isCompleted
                            ? const Color(0xFF4F46E5)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),

                  // 🔵 TEAM B
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                f.teamBName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            const SizedBox(width: 4),

                            if (f.status == "completed" &&
                                f.winnerId.isNotEmpty)
                              if (f.winnerId == f.teamBId)
                                const Icon(
                                  Icons.emoji_events,
                                  color: Colors.amber,
                                  size: 16,
                                )
                              else
                                Container(
                                  margin: const EdgeInsets.only(left: 5),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red,
                                  ),
                                ),
                          ],
                        ),

                        if (_players(f.teamBId).isNotEmpty)
                          Text(
                            _players(f.teamBId),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Formatted Time (e.g., 2:30 PM)
                if (f.time.isNotEmpty)
                  Text(
                    _fmt12hr(f.time),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),

                const SizedBox(height: 2),

                // 2. Formatted Date (e.g., 31-03-2026)
                if (f.date.isNotEmpty)
                  Text(
                    _fmtDate(f.date),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),

                // 3. Court info
                if (f.court.isNotEmpty)
                  Text(
                    "Court: ${f.court}",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            _StatusPill(label: f.statusLabel, color: f.statusColor),
            const SizedBox(width: 8),

            if (!isUser)
              GestureDetector(
                onTap: () {
                  final allTeams = <String, ParticipantModel>{};

                  for (var fx in group.fixtures) {
                    if (fx.teamAName.isNotEmpty && fx.teamAName != 'TBD') {
                      allTeams[fx.teamAName] = ParticipantModel(
                        id: fx.teamAId,
                        name: fx.teamAName,
                        playerNames: [],
                      );
                    }

                    if (fx.teamBName.isNotEmpty && fx.teamBName != 'TBD') {
                      allTeams[fx.teamBName] = ParticipantModel(
                        id: fx.teamBId,
                        name: fx.teamBName,
                        playerNames: [],
                      );
                    }
                  }
                  showDialog(
                    context: context,
                    builder: (_) => _FixtureEditDialog(
                      fixture: f,
                      participants: allTeams.values.toList(), // ✅ FIXED
                      tournamentId: int.parse(
                        context
                            .findAncestorStateOfType<
                              _TournamentViewScreenState
                            >()!
                            ._t
                            .id
                            .toString(),
                      ),
                      format: group.format,
                      eventGroupId: group.id.toString(),
                      onRefresh: () async {
                        final parentState = context
                            .findAncestorStateOfType<
                              _TournamentViewScreenState
                            >();

                        if (parentState == null) return;

                        await parentState._fetchLatest(); // ✅ FIX
                      },
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 13,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
          ],
        ),
      );
    }).toList(),
  );
}

// ══════════════════════════════════════════════════════════════
// FIXTURE EDIT DIALOG
// ══════════════════════════════════════════════════════════════
class _FixtureEditDialog extends StatefulWidget {
  final FixtureModel fixture;
  final Future<void> Function() onRefresh;
  final List<ParticipantModel> participants;
  final int tournamentId;
  final String format;
  final String eventGroupId; // 🔥 ADD THIS

  const _FixtureEditDialog({
    required this.fixture,
    required this.participants,
    required this.onRefresh,
    required this.tournamentId,
    required this.format,
    required this.eventGroupId, // 🔥 ADD THIS
  });

  @override
  State<_FixtureEditDialog> createState() => _FixtureEditDialogState();
}

class _FixtureEditDialogState extends State<_FixtureEditDialog> {
  late FixtureModel _f;
  final _liveCtrl = TextEditingController();
  final _aCtrl = TextEditingController();
  final _bCtrl = TextEditingController();
  static const _indigo = Color(0xFF4F46E5);

  String? _selectedWinner;
  String _selectedStatus = "scheduled";

  DateTime? selectedDate;
  TimeOfDay? _selectedTime;

  String? _selectedCourt;
  String? _selectedDate;

  String selectedAId = '';
  String selectedAName = '';

  String selectedBId = '';
  String selectedBName = '';

  @override
  void initState() {
    super.initState();
    _f = widget.fixture;
    _selectedStatus = _f.status.toLowerCase();
    _liveCtrl.text = _f.liveStreamUrl;
    _aCtrl.text = _f.teamAName ?? '';
    _bCtrl.text = _f.teamBName ?? '';
    if (_f.winnerId == _f.teamAId) {
      _selectedWinner = "A";
    } else if (_f.winnerId == _f.teamBId) {
      _selectedWinner = "B";
    } else {
      _selectedWinner = null;
    }

    // Date
    if (widget.fixture.date.isNotEmpty) {
      selectedDate = DateTime.tryParse(widget.fixture.date);
    }

    // Time (SAFE)
    if (widget.fixture.time.isNotEmpty) {
      final parts = widget.fixture.time.split(":");
      if (parts.length >= 2) {
        _selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    // Court
    _selectedCourt = widget.fixture.court ?? '';

    _selectedCourt = (widget.fixture.court ?? '').isNotEmpty
        ? widget.fixture.court
        : null;
    _selectedDate = widget.fixture.date;
  }

  @override
  void dispose() {
    _liveCtrl.dispose();
    _aCtrl.dispose();
    _bCtrl.dispose();
    super.dispose();
  }

  void _swapTeamsIfNeeded(String newTeam, bool isTeamA) {
    if (newTeam == 'BYE') return; // allow BYE freely

    if (isTeamA) {
      final oldA = _aCtrl.text;

      if (newTeam != oldA) {
        setState(() {
          _aCtrl.text = newTeam;
          final selected = widget.participants.firstWhere(
            (p) => p.name == newTeam,
            orElse: () => widget.participants.first,
          );

          _f = _f.copyWith(
            teamAId: selected.id, // ✅ ADD THIS
            teamAName: selected.name,
            winnerId: "",
          );
          _selectedWinner = null; // 🔥 RESET WINNER
        });
      }
    } else {
      final oldB = _bCtrl.text;

      if (newTeam != oldB) {
        setState(() {
          _bCtrl.text = newTeam;
          final selected = widget.participants.firstWhere(
            (p) => p.name == newTeam,
          );

          _f = _f.copyWith(
            teamBId: selected.id, // ✅ ADD THIS
            teamBName: selected.name,
            winnerId: "",
          );

          _selectedWinner = null; // 🔥 RESET WINNER
        });
      }
    }
  }

  String _playersOf(String name) {
    final p = _firstOrNull(widget.participants.where((p) => p.name == name));
    return p?.playerNames.join(' / ') ?? '';
  }

  int getWinsA(List sets) {
    int wins = 0;
    for (var s in sets) {
      if (s.scoreA > s.scoreB) wins++;
    }
    return wins;
  }

  int getWinsB(List sets) {
    int wins = 0;
    for (var s in sets) {
      if (s.scoreB > s.scoreA) wins++;
    }
    return wins;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_calendar_rounded, color: _indigo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Edit Fixture — ${_f.round}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(height: 20, color: Colors.grey.shade200),

              const Text(
                'Participants',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _participantField('Team / Player A', _aCtrl, (v) {
                      if (v == _bCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Same team not allowed"),
                          ),
                        );
                        return;
                      }
                      _swapTeamsIfNeeded(v, true); // 🔥 ADD THIS

                      // setState(() => _f = _f.copyWith(teamAName: v));
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'vs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _participantField('Team / Player B', _bCtrl, (v) {
                      if (v == _aCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Same team not allowed"),
                          ),
                        );
                        return;
                      }
                      _swapTeamsIfNeeded(v, false); // 🔥 ADD THIS

                      // setState(() => _f = _f.copyWith(teamBName: v));
                    }),
                  ),
                ],
              ),
              if (widget.participants.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _playersOf(_aCtrl.text),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          _playersOf(_bCtrl.text),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(height: 20, color: Colors.grey.shade200),

              const Text(
                'Schedule',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('Date'),
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _f.date.isNotEmpty
                                  ? (DateTime.tryParse(_f.date) ??
                                        DateTime.now())
                                  : DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (d != null)
                              setState(() {
                                _selectedDate = d.toIso8601String().substring(
                                  0,
                                  10,
                                ); // 🔥 FIX
                                _f = _f.copyWith(date: _selectedDate);
                              });
                          },
                          child: _pickerBox(
                            _f.date.isEmpty ? 'Pick date' : _f.date,
                            Icons.calendar_today_outlined,
                            _f.date.isNotEmpty,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('Time'),
                        InkWell(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime ?? TimeOfDay.now(),
                            );

                            if (t != null) {
                              setState(() {
                                _selectedTime = t;
                                _f = _f.copyWith(
                                  time:
                                      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                                );
                              });
                            }
                          },
                          child: _pickerBox(
                            _f.time.isEmpty ? 'Pick time' : _f.time,
                            Icons.access_time_rounded,
                            _f.time.isNotEmpty,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FormLabel('Court / Venue'),
              DropdownButtonFormField<String>(
                value: TournamentSeeds.courts.contains(_f.court)
                    ? _f.court
                    : null,
                decoration: _inputDeco('Select court'),
                items: TournamentSeeds.courts
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedCourt = v; // 🔥 THIS FIX
                    _f = _f.copyWith(court: v ?? '');
                  });
                },
              ),
              Divider(height: 20, color: Colors.grey.shade200),
              _FormLabel('Status'),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: FixtureModel.statuses.map((s) {
                  final dummy = _f.copyWith(status: s);
                  final isSel = _selectedStatus == s;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStatus = s; // ✅ UI state
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSel ? dummy.statusColor : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSel
                              ? dummy.statusColor
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        dummy.statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSel ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (_selectedStatus == 'completed')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Builder(
                    builder: (context) {
                      final items = <DropdownMenuItem<String>>[];

                      // ✅ Team A
                      if (_f.teamAName.isNotEmpty &&
                          _f.teamAName != 'TBD' &&
                          _f.teamAName != 'BYE') {
                        items.add(
                          DropdownMenuItem(
                            value: "A",
                            child: Text(_f.teamAName),
                          ),
                        );
                      }

                      // ✅ Team B (FIXED)
                      if (_f.teamBName.isNotEmpty &&
                          _f.teamBName != 'TBD' &&
                          _f.teamBName != 'BYE') {
                        items.add(
                          DropdownMenuItem(
                            value: "B",
                            child: Text(_f.teamBName),
                          ),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        value: items.any((e) => e.value == _selectedWinner)
                            ? _selectedWinner
                            : null,

                        decoration: _inputDeco('Select Winner'),

                        items: items,

                        onChanged: (v) {
                          setState(() {
                            _selectedWinner = v; // A or B
                          });
                        },
                      );
                    },
                  ),
                ),

              Divider(height: 20, color: Colors.grey.shade200),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _indigo,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          onPressed: () async {
            try {
              // 🚨 VALIDATION
              if (_selectedStatus == "completed" && _selectedWinner == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "⚠️ Please select a winner before marking completed",
                    ),
                  ),
                );
                return;
              }

              if (widget.fixture.status == 'completed') {
                ScaffoldMessenger.of(context).clearSnackBars();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Already completed match cannot be edited"),
                    duration: Duration(seconds: 2),
                  ),
                );

                return;
              }

              // ❌ same team validation
              if (_aCtrl.text == _bCtrl.text && _aCtrl.text != "BYE") {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Same team not allowed")),
                );
                return;
              }

              // 🔥 STEP 1: get all fixtures from parent
              final parentState = context
                  .findAncestorStateOfType<_TournamentViewScreenState>();
              final allFixtures = parentState?._t.allFixtures ?? [];

              // 🔥 STEP 2: proper swap logic
              final oldA = widget.fixture.teamAName;
              final oldB = widget.fixture.teamBName;

              final newA = _aCtrl.text.isEmpty ? "BYE" : _aCtrl.text;
              final newB = _bCtrl.text.isEmpty ? "BYE" : _bCtrl.text;

              /*
              for (var fx in allFixtures) {
                if (fx.id == widget.fixture.id) continue;

                String a = fx.teamAName;
                String b = fx.teamBName;

                bool updated = false;

                // swap newA
                if (a == newA) {
                  a = oldA;
                  updated = true;
                } else if (b == newA) {
                  b = oldA;
                  updated = true;
                }

                // swap newB
                if (a == newB) {
                  a = oldB;
                  updated = true;
                } else if (b == newB) {
                  b = oldB;
                  updated = true;
                }

                // 🔥 THIS WAS MISSING (CRITICAL)
                if (widget.format == "round_robin") {
                  await TournamentService.updateMatch(
                    matchId: fx.id.toString(),
                    teamAId: null,
                    teamBId: null,
                  );
                } else {
                  await TournamentService.updateManualMatch(fx.id.toString(), {
                    "team_a_name": a,
                    "team_b_name": b,
                  });
                }
              }
              */

              _f = _f.copyWith(teamAName: newA, teamBName: newB);

              String? formattedTime;

              if (_selectedTime != null) {
                final h = _selectedTime!.hour.toString().padLeft(2, '0');
                final m = _selectedTime!.minute.toString().padLeft(2, '0');
                formattedTime = "$h:$m:00";
              } else {
                formattedTime = _f.time;
              }

              if (widget.format == 'custom') {
                if (_f.id.startsWith("temp")) {
                  // ➕ CREATE
                  await TournamentService.createManualMatch({
                    "tournament_id": widget.tournamentId,
                    "event_group_id": widget.eventGroupId,

                    "team_a_id": _f.teamAId,
                    "team_a_name": _f.teamAName,

                    "team_b_id": _f.teamBId,
                    "team_b_name": _f.teamBName,

                    "match_date": _selectedDate ?? _f.date,
                    "match_time": formattedTime,
                    "court": _selectedCourt ?? _f.court,

                    "status": _selectedStatus,
                  });
                } else {
                  // ✏️ UPDATE
                  await TournamentService.updateManualMatch(_f.id.toString(), {
                    "team_a_id": _f.teamAId,
                    "team_a_name": _f.teamAName,

                    "team_b_id": _f.teamBId,
                    "team_b_name": _f.teamBName,

                    "match_date": _selectedDate ?? _f.date,
                    "match_time": formattedTime,
                    "court": _selectedCourt ?? _f.court,
                    "status": _selectedStatus,

                    "winner_team_id": (_selectedWinner == "A")
                        ? _f.teamAId
                        : (_selectedWinner == "B")
                        ? _f.teamBId
                        : null,

                    "winner_team_name": (_selectedWinner == "A")
                        ? _f.teamAName
                        : (_selectedWinner == "B")
                        ? _f.teamBName
                        : null,
                  });
                }

                await widget.onRefresh();

                if (!mounted) return;

                Navigator.pop(context);
                return;
              } else {
                final isRoundRobin =
                    widget.fixture.round?.toLowerCase().trim() == "round robin";

                if (isRoundRobin) {
                  print("🔥 SAVE CLICKED");
                  print("👉 MATCH ID: ${widget.fixture.id}");
                  print("👉 FORMAT: ${widget.format}");
                  print("👉 TEAM A: ${_f.teamAId} (${_f.teamAName})");
                  print("👉 TEAM B: ${_f.teamBId} (${_f.teamBName})");
                  print("👉 DATE: ${_selectedDate ?? _f.date}");
                  print("👉 TIME: $formattedTime");
                  print("👉 COURT: ${_selectedCourt ?? _f.court}");
                  print("👉 STATUS: $_selectedStatus");

                  // ✅ RR → matches table
                  print("🚀 CALLING updateMatch (RR)");
                  await TournamentService.updateMatch(
                    matchId: widget.fixture.id.toString(),
                    teamAId: _f.teamAId,
                    teamBId: _f.teamBId,
                    date: _selectedDate ?? _f.date,
                    time: formattedTime,
                    court: _selectedCourt ?? _f.court,
                    status: _selectedStatus,
                    winner_team_id: (_selectedStatus == "completed")
                        ? (_selectedWinner == "A"
                              ? _f.teamAId
                              : _selectedWinner == "B"
                              ? _f.teamBId
                              : null)
                        : null,
                    winner_team_name: (_selectedStatus == "completed")
                        ? (_selectedWinner == "A"
                              ? _f.teamAName
                              : _selectedWinner == "B"
                              ? _f.teamBName
                              : null)
                        : null,
                  );
                } else {
                  // ✅ KO + CUSTOM
                  print("🚀 CALLING updateManualMatch (KO)");
                  await TournamentService.updateManualMatch(
                    widget.fixture.id.toString(),
                    {
                      "team_a_id": _f.teamAId,
                      "team_a_name": _f.teamAName,

                      "team_b_id": _f.teamBId,
                      "team_b_name": _f.teamBName,

                      "match_date": _selectedDate ?? _f.date,
                      "match_time": formattedTime,
                      "court": _selectedCourt ?? _f.court,

                      "status": _selectedStatus,

                      "winner_team_id": (_selectedStatus == "completed")
                          ? (_selectedWinner == "A"
                                ? _f.teamAId
                                : _selectedWinner == "B"
                                ? _f.teamBId
                                : null)
                          : null,

                      "winner_team_name": (_selectedStatus == "completed")
                          ? (_selectedWinner == "A"
                                ? _f.teamAName
                                : _selectedWinner == "B"
                                ? _f.teamBName
                                : null)
                          : null,
                    },
                  );
                }
              }

              if (widget.format != 'round_robin' &&
                  _selectedStatus == 'completed') {
                if (_selectedWinner == null &&
                    _f.teamAName != "BYE" &&
                    _f.teamBName != "BYE") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Select winner")),
                  );
                  return;
                }
              }

              final isScheduled = _f.status.toLowerCase() == 'scheduled';

              // ==============================
              // 🔥 WINNER SELECTION (FINAL FIX)
              // ==============================
              String? winnerName;
              String? winnerId;

              // ✅ NORMAL WINNER
              if (_selectedWinner == "A") {
                winnerName = _f.teamAName;
                winnerId = _f.teamAId;
              } else if (_selectedWinner == "B") {
                winnerName = _f.teamBName;
                winnerId = _f.teamBId;
              }

              // ==============================
              // ❌ BLOCK INVALID COMPLETION
              // ==============================

              print("WINNER DEBUG -> ${_selectedWinner}");

              // ✅ UPDATE STATUS FIRST
              _f = _f.copyWith(status: _selectedStatus);

              if (_selectedStatus == 'completed') {
                if (_selectedWinner == null &&
                    _f.teamAName != "BYE" &&
                    _f.teamBName != "BYE") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Select winner")),
                  );
                  return;
                }
              }

              if (_f.status != "completed") {
                _f = _f.copyWith(winnerId: "");
              }

              print("WINNER DEBUG -> ${_selectedWinner}");
              print("WINNER NAME -> $winnerName");
              print("WINNER ID -> $winnerId");

              String? finalWinnerId;

              // ❌ DO NOT send winner if no selection
              if (_selectedWinner == "A") {
                finalWinnerId = _f.teamAId;
              } else if (_selectedWinner == "B") {
                finalWinnerId = _f.teamBId;
              } else {
                finalWinnerId = null; // 🔥 IMPORTANT
              }

              if (!_f.id.toString().startsWith('temp')) {
                // ✅ ADD THIS BLOCK HERE
                if (widget.format == "round_robin" &&
                    _selectedStatus == "completed" &&
                    widget.fixture.status != "live") {
                  final homeScore = getWinsA(_f.sets);
                  final awayScore = getWinsB(_f.sets);

                  await TournamentService.submitResult(
                    fixtureId: _f.id.toString(),
                    homeScore: homeScore,
                    awayScore: awayScore,
                  );
                }
              }

              await widget.onRefresh();
              print("🔄 REFRESH CALLED");

              if (!mounted) return;

              print("📦 DIALOG CLOSED");
              Navigator.pop(context); // ✅ ONLY ONCE
            } catch (e) {
              print("Update Match Error: $e");

              final msg = e.toString();

              print("ERROR RAW: $msg");

              if (msg.contains("venue")) {
                if (widget.format == 'round_robin') {
                  // ✅ IGNORE VENUE CONFLICT FOR RR
                  Navigator.pop(context);
                  widget.onRefresh();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Round Robin allows flexible scheduling."),
                      backgroundColor: Colors.orange,
                    ),
                  );

                  return;
                }

                // ❌ KNOCKOUT → BLOCK
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("⚠️ Court already booked (±2 hrs)"),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (msg.contains("team")) {
                if (widget.format == 'round_robin') {
                  // ✅ IGNORE ERROR BUT STILL UPDATE UI
                  Navigator.pop(context);
                  widget.onRefresh();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "This court will be available in 30 minutes.",
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );

                  return;
                }

                // ❌ KNOCKOUT → BLOCK
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("⚠️ Team has another match nearby"),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Update failed")));
              }
            }
          },

          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _pickerBox(String text, IconData icon, bool hasValue) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: hasValue ? const Color(0xFF111827) : Colors.grey.shade400,
          ),
        ),
      ],
    ),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
  );

  Widget _participantField(
    String label,
    TextEditingController ctrl,
    void Function(String) onChange,
  ) {
    final uniqueParticipants = widget.participants
        .fold<Map<String, ParticipantModel>>({}, (map, p) {
          map[p.name] = p;
          return map;
        })
        .values
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label),

        if (uniqueParticipants.isNotEmpty)
          DropdownButtonFormField<String>(
            value:
                (ctrl.text.isNotEmpty &&
                    uniqueParticipants.any((p) => p.name == ctrl.text))
                ? ctrl.text
                : null,

            decoration: _inputDeco('Select'),

            items: [
              if (widget.format != 'round_robin')
                const DropdownMenuItem(
                  value: 'TBD',
                  child: Text('TBD', style: TextStyle(fontSize: 12)),
                ),

              ...uniqueParticipants.map(
                (p) => DropdownMenuItem(
                  value: p.name,
                  child: Text(p.name, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],

            onChanged: (v) {
              if (v == null) return;

              ctrl.text = v;

              final participant = uniqueParticipants.firstWhere(
                (p) => p.name == v,
                orElse: () =>
                    ParticipantModel(id: '', name: '', playerNames: []),
              );

              setState(() {
                if (label.contains('A')) {
                  _f = _f.copyWith(
                    teamAName: v,
                    teamAId: participant.id,
                    winnerId: "", // 🔥 reset winner
                  );
                } else {
                  _f = _f.copyWith(
                    teamBName: v,
                    teamBId: participant.id,
                    winnerId: "", // 🔥 reset winner
                  );
                }

                _selectedWinner = null; // 🔥 IMPORTANT
              });

              onChange(v); // 🔥 keep this
            },
          )
        else
          TextField(
            controller: ctrl,
            onChanged: onChange,
            style: const TextStyle(fontSize: 12),
            decoration: _inputDeco('Name'),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SCHEDULE TAB — category dropdown + dark match cards
// ══════════════════════════════════════════════════════════════
class _ScheduleTab extends StatefulWidget {
  final TournamentModel tournament;
  final void Function(FixtureModel) onUpdateFixture;
  const _ScheduleTab({required this.tournament, required this.onUpdateFixture});
  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  int _selIdx = 0;
  @override
  Widget build(BuildContext context) {
    final groups = widget.tournament.eventGroups;

    if (groups.isEmpty) return _empty('No fixtures yet.');
    if (_selIdx >= groups.length) _selIdx = 0;

    final g = groups[_selIdx];

    // ✅ ADD THIS LINE EXACTLY HERE
    print("Participants count: ${g.participants.length}");

    print("FIXTURES RAW: ${g.fixtures}");
    print("FIXTURE COUNT: ${g.fixtures.length}");

    return Column(
      children: [
        _CategorySelector(
          groups: groups,
          selectedIdx: _selIdx,
          onChanged: (i) => setState(() => _selIdx = i),
        ),
        Expanded(
          child: g.fixtures.isEmpty
              ? _empty('No fixtures for ${g.displayName}.')
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: g.fixtures.length,
                  itemBuilder: (_, i) {
                    final f = g.fixtures[i];
                    return _ScheduleMatchCard(
                      fixture: f,
                      group: g,
                      isUser: context
                          .findAncestorStateOfType<
                            _TournamentViewScreenState
                          >()!
                          .widget
                          .isUser,
                      onEdit: () => showDialog(
                        context: context,
                        builder: (_) => _FixtureEditDialog(
                          fixture: f,
                          participants: g.participants,
                          tournamentId: int.parse(
                            context
                                .findAncestorStateOfType<
                                  _TournamentViewScreenState
                                >()!
                                ._t
                                .id
                                .toString(),
                          ),
                          format: g.format,
                          eventGroupId: g.id.toString(),
                          onRefresh: () async {
                            final parentState = context
                                .findAncestorStateOfType<
                                  _TournamentViewScreenState
                                >();

                            if (parentState == null) return;

                            await parentState
                                ._fetchLatest(); // 🔥 USE CENTRAL METHOD
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ScheduleMatchCard extends StatelessWidget {
  final FixtureModel fixture;
  final EventGroup group;
  final VoidCallback onEdit;
  final bool isUser;

  const _ScheduleMatchCard({
    required this.fixture,
    required this.group,
    required this.onEdit,
    required this.isUser,
  });
  String _players(String id) {
    final p = _firstOrNull(group.participants.where((p) => p.id == id));
    return p?.playerNames.join(' / ') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final f = fixture;

    final isByeA = f.teamAName == "BYE";
    final isByeB = f.teamBName == "BYE";

    final aWins = !isByeA && f.winnerId == f.teamAId && f.winnerId.isNotEmpty;
    final bWins = !isByeB && f.winnerId == f.teamBId && f.winnerId.isNotEmpty;

    String dateStr = f.date.isEmpty ? 'Unscheduled' : f.date, dayStr = '';
    if (f.date.isNotEmpty) {
      try {
        final d = DateTime.parse(f.date);
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        dateStr = '${d.day} ${months[d.month - 1]} ${d.year}';
        dayStr = days[d.weekday - 1];
      } catch (_) {}
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: f.status == 'live'
              ? const Color(0xFF16A34A)
              : Colors.transparent,
          width: f.status == 'live' ? 2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (dayStr.isNotEmpty)
                    Text(
                      dayStr,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      f.time.isEmpty ? '—' : f.time,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (f.court.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.sports_tennis,
                          size: 10,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            f.court,
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_outlined,
                          size: 12,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${f.round}  •  M${f.matchNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Team A
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (aWins && f.teamAName != "BYE")
                                  const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Color(0xFF16A34A),
                                  )
                                else if (bWins && f.teamBName != "BYE")
                                  const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Color(0xFFEF4444),
                                  ),
                                if (aWins || bWins) const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    f.teamAName,
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: aWins
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.75),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_players(f.teamAId).isNotEmpty)
                              Text(
                                _players(f.teamAId),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            if (f.teamAId.isNotEmpty && f.teamAName != 'TBD')
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _AvatarStack(
                                  group.participants
                                      .where((p) => p.id == f.teamAId)
                                      .expand(
                                        (p) => p.playerNames.isEmpty
                                            ? [p.name]
                                            : p.playerNames,
                                      )
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Score
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: (f.setsWonA > 0 || f.setsWonB > 0)
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4F46E5,
                                  ).withOpacity(0.20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${f.setsWonA}–${f.setsWonB}',
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'sets',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                    ...f.sets.map(
                                      (s) => Text(
                                        '${s.scoreA}–${s.scoreB}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.white.withOpacity(0.4),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Text(
                                'vs',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                      ),
                      // Team B
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    f.teamBName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: bWins
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.75),
                                    ),
                                  ),
                                ),
                                if (bWins) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Color(0xFF16A34A),
                                  ),
                                ] else if (aWins) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Color(0xFFEF4444),
                                  ),
                                ],
                              ],
                            ),
                            if (_players(f.teamBId).isNotEmpty)
                              Text(
                                _players(f.teamBId),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            if (f.teamBId.isNotEmpty && f.teamBName != 'TBD')
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _AvatarStack(
                                  group.participants
                                      .where((p) => p.id == f.teamBId)
                                      .expand(
                                        (p) => p.playerNames.isEmpty
                                            ? [p.name]
                                            : p.playerNames,
                                      )
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusPill(label: f.statusLabel, color: f.statusColor),
                const SizedBox(height: 8),

                if (!isUser)
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final List<String> names;
  const _AvatarStack(this.names);
  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF16A34A),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];
    final list = names.take(4).toList();
    return SizedBox(
      height: 22,
      width: list.length * 16.0 + 6,
      child: Stack(
        children: list
            .asMap()
            .entries
            .map(
              (e) => Positioned(
                left: e.key * 16.0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: colors[e.key % colors.length],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0D1B2A),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      e.value.isNotEmpty ? e.value[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CALENDAR TAB — CSV downloads as real file
// ══════════════════════════════════════════════════════════════
class _CalendarTab extends StatefulWidget {
  final TournamentModel tournament;
  const _CalendarTab({required this.tournament});
  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  bool _calView = false;
  String _filterVenue = '', _filterTeam = '', _filterStatus = '';

  List<FixtureModel> get _allFixtures => [
    for (final g in widget.tournament.eventGroups) ...g.fixtures,
  ];
  List<FixtureModel> get _filtered => _allFixtures.where((f) {
    if (_filterVenue.isNotEmpty && f.court != _filterVenue) return false;
    if (_filterStatus.isNotEmpty && f.status != _filterStatus) return false;
    if (_filterTeam.isNotEmpty &&
        !f.teamAName.toLowerCase().contains(_filterTeam.toLowerCase()) &&
        !f.teamBName.toLowerCase().contains(_filterTeam.toLowerCase()))
      return false;
    return true;
  }).toList();

  Map<String, List<FixtureModel>> get _byDate {
    final map = <String, List<FixtureModel>>{};

    for (final f in _filtered) {
      String key;

      if (f.date == null || f.date.toString().isEmpty) {
        key = 'Unscheduled';
      } else {
        try {
          final parsed = DateTime.parse(f.date.toString());
          key =
              "${parsed.year.toString().padLeft(4, '0')}-"
              "${parsed.month.toString().padLeft(2, '0')}-"
              "${parsed.day.toString().padLeft(2, '0')}";
        } catch (e) {
          key = 'Unscheduled';
        }
      }

      map.putIfAbsent(key, () => []).add(f);
    }

    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  // ── CSV export —
  void _exportCsv() {
    final sb = StringBuffer();
    sb.writeln(
      'Category,Round,Match No,Team A,Team B,Date,Time,Court,Status,Sets A,Sets B,Set Scores',
    );
    for (final g in widget.tournament.eventGroups) {
      for (final f in g.fixtures) {
        final setScores = f.sets
            .map((s) => '${s.scoreA}-${s.scoreB}')
            .join(' | ');
        sb.writeln(
          '"${g.displayName}","${f.round}","${f.matchNumber}","${f.teamAName}","${f.teamBName}",'
          '"${f.date}","${f.time}","${f.court}","${f.statusLabel}","${f.setsWonA}","${f.setsWonB}","$setScores"',
        );
      }
    }
    final csvContent = sb.toString();
    final fileName =
        '${widget.tournament.name.replaceAll(' ', '_')}_schedule.csv';

    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(_csvSnack('Downloaded: $fileName', const Color(0xFF16A34A)));
  }

  SnackBar _csvSnack(String msg, Color color) => SnackBar(
    content: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ],
    ),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 4),
  );

  @override
  Widget build(BuildContext context) {
    final venues = _allFixtures
        .map((f) => f.court)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToggleBtn(
                      icon: Icons.view_list_rounded,
                      label: 'List',
                      active: !_calView,
                      onTap: () => setState(() => _calView = false),
                    ),
                    _ToggleBtn(
                      icon: Icons.calendar_month_rounded,
                      label: 'Calendar',
                      active: _calView,
                      onTap: () => setState(() => _calView = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CalFilter(
                        label: 'Status',
                        value: _filterStatus,
                        options: ['', ...FixtureModel.statuses],
                        onChanged: (v) => setState(() => _filterStatus = v),
                      ),
                      const SizedBox(width: 8),
                      if (venues.isNotEmpty)
                        _CalFilter(
                          label: 'Venue',
                          value: _filterVenue,
                          options: ['', ...venues],
                          onChanged: (v) => setState(() => _filterVenue = v),
                        ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 160,
                        height: 36,
                        child: TextField(
                          onChanged: (v) => setState(() => _filterTeam = v),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Filter team...',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.file_download_rounded, size: 15),
                label: const Text(
                  'Export CSV',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Stats bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              Text(
                '${_filtered.length} of ${_allFixtures.length} matches',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 16),
              ...FixtureModel.statuses.map((s) {
                final col = s == 'live'
                    ? const Color(0xFF16A34A)
                    : s == 'completed'
                    ? const Color(0xFF374151)
                    : s == 'cancelled'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF6366F1);
                final count = _allFixtures.where((f) => f.status == s).length;
                if (count == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$count ${s[0].toUpperCase()}${s.substring(1)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        Expanded(
          child: _calView
              ? _CalCardCalendarView(byDate: _byDate)
              : _CalListView(byDate: _byDate),
        ),
      ],
    );
  }
}

class _CalCardCalendarView extends StatelessWidget {
  final Map<String, List<FixtureModel>> byDate;

  const _CalCardCalendarView({required this.byDate});

  @override
  Widget build(BuildContext context) {
    if (byDate.isEmpty) return _empty('No valid dates.');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: byDate.entries.map((e) {
          final matches = e.value;

          return Container(
            width: 260,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DATE
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    e.key,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // MATCHES
                ...matches.map((f) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: f.statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "${_fmt12hr(f.time)}: ${f.teamAName} vs ${f.teamBName}",
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CalListView extends StatelessWidget {
  final Map<String, List<FixtureModel>> byDate;
  const _CalListView({required this.byDate});

  @override
  Widget build(BuildContext context) {
    if (byDate.isEmpty) return _empty('No fixtures match filters.');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: byDate.entries
            .map(
              (e) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _fmtDate(e.key),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Divider(color: Colors.grey.shade200)),
                      ],
                    ),
                  ),

                  ...e.value.map((f) {
                    print("RAW STATUS => ${f.status}");
                    print("STATUS: ${f.status} | COLOR: ${f.statusColor}");

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: f.statusColor.withOpacity(
                          0.08,
                        ), // 🔥 LIGHT BG COLOR
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: f.statusColor, // 🔥 FULL COLOR (NO OPACITY)
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 48,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: f.statusColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          if (f.time.isNotEmpty)
                            SizedBox(
                              width: 42,
                              child: Text(
                                _fmt12hr(f.time),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_fmt12hr(f.time)}: ${f.teamAName} vs ${f.teamBName}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Row(
                                  children: [
                                    _FormatBadge(label: f.round),
                                    if (f.court.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '· ${f.court}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (f.isCompleted) ...[
                            Text(
                              '${f.setsWonA}–${f.setsWonB}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          _StatusPill(
                            label: f.statusLabel,
                            color: f.statusColor,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CalGridView extends StatelessWidget {
  final Map<String, List<FixtureModel>> byDate;

  const _CalGridView({required this.byDate});

  DateTime _parseDate(String d) {
    try {
      return DateTime.parse(d.split(' ')[0]);
    } catch (_) {
      return DateTime(2000);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (byDate.isEmpty) return _empty('No fixtures match filters.');

    // 🔥 Convert keys → DateTime
    final dates =
        byDate.keys.where((e) => e != 'Unscheduled').map(_parseDate).toList()
          ..sort();

    if (dates.isEmpty) return _empty('No valid dates.');

    final first = DateTime(dates.first.year, dates.first.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(first.year, first.month);
    final startWeekday = first.weekday;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.3,
      ),
      itemCount: daysInMonth + (startWeekday - 1),
      itemBuilder: (context, index) {
        if (index < startWeekday - 1) {
          return const SizedBox();
        }

        final day = index - (startWeekday - 2);

        final dateKey =
            "${first.year.toString().padLeft(4, '0')}-${first.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";

        final matches = byDate[dateKey] ?? [];

        return _CalendarDayCell(day: day, matches: matches);
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final List<FixtureModel> matches;

  const _CalendarDayCell({required this.day, required this.matches});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$day',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          ...matches
              .take(3)
              .map(
                (f) => Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: f.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${_fmt12hr(f.time)} ${f.teamAName} vs ${f.teamBName}",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: f.statusColor),
                  ),
                ),
              ),

          if (matches.length > 3)
            Text(
              "+${matches.length - 3}",
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        boxShadow: active
            ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: active ? const Color(0xFF4F46E5) : Colors.grey.shade500,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF4F46E5) : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CalFilter extends StatelessWidget {
  final String label, value;
  final List<String> options;
  final void Function(String) onChanged;
  const _CalFilter({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: value.isNotEmpty
            ? const Color(0xFF4F46E5)
            : Colors.grey.shade300,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        hint: Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
        icon: Icon(
          Icons.keyboard_arrow_down,
          size: 16,
          color: Colors.grey.shade400,
        ),
        style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
        items: options
            .map(
              (o) => DropdownMenuItem(
                value: o,
                child: Text(
                  o.isEmpty
                      ? 'All $label'
                      : o[0].toUpperCase() + o.substring(1),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => onChanged(v ?? ''),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// LIVE TAB
// ══════════════════════════════════════════════════════════════
class _LiveTab extends StatefulWidget {
  final TournamentModel tournament;
  final Future<void> Function(FixtureModel) onUpdateFixture;
  final bool isUser;
  const _LiveTab({
    required this.tournament,
    required this.onUpdateFixture,
    required this.isUser,
  });
  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> {
  int _selCatIdx = 0;
  String _selFixId = '';
  static const _indigo = Color(0xFF4F46E5);

  List<EventGroup> get _groups => widget.tournament.eventGroups;
  EventGroup? get _selGroup =>
      _selCatIdx < _groups.length ? _groups[_selCatIdx] : null;
  List<FixtureModel> get _matches => _selGroup?.fixtures ?? [];
  FixtureModel? get _selFix {
    if (_selFixId.isEmpty)
      return _firstOrNull(_matches.where((f) => f.status == 'live')) ??
          _firstOrNull(_matches);
    return _firstOrNull(_matches.where((f) => f.id == _selFixId));
  }

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _groups.length; i++) {
      if (_groups[i].fixtures.any((f) => f.status == 'live')) {
        _selCatIdx = i;
        break;
      }
    }
  }

  void _toggleLive(FixtureModel f) {
    widget.onUpdateFixture(
      f.copyWith(status: f.status == 'live' ? 'scheduled' : 'live'),
    );
    setState(() {});
  }

  int? getSuperTbWinnerId(FixtureModel upd) {
    if (upd.sets.length < 3) return null;

    final lastSet = upd.sets.last;

    if (lastSet.scoreA > lastSet.scoreB) {
      return int.parse(upd.teamAId);
    } else if (lastSet.scoreB > lastSet.scoreA) {
      return int.parse(upd.teamBId);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_groups.isEmpty) return _empty('No categories found.');
    if (_selCatIdx >= _groups.length) _selCatIdx = 0;
    return Row(
      children: [
        // LEFT SIDEBAR
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CATEGORY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _indigo.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _indigo.withOpacity(0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selCatIdx,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: Color(0xFF4F46E5),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4F46E5),
                          ),
                          items: _groups
                              .asMap()
                              .entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _selCatIdx = v!;
                            _selFixId = '';
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: const Text(
                  'MATCHES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: _matches.length,
                  itemBuilder: (_, i) {
                    final f = _matches[i];
                    final isSel = f.id == (_selFix?.id ?? '');
                    return GestureDetector(
                      onTap: () => setState(() => _selFixId = f.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? _indigo.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel
                                ? _indigo.withOpacity(0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (f.status == 'live')
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'M${f.matchNumber}  •  ${f.round}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    f.teamAName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  Text(
                                    f.teamBName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (f.isCompleted)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 28),
                                  child: Text(
                                    '${f.setsWonA}–${f.setsWonB}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ),
                            if (f.status.toLowerCase() == 'cancelled')
                              Positioned(
                                bottom: 3,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "CANCELLED",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // RIGHT PANEL
        Expanded(
          child: _selFix == null
              ? _empty('Select a match from the left panel')
              : _LiveMatchPanel(
                  fixture: _selFix!,
                  group: _selGroup!,
                  onToggleLive: () => _toggleLive(_selFix!),
                  onEnterScore: () => showDialog(
                    context: context,
                    useRootNavigator: false,
                    builder: (_) => _PadelScoreDialog(
                      fixture: _selFix!,
                      group: _selGroup!,
                      onSave: (upd) async {
                        final superTbWinnerId = getSuperTbWinnerId(upd);
                        // 🔥 1. SAVE SCORE
                        await TournamentService.saveScore(
                          fixtureId: upd.id.toString(),
                          homeScore: upd.setsWonA,
                          awayScore: upd.setsWonB,
                          superTbWinnerId: superTbWinnerId,
                        );

                        // 🔥 2. WAIT FOR PARENT REFRESH (VERY IMPORTANT)
                        await widget.onUpdateFixture(upd);

                        Navigator.pop(context);

                        // 🔥 4. OPTIONAL (SAFE)
                        setState(() {});
                      },
                    ),
                  ),
                  isUser: widget.isUser,
                ),
        ),
      ],
    );
  }
}

class _LiveMatchPanel extends StatelessWidget {
  final FixtureModel fixture;
  final EventGroup group;
  final VoidCallback onToggleLive, onEnterScore;
  final bool isUser;

  const _LiveMatchPanel({
    required this.fixture,
    required this.group,
    required this.onToggleLive,
    required this.onEnterScore,
    required this.isUser,
  });
  String _players(String id) {
    final p = _firstOrNull(group.participants.where((p) => p.id == id));
    return p?.playerNames.join(' / ') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final aWins = f.winnerId == f.teamAId && f.winnerId.isNotEmpty;
    final bWins = f.winnerId == f.teamBId && f.winnerId.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${f.teamAName}  vs  ${f.teamBName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (_players(f.teamAId).isNotEmpty ||
                        _players(f.teamBId).isNotEmpty)
                      Text(
                        '${_players(f.teamAId)}   vs   ${_players(f.teamBId)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),

              if (!isUser) ...[
                ElevatedButton(
                  onPressed: onEnterScore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Enter Score',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          Divider(color: Colors.grey.shade200, height: 24),
          Row(
            children: [
              _StatusPill(
                label: f.status == 'live' ? '🔴 LIVE' : f.statusLabel,
                color: f.statusColor,
              ),
              const SizedBox(width: 12),
              Text(
                '${f.round}  •  Match ${f.matchNumber}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              if (f.court.isNotEmpty) ...[
                const SizedBox(width: 10),
                Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 2),
                Text(
                  f.court,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          // Scoreboard
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            f.teamAName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_players(f.teamAId).isNotEmpty)
                            Text(
                              _players(f.teamAId),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 12),
                          Text(
                            aWins && f.setsWonA == 0 && f.setsWonB == 0
                                ? 'W/O'
                                : '${f.setsWonA}',
                            style: TextStyle(
                              color: aWins
                                  ? const Color(0xFF4ADE80)
                                  : Colors.white,
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        ':',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            f.teamBName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_players(f.teamBId).isNotEmpty)
                            Text(
                              _players(f.teamBId),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 12),
                          Text(
                            bWins && f.setsWonB == 0 && f.setsWonA == 0
                                ? 'W/O'
                                : '${f.setsWonB}',
                            style: TextStyle(
                              color: bWins
                                  ? const Color(0xFF4ADE80)
                                  : Colors.white,
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (f.sets.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Divider(color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 12),
                  // Per-set scores
                  ...f.sets.asMap().entries.map((e) {
                    final sw = e.value.scoreA > e.value.scoreB
                        ? 'A'
                        : e.value.scoreB > e.value.scoreA
                        ? 'B'
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: sw == 'A'
                                    ? const Color(0xFF4F46E5).withOpacity(0.3)
                                    : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${e.value.scoreA}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: sw == 'A'
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              e.key >= 2 ? 'S.TB' : 'Set ${e.key + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: sw == 'B'
                                    ? const Color(0xFF4F46E5).withOpacity(0.3)
                                    : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${e.value.scoreB}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: sw == 'B'
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'No scores yet. Use "Enter Score" to record.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (f.winnerId.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Divider(color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFFF59E0B),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Winner: ${f.winnerId == f.teamAId ? f.teamAName : f.teamBName}',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
  @override
  State<_PadelScoreDialog> createState() => _PadelScoreDialogState();
}

class _PadelScoreDialogState extends State<_PadelScoreDialog> {
  List<int> _gA = [], _gB = [];
  String _winnerId = '';
  String _resultType = 'normal';
  List<String> _errors = [];
  int _bestOf = 3; // Best of 1 | 3 | 5
  bool _published = false;
  bool _submitting = false;
  static const _indigo = Color(0xFF4F46E5);
  static const _green = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    _gA = widget.fixture.sets.map((s) => s.scoreA).toList();
    _gB = widget.fixture.sets.map((s) => s.scoreB).toList();

    if (_gA.length >= 5)
      _bestOf = 5;
    else if (_gA.length >= 3)
      _bestOf = 3;
    else
      _bestOf = 3;
    _ensureSetCount();
    _published = widget.fixture.isCompleted;
    _recalc();
  }

  int get _setsNeeded => (_bestOf / 2).ceil();

  void _ensureSetCount() {
    int totalSets;

    if (_bestOf == 1) {
      totalSets = 2; // Set 1 + Super TB
    } else if (_bestOf == 3) {
      totalSets = 3; // Set1, Set2, SuperTB
    } else {
      totalSets = 5; // full
    }

    while (_gA.length < totalSets) {
      _gA.add(0);
      _gB.add(0);
    }

    while (_gA.length > totalSets) {
      _gA.removeLast();
      _gB.removeLast();
    }
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
      final isSuperTb =
          (_bestOf == 1 && i == 1) || // ✅ ADD THIS
          (_bestOf == 3 && i == 2) ||
          (_bestOf == 5 && i == 4);
      if (_gA[i] > 0 || _gB[i] > 0) {
        final err = _PadelScoringEngine.validateSet(
          _gA[i],
          _gB[i],
          isSuperTb ? 2 : i,
        );
        if (err != null) errors.add('Set ${isSuperTb ? "S.TB" : i + 1}: $err');
      }
      final w = _PadelScoringEngine.setWinner(
        _gA[i],
        _gB[i],
        isSuperTb ? 2 : i,
      );
      if (w == 'A') sA++;
      if (w == 'B') sB++;
    }
    String winner = '';
    switch (_resultType) {
      case 'walkover_a':
        winner = widget.fixture.teamAId;
        break;
      case 'walkover_b':
        winner = widget.fixture.teamBId;
        break;

      default:
        if (sA >= _setsNeeded)
          winner = widget.fixture.teamAId;
        else if (sB >= _setsNeeded)
          winner = widget.fixture.teamBId;
    }
    setState(() {
      _errors = errors;
      _winnerId = winner;
    });
  }

  int get _setsWonA {
    int s = 0;
    for (int i = 0; i < _gA.length; i++) {
      final isSuperTb = (_bestOf == 3 && i == 2) || (_bestOf == 5 && i == 4);
      if (_PadelScoringEngine.setWinner(_gA[i], _gB[i], isSuperTb ? 2 : i) ==
          'A')
        s++;
    }
    return s;
  }

  int get _setsWonB {
    int s = 0;
    for (int i = 0; i < _gA.length; i++) {
      final isSuperTb = (_bestOf == 3 && i == 2) || (_bestOf == 5 && i == 4);
      if (_PadelScoringEngine.setWinner(_gA[i], _gB[i], isSuperTb ? 2 : i) ==
          'B')
        s++;
    }
    return s;
  }

  void _submit({required bool publish}) async {
    if (_errors.isNotEmpty) {
      _showToast('Fix errors before submitting', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      int homeScore = _setsWonA;
      int awayScore = _setsWonB;

      final isWalkover =
          _resultType == 'walkover_a' || _resultType == 'walkover_b';

      if (isWalkover) {
        if (_resultType == 'walkover_a') {
          homeScore = 1;
          awayScore = 0;
        } else {
          homeScore = 0;
          awayScore = 1;
        }
      }

      print("🔥 SUBMIT FIXTURE ID: ${widget.fixture.id}");
      print("🔥 HOME: $homeScore AWAY: $awayScore WINNER: $_winnerId");

      // ✅ CALL SERVICE
      await TournamentService.submitResult(
        fixtureId: widget.fixture.id,
        homeScore: homeScore,
        awayScore: awayScore,
      );

      // ✅ KEEP UI UPDATE
      final sets = List.generate(
        _gA.length,
        (i) => SetScore(scoreA: _gA[i], scoreB: _gB[i]),
      );

      widget.onSave(
        widget.fixture.copyWith(
          sets: sets,
          setsWonA: isWalkover
              ? (_winnerId == widget.fixture.teamAId ? 1 : 0)
              : _setsWonA,
          setsWonB: isWalkover
              ? (_winnerId == widget.fixture.teamBId ? 1 : 0)
              : _setsWonB,
          winnerId: _winnerId,
          status: publish ? 'completed' : 'live',
          isLive: !publish,
        ),
      );

      _showToast(
        publish ? '✓ Score published successfully' : '✓ Score saved as draft',
        isError: false,
      );

      if (publish) Navigator.pop(context);
    } catch (e) {
      print("❌ ERROR: $e");
      _showToast('Failed to save score', isError: true);
    }

    setState(() => _submitting = false);
  }

  void _showToast(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : _green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userRole == 'viewer') {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              const Text(
                'Access Restricted',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Score entry is only available to Scorers and Admins.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 560,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sports_tennis,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Score Entry',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${widget.fixture.teamAName}  vs  ${widget.fixture.teamBName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.userRole.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: const Color(0xFFF8F9FE),
              child: Row(
                children: [
                  _FormatBadge(label: widget.fixture.round),
                  const SizedBox(width: 8),
                  _FormatBadge(
                    label: 'M${widget.fixture.matchNumber}',
                    color: Colors.grey.shade500,
                  ),
                  if (widget.fixture.court.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.sports_tennis_rounded,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      widget.fixture.court,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Best-of selector
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _indigo.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Best of:',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ...[1, 3, 5].map(
                          (n) => GestureDetector(
                            onTap: () => _setBestOf(n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 26,
                              height: 26,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: _bestOf == n
                                    ? _indigo
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '$n',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _bestOf == n
                                        ? Colors.white
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Result Type',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _resultChip('normal', 'Normal Match'),
                        _resultChip('walkover_a', 'W/O: ${_aN} wins'),
                        _resultChip('walkover_b', 'W/O: ${_bN} wins'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_resultType == 'normal') ...[
                      Row(
                        children: [
                          const SizedBox(width: 70),
                          Expanded(
                            child: Text(
                              _aN,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _bN,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 24),
                        ],
                      ),
                      const SizedBox(height: 10),

                      ...List.generate(_gA.length, (i) {
                        final isSuperTb =
                            (_bestOf == 3 && i == 2) ||
                            (_bestOf == 5 && i == 4);
                        final label = isSuperTb
                            ? 'Super\nTB'
                            : (_bestOf == 1 && i == 1)
                            ? 'Super\nTB'
                            : 'Set ${i + 1}';
                        final hint = isSuperTb ? ' ' : ' ';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _setRow(i, label, hint, isSuperTb),
                        );
                      }),
                    ],

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _indigo.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _indigo.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _aN,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$_setsWonA',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: _indigo,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'SETS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                          Text(
                            '$_setsWonB',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: _indigo,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _bN,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Winner banner
                    if (_winnerId.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: Color(0xFFF59E0B),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Winner: ${_winnerId == widget.fixture.teamAId ? _aN : _bN}',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (_resultType != 'normal') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _resultType.contains('walkover')
                                      ? 'Walkover'
                                      : 'Retirement',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFF59E0B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // ── Validation errors ─────────────────────────────────
            if (_errors.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _errors
                      .map(
                        (e) => Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 12,
                              color: Colors.red.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),

            // ── Actions: Cancel | Save Draft | Publish ─────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  const Spacer(),
                  // Edit / Save Draft button (saves without publishing)
                  OutlinedButton.icon(
                    onPressed: (_submitting || _errors.isNotEmpty)
                        ? null
                        : () => _submit(publish: false),
                    icon: _submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined, size: 15),
                    label: const Text(
                      'Save Draft',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _indigo,
                      side: BorderSide(
                        color: _errors.isNotEmpty
                            ? Colors.grey.shade300
                            : _indigo,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Publish button
                  ElevatedButton.icon(
                    onPressed:
                        (_submitting || _errors.isNotEmpty || _winnerId.isEmpty)
                        ? null
                        : () => _submit(publish: true),
                    icon: _submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.publish_rounded, size: 15),
                    label: const Text(
                      'Publish Score',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _errors.isNotEmpty || _winnerId.isEmpty
                          ? Colors.grey.shade400
                          : _green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  String get _aN => widget.fixture.teamAName;
  String get _bN => widget.fixture.teamBName;

  Widget _resultChip(String value, String label) {
    final sel = _resultType == value;
    return GestureDetector(
      onTap: () => setState(() {
        _resultType = value;
        _recalc();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _indigo : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _indigo : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: sel ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _setRow(int setIdx, String label, String hint, bool isSuperTb) {
    if (setIdx >= _gA.length) return const SizedBox.shrink();
    final w = _PadelScoringEngine.setWinner(
      _gA[setIdx],
      _gB[setIdx],
      isSuperTb ? 2 : setIdx,
    );
    final hasErr = _errors.any(
      (e) => e.startsWith('Set ${isSuperTb ? "S.TB" : setIdx + 1}'),
    );
    final maxScore = isSuperTb ? 25 : 7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hasErr
            ? Colors.red.shade50
            : w != null
            ? const Color(0xFFF0FDF4)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasErr
              ? Colors.red.shade300
              : w != null
              ? _green.withOpacity(0.4)
              : Colors.grey.shade200,
          width: (hasErr || w != null) ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                ),
                if (w != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      w == 'A' ? '✓ $_aN' : '✓ $_bN',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        color: _green,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _counter(
              _gA[setIdx],
              maxScore,
              w == 'A',
              dec: () {
                if (_gA[setIdx] > 0)
                  setState(() {
                    _gA[setIdx]--;
                    _recalc();
                  });
              },
              inc: () => setState(() {
                _gA[setIdx]++;
                _recalc();
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '–',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: _counter(
              _gB[setIdx],
              maxScore,
              w == 'B',
              dec: () {
                if (_gB[setIdx] > 0)
                  setState(() {
                    _gB[setIdx]--;
                    _recalc();
                  });
              },
              inc: () => setState(() {
                _gB[setIdx]++;
                _recalc();
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _counter(
    int value,
    int maxVal,
    bool winner, {
    required VoidCallback dec,
    required VoidCallback inc,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _counterBtn(Icons.remove_rounded, value > 0, dec),
      const SizedBox(width: 8),
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: winner ? _green.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: winner ? _green : Colors.grey.shade300,
            width: winner ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: winner ? _green : const Color(0xFF111827),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      _counterBtn(Icons.add_rounded, value < maxVal, inc),
    ],
  );

  Widget _counterBtn(IconData icon, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: enabled ? _indigo.withOpacity(0.08) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? _indigo : Colors.grey.shade300,
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// STANDINGS TAB
// ══════════════════════════════════════════════════════════════
class _StandingsTab extends StatefulWidget {
  final TournamentModel tournament;
  final bool isUser;
  const _StandingsTab({required this.tournament, required this.isUser});
  @override
  State<_StandingsTab> createState() => _StandingsTabState();
}

class _StandingsTabState extends State<_StandingsTab> {
  int _selIdx = 0;
  bool _showTiebreakerInfo = false;
  static const _indigo = Color(0xFF4F46E5);

  List<StandingRow> standings = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    try {
      final g = widget.tournament.eventGroups.first;

      print("🔥 GROUP ID: ${g.id}");

      final res = await TournamentService.getStandings(g.id);
      final List data = res;

      print("🔥 API STANDINGS: $data");

      final rows = data.map<StandingRow>((s) {
        print("🔥 TEAM ID FROM API: ${s['team_id']}");
        print(
          "🔥 PARTICIPANTS: ${g.participants.map((p) => "${p.id}-${p.name}").toList()}",
        );

        final teamId = s['team_id']?.toString() ?? '';

        final participant = g.participants.firstWhere(
          (p) => p.id == teamId,
          orElse: () =>
              ParticipantModel(id: '', name: 'Unknown', playerNames: []),
        );

        return StandingRow.fromJson(s, participant.name);
      }).toList();

      setState(() {
        standings = rows;
        loading = false;
      });
    } catch (e) {
      print("❌ STANDINGS ERROR: $e");

      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.tournament.eventGroups;
    if (groups.isEmpty) return _empty('No categories yet.');
    if (_selIdx >= groups.length) _selIdx = 0;
    final g = groups[_selIdx];

    return Column(
      children: [
        _CategorySelector(
          groups: groups,
          selectedIdx: _selIdx,
          onChanged: (i) => setState(() => _selIdx = i),
          trailing: [
            GestureDetector(
              onTap: () =>
                  setState(() => _showTiebreakerInfo = !_showTiebreakerInfo),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _showTiebreakerInfo
                      ? _indigo.withOpacity(0.1)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _showTiebreakerInfo
                        ? _indigo.withOpacity(0.4)
                        : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 12,
                      color: _showTiebreakerInfo
                          ? _indigo
                          : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Tiebreaker Rules',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _showTiebreakerInfo
                            ? _indigo
                            : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (_showTiebreakerInfo) _TiebreakerInfoPanel(format: g.format),

        Expanded(
          child: (g.format == 'round_robin' || g.format == 'custom')
              ? _RoundRobinStandings(group: g, isUser: widget.isUser)
              : g.format == 'knockout'
              ? _KnockoutStandings(group: g)
              : _empty('Standings not available'),
        ),
      ],
    );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.sort_rounded, size: 14, color: _indigo),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ranking Calculation & Tiebreaker Order',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...[
            _tbRow(
              '1',
              Icons.stars_rounded,
              'Points',
              'Win = 3 pts  ·  Loss = 0 pts  ·  Teams sorted by total points first',
              const Color(0xFF4F46E5),
            ),
            _tbRow(
              '2',
              Icons.compare_arrows_rounded,
              'Head to Head',
              'If equal points: direct result between tied teams decides rank',
              const Color(0xFF0891B2),
            ),
            _tbRow(
              '3',
              Icons.sports_tennis_rounded,
              'Set Difference',
              'If H2H tied: Sets Won − Sets Lost across all matches',
              const Color(0xFF16A34A),
            ),
            _tbRow(
              '4',
              Icons.calculate_outlined,
              'Game / Point Difference',
              'If set diff tied: Total Games Won − Total Games Lost',
              const Color(0xFFF59E0B),
            ),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 12,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'If all tiebreakers are equal, teams share the same rank.',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tbRow(
    String step,
    IconData icon,
    String title,
    String desc,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                desc,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Standing entry data model ─────────────────────────────────
class _SE {
  final String id, name;
  final int pl, w, l, sf, sa, gf, ga, pts;
  final Map<String, int> h2h;
  const _SE({
    required this.id,
    required this.name,
    this.pl = 0,
    this.w = 0,
    this.l = 0,
    this.sf = 0,
    this.sa = 0,
    this.gf = 0,
    this.ga = 0,
    this.pts = 0,
    this.h2h = const {},
  });
  _SE upd({
    int? pl,
    int? w,
    int? l,
    int? sf,
    int? sa,
    int? gf,
    int? ga,
    int? pts,
    Map<String, int>? h2h,
  }) => _SE(
    id: id,
    name: name,
    pl: pl ?? this.pl,
    w: w ?? this.w,
    l: l ?? this.l,
    sf: sf ?? this.sf,
    sa: sa ?? this.sa,
    gf: gf ?? this.gf,
    ga: ga ?? this.ga,
    pts: pts ?? this.pts,
    h2h: h2h ?? this.h2h,
  );
}

// ── Round Robin Standings ──────────────────────────────────────
class _RoundRobinStandings extends StatefulWidget {
  final EventGroup group;
  final bool isUser;
  final bool hideH2H;
  final bool hideProgress;
  final bool hideFooter;
  final bool isCompact;
  final bool hideLegend;

  const _RoundRobinStandings({
    required this.group,
    required this.isUser,
    this.hideH2H = false,
    this.hideProgress = false,
    this.hideFooter = false,
    this.isCompact = false,
    this.hideLegend = false,
  });

  @override
  State<_RoundRobinStandings> createState() => _RoundRobinStandingsState();
}

class _RoundRobinStandingsState extends State<_RoundRobinStandings> {
  static const _indigo = Color(0xFF4F46E5);
  List<dynamic> standings = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchStandings();
  }

  Future<void> fetchStandings() async {
    try {
      print("🔥 GROUP ID: ${widget.group.id}");
      print("🔥 STAGE ID: ${widget.group.stageId}");

      final res = await TournamentService.getStandings(widget.group.id);

      standings = res;
      print("✅ STANDINGS API: $standings");
    } catch (e) {
      print("❌ ERROR: $e");
    }

    setState(() => loading = false);
  }

  void _openEditDialog(dynamic row) {
    final played = TextEditingController(text: row['played'].toString());
    final won = TextEditingController(text: row['won'].toString());
    final lost = TextEditingController(text: row['lost'].toString());
    final draw = TextEditingController(text: row['draw'].toString());
    final gf = TextEditingController(text: row['gf'].toString());
    final ga = TextEditingController(text: row['ga'].toString());
    final sd = TextEditingController(text: (row['sd'] ?? 0).toString());
    final gd = TextEditingController(text: row['gd'].toString());
    final pts = TextEditingController(text: row['points'].toString());
    final pos = TextEditingController(text: row['position'].toString());
    final h2h = TextEditingController(text: (row['h2h'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit Standing"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _input("Played", played),
              _input("Won", won),
              _input("Lost", lost),
              _input("Draw", draw),
              _input("GF", gf),
              _input("GA", ga),
              _input("SD", sd),
              _input("GD", gd),
              _input("Points", pts),
              _input("Position", pos),
              _input("H2H", h2h),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await TournamentService.updateStanding(row['id'].toString(), {
                "played": int.parse(played.text),
                "won": int.parse(won.text),
                "lost": int.parse(lost.text),
                "draw": int.parse(draw.text),
                "gf": int.parse(gf.text),
                "ga": int.parse(ga.text),
                "sd": int.parse(sd.text),
                "gd": int.parse(gd.text),
                "points": int.parse(pts.text),
                "position": int.parse(pos.text),
                "h2h": int.parse(h2h.text),
              });

              Navigator.pop(context);
              fetchStandings(); // refresh
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  String _sign(int v) => v > 0 ? '+$v' : '$v';
  Color _signColor(int v) =>
      v >= 0 ? const Color(0xFF16A34A) : const Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (standings.isEmpty) {
      return const Center(child: Text("No standings yet"));
    }

    final rows = standings;

    final completed = widget.group.fixtures.where((f) => f.isCompleted).length;

    final total = widget.group.fixtures.length;

    return SingleChildScrollView(
      padding: widget.isCompact
          ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
          : const EdgeInsets.fromLTRB(12, 12, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          if (!widget.hideProgress)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Match Progress',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$completed / $total completed',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? completed / total : 0,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(_indigo),
                    ),
                  ),
                ],
              ),
            ),

          if (!widget.hideLegend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: EdgeInsets.only(bottom: widget.hideLegend ? 0 : 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  // LEFT SIDE (LEGEND)
                  Expanded(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        _legend('Pl', 'Played'),
                        _legend('W', 'Won'),
                        _legend('L', 'Lost'),
                        if (!widget.hideH2H)
                          _legend('H2H', 'Head to Head result'),
                        _legend('SD', 'Set Diff'),
                        _legend('GD', 'Game Diff'),
                        _legend('Pts', 'Points (W=3)'),
                      ],
                    ),
                  ),

                  // 🔥 RIGHT SIDE (RESTORE BUTTON)
                  if (!widget.hideLegend && !widget.isUser)
                    ElevatedButton.icon(
                      icon: Icon(Icons.refresh, size: 16),
                      label: Text("Restore"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("Confirm Restore"),
                            content: Text(
                              "Are you sure you want to restore standings?\n\nAll manual changes will be lost.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text("Cancel"),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: Text("Restore"),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await TournamentService.restoreStandings(
                            widget.group.id.toString(),
                          );

                          fetchStandings();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Standings restored successfully"),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),

          Builder(
            builder: (_) {
              Widget table = Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: widget.isCompact ? 8 : 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 32,
                            child: Text(
                              '#',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            flex: 5,
                            child: Text(
                              'Team / Player',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          _hCell('Pl'),
                          _hCell('W'),
                          _hCell('L'),
                          if (!widget.hideH2H)
                            _hCell('H2H', color: const Color(0xFF0891B2)),
                          _hCell('GD', color: const Color(0xFF16A34A)),
                          _hCell('SD', color: const Color(0xFFF59E0B)),
                          _hCell('Pts', flex: 2, color: _indigo),
                        ],
                      ),
                    ),

                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No matches completed yet.',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ...rows.asMap().entries.map((e) {
                        final r = e.value;
                        final idx = e.key;

                        final isTop = idx == 0;

                        final teamId = r['team_id']?.toString() ?? '';

                        final participant = widget.group.participants
                            .firstWhere(
                              (p) => p.id.toString() == teamId.toString(),
                              orElse: () => ParticipantModel(
                                id: '',
                                name: 'Unknown',
                                playerNames: [],
                              ),
                            );

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: idx.isEven
                                ? Colors.white
                                : Colors.grey.shade50,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade100),
                            ),
                            borderRadius: idx == rows.length - 1
                                ? const BorderRadius.vertical(
                                    bottom: Radius.circular(12),
                                  )
                                : BorderRadius.zero,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${idx + 1}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        participant.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                    ),
                                    if (isTop &&
                                        (int.tryParse(r['points'].toString()) ??
                                                0) >
                                            0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF16A34A,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Text(
                                          'TOP',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _dCell('${r['played']}'),
                              _dCell(
                                '${r['won']}',
                                color:
                                    (int.tryParse(r['won'].toString()) ?? 0) > 0
                                    ? const Color(0xFF16A34A)
                                    : null,
                                bold:
                                    (int.tryParse(r['won'].toString()) ?? 0) >
                                    0,
                              ),
                              _dCell(
                                '${r['lost']}',
                                color:
                                    (int.tryParse(r['lost'].toString()) ?? 0) >
                                        0
                                    ? const Color(0xFFEF4444)
                                    : null,
                                bold:
                                    (int.tryParse(r['lost'].toString()) ?? 0) >
                                    0,
                              ),

                              if (!widget.hideH2H)
                                _dCell(
                                  (r['h2h'] == null ||
                                          r['h2h'].toString().isEmpty)
                                      ? ''
                                      : r['h2h'].toString(),
                                ),

                              _dCell(
                                _sign(int.tryParse(r['gd'].toString()) ?? 0),
                                color: _signColor(
                                  int.tryParse(r['gd'].toString()) ?? 0,
                                ),
                              ),

                              _dCell(
                                _sign(int.tryParse(r['sd'].toString()) ?? 0),
                                color: _signColor(
                                  int.tryParse(r['sd'].toString()) ?? 0,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // SHIFT LEFT LITTLE BIT (to balance icon)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 18),
                                      child: _ptsCell(
                                        int.tryParse(r['points'].toString()) ??
                                            0,
                                      ),
                                    ),

                                    // EDIT ICON FIXED RIGHT
                                    // EDIT ICON FIXED RIGHT
                                    if (!widget.isUser)
                                      Positioned(
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () => _openEditDialog(r),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(
                                                0.08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.edit,
                                              size: 16,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              );
              return widget.isCompact
                  ? Transform.translate(
                      offset: const Offset(0, -6),
                      child: table,
                    )
                  : table;
            },
          ),

          if (!widget.hideFooter) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 13,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Win = 3 pts  ·  Loss = 0 pts  ·  Tiebreaker order: Points → H2H → Set Diff → Game Diff',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _input(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _legend(String key, String desc) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _indigo.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          key,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _indigo,
          ),
        ),
      ),
      const SizedBox(width: 4),
      Text(desc, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ],
  );

  Widget _hCell(String t, {int flex = 1, Color? color}) => Expanded(
    flex: flex,
    child: Text(
      t,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color ?? const Color(0xFF6B7280),
      ),
    ),
  );
  Widget _dCell(String t, {Color? color, bool bold = false}) => Expanded(
    child: Text(
      t,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: color ?? const Color(0xFF374151),
      ),
    ),
  );

  Widget _ptsCell(int pts, {int flex = 1}) => Container(
    margin: EdgeInsets.zero,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: _indigo.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Center(
      child: Text(
        '$pts',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: _indigo,
        ),
      ),
    ),
  );
}

class _KnockoutStandings extends StatelessWidget {
  final EventGroup group;
  const _KnockoutStandings({required this.group});
  static const _indigo = Color(0xFF4F46E5);

  List<Map<String, dynamic>> _compute() {
    final reached = <String, int>{for (final p in group.participants) p.id: 0};

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
      final r = reached[p.id] ?? 0;
      final isCh = group.fixtures.any(
        (f) => f.isCompleted && f.round == 'Final' && f.winnerId == p.id,
      );

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
      return {
        'id': p.id,
        'name': p.name,
        'reached': r,
        'isChamp': isCh,
        'progress': progress,
      };
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 36,
                    child: Text(
                      '#',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 5,
                    child: Text(
                      'Team / Player',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Progress',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Rows
            ...rows.asMap().entries.map((e) {
              final row = e.value;
              final idx = e.key;
              final isChamp = row['isChamp'] as bool;
              final progress = row['progress'] as String;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: isChamp
                      ? const Color(0xFFFFFBEB)
                      : idx.isEven
                      ? Colors.white
                      : Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                  ),
                  borderRadius: idx == rows.length - 1
                      ? const BorderRadius.vertical(bottom: Radius.circular(12))
                      : BorderRadius.zero,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Center(
                        child: isChamp
                            ? const Text('🏆', style: TextStyle(fontSize: 16))
                            : Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        row['name'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isChamp
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isChamp
                              ? const Color(0xFFF59E0B).withOpacity(0.12)
                              : _indigo.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          progress,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isChamp ? 11 : 10,
                            fontWeight: FontWeight.w700,
                            color: isChamp ? const Color(0xFFF59E0B) : _indigo,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED MICRO WIDGETS + HELPERS
// ══════════════════════════════════════════════════════════════
class _FormatBadge extends StatelessWidget {
  final String label;
  final Color? color;
  const _FormatBadge({required this.label, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (color ?? const Color(0xFF4F46E5)).withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color ?? const Color(0xFF4F46E5),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

Widget _FormLabel(String label) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    label,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF374151),
    ),
  ),
);

Widget _empty(String msg) => Center(
  child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          msg,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  ),
);

T? _firstOrNull<T>(Iterable<T> iter) {
  final it = iter.iterator;
  return it.moveNext() ? it.current : null;
}

String _fmtDate(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}-${p[1]}-${p[0]}';
  } catch (_) {
    return iso;
  }
}

String _fmt12hr(String t) {
  if (t.isEmpty) return '';
  try {
    final p = t.split(':');
    int h = int.parse(p[0]);
    final m = p[1];
    final ap = h >= 12 ? 'PM' : 'AM';
    if (h == 0)
      h = 12;
    else if (h > 12)
      h -= 12;
    return '${h.toString().padLeft(2, '0')}:$m $ap';
  } catch (_) {
    return t;
  }
}
