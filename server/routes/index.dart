import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

/// Root API endpoint - health check and basic information
Future<Response> onRequest(RequestContext context) async {
  return Response.json(
    body: {
      'name': 'Apogee Habit Tracker API',
      'version': '1.0.0',
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
      'environment': Platform.environment['ENVIRONMENT'] ?? 'development',
    },
  );
}