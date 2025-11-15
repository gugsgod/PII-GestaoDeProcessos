// backend/routes/_middleware.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:postgres/postgres.dart';

Connection? _connection;
dotenv.DotEnv? _dotEnv;

Handler middleware(Handler handler) {
  return (context) async {
    // 1. Defina os headers de CORS PRIMEIRO.
    const allowOrigin = '*';
    const corsHeaders = <String, Object>{
      'Access-Control-Allow-Origin': allowOrigin,
      'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      'Access-Control-Allow-Headers':
          'Origin, Content-Type, Accept, Authorization, Cache-Control',
    };

    // 2. Lide com o preflight (OPTIONS) imediatamente.
    if (context.request.method == HttpMethod.options) {
      return Response(statusCode: 204, headers: corsHeaders);
    }

    // 3. ENVOLVA TUDO em um try/catch.
    try {
      // Carrega .env (uma vez)
      _dotEnv ??= dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);

      // Abre a conexão Postgres (uma vez)
      if (_connection == null) {
        final host = _dotEnv!['DB_HOST']!;
        final port = int.tryParse(_dotEnv!['DB_PORT'] ?? '5432') ?? 5432;
        final db = _dotEnv!['DB_NAME']!;
        final user = _dotEnv!['DB_USER']!;
        final pass = _dotEnv!['DB_PASSWORD']!;

        _connection = await Connection.open(
          Endpoint(
              host: host,
              port: port,
              database: db,
              username: user,
              password: pass,),
          settings: const ConnectionSettings(sslMode: SslMode.require),
        );
      }

      // Provider com segredo do JWT
      final config = <String, String>{
        'JWT_SECRET': _dotEnv!['JWT_SECRET'] ??
            Platform.environment['JWT_SECRET'] ??
            'dev-secret-change-me',
      };

      // 4. Tente rodar o handler com os providers
      final res = await handler
          .use(provider<Connection>((_) => _connection!))
          .use(provider<Map<String, String>>((_) => config))
          .call(context);
      
      // 5. Anexa os headers de CORS à resposta de SUCESSO
      return res.copyWith(headers: {
        ...res.headers,
        ...corsHeaders,
      });

    } catch (e, st) {
      // 6. Se QUALQUER coisa falhar (Conexão com DB, race condition)
      //    Crie uma resposta de erro 500 COM OS HEADERS DE CORS.
      print('Erro fatal no middleware: $e\n$st');
      return Response.json(
        statusCode: 500,
        body: {'error': 'Erro fatal no middleware: ${e.toString()}'},
        headers: corsHeaders, // <-- O importante
      );
    }
  };
}
