import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/sports/data/models/sport_model.dart';

// Place at: lib/features/admin/sports/presentation/screens/edit_sport_screen.dart

class EditSportScreen extends StatefulWidget {
  final SportModel sport;
  final void Function(SportModel updated) onSave;
  const EditSportScreen({super.key, required this.sport, required this.onSave});

  @override
  State<EditSportScreen> createState() => _EditSportScreenState();
}

class _EditSportScreenState extends State<EditSportScreen> {
  final _formKey   = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _notesCtrl;

  late String _sportType;
  late String _category;
  late String _icon;
  late String _preset;
  bool        _saving = false;

  // Scoring
  late int  _sets;
  late int  _gamesPerSet;
  late bool _hasTieBreak;
  late int  _tieBreakAt;
  late int  _tieBreakPoints;
  late int  _tieBreakDiff;
  late bool _goldenPoint;

  static const _categories = ['Racket', 'Field', 'Court', 'Combat', 'Other'];
  static const _icons = ['🎾','🏸','🏓','🎱','⚽','🏏','🏒','🥊','🏀','🏐','🎿','🏅'];

  @override
  void initState() {
    super.initState();
    final s         = widget.sport;
    _nameCtrl       = TextEditingController(text: s.name);
    _descCtrl       = TextEditingController(text: s.description);
    _notesCtrl      = TextEditingController(text: s.notes);
    _sportType      = s.sportType;
    _category       = _categories.contains(s.category) ? s.category : 'Racket';
    _icon           = _icons.contains(s.icon) ? s.icon : '🎾';
    _preset         = 'Custom';
    // Scoring
    _sets           = s.scoringRules.sets;
    _gamesPerSet    = s.scoringRules.gamesPerSet;
    _hasTieBreak    = s.scoringRules.hasTieBreak;
    _tieBreakAt     = s.scoringRules.tieBreakAt;
    _tieBreakPoints = s.scoringRules.tieBreakPoints;
    _tieBreakDiff   = s.scoringRules.tieBreakDiff;
    _goldenPoint    = s.scoringRules.goldenPoint;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(String preset) {
    setState(() => _preset = preset);
    final p = SportPresets.forName(preset);
    if (p == null) return;
    _nameCtrl.text = p.name;
    _descCtrl.text = p.description;
    setState(() {
      _sportType      = p.sportType;
      _category       = p.category;
      _icon           = p.icon;
      _sets           = p.scoringRules.sets;
      _gamesPerSet    = p.scoringRules.gamesPerSet;
      _hasTieBreak    = p.scoringRules.hasTieBreak;
      _tieBreakAt     = p.scoringRules.tieBreakAt;
      _tieBreakPoints = p.scoringRules.tieBreakPoints;
      _tieBreakDiff   = p.scoringRules.tieBreakDiff;
      _goldenPoint    = p.scoringRules.goldenPoint;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final updated = widget.sport.copyWith(
      name:        _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      sportType:   _sportType,
      category:    _category,
      icon:        _icon,
      notes:       _notesCtrl.text.trim(),
      version:     widget.sport.version + 1, // bump version on rule change
      scoringRules: ScoringRules(
        sets:           _sets,
        gamesPerSet:    _gamesPerSet,
        hasTieBreak:    _hasTieBreak,
        tieBreakAt:     _tieBreakAt,
        tieBreakPoints: _tieBreakPoints,
        tieBreakDiff:   _tieBreakDiff,
        goldenPoint:    _goldenPoint,
      ),
    );

    setState(() => _saving = false);
    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _SportFormDialog(
      title:     "Edit Sport",
      subtitle:  '"${widget.sport.name}" · v${widget.sport.version} → v${widget.sport.version + 1}',
      isEdit:    true,
      saving:    _saving,
      saveLabel: "Update Sport",
      onCancel:  () => Navigator.pop(context),
      onSave:    _save,
      child: Form(
        key: _formKey,
        child: _SportFormBody(
          nameCtrl:        _nameCtrl,
          descCtrl:        _descCtrl,
          notesCtrl:       _notesCtrl,
          sportType:       _sportType,
          category:        _category,
          icon:            _icon,
          preset:          _preset,
          categories:      _categories,
          icons:           _icons,
          sets:            _sets,
          gamesPerSet:     _gamesPerSet,
          hasTieBreak:     _hasTieBreak,
          tieBreakAt:      _tieBreakAt,
          tieBreakPoints:  _tieBreakPoints,
          tieBreakDiff:    _tieBreakDiff,
          goldenPoint:     _goldenPoint,
          onPreset:        _applyPreset,
          onSportType:     (v) => setState(() => _sportType   = v),
          onCategory:      (v) => setState(() => _category    = v),
          onIcon:          (v) => setState(() => _icon        = v),
          onSets:          (v) => setState(() => _sets        = v),
          onGamesPerSet:   (v) => setState(() => _gamesPerSet = v),
          onHasTieBreak:   (v) => setState(() => _hasTieBreak = v),
          onTieBreakAt:    (v) => setState(() => _tieBreakAt  = v),
          onTieBreakPoints:(v) => setState(() => _tieBreakPoints = v),
          onTieBreakDiff:  (v) => setState(() => _tieBreakDiff   = v),
          onGoldenPoint:   (v) => setState(() => _goldenPoint    = v),
        ),
      ),
    );
  }
}
class _SportFormBody extends StatelessWidget {
  final TextEditingController nameCtrl, descCtrl, notesCtrl;
  final String     sportType, category, icon, preset;
  final List<String> categories, icons;

  // Scoring
  final int  sets, gamesPerSet, tieBreakAt, tieBreakPoints, tieBreakDiff;
  final bool hasTieBreak, goldenPoint;

  // Callbacks — basic
  final void Function(String) onPreset, onSportType, onCategory, onIcon;
  // Callbacks — scoring
  final void Function(int)  onSets, onGamesPerSet, onTieBreakAt,
                             onTieBreakPoints, onTieBreakDiff;
  final void Function(bool) onHasTieBreak, onGoldenPoint;

  const _SportFormBody({
    required this.nameCtrl,
    required this.descCtrl,
    required this.notesCtrl,
    required this.sportType,
    required this.category,
    required this.icon,
    required this.preset,
    required this.categories,
    required this.icons,
    required this.sets,
    required this.gamesPerSet,
    required this.hasTieBreak,
    required this.tieBreakAt,
    required this.tieBreakPoints,
    required this.tieBreakDiff,
    required this.goldenPoint,
    required this.onPreset,
    required this.onSportType,
    required this.onCategory,
    required this.onIcon,
    required this.onSets,
    required this.onGamesPerSet,
    required this.onHasTieBreak,
    required this.onTieBreakAt,
    required this.onTieBreakPoints,
    required this.onTieBreakDiff,
    required this.onGoldenPoint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Quick preset picker ───────────────────────────
        _SectionTitle("Quick Presets"),
        const SizedBox(height: 8),
        Text(
          "Select Padel to auto-fill standard rules, or choose Custom to configure manually",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: SportPresets.presetNames.map((p) => _PresetChip(
            label:    p,
            selected: preset == p,
            onTap:    () => onPreset(p),
          )).toList(),
        ),

        const SizedBox(height: 24),
        const _Divider(),
        const SizedBox(height: 20),

        // ── Sport details ─────────────────────────────────
        _SectionTitle("Sport Details"),
        const SizedBox(height: 14),

        // Icon picker + name on same row
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _FieldLabel("Icon"),
            _IconPicker(selected: icon, icons: icons, onPick: onIcon),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel("Sport Name", required: true),
              TextFormField(
                controller: nameCtrl,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Sport name is required' : null,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
                decoration: _inputDeco(
                    "e.g. Padel", Icons.sports_outlined),
              ),
            ],
          )),
        ]),

