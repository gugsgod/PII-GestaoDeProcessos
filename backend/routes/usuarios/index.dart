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
    case HttpMethod.patch:
      return _patch(context);
    case HttpMethod.delete:
      return _delete(context);
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
    final filtroFuncaoRaw = query['funcao'];

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
    if (filtroFuncaoRaw != null && 
        filtroFuncaoRaw.isNotEmpty && 
        filtroFuncaoRaw != 'Todos os Perfis') {
      
      String valorDb;
      // Normaliza para minúsculo para facilitar a comparação
      final v = filtroFuncaoRaw.toLowerCase();
      
      if (v.contains('admin')) {
        valorDb = 'admin';
      } else if (v.contains('tecnico') || v.contains('técnico')) {
        valorDb = 'tecnico';
      } else {
        valorDb = filtroFuncaoRaw; // Fallback
      }

      whereClauses.add('funcao = @funcao');
      parameters['funcao'] = valorDb;
    }

    if (whereClauses.isNotEmpty) {
      sql += ' WHERE ${whereClauses.join(' AND ')}';
    }

    sql += ' ORDER BY nome LIMIT @limit OFFSET @offset';
    // --- Fim da Lógica ---

    final result =
        await connection.execute(Sql.named(sql), parameters: parameters);

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
  final data = jsonDecode(await context.request.body()) as Map<String, dynamic>;

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
    if (e.message.contains('23505') == true) {
      // Unique violation (email)
      return Response.json(
          statusCode: 409, body: {'error': 'E-mail já cadastrado.'});
    }
    if (e.message.contains('23514') == true) {
      // Check constraint
      // ignore: avoid_print
      print('ERRO DE CHECK CONSTRAINT: $e. Valor enviado: $funcao');
      return Response.json(
          statusCode: 400,
          body: {'error': 'Valor de função inválido para o banco de dados.'});
    }
    // ignore: avoid_print
    print('Erro de PG: $e');
    rethrow;
  }
}

Future<Response> _patch(RequestContext context) async {
  final connection = context.read<Connection>();

  try {
    // 1. LÊ O CORPO
    final body = await context.request.json() as Map<String, dynamic>;

    print('=== PATCH /usuarios DEBUG ===');
    print('Body recebido: $body');

    final id = body['id_usuario'];
    if (id == null) {
      print('>>> ERRO: id_usuario nulo');
      return Response.json(
        statusCode: 400,
        body: {'error': 'O campo "id_usuario" é obrigatório.'},
      );
    }

    final updateClauses = <String>[];
    final parameters = <String, dynamic>{'id': id};

    // --- (A) NOME ---
    if (body.containsKey('nome')) {
      final nome = body['nome'] as String?;
      if (nome != null && nome.trim().isNotEmpty) {
        updateClauses.add('nome = @nome');
        parameters['nome'] = nome.trim();
      }
    }

    // --- (B) EMAIL ---
    if (body.containsKey('email')) {
      final email = body['email'] as String?;
      if (email != null && email.trim().isNotEmpty) {
        updateClauses.add('email = @email');
        parameters['email'] = email.trim().toLowerCase();
      }
    }

    // --- (C) FUNÇÃO ---
    if (body.containsKey('funcao')) {
      final funcao = body['funcao'] as String?;
      print('>>> Processando funcao: "$funcao"'); 

      if (funcao == 'admin' || funcao == 'tecnico') {
        updateClauses.add('funcao = @funcao');
        parameters['funcao'] = funcao;
      } else {
        print('>>> ERRO: Funcao invalida ou nula');
        return Response.json(
            statusCode: 400,
            body: {'error': 'Função inválida. Use "admin" ou "tecnico".'});
      }
    }

    // --- (D) ATIVO ---
    if (body.containsKey('ativo')) {
      final ativo = body['ativo'];
      if (ativo is bool) {
        updateClauses.add('ativo = @ativo');
        parameters['ativo'] = ativo;
      }
    }
    
    // --- (E) SENHA ---
    if (body.containsKey('senha')) {
       final senha = body['senha'] as String?;
       if (senha != null && senha.isNotEmpty) {
           if (senha.length < 8) {
               return Response.json(statusCode: 400, body: {'error': 'Senha curta.'});
           }
           updateClauses.add('senha = @senha');
           parameters['senha'] = hashPassword(senha); 
       }
    }

    print('Clauses: $updateClauses');
    print('Params: $parameters');

    if (updateClauses.isEmpty) {
      print('>>> AVISO: Nada a atualizar');
      return Response.json(
        statusCode: 200,
        body: {'message': 'Nenhum campo válido enviado para atualização.'},
      );
    }

    final query =
        'UPDATE usuarios SET ${updateClauses.join(', ')} WHERE id_usuario = @id';

    final result = await connection.execute(
      Sql.named(query),
      parameters: parameters,
    );

    if (result.affectedRows == 0) {
      print('>>> ERRO: Usuário ID $id não encontrado no banco.');
      return Response.json(
        statusCode: 404,
        body: {'error': 'Usuário com id $id não encontrado.'},
      );
    }

    print('=== SUCESSO ===');
    return Response.json(body: {'message': 'Usuário atualizado com sucesso!'});

  } on PgException catch (e) {
    if (e.message.contains('23505') == true) {
       return Response.json(statusCode: 409, body: {'error': 'Email duplicado.'});
    }
    print('Erro PG no PATCH: $e');
    return Response.json(statusCode: 500, body: {'error': 'Erro de banco.'});
  } catch (e, st) {
    print('Erro interno PATCH: $e\n$st');
    return Response.json(statusCode: 500, body: {'error': 'Erro interno.'});
  }
}

Future<Response> _delete(RequestContext context) async {
  final connection = context.read<Connection>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final id = body['id_usuario'];

    if (id == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'O campo "id_usuario" é obrigatório no corpo JSON.'},
      );
    }

    final result = await connection.execute(
      Sql.named('UPDATE usuarios SET ativo = false WHERE id_usuario = @id'),
      parameters: {'id': id},
    );

    if (result.affectedRows == 0) {
      return Response.json(
        statusCode: 404,
        body: {'error': 'Usuário com id $id não encontrado.'},
      );
    }

    return Response.json(body: {'message': 'Usuário desativado com sucesso.'});
  } catch (e, st) {
    print('Erro ao deletar usuário: $e\n$st');
    return Response.json(
      body: {
        'error': 'Erro ao processar a exclusão. Verifique o JSON enviado.'
      },
    );
  }
}
