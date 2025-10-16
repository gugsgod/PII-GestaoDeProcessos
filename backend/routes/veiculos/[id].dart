import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context, String idStr) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _get(context, idStr);
    case HttpMethod.patch:
      final guard = await requireAdmin(context);
      if (guard != null) return guard;
      return _patch(context, idStr);
    case HttpMethod.delete:
      final guard2 = await requireAdmin(context);
      if (guard2 != null) return guard2;
      return _delete(context, idStr);
    default:
      return Response(statusCode: 405);
  }
}

Future<Response> _get(RequestContext context, String idStr) async {
  final conn = context.read<Connection>();
  final id = int.tryParse(idStr);
  if (id == null) return jsonBad({'error': 'id inválido'});

  final rows = await conn.execute(
    Sql.named('SELECT id, identificador, ativo FROM veiculos WHERE id=@id'),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonNotFound('veículo não encontrado');

  final r = rows.first;
  return jsonOk({'id': r[0], 'identificador': r[1], 'ativo': r[2]});
}

Future<Response> _patch(RequestContext context, String idStr) async {
  final conn = context.read<Connection>();
  final id = int.tryParse(idStr);
  if (id == null) return jsonBad({'error': 'id inválido'});

  try {
    final body = await readJson(context);
    final identificador = (body['identificador'] as String?);
    final ativo = (body['ativo'] as bool?);

    final rows = await conn.execute(
      Sql.named('''
        UPDATE veiculos
           SET identificador = COALESCE(@identificador, identificador),
               ativo         = COALESCE(@ativo, ativo)
         WHERE id = @id
     RETURNING id, identificador, ativo
      '''),
      parameters: {'id': id, 'identificador': identificador, 'ativo': ativo},
    );

    if (rows.isEmpty) return jsonNotFound('veículo não encontrado');
    final r = rows.first;
    return jsonOk({'id': r[0], 'identificador': r[1], 'ativo': r[2]});
  } catch (e, st) {
    print('PATCH /veiculos/$id error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

Future<Response> _delete(RequestContext context, String idStr) async {
  final conn = context.read<Connection>();
  final id = int.tryParse(idStr);
  if (id == null) return jsonBad({'error': 'id inválido'});

  final rows = await conn.execute(
    Sql.named('DELETE FROM veiculos WHERE id=@id RETURNING id'),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonNotFound('veículo não encontrado');

  return jsonOk({'ok': true});
}
