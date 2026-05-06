import 'dart:html' as html;

class AppSession {
  static String get token => html.window.localStorage["token"] ?? "";

  static int get roleId =>
      int.tryParse(html.window.localStorage["role_id"] ?? "0") ?? 0;

  static String get tournamentId =>
      html.window.localStorage["tournamentId"] ?? "";

  static void setTournament(String id) {
    html.window.localStorage["tournamentId"] = id;
  }
}
