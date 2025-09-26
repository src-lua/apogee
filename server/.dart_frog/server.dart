// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../main.dart' as entrypoint;
import '../routes/index.dart' as index;
import '../routes/api/v1/users/[userId]/index.dart' as api_v1_users_$user_id_index;
import '../routes/api/v1/sync/[userId].dart' as api_v1_sync_$user_id;
import '../routes/api/v1/auth/register.dart' as api_v1_auth_register;
import '../routes/api/v1/auth/login.dart' as api_v1_auth_login;

import '../routes/_middleware.dart' as middleware;
import '../routes/api/_middleware.dart' as api_middleware;
import '../routes/api/v1/users/_middleware.dart' as api_v1_users_middleware;

void main() async {
  final address = InternetAddress.tryParse('') ?? InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  hotReload(() => createServer(address, port));
}

Future<HttpServer> createServer(InternetAddress address, int port) {
  final handler = Cascade().add(buildRootHandler()).handler;
  return entrypoint.run(handler, address, port);
}

Handler buildRootHandler() {
  final pipeline = const Pipeline().addMiddleware(middleware.middleware);
  final router = Router()
    ..mount('/api/v1/auth', (context) => buildApiV1AuthHandler()(context))
    ..mount('/api/v1/sync', (context) => buildApiV1SyncHandler()(context))
    ..mount('/api/v1/users/<userId>', (context,userId,) => buildApiV1Users$userIdHandler(userId,)(context))
    ..mount('/', (context) => buildHandler()(context));
  return pipeline.addHandler(router);
}

Handler buildApiV1AuthHandler() {
  final pipeline = const Pipeline().addMiddleware(api_middleware.middleware);
  final router = Router()
    ..all('/register', (context) => api_v1_auth_register.onRequest(context,))..all('/login', (context) => api_v1_auth_login.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1SyncHandler() {
  final pipeline = const Pipeline().addMiddleware(api_middleware.middleware);
  final router = Router()
    ..all('/<userId>', (context,userId,) => api_v1_sync_$user_id.onRequest(context,userId,));
  return pipeline.addHandler(router);
}

Handler buildApiV1Users$userIdHandler(String userId,) {
  final pipeline = const Pipeline().addMiddleware(api_middleware.middleware).addMiddleware(api_v1_users_middleware.middleware);
  final router = Router()
    ..all('/', (context) => api_v1_users_$user_id_index.onRequest(context,userId,));
  return pipeline.addHandler(router);
}

Handler buildHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => index.onRequest(context,));
  return pipeline.addHandler(router);
}

