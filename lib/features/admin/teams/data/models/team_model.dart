// lib/features/admin/teams/data/models/team_model.dart


import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PLAYER REFERENCE STUB  (delete when wiring real PlayerModel)
// ─────────────────────────────────────────────────────────────────────────────
class PlayerRef {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String skillLevel;
  final String gender;
  final String city;
  final bool   isActive;
  final Color  skillColor;
  final Color  avatarColor;

  const PlayerRef({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.skillLevel,
    required this.gender,
    required this.city,
    required this.isActive,
    required this.skillColor,
    required this.avatarColor,
  });

  String get fullName  => '$firstName $lastName';
  String get initials  =>
      '${firstName.isNotEmpty ? firstName[0] : ''}'
      '${lastName.isNotEmpty  ? lastName[0]  : ''}'.toUpperCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// TEAM MODEL
// ─────────────────────────────────────────────────────────────────────────────
class TeamModel {
  final String       id;
  final String       name;
  // No tournamentId / tournamentName — a team can join many tournaments
  final String       sport;
  final int          maxPlayers;   // admin types this freely (≥ 1)
  final List<String> playerIds;
  final String       status;       // draft | active | published | archived
  final String       captainId;
  final String       coachName;
  final String       notes;
  final String       createdAt;
  final String       updatedAt;

