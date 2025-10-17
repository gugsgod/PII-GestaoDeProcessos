import 'dart:convert';

import 'package:backend/security/bcrypt.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _get(context);
    case HttpMethod.post:
      return _post(context);
    default:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

Future<Response> _get(RequestContext context) async {
  final connection = context.read<Connection>();

  try {
    // Postgres 3.x: execute() retorna um Result que é Iterable<Row>
    final result = await connection.execute(
      'SELECT id_usuario, nome, funcao FROM usuario',
      'SELECT id_usuario, nome, email, funcao FROM usuario ORDER BY nome',
    );

    final usersList = result.map((row) {
      // Acessa por índice (ou row.toColumnMap() se preferir por nome)
      final map = row.toColumnMap();
      return {
        'id': row[0],
        'nome': row[1],
        'funcao': row[2],
        'id': map['id_usuario'],
        'nome': map['nome'],
        'email': map['email'],
        'funcao': map['funcao'],
      };
    }).toList();

    return Response.json(body: usersList);
  } catch (e, st) {
    // ignore: avoid_print
    print('Erro na consulta: $e\n$st');
    return Response(statusCode: 500, body: 'Erro ao buscar usuários.');
  }
}

Future<Response> _post(RequestContext context) async {
  final connection = context.read<Connection>();
  final data =
      jsonDecode(await context.request.body()) as Map<String, dynamic>;

  final nome = (data['nome'] as String?)?.trim();
  final email = (data['email'] as String?)?.trim().toLowerCase();
  final senha = data['senha'] as String?;
  final funcao = (data['funcao'] as String?)?.trim();

  if (nome == null || nome.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'Informe o nome.'});
  }
  if (email == null || email.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'Informe o e-mail.'});
  }
  if (senha == null || senha.length < 8) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Senha muito curta (mínimo 8 caracteres).'},
    );
  }

  final hash = hashPassword(senha);

  try {
    final result = await connection.execute(
      Sql.named('''
        INSERT INTO usuario (nome, email, funcao, senha)
        VALUES (@nome, @email, @funcao, @hash)
        RETURNING id_usuario, nome, email, funcao
      '''),
      parameters: {
        'nome': nome,
        'email': email,
        'funcao': funcao,
        'hash': hash,
      },
    );

    final user = result.first.toColumnMap();
    return Response.json(statusCode: 201, body: user);
  } on PostgreSQLException catch (e) {
    if (e.code == '23505') {
      return Response.json(statusCode: 409, body: {'error': 'E-mail já cadastrado.'});
    }
    rethrow;
  }
}
