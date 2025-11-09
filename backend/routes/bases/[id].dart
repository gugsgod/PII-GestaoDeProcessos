import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context, String idStr) async {
  final method = context.request.method;
  switch (method) {
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
    Sql.named('SELECT id, nome, linha, ativo FROM bases WHERE id=@id'),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonNotFound('base não encontrada');

  final r = rows.first;
  return jsonOk({'id': r[0], 'nome': r[1], 'linha': r[2], 'ativo': r[3]});
}

Future<Response> _patch(RequestContext context, String idStr) async {
  final conn = context.read<Connection>();
  final id = int.tryParse(idStr);
  if (id == null) return jsonBad({'error': 'id inválido'});

  try {
    final body = await readJson(context);
    final nome = (body['nome'] as String?);
    final linha = (body['linha'] as String?);
    final ativo = (body['ativo'] as bool?);

    final rows = await conn.execute(
      Sql.named('''
        UPDATE bases
           SET nome = COALESCE(@nome, nome),
               linha = COALESCE(@linha, linha),
               ativo = COALESCE(@ativo, ativo)
         WHERE id = @id
     RETURNING id, nome, linha, ativo
      '''),
      parameters: {'id': id, 'nome': nome, 'linha': linha, 'ativo': ativo},
    );

    if (rows.isEmpty) return jsonNotFound('base não encontrada');
    final r = rows.first;
    return jsonOk({'id': r[0], 'nome': r[1], 'linha': r[2], 'ativo': r[3]});
  } catch (e, st) {
    print('PATCH /bases/$id error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

Future<Response> _delete(RequestContext context, String idStr) async {
  final conn = context.read<Connection>();
  final id = int.tryParse(idStr);
  if (id == null) return jsonBad({'error': 'id inválido'});

  final rows = await conn.execute(
    Sql.named('DELETE FROM bases WHERE id=@id RETURNING id'),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonNotFound('base não encontrada');

  return jsonOk({'ok': true});
}
