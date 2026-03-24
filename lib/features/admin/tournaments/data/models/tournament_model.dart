// lib/features/admin/tournaments/data/models/tournament_model.dart
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// SPONSOR MODEL
// ─────────────────────────────────────────────────────────────
class SponsorModel {
  final String id, name, logoBase64, url;
  final int    order;
  const SponsorModel({required this.id, required this.name,
      required this.logoBase64, required this.url, required this.order});
  SponsorModel copyWith({String? id, String? name, String? logoBase64, String? url, int? order}) =>
      SponsorModel(id: id??this.id, name: name??this.name, logoBase64: logoBase64??this.logoBase64,
          url: url??this.url, order: order??this.order);
  Map<String, dynamic> toJson() =>
      {'id':id,'name':name,'logoBase64':logoBase64,'url':url,'order':order};
}

// ─────────────────────────────────────────────────────────────
// SET SCORE
// ─────────────────────────────────────────────────────────────
class SetScore {
  final int scoreA, scoreB;
  const SetScore({required this.scoreA, required this.scoreB});
  SetScore copyWith({int? scoreA, int? scoreB}) =>
      SetScore(scoreA: scoreA??this.scoreA, scoreB: scoreB??this.scoreB);
  Map<String, dynamic> toJson() => {'scoreA':scoreA,'scoreB':scoreB};
  factory SetScore.fromJson(Map<String, dynamic> j) =>
      SetScore(scoreA: j['scoreA']??0, scoreB: j['scoreB']??0);
  factory SetScore.empty() => const SetScore(scoreA:0, scoreB:0);
}

// ─────────────────────────────────────────────────────────────
// FIXTURE MODEL
// ─────────────────────────────────────────────────────────────
class FixtureModel {
  final String         id, eventGroupId, round;
  final int            matchNumber, roundIndex, matchIndex;
  final String         teamAId, teamAName, teamBId, teamBName;
  final String         date, time, venueId, venueName, court;
  final String         status; // scheduled|live|completed|cancelled
  final List<SetScore> sets;
  final int            setsWonA, setsWonB;
  final String         winnerId;
  final bool           isLive;
  final String         liveStreamUrl;

  const FixtureModel({
    required this.id, required this.eventGroupId, required this.round,
    required this.matchNumber,
    this.roundIndex = 0, this.matchIndex = 0,
    required this.teamAId, required this.teamAName,
    required this.teamBId, required this.teamBName,
    required this.date, required this.time,
    this.venueId = '', this.venueName = '',
    required this.court, required this.status,
    required this.sets, required this.setsWonA, required this.setsWonB,
    required this.winnerId, required this.isLive,
    this.liveStreamUrl = '',
  });

  bool get isScheduled => status == 'scheduled';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get hasWinner   => winnerId.isNotEmpty;
  bool get hasSchedule => date.isNotEmpty;
  bool get isTBD       => teamAName == 'TBD' || teamBName == 'TBD';
  String get displayScore => isCompleted ? '$setsWonA – $setsWonB' : '—';

  Color get statusColor {
    switch (status) {
      case 'scheduled': return const Color(0xFF6366F1);
      case 'live':      return const Color(0xFF16A34A);
      case 'completed': return const Color(0xFF374151);
      case 'cancelled': return const Color(0xFFEF4444);
      default:          return const Color(0xFF9CA3AF);
    }
  }
  String get statusLabel {
    switch (status) {
      case 'scheduled': return 'Scheduled';
      case 'live':      return 'Live';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default:          return status;
    }
  }

  FixtureModel copyWith({
    String? id, String? eventGroupId, String? round,
    int? matchNumber, int? roundIndex, int? matchIndex,
    String? teamAId, String? teamAName, String? teamBId, String? teamBName,
    String? date, String? time, String? venueId, String? venueName,
    String? court, String? status, List<SetScore>? sets,
    int? setsWonA, int? setsWonB, String? winnerId, bool? isLive,
    String? liveStreamUrl,
  }) => FixtureModel(
    id: id??this.id, eventGroupId: eventGroupId??this.eventGroupId,
    round: round??this.round, matchNumber: matchNumber??this.matchNumber,
    roundIndex: roundIndex??this.roundIndex, matchIndex: matchIndex??this.matchIndex,
    teamAId: teamAId??this.teamAId, teamAName: teamAName??this.teamAName,
    teamBId: teamBId??this.teamBId, teamBName: teamBName??this.teamBName,
    date: date??this.date, time: time??this.time,
    venueId: venueId??this.venueId, venueName: venueName??this.venueName,
    court: court??this.court, status: status??this.status,
    sets: sets??List.from(this.sets),
    setsWonA: setsWonA??this.setsWonA, setsWonB: setsWonB??this.setsWonB,
    winnerId: winnerId??this.winnerId, isLive: isLive??this.isLive,
    liveStreamUrl: liveStreamUrl??this.liveStreamUrl,
  );

