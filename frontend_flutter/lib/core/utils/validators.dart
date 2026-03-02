class Validators {
  static String? validateEmail(String email) {
    if (email.isEmpty) return "Email is required";
    if (!email.contains("@") || !email.contains(".")) {
      return "Enter a valid email";
    }
    return null;
  }

  static String? validatePassword(String password) {
    if (password.isEmpty) return "Password is required";
    if (password.length < 6) return "Password must be at least 6 characters";
    return null;
  }

  static String? validateName(String name) {
    if (name.isEmpty) return "Full name is required";
    return null;
  }
}