        const SizedBox(height: 16),

        _FieldLabel("Description"),
        TextFormField(
          controller: descCtrl,
          minLines: 2, maxLines: 3,
          style: const TextStyle(fontSize: 14),
          decoration: _inputDeco(
              "Brief description of the sport...", Icons.info_outline),
        ),

        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel("Sport Type"),
              _SegmentControl(
                options:  const ['Individual', 'Team'],
                selected: sportType,
                onSelect: onSportType,
              ),
            ],
          )),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel("Category"),
              _StyledDropdown<String>(
                value:     category,
                items:     categories,
                label:     (c) => c,
                onChanged: onCategory,
              ),
            ],
          )),
          const SizedBox(width: 16),
          const Expanded(child: SizedBox()), // spacer
        ]),

        const SizedBox(height: 24),
        const _Divider(),
        const SizedBox(height: 20),

        // ── Scoring rules ─────────────────────────────────
        _SectionTitle("Scoring Rules"),
        const SizedBox(height: 6),
        Text(
          "Configure sets and games. Tiebreak uses a point-difference win condition.",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 16),

        // Sets + Games per set
        Row(children: [
          Expanded(child: _NumberField(
            label: "Sets to Play",
            value: sets, min: 1, max: 9,
            hint: "e.g. 3",
            onChanged: onSets,
          )),
          const SizedBox(width: 14),
          Expanded(child: _NumberField(
            label: "Games per Set",
            value: gamesPerSet, min: 1, max: 30,
            hint: "e.g. 6",
            onChanged: onGamesPerSet,
          )),
          const SizedBox(width: 14),
          const Expanded(child: SizedBox()),
        ]),

        const SizedBox(height: 20),

        // ── Tiebreak section ──────────────────────────────
        _TieBreakSection(
          hasTieBreak:     hasTieBreak,
          tieBreakAt:      tieBreakAt,
          tieBreakPoints:  tieBreakPoints,
          tieBreakDiff:    tieBreakDiff,
          goldenPoint:     goldenPoint,
          onHasTieBreak:   onHasTieBreak,
          onTieBreakAt:    onTieBreakAt,
          onTieBreakPoints:onTieBreakPoints,
          onTieBreakDiff:  onTieBreakDiff,
          onGoldenPoint:   onGoldenPoint,
        ),

        const SizedBox(height: 24),
        const _Divider(),
        const SizedBox(height: 20),

        // ── Notes ─────────────────────────────────────────
        _SectionTitle("Notes"),
        const SizedBox(height: 12),
        TextFormField(
          controller: notesCtrl,
          minLines: 2, maxLines: 4,
          style: const TextStyle(fontSize: 14),
          decoration: _inputDeco(
              "Any additional notes about this sport...",
              Icons.notes_rounded),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText:  hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        filled: true, fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF93C5FD), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF0A46D8), width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade600, width: 2)),
      );
}

