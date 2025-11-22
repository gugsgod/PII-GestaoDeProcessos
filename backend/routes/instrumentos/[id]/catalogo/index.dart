import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context, String idStr) async {
  // Apenas PATCH permitido
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405);
  }

  // Apenas Admin ou Técnico autenticado
  // final user = await getPayload(context);
  // if (user == null) return jsonUnauthorized('Token inválido');

  final conn = context.read<Connection>();
  final id = int.tryParse(idStr);

  if (id == null) return jsonBad({'error': 'ID inválido'});

  try {
    final body = await readJson(context);
    final novaDataStr = body['proxima_calibracao_em'] as String?;

    if (novaDataStr == null) {
      return jsonBad({'error': 'Data (proxima_calibracao_em) é obrigatória'});
    }

    final novaData = DateTime.tryParse(novaDataStr);
    if (novaData == null) {
      return jsonBad({'error': 'Formato de data inválido (ISO 8601 esperado)'});
    }

    // Atualiza a data no banco
    final result = await conn.execute(
      Sql.named('''
        UPDATE instrumentos
        SET proxima_calibracao_em = @data,
            updated_at = NOW()
        WHERE id = @id
        RETURNING id, proxima_calibracao_em
      '''),
      parameters: {
        'id': id,
        'data': novaData.toUtc(), // Salvar em UTC
      },
    );

    if (result.isEmpty) {
      return jsonNotFound('Instrumento não encontrado');
    }

    return jsonOk({
      'message': 'Calibração atualizada com sucesso',
      'nova_data': result.first[1],
    });

  } catch (e, st) {
    print('PATCH /instrumentos/$id/calibracao error: $e\n$st');
    return jsonServer({'error': 'Erro interno ao atualizar calibração'});
  }
}