import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

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
      return jsonServer(context);
  }
}

Future<Response> _get(RequestContext context) async {
  // final guard = await requireAdmin(context);
  // if (guard != null) return guard;
  
  final connection = context.read<Connection>();

  final qp = context.request.uri.queryParameters;
  final bool? filtroAtivo = (qp['ativo'] == 'true');
  
  String whereClause = '';
  final params = <String, dynamic>{};

  // Se o filtro ?ativo=true for passado, adicione-o à query
  if (filtroAtivo == true) {
    whereClause = 'WHERE i.ativo = @ativo';
    params['ativo'] = true;
  }

  try{
    final result = await connection.execute(
      Sql.named('''
        SELECT 
          i.id, i.patrimonio, i.descricao, i.categoria, 
          i.status::text AS status, 
          i.local_atual_id, 
          i.responsavel_atual_id, i.proxima_calibracao_em, 
          i.ativo, i.created_at, i.updated_at,
          lf.nome AS local_atual_nome
        FROM instrumentos i
        LEFT JOIN locais_fisicos lf ON i.local_atual_id = lf.id
        $whereClause 
      '''),
      parameters: params, // Passa os parâmetros (pode estar vazio)
    );

    dynamic _convertValue(dynamic value) {
      if (value is UndecodedBytes) {
        try {
          return value.asString;
        } catch (e) {
          return value.toString();
        }
      }
      if (value is DateTime) {
        return value.toIso8601String();
      }

      return value;
    }

    final instrumentosList = result.map((row) {
      final map = row.toColumnMap();

      final convertMap = map.map(
        (key, value) => MapEntry(key, _convertValue(value)),
      );

      return convertMap;
      // return {
      //   'id': map['id'],
      //   'patrimonio': map['patrimonio'],
      //   'descricao': map['descricao'],
      //   'categoria': map['categoria'],
      //   'status': map['status'],
      //   'local_atual_id': map['local_atual_id'],
      //   'responsavel_atual_id': map['responsavel_atual_id'],
      //   'proxima_calibracao_em': map['proxima_calibracao_em'],
      //   'ativo': map['ativo'],
      //   'created_at': map['created_at'],
      //   'updated_at': map['updated_at'],
      // };
    }).toList();

    return Response.json(body: instrumentosList);

  } catch(e, st){
    print('Erro na consulta: $e\n$st');
    return Response(statusCode: 500, body: 'Erro ao buscar instrumentos.');
  }
}

Future<Response> _post(RequestContext context) async {
  final connection = context.read<Connection>();
  final body = await context.request.json() as Map<String, dynamic>;

  final patrimonio = body['patrimonio'] as String?;
  final descricao = body['descricao'] as String?;

  if (patrimonio == null || descricao == null) {
    return Response(
      statusCode: 400,
      body: 'Os campos "patrimonio" e "descricao" são obrigatórios.',
    );
   }

  try {
    final result = await connection.execute(
      Sql.named('''
        INSERT INTO instrumentos (
          patrimonio,
          descricao,
          categoria,
          local_atual_id,
          proxima_calibracao_em,
          status,
          ativo
        ) VALUES (
          @patrimonio,
          @descricao,
          @categoria,
          @localId,
          @proximaCalibracao,
          'disponivel',
          true
        ) RETURNING id;
      '''),
      parameters: {
        'patrimonio': patrimonio,
        'descricao': descricao,
        'categoria': body['categoria'] as String?,
        'localId': body['local_atual_id'] as int?,
        'proximaCalibracao': body['proxima_calibracao_em'] as String?,
      },
    );

    final newId = result.first.toColumnMap()['id'];

    return Response.json(
      statusCode: 201,
      body: {'id': newId, 'message': 'Instrumento criado com sucesso!'},
    );
  } on PgException catch (e) {
    if (e.message.contains('23505') == true) { // unique_violation
      return Response(
        statusCode: 409,
        body: 'Erro: Patrimônio "$patrimonio" já cadastrado.',
      );
    }
    return Response(
      statusCode: 500,
      body: 'Erro no banco de dados ao inserir instrumento.$e',
    );
  } catch (e, st) {
    print('Erro inesperado na inserção: $e\n$st');
    return Response(statusCode: 500, body: 'Erro interno ao inserir instrumento.');
  }
}

