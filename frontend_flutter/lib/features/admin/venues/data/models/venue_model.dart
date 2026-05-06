// Place at: lib/features/admin/venues/data/models/venue_model.dart

// ── Ground model (each venue can have multiple grounds/courts) ─
class GroundModel {
  final String groundName;
  final String
  groundType; // Cricket, Football, Padel, Tennis, Badminton, General
  final int courtCount;

  const GroundModel({
    required this.groundName,
    required this.groundType,
    required this.courtCount,
  });

  GroundModel copyWith({
    String? groundName,
    String? groundType,
    int? courtCount,
  }) => GroundModel(
    groundName: groundName ?? this.groundName,
    groundType: groundType ?? this.groundType,
    courtCount: courtCount ?? this.courtCount,
  );

  Map<String, dynamic> toJson() => {
    'ground_name': groundName,
    'ground_type': groundType,
    'court_count': courtCount,
  };

  factory GroundModel.fromJson(Map<String, dynamic> j) => GroundModel(
    groundName: j['ground_name'] ?? '',
    groundType: j['ground_type'] ?? 'General',
    courtCount: j['court_count'] ?? 1,
  );

  factory GroundModel.empty() =>
      const GroundModel(groundName: '', groundType: 'General', courtCount: 1);
}

// ── Venue model ────────────────────────────────────────────────
class VenueModel {
  final String id;
  final String venueName;
  final String address;
  final String city;
  final String state;
  final String country;
  final String latitude;
  final String longitude;
  final String mapUrl; // manual Google Maps link if no lat/lng
  final String notes;
  final String status; // 'Active' | 'Inactive'
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
  int get totalCourts => grounds.fold(0, (sum, g) => sum + g.courtCount);

  VenueModel copyWith({
    String? id,
    String? venueName,
    String? address,
    String? city,
    String? state,
    String? country,
    String? latitude,
    String? longitude,
    String? mapUrl,
    String? notes,
    String? status,
    List<GroundModel>? grounds,
  }) => VenueModel(
    id: id ?? this.id,
    venueName: venueName ?? this.venueName,
    address: address ?? this.address,
    city: city ?? this.city,
    state: state ?? this.state,
    country: country ?? this.country,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    mapUrl: mapUrl ?? this.mapUrl,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    grounds: grounds ?? this.grounds,
  );

  Map<String, dynamic> toJson() => {
    'venue_name': venueName,
    'location': address,
    'description': notes,
    'is_active': status == 'Active' ? 1 : 0,
    'grounds': grounds.map((g) => g.toJson()).toList(),
  };

  factory VenueModel.fromJson(Map<String, dynamic> j) => VenueModel(
    id: j['id'].toString(),

    venueName: j['venue_name'] ?? '',
    address: j['location'] ?? '',
    notes: j['description'] ?? '',

    city: j['city'] ?? '',
    state: j['state'] ?? '',
    country: j['country'] ?? '',

    latitude: j['latitude']?.toString() ?? '',
    longitude: j['longitude']?.toString() ?? '',

    mapUrl: j['map_url'] ?? '',

    status: (j['is_active'] == 1) ? 'Active' : 'Inactive',

    grounds: (j['grounds'] as List<dynamic>? ?? [])
        .map((g) => GroundModel.fromJson(g))
        .toList(),
  );
  
  factory VenueModel.empty() => const VenueModel(
    id: '',
    venueName: '',
    address: '',
    city: '',
    state: '',
    country: '',
    latitude: '',
    longitude: '',
    mapUrl: '',
    notes: '',
    status: 'Active',
    grounds: [],
  );
}