  Map<String, dynamic> toJson() => {
    'id':id,'eventGroupId':eventGroupId,'round':round,'matchNumber':matchNumber,
    'roundIndex':roundIndex,'matchIndex':matchIndex,
    'teamAId':teamAId,'teamAName':teamAName,'teamBId':teamBId,'teamBName':teamBName,
    'date':date,'time':time,'venueId':venueId,'venueName':venueName,
    'court':court,'status':status,
    'sets':sets.map((s)=>s.toJson()).toList(),
    'setsWonA':setsWonA,'setsWonB':setsWonB,'winnerId':winnerId,
    'isLive':isLive,'liveStreamUrl':liveStreamUrl,
  };
  static const List<String> statuses = ['scheduled','live','completed','cancelled'];
}

// ─────────────────────────────────────────────────────────────
// PARTICIPANT MODEL
// ─────────────────────────────────────────────────────────────
class ParticipantModel {
  final String       id, name;
  final List<String> playerNames;
  final String       email, phone, seed;

  const ParticipantModel({
    required this.id, required this.name, required this.playerNames,
    this.email = '', this.phone = '', this.seed = '',
  });

  String get displayPlayers => playerNames.isEmpty ? name : playerNames.join(' /');
  String get initials {
    final words = name.trim().split(' ');
    return words.map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
  }

  ParticipantModel copyWith({
    String? id, String? name, List<String>? playerNames,
    String? email, String? phone, String? seed,
  }) => ParticipantModel(
    id: id??this.id, name: name??this.name,
    playerNames: playerNames??List.from(this.playerNames),
    email: email??this.email, phone: phone??this.phone, seed: seed??this.seed,
  );
  Map<String, dynamic> toJson() =>
      {'id':id,'name':name,'playerNames':playerNames,'email':email,'phone':phone,'seed':seed};
}

// ─────────────────────────────────────────────────────────────
// STANDINGS ROW
// ─────────────────────────────────────────────────────────────
class StandingRow {
  final String participantId, participantName;
  final int played, won, lost, gameDiff, points;
  const StandingRow({
    required this.participantId, required this.participantName,
    required this.played, required this.won, required this.lost,
    required this.gameDiff, required this.points,
  });
}

// ─────────────────────────────────────────────────────────────
// EVENT GROUP
// ─────────────────────────────────────────────────────────────
class EventGroup {
  final String                 id;
  final String                 eventName;    // e.g. "Women's Doubles"
  final String                 sportName;    // kept for backwards compat
  final String                 format;       // round_robin|knockout|custom
  final String                 participantType; // Team|Individual|Pair
  final String                 gender;       // Open|Men|Women|Mixed
  final int                    maxParticipants;
  final List<ParticipantModel> participants;
  final List<FixtureModel>     fixtures;

  const EventGroup({
    required this.id,
    this.eventName = '',
    required this.sportName,
    required this.format,
    required this.participantType,
    this.gender = 'Open',
    this.maxParticipants = 0,
    required this.participants,
    required this.fixtures,
  });

  String get displayName => eventName.isNotEmpty ? eventName : sportName;

  String get formatLabel {
    switch (format) {
      case 'round_robin': return 'Round Robin';
      case 'knockout':    return 'Knockout (Single Elim.)';
      case 'custom':      return 'Custom';
      default:            return format;
    }
  }

  Color get formatColor {
    switch (format) {
      case 'round_robin': return const Color(0xFF6366F1);
      case 'knockout':    return const Color(0xFFEF4444);
      case 'custom':      return const Color(0xFFF59E0B);
      default:            return const Color(0xFF9CA3AF);
    }
  }

