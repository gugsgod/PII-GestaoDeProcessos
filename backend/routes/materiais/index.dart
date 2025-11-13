import 'package:backend/api_utils.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

const int _SAP_MIN = 15000000;
const int _SAP_MAX = 15999999;

bool _isValidSap(int v) => v >= _SAP_MIN && v <= _SAP_MAX;

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _list(context);
    case HttpMethod.post:
      final guard = await requireAdmin(context);
      if (guard != null) return guard;
      return _create(context);
    case HttpMethod.delete:
      return _delete(context);
    default:
      return Response(statusCode: 405);
  }
}

Future<Response> _list(RequestContext context) async {
  final conn = context.read<Connection>();
  final qp = context.request.uri.queryParameters;
  final pg = readPagination(context.request);

  final q = qp['q']?.trim(); // busca em descricao/apelido
  final categoria = qp['categoria']?.trim();
  final ativoStr = qp['ativo']?.trim();
  final codSap = int.tryParse(qp['cod_sap'] ?? '');
  final codPrefix = qp['cod_prefix']?.trim(); // opcional: prefixo (ex: "1500")

  final where = <String>[];
  final params = <String, Object?>{};

  // sempre garantir range SAP
  where.add('cod_sap BETWEEN $_SAP_MIN AND $_SAP_MAX');

  if (q != null && q.isNotEmpty) {
    where.add('(descricao ILIKE @q OR apelido ILIKE @q)');
    params['q'] = '%$q%';
  }
  if (categoria != null && categoria.isNotEmpty) {
    where.add('categoria ILIKE @categoria');
    params['categoria'] = '%$categoria%';
  }
  if (ativoStr != null) {
    final ativo =
        (ativoStr == 'true') ? true : (ativoStr == 'false' ? false : null);
    if (ativo != null) {
      where.add('ativo = @ativo');
      params['ativo'] = ativo;
    }
  }
  if (codSap != null) {
    where.add('cod_sap = @cod_sap');
    params['cod_sap'] = codSap;
  } else if (codPrefix != null && codPrefix.isNotEmpty) {
    // prefixo por LIKE (ex.: 1500%)
    where.add('cod_sap::text LIKE @cod_prefix');
    params['cod_prefix'] = '$codPrefix%';
  }

  final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

  try {
    final totalRows = await conn.execute(
      Sql.named('SELECT COUNT(*) FROM materiais $whereSql'),
      parameters: params,
    );
    final total = totalRows.first[0] as int;

    final rows = await conn.execute(
      Sql.named('''
        SELECT id, cod_sap, descricao, apelido, categoria, unidade, ativo
          FROM materiais
          $whereSql
         ORDER BY cod_sap
         LIMIT @limit OFFSET @offset
      '''),
      parameters: {...params, 'limit': pg.limit, 'offset': pg.offset},
    );

    final data = rows
        .map((r) => {
              'id': r[0],
              'cod_sap': r[1],
              'descricao': r[2],
              'apelido': r[3],
              'categoria': r[4],
              'unidade': r[5],
              'ativo': r[6],
            })
        .toList();

    return jsonOk(
        {'page': pg.page, 'limit': pg.limit, 'total': total, 'data': data});
  } catch (e, st) {
    print('GET /materiais error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

Future<Response> _create(RequestContext context) async {
  final conn = context.read<Connection>();
  try {
    final body = await readJson(context);

    final codSap = body['cod_sap'];
    final descricao = (body['descricao'] as String?)?.trim();
    final apelido = (body['apelido'] as String?)?.trim();
    final categoria = (body['categoria'] as String?)?.trim();
    final unidade = (body['unidade'] as String?)?.trim();

    if (codSap is! int) {
      return jsonBad({'error': 'cod_sap (int) é obrigatório'});
    }
    if (!_isValidSap(codSap)) {
      return jsonUnprocessable(
          {'error': 'cod_sap fora do range SAP 15000000–15999999'});
    }
    if (descricao == null || descricao.isEmpty) {
      return jsonBad({'error': 'descricao é obrigatória'});
    }

    final rows = await conn.execute(
      Sql.named('''
        INSERT INTO materiais (cod_sap, descricao, apelido, categoria, unidade, ativo)
        VALUES (@cod_sap, @descricao, @apelido, @categoria, @unidade, TRUE)
        RETURNING id, cod_sap, descricao, apelido, categoria, unidade, ativo
      '''),
      parameters: {
        'cod_sap': codSap,
        'descricao': descricao,
        'apelido': apelido,
        'categoria': categoria,
        'unidade': unidade,
      },
    );

    final r = rows.first;
    return jsonCreated({
      'id': r[0],
      'cod_sap': r[1],
      'descricao': r[2],
      'apelido': r[3],
      'categoria': r[4],
      'unidade': r[5],
      'ativo': r[6],
    });
  } on PgException catch (e, st) {
    // conflito de unique (cod_sap)
    if (e.message.contains('23505') == true) {
      return jsonUnprocessable({'error': 'cod_sap já existente'});
    }
    print('POST /materiais pg error: $e\n$st');
    return jsonServer({'error': 'internal'});
  } catch (e, st) {
    print('POST /materiais error: $e\n$st');
    return jsonServer({'error': 'internal'});
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

  final cod_sap = body['cod_sap'] as int?;

  if (cod_sap == null) {
    return Response(
      statusCode: 400, body: 'O campo sap_cod (str) é obrigatório no corpo');
  }

  try {
    final result = await connection.execute(
      Sql.named("DELETE FROM materiais WHERE cod_sap = @cod_sap"),
      parameters: {'cod_sap': cod_sap},
    );

    if (result.affectedRows == 0) {
      return Response(
          statusCode: 404,
          body: 'Material com sap_cod $cod_sap não encontrado.');
    }

    return Response(statusCode: 204);
  } on PgException catch (e) {
    print('Erro no banco de dados ao deletar: $e');
    return Response(
        statusCode: 500, body: 'Erro no banco de dados: ${e.message}');
  } catch (e, st) {
    print('Erro inesperado ao deletar: $e\n$st');
    return Response(
        statusCode: 500, body: 'Erro interno ao deletar instrumento.');
  }
}
