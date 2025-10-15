import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:postgres/postgres.dart';

Response _json(int status, Object body) =>
    Response.json(statusCode: status, body: body);

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return _json(405, {'error': 'Method not allowed'});
  }

  // Lê connection injetada no middleware
  final conn = context.read<Connection>();

  // Lê corpo JSON
  late final Map<String, dynamic> payload;
  try {
    final raw = await context.request.body();
    payload = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return _json(400, {'error': 'JSON inválido'});
  }

  final email = (payload['email'] as String?)?.trim();
  final senha = payload['senha'] as String?;

  if (email == null || email.isEmpty || senha == null || senha.isEmpty) {
    return _json(400, {'error': 'Informe email e senha.'});
  }

  try {
    // busca usuario
    final rows = await conn.execute(
      Sql.named('''
        SELECT id_usuario, nome, email, funcao, senha
        FROM usuario
        WHERE email = @email
        LIMIT 1
      '''),
      parameters: {'email': email},
    );

    if (rows.isEmpty) {
      // não revelar se e-mail existe: devolve erro genérico
      return _json(401, {'error': 'Credenciais inválidas.'});
    }

    final row = rows.first.toColumnMap();
    // final ativo = (row['ativo'] as bool?) ?? false;
    // if (!ativo) {
    //   return _json(403, {'error': 'Usuário inativo.'});
    // }

    final hash = row['senha'] as String;
    final senhaOk = BCrypt.checkpw(senha, hash);
    if (!senhaOk) {
      return _json(401, {'error': 'Credenciais inválidas.'});
    }

    // jwt
    final cfg = context.read<Map<String, String>>();
    final jwtSecret = cfg['JWT_SECRET'] ?? '';

    final jwt = JWT({
      'sub': row['id_usuario'],
      'name': row['nome'],
      'email': row['email'],
      'role': row['funcao'],
    });

    final token = jwt.sign(
      SecretKey(jwtSecret),
      expiresIn: const Duration(hours: 12),
    );

    return _json(200, {
      'ok': true,
      'user': {
        'id': row['id_usuario'],
        'nome': row['nome'],
        'email': row['email'],
        'funcao': row['funcao'],
      },
      'token': token,
    });
  } catch (e, st) {
    print('Erro no login: $e\n$st');
    return _json(500, {'error': 'Erro interno. $e'});
  }
}
