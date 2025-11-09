import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method;
  switch (method) {
    case HttpMethod.get:
      return _list(context);
    case HttpMethod.post:
      final guard = await requireAdmin(context);
      if (guard != null) return guard;
      return _create(context);
    default:
      return Response(statusCode: 405);
  }
}

Future<Response> _list(RequestContext context) async {
  final conn = context.read<Connection>();
  final qp = context.request.uri.queryParameters;
  final q = qp['q']?.trim();
  final pg = readPagination(context.request);

  try {
    final where = <String>[];
    final params = <String, Object?>{};
    if (q != null && q.isNotEmpty) {
      where.add('identificador ILIKE @q');
      params['q'] = '%$q%';
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final totalRows = await conn.execute(
      Sql.named('SELECT COUNT(*) FROM veiculos $whereSql'),
      parameters: params,
    );
    final total = totalRows.first[0] as int;

    final rows = await conn.execute(
      Sql.named('''
        SELECT id, identificador, ativo
          FROM veiculos
          $whereSql
         ORDER BY identificador
         LIMIT @limit OFFSET @offset
      '''),
      parameters: {...params, 'limit': pg.limit, 'offset': pg.offset},
    );

    final data = rows
        .map((r) => {'id': r[0], 'identificador': r[1], 'ativo': r[2]})
        .toList();

    return jsonOk({'page': pg.page, 'limit': pg.limit, 'total': total, 'data': data});
  } catch (e, st) {
    print('GET /veiculos error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

Future<Response> _create(RequestContext context) async {
  final conn = context.read<Connection>();
  try {
    final body = await readJson(context);
    final ident = (body['identificador'] as String?)?.trim();
    if (ident == null || ident.isEmpty) {
      return jsonBad({'error': 'identificador é obrigatório'});
    }

    final rows = await conn.execute(
      Sql.named('''
        INSERT INTO veiculos (identificador, ativo)
        VALUES (@ident, TRUE)
        RETURNING id, identificador, ativo
      '''),
      parameters: {'ident': ident},
    );

    final r = rows.first;
    return jsonCreated({'id': r[0], 'identificador': r[1], 'ativo': r[2]});
  } catch (e, st) {
    print('POST /veiculos error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}
