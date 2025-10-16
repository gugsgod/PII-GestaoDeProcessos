import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method;
  switch (method) {
    case HttpMethod.get:
      return _list(context);
    case HttpMethod.post:
      // admin only
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
  final ({int page, int limit, int offset}) pg =
      readPagination(context.request);

  try {
    final where = <String>[];
    final params = <String, Object?>{};
    if (q != null && q.isNotEmpty) {
      where.add('nome ILIKE @q');
      params['q'] = '%$q%';
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final totalRows = await conn.execute(
      Sql.named('SELECT COUNT(*) AS c FROM bases $whereSql'),
      parameters: params,
    );
    final total = (totalRows.first[0] as int);

    final rows = await conn.execute(
      Sql.named('''
        SELECT id, nome, linha, ativo
        FROM bases
        $whereSql
        ORDER BY nome ASC
        LIMIT @limit OFFSET @offset
      '''),
      parameters: {
        ...params,
        'limit': pg.limit,
        'offset': pg.offset,
      },
    );

    final data = rows
        .map((r) => {
              'id': r[0],
              'nome': r[1],
              'linha': r[2],
              'ativo': r[3],
            })
        .toList();

    return jsonOk({
      'page': pg.page,
      'limit': pg.limit,
      'total': total,
      'data': data,
    });
  } catch (e, st) {
    print('GET /bases error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

Future<Response> _create(RequestContext context) async {
  final conn = context.read<Connection>();
  try {
    final body = await readJson(context);
    final nome = (body['nome'] as String?)?.trim();
    final linha = (body['linha'] as String?)?.trim();

    if (nome == null || nome.isEmpty) {
      return jsonBad({'error': 'nome é obrigatório'});
    }

    final rows = await conn.execute(
      Sql.named('''
        INSERT INTO bases (nome, linha, ativo)
        VALUES (@nome, @linha, TRUE)
        RETURNING id, nome, linha, ativo
      '''),
      parameters: {'nome': nome, 'linha': linha},
    );
    final r = rows.first;
    return jsonCreated({
      'id': r[0],
      'nome': r[1],
      'linha': r[2],
      'ativo': r[3],
    });
  } catch (e, st) {
    print('POST /bases error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}