// ── Tiebreak section widget ───────────────────────────────────
// Shows: enable toggle, trigger score, min points, win-by diff, golden point
class _TieBreakSection extends StatelessWidget {
  final bool hasTieBreak, goldenPoint;
  final int  tieBreakAt, tieBreakPoints, tieBreakDiff;
  final void Function(bool) onHasTieBreak, onGoldenPoint;
  final void Function(int)  onTieBreakAt, onTieBreakPoints, onTieBreakDiff;

  const _TieBreakSection({
    required this.hasTieBreak,
    required this.tieBreakAt,
    required this.tieBreakPoints,
    required this.tieBreakDiff,
    required this.goldenPoint,
    required this.onHasTieBreak,
    required this.onTieBreakAt,
    required this.onTieBreakPoints,
    required this.onTieBreakDiff,
    required this.onGoldenPoint,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasTieBreak
            ? const Color(0xFFF5F3FF)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasTieBreak
              ? const Color(0xFF7C3AED).withOpacity(0.35)
              : Colors.grey.shade200,
          width: hasTieBreak ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Header toggle row
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: hasTieBreak
                    ? const Color(0xFF7C3AED).withOpacity(0.12)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.sports_score_outlined,
                  size: 18,
                  color: hasTieBreak
                      ? const Color(0xFF7C3AED)
                      : Colors.grey.shade400),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tiebreak Rules",
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: hasTieBreak
                            ? const Color(0xFF5B21B6)
                            : const Color(0xFF374151))),
                Text(
                  hasTieBreak
                      ? "Win tiebreak by ${tieBreakDiff} points (min $tieBreakPoints pts)"
                      : "Tiebreak is disabled — sets use advantage",
                  style: TextStyle(
                      fontSize: 11,
                      color: hasTieBreak
                          ? const Color(0xFF7C3AED).withOpacity(0.7)
                          : Colors.grey.shade400),
                ),
              ],
            )),
            // Toggle switch
            GestureDetector(
              onTap: () => onHasTieBreak(!hasTieBreak),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 24,
                decoration: BoxDecoration(
                  color: hasTieBreak
                      ? const Color(0xFF7C3AED)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: hasTieBreak ? 22 : 2, top: 2,
                    child: Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ]),
              ),
            ),
          ]),

          // Expanded config — only shown when tiebreak is ON
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: hasTieBreak
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Tiebreak trigger + min points + win-by diff
                  Row(children: [
                    Expanded(child: _NumberField(
                      label:     "Trigger at (each side)",
                      value:     tieBreakAt, min: 1, max: 20,
                      hint:      "e.g. 6  →  triggers at 6-6",
                      onChanged: onTieBreakAt,
                    )),
                    const SizedBox(width: 14),
                    Expanded(child: _NumberField(
                      label:     "Min Points to Win",
                      value:     tieBreakPoints, min: 5, max: 30,
                      hint:      "e.g. 7",
                      onChanged: onTieBreakPoints,
                    )),
                    const SizedBox(width: 14),
                    Expanded(child: _NumberField(
                      label:     "Win by (difference)",
                      value:     tieBreakDiff, min: 1, max: 5,
                      hint:      "e.g. 2 → must win by 2 pts",
                      onChanged: onTieBreakDiff,
                    )),
                  ]),

                  const SizedBox(height: 14),

                  // Live preview banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF7C3AED).withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 15, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Tiebreak starts at $tieBreakAt-$tieBreakAt. "
                          "First to $tieBreakPoints+ points, "
                          "winning by at least $tieBreakDiff.",
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5B21B6),
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 14),

                  // Golden point toggle
                  _ToggleRow(
                    label:    "Golden Point at Game Deuce",
                    sublabel: "Sudden death instead of advantage — 1 point decides the game",
                    value:    goldenPoint,
                    onChanged: onGoldenPoint,
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SHARED DIALOG + WIDGETS
// ════════════════════════════════════════════════════════════

class _SportFormDialog extends StatelessWidget {
  final String title, subtitle, saveLabel;
  final bool   isEdit, saving;
  final VoidCallback onCancel, onSave;
  final Widget child;

  const _SportFormDialog({
    required this.title, required this.subtitle,
    required this.saveLabel, required this.isEdit,
    required this.saving, required this.onCancel,
    required this.onSave, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 820,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40, offset: const Offset(0, 16))],
        ),
        child: Column(children: [

          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
            decoration: BoxDecoration(
              color: isEdit
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFFF0F5FF),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isEdit
                      ? const Color(0xFFF59E0B).withOpacity(0.15)
                      : const Color(0xFF0A46D8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEdit ? Icons.edit_outlined : Icons.sports_outlined,
                  color: isEdit
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF0A46D8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFF0A1D4A))),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              )),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.close_rounded,
                        color: Colors.grey.shade600, size: 20),
                  ),
                ),
              ),
            ]),
          ),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
              child: child,
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Text("Cancel",
                    style: TextStyle(color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 14),
              Expanded(child: ElevatedButton(
                onPressed: saving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A46D8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(saveLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
              color: const Color(0xFF0A46D8),
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold,
            color: Color(0xFF0A1D4A))),
      ]);
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: Colors.grey.shade100);
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF374151))),
          if (required) ...[
            const SizedBox(width: 3),
            const Text("*",
                style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ]),
      );
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emoji = {'Padel': '🎾', 'Custom': '⚙️'}[label] ?? '🏅';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0A46D8) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? const Color(0xFF0A46D8)
                  : Colors.grey.shade200,
              width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [BoxShadow(
                  color: const Color(0xFF0A46D8).withOpacity(0.25),
                  blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF374151))),
        ]),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  final String selected;
  final List<String> icons;
  final void Function(String) onPick;
  const _IconPicker({required this.selected, required this.icons,
      required this.onPick});

  @override
  Widget build(BuildContext context) => Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F5FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF93C5FD), width: 1.5),
        ),
        child: PopupMenuButton<String>(
          tooltip: "Pick icon",
          offset: const Offset(56, 0),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: icons.map((e) => GestureDetector(
                  onTap: () {
                    onPick(e);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: selected == e
                          ? const Color(0xFF0A46D8).withOpacity(0.12)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: selected == e
                              ? const Color(0xFF0A46D8)
                              : Colors.transparent),
                    ),
                    child: Center(child: Text(e,
                        style: const TextStyle(fontSize: 20))),
                  ),
                )).toList(),
              ),
            ),
          ],
          child: Center(child: Text(selected,
              style: const TextStyle(fontSize: 24))),
        ),
      );
}

