// ── Event Model ───────────────────────────────────────────────
// Place at: lib/features/admin/events/data/models/event_model.dart

class EventModel {
  final String id;
  final String eventName;
  final String description;
  final String startDate;
  final String endDate;
  final String venueId;
  final String venueName;
  final String banner;   // base64 string or URL
  final String domain;
  final String status;   // 'Draft' | 'Published'

  const EventModel({
    required this.id,
    required this.eventName,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.venueId,
    required this.venueName,
    required this.banner,
    required this.domain,
    required this.status,
  });

  EventModel copyWith({
    String? id,
    String? eventName,
    String? description,
    String? startDate,
    String? endDate,
    String? venueId,
    String? venueName,
    String? banner,
    String? domain,
    String? status,
  }) =>
      EventModel(
        id:          id          ?? this.id,
        eventName:   eventName   ?? this.eventName,
        description: description ?? this.description,
        startDate:   startDate   ?? this.startDate,
        endDate:     endDate     ?? this.endDate,
        venueId:     venueId     ?? this.venueId,
        venueName:   venueName   ?? this.venueName,
        banner:      banner      ?? this.banner,
        domain:      domain      ?? this.domain,
        status:      status      ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id':          id,
        'eventName':   eventName,
        'description': description,
        'startDate':   startDate,
        'endDate':     endDate,
        'venueId':     venueId,
        'venueName':   venueName,
        'banner':      banner,
        'domain':      domain,
        'status':      status,
      };

  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
        id:          json['id']          ?? '',
        eventName:   json['eventName']   ?? '',
        description: json['description'] ?? '',
        startDate:   json['startDate']   ?? '',
        endDate:     json['endDate']     ?? '',
        venueId:     json['venueId']     ?? '',
        venueName:   json['venueName']   ?? '',
        banner:      json['banner']      ?? '',
        domain:      json['domain']      ?? '',
        status:      json['status']      ?? 'Draft',
      );

  // Empty factory for new form
  factory EventModel.empty() => const EventModel(
        id:          '',
        eventName:   '',
        description: '',
        startDate:   '',
        endDate:     '',
        venueId:     '',
        venueName:   '',
        banner:      '',
        domain:      '',
        status:      'Draft',
      );
}

// ── Venue dropdown model (used in Add/Edit form) ──────────────
class VenueOption {
  final String id;
  final String venueName;
  const VenueOption({required this.id, required this.venueName});
}