// lib/features/admin/tournaments/presentation/screens/create_tournament_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/features/admin/venues/data/models/venue_model.dart';
import '/features/admin/tournaments/data/models/tournament_model.dart';
import '/features/admin/teams/data/models/team_model.dart';
import '/features/admin/players/data/models/player_model.dart';
import '../../data/services/tournament_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '/core/session/app_session.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

// ══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════

// 👇 ADD HERE (above CreateTournamentScreen)

class LocalTournamentSeeds {
  static List<Map<String, String>> sports = [
    {"id": "3", "name": "Padel"},
    {"id": "1", "name": "Cricket"},
    {"id": "2", "name": "Football"},
  ];

  static List<Map<String, String>> events = [
    {"id": "1", "name": "League"},
    {"id": "2", "name": "Knockout"},
  ];

  static List<Map<String, String>> venues = [];
}

class CreateTournamentScreen extends StatefulWidget {
  final List<TournamentModel> existing;
  final void Function(TournamentModel) onSave;
  final TournamentModel? editTournament;
  const CreateTournamentScreen({
    super.key,
    required this.existing,
    required this.onSave,
    this.editTournament,
  });
  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  List<TeamModel> _teams = [];
  List<TeamModel> _individualTeams = [];
  List<PlayerModel> _players = [];
  late String _currentTournamentId;
  String? _bannerUrl;
  String? _tournamentId;
  bool _dropdownReady = false;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  // Venue search
  final _venueSearchCtrl = TextEditingController();
  // Venue manual structured
  final _venueAddrCtrl = TextEditingController();
  final _venueCityCtrl = TextEditingController();
  final _venueStateCtrl = TextEditingController();
  final _venuePinCtrl = TextEditingController();
  final _venueCountryCtrl = TextEditingController();
  // Contact
  final _contactNameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  String? _sportId;
  String _sportName = '';
  String? _eventId;
  String _eventName = '';
  String? _venueId;
  String _venueName = '';
  bool _venueManualMode = false;
  bool _venueVerified = false;
  bool _venueSearching = false;
  List<Map<String, dynamic>> _venueResults = [];
  Timer? _venueDebounce;

  String? _participantType = 'Team';
  String _startDate = '', _endDate = '', _regDueDate = '';
  String _banner = '', _bannerName = '';
  List<_CategoryDraft> _categories = [];
  List<_SponsorDraft> _sponsors = [];
  bool _saving = false;

  bool get _isEdit => widget.editTournament != null;
  bool get _published =>
      _isEdit && widget.editTournament!.status == 'published';
  static const _indigo = Color(0xFF4F46E5);

  List<VenueModel> venues = [];

  // ── Date / Time helpers ───────────────────────────────────────