  // Round Robin generator — uses proper "Match N" labeling
  static List<FixtureModel> generateRoundRobin(
      String groupId, List<ParticipantModel> parts) {
    final fixtures = <FixtureModel>[];
    int matchNo = 1;
    for (int i = 0; i < parts.length; i++) {
      for (int j = i + 1; j < parts.length; j++) {
        fixtures.add(FixtureModel(
          id: 'f_${groupId}_rr_$matchNo',
          eventGroupId: groupId,
          round: 'Group Stage', matchNumber: matchNo,
          roundIndex: 0, matchIndex: matchNo - 1,
          teamAId: parts[i].id, teamAName: parts[i].name,
          teamBId: parts[j].id, teamBName: parts[j].name,
          date: '', time: '', court: '', status: 'scheduled',
          sets: const [], setsWonA: 0, setsWonB: 0,
          winnerId: '', isLive: false,
        ));
        matchNo++;
      }
    }
    return fixtures;
  }

  // Knockout generator — proper bracket with roundIndex/matchIndex
  static List<FixtureModel> generateKnockout(
      String groupId, List<ParticipantModel> parts) {
    final fixtures = <FixtureModel>[];
    int size = 1;
    while (size < parts.length) size *= 2;
    final padded = List<ParticipantModel>.from(parts);
    while (padded.length < size) {
      padded.add(ParticipantModel(id:'bye_${padded.length}', name:'BYE', playerNames:[]));
    }
    int matchNo = 1;
    // Round 1 — seed actual participants
    for (int i = 0; i < size; i += 2) {
      final a = padded[i]; final b = padded[i + 1];
      final isBye = a.name == 'BYE' || b.name == 'BYE';
      fixtures.add(FixtureModel(
        id: 'f_${groupId}_r0_${i~/2}', eventGroupId: groupId,
        round: _roundLabel(size), matchNumber: matchNo++,
        roundIndex: 0, matchIndex: i ~/ 2,
        teamAId: a.id, teamAName: a.name,
        teamBId: b.id, teamBName: b.name,
        date: '', time: '', court: '',
        status: isBye ? 'completed' : 'scheduled', sets: const [],
        setsWonA: b.name == 'BYE' ? 1 : 0,
        setsWonB: a.name == 'BYE' ? 1 : 0,
        winnerId: a.name == 'BYE' ? b.id : (b.name == 'BYE' ? a.id : ''),
        isLive: false,
      ));
    }
    // Later rounds — TBD placeholders
    int roundSize = size ~/ 2;
    int roundIdx = 1;
    while (roundSize >= 2) {
      final count = roundSize ~/ 2;
      for (int i = 0; i < count; i++) {
        fixtures.add(FixtureModel(
          id: 'f_${groupId}_r${roundIdx}_$i', eventGroupId: groupId,
          round: _roundLabel(roundSize), matchNumber: matchNo++,
          roundIndex: roundIdx, matchIndex: i,
          teamAId: '', teamAName: 'TBD', teamBId: '', teamBName: 'TBD',
          date: '', time: '', court: '', status: 'scheduled',
          sets: const [], setsWonA: 0, setsWonB: 0, winnerId: '', isLive: false,
        ));
      }
      roundSize ~/= 2;
      roundIdx++;
    }
    return fixtures;
  }

  static String _roundLabel(int size) {
    // size = number of participants in this round (bracket size)
    switch (size) {
      case 2:  return 'Final';
      case 4:  return 'Semi-Final';
      case 8:  return 'Quarter-Final';
      case 16: return 'Pre-Quarter-Final';
      case 32: return 'Round of 32';
      default: return 'Round of $size';
    }
  }

  // Ordered rounds for bracket display
  List<String> get orderedRounds {
    final seen = <String>{};
    final result = <String>[];
    final sorted = List<FixtureModel>.from(fixtures)
      ..sort((a, b) => a.roundIndex.compareTo(b.roundIndex));
    for (final f in sorted) {
      if (!seen.contains(f.round)) { seen.add(f.round); result.add(f.round); }
    }
    return result;
  }

