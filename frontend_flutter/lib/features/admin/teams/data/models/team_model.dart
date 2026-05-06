// lib/features/admin/teams/data/models/team_model.dart

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TEAM MODEL
// ─────────────────────────────────────────────────────────────────────────────
class TeamModel {
  final String id;
  final String name;
  // No tournamentId / tournamentName — a team can join many tournaments
  final String sport;
  final int maxPlayers; // admin types this freely (≥ 1)
  final List<String> playerIds;
  final String status; // draft | active | published | archived
  final String coachName;
  final String createdAt;
  final String updatedAt;
  final String type;
  final int locked;
  final bool isPublished;
  final bool isLocked;
  final int tournamentId;
  final int eventId;

  TeamModel({
    required this.id,
    required this.name,
    required this.sport,
    required this.maxPlayers,
    required this.playerIds,
    required this.status,
    required this.coachName,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
    required this.locked,
    required this.isPublished,
    required this.isLocked,
    required this.tournamentId,
    required this.eventId,
  });

  // ── Computed ─────────────────────────────────────────────────────────────
  int get playerCount => playerIds.length;
  bool get isFull => playerIds.length >= maxPlayers;
  double get fillRatio =>
      maxPlayers > 0 ? (playerIds.length / maxPlayers).clamp(0.0, 1.0) : 0.0;

  Color get statusColor {
    switch (status) {
      case 'draft':
        return const Color(0xFF6B7280);
      case 'active':
        return const Color(0xFF0A46D8);
      case 'published':
        return const Color(0xFF16A34A);
      case 'archived':
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'active':
        return 'Active';
      case 'published':
        return 'Published';
      case 'archived':
        return 'Archived';
      default:
        return status;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'draft':
        return Icons.edit_note_outlined;
      case 'active':
        return Icons.sports_outlined;
      case 'published':
        return Icons.lock_outlined;
      case 'archived':
        return Icons.archive_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color get progressColor {
    if (fillRatio >= 1.0) return const Color(0xFF16A34A);
    if (fillRatio >= 0.5) return const Color(0xFF0A46D8);
    return const Color(0xFFF59E0B);
  }

  TeamModel copyWith({
    String? id,
    String? name,
    String? sport,
    int? maxPlayers,
    List<String>? playerIds,
    String? status,
    String? captainId,
    String? coachName,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? type,
    int? locked,
    bool? isPublished,
    bool? islocked,
    int? tournamentId,
    int? eventId,
  }) => TeamModel(
    id: id ?? this.id,
    name: name ?? this.name,
    sport: sport ?? this.sport,
    maxPlayers: maxPlayers ?? this.maxPlayers,
    playerIds: playerIds ?? List<String>.from(this.playerIds),
    status: status ?? this.status,
    coachName: coachName ?? this.coachName,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? DateTime.now().toIso8601String().substring(0, 10),
    type: type ?? this.type,
    locked: locked ?? this.locked,
    isPublished: isPublished ?? this.isPublished,
    isLocked: islocked ?? this.isLocked,
    tournamentId: tournamentId ?? this.tournamentId,
    eventId: eventId ?? this.eventId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sport': sport,
    'maxPlayers': maxPlayers,
    'playerIds': playerIds,
    'status': status,
    'coachName': coachName,
    'type': type,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      sport: json['sport'] ?? '',
      maxPlayers: json['playing_limit'] ?? json['max_players'] ?? 2,

      playerIds: json['player_ids'] == null
          ? []
          : List<String>.from(
              (json['player_ids'] as List).map((e) => e.toString()),
            ),

      status: json['status'] ?? 'draft',
      coachName: json['coach_name'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      type: json['type'] ?? 'individual',
      locked: int.tryParse(json['locked'].toString()) ?? 0,

      isPublished: json['is_published'].toString() == "1",
      isLocked: json['locked'].toString() == "1",

      tournamentId: json['tournament_id'] ?? 0,
      eventId: json['event_id'] ?? 0,
    );
  }

  // ── Constants ─────────────────────────────────────────────────────────────
  static const List<String> sports = [
    'Padel',
    'Tennis',
    'Badminton',
    'Squash',
    'Table Tennis',
    'Pickleball',
    'Basketball',
    'Football',
  ];

  static const List<String> statuses = [
    'draft',
    'active',
    'published',
    'archived',
  ];
}
