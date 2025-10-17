import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  final conn = context.read<Connection>();
  final qp = context.request.uri.queryParameters;
  final pg = readPagination(context.request);

  final materialId = int.tryParse(qp['material_id'] ?? '');
  final codSap     = int.tryParse(qp['cod_sap'] ?? '');
  final baseId     = int.tryParse(qp['base_id'] ?? '');
  final veiculoId  = int.tryParse(qp['veiculo_id'] ?? '');
  final localId    = int.tryParse(qp['local_id'] ?? '');
  final localQ     = qp['local_q']?.trim();
  final lote       = qp['lote']?.trim();

  final where = <String>[];
  final params = <String, Object?>{};

  if (materialId != null) {
    where.add('es.material_id = @material_id');
    params['material_id'] = materialId;
  }
  if (codSap != null) {
    where.add('m.cod_sap = @cod_sap');
    params['cod_sap'] = codSap;
  }
  if (localId != null) {
    where.add('lf.id = @local_id');
    params['local_id'] = localId;
  }
  if (baseId != null) {
    where.add("lf.contexto = 'base' AND lf.base_id = @base_id");
    params['base_id'] = baseId;
  }
  if (veiculoId != null) {
    where.add("lf.contexto = 'veiculo' AND lf.veiculo_id = @veiculo_id");
    params['veiculo_id'] = veiculoId;
  }
  if (localQ != null && localQ.isNotEmpty) {
    where.add('lf.nome ILIKE @local_q');
    params['local_q'] = '%$localQ%';
  }
  if (lote != null && lote.isNotEmpty) {
    where.add('(es.lote = @lote)');
    params['lote'] = lote;
  }

  final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

  try {
    final countRows = await conn.execute(
      Sql.named('''
        SELECT COUNT(*)
          FROM estoque_saldos es
          JOIN materiais m     ON m.id = es.material_id
          JOIN locais_fisicos lf ON lf.id = es.local_id
          $whereSql
      '''),
      parameters: params,
    );
    final total = countRows.first[0] as int;

    final rows = await conn.execute(
      Sql.named('''
        SELECT
          es.id           AS saldo_id,
          es.lote,
          es.qt_disp::float8 AS qt_disp,
          es.minimo::float8  AS minimo,
          m.id            AS material_id,
          m.cod_sap,
          m.descricao,
          m.unidade,
          lf.id           AS local_id,
          lf.contexto::text AS contexto,
          lf.base_id,
          lf.veiculo_id,
          lf.nome         AS local_nome
        FROM estoque_saldos es
        JOIN materiais m     ON m.id = es.material_id
        JOIN locais_fisicos lf ON lf.id = es.local_id
        $whereSql
        ORDER BY m.cod_sap, lf.contexto, lf.nome, es.lote NULLS FIRST
        LIMIT @limit OFFSET @offset
      '''),
      parameters: {...params, 'limit': pg.limit, 'offset': pg.offset},
    );

    final data = rows.map((r) => {
      'saldo_id' : r[0],
      'lote'     : r[1],
      'qt_disp'  : r[2],
      'minimo'   : r[3],
      'abaixo_minimo': (r[2] as double) < (r[3] as double),
      'material' : {
        'id': r[4],
        'cod_sap': r[5],
        'descricao': r[6],
        'unidade': r[7],
      },
      'local'    : {
        'id': r[8],
        'contexto': r[9],
        'base_id': r[10],
        'veiculo_id': r[11],
        'nome': r[12],
      },
    }).toList();

    return jsonOk({'page': pg.page, 'limit': pg.limit, 'total': total, 'data': data});
  } catch (e, st) {
    print('GET /estoque/saldos error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}
