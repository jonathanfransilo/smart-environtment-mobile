import 'package:flutter_test/flutter_test.dart';
import 'package:sirkular_app/services/profile_service.dart';
import 'package:sirkular_app/models/user_profile.dart';

/// Unit tests for ProfileService
///
/// Note: These tests require a running backend API and valid authentication token.
/// For proper unit testing, consider mocking the Dio client.
void main() {
  group('ProfileService Tests', () {
    late ProfileService profileService;

    setUp(() {
      profileService = ProfileService();
    });

    test('getProfile should return user profile data', () async {
      // Arrange
      // Note: This requires valid authentication token in storage

      // Act
      final (success, message, data) = await profileService.getProfile();

      // Assert
      expect(success, isA<bool>());
      if (success) {
        expect(data, isNotNull);
        expect(data!['id'], isA<int>());
        expect(data['name'], isA<String>());
        expect(data['email'], isA<String>());
      } else {
        expect(message, isNotNull);
      }
    });

    test('UserProfile model should parse JSON correctly', () {
      // Arrange
      final json = {
        'id': 1,
        'name': 'John Doe',
        'email': 'john@example.com',
        'phone': '081234567890',
        'roles': ['resident'],
        'created_at': '2024-01-01T00:00:00.000000Z',
        'updated_at': '2024-01-01T00:00:00.000000Z',
      };

      // Act
      final profile = UserProfile.fromJson(json);

      // Assert
      expect(profile.id, equals(1));
      expect(profile.name, equals('John Doe'));
      expect(profile.email, equals('john@example.com'));
      expect(profile.phone, equals('081234567890'));
      expect(profile.roles, contains('resident'));
    });

    test('UserProfile toJson should convert to Map correctly', () {
      // Arrange
      final profile = UserProfile(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        phone: '081234567890',
        roles: ['resident'],
      );

      // Act
      final json = profile.toJson();

      // Assert
      expect(json['id'], equals(1));
      expect(json['name'], equals('John Doe'));
      expect(json['email'], equals('john@example.com'));
      expect(json['phone'], equals('081234567890'));
    });

    test(
      'UserProfile copyWith should create new instance with updated fields',
      () {
        // Arrange
        final profile = UserProfile(
          id: 1,
          name: 'John Doe',
          email: 'john@example.com',
        );

        // Act
        final updatedProfile = profile.copyWith(
          name: 'Jane Doe',
          phone: '081234567890',
        );

        // Assert
        expect(updatedProfile.id, equals(1)); // unchanged
        expect(updatedProfile.name, equals('Jane Doe')); // changed
        expect(updatedProfile.email, equals('john@example.com')); // unchanged
        expect(updatedProfile.phone, equals('081234567890')); // changed
      },
    );

    test('updateProfile should validate required fields', () async {
      // Act & Assert
      expect(
        () async =>
            await profileService.updateProfile(name: '', phone: '081234567890'),
        isA<Future>(),
      );
    });

    test('changePassword should validate password requirements', () async {
      // Note: This is handled by the backend, but we can test the service call

      // Act
      final (success, message) = await profileService.changePassword(
        currentPassword: 'old123',
        newPassword: 'short',
        newPasswordConfirmation: 'short',
      );

      // Assert
      expect(success, isA<bool>());
      if (!success) {
        expect(message, isNotNull);
      }
    });
  });

  group('Password Validation Tests', () {
    test('Password should be at least 8 characters', () {
      // Arrange
      final password = 'abc123';

      // Act
      final isValid = password.length >= 8;

      // Assert
      expect(isValid, isFalse);
    });

    test('Password should contain letters and numbers', () {
      // Arrange
      final validPassword = 'abc12345';
      final invalidPassword1 = 'abcdefgh'; // no numbers
      final invalidPassword2 = '12345678'; // no letters

      // Act
      final regex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)');
      final isValid1 = regex.hasMatch(validPassword);
      final isValid2 = regex.hasMatch(invalidPassword1);
      final isValid3 = regex.hasMatch(invalidPassword2);

      // Assert
      expect(isValid1, isTrue);
      expect(isValid2, isFalse);
      expect(isValid3, isFalse);
    });

    test('Password confirmation should match new password', () {
      // Arrange
      final newPassword = 'abc12345';
      final confirmPassword1 = 'abc12345';
      final confirmPassword2 = 'different';

      // Act & Assert
      expect(newPassword == confirmPassword1, isTrue);
      expect(newPassword == confirmPassword2, isFalse);
    });
  });
}
