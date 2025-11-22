import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  
  final connection = context.read<Connection>();
  final qp = context.request.uri.queryParameters;
  
  // Filtros
  final bool filtroAtivo = qp['ativo'] == 'true';
  final bool filtroVencidos = qp['vencidos'] == 'true'; // NOVO FILTRO

  final whereClauses = <String>[];
  
  if (filtroAtivo) {
    whereClauses.add('i.ativo = true');
  }
  
  // LÓGICA DE NEGÓCIO: Se pedir vencidos, filtra pela data menor que agora
  if (filtroVencidos) {
    whereClauses.add('i.proxima_calibracao_em < NOW()');
  }

  String whereSql = '';
  if (whereClauses.isNotEmpty) {
    whereSql = 'WHERE ${whereClauses.join(' AND ')}';
  }
  
  try {
    final rows = await connection.execute(
      '''
        SELECT 
          i.id, i.patrimonio, i.descricao, i.categoria, 
          i.status::text AS status, 
          i.local_atual_id, 
          i.responsavel_atual_id, i.proxima_calibracao_em, 
          i.ativo, i.created_at, i.updated_at,
          lf.nome AS local_atual_nome
        FROM instrumentos i
        LEFT JOIN locais_fisicos lf ON i.local_atual_id = lf.id
        $whereSql
        ORDER BY i.proxima_calibracao_em ASC
      '''
    );

    final data = rows.map((r) => {
      'id': r[0],
      'patrimonio': r[1],
      'descricao': r[2],
      'categoria': r[3],
      'status': r[4],
      'local_atual_id': r[5],
      'responsavel_atual_id': r[6],
      'proxima_calibracao_em': (r[7] as DateTime?)?.toIso8601String(),
      'ativo': r[8],
      'created_at': (r[9] as DateTime?)?.toIso8601String(),
      'updated_at': (r[10] as DateTime?)?.toIso8601String(),
      'local_atual_nome': r[11],
    }).toList();

    return jsonOk(data);
  } catch (e, st) {
    print('GET /instrumentos/catalogo error: $e\n$st');
    return Response.json(statusCode: 500, body: {'error': 'internal'});
  }
}