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
    Sql.named(
        'SSELECT id, contexto::text AS contexto, base_id, veiculo_id, nome FROM locais_fisicos WHERE id=@id'),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonNotFound('local não encontrado');

  final r = rows.first;
  return jsonOk({
    'id': r[0],
    'contexto': r[1],
    'base_id': r[2],
    'veiculo_id': r[3],
    'nome': r[4]
  });
}

Future<Response> _patch(RequestContext context, String idStr) async {
  final conn = context.read<Connection>();
  final id = int.tryParse(idStr);
  if (id == null) return jsonBad({'error': 'id inválido'});

  try {
    final body = await readJson(context);
    final nome = (body['nome'] as String?);
    // **Não** permitimos trocar 'contexto' depois de criado (evita bagunça)
    final rows = await conn.execute(
      Sql.named('''
        UPDATE locais_fisicos
           SET nome = COALESCE(@nome, nome)
         WHERE id = @id
     RETURNING id, contexto::text AS contexto, base_id, veiculo_id, nome
      '''),
      parameters: {'id': id, 'nome': nome},
    );
    if (rows.isEmpty) return jsonNotFound('local não encontrado');
    final r = rows.first;
    return jsonOk({
      'id': r[0],
      'contexto': r[1],
      'base_id': r[2],
      'veiculo_id': r[3],
      'nome': r[4]
    });
  } catch (e, st) {
    print('PATCH /locais/$id error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

Future<Response> _delete(RequestContext context, String idStr) async {
  final conn = context.read<Connection>();
  final id = int.tryParse(idStr);
  if (id == null) return jsonBad({'error': 'id inválido'});

  final rows = await conn.execute(
    Sql.named('DELETE FROM locais_fisicos WHERE id=@id RETURNING id'),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonNotFound('local não encontrado');

  return jsonOk({'ok': true});
}
