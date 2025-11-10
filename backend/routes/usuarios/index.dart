import 'dart:convert';
import 'dart:math';

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
    // --- Lógica de Filtro e Paginação ---
    final query = context.request.uri.queryParameters;
    
    // Busca e Filtro
    final searchQuery = query['q'];
    final category = query['categoria'];

    // Paginação
    final limit = int.tryParse(query['limit'] ?? '20') ?? 20;
    // O front-end estava enviando "page": "q", então vamos tratar 'q' como 1
    final page = int.tryParse(query['page'] ?? '1') ?? 1;
    final offset = max(0, page - 1) * limit;

    var sql = 'SELECT id_usuario, nome, email, funcao FROM usuarios';
    final whereClauses = <String>[];
    final parameters = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add('(nome ILIKE @q OR email ILIKE @q)');
      parameters['q'] = '%$searchQuery%';
    }
    
    // O front-end envia 'Todas as Categorias', que não devemos filtrar
    if (category != null && category.isNotEmpty && category != 'Todas as Categorias') {
      whereClauses.add('funcao = @categoria');
      parameters['categoria'] = category;
    }

    if (whereClauses.isNotEmpty) {
      sql += ' WHERE ${whereClauses.join(' AND ')}';
    }

    sql += ' ORDER BY nome LIMIT @limit OFFSET @offset';
    // --- Fim da Lógica ---

    final result = await connection.execute(Sql.named(sql), parameters: parameters);

    final usersList = result.map((row) {
      // Mapeia direto para o front-end não ter que adivinhar os nomes
      return row.toColumnMap(); 
    }).toList();

    // FIX 1: Retornar como {'data': [...]}
    return Response.json(body: {'data': usersList});

  } catch (e, st) {
    // ignore: avoid_print
    print('Erro na consulta: $e\n$st');
    // FIX 4: Retornar erro como JSON
    return Response.json(
      statusCode: 500,
      body: {'error': 'Erro ao buscar usuários: ${e.toString()}'},
    );
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

  if (funcao != 'admin' && funcao != 'tecnico') {
     return Response.json(
      statusCode: 400,
      body: {'error': 'Função inválida recebida: $funcao'},
    );
  }

  final hash = hashPassword(senha);

  try {
    final result = await connection.execute(
      Sql.named('''
        INSERT INTO usuarios (nome, email, funcao, senha)
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
  } on PgException catch (e) {
    if (e.message.contains('23505') == true) { // Unique violation (email)
      return Response.json(statusCode: 409, body: {'error': 'E-mail já cadastrado.'});
    }
    if (e.message.contains('23514') == true) { // Check constraint
      // ignore: avoid_print
      print('ERRO DE CHECK CONSTRAINT: $e. Valor enviado: $funcao');
      return Response.json(statusCode: 400, body: {'error': 'Valor de função inválido para o banco de dados.'});
    }
    // ignore: avoid_print
    print('Erro de PG: $e');
    rethrow;
  }
}