  Map<String, List<FixtureModel>> get fixturesByRound {
    final map = <String, List<FixtureModel>>{};
    for (final f in fixtures) map.putIfAbsent(f.round, () => []).add(f);
    return map;
  }

  List<StandingRow> get standings {
    final map = <String, StandingRow>{};
    for (final p in participants) {
      map[p.id] = StandingRow(participantId:p.id, participantName:p.name,
          played:0, won:0, lost:0, gameDiff:0, points:0);
    }
    for (final f in fixtures) {
      if (!f.isCompleted || f.winnerId.isEmpty) continue;
      final a = map[f.teamAId]; final b = map[f.teamBId];
      if (a == null || b == null) continue;
      map[f.teamAId] = StandingRow(
        participantId: a.participantId, participantName: a.participantName,
        played: a.played+1,
        won:  f.winnerId == f.teamAId ? a.won+1  : a.won,
        lost: f.winnerId != f.teamAId ? a.lost+1 : a.lost,
        gameDiff: a.gameDiff + f.setsWonA - f.setsWonB,
        points: f.winnerId == f.teamAId ? a.points+3 : a.points,
      );
      map[f.teamBId] = StandingRow(
        participantId: b.participantId, participantName: b.participantName,
        played: b.played+1,
        won:  f.winnerId == f.teamBId ? b.won+1  : b.won,
        lost: f.winnerId != f.teamBId ? b.lost+1 : b.lost,
        gameDiff: b.gameDiff + f.setsWonB - f.setsWonA,
        points: f.winnerId == f.teamBId ? b.points+3 : b.points,
      );
    }
    final rows = map.values.toList()
      ..sort((a,b) {
        if (b.points != a.points) return b.points.compareTo(a.points);
        return b.gameDiff.compareTo(a.gameDiff);
      });
    return rows;
  }

  EventGroup copyWith({
    String? id, String? eventName, String? sportName, String? format,
    String? participantType, String? gender, int? maxParticipants,
    List<ParticipantModel>? participants, List<FixtureModel>? fixtures,
  }) => EventGroup(
    id: id??this.id, eventName: eventName??this.eventName,
    sportName: sportName??this.sportName, format: format??this.format,
    participantType: participantType??this.participantType,
    gender: gender??this.gender, maxParticipants: maxParticipants??this.maxParticipants,
    participants: participants??List.from(this.participants),
    fixtures: fixtures??List.from(this.fixtures),
  );

  Map<String, dynamic> toJson() => {
    'id':id,'eventName':eventName,'sportName':sportName,'format':format,
    'participantType':participantType,'gender':gender,'maxParticipants':maxParticipants,
    'participants':participants.map((p)=>p.toJson()).toList(),
    'fixtures':fixtures.map((f)=>f.toJson()).toList(),
  };

  static const List<String> formats = ['round_robin','knockout','custom'];
  static const List<String> participantTypes = ['Team','Individual'];
  static const List<String> genders = ['Open','Men','Women','Mixed'];
}

// ─────────────────────────────────────────────────────────────
// TOURNAMENT MODEL
// ─────────────────────────────────────────────────────────────
class TournamentModel {
  final String             id, name, subTypeLabel;
  final String             sportId, sportName;
  final String             eventId, eventName;
  final String             venueId, venueName, venueManual;
  final String             startDate, endDate, registrationDueDate;
  final String             contactName, contactEmail, contactPhone;
  final String             addressLine1, city, state, country, pinCode;
  final String             banner, description, status;
  final List<EventGroup>   eventGroups;
  final List<SponsorModel> sponsors;
  final String             createdAt, updatedAt;

  const TournamentModel({
    required this.id, required this.name, required this.subTypeLabel,
    required this.sportId, required this.sportName,
    required this.eventId, required this.eventName,
    required this.venueId, required this.venueName,
    this.venueManual = '',
    required this.startDate, required this.endDate,
    this.registrationDueDate = '',
    this.contactName = '', this.contactEmail = '', this.contactPhone = '',
    this.addressLine1 = '', this.city = '', this.state = '',
    this.country = 'India', this.pinCode = '',
    required this.banner, required this.description, required this.status,
    required this.eventGroups, this.sponsors = const [],
    required this.createdAt, required this.updatedAt,
  });