class _SegmentControl extends StatelessWidget {
  final List<String> options;
  final String selected;
  final void Function(String) onSelect;
  final Color activeColor;
  const _SegmentControl({required this.options, required this.selected,
      required this.onSelect,
      this.activeColor = const Color(0xFF0A46D8)});

  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: options.map((o) {
            final sel = o == selected;
            return Expanded(child: GestureDetector(
              onTap: () => onSelect(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: sel ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: sel
                      ? [BoxShadow(color: activeColor.withOpacity(0.3),
                          blurRadius: 6, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Center(child: Text(o,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel
                            ? Colors.white
                            : Colors.grey.shade500))),
              ),
            ));
          }).toList(),
        ),
      );
}

class _StyledDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final void Function(T) onChanged;
  const _StyledDropdown({required this.value, required this.items,
      required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: const Border.fromBorderSide(
              BorderSide(color: Color(0xFF93C5FD), width: 1.2)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade500),
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF0A1D4A),
                fontWeight: FontWeight.w500),
            items: items.map((i) => DropdownMenuItem<T>(
                value: i, child: Text(label(i)))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      );
}

class _NumberField extends StatelessWidget {
  final String label, hint;
  final int    value, min, max;
  final bool   enabled;
  final void Function(int) onChanged;

  const _NumberField({
    required this.label, required this.value,
    required this.min,   required this.max,
    required this.hint,  required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: const Border.fromBorderSide(
                  BorderSide(color: Color(0xFF93C5FD), width: 1.2)),
            ),
            child: Row(children: [
              _NumBtn(
                icon: Icons.remove_rounded,
                enabled: enabled && value > min,
                onTap: () { if (value > min) onChanged(value - 1); },
              ),
              Expanded(child: Center(child: Text(
                "$value",
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold,
                    color: enabled
                        ? const Color(0xFF0A1D4A)
                        : Colors.grey.shade400),
              ))),
              _NumBtn(
                icon: Icons.add_rounded,
                enabled: enabled && value < max,
                onTap: () { if (value < max) onChanged(value + 1); },
              ),
            ]),
          ),
        ],
      );
}

class _NumBtn extends StatelessWidget {
  final IconData icon;
  final bool     enabled;
  final VoidCallback onTap;
  const _NumBtn({required this.icon, required this.enabled,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 38, height: 46,
            child: Icon(icon, size: 18,
                color: enabled
                    ? const Color(0xFF0A46D8)
                    : Colors.grey.shade300),
          ),
        ),
      );
}

class _ToggleRow extends StatelessWidget {
  final String label, sublabel;
  final bool value;
  final void Function(bool) onChanged;
  const _ToggleRow({required this.label, required this.sublabel,
      required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFF0A46D8).withOpacity(0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: value
                    ? const Color(0xFF0A46D8).withOpacity(0.3)
                    : Colors.grey.shade200,
                width: value ? 1.5 : 1),
          ),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: value
                            ? const Color(0xFF0A46D8)
                            : const Color(0xFF374151))),
                const SizedBox(height: 2),
                Text(sublabel,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            )),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40, height: 22,
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFF0A46D8)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Stack(children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  left: value ? 20 : 2, top: 2,
                  child: Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
}