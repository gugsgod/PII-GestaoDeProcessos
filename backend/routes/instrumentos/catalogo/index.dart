import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405); // Método não permitido
  }
  
  final connection = context.read<Connection>();
  
  try {
    // Query otimizada para o catálogo: inclui o NOME do local via JOIN
    final rows = await connection.execute(
      '''
        SELECT 
          i.id, i.patrimonio, i.descricao, i.categoria, 
          i.status::text AS status, 
          i.local_atual_id, 
          i.responsavel_atual_id, i.proxima_calibracao_em, 
          i.ativo, i.created_at, i.updated_at,
          lf.nome AS local_atual_nome -- NOVO: Nome do Local
        FROM instrumentos i
        LEFT JOIN locais_fisicos lf ON i.local_atual_id = lf.id; -- JOIN para obter o nome
      '''
    );

    // Mapeamento dos resultados
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
      'local_atual_nome': r[11], // O nome do local (índice 11)
    }).toList();

    return jsonOk(data);
  } catch (e, st) {
    print('GET /instrumentos/catalogo error: $e\n$st');
    return Response.json(statusCode: 500, body: {'error': 'internal'});
  }
}