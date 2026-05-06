// lib/features/admin/teams/presentation/screens/add_team_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tms_flutter/features/admin/teams/data/models/team_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tms_flutter/core/session/app_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:typed_data';

class AddTeamScreen extends StatefulWidget {
  final String type;
  final List<TeamModel> existingTeams;
  final void Function(TeamModel) onSave;
  final TeamModel? editTeam; // non-null = edit mode

  const AddTeamScreen({
    super.key,
    required this.type,
    required this.existingTeams,
    required this.onSave,
    this.editTeam,
  });

  @override
  State<AddTeamScreen> createState() => _AddTeamScreenState();
}

class _AddTeamScreenState extends State<AddTeamScreen> {
  final String baseUrl = "https://dev.sports-next.com/api";
  String token = AppSession.token;
  String tournamentId = AppSession.tournamentId;

  late String type;

  List<TextEditingController> playerControllers = [];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _coachCtrl = TextEditingController();
  final _maxPlayersCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _sport = TeamModel.sports.first;
  bool _saving = false;

  bool get _isEdit => widget.editTeam != null;

  @override
  void initState() {
    super.initState();

    type = widget.type;

    if (_isEdit) {
      final t = widget.editTeam!;
      _nameCtrl.text = t.name;
      _coachCtrl.text = t.coachName;
      _maxPlayersCtrl.text = '${t.maxPlayers}';

      if (TeamModel.sports.contains(t.sport)) {
        _sport = t.sport;
      } else {
        _sport = TeamModel.sports.first;
      }
    } else {
      _maxPlayersCtrl.text = type == "individual" ? '2' : '5';
    }

    _maxPlayersCtrl.addListener(() {
      final count = int.tryParse(_maxPlayersCtrl.text) ?? 0;

      playerControllers = List.generate(count, (_) => TextEditingController());

      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _coachCtrl.dispose();
    _maxPlayersCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _genId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return 't${ts.substring(ts.length - 8)}';
  }

  void generatePlayerFields() {
    final max = int.tryParse(_maxPlayersCtrl.text) ?? 0;

    playerControllers = List.generate(max, (_) => TextEditingController());

    setState(() {});
  }

  Future<void> importExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null) return;

    Uint8List? bytes = result.files.single.bytes!;

    var excel = ex.Excel.decodeBytes(bytes!);

    List<String> names = [];

    for (var sheet in excel.tables.keys) {
      for (var row in excel.tables[sheet]!.rows) {
        if (row.isNotEmpty && row[0] != null) {
          names.add(row[0]!.value.toString());
        }
      }

      break;
    }

    playerControllers = names
        .map((name) => TextEditingController(text: name))
        .toList();

    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      http.Response response;

      print("UPDATE PAYLOAD:");

      print(
        json.encode({
          "name": _nameCtrl.text.trim(),
          "sport": _sport,
          "coach_name": _coachCtrl.text.trim(),
          "max_players": int.parse(_maxPlayersCtrl.text),
          "type": type,
          "tournament_id": int.parse(tournamentId),
        }),
      );

      if (_isEdit) {
        response = await http.put(
          Uri.parse("$baseUrl/teams/${widget.editTeam!.id}"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: json.encode({
            "name": _nameCtrl.text.trim(),
            "sport": _sport,
            "coach_name": _coachCtrl.text.trim(),
            "max_players": int.parse(_maxPlayersCtrl.text),
            "type": type,
            "tournament_id": int.parse(tournamentId),
            "event_id": widget.editTeam!.eventId,
          }),
        );

        print("UPDATE RESPONSE: ${response.body}");

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _snack("Team updated successfully");

          // 🔥 FIX: update UI
          widget.onSave(
            widget.editTeam!.copyWith(
              name: _nameCtrl.text.trim(),
              sport: _sport,
              coachName: _coachCtrl.text.trim(),
              maxPlayers: int.parse(_maxPlayersCtrl.text),
            ),
          );

          if (mounted) Navigator.pop(context);
        } else {
          print("ERROR RESPONSE: ${response.body}");
          _snack("Failed to update team", error: true);
        }
      } else {
        List<String> players = playerControllers
            .map((c) => c.text.trim())
            .where((p) => p.isNotEmpty)
            .toList();

        print("PLAYERS SENT: $players");

        response = await http.post(
          Uri.parse("$baseUrl/tournaments/$tournamentId/teams"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: json.encode({
            "name": _nameCtrl.text.trim(),
            "sport": _sport,
            "max_players": int.parse(_maxPlayersCtrl.text),
            "coach_name": _coachCtrl.text.trim(),
            "type": type,

            "players": type == "team_event" ? players : [],
          }),
        );

        print("UPDATE RESPONSE: ${response.body}");

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _snack("Team created successfully");

          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      print("TEAM SAVE ERROR: $e");
      _snack("Server error", error: true);
    }

    setState(() => _saving = false);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: error ? Colors.red.shade700 : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 680,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FF),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A46D8).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group_add_outlined,
                      color: Color(0xFF0A46D8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit Team' : 'Create New Team',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A1D4A),
                          ),
                        ),
                        Text(
                          _isEdit
                              ? 'Update team details below.'
                              : 'Fill in team details. Assign players after creation.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── SECTION 1: Team Identity ────────────────────────────
                      _SectionTitle('Team Identity'),
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _Field(
                              ctrl: _nameCtrl,
                              label: 'Team Name',
                              hint: 'e.g. Thunder Hawks',
                              icon: Icons.shield_outlined,
                              required: type == "team_event",
                              validator: (v) {
                                if (type == "team_event") {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Team name is required for team event';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _Field(
                              ctrl: _coachCtrl,
                              label: 'Coach Name',
                              hint: 'Optional',
                              icon: Icons.person_pin_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // ── SECTION 2: Sport & Roster Size ──────────────────────
                      _SectionTitle('Sport & Roster Size'),
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sport dropdown
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Sport', required: true),
                                Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF93C5FD),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: TeamModel.sports.contains(_sport)
                                          ? _sport
                                          : null,
                                      isExpanded: true,
                                      icon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.grey.shade500,
                                        size: 20,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF374151),
                                      ),
                                      items: TeamModel.sports
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null)
                                          setState(() => _sport = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Max Players — free number field
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Max Players', required: true),
                                TextFormField(
                                  enabled: type == "team_event",
                                  controller: _maxPlayersCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    // Cap at 3 digits so nobody enters 9999
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 6',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                    helperText: 'Number of player slots',
                                    helperStyle: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF93C5FD),
                                        width: 1.2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF0A46D8),
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.red.shade400,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.red.shade600,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return 'Required';
                                    final n = int.tryParse(v.trim());
                                    if (n == null || n < 2)
                                      return 'Min 2 players required';
                                    if (n > 50) return 'Max 50 players allowed';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Team Players Section ----------------------------------
                      if (type == "team_event")
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Team Players",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: importExcel,
                                  child: const Text("Import Excel"),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: generatePlayerFields,
                                  child: const Text("Generate Fields"),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            ...List.generate(playerControllers.length, (index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextFormField(
                                  controller: playerControllers[index],
                                  decoration: InputDecoration(
                                    labelText: "Player ${index + 1}",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),

                      const SizedBox(height: 22),

                      // ── SECTION 3: Notes ─────────────────────────────────────
                      _SectionTitle('Notes'),
                      const SizedBox(height: 16),
                      _Field(
                        ctrl: _notesCtrl,
                        label: 'Additional Notes',
                        hint: 'Optional — internal notes about this team',
                        icon: Icons.notes_outlined,
                        maxLines: 3,
                      ),

                      const SizedBox(height: 18),

                      // Info notice
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F5FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF0A46D8).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 15,
                              color: Color(0xFF0A46D8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isEdit
                                    ? 'Changes will update the team. Player roster is managed separately via "Manage Roster".'
                                    : 'Team is created in Draft status. '
                                          'Assign players via "Manage Roster" then publish when ready. '
                                          'A team can participate in multiple tournaments.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // ── Footer ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A46D8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEdit ? 'Save Changes' : 'Create Team',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED FORM WIDGETS  (StatelessWidget — safe everywhere)
// ─────────────────────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool required;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.required = false,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FieldLabel(label, required: required),
      TextFormField(
        controller: ctrl,
        validator: validator,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 2 : 1,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0A46D8), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade600, width: 2),
          ),
        ),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFF0A46D8),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0A1D4A),
        ),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF374151),
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text('*', style: TextStyle(color: Colors.red, fontSize: 13)),
        ],
      ],
    ),
  );
}