  static String _displayDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final parts = iso.split('-');
      if (parts.length != 3) return iso;
      return '${parts[2]}-${parts[1]}-${parts[0]}'; // DD-MM-YYYY
    } catch (_) {
      return iso;
    }
  }

  /// Converts 24hr "HH:mm" to 12hr "hh:mm AM/PM"
  static String _display12hr(String time24) {
    if (time24.isEmpty) return '';
    try {
      final parts = time24.split(':');
      int h = int.parse(parts[0]);
      final m = parts[1];
      final ampm = h >= 12 ? 'PM' : 'AM';
      if (h == 0)
        h = 12;
      else if (h > 12)
        h -= 12;
      return '${h.toString().padLeft(2, '0')}:$m $ampm';
    } catch (_) {
      return time24;
    }
  }

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (AppSession.token == null || AppSession.token!.isEmpty) {
        print("❌ TOKEN NOT READY");
        return;
      }

      loadTeams();
      loadIndividualTeams();
      loadPlayers();
      fetchVenues();
    });

    if (_isEdit) {
      _tournamentId = widget.editTournament!.id.toString();
      _loadTournamentDetails();
    } else {
      _categories = [_CategoryDraft.empty()];
      _dropdownReady = true;
    }
  }

  Future<void> fetchVenues() async {
    if (AppSession.token == null || AppSession.token!.isEmpty) {
      print("❌ NO TOKEN → skipping venues");
      return;
    }
    try {
      final response = await http.get(
        Uri.parse("https://dev.sports-next.com/api/venues"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AppSession.token}",
        },
      );

      final data = jsonDecode(response.body);

      final list = data['data'] ?? [];

      // 🔥 IMPORTANT: CLEAR OLD HARD CODE
      LocalTournamentSeeds.venues.clear();

      for (var v in list) {
        LocalTournamentSeeds.venues.add({
          "id": v['id'].toString(),
          "name": v['venue_name'] ?? '',
        });
      }

      print("✅ VENUES LOADED: ${LocalTournamentSeeds.venues}");

      if (!mounted) return;

      setState(() {
        _dropdownReady = true;
      });
    } catch (e) {
      print("❌ VENUE LOAD ERROR: $e");
    }
  }

  String _normalizeId(dynamic id) {
    if (id == null) return '';
    return int.tryParse(id.toString().trim())?.toString() ?? '';
  }

  Future<void> _loadTournamentDetails() async {
    if (_tournamentId == null) return;

    final res = await TournamentService.getTournamentById(_tournamentId!);

    if (res['success'] != true) return;

    final t = TournamentModel.fromJson(res['data']);

    print("SPORT ID RAW: ${t.sportId}");
    print("EVENT ID RAW: ${t.eventId}");
    print("VENUE ID RAW: ${t.venueId}");

    setState(() {
      _nameCtrl.text = t.name ?? '';
      _descCtrl.text = t.description ?? '';

      _contactNameCtrl.text = t.contactName ?? '';
      _contactEmailCtrl.text = t.contactEmail ?? '';
      _contactPhoneCtrl.text = t.contactPhone ?? '';

      _cityCtrl.text = t.city ?? '';
      _stateCtrl.text = t.state ?? '';
      _pinCtrl.text = t.pinCode ?? '';

      // ✅ SPORT
      final sId = _normalizeId(t.sportId);
      _sportId = sId.isEmpty ? null : sId;
      _sportName = t.sportName ?? '';
      print("SPORT ID CLEAN: $_sportId");

      // ✅ EVENT
      final eId = _normalizeId(t.eventId);
      _eventId = eId.isEmpty ? null : eId;
      _eventName = t.eventName ?? '';
      print("EVENT ID CLEAN: $_eventId");

      final cleanedVenueId = _normalizeId(t.venueId);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;

        setState(() {
          _venueName = t.venueName ?? '';

          if (cleanedVenueId.isEmpty) {
            _venueManualMode = true;
            _venueId = null;
          } else {
            _venueManualMode = false;

            final exists = LocalTournamentSeeds.venues.any(
              (v) => v['id'] == cleanedVenueId,
            );

            _venueId = exists ? cleanedVenueId : null;
          }
        });
      });

      print("VENUE ID CLEAN: $_venueId");

      // ✅ DATES
      _startDate = t.startDate ?? '';
      _endDate = t.endDate ?? '';
      _regDueDate = t.registrationDueDate ?? '';

      // ✅ BANNER
      _bannerUrl = t.banner ?? '';

      // ✅ PARTICIPANT TYPE
      final pt = t.subTypeLabel;
      _participantType = (pt == null || pt.isEmpty) ? 'Team' : pt;

      // ✅ DATA
      _categories = t.eventGroups
          .map((g) => _CategoryDraft.fromGroup(g))
          .toList();

      _sponsors = t.sponsors.map((s) => _SponsorDraft.fromModel(s)).toList();

      _dropdownReady = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _venueDebounce?.cancel();
    for (final c in [
      _nameCtrl,
      _descCtrl,
      _scrollCtrl,
      _venueSearchCtrl,
      _venueAddrCtrl,
      _venueCityCtrl,
      _venueStateCtrl,
      _venuePinCtrl,
      _venueCountryCtrl,
      _contactNameCtrl,
      _contactEmailCtrl,
      _contactPhoneCtrl,
      _cityCtrl,
      _stateCtrl,
      _pinCtrl,
    ])
      c.dispose();
    super.dispose();
  }

  Future<void> loadTeams() async {
    try {
      final response = await http.get(
        Uri.parse("https://dev.sports-next.com/api/master-individual-teams"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AppSession.token}",
        },
      );

      final data = jsonDecode(response.body);

      final list = data['data'] ?? [];

      if (!mounted) return;

      setState(() {
        _teams = (list as List)
            .map((e) => TeamModel.fromJson(e))
            .toList()
            .reversed 
            .toList();
      });

      print("✅ FILTERED TEAM MASTER: $_teams");
    } catch (e) {
      print("❌ TEAM LOAD ERROR: $e");
    }
  }

  Future<void> loadIndividualTeams() async {
    try {
      final response = await http.get(
        Uri.parse(
          "https://dev.sports-next.com/api/master-individual-only-teams",
        ),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AppSession.token}",
        },
      );

      final data = jsonDecode(response.body);

      final rawList = data['data'] as List;

      final teams = rawList
          .map<TeamModel>((e) => TeamModel.fromJson(e))
          .where(
            (t) =>
                t.type == 'individual' && t.isLocked && t.playerIds.isNotEmpty,
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _individualTeams = teams.reversed.toList(); 
      });

      print("🔥 FINAL INDIVIDUAL TEAMS COUNT: ${teams.length}");
      print("🔥 FINAL INDIVIDUAL TEAMS: $teams");
      print("✅ FINAL INDIVIDUAL TEAMS: $_individualTeams");
    } catch (e) {
      print("❌ INDIVIDUAL TEAM LOAD ERROR: $e");
    }
  }

  Future<void> loadPlayers() async {
    final res = await http.get(
      Uri.parse("https://dev.sports-next.com/api/players"),
      headers: {
        "Authorization": "Bearer ${AppSession.token}",
        "Accept": "application/json",
      },
    );

    final data = jsonDecode(res.body);

    if (!mounted) return;

    setState(() {
      _players = (data['data'] as List)
          .map((e) => PlayerModel.fromJson(e))
          .toList();
    });

    print("👤 PLAYERS LOADED: $_players");
  }

  // ── venue search (OpenStreetMap) ────────
  void _onVenueSearch(String query) {
    _venueDebounce?.cancel();
    if (query.length < 3) {
      setState(() {
        _venueResults = [];
        _venueSearching = false;
      });
      return;
    }
    setState(() {
      _venueSearching = true;
      _venueVerified = false;
    });
    _venueDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?format=json&addressdetails=1&limit=8&countrycodes=in&q=${Uri.encodeComponent(query)}',
        );
        final res = await http.get(
          uri,
          headers: {'User-Agent': 'TMS-Flutter-App/1.0'},
        );
        if (!mounted) return;
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List;
          setState(() {
            _venueResults = data.map((e) => e as Map<String, dynamic>).toList();
            _venueSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _venueSearching = false);
      }
    });
  }

  void _selectVenue(Map<String, dynamic> place) {
    final addr = place['address'] as Map<String, dynamic>? ?? {};
    final name = (place['display_name'] as String? ?? '')
        .split(',')
        .first
        .trim();
    final address = place['display_name'] as String? ?? '';
    final city =
        (addr['city'] ?? addr['town'] ?? addr['village'] ?? '') as String;
    final state = (addr['state'] ?? '') as String;
    final country = (addr['country'] ?? 'India') as String;

    setState(() {
      _venueManualMode = true;
      _venueVerified = true;
      _venueResults = [];
      _venueSearchCtrl.text = address;
      _venueAddrCtrl.text = address;
      _venueCityCtrl.text = city;
      _venueStateCtrl.text = state;
      _venuePinCtrl.text = (addr['postcode'] ?? '') as String;
      _venueCountryCtrl.text = country;
    });
  }

  void _clearVenueManual() {
    setState(() {
      _venueManualMode = false;
      _venueVerified = false;
      _venueResults = [];
      _venueSearchCtrl.clear();
      _venueAddrCtrl.clear();
      _venueCityCtrl.clear();
      _venueStateCtrl.clear();
      _venuePinCtrl.clear();
      _venueCountryCtrl.clear();
      _venueId = null;
      _venueName = '';
    });
  }

  String get _builtVenueManual {
    if (!_venueManualMode) return '';
    return [
      _venueAddrCtrl.text.trim(),
      _venueCityCtrl.text.trim(),
      _venueStateCtrl.text.trim(),
      _venuePinCtrl.text.trim(),
      _venueCountryCtrl.text.trim().isEmpty
          ? 'India'
          : _venueCountryCtrl.text.trim(),
    ].join('||');
  }

  Future<void> _pickBanner() async {
    print("TOURNAMENT ID: $_tournamentId");

    if (_tournamentId == null) {
      _snack("Please save tournament first", error: true);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // 🔥 IMPORTANT
    );

    if (result == null) return;

    final file = result.files.first;

    final bytes = file.bytes;

    if (bytes == null) {
      _snack("Failed to read file", error: true);
      return;
    }

    final request = http.MultipartRequest(
      "POST",
      Uri.parse(
        "https://dev.sports-next.com/api/tournaments/${_tournamentId}/banner",
      ),
    );

    request.headers["Authorization"] = "Bearer ${AppSession.token}";

    request.files.add(
      http.MultipartFile.fromBytes("banner", bytes, filename: file.name),
    );

    final response = await request.send();
    final resBody = await response.stream.bytesToString();

    print("📤 BANNER STATUS: ${response.statusCode}");
    print("📤 BANNER RESPONSE: $resBody");

    if (response.statusCode == 200) {
      final data = jsonDecode(resBody);

      setState(() {
        _bannerUrl =
            "${data['url']}?t=${DateTime.now().millisecondsSinceEpoch}";
      });

      _snack("Banner uploaded");
    } else {
      _snack("Upload failed", error: true);
    }
  }

  void _save(String status) async {
    print("🔥 SAVE CALLED: $status");

    if (status == 'published') {
      final hasNoFixtures = _categories.every((g) {
        if (g.format == 'custom') {
          return g.fixturesManual.isEmpty; // ❗ must have manual matches
        }

        final hasManual = g.fixturesManual.isNotEmpty;

        final hasAuto =
            g.participants.length >= 2 &&
            (g.format == 'knockout' || g.format == 'round_robin');

        return !(hasManual || hasAuto);
      });

      if (hasNoFixtures) {
        _snack("Add fixtures before publishing", error: true);
        return;
      }
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      print("❌ FORM INVALID");
      _snack("Fill required fields", error: true);
      return;
    }

    setState(() => _saving = true);

    final now = DateTime.now();
    final id = _tournamentId ?? 'trn_${now.millisecondsSinceEpoch}';

    _currentTournamentId = id;

    final groups = _categories.map((g) {
      final parts = g.participants.map((p) {
        print("P NAME: ${p.name}");
        print("P PLAYERS: ${p.players}");

        return ParticipantModel(
          id: p.id,
          name: (_participantType == 'Individual' && p.players.isNotEmpty)
              ? p.players.join(' & ')
              : p.name,
          playerNames: p.players,
          email: p.email,
          phone: p.phone,
        );
      }).toList();

      List<FixtureModel> fixtures = [];

      if (g.format == 'custom') {
        // ✅ FULL MANUAL ONLY
        fixtures = g.fixturesManual;
      } else {
        // ✅ KEEP OLD LOGIC (RR + KO untouched)
        fixtures = g.fixturesManual.isEmpty
            ? _autoFixtures(g.id, g.format, parts)
            : g.fixturesManual;
      }

      return EventGroup(
        id: g.id,
        eventName: g.categoryName,
        sportName: g.categoryName,
        format: g.format,
        participantType: _participantType ?? 'Team',
        gender: g.gender,
        maxParticipants: g.maxParticipants,
        participants: parts,
        fixtures: fixtures,
      );
    }).toList();

    final sponsorModels = _sponsors
        .asMap()
        .entries
        .map(
          (e) => SponsorModel(
            id: e.value.id,
            name: 'sponser',
            logoBase64: e.value.logoBase64,
            url: e.value.url,
            order: e.key,
          ),
        )
        .toList();

    final t = TournamentModel(
      id: id,
      name: _nameCtrl.text.trim(),

      subTypeLabel: _participantType ?? 'Team',

      sportId: _sportId ?? '',
      sportName: _sportName,

      eventId: _eventId ?? '',
      eventName: _eventName,

      venueId: _venueManualMode ? '' : (_venueId ?? ''),
      venueName: _venueManualMode ? '' : _venueName,
      venueManual: _builtVenueManual,

      startDate: _startDate,
      endDate: _endDate,
      registrationDueDate: _regDueDate,

      contactName: _contactNameCtrl.text.trim(),
      contactEmail: _contactEmailCtrl.text.trim(),
      contactPhone: _contactPhoneCtrl.text.trim(),

      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      pinCode: _pinCtrl.text.trim(),

      description: _descCtrl.text.trim(),

      status: status,

      eventGroups: groups, // keep this (model side)

      sponsors: sponsorModels,

      createdAt: _isEdit
          ? widget.editTournament!.createdAt
          : now.toIso8601String().substring(0, 10),
      updatedAt: now.toIso8601String().substring(0, 10),
    );

    try {
      print("SENDING GROUP IDS:");
      for (var g in _categories) {
        print("GROUP ID: ${g.eventGroupId}");
      }
      final data = {
        "name": t.name,

        "sport_id": t.sportId,
        "event_id": t.eventId,

        "venue_id": _venueManualMode
            ? null
            : (_venueId != null && _venueId!.isNotEmpty
                  ? int.parse(_venueId!)
                  : null),

        // 🔥 ONLY SEND venue_name IF MANUAL MODE
        if (_venueManualMode && _venueAddrCtrl.text.trim().isNotEmpty)
          "venue_name": _venueAddrCtrl.text.trim(),

        "start_date": t.startDate,
        "end_date": t.endDate,
        "registration_due_date": t.registrationDueDate,

        "contact_name": t.contactName,
        "contact_email": t.contactEmail,
        "contact_phone": t.contactPhone,

        "city": t.city,
        "state": t.state,
        "pin_code": t.pinCode,

        "description": t.description,

        "status": status,

        "event_groups": _categories.map((g) {
          return {
            "id": g.eventGroupId,
            "event_name": g.categoryName,

            // 🔥 MAIN FIX
            "format": g.format,

            "participant_type": _participantType,
            "gender": g.gender,
            "max_participants": g.maxParticipants,

            "participants": g.participants.map((p) {
              return {
                "id": p.id,
                "team_id": p.id, // ✅ IMPORTANT FIX
                "name": p.name,
              };
            }).toList(),

            "matches": g.fixturesManual.map((f) {
              return {
                "id": int.tryParse(f.id),
                "team_a_id": f.teamAId,
                "team_b_id": f.teamBId,
                "team_a_name": f.teamAName,
                "team_b_name": f.teamBName,
                "round": f.round,
                "match_number": f.matchNumber,
              };
            }).toList(),
          };
        }).toList(),
      };

      print("📤 FINAL DATA: ${jsonEncode(data)}");

      Map<String, dynamic> res;

      if (_isEdit) {
        res = await TournamentService.updateTournament(_tournamentId!, data);

        final fresh = await TournamentService.getTournamentById(_tournamentId!);

        setState(() {
          final t = TournamentModel.fromJson(fresh['data']);

          _categories = t.eventGroups.map((g) {
            // 🔥 ADD THIS LINE (EXACT PLACE)
            print("FROM API GROUP ID: ${g.id}");

            return _CategoryDraft.fromGroup(g);
          }).toList();
        });
      } else {
        print("📤 FINAL PAYLOAD: ${jsonEncode(data)}");

        res = await TournamentService.createTournament(data);

        if (!mounted) return;
      }

      if (res['success'] == true) {
        _tournamentId = res['data']['id'].toString();
        print("✅ TOURNAMENT ID: $_tournamentId");

        print("FULL RESPONSE: $res");

        final backendGroups = res['data']['event_groups'];

        print("BACKEND GROUPS: $backendGroups");
        print("FRONTEND GROUPS LENGTH: ${groups.length}");
        print("BACKEND GROUPS LENGTH: ${backendGroups?.length}");

        for (int i = 0; i < groups.length; i++) {
          final frontendGroup = groups[i];

          // 🔥 SAFE CHECK
          if (backendGroups == null || backendGroups.length <= i) {
            print("❌ BACKEND GROUPS MISMATCH");
            continue;
          }

          final backendGroup = backendGroups[i];

          final realGroupId = backendGroup['id'].toString();

          print("✅ USING REAL GROUP ID: $realGroupId");

          if (frontendGroup.fixtures.isNotEmpty) {
            await TournamentService.storeMatches(
              realGroupId.toString(),
              frontendGroup.fixtures
                  .map(
                    (f) => {
                      "id": f.id.startsWith("temp")
                          ? null
                          : int.tryParse(f.id.toString()),

                      "team_a_id": (f.teamAName == "BYE")
                          ? null
                          : int.tryParse(f.teamAId.toString()),

                      "team_b_id": (f.teamBName == "BYE")
                          ? null
                          : int.tryParse(f.teamBId.toString()),

                      "team_a_name": f.teamAName,
                      "team_b_name": f.teamBName,

                      "match_date": f.date ?? "",
                      "match_time": (f.time == null || f.time!.isEmpty)
                          ? null
                          : f.time,
                      "court": (f.court == null || f.court!.isEmpty)
                          ? null
                          : f.court,

                      "status": f.status,
                    },
                  )
                  .toList(),
            );
          }
        }
      }

      if (res['success'] == true && !_isEdit) {
        _tournamentId = res['data']['id'].toString();
      }

      if (res['success'] == true) {
        if (status == 'published') {
          await TournamentService.updateStatus(
            id,
            'published',
          ); // 🔥 FORCE PUBLISH

          if (!mounted) return;
        }

        if (!mounted) return;

        _snack(
          "Tournament ${status == 'draft' ? 'saved as draft' : 'published'}",
        );

        if (!mounted) return;

        Navigator.pop(context, true);
      } else {
        _snack(res['message'] ?? "Error", error: true);
      }
    } catch (e) {
      _snack("API Error", error: true);
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  List<FixtureModel> _autoFixtures(
    String gid,
    String fmt,
    List<ParticipantModel> parts,
  ) {
    if (fmt == 'knockout') return EventGroup.generateKnockout(gid, parts);
    if (fmt == 'round_robin') return EventGroup.generateRoundRobin(gid, parts);
    return [];
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);

    if (messenger == null) {
      // 🔥 fallback (dialog issue)
      ScaffoldMessenger.of(
        Navigator.of(context, rootNavigator: true).context,
      ).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? Colors.red : const Color(0xFF4F46E5),
        ),
      );
      return;
    }

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : const Color(0xFF4F46E5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        width: 980,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.93,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBasicInfo(),
                      const SizedBox(height: 20),

                      _dropdownReady
                          ? _buildDropdownRow()
                          : const SizedBox(height: 60),

                      const SizedBox(height: 16), // 🔥 ADD THIS SPACING

                      _buildVenueSection(),
                      const SizedBox(height: 20),

                      _buildDateBannerRow(),
                      const SizedBox(height: 20),

                      _buildContactLocationRow(),
                      const SizedBox(height: 20),

                      _buildDescriptionField(),
                      const SizedBox(height: 20),

                      _buildSponsorSection(),
                      const SizedBox(height: 20),

                      _buildCategoriesSection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(32, 22, 24, 22),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF6D28D9)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Row(
      children: [
        const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            _isEdit ? 'Edit Tournament' : 'Create Tournament',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        if (_published)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outlined, size: 13, color: Colors.white),
                SizedBox(width: 5),
                Text(
                  'Published',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    ),
  );

  // ── BASIC INFO: Tournament Name + Participant Type ─────────────
  Widget _buildBasicInfo() {
    final participantTypes = EventGroup.participantTypes
        .toSet()
        .toList(); // 🔥 REMOVE DUPLICATES

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _Field(
            label: 'Tournament Name *',
            child: TextFormField(
              controller: _nameCtrl,
              decoration: _deco('e.g. Mumbai Padel Open 2026'),
              validator: (_) => null,
            ),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: _Field(
            label: 'Participant Type',
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: ValueKey(
                    "participant_${_participantType ?? 'null'}",
                  ), // 🔥 FORCE REBUILD
                  value: participantTypes.contains(_participantType)
                      ? _participantType
                      : null,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF111827),
                  ),
                  items: participantTypes
                      .map(
                        (t) =>
                            DropdownMenuItem<String>(value: t, child: Text(t)),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _participantType = v ?? 'Team';
                    });
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? getSafeValue(String? value, List<Map<String, String>> items) {
    if (value == null || value.isEmpty) return null;

    try {
      final match = items.firstWhere((e) => e['id'] == value);
      return match['id'];
    } catch (e) {
      return null; // 🔥 FORCE SAFE
    }
  }

  // 🔥 REMOVE DUPLICATES
  List<Map<String, String>> getUniqueById(List<Map<String, String>> list) {
    return {for (var e in list) e['id']!: e}.values.toList();
  }

  // ── SPORT / EVENT / VENUE DROPDOWN ────────────────────────────
  Widget _buildDropdownRow() {
    final sports = getUniqueById(LocalTournamentSeeds.sports);
    final events = getUniqueById(LocalTournamentSeeds.events);
    final venues = getUniqueById(LocalTournamentSeeds.venues);

    return Row(
      children: [
        Expanded(
          child: _Field(
            label: 'Sport *',
            child: DropdownButtonFormField<String>(
              key: ValueKey("sport_${_sportId ?? 'null'}"),
              value: sports.any((e) => e['id'] == _sportId) ? _sportId : null,
              decoration: _deco('Select sport'),
              items: sports
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s['id']!,
                      child: Text(s['name']!),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                final s = sports.firstWhere((x) => x['id'] == v);
                setState(() {
                  _sportId = v;
                  _sportName = s['name']!;
                });
              },
              validator: (v) => v == null ? 'Select a sport' : null,
            ),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: _Field(
            label: 'Event *',
            child: DropdownButtonFormField<String>(
              key: ValueKey("event_${_eventId ?? 'null'}"),
              value: events.any((e) => e['id'] == _eventId) ? _eventId : null,
              decoration: _deco('Select event'),
              items: events
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e['id']!,
                      child: Text(e['name']!),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                final e = events.firstWhere((x) => x['id'] == v);
                setState(() {
                  _eventId = v;
                  _eventName = e['name']!;
                });
              },
              validator: (v) => v == null ? 'Select an event' : null,
            ),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: _Field(
            label: 'Venue (from list)',
            child: DropdownButtonFormField<String>(
              key: ValueKey("venue_${_venueId ?? 'null'}_${_venueManualMode}"),
              value: venues.any((e) => e['id'] == _venueId) ? _venueId : null,
              decoration: _deco('Select venue'),
              items: venues
                  .map(
                    (v) => DropdownMenuItem<String>(
                      value: v['id']!,
                      child: Text(v['name']!),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                final ve = venues.firstWhere((x) => x['id'] == v);
                setState(() {
                  _venueManualMode = false;
                  _venueId = v;
                  _venueName = ve['name']!;
                });
              },
              validator: (v) => (!_venueManualMode && v == null)
                  ? 'Select a venue or enter manually below'
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // ── VENUE SECTION — Google-Maps-style search ──────────────────
  Widget _buildVenueSection() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _indigo.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(
          children: [
            const Icon(Icons.location_on_rounded, size: 16, color: _indigo),
            const SizedBox(width: 6),
            const Text(
              'Venue Address (Manual Entry)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _indigo,
              ),
            ),
            const Spacer(),
            if (_venueManualMode)
              TextButton.icon(
                onPressed: _clearVenueManual,
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                ),
              ),
            if (!_venueManualMode)
              Text(
                'Or pick from dropdown above',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Search bar (Google Maps style)
        TextFormField(
          controller: _venueSearchCtrl,
          onChanged: _onVenueSearch,
          validator: (_) => null,
          decoration: InputDecoration(
            hintText: 'Search venue on map (e.g. Wankhede Stadium, Mumbai)...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: _venueSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _indigo,
                      ),
                    ),
                  )
                : Icon(
                    Icons.search_rounded,
                    color: _venueVerified
                        ? const Color(0xFF16A34A)
                        : Colors.grey.shade400,
                  ),
            suffixIcon: _venueVerified
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                    size: 20,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _venueVerified
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF93C5FD),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _indigo, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),

        // Search results dropdown
        if (_venueResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _venueResults.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (_, i) {
                final place = _venueResults[i];
                final name = place['display_name'] as String? ?? '';
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _selectVenue(place),
                    hoverColor: const Color(0xFFF0F5FF),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: _indigo,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Verified badge
        if (_venueVerified)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  'Location verified from map',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Structured address fields (shown when venue is selected or manual)
        if (_venueManualMode) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _Field(
                  label: 'Full Address',
                  child: TextFormField(
                    controller: _venueAddrCtrl,
                    decoration: _deco('Street, area, landmark...'),
                    validator: (_) => null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _Field(
                  label: 'City *',
                  child: TextFormField(
                    controller: _venueCityCtrl,
                    decoration: _deco('e.g. Mumbai'),
                    validator: (_) => null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _Field(
                  label: 'State *',
                  child: TextFormField(
                    controller: _venueStateCtrl,
                    decoration: _deco('e.g. Maharashtra'),
                    validator: (_) => null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'PIN',
                  child: TextFormField(
                    controller: _venuePinCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _deco('400001'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'Country',
                  child: TextFormField(
                    controller: _venueCountryCtrl,
                    decoration: _deco('India'),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() {
              _venueManualMode = true;
            }),
            child: Text(
              'Enter address manually instead →',
              style: TextStyle(
                fontSize: 11,
                color: _indigo,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildDateBannerRow() => Row(
    children: [
      Expanded(
        child: _Field(
          label: 'Start Date *',
          child: TextFormField(
            readOnly: true,
            controller: TextEditingController.fromValue(
              TextEditingValue(text: _displayDate(_startDate)),
            ),
            decoration: _deco('DD-MM-YYYY').copyWith(
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _startDate.isNotEmpty
                    ? DateTime.tryParse(_startDate) ?? DateTime.now()
                    : DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (d != null)
                setState(
                  () => _startDate = d.toIso8601String().substring(0, 10),
                );
            },
            validator: (v) => _startDate.isEmpty ? 'Required' : null,
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _Field(
          label: 'End Date *',
          child: TextFormField(
            readOnly: true,
            controller: TextEditingController.fromValue(
              TextEditingValue(text: _displayDate(_endDate)),
            ),
            decoration: _deco('DD-MM-YYYY').copyWith(
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _endDate.isNotEmpty
                    ? DateTime.tryParse(_endDate) ?? DateTime.now()
                    : DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (d != null)
                setState(() => _endDate = d.toIso8601String().substring(0, 10));
            },
            validator: (v) => _endDate.isEmpty ? 'Required' : null,
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _Field(
          label: 'Reg. Due Date',
          child: TextFormField(
            readOnly: true,
            controller: TextEditingController.fromValue(
              TextEditingValue(text: _displayDate(_regDueDate)),
            ),
            decoration: _deco('DD-MM-YYYY').copyWith(
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _regDueDate.isNotEmpty
                    ? DateTime.tryParse(_regDueDate) ?? DateTime.now()
                    : DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (d != null)
                setState(
                  () => _regDueDate = d.toIso8601String().substring(0, 10),
                );
            },
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _Field(
          label: 'Tournament Banner',
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: InkWell(
              onTap: _published ? null : _pickBanner,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _published ? Colors.grey.shade400 : _indigo,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _published ? 'Locked' : 'Upload',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _bannerName.isEmpty
                            ? (_banner.isNotEmpty
                                  ? '(existing)'
                                  : 'JPG/PNG ≤ 5MB')
                            : _bannerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildContactLocationRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          children: [
            _Field(
              label: 'Contact Name',
              child: TextFormField(
                controller: _contactNameCtrl,
                decoration: _deco('Organiser Name'),
              ),
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'Contact Email',
              child: TextFormField(
                controller: _contactEmailCtrl,
                decoration: _deco('email@example.com'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          children: [
            _Field(
              label: 'Contact Phone',
              child: TextFormField(
                controller: _contactPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _deco('+91 99999 99999'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'City',
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: _deco('Mumbai'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    label: 'State',
                    child: TextFormField(
                      controller: _stateCtrl,
                      decoration: _deco('Maharashtra'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildDescriptionField() => _Field(
    label: 'About this Tournament',
    child: TextFormField(
      controller: _descCtrl,
      maxLines: 3,
      decoration: _deco('Say something about this tournament...'),
    ),
  );

  Widget _buildSponsorSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _sectionTitle('Sponsors', Icons.business_rounded),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _indigo.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_sponsors.length}/10',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _indigo,
              ),
            ),
          ),

          const Spacer(),
          if (_sponsors.length < 10)
            _AddBtn(
              label: '+ Add Sponsor',
              onTap: () async {
                // MUST HAVE TOURNAMENT ID
                if (_tournamentId == null) {
                  _snack("Please save tournament first", error: true);
                  return;
                }

                // PICK IMAGE
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  withData: true,
                );

                if (result == null) return;

                final file = result.files.first;

                if (file.bytes == null) {
                  _snack("File read failed", error: true);
                  return;
                }

                final urlController = TextEditingController();

                final resultDialog = await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Add Sponsor"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: urlController,
                          decoration: const InputDecoration(
                            labelText: "URL (optional)",
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Save"),
                      ),
                    ],
                  ),
                );

                if (resultDialog != true) return;

                final res = await TournamentService.addSponsor(
                  _tournamentId!,
                  file.bytes!,
                  file.name,
                  "sponsor", // REAL NAME
                  urlController.text, // REAL URL
                );

                // UPDATE UI
                if (res != null) {
                  final list = await TournamentService.getSponsors(
                    _tournamentId!,
                  );

                  setState(() {
                    _sponsors = list.map((e) {
                      return _SponsorDraft(
                        id: e['id'].toString(),
                        name: e['name'] ?? '',

                        logoBase64: e['logo'] != null
                            ? "https://dev.sports-next.com/storage/${e['logo']}"
                            : '',

                        url: e['url'] ?? '',
                      );
                    }).toList();
                  });

                  _snack("Sponsor added");
                } else {
                  _snack("Upload failed", error: true);
                }
              },
            ),
        ],
      ),

      const SizedBox(height: 12),
      if (_sponsors.isEmpty)
        _EmptyHint('No sponsors yet. Add up to 10.')
      else
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _sponsors.length,
          onReorder: (o, n) {
            setState(() {
              if (n > o) n--;
              final s = _sponsors.removeAt(o);
              _sponsors.insert(n, s);
            });
          },
          itemBuilder: (_, i) => _SponsorRow(
            key: ValueKey(_sponsors[i].id),
            draft: _sponsors[i],
            index: i,

            onRemove: () async {
              final ok = await TournamentService.deleteSponsor(
                _tournamentId!,
                _sponsors[i].id!,
              );

              if (ok) {
                setState(() => _sponsors.removeAt(i));
                _snack("Deleted");
              } else {
                _snack("Delete failed", error: true);
              }
            },

            onEdit: () async {
              final d = await _showSponsorDialog(
                context,
                existing: _sponsors[i],
              );

              if (d != null) {
                final updated = await TournamentService.updateSponsor(
                  d.id!,
                  "sponsor",
                  d.url,
                );

                if (updated) {
                  final list = await TournamentService.getSponsors(
                    _tournamentId!,
                  );

                  setState(() {
                    _sponsors = list
                        .map(
                          (e) => _SponsorDraft(
                            id: e['id'].toString(),
                            name: e['name'] ?? '',
                            logoBase64: e['logo'] != null
                                ? "https://dev.sports-next.com/storage/${e['logo']}"
                                : '',
                            url: e['url'] ?? '',
                          ),
                        )
                        .toList();
                  });
                }
              }
            },
          ),
        ),
    ],
  );

  Widget _buildCategoriesSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _sectionTitle('Categories', Icons.category_outlined),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _indigo.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_categories.length}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _indigo,
              ),
            ),
          ),
          const Spacer(),
          _AddBtn(
            label: '+ Add Category',
            onTap: () =>
                setState(() => _categories.add(_CategoryDraft.empty())),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        "Each category is a separate division (e.g. Men's Doubles, Women's Singles)",
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),

      const SizedBox(height: 16),

      ..._categories.asMap().entries.map((e) {
        final isIndividual = _participantType == 'Individual';

        final teamsToPass = isIndividual ? _individualTeams : _teams;

        // 🔥 HARD GUARD (NO WRONG DATA EVER)
        final safeTeamsToPass = _participantType == 'Individual'
            ? _individualTeams
            : _teams;

        // 🔥 FORCE FIX (IMPORTANT)
        print("PARTICIPANT TYPE: $_participantType");
        print("PASSING TEAMS: ${teamsToPass.length}");

        if (_participantType == 'Individual' && teamsToPass.isEmpty) {
          return const SizedBox(); // or loader
        }

        return _CategoryCard(
          key: ValueKey(e.value.id),
          index: e.key,
          draft: e.value,
          published: _published,
          participantType: _participantType ?? 'Team',
          teams: safeTeamsToPass,
          players: _players,
          onRemove: () => setState(() => _categories.removeAt(e.key)),
          onChange: (updated) => setState(() => _categories[e.key] = updated),
          tournamentId: int.tryParse(_tournamentId ?? '') ?? 0,
        );
      }),
    ],
  );

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.fromLTRB(32, 14, 32, 18),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      border: Border(top: BorderSide(color: Colors.grey.shade200)),
    ),

    child: Row(
      children: [
        Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 8),

        Expanded(
          child: Text(
            'Changes saved locally until connected to API.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ),

        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(width: 10),
        if (!_published)
          OutlinedButton(
            onPressed: _saving
                ? null
                : () {
                    print("🔥 DRAFT CLICKED");
                    _save('draft');
                  },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              side: const BorderSide(color: _indigo),
              foregroundColor: _indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            child: const Text(
              'Save Draft',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),

        const SizedBox(width: 10),

        ElevatedButton.icon(
          onPressed: _saving
              ? null
              : () {
                  print("🔥 PUBLISH CLICKED");
                  _save('published');
                },
          icon: const Icon(Icons.publish_rounded, size: 17),
          label: const Text(
            'Publish',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ),
  );

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _indigo, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.red),
    ),
    filled: true,
    fillColor: Colors.white,
  );

  Widget _sectionTitle(String t, IconData icon) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _indigo.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: _indigo),
      ),
      const SizedBox(width: 10),
      Text(
        t,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF111827),
        ),
      ),
    ],
  );

  Future<_SponsorDraft?> _showSponsorDialog(
    BuildContext ctx, {
    _SponsorDraft? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    String logoB64 = existing?.logoBase64 ?? '';
    return showDialog<_SponsorDraft>(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Add Sponsor' : 'Edit Sponsor',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Divider(height: 20, color: Colors.grey.shade200),
                GestureDetector(
                  onTap: () async {
                    final res = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      withData: true,
                    );
                    if (res?.files.first.bytes == null) return;
                    final bytes = res!.files.first.bytes!;
                    if (bytes.lengthInBytes > 2 * 1024 * 1024) return;
                    setS(() => logoB64 = base64Encode(bytes));
                  },
                  child: Container(
                    height: 90,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: logoB64.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 28,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Click to upload logo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: logoB64.isNotEmpty
                                ? Image.network(
                                    logoB64.startsWith('http')
                                        ? logoB64
                                        : "https://dev.sports-next.com/storage/${logoB64.replaceAll("\\", "/")}",
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.image),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: nameCtrl,
                  decoration: _deco('Sponsor Name *'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: urlCtrl,
                  decoration: _deco('Website URL (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(
                  dCtx,
                  _SponsorDraft(
                    id:
                        existing?.id ??
                        'sp_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim(),
                    logoBase64: logoB64,
                    url: urlCtrl.text.trim(),
                  ),
                );
              },
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CATEGORY CARD
// ══════════════════════════════════════════════════════════════
class _CategoryCard extends StatefulWidget {
  final int index;
  final _CategoryDraft draft;
  final bool published;
  final String participantType;
  final List<TeamModel> teams;
  final List<PlayerModel> players;
  final VoidCallback onRemove;
  final void Function(_CategoryDraft) onChange;
  final int tournamentId;

  const _CategoryCard({
    super.key,
    required this.index,
    required this.draft,
    required this.published,
    required this.participantType,
    required this.teams,
    required this.players,
    required this.onRemove,
    required this.onChange,
    required this.tournamentId,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  late _CategoryDraft _d;
  final _nameCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  static const _indigo = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _d = widget.draft;
    _nameCtrl.text = _d.categoryName;
    _maxCtrl.text = _d.maxParticipants > 0 ? '${_d.maxParticipants}' : '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _emit() => widget.onChange(_d);

  bool get _isTeam => true;

  void _generateFixtures() {
    final parts = _d.participants
        .where((p) => p.name.trim().isNotEmpty)
        .map(
          (p) => ParticipantModel(
            id: p.id,
            name:
                (widget.participantType == 'Individual' && p.players.isNotEmpty)
                ? p.players.join(' & ')
                : p.name,
            playerNames: p.players,
            email: p.email,
            phone: p.phone,
          ),
        )
        .toList();
    if (parts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 2 participants with names'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    List<FixtureModel> fixtures;
    if (_d.format == 'knockout') {
      fixtures = EventGroup.generateKnockout(_d.id, parts);
    } else if (_d.format == 'round_robin') {
      fixtures = EventGroup.generateRoundRobin(_d.id, parts);
    } else {
      fixtures = [];
    }
    setState(() => _d = _d.copyWith(fixturesManual: fixtures));
    _emit();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✓ Generated ${fixtures.length} fixtures for ${_d.categoryName.isEmpty ? "this category" : _d.categoryName}',
        ),
        backgroundColor: _indigo,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _pickFromTeamMaster() async {
    final isIndividual = widget.participantType == 'Individual';

    // 🔥 LOCK DATA BEFORE OPENING PICKER
    final teamsToUse = isIndividual
        ? widget.teams.where((t) => t.playerIds.isNotEmpty).toList()
        : widget.teams;

    final result = await showDialog<List<_ParticipantDraft>>(
      context: context,
      builder: (_) => _TeamMasterPicker(
        existingIds: _d.participants.map((p) => p.id).toList(),
        teams: teamsToUse,
        players: widget.players,
      ),
    );

    // 🔥 MOUNTED CHECK (IMPORTANT)
    if (!mounted) return;

    if (result != null && result.isNotEmpty) {
      final updated = result.map((team) {
        return _ParticipantDraft(
          id: team.id,
          name:
              (widget.participantType == 'Individual' &&
                  team.players.isNotEmpty)
              ? team.players.join(' & ')
              : team.name,
          players: team.players,
          email: '',
          phone: '',
          teamId: team.id,
          seed: '',
        );
      }).toList();

      setState(() {
        _d = _d.copyWith(
          participants: [..._d.participants, ...updated],
          fixturesManual: [],
        );
      });

      _emit();
    }
  }

  // ── Pick from Player Master (Individual mode) ─────────────────
  void _pickFromPlayerMaster() async {
    final result = await showDialog<List<_ParticipantDraft>>(
      context: context,
      builder: (_) => _PlayerMasterPicker(
        existingIds: _d.participants.map((p) => p.id).toList(),
        players: widget.players,
      ),
    );

    if (result != null && result.isNotEmpty) {
      final existing = _d.participants.where((p) => p.name.isNotEmpty).toList();

      // ✅ FIX: NO teamId for players
      final updated = result.map((p) {
        return _ParticipantDraft(
          id: p.id,
          name: p.name,
          players: p.players,
          email: p.email,
          phone: p.phone,

          teamId: null, // 🔥 IMPORTANT
          seed: '',
        );
      }).toList();

      setState(() {
        _d = _d.copyWith(
          participants: [...existing, ...updated],
          fixturesManual: [],
        );
      });

      _emit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Added ${updated.length} player(s) from Player Master',
          ),
          backgroundColor: const Color(0xFF0891B2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /*
  Future<void> saveParticipants() async {
    try {
      if (_d.eventGroupId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Event group not found"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final participants = _d.participants
          .where((p) => p.name.trim().isNotEmpty)
          .map(
            (p) => {
              "team_id": p.teamId,
              "name": p.name,
              "players": p.players,
              "seed": p.seed,
            },
          )
          .toList();

      if (participants.isEmpty) return;

      final url = Uri.parse(
        "https://dev.sports-next.com/api/tournaments/${widget.tournamentId}/participants",
      );

      print("TOURNAMENT ID: ${widget.tournamentId}");
      print("EVENT GROUP ID (FINAL): ${_d.eventGroupId}");
      print("PARTICIPANTS: ${_d.participants}");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer ${AppSession.token}", // 🔥 DYNAMIC TOKEN
        },
        body: jsonEncode({
          "event_group_id": _d.eventGroupId,
          "participants": participants,
        }),
      );

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Participants saved"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Failed to save participants"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print(e);
    }
  }
    */

  /* ── Import Excel / CSV file ────────────────────────────────────
  void _importExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );

    if (result == null || result.files.first.bytes == null) return;

    final file = result.files.first;
    final bytes = file.bytes!;
    final name = file.name.toLowerCase();
    List<_ParticipantDraft> parsed = [];

    try {
      if (name.endsWith('.csv')) {
        final content = String.fromCharCodes(bytes);
        final lines = content
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        final startIdx =
            (lines.isNotEmpty &&
                (lines[0].toLowerCase().contains('name') ||
                    lines[0].toLowerCase().contains('player') ||
                    lines[0].toLowerCase().contains('team')))
            ? 1
            : 0;

        for (int i = startIdx; i < lines.length; i++) {
          final cols = lines[i].contains('\t')
              ? lines[i]
                    .split('\t')
                    .map((c) => c.trim().replaceAll('"', ''))
                    .toList()
              : lines[i]
                    .split(',')
                    .map((c) => c.trim().replaceAll('"', ''))
                    .toList();

          if (cols.isEmpty || cols[0].isEmpty) continue;

          if (_isTeam) {
            final teamName = cols[0];
            final p1 = cols.length > 1 ? cols[1] : '';
            final p2 = cols.length > 2 ? cols[2] : '';
            final players = [p1, p2].where((s) => s.isNotEmpty).toList();

            parsed.add(
              _ParticipantDraft(
                id: 'pt_imp_${DateTime.now().millisecondsSinceEpoch}_$i',
                name: teamName,
                players: players,
                teamId: null,
                seed: '',
              ),
            );
          } else {
            final firstName = cols[0];
            final surname = cols.length > 1 ? cols[1] : '';
            final email = cols.length > 2 ? cols[2] : '';
            final phone = cols.length > 3 ? cols[3] : '';
            final fullName = [
              firstName,
              surname,
            ].where((s) => s.isNotEmpty).join(' ');

            if (fullName.isEmpty) continue;

            parsed.add(
              _ParticipantDraft(
                id: 'pt_imp_${DateTime.now().millisecondsSinceEpoch}_$i',
                name: fullName,
                players: [
                  if (firstName.isNotEmpty) firstName,
                  if (surname.isNotEmpty) surname,
                ],
                email: email,
                phone: phone,
                teamId: null,
                seed: '',
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For Excel files: Save as CSV first, then import. Or use Paste option.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      if (parsed.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No valid rows found. Check file format.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _ImportPreviewDialog(
          participants: parsed,
          isTeam: _isTeam,
          fileName: file.name,
        ),
      );

      if (confirmed == true && mounted) {
        final existing = _d.participants
            .where((p) => p.name.isNotEmpty)
            .toList();
        setState(
          () => _d = _d.copyWith(
            participants: [...existing, ...parsed],
            fixturesManual: [],
          ),
        );
        _emit();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Imported ${parsed.length} ${_isTeam ? "team" : "player"}(s) from ${file.name}',
            ),
            backgroundColor: const Color(0xFF7C3AED),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to parse file: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  } */

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _indigo.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            decoration: BoxDecoration(
              color: _indigo.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _indigo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Category ${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                if (_d.categoryName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '— ${_d.categoryName}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _indigo.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.participantType,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _indigo,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!widget.published)
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Colors.red.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Name + Gender + Max
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _Field(
                        label: 'Category Name *',
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: _deco("e.g. Women's Doubles"),
                          onChanged: (v) {
                            _d = _d.copyWith(categoryName: v);
                            _emit();
                          },
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? 'Category name required'
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: _Field(
                        label: 'Gender',
                        child: DropdownButtonFormField<String>(
                          value: _d.gender,
                          decoration: _deco(''),
                          items: EventGroup.genders
                              .map(
                                (g) =>
                                    DropdownMenuItem(value: g, child: Text(g)),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _d = _d.copyWith(gender: v!));
                            _emit();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: _Field(
                        label: 'Max Participants',
                        child: TextFormField(
                          controller: _maxCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _deco('e.g. 16'),
                          onChanged: (v) {
                            _d = _d.copyWith(
                              maxParticipants: int.tryParse(v) ?? 0,
                            );
                            _emit();
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Format selector
                _Field(
                  label: 'Tournament Format',
                  child: _FormatSelector(
                    selected: _d.format,
                    disabled: widget.published,
                    onChanged: (f) {
                      setState(
                        () => _d = _d.copyWith(format: f, fixturesManual: []),
                      );
                      _emit();
                    },
                  ),
                ),

                // Format info hint
                const SizedBox(height: 8),
                _buildFormatHint(),

                const SizedBox(height: 20),

                // Participants header
                Row(
                  children: [
                    const Text(
                      'Participants',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _indigo.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_d.participants.where((p) => p.name.isNotEmpty).length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _indigo,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Show "From Team Master" for Team/Pair, "From Player Master" for Individual
                    if (_isTeam)
                      _SmallBtn(
                        label: 'From Team Master',
                        icon: Icons.groups_rounded,
                        active: false,
                        color: const Color(0xFF16A34A),
                        onTap: _pickFromTeamMaster,
                      )
                    else
                      _SmallBtn(
                        label: 'From Player Master',
                        icon: Icons.person_search_rounded,
                        active: false,
                        color: const Color(0xFF0891B2),
                        onTap: _pickFromPlayerMaster,
                      ),
                    const SizedBox(width: 8),

                    /* Import Excel button
                    _SmallBtn(
                      label: 'Import Excel',
                      icon: Icons.upload_file_rounded,
                      active: false,
                      color: const Color(0xFF7C3AED),
                      onTap: _importExcel,
                    ), */

                    /*
                    const SizedBox(width: 8),
                    _SmallBtn(
                      label: '+ Add Row',
                      icon: Icons.add_rounded,
                      active: false,
                      onTap: () {
                        setState(() {
                          _d = _d.copyWith(
                            participants: [
                              ..._d.participants,
                              _ParticipantDraft(
                                id: 'pt_${DateTime.now().millisecondsSinceEpoch}_${_d.participants.length}',
                                name: '',
                                players: [],
                              ),
                            ],
                          );
                        });
                      },
                    ),
                    */
                  ],
                ),

                const SizedBox(height: 12),

                // Excel grid - uses row-level widgets
                _ExcelGrid(
                  key: ValueKey(_d.id),
                  participants: _d.participants,
                  isTeam: _isTeam,
                  participantType: widget.participantType,
                  onChanged: (updated) {
                    setState(
                      () => _d = _d.copyWith(
                        participants: updated,
                        fixturesManual: [],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                /*
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saveParticipants,
                    child: const Text("Save Participants"),
                  ),
                ),

                const SizedBox(height: 10),
                  */
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _d.participants
                                .where((p) => p.name.trim().isNotEmpty)
                                .length <
                            2
                        ? null
                        : _generateFixtures,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: Text(
                      _d.format == 'knockout'
                          ? 'Auto-Generate Knockout Bracket'
                          : _d.format == 'round_robin'
                          ? 'Auto-Generate Round Robin'
                          : 'Generate Custom Fixtures',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                // Editable fixture list
                if (_d.fixturesManual.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _EditableFixtureList(
                    fixtures: _d.fixturesManual,
                    participants: _d.participants,
                    onChanged: (updated) {
                      setState(() => _d = _d.copyWith(fixturesManual: updated));
                      _emit();
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatHint() {
    String hint = '';
    Color color = Colors.grey.shade600;
    if (_d.format == 'knockout') {
      final count = _d.participants
          .where((p) => p.name.trim().isNotEmpty)
          .length;
      if (count >= 2) {
        int size = 1;
        while (size < count) size *= 2;
        final rounds = <String>[];
        if (size >= 16) rounds.add('Round of 16');
        if (size >= 8) rounds.add('Quarter-Final');
        if (size >= 4) rounds.add('Semi-Final');
        rounds.add('Final');
        hint = 'With $count participants → ${rounds.join(' → ')}';
        if (size > count)
          hint += ' (${size - count} BYE${size - count > 1 ? 's' : ''})';
      } else {
        hint =
            '16 teams: Round of 16 → QF → SF → Final  |  8 teams: QF → SF → Final  |  4 teams: SF → Final';
      }
      color = const Color(0xFFEF4444);
    } else if (_d.format == 'round_robin') {
      final count = _d.participants
          .where((p) => p.name.trim().isNotEmpty)
          .length;
      final matches = count > 1 ? count * (count - 1) ~/ 2 : 0;
      hint = count >= 2
          ? 'With $count participants → $matches total matches (everyone plays everyone)'
          : 'Every team plays every other team once. Total matches = n×(n-1)/2';
      color = const Color(0xFF6366F1);
    } else if (_d.format == 'custom') {
      hint = 'Manually create and schedule fixtures after adding participants';
      color = const Color(0xFFF59E0B);
    }
    if (hint.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 13, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _indigo, width: 2),
    ),
    filled: true,
    fillColor: Colors.white,
  );
}

// ══════════════════════════════════════════════════════════════
// EXCEL GRID
// Columns (Team mode):  # | Team Name | Player 1 | Player 2 | ×
// Columns (Individual): # | First Name | Surname  | Email   | Phone | ×
// ══════════════════════════════════════════════════════════════
class _ExcelGrid extends StatefulWidget {
  final List<_ParticipantDraft> participants;
  final bool isTeam;
  final void Function(List<_ParticipantDraft>) onChanged;
  final String participantType;

  const _ExcelGrid({
    super.key,
    required this.participants,
    required this.isTeam,
    required this.onChanged,
    required this.participantType,
  });

  @override
  State<_ExcelGrid> createState() => _ExcelGridState();
}

class _ExcelGridState extends State<_ExcelGrid> {
  bool _showPaste = false;
  final _pasteCtrl = TextEditingController();

  static const _hdrBg = Color(0xFF1E1B4B);
  static const _borderCol = Color(0xFFD1D5DB);
  static const _indigo = Color(0xFF4F46E5);

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  void _removeRow(int idx) {
    final updated = List<_ParticipantDraft>.from(widget.participants)
      ..removeAt(idx);
    widget.onChanged(updated);
  }

  void _updateRow(int index, _ParticipantDraft updated) {
    final list = [...widget.participants];

    list[index] = updated; // ✅ FULL REPLACE (CRITICAL)

    widget.onChanged(list);
  }

  void _doPaste() {
    final raw = _pasteCtrl.text.trim();
    if (raw.isEmpty) return;
    final rows = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final added = <_ParticipantDraft>[];
    for (final row in rows) {
      final cols = row.split('\t').map((c) => c.trim()).toList();
      if (cols.isEmpty || cols[0].isEmpty) continue;
      if (widget.isTeam) {
        final teamName = cols[0];
        final p1 = cols.length > 1 ? cols[1] : '';
        final p2 = cols.length > 2 ? cols[2] : '';
        final players = [p1, p2].where((s) => s.isNotEmpty).toList();
        added.add(
          _ParticipantDraft(
            id: 'pt_${DateTime.now().millisecondsSinceEpoch}_${added.length}',
            name: teamName,
            players: players,
          ),
        );
      } else {
        // Individual: col0=FirstName, col1=Surname, col2=Email, col3=Phone
        final firstName = cols[0];
        final surname = cols.length > 1 ? cols[1] : '';
        final email = cols.length > 2 ? cols[2] : '';
        final phone = cols.length > 3 ? cols[3] : '';
        final fullName = [
          firstName,
          surname,
        ].where((s) => s.isNotEmpty).join(' ');
        if (fullName.isEmpty) continue;
        added.add(
          _ParticipantDraft(
            id: 'pt_${DateTime.now().millisecondsSinceEpoch}_${added.length}',
            name: fullName,
            players: [
              if (firstName.isNotEmpty) firstName,
              if (surname.isNotEmpty) surname,
            ],
            email: email,
            phone: phone,
          ),
        );
      }
    }
    if (added.isEmpty) return;
    // Remove empty placeholder rows first, then add pasted
    final existing = widget.participants
        .where((p) => p.name.trim().isNotEmpty)
        .toList();
    widget.onChanged([...existing, ...added]);
    setState(() {
      _showPaste = false;
      _pasteCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _indigo.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.content_paste_rounded, size: 14, color: _indigo),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Paste from Excel / Google Sheets (Tab-separated)',
                  style: TextStyle(
                    fontSize: 11,
                    color: _indigo,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showPaste = !_showPaste),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _indigo,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _showPaste ? 'Hide' : 'Paste',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        /*
        if (_showPaste) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _indigo.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _indigo.withOpacity(0.06),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.isTeam
                              ? 'Format: Team Name [TAB] Player 1 [TAB] Player 2'
                              : 'Format: First Name [TAB] Surname [TAB] Email (optional) [TAB] Phone (optional)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextField(
                  controller: _pasteCtrl,
                  maxLines: 6,
                  minLines: 4,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: widget.isTeam
                        ? 'Thunder Hawks\tArjun Mehta\tPriya Sharma\nDesert Eagles\tRahul Gupta\tNeha Patel'
                        : 'Arjun\tMehta\tarjun@email.com\t9876543210\nPriya\tSharma\tpriya@email.com',
                    hintStyle: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade300,
                      fontFamily: 'monospace',
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Copy cells from Excel/Sheets (Ctrl+C) then paste above',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _doPaste,
                        icon: const Icon(Icons.upload_rounded, size: 14),
                        label: const Text(
                          'Import',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ], */

        // ── Spreadsheet table ─────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderCol),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              Container(
                color: _hdrBg,
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 36,
                      child: Center(
                        child: Text(
                          '#',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                    if (widget.isTeam) ...[
                      _hdrCell('Team Name', flex: 3),
                      _hdrCell('Player 1', flex: 2),
                      _hdrCell('Player 2', flex: 2),
                    ] else ...[
                      _hdrCell('First Name *', flex: 2),
                      _hdrCell('Surname *', flex: 2),
                      _hdrCell('Email', flex: 2),
                      _hdrCell('Phone', flex: 2),
                    ],
                    const SizedBox(width: 36),
                  ],
                ),
              ),

              ...widget.participants.asMap().entries.map(
                (e) => _ExcelRow(
                  key: ValueKey(e.value.id),
                  index: e.key,
                  draft: e.value,
                  isTeam: widget.isTeam,
                  isEven: e.key.isEven,
                  onChanged: (updatedRow) {
                    _updateRow(e.key, updatedRow);
                  },
                  onRemove: () => _removeRow(e.key),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hdrCell(String label, {required int flex}) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white24, width: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    ),
  );
}

class _ExcelRow extends StatefulWidget {
  final int index;
  final _ParticipantDraft draft;
  final bool isTeam;
  final bool isEven;
  final void Function(_ParticipantDraft) onChanged;
  final VoidCallback onRemove;
  const _ExcelRow({
    super.key,
    required this.index,
    required this.draft,
    required this.isTeam,
    required this.isEven,
    required this.onChanged,
    required this.onRemove,
  });
  @override
  State<_ExcelRow> createState() => _ExcelRowState();
}

class _ExcelRowState extends State<_ExcelRow> {
  // Team mode: teamName / player1 / player2
  late final TextEditingController _teamCtrl;
  late final TextEditingController _p1Ctrl;
  late final TextEditingController _p2Ctrl;
  // Individual mode: firstName / surname / email / phone
  late final TextEditingController _firstCtrl;
  late final TextEditingController _surnameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  static const _borderCol = Color(0xFFD1D5DB);

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    // Team mode
    _teamCtrl = TextEditingController(text: d.name);
    _p1Ctrl = TextEditingController(
      text: d.players.isNotEmpty ? d.players[0] : '',
    );
    _p2Ctrl = TextEditingController(
      text: d.players.length > 1 ? d.players[1] : '',
    );
    // Individual mode — stored as: name="First Surname", players=[first, surname]
    _firstCtrl = TextEditingController(
      text: d.players.isNotEmpty ? d.players[0] : d.name.split(' ').first,
    );
    _surnameCtrl = TextEditingController(
      text: d.players.length > 1
          ? d.players[1]
          : (d.name.contains(' ') ? d.name.split(' ').skip(1).join(' ') : ''),
    );
    _emailCtrl = TextEditingController(text: d.email);
    _phoneCtrl = TextEditingController(text: d.phone);
  }

  @override
  void didUpdateWidget(covariant _ExcelRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    final d = widget.draft;

    // 🔥 ONLY UPDATE IF VALUE CHANGED (IMPORTANT)
    if (_teamCtrl.text != d.name) {
      _teamCtrl.text = d.name;
    }

    final p1 = d.players.isNotEmpty ? d.players[0] : '';
    if (_p1Ctrl.text != p1) {
      _p1Ctrl.text = p1;
    }

    final p2 = d.players.length > 1 ? d.players[1] : '';
    if (_p2Ctrl.text != p2) {
      _p2Ctrl.text = p2;
    }

    final first = d.players.isNotEmpty ? d.players[0] : d.name.split(' ').first;

    if (_firstCtrl.text != first) {
      _firstCtrl.text = first;
    }

    final surname = d.players.length > 1
        ? d.players[1]
        : (d.name.contains(' ') ? d.name.split(' ').skip(1).join(' ') : '');

    if (_surnameCtrl.text != surname) {
      _surnameCtrl.text = surname;
    }

    if (_emailCtrl.text != d.email) {
      _emailCtrl.text = d.email;
    }

    if (_phoneCtrl.text != d.phone) {
      _phoneCtrl.text = d.phone;
    }
  }

  @override
  void dispose() {
    _teamCtrl.dispose();
    _p1Ctrl.dispose();
    _p2Ctrl.dispose();
    _firstCtrl.dispose();
    _surnameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _emitTeam() {
    final players = <String>[];
    if (_p1Ctrl.text.trim().isNotEmpty) players.add(_p1Ctrl.text.trim());
    if (_p2Ctrl.text.trim().isNotEmpty) players.add(_p2Ctrl.text.trim());
    widget.onChanged(
      _ParticipantDraft(
        id: widget.draft.id,
        name: _teamCtrl.text.trim(),
        players: players,
        email: '',
        phone: '',
      ),
    );
  }

  void _emitIndividual() {
    final first = _firstCtrl.text.trim();
    final surname = _surnameCtrl.text.trim();
    final fullName = [first, surname].where((s) => s.isNotEmpty).join(' ');
    widget.onChanged(
      _ParticipantDraft(
        id: widget.draft.id,
        name: fullName,
        players: [if (first.isNotEmpty) first, if (surname.isNotEmpty) surname],
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rowColor = widget.isEven ? const Color(0xFFFAFBFF) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: rowColor,
        border: const Border(top: BorderSide(color: _borderCol, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            child: Center(
              child: Text(
                '${widget.index + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ),
          if (widget.isTeam) ...[
            _cell(_teamCtrl, 'Team name...', onChanged: (_) {}, flex: 3),
            _cell(_p1Ctrl, 'Player 1...', onChanged: (_) {}, flex: 2),
            _cell(_p2Ctrl, 'Player 2...', onChanged: (_) {}, flex: 2),
          ] else ...[
            _cell(_firstCtrl, 'First name *', onChanged: (_) {}, flex: 2),
            _cell(_surnameCtrl, 'Surname *', onChanged: (_) {}, flex: 2),
            _cell(_emailCtrl, 'Email', onChanged: (_) {}, flex: 2),
            _cell(
              _phoneCtrl,
              'Phone',
              onChanged: (_) => _emitIndividual(),
              flex: 2,
            ),
          ],

          SizedBox(
            width: 36,
            child: Center(
              child: GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: Colors.red.shade400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    TextEditingController ctrl,
    String hint, {
    required void Function(String) onChanged,
    required int flex,
  }) => Expanded(
    flex: flex,
    child: Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _borderCol, width: 0.5)),
      ),
      child: TextField(
        controller: ctrl,
        onChanged: (v) {
          if (widget.isTeam) {
            _emitTeam();
          } else {
            _emitIndividual();
          }
        },
        style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade300),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// TEAM MASTER PICKER DIALOG
// ══════════════════════════════════════════════════════════════
class _TeamMasterPicker extends StatefulWidget {
  final List<String> existingIds;
  final List<TeamModel> teams;
  final List<PlayerModel> players;

  const _TeamMasterPicker({
    required this.existingIds,
    required this.teams,
    required this.players,
  });

  @override
  State<_TeamMasterPicker> createState() => _TeamMasterPickerState();
}

class _TeamMasterPickerState extends State<_TeamMasterPicker> {
  final Set<String> _selected = {};
  String _search = '';
  static const _indigo = Color(0xFF4F46E5);

  List<TeamModel> get _filtered => widget.teams.where((t) {
    if (widget.existingIds.contains(t.id)) return false;

    // 🔥 IMPORTANT (only real teams)
    if (t.playerIds.isEmpty) return false;

    if (_search.isEmpty) return true;

    return t.name.toLowerCase().contains(_search.toLowerCase());
  }).toList();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Select from Team Master',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
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

            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search teams...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
                ),
              ),
            ),
            // Team list
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No teams found',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final team = _filtered[i];
                        final isSel = _selected.contains(team.id);

                        final playerNames = team.playerIds.isEmpty
                            ? ['No Players']
                            : team.playerIds.map((pid) {
                                final player = widget.players.firstWhere(
                                  (p) => p.id.toString() == pid.toString(),
                                  orElse: () => PlayerModel(
                                    id: '',
                                    firstName: 'Unknown',
                                    lastName: pid.toString(),
                                    email: '',
                                    phone: '',
                                    gender: '',
                                    ageGroup: '',
                                    skillLevel: '',
                                    city: '',
                                    state: '',
                                    country: '',
                                    notes: '',
                                    isActive: true,
                                    createdAt: '',
                                    updatedAt: '',
                                    history: [],
                                    isPlaying: false,
                                    eventId: 0,
                                    type: 'individual',
                                  ),
                                );
                                return player.fullName;
                              }).toList();

                        return GestureDetector(
                          onTap: () => setState(() {
                            if (isSel)
                              _selected.remove(team.id);
                            else
                              _selected.add(team.id);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? _indigo.withOpacity(0.06)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? _indigo : Colors.grey.shade200,
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isSel ? _indigo : Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isSel
                                          ? _indigo
                                          : Colors.grey.shade400,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSel
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 13,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _indigo.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.shield_rounded,
                                    size: 18,
                                    color: _indigo,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        playerNames.join(' & '),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSel
                                              ? _indigo
                                              : const Color(0xFF111827),
                                        ),
                                      ),
                                      if (playerNames.isNotEmpty)
                                        Text(
                                          playerNames.join('  •  '),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
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
                                    color: team.statusColor.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    team.status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: team.statusColor,
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

            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Text(
                    '${_selected.length} selected',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            final drafts = widget.teams
                                .where((t) => _selected.contains(t.id))
                                .map((team) {
                                  final playerNames = team.playerIds.map((pid) {
                                    final player = widget.players.firstWhere(
                                      (p) => p.id.toString() == pid.toString(),
                                    );

                                    return player.fullName;
                                  }).toList();

                                  return _ParticipantDraft(
                                    id: team.id,
                                    name: team.name, // ✅ clean now
                                    players: playerNames,
                                    email: '',
                                    phone: '',
                                    teamId: team.id,
                                    seed: '',
                                  );
                                })
                                .toList();

                            Navigator.pop(context, drafts);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'Add Selected',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

// ══════════════════════════════════════════════════════════════
// PLAYER MASTER PICKER DIALOG — for Individual participant type
// ══════════════════════════════════════════════════════════════
class _PlayerMasterPicker extends StatefulWidget {
  final List<String> existingIds;
  final List<dynamic> players;
  const _PlayerMasterPicker({required this.existingIds, required this.players});
  @override
  State<_PlayerMasterPicker> createState() => _PlayerMasterPickerState();
}

class _PlayerMasterPickerState extends State<_PlayerMasterPicker> {
  final Set<String> _selected = {};
  String _search = '';
  String _filterGender = '';
  String _filterSkill = '';
  static const _cyan = Color(0xFF0891B2);

  List<String> get _genders =>
      widget.players.map((p) => (p.gender ?? '').toString()).toSet().toList()
        ..sort();
  List<String> get _skillLevels =>
      widget.players
          .map((p) => (p.skillLevel ?? '').toString())
          .toSet()
          .toList()
        ..sort();

  List<PlayerModel> get _filteredPlayers => widget.players
      .where((p) {
        if (widget.existingIds.contains(p.id)) return false;

        if (_search.isNotEmpty &&
            !(p.fullName ?? '').toLowerCase().contains(_search.toLowerCase()) &&
            !(p.city ?? '').toLowerCase().contains(_search.toLowerCase())) {
          return false;
        }

        if (_filterGender.isNotEmpty && p.gender != _filterGender) return false;
        if (_filterSkill.isNotEmpty && p.skillLevel != _filterSkill)
          return false;

        return true;
      })
      .cast<PlayerModel>()
      .toList();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0891B2), Color(0xFF0369A1)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_search_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Select Individual Teams',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
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

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search by name or city...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _filterChip(
                          'Gender',
                          _filterGender,
                          ['', ..._genders],
                          (v) => setState(() => _filterGender = v),
                        ),
                      ),
                      const SizedBox(width: 8),

                      Expanded(
                        child: _filterChip(
                          'Skill',
                          _filterSkill,
                          ['', ..._skillLevels],
                          (v) => setState(() => _filterSkill = v),
                        ),
                      ),
                      const SizedBox(width: 8),

                      GestureDetector(
                        onTap: () => setState(() {
                          if (_filteredPlayers.every(
                            (t) => _selected.contains(t.id),
                          )) {
                            _selected.removeAll(
                              _filteredPlayers.map((t) => t.id),
                            );
                          } else {
                            _selected.addAll(_filteredPlayers.map((t) => t.id));
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _cyan.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _cyan.withOpacity(0.3)),
                          ),
                          child: Text(
                            _filteredPlayers.every(
                                  (p) => _selected.contains(p.id),
                                )
                                ? 'Deselect All'
                                : 'Select All',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _cyan,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Player list
            Expanded(
              child: _filteredPlayers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No players found',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                      itemCount: _filteredPlayers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final player = _filteredPlayers[i];
                        final isSel = _selected.contains(player.id);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (isSel)
                              _selected.remove(player.id);
                            else
                              _selected.add(player.id);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? _cyan.withOpacity(0.06)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? _cyan : Colors.grey.shade200,
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Checkbox
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isSel ? _cyan : Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isSel
                                          ? _cyan
                                          : Colors.grey.shade400,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSel
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 13,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                // Avatar
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: player.avatarColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      player.initials,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: player.avatarColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        player.fullName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSel
                                              ? _cyan
                                              : const Color(0xFF111827),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          if (player.city.isNotEmpty) ...[
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 11,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              player.city,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          if (player.email.isNotEmpty)
                                            Text(
                                              player.email,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade400,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: player.skillColor.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    player.skillLevel ?? '',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: player.skillColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Gender badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    player.gender ?? '',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
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

            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Text(
                    '${_selected.length} selected',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            final drafts = widget.players
                                .where((p) => _selected.contains(p.id))
                                .map(
                                  (p) => _ParticipantDraft(
                                    id: p.id,
                                    name: p.fullName,
                                    players:
                                        [
                                              (p.firstName ?? '').toString(),
                                              (p.lastName ?? '').toString(),
                                            ]
                                            .where((s) => s.isNotEmpty)
                                            .toList()
                                            .cast<String>(),
                                    email: p.email,
                                    phone: p.phone,
                                  ),
                                )
                                .toList();
                            Navigator.pop(context, drafts);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cyan,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'Add Selected',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _filterChip(
    String label,
    String value,
    List<String> options,
    void Function(String) onChanged,
  ) => Container(
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: value.isNotEmpty ? _cyan : Colors.grey.shade300,
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
                  o.isEmpty ? 'All $label' : o,
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
// IMPORT PREVIEW DIALOG — shows parsed rows before confirming import
// ══════════════════════════════════════════════════════════════
class _ImportPreviewDialog extends StatelessWidget {
  final List<_ParticipantDraft> participants;
  final bool isTeam;
  final String fileName;
  const _ImportPreviewDialog({
    required this.participants,
    required this.isTeam,
    required this.fileName,
  });

  static const _purple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.upload_file_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Import Preview',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'From: $fileName',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: _purple.withOpacity(0.05),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${participants.length} ${isTeam ? "team" : "player"}(s) ready to import',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  const SizedBox(
                    width: 32,
                    child: Text(
                      '#',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      isTeam ? 'Team Name' : 'Full Name',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      isTeam ? 'Players' : 'Email',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  if (!isTeam)
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Phone',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: participants.length,
                itemBuilder: (_, i) {
                  final p = participants[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.white : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            (p.players != null && p.players.isNotEmpty)
                                ? p.players.join(' & ')
                                : p.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            isTeam
                                ? p.players.join(' / ')
                                : (p.email.isNotEmpty ? p.email : '—'),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isTeam)
                          Expanded(
                            flex: 2,
                            child: Text(
                              p.phone.isNotEmpty ? p.phone : '—',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'These will be added to existing participants.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.upload_rounded, size: 15),
                    label: Text(
                      'Import ${participants.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
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

// ══════════════════════════════════════════════════════════════
// FORMAT SELECTOR
// ══════════════════════════════════════════════════════════════
class _FormatSelector extends StatelessWidget {
  final String selected;
  final bool disabled;
  final void Function(String) onChanged;
  const _FormatSelector({
    required this.selected,
    required this.disabled,
    required this.onChanged,
  });

  static const _formats = [
    _FmtInfo(
      id: 'round_robin',
      name: 'Round Robin',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFF6366F1),
      desc: 'Everyone vs Everyone',
    ),
    _FmtInfo(
      id: 'knockout',
      name: 'Knockout',
      icon: Icons.account_tree_rounded,
      color: Color(0xFFEF4444),
      desc: 'Single Elimination',
    ),
    _FmtInfo(
      id: 'custom',
      name: 'Custom',
      icon: Icons.tune_rounded,
      color: Color(0xFFF59E0B),
      desc: 'Manual Scheduling',
    ),
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: _formats.map((f) {
      final isSel = selected == f.id;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: disabled ? null : () => onChanged(f.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: isSel ? f.color.withOpacity(0.08) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? f.color : Colors.grey.shade200,
                  width: isSel ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isSel ? f.color : Colors.grey.shade400)
                          .withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      f.icon,
                      color: isSel ? f.color : Colors.grey.shade400,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    f.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSel ? f.color : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    f.desc,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSel
                          ? f.color.withOpacity(0.7)
                          : Colors.grey.shade400,
                    ),
                  ),
                  if (isSel) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: f.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Selected',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: f.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class _FmtInfo {
  final String id, name, desc;
  final IconData icon;
  final Color color;
  const _FmtInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.desc,
  });
}

// ══════════════════════════════════════════════════════════════
// EDITABLE FIXTURE LIST
// ══════════════════════════════════════════════════════════════
class _EditableFixtureList extends StatefulWidget {
  final List<FixtureModel> fixtures;
  final List<_ParticipantDraft> participants;
  final void Function(List<FixtureModel>) onChanged;
  const _EditableFixtureList({
    required this.fixtures,
    required this.participants,
    required this.onChanged,
  });
  @override
  State<_EditableFixtureList> createState() => _EditableFixtureListState();
}

class _EditableFixtureListState extends State<_EditableFixtureList> {
  late List<FixtureModel> _fixtures;
  static const _indigo = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _fixtures = List.from(widget.fixtures);
  }

  @override
  void didUpdateWidget(_EditableFixtureList old) {
    super.didUpdateWidget(old);
    if (old.fixtures != widget.fixtures)
      setState(() => _fixtures = List.from(widget.fixtures));
  }

  void _emit() => widget.onChanged(_fixtures);

  String _getPlayerNames(String teamName) {
    final p = widget.participants.where((p) => p.name == teamName).toList();
    if (p.isEmpty || p.first.players.isEmpty) return '';
    return p.first.players.join(' / ');
  }

  void _editFixture(int i) async {
    final f = _fixtures[i];
    final validNames = widget.participants
        .map((p) => p.name)
        .where((n) => n.isNotEmpty)
        .toList();
    String selA = validNames.contains(f.teamAName)
        ? f.teamAName
        : (validNames.isNotEmpty ? validNames.first : '');
    String selB = validNames.contains(f.teamBName)
        ? f.teamBName
        : (validNames.isNotEmpty ? validNames.first : '');

    final result = await showDialog<FixtureModel>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 460,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_rounded, color: _indigo, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Fixture — ${f.round}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Divider(height: 20, color: Colors.grey.shade200),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Team A',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _participantDropdown(
                            validNames,
                            selA,
                            (v) => setS(() => selA = v),
                          ),
                          if (_getPlayerNames(selA).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _getPlayerNames(selA),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'vs',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Team B',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _participantDropdown(
                            validNames,
                            selB,
                            (v) => setS(() => selB = v),
                          ),
                          if (_getPlayerNames(selB).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _getPlayerNames(selB),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(
                ctx,
                f.copyWith(
                  teamAName: selA.isEmpty ? f.teamAName : selA,
                  teamBName: selB.isEmpty ? f.teamBName : selB,
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() => _fixtures[i] = result);
      _emit();
    }
  }

  Widget _participantDropdown(
    List<String> names,
    String current,
    void Function(String) onChange,
  ) {
    final all = [...names, 'TBD'];
    final val = all.contains(current)
        ? current
        : (all.isNotEmpty ? all.first : null);
    return DropdownButtonFormField<String>(
      value: val,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: all
          .map(
            (n) => DropdownMenuItem(
              value: n,
              child: Text(n, style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChange(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(9),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt_rounded, size: 15, color: _indigo),
                const SizedBox(width: 8),
                Text(
                  'Generated Fixtures (${_fixtures.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _indigo,
                  ),
                ),
                const Spacer(),
                Text(
                  'Drag to reorder  •  Tap ✏️ to edit names',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            child: const Row(
              children: [
                SizedBox(width: 36),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Round',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Team A',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Center(
                    child: Text(
                      'vs',
                      style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Team B',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                SizedBox(width: 56),
              ],
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _fixtures.length,
            onReorder: (o, n) {
              setState(() {
                if (n > o) n--;
                final f = _fixtures.removeAt(o);
                _fixtures.insert(n, f);
                for (int i = 0; i < _fixtures.length; i++)
                  _fixtures[i] = _fixtures[i].copyWith(matchNumber: i + 1);
              });
              _emit();
            },
            itemBuilder: (_, i) {
              final f = _fixtures[i];
              return Container(
                key: ValueKey(f.id),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _indigo.withOpacity(0.08),
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
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _indigo.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          f.round,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _indigo,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.teamAName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            if (_getPlayerNames(f.teamAName).isNotEmpty)
                              Text(
                                _getPlayerNames(f.teamAName),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade400,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 30,
                      child: Center(
                        child: Text(
                          'vs',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.teamBName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (_getPlayerNames(f.teamBName).isNotEmpty)
                            Text(
                              _getPlayerNames(f.teamBName),
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _editFixture(i),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _indigo.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 13,
                                color: _indigo,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.drag_handle_rounded,
                            size: 16,
                            color: Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SPONSOR ROW
// ══════════════════════════════════════════════════════════════
class _SponsorRow extends StatelessWidget {
  final _SponsorDraft draft;
  final int index;
  final VoidCallback onRemove, onEdit;
  const _SponsorRow({
    super.key,
    required this.draft,
    required this.index,
    required this.onRemove,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
    ),

    child: Row(
      children: [
        Container(
          width: 24,
          height: 40,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.drag_indicator, size: 12, color: Color(0xFF9CA3AF)),
              SizedBox(height: 2),
              Icon(Icons.drag_indicator, size: 12, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),

        const SizedBox(width: 10),

        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),

          child: draft.logoBase64.isEmpty
              ? Icon(
                  Icons.business_rounded,
                  color: Colors.grey.shade400,
                  size: 22,
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Builder(
                    builder: (context) {
                      final viewId = 'sponsor-${index}-${draft.logoBase64}';

                      // ignore: undefined_prefixed_name
                      ui.platformViewRegistry.registerViewFactory(viewId, (
                        int viewId,
                      ) {
                        final img = html.ImageElement()
                          ..src = draft.logoBase64.startsWith('http')
                              ? draft.logoBase64
                              : "https://dev.sports-next.com/storage/${draft.logoBase64.replaceAll("\\", "/")}"
                          ..style.width = '100%'
                          ..style.height = '100%'
                          ..style.objectFit = 'cover';

                        return img;
                      });

                      return SizedBox(
                        width: 40,
                        height: 40,
                        child: HtmlElementView(viewType: viewId),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                draft.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 16),
          color: Colors.grey.shade500,
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          color: Colors.red.shade400,
          onPressed: onRemove,
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════
class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _AddBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: const Color(0xFF4F46E5)),
    child: Text(
      label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color? color;
  final VoidCallback onTap;
  const _SmallBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF4F46E5);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? c : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? c : Colors.grey.shade600),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? c : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String msg;
  const _EmptyHint(this.msg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: Text(
        msg,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade400,
          fontStyle: FontStyle.italic,
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// DRAFT MODELS
// ══════════════════════════════════════════════════════════════
class _ParticipantDraft {
  final String id;

  String name;
  List<String> players;
  String email;
  String phone;

  String? teamId;
  String seed;

  // 🔥 ADD CONTROLLERS
  final TextEditingController nameCtrl;
  final TextEditingController player1Ctrl;
  final TextEditingController player2Ctrl;

  _ParticipantDraft({
    required this.id,
    this.name = '',
    this.players = const [],
    this.email = '',
    this.phone = '',
    this.teamId,
    this.seed = '',
  }) : nameCtrl = TextEditingController(text: name),
       player1Ctrl = TextEditingController(
         text: players.isNotEmpty ? players[0] : '',
       ),
       player2Ctrl = TextEditingController(
         text: players.length > 1 ? players[1] : '',
       );
}

class _SponsorDraft {
  final String id, name, logoBase64, url;
  _SponsorDraft({
    required this.id,
    required this.name,
    required this.logoBase64,
    required this.url,
  });
  factory _SponsorDraft.fromModel(SponsorModel m) => _SponsorDraft(
    id: m.id,
    name: m.name,
    logoBase64: m.logoBase64,
    url: m.url,
  );
}

class _CategoryDraft {
  final String id, categoryName, format, gender;
  final int maxParticipants;
  List<_ParticipantDraft> participants;
  List<FixtureModel> fixturesManual;
  final int? eventGroupId;

  _CategoryDraft({
    required this.id,
    required this.categoryName,
    required this.format,
    this.gender = 'Men',
    this.maxParticipants = 0,
    required this.participants,
    required this.fixturesManual,
    this.eventGroupId,
  });

  factory _CategoryDraft.empty() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return _CategoryDraft(
      id: 'cat_$ts',
      categoryName: '',
      format: 'round_robin',
      participants: [],
      fixturesManual: [],
    );
  }

  factory _CategoryDraft.fromGroup(EventGroup g) {
    return _CategoryDraft(
      id: g.id,
      eventGroupId: g.id != null ? int.tryParse(g.id.toString()) : null,
      categoryName: g.displayName,
      format: g.format,
      gender: g.gender,
      maxParticipants: g.maxParticipants,
      participants: g.participants
          .map(
            (p) => _ParticipantDraft(
              id: p.id,
              name: p.name,
              players: p.playerNames,
              email: p.email,
              phone: p.phone,
            ),
          )
          .toList(),
      fixturesManual: List.from(g.fixtures),
    );
  }

  _CategoryDraft copyWith({
    String? id,
    String? categoryName,
    String? format,
    String? gender,
    int? maxParticipants,
    List<_ParticipantDraft>? participants,
    List<FixtureModel>? fixturesManual,
    int? eventGroupId,
  }) => _CategoryDraft(
    id: id ?? this.id,
    categoryName: categoryName ?? this.categoryName,
    format: format ?? this.format,
    gender: gender ?? this.gender,
    maxParticipants: maxParticipants ?? this.maxParticipants,
    participants: participants ?? this.participants,
    fixturesManual: fixturesManual ?? this.fixturesManual,
    eventGroupId: eventGroupId ?? this.eventGroupId,
  );
}