  bool get isDraft     => status == 'draft';
  bool get isPublished => status == 'published';
  bool get isCompleted => status == 'completed';
  bool get hasBanner   => banner.isNotEmpty;

  String get effectiveVenue => venueManual.isNotEmpty ? venueManual : venueName;

  int get totalMatches      => eventGroups.fold(0,(s,g)=>s+g.fixtures.length);
  int get completedMatches  => eventGroups.fold(0,(s,g)=>s+g.fixtures.where((f)=>f.isCompleted).length);
  int get totalParticipants => eventGroups.fold(0,(s,g)=>s+g.participants.length);
  int get liveMatches       => eventGroups.fold(0,(s,g)=>s+g.fixtures.where((f)=>f.isLive).length);
  bool get hasLive          => liveMatches > 0;
  List<FixtureModel> get allFixtures => [for (final g in eventGroups) ...g.fixtures];

  Color get statusColor {
    switch (status) {
      case 'draft':     return const Color(0xFF6B7280);
      case 'published': return const Color(0xFF16A34A);
      case 'completed': return const Color(0xFF7C3AED);
      default:          return const Color(0xFF6B7280);
    }
  }
  String get statusLabel {
    switch (status) {
      case 'draft':     return 'Draft';
      case 'published': return 'Published';
      case 'completed': return 'Completed';
      default:          return status;
    }
  }

  TournamentModel copyWith({
    String? id, String? name, String? subTypeLabel,
    String? sportId, String? sportName, String? eventId, String? eventName,
    String? venueId, String? venueName, String? venueManual,
    String? startDate, String? endDate, String? registrationDueDate,
    String? contactName, String? contactEmail, String? contactPhone,
    String? addressLine1, String? city, String? state, String? country, String? pinCode,
    String? banner, String? description, String? status,
    List<EventGroup>? eventGroups, List<SponsorModel>? sponsors,
    String? createdAt, String? updatedAt,
  }) => TournamentModel(
    id: id??this.id, name: name??this.name, subTypeLabel: subTypeLabel??this.subTypeLabel,
    sportId: sportId??this.sportId, sportName: sportName??this.sportName,
    eventId: eventId??this.eventId, eventName: eventName??this.eventName,
    venueId: venueId??this.venueId, venueName: venueName??this.venueName,
    venueManual: venueManual??this.venueManual,
    startDate: startDate??this.startDate, endDate: endDate??this.endDate,
    registrationDueDate: registrationDueDate??this.registrationDueDate,
    contactName: contactName??this.contactName, contactEmail: contactEmail??this.contactEmail,
    contactPhone: contactPhone??this.contactPhone,
    addressLine1: addressLine1??this.addressLine1, city: city??this.city,
    state: state??this.state, country: country??this.country, pinCode: pinCode??this.pinCode,
    banner: banner??this.banner, description: description??this.description,
    status: status??this.status,
    eventGroups: eventGroups??List.from(this.eventGroups),
    sponsors: sponsors??List.from(this.sponsors),
    createdAt: createdAt??this.createdAt,
    updatedAt: updatedAt??DateTime.now().toIso8601String().substring(0,10),
  );

  Map<String, dynamic> toJson() => {
    'id':id,'name':name,'subTypeLabel':subTypeLabel,
    'sportId':sportId,'sportName':sportName,'eventId':eventId,'eventName':eventName,
    'venueId':venueId,'venueName':venueName,'venueManual':venueManual,
    'startDate':startDate,'endDate':endDate,'registrationDueDate':registrationDueDate,
    'contactName':contactName,'contactEmail':contactEmail,'contactPhone':contactPhone,
    'addressLine1':addressLine1,'city':city,'state':state,'country':country,'pinCode':pinCode,
    'banner':banner,'description':description,'status':status,
    'eventGroups':eventGroups.map((g)=>g.toJson()).toList(),
    'sponsors':sponsors.map((s)=>s.toJson()).toList(),
    'createdAt':createdAt,'updatedAt':updatedAt,
  };
}

