import 'package:dio/dio.dart';

class AuthAPI {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "https://dev.sports-next.com/api",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
    ),
  );

  // ✅ REGISTER (FIXED)
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        "/register",
        data: {
          "name": fullName,
          "email": email,
          "password": password,
          "password_confirmation": password,
        },
      );

      print("REGISTER RESPONSE: ${res.data}");

      return res.data; // ✅ direct backend response
    } catch (e) {
      if (e is DioException && e.response != null) {
        print("REGISTER ERROR: ${e.response?.data}");

        return e.response!.data; // ✅ real backend error
      }

      return {"success": false, "message": "Something went wrong"};
    }
  }

  // ✅ LOGIN (ALREADY CORRECT)
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        "/login",
        data: {"email": email, "password": password},
      );

      print("LOGIN RESPONSE: ${res.data}");

      return res.data;
    } catch (e) {
      if (e is DioException && e.response != null) {
        print("LOGIN ERROR: ${e.response?.data}");

        return e.response!.data;
      }

      return {"success": false, "message": "Something went wrong"};
    }
  }
}
