import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tms_flutter/features/admin/players/data/models/player_model.dart';

// Place at: lib/features/admin/players/presentation/screens/edit_player_screen.dart

class EditPlayerScreen extends StatefulWidget {
  final PlayerModel player;
  final void Function(PlayerModel updated) onSave;
  const EditPlayerScreen({super.key, required this.player, required this.onSave});
  @override
  State<EditPlayerScreen> createState() => _EditPlayerScreenState();
}

class _EditPlayerScreenState extends State<EditPlayerScreen> {
  final _formKey     = GlobalKey<FormState>();
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _notesCtrl;

  late String _gender;
  late String _ageGroup;
  late String _skillLevel;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p    = widget.player;
    _firstCtrl   = TextEditingController(text: p.firstName);
    _lastCtrl    = TextEditingController(text: p.lastName);
    _emailCtrl   = TextEditingController(text: p.email);
    _phoneCtrl   = TextEditingController(text: p.phone);
    _cityCtrl    = TextEditingController(text: p.city);
    _stateCtrl   = TextEditingController(text: p.state);
    _countryCtrl = TextEditingController(text: p.country);
    _notesCtrl   = TextEditingController(text: p.notes);
    _gender      = PlayerModel.genders.contains(p.gender)     ? p.gender     : 'Male';
    _ageGroup    = PlayerModel.ageGroups.contains(p.ageGroup) ? p.ageGroup   : '18–30';
    _skillLevel  = PlayerModel.skillLevels.contains(p.skillLevel)
        ? p.skillLevel : 'Beginner';
  }

  @override
  void dispose() {
    for (final c in [_firstCtrl, _lastCtrl, _emailCtrl, _phoneCtrl,
      _cityCtrl, _stateCtrl, _countryCtrl, _notesCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final updated = widget.player.copyWith(
      firstName:  _firstCtrl.text.trim(),
      lastName:   _lastCtrl.text.trim(),
      email:      _emailCtrl.text.trim(),
      phone:      _phoneCtrl.text.trim(),
      gender:     _gender,
      ageGroup:   _ageGroup,
      skillLevel: _skillLevel,
      city:       _cityCtrl.text.trim(),
      state:      _stateCtrl.text.trim(),
      country:    _countryCtrl.text.trim(),
      notes:      _notesCtrl.text.trim(),
      updatedAt:  DateTime.now().toIso8601String(),
    );
    setState(() => _saving = false);
    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _PlayerFormDialog(
    title:     "Edit Player",
    subtitle:  'Editing profile of "${widget.player.fullName}"',
    saveLabel: "Update Player",
    isEdit:    true,
    saving:    _saving,
    onCancel:  () => Navigator.pop(context),
    onSave:    _save,
    child: Form(
      key: _formKey,
      child: _PlayerFormBody(
        firstCtrl:   _firstCtrl,   lastCtrl:    _lastCtrl,
        emailCtrl:   _emailCtrl,   phoneCtrl:   _phoneCtrl,
        cityCtrl:    _cityCtrl,    stateCtrl:   _stateCtrl,
        countryCtrl: _countryCtrl, notesCtrl:   _notesCtrl,
        gender:      _gender,      ageGroup:    _ageGroup,
        skillLevel:  _skillLevel,
        onGender:   (v) => setState(() => _gender     = v),
        onAgeGroup: (v) => setState(() => _ageGroup   = v),
        onSkill:    (v) => setState(() => _skillLevel = v),
      ),
    ),
  );
}

class _PlayerFormBody extends StatelessWidget {
  final TextEditingController firstCtrl, lastCtrl, emailCtrl, phoneCtrl,
      cityCtrl, stateCtrl, countryCtrl, notesCtrl;
  final String gender, ageGroup, skillLevel;
  final void Function(String) onGender, onAgeGroup, onSkill;

  const _PlayerFormBody({
    required this.firstCtrl, required this.lastCtrl,
    required this.emailCtrl, required this.phoneCtrl,
    required this.cityCtrl,  required this.stateCtrl,
    required this.countryCtrl, required this.notesCtrl,
    required this.gender,    required this.ageGroup,
    required this.skillLevel,required this.onGender,
    required this.onAgeGroup,required this.onSkill,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      // ── Personal Information ────────────────────────────────────────────────
      _SectionTitle("Personal Information"),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _Field(
          ctrl: firstCtrl, label: "First Name", hint: "e.g. Arjun",
          icon: Icons.person_outline, required: true,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'First name is required' : null,
        )),
        const SizedBox(width: 16),
        Expanded(child: _Field(
          ctrl: lastCtrl, label: "Last Name", hint: "e.g. Mehta",
          icon: Icons.person_outline, required: true,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Last name is required' : null,
        )),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _Field(
          ctrl: emailCtrl, label: "Email Address", hint: "player@email.com",
          icon: Icons.email_outlined, keyboard: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
            return null;
          },
        )),
        const SizedBox(width: 16),
        Expanded(child: _Field(
          ctrl: phoneCtrl, label: "Phone Number", hint: "e.g. 9876543210",
          icon: Icons.phone_outlined, keyboard: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10)],
        )),
      ]),

      const SizedBox(height: 24),
      Divider(height: 1, color: Colors.grey.shade100),
      const SizedBox(height: 22),

      // ── Player Attributes ───────────────────────────────────────────────────
      _SectionTitle("Player Attributes"),
      const SizedBox(height: 16),

      // Gender
      _FieldLabel("Gender", required: true),
      const SizedBox(height: 8),
      _ChipRow(
        options: PlayerModel.genders,
        selected: gender,
        color: const Color(0xFF0A46D8),
        onSelect: onGender,
      ),
      const SizedBox(height: 18),

      // Age group
      _FieldLabel("Age Group", required: true),
      const SizedBox(height: 8),
      _ChipRow(
        options: PlayerModel.ageGroups,
        selected: ageGroup,
        color: const Color(0xFF7C3AED),
        onSelect: onAgeGroup,
      ),
      const SizedBox(height: 18),

      // Skill level — visual selector cards
      _FieldLabel("Skill Level", required: true),
      const SizedBox(height: 8),
      _SkillSelector(selected: skillLevel, onSelect: onSkill),

      const SizedBox(height: 24),
      Divider(height: 1, color: Colors.grey.shade100),
      const SizedBox(height: 22),

      // ── Location ────────────────────────────────────────────────────────────
      _SectionTitle("Location"),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _Field(
          ctrl: cityCtrl, label: "City", hint: "e.g. Mumbai",
          icon: Icons.location_city_outlined,
        )),
        const SizedBox(width: 16),
        Expanded(child: _Field(
          ctrl: stateCtrl, label: "State", hint: "e.g. Maharashtra",
          icon: Icons.map_outlined,
        )),
        const SizedBox(width: 16),
        Expanded(child: _Field(
          ctrl: countryCtrl, label: "Country", hint: "e.g. India",
          icon: Icons.public_outlined,
        )),
      ]),

      const SizedBox(height: 24),
      Divider(height: 1, color: Colors.grey.shade100),
      const SizedBox(height: 22),

      // ── Notes ───────────────────────────────────────────────────────────────
      _SectionTitle("Notes"),
      const SizedBox(height: 12),
      _FieldLabel("Internal Notes (optional)"),
      TextFormField(
        controller: notesCtrl, minLines: 2, maxLines: 4,
        style: const TextStyle(fontSize: 14),
        decoration: _fieldDecoration(
            "Any additional notes about this player...", Icons.notes_rounded),
      ),
      const SizedBox(height: 24),
    ],
  );

  static InputDecoration _fieldDecoration(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0A46D8), width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade600, width: 2)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// SKILL SELECTOR — 4 visual cards
