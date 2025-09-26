import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'lib/services/database_service.dart';

/// Main entry point for the Apogee server
/// Initializes database connection and starts the HTTP server
Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  // Initialize environment configuration
  DatabaseService.initializeEnv();

  // Initialize environment variables
  _loadEnvironmentVariables();

  // Initialize database connection (optional for development)
  print('Initializing database connection...');
  try {
    await DatabaseService.initialize();
  } catch (e) {
    print('Warning: Database connection failed - running without database: $e');
    print('Start PostgreSQL or use Docker to enable database features');
  }

  // Register cleanup handler for graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('Received SIGINT, shutting down gracefully...');
    await DatabaseService.close();
    exit(0);
  });

  // Only register SIGTERM on non-Windows platforms
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) async {
      print('Received SIGTERM, shutting down gracefully...');
      await DatabaseService.close();
      exit(0);
    });
  }

  print('Starting Apogee server on $ip:$port');
  return serve(handler, ip, port);
}

/// Load environment variables with defaults for development
void _loadEnvironmentVariables() {
  final environment = Platform.environment;

  // Helper function to get environment variable with default
  String getEnvVar(String key, String defaultValue) {
    return environment[key] ?? defaultValue;
  }

  // Get configuration values with defaults
  final port = getEnvVar('PORT', '8080');
  final host = getEnvVar('HOST', '0.0.0.0');
  final env = getEnvVar('ENVIRONMENT', 'development');
  final dbHost = getEnvVar('DB_HOST', 'localhost');
  final dbName = getEnvVar('DB_NAME', 'apogee');
  final jwtSecret = getEnvVar('JWT_SECRET', 'dev-secret-change-in-production');

  // Log configuration (without sensitive data)
  print('Server configuration:');
  print('  Environment: $env');
  print('  Host: $host');
  print('  Port: $port');
  print('  DB Host: $dbHost');
  print('  DB Name: $dbName');
}