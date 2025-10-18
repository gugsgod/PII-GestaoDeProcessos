import 'dart:convert';
import 'package:backend/security/bcrypt.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:postgres/postgres.dart';

Response _json(int status, Object body, {Map<String, Object>? headers}) {
  return Response.json(
    statusCode: status,
    body: body,
    headers: headers ?? const {}, // <- evita null
  );
}

bool _isValidEmail(String s) {
  final r = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  return r.hasMatch(s);
}

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return _json(405, {'error': 'Method not allowed'});
  }

  final conn = context.read<Connection>();

  // 1) Ler JSON
  Map<String, dynamic> data;
  try {
    data = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } catch (_) {
    return _json(400, {'error': 'JSON inválido.'});
  }

  // 2) Extrair e validar campos
  final rawNome = (data['nome'] as String?)?.trim() ?? '';
  final rawEmail = (data['email'] as String?)?.trim() ?? '';
  final senha = data['senha'] as String?;
  final funcao = (data['funcao'] as String?)?.trim();

  final email = rawEmail.toLowerCase();

  if (rawNome.isEmpty) return _json(400, {'error': 'Informe o nome.'});
  if (email.isEmpty || !_isValidEmail(email)) {
    return _json(400, {'error': 'E-mail inválido.'});
  }
  if (senha == null || senha.length < 8) {
    return _json(400, {'error': 'Senha muito curta (mínimo 8 caracteres).'});
  }

  // 3) Gerar hash da senha
  final hash = hashPassword(senha);

  try {
    // 4) Inserir usuário (parametrizado) e retornar dados essenciais
    final rows = await conn.execute(
      Sql.named('''
        INSERT INTO usuarios (nome, email, funcao, senha)
        VALUES (@nome, @email, @funcao, @hash)
        RETURNING id_usuario, nome, email, funcao
      '''),
      parameters: {
        'nome': rawNome,
        'email': email,
        'funcao': funcao,
        'hash': hash,
      },
    );

    final row = rows.first.toColumnMap();
    final user = {
      'id': row['id_usuario'],
      'nome': row['nome'],
      'email': row['email'],
      'funcao': row['funcao'],
    };

    String? token;
    try {
      final cfg = context.read<Map<String, String>>();
      final secret = cfg['JWT_SECRET'];
      if (secret != null && secret.isNotEmpty) {
        final jwt = JWT({
          'sub': user['id'],
          'name': user['nome'],
          'email': user['email'],
          'role': user['funcao'],
        });
        token =
            jwt.sign(SecretKey(secret), expiresIn: const Duration(hours: 12));
      }
    } catch (_) {
      // Se não houver provider, apenas não gera token (sem erro)
    }

    // 6) Retornar 201 + Location
    final headers = <String, Object>{
      'Location': '/usuarios/${user['id']}',
    };

    return _json(
        201,
        {
          'ok': true,
          'user': user,
          if (token != null) 'token': token,
        },
        headers: headers,);
  } catch (e) {
    // Tratamento de e-mail duplicado
    final msg = e.toString();
    if (msg.contains('23505') || msg.toLowerCase().contains('unique')) {
      return _json(409, {'error': 'E-mail já cadastrado.'});
    }
    // Log no servidor
    // ignore: avoid_print
    print('Erro no register: $e');
    return _json(500, {'error': 'Erro interno.'});
  }
}
