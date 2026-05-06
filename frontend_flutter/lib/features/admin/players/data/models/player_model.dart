// Place at: lib/features/admin/players/data/models/player_model.dart

import 'package:flutter/material.dart';

int _playerInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

// ── Tournament participation record ───────────────────────────────────────────
class TournamentRecord {
  final String tournamentId;
  final String tournamentName;
  final String sport;
  final String venue;
  final String result;
  final String date;
  final int matchesPlayed;
  final int wins;
  final int losses;

  const TournamentRecord({
    required this.tournamentId,
    required this.tournamentName,
    required this.sport,
    required this.venue,
    required this.result,
    required this.date,
    this.matchesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
  });

  Map<String, dynamic> toJson() => {
    'tournamentId': tournamentId,
    'tournamentName': tournamentName,
    'sport': sport,
    'venue': venue,
    'result': result,
    'date': date,
    'matches_played': matchesPlayed,
    'wins': wins,
    'losses': losses,
  };

  factory TournamentRecord.fromJson(Map<String, dynamic> j) => TournamentRecord(
    tournamentId: j['tournamentId']?.toString() ?? '',
    tournamentName: j['tournamentName']?.toString() ?? '',
    sport: j['sport']?.toString() ?? '',
    venue: j['venue']?.toString() ?? '',
    result: j['result']?.toString() ?? 'Participant',
    date: j['date']?.toString() ?? '',
    matchesPlayed: _playerInt(j['matches_played'] ?? j['matchesPlayed']),
    wins: _playerInt(j['wins']),
    losses: _playerInt(j['losses']),
  );
}

