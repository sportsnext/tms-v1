import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/sports/data/models/sport_model.dart';
import 'add_sport_screen.dart';
import 'edit_sport_screen.dart';

// Place at: lib/features/admin/sports/presentation/screens/sports_list_screen.dart

class SportsListScreen extends StatefulWidget {
  const SportsListScreen({super.key});

  @override
  State<SportsListScreen> createState() => _SportsListScreenState();
}

class _SportsListScreenState extends State<SportsListScreen> {

  // TODO: replace with GET /api/sports/all
  final List<SportModel> _sports = [
    SportPresets.padel.copyWith(
      id: 's1', createdAt: '2025-01-10',
    ),
  ];

  String _searchQuery = '';

  List<SportModel> get _filtered => _sports.where((s) =>
      s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      s.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      s.sportType.toLowerCase().contains(_searchQuery.toLowerCase())
  ).toList();

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _confirmDelete(SportModel sport) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 380, padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade600, size: 32),
            ),
            const SizedBox(height: 16),
            const Text("Delete Sport",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Delete "${sport.name}"? All scoring rules will be lost.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Text("Cancel",
                    style: TextStyle(color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  setState(() => _sports.removeWhere((s) => s.id == sport.id));
                  Navigator.pop(context);
                  _showSnack('"${sport.name}" deleted');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Delete",
                    style: TextStyle(fontWeight: FontWeight.w600)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  void _openAdd() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddSportScreen(
        onSave: (SportModel s) {
          setState(() => _sports.add(s));
          _showSnack('"${s.name}" added successfully!');
        },
      ),
    );
  }

  void _openEdit(SportModel sport) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditSportScreen(
        sport: sport,
        onSave: (SportModel updated) {
          setState(() {
            final i = _sports.indexWhere((s) => s.id == updated.id);
            if (i != -1) _sports[i] = updated;
          });
          _showSnack('"${updated.name}" updated successfully!');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final team = _sports.where((s) => s.sportType == 'Team').length;
    final ind  = _sports.where((s) => s.sportType == 'Individual').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Title + Add button ──────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Sports Master",
                    style: TextStyle(
                        fontSize: 30, fontWeight: FontWeight.bold,
                        color: Color(0xFF0A46D8))),
                const SizedBox(height: 3),
                Text("Define sports and configure scoring rules",
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500)),
              ]),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _openAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Add Sport",
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A46D8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 15),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Stat cards ──────────────────────────────────
          Row(children: [
            _StatCard(
              label: "Total Sports",
              value: "${_sports.length}",
              icon:  Icons.sports_outlined,
              color: const Color(0xFF0A46D8),
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: "Individual",
              value: "$ind",
              icon:  Icons.person_outline,
              color: const Color(0xFF7C3AED),
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: "Team Sports",
              value: "$team",
              icon:  Icons.group_outlined,
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: "With Tiebreak",
              value: "${_sports.where((s) => s.scoringRules.hasTieBreak).length}",
              icon:  Icons.sports_score_outlined,
              color: const Color(0xFF16A34A),
            ),
          ]),

          const SizedBox(height: 22),

          // ── Search ──────────────────────────────────────
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search by sport name, category or type...",
                hintStyle: TextStyle(
                    color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search,
                    color: Colors.grey.shade400, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // ── Sports grid ─────────────────────────────────
          _filtered.isEmpty
              ? _buildEmpty()
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _SportCard(
                    sport:    _filtered[i],
                    onEdit:   () => _openEdit(_filtered[i]),
                    onDelete: () => _confirmDelete(_filtered[i]),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 72),
        child: Center(child: Column(children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6), shape: BoxShape.circle),
            child: const Icon(Icons.sports_outlined,
                size: 34, color: Color(0xFFD1D5DB)),
          ),
          const SizedBox(height: 16),
          const Text("No sports found",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          const Text("Click '+ Add Sport' to get started",
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        ])),
      );
}

// ── Sport card ────────────────────────────────────────────────
class _SportCard extends StatefulWidget {
  final SportModel   sport;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SportCard({
    required this.sport,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SportCard> createState() => _SportCardState();
}

class _SportCardState extends State<_SportCard> {
  bool _hovered = false;

  Color get _categoryColor {
    switch (widget.sport.category) {
      case 'Racket': return const Color(0xFF0A46D8);
      case 'Field':  return const Color(0xFF16A34A);
      case 'Court':  return const Color(0xFF7C3AED);
      case 'Combat': return const Color(0xFFDC2626);
      default:       return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s  = widget.sport;
    final sr = s.scoringRules;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? const Color(0xFF0A46D8).withOpacity(0.4)
                : const Color(0xFFE5E7EB),
            width: _hovered ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(
            color: _hovered
                ? const Color(0xFF0A46D8).withOpacity(0.10)
                : Colors.black.withOpacity(0.05),
            blurRadius: _hovered ? 20 : 8,
            offset: const Offset(0, 4),
          )],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Top: icon + name + chips ────────────────
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _categoryColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(s.icon,
                      style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                    const SizedBox(height: 3),
                    Row(children: [
                      _MiniChip(label: s.category, color: _categoryColor),
                      const SizedBox(width: 6),
                      _MiniChip(
                        label: s.sportType,
                        color: s.sportType == 'Team'
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF7C3AED),
                      ),
                    ]),
                  ],
                )),
              ]),

              const SizedBox(height: 12),

              // ── Scoring summary pills ───────────────────
              Expanded(
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    _ScorePill(label: "Sets",   value: "${sr.sets}"),
                    _ScorePill(label: "Games",  value: "${sr.gamesPerSet}"),
                    if (sr.hasTieBreak) ...[
                      _ScorePill(
                        label: "TB pts",
                        value: "${sr.tieBreakPoints}",
                        color: const Color(0xFF7C3AED),
                      ),
                      _ScorePill(
                        label: "Win by",
                        value: "+${sr.tieBreakDiff}",
                        color: const Color(0xFF0891B2),
                      ),
                    ],
                    if (sr.goldenPoint)
                      _ScorePill(
                        label: "Golden Pt",
                        value: "ON",
                        color: const Color(0xFFF59E0B),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 8),

              // ── Bottom: version + actions ───────────────
              Row(children: [
                Icon(Icons.history_rounded,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text("v${s.version}",
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                _ActionBtn(
                  icon:    Icons.edit_outlined,
                  color:   const Color(0xFFF59E0B),
                  tooltip: "Edit",
                  onTap:   widget.onEdit,
                ),
                const SizedBox(width: 6),
                _ActionBtn(
                  icon:    Icons.delete_outline_rounded,
                  color:   const Color(0xFFEF4444),
                  tooltip: "Delete",
                  onTap:   widget.onDelete,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold,
                  color: color, height: 1)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(
                  fontSize: 11, color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500)),
            ]),
          ]),
        ),
      );
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: color)),
      );
}

class _ScorePill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ScorePill({required this.label, required this.value,
      this.color = const Color(0xFF0A46D8)});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(
              fontSize: 9, color: color.withOpacity(0.7),
              fontWeight: FontWeight.w500)),
        ]),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color,
      required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            hoverColor: color.withOpacity(0.18),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(icon, color: color, size: 16),
            ),
          ),
        ),
      );
}