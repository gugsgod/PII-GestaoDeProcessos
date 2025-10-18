import 'package:backend/api_utils.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

// Exceções simples locais
class _BadRequest implements Exception {
  _BadRequest(this.message);
  final String message;
}

class _NotFound implements Exception {
  _NotFound(this.message);
  final String message;
}

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  // Exija usuário autenticado (troque por requireAdmin se preferir)
  final guard = await requireAdmin(context);
  if (guard != null) return guard;

  final conn = context.read<Connection>();

  try {
    final body = await readJson(context);
    final materialId = body['material_id'];
    final localId = body['local_id'];
    final lote = (body['lote'] as String?)?.trim();
    final quantidade = body['quantidade'];
    final observacao = (body['observacao'] as String?)?.trim();

    if (materialId is! int) {
      throw _BadRequest('material_id (int) é obrigatório');
    }
    if (localId is! int) throw _BadRequest('local_id (int) é obrigatório');
    if (quantidade is! num || quantidade <= 0) {
      throw _BadRequest('quantidade deve ser > 0');
    }

    final result = await conn.runTx((tx) async {
      // valida material/local
      final m = await tx.execute(
        Sql.named('SELECT 1 FROM materiais WHERE id=@id'),
        parameters: {'id': materialId},
      );
      if (m.isEmpty) throw _BadRequest('material não encontrado');

      final l = await tx.execute(
        Sql.named('SELECT 1 FROM locais_fisicos WHERE id=@id'),
        parameters: {'id': localId},
      );
      if (l.isEmpty) throw _NotFound('local não encontrado');

      // upsert do saldo
      if (lote == null || lote.isEmpty) {
        final up = await tx.execute(
          Sql.named('''
            UPDATE estoque_saldos
               SET qt_disp = qt_disp + @qtd
             WHERE material_id=@mid AND local_id=@lid AND lote IS NULL
         RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
          '''),
          parameters: {'mid': materialId, 'lid': localId, 'qtd': quantidade},
        );

        final row = up.isNotEmpty
            ? up.first
            : (await tx.execute(
                Sql.named('''
                  INSERT INTO estoque_saldos (material_id, local_id, lote, qt_disp, minimo)
                  VALUES (@mid, @lid, NULL, @qtd, 0)
                  RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
                '''),
                parameters: {
                  'mid': materialId,
                  'lid': localId,
                  'qtd': quantidade
                },
              ))
                .first;

        // log
        await _logMov(
          tx,
          tipo: 'entrada',
          materialId: materialId,
          origemLocalId: null,
          destinoLocalId: localId,
          lote: null,
          quantidade: quantidade,
          observacao: observacao,
          usuarioId: null, // TODO: pegue do JWT se precisar
        );

        return {
          'saldo_id': row[0],
          'lote': row[1],
          'qt_disp': row[2],
          'minimo': row[3],
        };
      } else {
        final up = await tx.execute(
          Sql.named('''
            UPDATE estoque_saldos
               SET qt_disp = qt_disp + @qtd
             WHERE material_id=@mid AND local_id=@lid AND lote=@lote
         RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
          '''),
          parameters: {
            'mid': materialId,
            'lid': localId,
            'lote': lote,
            'qtd': quantidade
          },
        );

        final row = up.isNotEmpty
            ? up.first
            : (await tx.execute(
                Sql.named('''
                  INSERT INTO estoque_saldos (material_id, local_id, lote, qt_disp, minimo)
                  VALUES (@mid, @lid, @lote, @qtd, 0)
                  RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
                '''),
                parameters: {
                  'mid': materialId,
                  'lid': localId,
                  'lote': lote,
                  'qtd': quantidade
                },
              ))
                .first;

        // log
        await _logMov(
          tx,
          tipo: 'entrada',
          materialId: materialId,
          origemLocalId: null,
          destinoLocalId: localId,
          lote: lote,
          quantidade: quantidade,
          observacao: observacao,
          usuarioId: null, // TODO
        );

        return {
          'saldo_id': row[0],
          'lote': row[1],
          'qt_disp': row[2],
          'minimo': row[3],
        };
      }
    });

    return jsonOk(result);
  } on _BadRequest catch (e) {
    return jsonBad({'error': e.message});
  } on _NotFound catch (e) {
    return jsonNotFound(e.message);
  } on PgException catch (e, st) {
    print('POST /movimentacoes/entrada pg error: $e\n$st');
    return jsonServer({'error': 'internal', 'detail': e.toString()});
  } on Exception catch (e, st) {
    print('POST /movimentacoes/entrada error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

Future<void> _logMov(
  dynamic tx, {
  required String tipo,
  required int materialId,
  required num quantidade, int? origemLocalId,
  int? destinoLocalId,
  String? lote,
  String? observacao,
  int? usuarioId,
}) async {
  await tx.execute(
    Sql.named('''
      INSERT INTO movimentacao_material
      (tipo, material_id, origem_local_id, destino_local_id, lote, quantidade, usuario_id, observacao)
      VALUES (@tipo, @mid, @origem, @destino, @lote, @qtd, @uid, @obs)
    '''),
    parameters: {
      'tipo': tipo,
      'mid': materialId,
      'origem': origemLocalId,
      'destino': destinoLocalId,
      'lote': lote,
      'qtd': quantidade,
      'uid': usuarioId, // null se não tiver
      'obs': observacao,
    },
  );
}