// ══════════════════════════════════════════════════════════════════════════════

class _SkillSelector extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;

  static const _data = [
    _SkillData('Beginner',     Icons.sports_outlined,      Color(0xFF16A34A), 'Just starting out'),
    _SkillData('Intermediate', Icons.trending_up_rounded,  Color(0xFF0A46D8), 'Plays regularly'),
    _SkillData('Advanced',     Icons.bolt_rounded,         Color(0xFF7C3AED), 'Tournament ready'),
    _SkillData('Professional', Icons.emoji_events_outlined,Color(0xFFDC2626), 'Elite competitor'),
  ];

  const _SkillSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => Row(
    children: _data.asMap().entries.map((entry) {
      final d     = entry.value;
      final isSel = selected == d.label;
      final isLast= entry.key == _data.length - 1;
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: isLast ? 0 : 10),
        child: GestureDetector(
          onTap: () => onSelect(d.label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              color: isSel ? d.color.withOpacity(0.07) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isSel ? d.color : Colors.grey.shade200,
                  width: isSel ? 2 : 1),
              boxShadow: isSel ? [BoxShadow(
                  color: d.color.withOpacity(0.15),
                  blurRadius: 8, offset: const Offset(0, 3))] : [],
            ),
            child: Column(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(
                    color: isSel ? d.color.withOpacity(0.12) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(d.icon,
                    color: isSel ? d.color : Colors.grey.shade400, size: 22)),
              const SizedBox(height: 8),
              Text(d.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: isSel ? d.color : Colors.grey.shade500)),
              const SizedBox(height: 3),
              Text(d.sub, style: TextStyle(fontSize: 10,
                  color: isSel ? d.color.withOpacity(0.7) : Colors.grey.shade400)),
            ]),
          ),
        ),
      ));
    }).toList(),
  );
}