// ── Player model ───────────────────────────────────────────────────────────────
class PlayerModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String gender; // 'Male' | 'Female' | 'Other'
  final String ageGroup; // see PlayerModel.ageGroups
  final String
  skillLevel; // 'Beginner' | 'Intermediate' | 'Advanced' | 'Professional'
  final String city;
  final String state;
  final String country;
  final String notes;
  final bool isActive; // soft delete / deactivate
  final String createdAt;
  final String updatedAt;
  final List<TournamentRecord> history;
  final bool isPlaying;
  final int eventId;
  final String type;

  const PlayerModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.gender,
    required this.ageGroup,
    required this.skillLevel,
    required this.city,
    required this.state,
    required this.country,
    required this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.history,
    required this.isPlaying,
    required this.eventId,
    required this.type,
  });

  // ── Computed ──────────────────────────────────────────────────────────────────
  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  int get totalMatches => history.fold(0, (sum, h) => sum + h.matchesPlayed);

  int get wins => history.fold(0, (sum, h) => sum + h.wins);

  int get losses => history.fold(0, (sum, h) => sum + h.losses);

  Color get skillColor {
    switch (skillLevel) {
      case 'Beginner':
        return const Color(0xFF16A34A);
      case 'Intermediate':
        return const Color(0xFF0A46D8);
      case 'Advanced':
        return const Color(0xFF7C3AED);
      case 'Professional':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color get avatarColor {
    const p = [
      Color(0xFF0A46D8),
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      Color(0xFF16A34A),
      Color(0xFFDC2626),
      Color(0xFFD97706),
    ];
    return p[(firstName.length + lastName.length) % p.length];
  }

  // ── Duplicate score — score ≥ 4 = probable duplicate ─────────────────────────
  double duplicateScore(PlayerModel other) {
    if (id == other.id) return 0;
    double s = 0;
    if (email.isNotEmpty && email.toLowerCase() == other.email.toLowerCase())
      s += 5;
    if (phone.isNotEmpty && phone == other.phone) s += 4;
    if (fullName.toLowerCase() == other.fullName.toLowerCase())
      s += 3;
    else {
      if (firstName.toLowerCase() == other.firstName.toLowerCase()) s += 1.5;
      if (lastName.toLowerCase() == other.lastName.toLowerCase()) s += 1.5;
    }
    if (city.toLowerCase() == other.city.toLowerCase() &&
        gender == other.gender)
      s += 0.5;
    return s;
  }

  // ── Static option lists ───────────────────────────────────────────────────────
  static const List<String> genders = ['Male', 'Female', 'Other'];
  static const List<String> ageGroups = [
    'Under 18',
    '18–30',
    '31–45',
    '46–60',
    '60+',
  ];
  static const List<String> skillLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Professional',
  ];

  // ── CSV support ───────────────────────────────────────────────────────────────
  static const List<String> csvColumns = [
    'firstName',
    'lastName',
    'email',
    'phone',
    'gender',
    'ageGroup',
    'skillLevel',
    'city',
    'state',
    'country',
    'notes',
  ];
  static String get csvHeader => csvColumns.join(',');
  static String get csvSample1 =>
      'Arjun,Mehta,arjun.mehta@email.com,9876543210,Male,18–30,Advanced,Mumbai,Maharashtra,India,Strong backhand';
  static String get csvSample2 =>
      'Priya,Sharma,priya.sharma@email.com,9823456789,Female,18–30,Intermediate,Pune,Maharashtra,India,';

  /// Parse a single CSV data row (no header). Returns null if not enough columns.
  static PlayerModel? fromCsvRow(String row, int rowIndex) {
    final cols = row.split(',').map((c) => c.trim()).toList();
    if (cols.length < 2 || cols[0].isEmpty) return null;
    String pick(List<String> valid, String raw, String fb) =>
        valid.contains(raw) ? raw : fb;
    return PlayerModel(
      id: 'csv_${DateTime.now().millisecondsSinceEpoch}_$rowIndex',
      firstName: cols[0],
      lastName: cols.length > 1 ? cols[1] : '',
      email: cols.length > 2 ? cols[2] : '',
      phone: cols.length > 3 ? cols[3] : '',
      gender: pick(genders, cols.length > 4 ? cols[4] : '', 'Male'),
      ageGroup: pick(ageGroups, cols.length > 5 ? cols[5] : '', '18–30'),
      skillLevel: pick(skillLevels, cols.length > 6 ? cols[6] : '', 'Beginner'),
      city: cols.length > 7 ? cols[7] : '',
      state: cols.length > 8 ? cols[8] : '',
      country: cols.length > 9 ? cols[9] : 'India',
      notes: cols.length > 10 ? cols[10] : '',
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      history: [],
      isPlaying: false,
      eventId: 0,
      type: cols.length > 11 ? cols[11] : 'individual',
    );
  }

  // ── copyWith ──────────────────────────────────────────────────────────────────
  PlayerModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? gender,
    String? ageGroup,
    String? skillLevel,
    String? city,
    String? state,
    String? country,
    String? notes,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    List<TournamentRecord>? history,
    bool? isPlaying,
    int? eventId,
    String? type,
  }) => PlayerModel(
    id: id ?? this.id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    gender: gender ?? this.gender,
    ageGroup: ageGroup ?? this.ageGroup,
    skillLevel: skillLevel ?? this.skillLevel,
    city: city ?? this.city,
    state: state ?? this.state,
    country: country ?? this.country,
    notes: notes ?? this.notes,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    history: history ?? this.history,
    isPlaying: isPlaying ?? this.isPlaying,
    eventId: eventId ?? this.eventId,
    type: type ?? this.type,
  );

  Map<String, dynamic> toJson() {
    return {
      "full_name": "$firstName $lastName",
      "gender": gender,
      "age_group": ageGroup,
      "skill_level": skillLevel,
      "phone": phone,
      "email": email,
      "is_active": isActive ? 1 : 0,
      "is_playing": isPlaying ? 1 : 0,
    };
  }

  factory PlayerModel.fromJson(Map<String, dynamic> j) {
    // ✅ FIX: support both APIs
    final fullName = (j['name'] ?? j['full_name'] ?? '').toString();

    final parts = fullName.trim().split(' ');

    return PlayerModel(
      id: j['id'].toString(),

      // ✅ FIX: works for "A & B" also
      firstName: parts.isNotEmpty ? parts.first : '',
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',

      email: j['email'] ?? '',
      phone: j['phone'] ?? '',

      gender: j['gender'] ?? 'Male',

      ageGroup: j['age_group'] ?? '18–30',

      skillLevel: j['skill_level'] ?? 'Beginner',

      city: j['city'] ?? '',
      state: j['state'] ?? '',
      country: j['country'] ?? 'India',

      notes: j['notes'] ?? '',

      isActive: j['is_active'] == 1 || j['is_active'] == true,

      createdAt: j['created_at'] ?? '',
      updatedAt: j['updated_at'] ?? '',

      history: ((j['history'] as List?) ?? const [])
          .map((e) => TournamentRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList(),

      isPlaying: j['is_playing'] == 1 || j['is_playing'] == true,

      eventId: j['event_id'] ?? 0,

      type: j['type'] ?? 'individual',
    );
  }
}

