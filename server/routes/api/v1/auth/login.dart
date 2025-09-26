import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import '../../../../lib/services/auth_service.dart';

/// Handles user authentication
/// POST /api/v1/auth/login
Future<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.post => await _handleLogin(context),
    HttpMethod.options => _handleOptions(),
    _ => Response(statusCode: HttpStatus.methodNotAllowed),
  };
}

/// Handle user login with email and password
Future<Response> _handleLogin(RequestContext context) async {
  try {
    final body = await context.request.body();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final email = data['email'] as String?;
    final password = data['password'] as String?;
    final deviceId = data['deviceId'] as String?;

    // Validate required fields
    if (email == null || password == null || deviceId == null) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'Missing required fields',
          'message': 'email, password, and deviceId are required',
        },
      );
    }

    // Attempt login
    final result = await AuthService.login(
      email: email,
      password: password,
      deviceId: deviceId,
    );

    return Response.json(
      statusCode: 200,
      body: {
        'success': true,
        'data': result,
        'message': 'Login successful',
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: 401,
      body: {
        'error': 'Authentication failed',
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