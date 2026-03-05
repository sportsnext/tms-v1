// Place at: lib/features/admin/venues/data/models/venue_model.dart

// ── Ground model (each venue can have multiple grounds/courts) ─
class GroundModel {
  final String groundName;
  final String groundType; // Cricket, Football, Padel, Tennis, Badminton, General
  final int    courtCount;

  const GroundModel({
    required this.groundName,
    required this.groundType,
    required this.courtCount,
  });

  GroundModel copyWith({
    String? groundName,
    String? groundType,
    int?    courtCount,
  }) => GroundModel(
    groundName: groundName ?? this.groundName,
    groundType: groundType ?? this.groundType,
    courtCount: courtCount ?? this.courtCount,
  );

  Map<String, dynamic> toJson() => {
    'groundName': groundName,
    'groundType': groundType,
    'courtCount': courtCount,
  };

  factory GroundModel.fromJson(Map<String, dynamic> j) => GroundModel(
    groundName: j['groundName'] ?? '',
    groundType: j['groundType'] ?? 'General',
    courtCount: j['courtCount'] ?? 1,
  );

  factory GroundModel.empty() => const GroundModel(
    groundName: '',
    groundType: 'General',
    courtCount: 1,
  );
}

// ── Venue model ────────────────────────────────────────────────
class VenueModel {
  final String           id;
  final String           venueName;
  final String           address;
  final String           city;
  final String           state;
  final String           country;
  final String           latitude;
  final String           longitude;
  final String           mapUrl;     // manual Google Maps link if no lat/lng
  final String           notes;
  final String           status;     // 'Active' | 'Inactive'
  final List<GroundModel> grounds;

  const VenueModel({
    required this.id,
    required this.venueName,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.mapUrl,
    required this.notes,
    required this.status,
    required this.grounds,
  });

  bool get hasLocation => latitude.isNotEmpty && longitude.isNotEmpty;
  int  get totalCourts => grounds.fold(0, (sum, g) => sum + g.courtCount);

  VenueModel copyWith({
    String?            id,
    String?            venueName,
    String?            address,
    String?            city,
    String?            state,
    String?            country,
    String?            latitude,
    String?            longitude,
    String?            mapUrl,
    String?            notes,
    String?            status,
    List<GroundModel>? grounds,
  }) => VenueModel(
    id:        id        ?? this.id,
    venueName: venueName ?? this.venueName,
    address:   address   ?? this.address,
    city:      city      ?? this.city,
    state:     state     ?? this.state,
    country:   country   ?? this.country,
    latitude:  latitude  ?? this.latitude,
    longitude: longitude ?? this.longitude,
    mapUrl:    mapUrl    ?? this.mapUrl,
    notes:     notes     ?? this.notes,
    status:    status    ?? this.status,
    grounds:   grounds   ?? this.grounds,
  );

  Map<String, dynamic> toJson() => {
    'id':        id,
    'venueName': venueName,
    'address':   address,
    'city':      city,
    'state':     state,
    'country':   country,
    'latitude':  latitude,
    'longitude': longitude,
    'mapUrl':    mapUrl,
    'notes':     notes,
    'status':    status,
    'grounds':   grounds.map((g) => g.toJson()).toList(),
  };

  factory VenueModel.fromJson(Map<String, dynamic> j) => VenueModel(
    id:        j['id']        ?? '',
    venueName: j['venueName'] ?? '',
    address:   j['address']   ?? '',
    city:      j['city']      ?? '',
    state:     j['state']     ?? '',
    country:   j['country']   ?? '',
    latitude:  j['latitude']  ?? '',
    longitude: j['longitude'] ?? '',
    mapUrl:    j['mapUrl']    ?? '',
    notes:     j['notes']     ?? '',
    status:    j['status']    ?? 'Active',
    grounds:   (j['grounds'] as List<dynamic>? ?? [])
        .map((g) => GroundModel.fromJson(g as Map<String, dynamic>))
        .toList(),
  );

  factory VenueModel.empty() => const VenueModel(
    id:        '',
    venueName: '',
    address:   '',
    city:      '',
    state:     '',
    country:   '',
    latitude:  '',
    longitude: '',
    mapUrl:    '',
    notes:     '',
    status:    'Active',
    grounds:   [],
  );
}