/// Utility for validating student passwords according to security requirements:
/// - Minimum length: 8 characters
/// - Maximum length: 20 characters
/// - At least 1 uppercase letter: A-Z
/// - At least 1 lowercase letter: a-z
/// - At least 1 digit: 0-9
/// - At least 1 special character: @ # $ % ! & *
/// - No spaces
class PasswordValidator {
  static const int minLength = 8;
  static const int maxLength = 20;

  /// Returns null if [password] satisfies all rules, or a user-friendly error message.
  static String? validate(String? password) {
    if (password == null || password.isEmpty) {
      return 'Please enter your password';
    }
    if (password.contains(' ')) {
      return 'Password must not contain spaces';
    }
    if (password.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (password.length > maxLength) {
      return 'Password must not exceed $maxLength characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least 1 uppercase letter (A-Z)';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain at least 1 lowercase letter (a-z)';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least 1 digit (0-9)';
    }
    if (!RegExp(r'[@#$%!&*]').hasMatch(password)) {
      return 'Password must contain at least 1 special character (@ # \$ % ! & *)';
    }
    return null;
  }

  /// List of human-readable password policy rules.
  static const List<String> rules = [
    'Minimum length: 8 characters',
    'Maximum length: 20 characters',
    'At least 1 uppercase letter: A-Z',
    'At least 1 lowercase letter: a-z',
    'At least 1 digit: 0-9',
    'At least 1 special character: @ # \$ % ! & *',
    'No spaces',
  ];
}
