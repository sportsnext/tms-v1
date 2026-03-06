// Place at: lib/features/admin/sports/data/models/sport_model.dart

// ── Scoring rule model ─────────────────────────────────────────
// Padel-focused scoring:
//   sets        — best of N sets (e.g. 3)
//   gamesPerSet — games needed to win a set (e.g. 6)
//   hasTieBreak — whether a tiebreak is played at set deuce
//   tieBreakAt  — score at which tiebreak triggers (e.g. 6-6)
//   tieBreakDiff— points difference needed to win the tiebreak (e.g. win by 2)
//   tieBreakPoints — minimum points to win tiebreak (e.g. 7)
//   goldenPoint — sudden-death at deuce instead of advantage

class ScoringRules {
  final int  sets;
  final int  gamesPerSet;
  final bool hasTieBreak;
  final int  tieBreakAt;      // game score that triggers tiebreak (e.g. 6)
  final int  tieBreakPoints;  // minimum points to win tiebreak (e.g. 7)
  final int  tieBreakDiff;    // points difference to win tiebreak (e.g. 2)
  final bool goldenPoint;     // sudden-death at game deuce

  const ScoringRules({
    required this.sets,
    required this.gamesPerSet,
    required this.hasTieBreak,
    required this.tieBreakAt,
    required this.tieBreakPoints,
    required this.tieBreakDiff,
    required this.goldenPoint,
  });

  ScoringRules copyWith({
    int?  sets,
    int?  gamesPerSet,
    bool? hasTieBreak,
    int?  tieBreakAt,
    int?  tieBreakPoints,
    int?  tieBreakDiff,
    bool? goldenPoint,
  }) => ScoringRules(
    sets:           sets           ?? this.sets,
    gamesPerSet:    gamesPerSet    ?? this.gamesPerSet,
    hasTieBreak:    hasTieBreak    ?? this.hasTieBreak,
    tieBreakAt:     tieBreakAt     ?? this.tieBreakAt,
    tieBreakPoints: tieBreakPoints ?? this.tieBreakPoints,
    tieBreakDiff:   tieBreakDiff   ?? this.tieBreakDiff,
    goldenPoint:    goldenPoint    ?? this.goldenPoint,
  );

  Map<String, dynamic> toJson() => {
    'sets':           sets,
    'gamesPerSet':    gamesPerSet,
    'hasTieBreak':    hasTieBreak,
    'tieBreakAt':     tieBreakAt,
    'tieBreakPoints': tieBreakPoints,
    'tieBreakDiff':   tieBreakDiff,
    'goldenPoint':    goldenPoint,
  };

  factory ScoringRules.fromJson(Map<String, dynamic> j) => ScoringRules(
    sets:           j['sets']           ?? 3,
    gamesPerSet:    j['gamesPerSet']    ?? 6,
    hasTieBreak:    j['hasTieBreak']    ?? true,
    tieBreakAt:     j['tieBreakAt']     ?? 6,
    tieBreakPoints: j['tieBreakPoints'] ?? 7,
    tieBreakDiff:   j['tieBreakDiff']   ?? 2,
    goldenPoint:    j['goldenPoint']    ?? true,
  );

  factory ScoringRules.padelDefaults() => const ScoringRules(
    sets: 3, gamesPerSet: 6,
    hasTieBreak: true, tieBreakAt: 6,
    tieBreakPoints: 7, tieBreakDiff: 2,
    goldenPoint: true,
  );
}

// ── Main Sport model ───────────────────────────────────────────
class SportModel {
  final String       id;
  final String       name;
  final String       description;
  final String       sportType;   // 'Individual' | 'Team'
  final String       category;   // 'Racket' | 'Field' | 'Court' | 'Combat' | 'Other'
  final String       icon;       // emoji
  final int          version;    // rule version — future-ready
  final ScoringRules scoringRules;
  final String       notes;
  final String       createdAt;

  const SportModel({
    required this.id,
    required this.name,
    required this.description,
    required this.sportType,
    required this.category,
    required this.icon,
    required this.version,
    required this.scoringRules,
    required this.notes,
    required this.createdAt,
  });

  SportModel copyWith({
    String?       id,
    String?       name,
    String?       description,
    String?       sportType,
    String?       category,
    String?       icon,
    int?          version,
    ScoringRules? scoringRules,
    String?       notes,
    String?       createdAt,
  }) => SportModel(
    id:           id           ?? this.id,
    name:         name         ?? this.name,
    description:  description  ?? this.description,
    sportType:    sportType    ?? this.sportType,
    category:     category     ?? this.category,
    icon:         icon         ?? this.icon,
    version:      version      ?? this.version,
    scoringRules: scoringRules ?? this.scoringRules,
    notes:        notes        ?? this.notes,
    createdAt:    createdAt    ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id':          id,
    'name':        name,
    'description': description,
    'sportType':   sportType,
    'category':    category,
    'icon':        icon,
    'version':     version,
    'scoringRules':scoringRules.toJson(),
    'notes':       notes,
    'createdAt':   createdAt,
  };

  factory SportModel.fromJson(Map<String, dynamic> j) => SportModel(
    id:           j['id']          ?? '',
    name:         j['name']        ?? '',
    description:  j['description'] ?? '',
    sportType:    j['sportType']   ?? 'Team',
    category:     j['category']    ?? 'Racket',
    icon:         j['icon']        ?? '🎾',
    version:      j['version']     ?? 1,
    scoringRules: ScoringRules.fromJson(j['scoringRules'] ?? {}),
    notes:        j['notes']       ?? '',
    createdAt:    j['createdAt']   ?? '',
  );

  factory SportModel.empty() => SportModel(
    id: '', name: '', description: '',
    sportType: 'Team', category: 'Racket',
    icon: '🎾', version: 1,
    scoringRules: ScoringRules.padelDefaults(),
    notes: '',
    createdAt: DateTime.now().toIso8601String(),
  );
}

// ── Padel preset ───────────────────────────────────────────────
// Only Padel is supported. Custom allows manual config.
class SportPresets {
  static SportModel get padel => SportModel(
    id: '', name: 'Padel',
    description: 'Padel — doubles court sport with walls. '
        'Standard scoring: 3 sets, 6 games per set, tiebreak at 6-6 '
        'won by 2 points difference (min 7 pts). Golden point at game deuce.',
    sportType: 'Team', category: 'Racket', icon: '🎾',
    version: 1,
    scoringRules: ScoringRules.padelDefaults(),
    notes: '', createdAt: '',
  );

  // Preset names shown in form — Padel + Custom only
  static const List<String> presetNames = ['Padel', 'Custom'];

  static SportModel? forName(String name) {
    switch (name) {
      case 'Padel': return padel;
      default:      return null;
    }
  }
}