Future<Response> _patch(RequestContext context) async {
  final connection = context.read<Connection>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    
    // O ID é obrigatório para saber quem atualizar
    final id = body['id'] as int?;
    if (id == null) {
      return Response.json(statusCode: 400, body: {'error': 'O campo "id" é obrigatório.'});
    }

    // Lista de campos possíveis para atualização
    final updateClauses = <String>[];
    final parameters = <String, dynamic>{'id': id};

    // 1. Patrimônio
    if (body.containsKey('patrimonio')) {
      final p = body['patrimonio'] as String?;
      if (p != null && p.isNotEmpty) {
        updateClauses.add('patrimonio = @patrimonio');
        parameters['patrimonio'] = p;
      }
    }

    // 2. Descrição
    if (body.containsKey('descricao')) {
      final d = body['descricao'] as String?;
      if (d != null && d.isNotEmpty) {
        updateClauses.add('descricao = @descricao');
        parameters['descricao'] = d;
      }
    }

    // 3. Categoria
    if (body.containsKey('categoria')) {
      updateClauses.add('categoria = @categoria');
      parameters['categoria'] = body['categoria']; // Pode ser null
    }

    // 4. Local Atual (Mudança de base via admin)
    if (body.containsKey('local_atual_id')) {
      final lid = body['local_atual_id'] as int?;
      if (lid != null) {
         updateClauses.add('local_atual_id = @lid');
         parameters['lid'] = lid;
      }
    }

    // 5. Data de Calibração
    if (body.containsKey('proxima_calibracao_em')) {
      final dataStr = body['proxima_calibracao_em'] as String?;
      if (dataStr != null) {
        final data = DateTime.tryParse(dataStr);
        if (data != null) {
          updateClauses.add('proxima_calibracao_em = @calib');
          parameters['calib'] = data.toUtc();
        }
      }
    }

    // 6. Status ATIVO/INATIVO (O que você precisa)
    if (body.containsKey('ativo')) {
      final ativo = body['ativo'];
      if (ativo is bool) {
        updateClauses.add('ativo = @ativo');
        parameters['ativo'] = ativo;
        
        // REGRA DE NEGÓCIO: Se desativar, muda status para 'inativo' para consistência?
        // Opcional, mas recomendado:
        // if (!ativo) {
        //   updateClauses.add("status = 'inativo'"); 
        // }
      }
    }

    // Verifica se há algo para atualizar
    if (updateClauses.isEmpty) {
      return Response.json(statusCode: 200, body: {'message': 'Nada a atualizar.'});
    }

    // Sempre atualiza o timestamp
    updateClauses.add('updated_at = NOW()');

    // Executa a query dinâmica
    final query = 'UPDATE instrumentos SET ${updateClauses.join(', ')} WHERE id = @id';

    final result = await connection.execute(
      Sql.named(query),
      parameters: parameters,
    );

    if (result.affectedRows == 0) {
      return Response.json(statusCode: 404, body: {'error': 'Instrumento não encontrado.'});
    }

    return Response.json(statusCode: 200, body: {'message': 'Instrumento atualizado com sucesso.'});

  } on PgException catch (e) {
    // if (e.code == '23505') { // Unique violation (patrimonio duplicado)
    //    return Response.json(statusCode: 409, body: {'error': 'Já existe um instrumento com este patrimônio.'});
    // }
    print('Erro PG no PATCH instrumentos: $e');
    return Response.json(statusCode: 500, body: {'error': 'Erro de banco de dados.'});
  } catch (e, st) {
    print('Erro interno PATCH instrumentos: $e\n$st');
    return Response.json(statusCode: 500, body: {'error': 'Erro interno.'});
  }
}

Future<Response> _delete(RequestContext context) async {
  

  final guard = await requireAdmin(context);
  if (guard != null) return guard;

  final connection = context.read<Connection>();
  
  Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (e) {
    return Response(statusCode: 400, body: 'Corpo JSON inválido.');
  }

  final patrimonio = body['patrimonio'] as String?;

  if (patrimonio == null) {
    return Response(statusCode: 400, body: 'O campo "patrimonio" (str) é obrigatório no corpo.');
  }

  try {
    final result = await connection.execute(
      Sql.named('DELETE FROM instrumentos WHERE patrimonio = @patrimonio'),
      parameters: {'patrimonio': patrimonio},
    );

    if (result.affectedRows == 0) {
      return Response(statusCode: 404, body: 'Instrumento com patrimonio $patrimonio não encontrado.');
    }

    return Response(statusCode: 204);

  } on PgException catch (e) {
    
    print('Erro no banco de dados ao deletar: $e');
    return Response(statusCode: 500, body: 'Erro no banco de dados: ${e.message}');
  } catch (e, st) {

    print('Erro inesperado ao deletar: $e\n$st');
    return Response(statusCode: 500, body: 'Erro interno ao deletar instrumento.');
  }
}
