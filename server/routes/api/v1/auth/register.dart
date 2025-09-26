import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import '../../../../lib/services/auth_service.dart';

/// Handles user registration
/// POST /api/v1/auth/register
Future<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.post => await _handleRegister(context),
    HttpMethod.options => _handleOptions(),
    _ => Response(statusCode: HttpStatus.methodNotAllowed),
  };
}

/// Handle new user registration
Future<Response> _handleRegister(RequestContext context) async {
  try {
    final body = await context.request.body();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final email = data['email'] as String?;
    final password = data['password'] as String?;
    final displayName = data['displayName'] as String?;
    final deviceId = data['deviceId'] as String?;

    // Validate required fields
    if (email == null || password == null || displayName == null || deviceId == null) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'Missing required fields',
          'message': 'email, password, displayName, and deviceId are required',
        },
      );
    }

    // Validate input format
    if (email.isEmpty || !email.contains('@')) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'Invalid email',
          'message': 'Please provide a valid email address',
        },
      );
    }

    if (password.length < 8) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'Weak password',
          'message': 'Password must be at least 8 characters long',
        },
      );
    }

    if (displayName.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'Invalid display name',
          'message': 'Display name cannot be empty',
        },
      );
    }

    // Attempt registration
    final result = await AuthService.register(
      email: email.trim().toLowerCase(),
      password: password,
      displayName: displayName.trim(),
      deviceId: deviceId,
    );

    return Response.json(
      statusCode: 201,
      body: {
        'success': true,
        'data': result,
        'message': 'Registration successful',
      },
    );
  } catch (e) {
    final statusCode = e.toString().contains('already exists') ? 409 : 400;

    return Response.json(
      statusCode: statusCode,
      body: {
        'error': 'Registration failed',
        'message': e.toString(),
      },
    );
  }
}

/// Handle CORS preflight requests
Response _handleOptions() {
  return Response(
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  );
}