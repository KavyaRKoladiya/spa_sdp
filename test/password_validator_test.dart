import 'package:flutter_test/flutter_test.dart';
import 'package:spa_sdp/utils/password_validator.dart';

void main() {
  group('PasswordValidator Rules Tests', () {
    test('Empty or null password returns required message', () {
      expect(PasswordValidator.validate(null), 'Please enter your password');
      expect(PasswordValidator.validate(''), 'Please enter your password');
    });

    test('Password containing spaces is rejected', () {
      expect(
        PasswordValidator.validate('Pass word1@'),
        'Password must not contain spaces',
      );
      expect(
        PasswordValidator.validate(' Password1@'),
        'Password must not contain spaces',
      );
      expect(
        PasswordValidator.validate('Password1@ '),
        'Password must not contain spaces',
      );
    });

    test('Password shorter than 8 characters is rejected', () {
      expect(
        PasswordValidator.validate('Pass1@'),
        'Password must be at least 8 characters',
      );
    });

    test('Password longer than 20 characters is rejected', () {
      expect(
        PasswordValidator.validate('Abcdefghij12345678901@'),
        'Password must not exceed 20 characters',
      );
    });

    test('Password without uppercase letter (A-Z) is rejected', () {
      expect(
        PasswordValidator.validate('password123@'),
        'Password must contain at least 1 uppercase letter (A-Z)',
      );
    });

    test('Password without lowercase letter (a-z) is rejected', () {
      expect(
        PasswordValidator.validate('PASSWORD123@'),
        'Password must contain at least 1 lowercase letter (a-z)',
      );
    });

    test('Password without digit (0-9) is rejected', () {
      expect(
        PasswordValidator.validate('Password@@@'),
        'Password must contain at least 1 digit (0-9)',
      );
    });

    test('Password without allowed special character (@ # \$ % ! & *) is rejected', () {
      expect(
        PasswordValidator.validate('Password123'),
        'Password must contain at least 1 special character (@ # \$ % ! & *)',
      );
      // Other symbols not in the allowed list
      expect(
        PasswordValidator.validate('Password123^'),
        'Password must contain at least 1 special character (@ # \$ % ! & *)',
      );
    });

    test('Valid passwords matching all rules pass validation', () {
      expect(PasswordValidator.validate('Password123@'), isNull);
      expect(PasswordValidator.validate('Student#2024'), isNull);
      expect(PasswordValidator.validate('StudyPlanner1\$'), isNull);
      expect(PasswordValidator.validate('Abcdef1%'), isNull);
      expect(PasswordValidator.validate('TestPass!1'), isNull);
      expect(PasswordValidator.validate('Secure&Pass9'), isNull);
      expect(PasswordValidator.validate('Alpha*Beta8'), isNull);
    });
  });
}
