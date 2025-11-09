import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    // só GET
    return Response(statusCode: 405);
  }

  final guard = await requireAdmin(context);
  if (guard != null) return guard;

  final conn = context.read<Connection>();
  final qp = context.request.uri.queryParameters;
  final pg = readPagination(context.request);

  final materialId = int.tryParse(qp['material_id'] ?? '');
  final localId = int.tryParse(qp['local_id'] ?? '');
  final operacao = qp['operacao']?.trim();
  final lote = qp['lote']?.trim();

  final where = <String>[];
  final params = <String, Object?>{};

  if (materialId != null) {
    where.add('mv.material_id = @mid');
    params['mid'] = materialId;
  }
  if (localId != null) {
    where.add('(mv.origem_local_id = @lid OR mv.destino_local_id = @lid)');
    params['lid'] = localId;
  }
  if (operacao != null && operacao.isNotEmpty) {
    where.add('mv.operacao = @op');
    params['op'] = operacao;
  }
  if (lote != null && lote.isNotEmpty) {
    where.add('mv.lote = @lote');
    params['lote'] = lote;
  }

  final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

  try {
    // TOTAL
    final totalRes = await conn.execute(
      Sql.named('SELECT COUNT(*) FROM movimentacao_material mv $whereSql'),
      parameters: params,
    );
    final total = totalRes.first[0] as int;

    // LINHAS
    final rows = await conn.execute(
      Sql.named('''
    SELECT
      mv.id,
      mv.operacao::text,                  
      mv.material_id,
      mv.origem_local_id,
      mv.destino_local_id,
      mv.lote::text,                      
      mv.quantidade::float8 AS quantidade,
      mv.responsavel_id,
      mv.observacao::text,                 
      mv.created_at,
      m.cod_sap,
      m.descricao::text,                   
      m.unidade::text                      
    FROM movimentacao_material mv
    JOIN materiais m ON m.id = mv.material_id
    $whereSql
    ORDER BY mv.created_at DESC
    LIMIT @limit OFFSET @offset
  '''),
      parameters: {...params, 'limit': pg.limit, 'offset': pg.offset},
    );

// mapeamento com toString() defensivo
    final data = rows.map((r) {
      return {
        'id': r[0],
        'operacao': r[1]?.toString(),
        'material_id': r[2],
        'origem_local_id': r[3],
        'destino_local_id': r[4],
        'lote': r[5],
        'quantidade': r[6],
        'responsavel_id': r[7],
        'observacao': r[8],
        'created_at': r[9]?.toString(),
        'material': {
          'cod_sap': r[10],
          'descricao': r[11],
          'unidade': r[12],
        }
      };
    }).toList();

    return jsonOk({
      'page': pg.page,
      'limit': pg.limit,
      'total': total,
      'data': data,
    });
  } on PgException catch (e, st) {
    print('GET /movimentacoes pg error: $e\n$st');
    return jsonServer({'error': 'internal', 'detail': e.message});
  } catch (e, st) {
    print('GET /movimentacoes error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}
