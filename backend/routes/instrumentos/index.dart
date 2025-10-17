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
  } on PostgreSQLException catch (e) {
    if (e.code == '23505') { // unique_violation
      return Response(
        statusCode: 409,
        body: 'Erro: Patrimônio "$patrimonio" já cadastrado.',
      );
    }
    return Response(
      statusCode: 500,
      body: 'Erro no banco de dados ao inserir instrumento.',
    );
  } catch (e, st) {
    print('Erro inesperado na inserção: $e\n$st');
    return Response(statusCode: 500, body: 'Erro interno ao inserir instrumento.');
  }
}

Future<Response> _patch(RequestContext context) async {
  final connection = context.read<Connection>();

}

Future<Response> _delete(RequestContext context) async {
  final connection = context.read<Connection>();

}