// ─────────────────────────────────────────────────────────────
// SEED DATA  — 1 dummy tournament with 3 events
// ─────────────────────────────────────────────────────────────
class TournamentSeeds {
  // ── Event 1: Women's Doubles — Round Robin (4 pairs) ──────
  static final _womenParts = [
    ParticipantModel(id:'wp1', name:'Nimisha / Sneha',
        playerNames:['Nimisha Idekar','Sneha Bhavsar'], seed:'1'),
    ParticipantModel(id:'wp2', name:'Priya / Kavya',
        playerNames:['Priya Sharma','Kavya Nair'], seed:'2'),
    ParticipantModel(id:'wp3', name:'Riya / Neha',
        playerNames:['Riya Kapoor','Neha Joshi'], seed:'3'),
    ParticipantModel(id:'wp4', name:'Divya / Ananya',
        playerNames:['Divya Mehta','Ananya Rao'], seed:'4'),
  ];
  static final _womenFixtures = () {
    final list = EventGroup.generateRoundRobin('eg1', _womenParts);
    // Seed completed results
    list[0] = list[0].copyWith(status:'completed',
        sets:[SetScore(scoreA:6,scoreB:4),SetScore(scoreA:6,scoreB:3)],
        setsWonA:2,setsWonB:0,winnerId:'wp1',
        date:'2026-03-14',time:'10:00',court:'Court 1',venueName:'Prime Padel Club');
    list[1] = list[1].copyWith(status:'completed',
        sets:[SetScore(scoreA:4,scoreB:6),SetScore(scoreA:7,scoreB:5),SetScore(scoreA:6,scoreB:4)],
        setsWonA:2,setsWonB:1,winnerId:'wp1',
        date:'2026-03-14',time:'11:30',court:'Court 2',venueName:'Prime Padel Club');
    
    list[3] = list[3].copyWith(date:'2026-03-14',time:'14:30',court:'Court 2',venueName:'Prime Padel Club');
    list[4] = list[4].copyWith(date:'2026-03-15',time:'10:00',court:'Court 1',venueName:'Prime Padel Club');
    list[5] = list[5].copyWith(date:'2026-03-15',time:'11:30',court:'Court 3',venueName:'Prime Padel Club');
    return list;
  }();

  // ── Event 2: Men's Singles — Knockout (8 players) ─────────
  static final _menParts = [
    ParticipantModel(id:'mp1', name:'Arjun Mehta',     playerNames:[], seed:'1'),
    ParticipantModel(id:'mp2', name:'Rahul Gupta',     playerNames:[], seed:'2'),
    ParticipantModel(id:'mp3', name:'Vikram Singh',    playerNames:[], seed:'3'),
    ParticipantModel(id:'mp4', name:'Aditya Joshi',    playerNames:[], seed:'4'),
    ParticipantModel(id:'mp5', name:'Siddharth Nair',  playerNames:[], seed:'5'),
    ParticipantModel(id:'mp6', name:'Karthik Iyer',    playerNames:[], seed:'6'),
    ParticipantModel(id:'mp7', name:'Dev Kapoor',      playerNames:[], seed:'7'),
    ParticipantModel(id:'mp8', name:'Rohan Shah',      playerNames:[], seed:'8'),
  ];
  static final _menFixtures = () {
    final list = EventGroup.generateKnockout('eg2', _menParts);
    // QF1 completed
    final qf1 = list.indexWhere((f)=>f.roundIndex==0&&f.matchIndex==0);
    if (qf1!=-1) list[qf1] = list[qf1].copyWith(
      status:'completed',winnerId:'mp1',setsWonA:2,setsWonB:0,
      sets:[SetScore(scoreA:6,scoreB:3),SetScore(scoreA:6,scoreB:4)],
      date:'2026-03-14',time:'09:00',court:'Centre Court',venueName:'Prime Padel Club',
    );
    // QF2 live
    final qf2 = list.indexWhere((f)=>f.roundIndex==0&&f.matchIndex==1);
    if (qf2!=-1) list[qf2] = list[qf2].copyWith(
      status:'live',isLive:true,
      sets:[SetScore(scoreA:4,scoreB:6)],setsWonA:0,setsWonB:1,
      date:'2026-03-14',time:'11:00',court:'Centre Court',venueName:'Prime Padel Club',
      liveStreamUrl:'https://youtube.com/live/xyz789',
    );
    return list;
  }();