// ── Seed data ──────────────────────────────────────────────────────────────────
class PlayerSeeds {
  static List<PlayerModel> get all => [
    PlayerModel(
      id: '101',
      firstName: 'Arjun',
      lastName: 'Mehta',
      email: 'arjun.mehta@email.com',
      phone: '9876543210',
      gender: 'Male',
      ageGroup: '18–30',
      skillLevel: 'Advanced',
      city: 'Mumbai',
      state: 'Maharashtra',
      country: 'India',
      notes: 'Strong backhand player',
      isActive: true,
      createdAt: '2025-01-05',
      updatedAt: '2025-03-10',
      history: [
        const TournamentRecord(
          tournamentId: 't1',
          tournamentName: 'Mumbai Padel Open',
          sport: 'Padel',
          venue: 'Arena One',
          result: 'Winner',
          date: '2025-02-10',
        ),
        const TournamentRecord(
          tournamentId: 't2',
          tournamentName: 'National Padel Cup',
          sport: 'Padel',
          venue: 'National Courts',
          result: 'Semi-Final',
          date: '2025-01-20',
        ),
      ],
      isPlaying: false,
      eventId: 1,
      type: 'individual',
    ),
    PlayerModel(
      id: '102',
      firstName: 'Priya',
      lastName: 'Sharma',
      email: 'priya.sharma@email.com',
      phone: '9823456789',
      gender: 'Female',
      ageGroup: '18–30',
      skillLevel: 'Intermediate',
      city: 'Pune',
      state: 'Maharashtra',
      country: 'India',
      notes: '',
      isActive: true,
      createdAt: '2025-01-08',
      updatedAt: '2025-02-15',
      history: [
        const TournamentRecord(
          tournamentId: 't1',
          tournamentName: 'Mumbai Padel Open',
          sport: 'Padel',
          venue: 'Arena One',
          result: 'Runner-up',
          date: '2025-02-10',
        ),
      ],
      isPlaying: false,
      eventId: 1,
      type: 'individual',
    ),
    PlayerModel(
      id: '103',
      firstName: 'Rohan',
      lastName: 'Kapoor',
      email: 'rohan.k@email.com',
      phone: '9912345678',
      gender: 'Male',
      ageGroup: '31–45',
      skillLevel: 'Professional',
      city: 'Delhi',
      state: 'Delhi',
      country: 'India',
      notes: 'Former national level player',
      isActive: true,
      createdAt: '2024-12-01',
      updatedAt: '2025-03-01',
      history: [
        const TournamentRecord(
          tournamentId: 't2',
          tournamentName: 'National Padel Cup',
          sport: 'Padel',
          venue: 'National Courts',
          result: 'Winner',
          date: '2025-01-20',
        ),
        const TournamentRecord(
          tournamentId: 't3',
          tournamentName: 'Delhi Open',
          sport: 'Padel',
          venue: 'DLF Arena',
          result: 'Winner',
          date: '2024-12-15',
        ),
      ],
      isPlaying: false,
      eventId: 1,
      type: 'individual',
    ),
    PlayerModel(
      id: '104',
      firstName: 'Sneha',
      lastName: 'Joshi',
      email: 'sneha.joshi@email.com',
      phone: '9745678901',
      gender: 'Female',
      ageGroup: '18–30',
      skillLevel: 'Beginner',
      city: 'Bangalore',
      state: 'Karnataka',
      country: 'India',
      notes: '',
      isActive: false,
      createdAt: '2025-02-01',
      updatedAt: '2025-02-20',
      history: [],
      isPlaying: false,
      eventId: 1,
      type: 'individual',
    ),
    PlayerModel(
      id: '105',
      firstName: 'Vikram',
      lastName: 'Singh',
      email: 'vikram.singh@email.com',
      phone: '9634567890',
      gender: 'Male',
      ageGroup: '46–60',
      skillLevel: 'Intermediate',
      city: 'Mumbai',
      state: 'Maharashtra',
      country: 'India',
      notes: 'Weekend player',
      isActive: true,
      createdAt: '2025-01-20',
      updatedAt: '2025-01-20',
      history: [
        const TournamentRecord(
          tournamentId: 't1',
          tournamentName: 'Mumbai Padel Open',
          sport: 'Padel',
          venue: 'Arena One',
          result: 'Participant',
          date: '2025-02-10',
        ),
      ],
      isPlaying: false,
      eventId: 1,
      type: 'individual',
    ),
    // Intentional duplicate of p1 to demonstrate detection + merge
    PlayerModel(
      id: '106',
      firstName: 'Arjun',
      lastName: 'Mehta',
      email: 'arjun.mehta@email.com',
      phone: '9876543210',
      gender: 'Male',
      ageGroup: '18–30',
      skillLevel: 'Intermediate',
      city: 'Mumbai',
      state: 'Maharashtra',
      country: 'India',
      notes: 'Duplicate entry from old system',
      isActive: true,
      createdAt: '2025-01-06',
      updatedAt: '2025-01-06',
      history: [
        const TournamentRecord(
          tournamentId: 't4',
          tournamentName: 'Bombay Classic',
          sport: 'Padel',
          venue: 'Court One',
          result: 'Runner-up',
          date: '2025-03-01',
        ),
      ],
      isPlaying: false,
      eventId: 1,
      type: 'individual',
    ),
  ];
}
