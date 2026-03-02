class FakeAuthAPI {
  static final List<Map<String, String>> _users = [];

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final existing = _users.any((u) => u["email"] == email);

    if (existing) {
      return {"success": false, "message": "Email already registered"};
    }

    _users.add({
      "name": fullName,
      "email": email,
      "password": password,
      "role": role,
    });

    print("USER REGISTERED: $fullName ($email)");
    print("CURRENT USERS: $_users"); // <-- SEE USERS IN CONSOLE

    return {"success": true};
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final user = _users.firstWhere(
      (u) => u["email"] == email && u["password"] == password,
      orElse: () => {},
    );

    print("LOGIN ATTEMPT --> email: $email | password: $password");
    print("CURRENT USERS: $_users"); // <-- SEE USERS AGAIN

    if (user.isEmpty) {
      return {"success": false, "message": "Invalid email or password"};
    }

    return {"success": true, "user": user};
  }
}