  // ── Event 3: Mixed Doubles — Round Robin (4 pairs) ────────
  static final _mixedParts = [
    ParticipantModel(id:'mx1', name:'Arjun / Priya',    playerNames:['Arjun Mehta','Priya Sharma'],    seed:'1'),
    ParticipantModel(id:'mx2', name:'Rahul / Divya',    playerNames:['Rahul Gupta','Divya Mehta'],     seed:'2'),
    ParticipantModel(id:'mx3', name:'Vikram / Riya',    playerNames:['Vikram Singh','Riya Kapoor'],    seed:'3'),
    ParticipantModel(id:'mx4', name:'Aditya / Ananya',  playerNames:['Aditya Joshi','Ananya Rao'],     seed:'4'),
  ];
  static final _mixedFixtures = () {
    final list = EventGroup.generateRoundRobin('eg3', _mixedParts);
    list[0] = list[0].copyWith(date:'2026-03-15',time:'09:00',court:'Court 3',venueName:'Prime Padel Club');
    list[1] = list[1].copyWith(date:'2026-03-15',time:'10:30',court:'Court 4',venueName:'Prime Padel Club');
    list[2] = list[2].copyWith(date:'2026-03-15',time:'12:00',court:'Court 3',venueName:'Prime Padel Club');
    return list;
  }();

  static final List<TournamentModel> all = [
    TournamentModel(
      id:'trn1', name:'Mumbai Padel Open 2026', subTypeLabel:'Open Championship',
      sportId:'sp1', sportName:'Padel',
      eventId:'e1',  eventName:'Padel Open',
      venueId:'v2',  venueName:'Prime Padel Club',
      startDate:'2026-03-14', endDate:'2026-03-16',
      registrationDueDate:'2026-03-10',
      contactName:'Padel Park Mumbai', contactEmail:'info@padelpark.in',
      contactPhone:'9820012345',
      city:'Mumbai', state:'Maharashtra', country:'India',
      banner:'', description:'Annual Mumbai Padel Open — featuring Women\'s Doubles, Men\'s Singles Knockout and Mixed Doubles. India\'s premier padel championship.',
      status:'published',
      eventGroups:[
        EventGroup(id:'eg1', eventName:"Women's Doubles", sportName:"Women's Doubles",
            format:'round_robin', participantType:'Pair', gender:'Women',
            participants:_womenParts, fixtures:_womenFixtures),
        EventGroup(id:'eg2', eventName:"Men's Singles", sportName:"Men's Singles",
            format:'knockout', participantType:'Individual', gender:'Men',
            participants:_menParts, fixtures:_menFixtures),
       
      ],
      sponsors:const [],
      createdAt:'2026-01-15', updatedAt:'2026-03-01',
    ),
  ];

  static const List<Map<String,String>> sports = [
    {'id':'sp1','name':'Padel'},   {'id':'sp2','name':'Tennis'},
    {'id':'sp3','name':'Badminton'},{'id':'sp4','name':'Squash'},
    {'id':'sp5','name':'Cricket'}, {'id':'sp6','name':'Table Tennis'},
  ];
  static const List<Map<String,String>> events = [
    {'id':'e1','name':'Padel Open'},   {'id':'e2','name':'Cricket Cup'},
    {'id':'e3','name':'Tennis Open'},  {'id':'e4','name':'Badminton Open'},
    {'id':'e5','name':'Club Championship'},
  ];
  static const List<Map<String,String>> venues = [
    {'id':'v1','name':'Wankhede Stadium'},  {'id':'v2','name':'Prime Padel Club'},
    {'id':'v3','name':'DY Patil Stadium'},  {'id':'v4','name':'Brabourne Stadium'},
    {'id':'v5','name':'Cooperage Ground'},
  ];
  static const List<String> courts = [
    'Court 1','Court 2','Court 3','Court 4','Centre Court','Main Arena',
  ];
  // venue busy slots: venueId → "yyyy-MM-dd HH:mm"
  static const Map<String,List<String>> busySlots = {
    'v1': ['2026-03-14 10:00','2026-03-14 12:00','2026-03-15 09:00'],
    'v2': ['2026-03-14 13:00','2026-03-15 10:30'],
    'v3': [], 'v4': ['2026-03-14 14:00'], 'v5': [],
  };
}