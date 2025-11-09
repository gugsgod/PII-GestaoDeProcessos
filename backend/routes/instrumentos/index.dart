import 'dart:convert';
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

  try{
    final result = await connection.execute(
      'SELECT id, patrimonio, descricao, categoria, status, local_atual_id, responsavel_atual_id, proxima_calibracao_em, ativo, created_at, updated_at FROM instrumentos;'
    );

    // ------ Apagar depois -------
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
          proxima_calibracao_em
        ) VALUES (
          @patrimonio,
          @descricao,
          @categoria,
          @localId,
          @proximaCalibracao
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
  return Response(statusCode: 501, body: 'Not Implemented');
}

Future<Response> _delete(RequestContext context) async {
  return Response(statusCode: 501, body: 'Not Implemented');
}
