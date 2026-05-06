// ── Event Model ───────────────────────────────────────────────
// Place at: lib/features/admin/events/data/models/event_model.dart

class EventModel {
  final String id;
  final String sportId;
  final String eventName;
  final String description;
  final String startDate;
  final String endDate;
  final String location;
  final String venueId;
  final String venueName;
  final String banner; // base64 string or URL
  final String domain;
  final String status; // 'Draft' | 'Published'

  const EventModel({
    required this.id,
    required this.sportId,
    required this.eventName,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.venueId,
    required this.venueName,
    required this.banner,
    required this.domain,
    required this.status,
  });

  EventModel copyWith({
    String? id,
    String? sportId,
    String? eventName,
    String? description,
    String? startDate,
    String? endDate,
    String? location,
    String? venueId,
    String? venueName,
    String? banner,
    String? domain,
    String? status,
  }) => EventModel(
    id: id ?? this.id,
    sportId: sportId ?? this.sportId,
    eventName: eventName ?? this.eventName,
    description: description ?? this.description,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    location: location ?? this.location,
    venueId: venueId ?? this.venueId,
    venueName: venueName ?? this.venueName,
    banner: banner ?? this.banner,
    domain: domain ?? this.domain,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'event_name': eventName,
    'description': description,
    'start_date': startDate,
    'end_date': endDate,
    'location': location,
    'venue_Id': venueId,
    'venue_name': venueName,
    'banner': banner,
    'domain': domain,
    'status': status,
  };

  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
    id: json['id']?.toString() ?? '',
    sportId: json['sport_id']?.toString() ?? '',
    eventName: json['event_name'] ?? '',
    description: json['description'] ?? '',
    startDate: json['start_date'] ?? '',
    endDate: json['end_date'] ?? '',
    location: json['location'] ?? '',
    venueId: json['venue_id']?.toString() ?? '',
    venueName: json['venue_name'] ?? json['location'] ?? '',
    banner: json['banner'] ?? '',
    domain: json['domain'] ?? '',
    status: (json['status'] ?? '').toString().toLowerCase() == 'draft'
        ? 'Draft'
        : 'Published',
  );

  // Empty factory for new form
  factory EventModel.empty() => const EventModel(
    id: '',
    sportId: '',
    eventName: '',
    description: '',
    startDate: '',
    endDate: '',
    location: '',
    venueId: '',
    venueName: '',
    banner: '',
    domain: '',
    status: 'Draft',
  );
}

// ── Venue dropdown model (used in Add/Edit form) ──────────────
class VenueOption {
  final String id;
  final String venueName;
  const VenueOption({required this.id, required this.venueName});
}