  const TeamModel({
    required this.id,
    required this.name,
    required this.sport,
    required this.maxPlayers,
    required this.playerIds,
    required this.status,
    required this.captainId,
    required this.coachName,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Computed ─────────────────────────────────────────────────────────────
  bool   get isPublished => status == 'published';
  bool   get isLocked    => status == 'published' || status == 'archived';
  int    get playerCount => playerIds.length;
  bool   get isFull      => playerIds.length >= maxPlayers;
  double get fillRatio   =>
      maxPlayers > 0
          ? (playerIds.length / maxPlayers).clamp(0.0, 1.0)
          : 0.0;

  Color get statusColor {
    switch (status) {
      case 'draft':     return const Color(0xFF6B7280);
      case 'active':    return const Color(0xFF0A46D8);
      case 'published': return const Color(0xFF16A34A);
      case 'archived':  return const Color(0xFF9CA3AF);
      default:          return const Color(0xFF6B7280);
    }
  }

  String get statusLabel {
    switch (status) {
      case 'draft':     return 'Draft';
      case 'active':    return 'Active';
      case 'published': return 'Published';
      case 'archived':  return 'Archived';
      default:          return status;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'draft':     return Icons.edit_note_outlined;
      case 'active':    return Icons.sports_outlined;
      case 'published': return Icons.lock_outlined;
      case 'archived':  return Icons.archive_outlined;
      default:          return Icons.info_outline;
    }
  }

  Color get progressColor {
    if (fillRatio >= 1.0) return const Color(0xFF16A34A);
    if (fillRatio >= 0.5) return const Color(0xFF0A46D8);
    return const Color(0xFFF59E0B);
  }

  TeamModel copyWith({
    String?       id,
    String?       name,
    String?       sport,
    int?          maxPlayers,
    List<String>? playerIds,
    String?       status,
    String?       captainId,
    String?       coachName,
    String?       notes,
    String?       createdAt,
    String?       updatedAt,
  }) =>
      TeamModel(
        id:         id         ?? this.id,
        name:       name       ?? this.name,
        sport:      sport      ?? this.sport,
        maxPlayers: maxPlayers ?? this.maxPlayers,
        playerIds:  playerIds  ?? List<String>.from(this.playerIds),
        status:     status     ?? this.status,
        captainId:  captainId  ?? this.captainId,
        coachName:  coachName  ?? this.coachName,
        notes:      notes      ?? this.notes,
        createdAt:  createdAt  ?? this.createdAt,
        updatedAt:  updatedAt  ??
            DateTime.now().toIso8601String().substring(0, 10),
      );

  Map<String, dynamic> toJson() => {
    'id':         id,
    'name':       name,
    'sport':      sport,
    'maxPlayers': maxPlayers,
    'playerIds':  playerIds,
    'status':     status,
    'captainId':  captainId,
    'coachName':  coachName,
    'notes':      notes,
    'createdAt':  createdAt,
    'updatedAt':  updatedAt,
  };

  // ── Constants ─────────────────────────────────────────────────────────────
  static const List<String> sports = [
    'Padel', 'Tennis', 'Badminton', 'Squash',
    'Table Tennis', 'Pickleball', 'Basketball', 'Football',
  ];

  static const List<String> statuses = [
    'draft', 'active', 'published', 'archived'
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// SEED DATA  — replace with real API in integration
// ─────────────────────────────────────────────────────────────────────────────
class TeamSeeds {
  static const List<PlayerRef> allPlayers = [
    PlayerRef(id: 'p1',  firstName: 'Arjun',  lastName: 'Mehta',
        email: 'arjun@gmail.com',  phone: '9876543210',
        skillLevel: 'Advanced',     gender: 'Male',   city: 'Mumbai',
        isActive: true,
        skillColor: Color(0xFF7C3AED), avatarColor: Color(0xFF0A46D8)),
    PlayerRef(id: 'p2',  firstName: 'Priya',  lastName: 'Sharma',
        email: 'priya@gmail.com',  phone: '9876543211',
        skillLevel: 'Intermediate', gender: 'Female', city: 'Delhi',
        isActive: true,
        skillColor: Color(0xFF0A46D8), avatarColor: Color(0xFF7C3AED)),
    PlayerRef(id: 'p3',  firstName: 'Rohan',  lastName: 'Kapoor',
        email: 'rohan@gmail.com',  phone: '9876543212',
        skillLevel: 'Professional', gender: 'Male',   city: 'Bangalore',
        isActive: true,
        skillColor: Color(0xFFEF4444), avatarColor: Color(0xFF16A34A)),
    PlayerRef(id: 'p4',  firstName: 'Sneha',  lastName: 'Patel',
        email: 'sneha@gmail.com',  phone: '9876543213',
        skillLevel: 'Beginner',     gender: 'Female', city: 'Pune',
        isActive: true,
        skillColor: Color(0xFF16A34A), avatarColor: Color(0xFFF59E0B)),
    PlayerRef(id: 'p5',  firstName: 'Vikram', lastName: 'Singh',
        email: 'vikram@gmail.com', phone: '9876543214',
        skillLevel: 'Advanced',     gender: 'Male',   city: 'Chennai',
        isActive: true,
        skillColor: Color(0xFF7C3AED), avatarColor: Color(0xFFEF4444)),
    PlayerRef(id: 'p6',  firstName: 'Anjali', lastName: 'Nair',
        email: 'anjali@gmail.com', phone: '9876543215',
        skillLevel: 'Intermediate', gender: 'Female', city: 'Hyderabad',
        isActive: true,
        skillColor: Color(0xFF0A46D8), avatarColor: Color(0xFF0D9488)),
    PlayerRef(id: 'p7',  firstName: 'Karan',  lastName: 'Joshi',
        email: 'karan@gmail.com',  phone: '9876543216',
        skillLevel: 'Professional', gender: 'Male',   city: 'Mumbai',
        isActive: true,
        skillColor: Color(0xFFEF4444), avatarColor: Color(0xFF7C3AED)),
    PlayerRef(id: 'p8',  firstName: 'Meera',  lastName: 'Reddy',
        email: 'meera@gmail.com',  phone: '9876543217',
        skillLevel: 'Beginner',     gender: 'Female', city: 'Kolkata',
        isActive: true,
        skillColor: Color(0xFF16A34A), avatarColor: Color(0xFFEC4899)),
    PlayerRef(id: 'p9',  firstName: 'Rahul',  lastName: 'Gupta',
        email: 'rahul@gmail.com',  phone: '9876543218',
        skillLevel: 'Intermediate', gender: 'Male',   city: 'Jaipur',
        isActive: true,
        skillColor: Color(0xFF0A46D8), avatarColor: Color(0xFFEA580C)),
    PlayerRef(id: 'p10', firstName: 'Pooja',  lastName: 'Verma',
        email: 'pooja@gmail.com',  phone: '9876543219',
        skillLevel: 'Advanced',     gender: 'Female', city: 'Ahmedabad',
        isActive: false,
        skillColor: Color(0xFF7C3AED), avatarColor: Color(0xFF0A46D8)),
    PlayerRef(id: 'p11', firstName: 'Aditya', lastName: 'Bose',
        email: 'aditya@gmail.com', phone: '9876543220',
        skillLevel: 'Intermediate', gender: 'Male',   city: 'Kolkata',
        isActive: true,
        skillColor: Color(0xFF0A46D8), avatarColor: Color(0xFF0D9488)),
    PlayerRef(id: 'p12', firstName: 'Nisha',  lastName: 'Iyer',
        email: 'nisha@gmail.com',  phone: '9876543221',
        skillLevel: 'Advanced',     gender: 'Female', city: 'Chennai',
        isActive: true,
        skillColor: Color(0xFF7C3AED), avatarColor: Color(0xFFEC4899)),
    PlayerRef(id: 'p13', firstName: 'Sameer', lastName: 'Khan',
        email: 'sameer@gmail.com', phone: '9876543222',
        skillLevel: 'Professional', gender: 'Male',   city: 'Mumbai',
        isActive: true,
        skillColor: Color(0xFFEF4444), avatarColor: Color(0xFFEA580C)),
    PlayerRef(id: 'p14', firstName: 'Divya',  lastName: 'Menon',
        email: 'divya@gmail.com',  phone: '9876543223',
        skillLevel: 'Beginner',     gender: 'Female', city: 'Pune',
        isActive: true,
        skillColor: Color(0xFF16A34A), avatarColor: Color(0xFF7C3AED)),
  ];

  static final List<TeamModel> all = [
    TeamModel(
      id: 't1', name: 'Thunder Hawks',
      sport: 'Padel', maxPlayers: 6,
      playerIds: ['p1', 'p2', 'p3'],
      status: 'active', captainId: 'p1', coachName: 'Raj Malhotra',
      notes: 'Top seeded team. Very strong defense.',
      createdAt: '2025-01-10', updatedAt: '2025-01-15',
    ),
    TeamModel(
      id: 't2', name: 'Desert Eagles',
      sport: 'Padel', maxPlayers: 6,
      playerIds: ['p4', 'p5', 'p6', 'p7'],
      status: 'published', captainId: 'p5', coachName: 'Sunita Rao',
      notes: 'Roster locked after tournament publish.',
      createdAt: '2025-01-11', updatedAt: '2025-01-18',
    ),
    TeamModel(
      id: 't3', name: 'Storm Riders',
      sport: 'Tennis', maxPlayers: 4,
      playerIds: ['p8'],
      status: 'draft', captainId: '', coachName: '',
      notes: '',
      createdAt: '2025-02-01', updatedAt: '2025-02-01',
    ),
    TeamModel(
      id: 't4', name: 'Golden Smashers',
      sport: 'Tennis', maxPlayers: 4,
      playerIds: ['p2', 'p9'],
      status: 'draft', captainId: 'p2', coachName: 'Dev Khanna',
      notes: 'Mixed doubles squad.',
      createdAt: '2025-02-03', updatedAt: '2025-02-03',
    ),
  ];
}