/// Pure, testable input validation used by all auth forms.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email address is required.';
    if (!_email.hasMatch(v)) return 'Please enter a valid email address.';
    return null;
  }

  /// Light rule used on the login form (full rules apply at signup).
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Full name is required.';
    if (v.length < 2) return 'Please enter your full name.';
    if (!RegExp(r"[a-zA-Z\u00C0-\u017F]").hasMatch(v)) {
      return 'Name must contain letters.';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[a-z]').hasMatch(v)) {
      return 'Add at least one lowercase letter.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(v)) {
      return 'Add at least one uppercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Add at least one number.';
    return null;
  }

  static String? confirmPassword(String? value, String? original) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? otp(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter the 6-digit code.';
    if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'Enter a valid 6-digit code.';
    return null;
  }

  /// Scores password strength 0-4 (length, uppercase, number, symbol).
  static int passwordStrength(String value) {
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }
}