class _SkillData {
  final String label, sub;
  final IconData icon;
  final Color color;
  const _SkillData(this.label, this.icon, this.color, this.sub);
}

// ══════════════════════════════════════════════════════════════════════════════
// CHIP ROW — gender / age group
// ══════════════════════════════════════════════════════════════════════════════

class _ChipRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final Color color;
  final void Function(String) onSelect;
  const _ChipRow({required this.options, required this.selected,
      required this.color, required this.onSelect});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8, runSpacing: 8,
    children: options.map((o) {
      final isSel = o == selected;
      return GestureDetector(
        onTap: () => onSelect(o),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? color : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSel ? color : Colors.grey.shade200,
                width: isSel ? 1.5 : 1),
            boxShadow: isSel ? [BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 6, offset: const Offset(0, 2))] : [],
          ),
          child: Text(o, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: isSel ? Colors.white : Colors.grey.shade600)),
        ),
      );
    }).toList(),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// DIALOG SHELL
// ══════════════════════════════════════════════════════════════════════════════

class _PlayerFormDialog extends StatelessWidget {
  final String title, subtitle, saveLabel;
  final bool isEdit, saving;
  final VoidCallback onCancel, onSave;
  final Widget child;
  const _PlayerFormDialog({
    required this.title, required this.subtitle, required this.saveLabel,
    required this.isEdit, required this.saving,
    required this.onCancel, required this.onSave, required this.child,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    child: Container(
      width: 800,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18),
              blurRadius: 40, offset: const Offset(0, 16))]),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
          decoration: BoxDecoration(
            color: isEdit ? const Color(0xFFFFF7ED) : const Color(0xFFF0F5FF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  color: isEdit
                      ? const Color(0xFFF59E0B).withOpacity(0.15)
                      : const Color(0xFF0A46D8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(
                  isEdit ? Icons.edit_outlined : Icons.person_add_outlined,
                  color: isEdit ? const Color(0xFFF59E0B) : const Color(0xFF0A46D8),
                  size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Color(0xFF0A1D4A))),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            MouseRegion(cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onCancel,
                child: Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.close_rounded,
                        color: Colors.grey.shade600, size: 20)),
              )),
          ]),
        ),
        // Scrollable body
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
          child: child,
        )),
        // Footer
        Container(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
          decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(top: BorderSide(color: Colors.grey.shade200))),
          child: Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.grey.shade300)),
              child: Text("Cancel",
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 14),
            Expanded(child: ElevatedButton(
              onPressed: saving ? null : onSave,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A46D8), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
                  : Text(saveLabel, style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            )),
          ]),
        ),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool required;
  final IconData icon;
  final TextInputType keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  const _Field({
    required this.ctrl, required this.label, required this.hint, required this.icon,
    this.required = false, this.keyboard = TextInputType.text,
    this.inputFormatters, this.validator,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FieldLabel(label, required: required),
      TextFormField(
        controller: ctrl, keyboardType: keyboard,
        inputFormatters: inputFormatters, validator: validator,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 1.2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0A46D8), width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade600, width: 2)),
        ),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 4, height: 18,
        decoration: BoxDecoration(color: const Color(0xFF0A46D8),
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 10),
    Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
        color: Color(0xFF0A1D4A))),
  ]);
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(children: [
      Text(text, style: const TextStyle(fontWeight: FontWeight.w600,
          fontSize: 13, color: Color(0xFF374151))),
      if (required) ...[
        const SizedBox(width: 3),
        const Text("*", style: TextStyle(color: Colors.red, fontSize: 13)),
      ],
    ]),
  );
}