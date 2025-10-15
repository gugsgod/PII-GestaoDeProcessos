// backend/routes/_middleware.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:postgres/postgres.dart';

Connection? _connection;
dotenv.DotEnv? _dotEnv;

Handler middleware(Handler handler) {
  return (context) async {
    // Carrega .env (uma vez)
    _dotEnv ??= dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);

    // Abre a conexão Postgres (uma vez)
    if (_connection == null) {
      final host = _dotEnv!['DB_HOST'] ?? 'localhost';
      final port = int.tryParse(_dotEnv!['DB_PORT'] ?? '5432') ?? 5432;
      final db = _dotEnv!['DB_NAME'] ?? '';
      final user = _dotEnv!['DB_USER'] ?? '';
      final pass = _dotEnv!['DB_PASSWORD'] ?? '';

      _connection = await Connection.open(
        Endpoint(
            host: host,
            port: port,
            database: db,
            username: user,
            password: pass),
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      );
    }

    // Provider com segredo do JWT
    final config = <String, String>{
      'JWT_SECRET': _dotEnv!['JWT_SECRET'] ??
          Platform.environment['JWT_SECRET'] ??
          'dev-secret-change-me',
    };


    const allowOrigin = '*';

    const corsHeaders = <String, Object>{
      'Access-Control-Allow-Origin': allowOrigin,
      'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      'Access-Control-Allow-Headers':
          'Origin, Content-Type, Accept, Authorization',
      // Se precisar enviar cookies, troque:
      // 'Access-Control-Allow-Credentials': 'true',
      // e NÃO use '*' no Allow-Origin; use o domínio específico.
    };

    // Trata preflight (OPTIONS) ANTES de chamar o handler
    if (context.request.method == HttpMethod.options) {
      return Response(statusCode: 204, headers: corsHeaders);
    }

    // Encadeia providers e chama o handler
    final res = await handler
        .use(provider<Connection>((_) => _connection!))
        .use(provider<Map<String, String>>((_) => config))
        .call(context);

    // Anexa os headers de CORS à resposta normal
    return res.copyWith(headers: {
      ...res.headers,
      ...corsHeaders,
    });
  };
}
