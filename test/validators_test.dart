import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('rejects empty and whitespace', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
    });

    test('rejects invalid formats', () {
      expect(Validators.email('plain'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('a b@c.com'), isNotNull);
    });

    test('accepts valid emails', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email(' first.last+tag@sub.example.co '), isNull);
    });
  });

  group('Validators.password', () {
    test('requires a value', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password(null), isNotNull);
    });

    test('enforces minimum length', () {
      expect(Validators.password('Ab1'), isNotNull);
    });

    test('enforces character classes', () {
      expect(Validators.password('abcdefgh'), isNotNull); // no upper, no digit
      expect(Validators.password('ABCDEFGH'), isNotNull); // no lower, no digit
      expect(Validators.password('ABCDEFG1'), isNotNull); // no lower
      expect(Validators.password('abcdefgh1'), isNotNull); // no upper
    });

    test('accepts a strong password', () {
      expect(Validators.password('Abcdefg1'), isNull);
      expect(Validators.password('P@ssw0rd!2026'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('requires confirmation', () {
      expect(Validators.confirmPassword('', 'Secret1'), isNotNull);
      expect(Validators.confirmPassword(null, 'Secret1'), isNotNull);
    });

    test('rejects mismatch', () {
      expect(Validators.confirmPassword('Secret2', 'Secret1'), isNotNull);
    });

    test('accepts match', () {
      expect(Validators.confirmPassword('Secret1', 'Secret1'), isNull);
    });
  });

  group('Validators.fullName', () {
    test('requires a name', () {
      expect(Validators.fullName(null), isNotNull);
      expect(Validators.fullName(''), isNotNull);
      expect(Validators.fullName('A'), isNotNull);
    });

    test('rejects non-letter names', () {
      expect(Validators.fullName('1234'), isNotNull);
    });

    test('accepts a real name', () {
      expect(Validators.fullName('Jane Doe'), isNull);
    });
  });

  group('Validators.otp', () {
    test('requires a 6-digit code', () {
      expect(Validators.otp(null), isNotNull);
      expect(Validators.otp(''), isNotNull);
      expect(Validators.otp('12345'), isNotNull);
      expect(Validators.otp('1234567'), isNotNull);
      expect(Validators.otp('abc123'), isNotNull);
    });

    test('accepts exactly 6 digits', () {
      expect(Validators.otp('123456'), isNull);
    });
  });

  group('Validators.passwordStrength', () {
    test('scores length, case, digits and symbols', () {
      expect(Validators.passwordStrength(''), 0);
      expect(Validators.passwordStrength('abcdefgh'), 1); // length
      expect(Validators.passwordStrength('Abcdefgh'), 2); // + upper
      expect(Validators.passwordStrength('Abcdefg1'), 3); // + digit
      expect(Validators.passwordStrength('Abcdefg1!'), 4); // + symbol
    });
  });
}
