import 'package:dart_frog/dart_frog.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:postgres/postgres.dart';

Connection? _connection;
dotenv.DotEnv? _dotEnv;

Handler middleware(Handler handler) {
  return (context) async {
    // Carrega o .env (uma única vez)
    _dotEnv ??= dotenv.DotEnv(includePlatformEnvironment: true)
      ..load(['.env']); // opcionalmente ..load(); (por padrão lê .env)

    // Abre a conexão (uma única vez)
    if (_connection == null) {
      final host = _dotEnv!['DB_HOST'] ?? 'localhost';
      final port = int.tryParse(_dotEnv!['DB_PORT'] ?? '5432') ?? 5432;
      final db   = _dotEnv!['DB_NAME'] ?? '';
      final user = _dotEnv!['DB_USER'] ?? '';
      final pass = _dotEnv!['DB_PASSWORD'] ?? '';

      _connection = await Connection.open(
        Endpoint(
          host: host,
          port: port,
          database: db,
          username: user,
          password: pass,
        ),
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      );
    }

    // Injeta a conexão para uso nas rotas
    return handler.use(provider<Connection>((_) => _connection!)).call(context);
  };
}
