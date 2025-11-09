import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context, String idStr) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  final conn = context.read<Connection>();
  final id = int.tryParse(idStr);
  if (id == null) return jsonBad({'error': 'id inválido'});

  try {
    // Primeiro conferimos se o material existe
    final m = await conn.execute(
      Sql.named('SELECT id, cod_sap, descricao FROM materiais WHERE id=@id'),
      parameters: {'id': id},
    );
    if (m.isEmpty) return jsonNotFound('material não encontrado');

    final material = {
      'id': m.first[0],
      'cod_sap': m.first[1],
      'descricao': m.first[2],
    };

    final rows = await conn.execute(
      Sql.named('''
        SELECT
          es.id,
          es.lote,
          es.qt_disp::float8 AS qt_disp,
          es.minimo::float8  AS minimo,
          lf.id        AS local_id,
          lf.contexto::text AS contexto,
          lf.base_id,
          lf.veiculo_id,
          lf.nome      AS local_nome
        FROM estoque_saldos es
        JOIN locais_fisicos lf ON lf.id = es.local_id
        WHERE es.material_id = @mid
        ORDER BY lf.contexto, lf.base_id NULLS FIRST, lf.veiculo_id NULLS FIRST, lf.nome, es.lote NULLS FIRST
      '''),
      parameters: {'mid': id},
    );

    final data = rows.map((r) => {
      'saldo_id' : r[0],
      'lote'     : r[1],
      'qt_disp'  : r[2],
      'minimo'   : r[3],
      'local'    : {
        'id'       : r[4],
        'contexto' : r[5],
        'base_id'  : r[6],
        'veiculo_id': r[7],
        'nome'     : r[8],
      },
      'abaixo_minimo': (r[2] as double) < (r[3] as double),
    }).toList();

    return jsonOk({'material': material, 'saldos': data});
  } catch (e, st) {
    print('GET /materiais/$idStr/saldos error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}
