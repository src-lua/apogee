import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:uuid/uuid.dart';
import 'package:apogee_shared/user.dart';
import 'database_service.dart';

/// Authentication service handling user registration, login, and JWT tokens
/// Provides secure authentication methods with proper password hashing
class AuthService {
  static final _uuid = Uuid();

  /// JWT secret key from environment or default for development
  static String get _jwtSecret =>
      Platform.environment['JWT_SECRET'] ?? 'dev-secret-change-in-production';

  /// Token expiration time (7 days)
  static const Duration _tokenExpiration = Duration(days: 7);

  /// Registers a new user with email and password
  /// Returns the created user and authentication token
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
    required String deviceId,
  }) async {
    // Validate input
    if (email.isEmpty || password.isEmpty || displayName.isEmpty) {
      throw ArgumentError('Email, password, and display name are required');
    }

    if (!_isValidEmail(email)) {
      throw ArgumentError('Invalid email format');
    }

    if (password.length < 8) {
      throw ArgumentError('Password must be at least 8 characters long');
    }

    // Check if user already exists
    final existingUser = await DatabaseService.findUserByEmail(email);
    if (existingUser != null) {
      throw StateError('User with this email already exists');
    }

    // Hash password
    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

    // Create user
    final user = User.create(
      email: email,
      displayName: displayName,
      deviceId: deviceId,
    );

    // Save to database
    await DatabaseService.createUser(user, hashedPassword);

    // Generate token
    final token = _generateToken(userId: user.id, deviceId: deviceId);

    return {
      'user': user.toJson(),
      'token': token,
    };
  }

  /// Authenticates user with email and password
  /// Returns user data and authentication token
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    // Validate input
    if (email.isEmpty || password.isEmpty) {
      throw ArgumentError('Email and password are required');
    }

    // Find user by email
    final userWithPassword = await DatabaseService.findUserByEmailWithPassword(email);
    if (userWithPassword == null) {
      throw StateError('Invalid email or password');
    }

    final user = userWithPassword['user'] as User;
    final storedPassword = userWithPassword['password'] as String;

    // Verify password
    if (!BCrypt.checkpw(password, storedPassword)) {
      throw StateError('Invalid email or password');
    }

    // Update last login and device
    final updatedUser = user.copyWith(
      lastLoginAt: DateTime.now(),
      deviceId: deviceId,
    );
    await DatabaseService.updateUser(updatedUser);

    // Generate token
    final token = _generateToken(userId: user.id, deviceId: deviceId);

    return {
      'user': updatedUser.toJson(),
      'token': token,
    };
  }

  /// Validates a JWT token and returns the payload
  /// Throws if token is invalid or expired
  static Map<String, dynamic> validateToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      return jwt.payload as Map<String, dynamic>;
    } catch (e) {
      throw StateError('Invalid or expired token');
    }
  }

  /// Refreshes an authentication token
  /// Validates existing token and issues a new one
  static Future<String> refreshToken(String oldToken) async {
    final payload = validateToken(oldToken);
    final userId = payload['userId'] as String;
    final deviceId = payload['deviceId'] as String;

    // Verify user still exists
    final user = await DatabaseService.findUserById(userId);
    if (user == null) {
      throw StateError('User no longer exists');
    }

    return _generateToken(userId: userId, deviceId: deviceId);
  }

  /// Changes user password
  /// Requires current password for verification
  static Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw ArgumentError('New password must be at least 8 characters long');
    }

    // Get user with current password
    final user = await DatabaseService.findUserById(userId);
    if (user == null) {
      throw StateError('User not found');
    }

    final userWithPassword = await DatabaseService.findUserByEmailWithPassword(user.email);
    if (userWithPassword == null) {
      throw StateError('User authentication data not found');
    }

    final storedPassword = userWithPassword['password'] as String;

    // Verify current password
    if (!BCrypt.checkpw(currentPassword, storedPassword)) {
      throw StateError('Current password is incorrect');
    }

    // Hash new password and update
    final hashedNewPassword = BCrypt.hashpw(newPassword, BCrypt.gensalt());
    await DatabaseService.updateUserPassword(userId, hashedNewPassword);
  }

  /// Generates a JWT token for the given user and device
  static String _generateToken({
    required String userId,
    required String deviceId,
  }) {
    final now = DateTime.now();
    final expiry = now.add(_tokenExpiration);

    final jwt = JWT({
      'userId': userId,
      'deviceId': deviceId,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      'jti': _uuid.v4(), // Unique token ID
    });

    return jwt.sign(SecretKey(_jwtSecret));
  }

  /// Validates email format
  static bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return regex.hasMatch(email);
  }

  /// Generates a secure device ID
  static String generateDeviceId() {
    return _uuid.v4();
  }
}