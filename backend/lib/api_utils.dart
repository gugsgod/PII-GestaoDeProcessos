import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

Response jsonOk(Object body) => Response.json(body: body);
Response jsonCreated(Object body) => Response.json(statusCode: 201, body: body);
Response jsonBad(Object body) => Response.json(statusCode: 400, body: body);
Response jsonUnauthorized([String? msg]) =>
    Response.json(statusCode: 401, body: {'error': msg ?? 'unauthorized'});
Response jsonForbidden([String? msg]) =>
    Response.json(statusCode: 403, body: {'error': msg ?? 'forbidden'});
Response jsonNotFound([String? msg]) =>
    Response.json(statusCode: 404, body: {'error': msg ?? 'not found'});
Response jsonUnprocessable(Object body) =>
    Response.json(statusCode: 422, body: body);
Response jsonServer(Object body) => Response.json(statusCode: 500, body: body);

({int page, int limit, int offset}) readPagination(Request request,
    {int defaultLimit = 20, int maxLimit = 100}) {
  final qp = request.uri.queryParameters;
  final page = int.tryParse(qp['page'] ?? '1') ?? 1;
  final limitRaw = int.tryParse(qp['limit'] ?? '$defaultLimit') ?? defaultLimit;
  final limit = limitRaw.clamp(1, maxLimit);
  final offset = (page - 1) * limit;
  return (page: page, limit: limit, offset: offset);
}

Map<String, dynamic>? readJwtClaims(RequestContext context) {
  try {
    final auth = context.request.headers['authorization'];
    if (auth == null || !auth.toLowerCase().startsWith('bearer ')) return null;
    final token = auth.substring(7).trim();
    final cfg = context.read<Map<String, String>>();
    final secret = cfg['JWT_SECRET'] ?? '';
    final jwt = JWT.verify(token, SecretKey(secret));
    return jwt.payload as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Future<Response?> requireAdmin(RequestContext context) async {
  final claims = readJwtClaims(context);
  if (claims == null) return jsonUnauthorized('missing/invalid token');
  final role = claims['role'] as String?;
  if (role != 'admin') return jsonForbidden('admin only');
  return null;
}

Future<Map<String, dynamic>> readJson(RequestContext context) async {
  final raw = await context.request.body();
  final data = jsonDecode(raw);
  if (data is! Map<String, dynamic>) {
    throw const FormatException('expected object');
  }
  return data;
}
