import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:tms_flutter/core/session/app_session.dart';
import '/core/session/app_session.dart';

class TournamentService {
  static const baseUrl = "https://dev.sports-next.com/api";

  static Future<Map<String, dynamic>> createTournament(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/tournaments"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode(data),
    );

    return jsonDecode(response.body);
  }

  // ================= STORE MATCHES =================
  static Future<Map<String, dynamic>> storeMatches(
    String eventGroupId,
    List<Map<String, dynamic>> matches,
  ) async {
    final url = Uri.parse("$baseUrl/event-groups/$eventGroupId/matches");

    final body = {
      "matches": matches, // 🔥 DIRECT PASS (NO mapping)
    };

    print("🚀 SENDING MATCHES: ${jsonEncode(body)}");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    print("📡 MATCH RESPONSE: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data ?? {};
    } else {
      throw Exception(data['message'] ?? "Failed to store matches");
    }
  }

  static Future<void> markCompleted(String id) async {
    await http.put(
      Uri.parse("$baseUrl/tournaments/$id/status"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode({"status": "completed"}),
    );
  }

  static Future<List<dynamic>> getTournaments() async {
    print("🔑 LIST TOKEN: ${AppSession.token}");

    final response = await http.get(
      Uri.parse("$baseUrl/tournaments"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
    );

    print("📡 LIST STATUS: ${response.statusCode}");
    print("📡 LIST BODY: ${response.body}");

    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    } else if (data['data'] != null) {
      return data['data'];
    }

    return [];
  }

  static Future<void> deleteTournament(dynamic id) async {
    await http.delete(
      Uri.parse("$baseUrl/tournaments/$id"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
    );
  }

  static Future<Map<String, dynamic>> updateStatus(
    String id,
    String status,
  ) async {
    final res = await http.patch(
      Uri.parse("$baseUrl/tournaments/$id/status"),
      headers: {
        "Authorization": "Bearer ${AppSession.token}",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"status": status}),
    );

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateTournament(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse("$baseUrl/tournaments/$id"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode(data),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getTournamentById(String id) async {
    final response = await http.get(
      Uri.parse("$baseUrl/tournaments/$id"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
    );

    print("🔑 TOKEN: ${AppSession.token}");

    return jsonDecode(response.body);
  }

  static Future<String?> uploadBanner(String tournamentId, File file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/tournaments/$tournamentId/banner"),
    );

    request.headers['Authorization'] = "Bearer ${AppSession.token}";
    request.headers['Accept'] = "application/json";

    request.files.add(await http.MultipartFile.fromPath('banner', file.path));

    final response = await request.send();

    final resBody = await response.stream.bytesToString();
    final data = jsonDecode(resBody);

    print("📤 BANNER STATUS: ${response.statusCode}");
    print("📤 BANNER RESPONSE: $data");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data['data']?['banner_url'];
    }

    return null;
  }

  // ================== SPONSOR APIs ==================

  // GET sponsors
  static Future<List<dynamic>> getSponsors(String tournamentId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/tournaments/$tournamentId/sponsors"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
    );

    final data = jsonDecode(res.body);

    if (data is List) return data;
    return data['data'] ?? [];
  }

  // ADD sponsor
  static Future<Map<String, dynamic>?> addSponsor(
    String tournamentId,
    List<int> bytes,
    String filename,
    String name,
    String url,
  ) async {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/tournaments/$tournamentId/sponsors"),
    );

    request.headers["Authorization"] = "Bearer ${AppSession.token}";
    request.headers["Accept"] = "application/json";

    request.files.add(
      http.MultipartFile.fromBytes("logo", bytes, filename: filename),
    );

    request.fields["name"] = name;
    request.fields["url"] = url;

    final response = await request.send();
    final body = await response.stream.bytesToString();

    print("📤 SPONSOR STATUS: ${response.statusCode}");
    print("📤 SPONSOR RESPONSE: $body");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(body);
    }

    return null;
  }

  // DELETE sponsor
  static Future<bool> deleteSponsor(
    String tournamentId,
    String sponsorId,
  ) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/tournaments/$tournamentId/sponsors/$sponsorId"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
    );

    return res.statusCode == 200;
  }

  // UPDATE SPONSOR
  static Future<bool> updateSponsor(String id, String name, String url) async {
    final res = await http.put(
      Uri.parse("$baseUrl/tournaments/sponsors/$id"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode({"name": name, "url": url}),
    );

    return res.statusCode == 200;
  }

  static Future<String?> uploadFixtureImage(
    String tournamentId,
    List<int> bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/tournaments/$tournamentId/fixture-image"),
    );

    request.headers['Authorization'] = "Bearer ${AppSession.token}";
    request.headers['Accept'] = "application/json";

    request.files.add(
      http.MultipartFile.fromBytes("fixture_image", bytes, filename: filename),
    );

    final response = await request.send();
    final resBody = await response.stream.bytesToString();
    final data = jsonDecode(resBody);

    print("📤 FIXTURE IMAGE STATUS: ${response.statusCode}");
    print("📤 FIXTURE IMAGE RESPONSE: $data");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data['data']?['fixture_image'];
    }

    return null;
  }

  static Future<void> completeMatch(String matchId) async {
    final res = await http.patch(
      Uri.parse("$baseUrl/matches/$matchId/complete"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to complete match");
    }
  }

  static Future<void> updateMatch({
    required String matchId,
    String? status,
    String? date,
    String? time,
    String? court,
    String? winner_team_name,
    String? winner_team_id,
    String? teamAId,
    String? teamBId,
  }) async {
    final body = <String, dynamic>{};

    // ✅ STATUS
    if (status != null) {
      body["status"] = status.toLowerCase();
    }

    // ✅ DATE / TIME / COURT
    if (date != null && date.isNotEmpty) body["match_date"] = date;
    if (time != null && time.isNotEmpty) body["match_time"] = time;
    if (court != null && court.isNotEmpty) body["court"] = court;

    // ==============================
    // 🔥 WINNER FIX (CRITICAL)
    // ==============================

    if (status == "completed") {
      body["winner_team_name"] = winner_team_name;
      body["winner_team_id"] =
          (winner_team_id != null && winner_team_id.isNotEmpty)
          ? int.tryParse(winner_team_id)
          : null;
    } else {
      // ❌ DO NOT SEND WINNER
      body["winner_team_name"] = null;
      body["winner_team_id"] = null;
    }

    // ==============================
    // 🔥 TEAM UPDATE (ONLY IF PROVIDED)
    // ==============================

    if (teamAId != null) {
      body["team_a_id"] = teamAId.isEmpty ? null : int.tryParse(teamAId);
    }

    if (teamBId != null) {
      body["team_b_id"] = teamBId.isEmpty ? null : int.tryParse(teamBId);
    }

    print("🚀 UPDATE BODY: ${jsonEncode(body)}");

    final res = await http.patch(
      Uri.parse("$baseUrl/matches/$matchId"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    print("📡 UPDATE RESPONSE: ${res.body}");

    if (res.statusCode == 200) return;

    if (res.statusCode == 409) {
      final data = jsonDecode(res.body);
      throw Exception(data['type']);
    }

    throw Exception("update_failed");
  }

  // 🔥 UPDATE FIXTURE TEAMS
  static Future<void> updateFixtureTeams(
    String matchId,
    String teamA,
    String teamB,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/fixtures/$matchId/update-teams"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode({"team_a_name": teamA, "team_b_name": teamB}),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update fixture");
    }
  }

  static Future createManualMatch(Map data) async {
    final res = await http.post(
      Uri.parse("$baseUrl/manual-matches"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode(data),
    );

    return jsonDecode(res.body);
  }

  static Future getManualMatches(String eventGroupId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/manual-matches/$eventGroupId"),
      headers: {"Authorization": "Bearer ${AppSession.token}"},
    );

    return jsonDecode(res.body);
  }

  static Future updateManualMatch(String id, Map data) async {
    final res = await http.patch(
      Uri.parse("$baseUrl/manual-matches/$id"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode(data),
    );

    print("🔥 MANUAL UPDATE BODY: ${jsonEncode(data)}");
    print("🔥 MANUAL UPDATE RESPONSE: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("Failed to update manual match");
    }

    return jsonDecode(res.body);
  }

  static Future<void> deleteMatch(String matchId) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/matches/$matchId"),
      headers: {
        "Authorization": "Bearer ${AppSession.token}",
        "Accept": "application/json",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Delete failed");
    }
  }

  static Future deleteManualMatch(String id) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/manual-matches/$id"),
      headers: {"Authorization": "Bearer ${AppSession.token}"},
    );

    if (res.statusCode != 200) {
      throw Exception("Delete failed");
    }
  }

  static Future createBracket(
    String eventGroupId,
    int size,
    String tournamentId,
  ) async {
    print("🔥 API REQUEST START");
    print("event_group_id: $eventGroupId");
    print("round_size: $size");
    print("tournament_id: $tournamentId");

    final url = "$baseUrl/manual-matches/create-bracket";

    print("API CALL → $url");
    print(
      "BODY → ${jsonEncode({"event_group_id": eventGroupId, "round_size": size, "tournament_id": tournamentId})}",
    );

    final res = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode({
        "event_group_id": eventGroupId,
        "round_size": size,
        "tournament_id": tournamentId,
      }),
    );

    print("🔥 STATUS: ${res.statusCode}");
    print("🔥 RESPONSE: ${res.body}");

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Server Error: ${res.body}");
    }
  }

  static Future deleteAllManualMatches(String groupId) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/manual-matches/delete-all/$groupId"),
      headers: {"Authorization": "Bearer ${AppSession.token}"},
    );

    if (res.statusCode != 200) {
      throw Exception("Delete failed");
    }
  }

  static Future<Map<String, dynamic>> submitResult({
    required String fixtureId,
    required int homeScore,
    required int awayScore,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/fixtures/$fixtureId/result"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode({
        "home_score": homeScore,
        "away_score": awayScore,
        "notes": null,
      }),
    );

    print("🔥 RESULT STATUS: ${response.statusCode}");
    print("🔥 RESULT BODY: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Result API failed: ${response.body}");
    }
  }

  static Future<List<dynamic>> getStandings(String stageId) async {

    final response = await http.get(
      Uri.parse("$baseUrl/standings/$stageId"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
    );

    print("🔥 STANDINGS RESPONSE: ${response.body}");

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data'] ?? []; // ✅ FIX
    } else {
      throw Exception("Failed to load standings");
    }
  }

  static Future<Map<String, dynamic>> getFixtures(
    String tournamentId,
    String stageId,
  ) async {
    final res = await http.get(
      Uri.parse("$baseUrl/tournaments/$tournamentId/stages/$stageId/fixtures"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
    );

    print("🔥 GET FIXTURES STATUS: ${res.statusCode}");
    print("🔥 GET FIXTURES BODY: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("Failed to fetch fixtures");
    }

    return jsonDecode(res.body);
  }

  static Future<void> updateStanding(
    String id,
    Map<String, dynamic> data,
  ) async {
    final res = await http.put(
      Uri.parse("$baseUrl/standings/$id"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode(data),
    );

    print("🔥 UPDATE STANDING RESPONSE: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("Failed to update standing");
    }
  }

  static Future<void> restoreStandings(String eventGroupId) async {
    final res = await http.post(
      Uri.parse("$baseUrl/standings/$eventGroupId/restore"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
    );

    print("🔥 RESTORE RESPONSE: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("Failed to restore standings");
    }
  }

  static Future<void> saveScore({
    required String fixtureId,
    required int homeScore,
    required int awayScore,
    int? superTbWinnerId,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/fixtures/$fixtureId/result"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode({
        "home_score": homeScore,
        "away_score": awayScore,
        "super_tb_winner_id": superTbWinnerId,
      }),
    );

    print("🔥 SCORE SAVE RESPONSE: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("Score not saved");
    }
  }

  // ==============================
  // 🔥 RR MANUAL (FRESH CLEAN)
  // ==============================

  // GET RR MANUAL MATCHES
  static Future<Map<String, dynamic>> getRRManualMatches(String groupId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/rr-manual/$groupId"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
    );

    print("🔥 RR MANUAL GET: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("Failed to fetch RR manual matches");
    }

    return jsonDecode(res.body);
  }

  // CREATE BRACKET
  static Future<void> createRRManualBracket(
    String groupId,
    int size,
    String tournamentId,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/manual-matches/create-bracket"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode({
        "event_group_id": groupId,
        "round_size": size,
        "tournament_id": tournamentId,
      }),
    );

    print("🔥 CREATE RR: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("Create bracket failed");
    }
  }

  // UPDATE MATCH (🔥 DATE/TIME FIX INCLUDED)
  static Future<void> updateRRManualMatch(
    String id,
    Map<String, dynamic> data,
  ) async {
    final res = await http.patch(
      Uri.parse("$baseUrl/manual-matches/$id"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
      body: jsonEncode(data),
    );

    print("🔥 RR UPDATE BODY: ${jsonEncode(data)}");
    print("🔥 RR UPDATE RESPONSE: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("Update failed");
    }
  }

  // DELETE ALL BRACKET
  static Future<void> deleteRRManualMatches(String groupId) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/rr-manual/$groupId"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer ${AppSession.token}",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Delete failed");
    }
  }
}
