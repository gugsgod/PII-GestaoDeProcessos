import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

class _BadRequest implements Exception {
  final String message;
  _BadRequest(this.message);
}
class _NotFound implements Exception {
  final String message;
  _NotFound(this.message);
}

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

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

    if (materialId is! int) throw _BadRequest('material_id obrigatório');
    if (localId is! int) throw _BadRequest('local_id obrigatório');
    if (quantidade is! num || quantidade <= 0) {
      throw _BadRequest('quantidade deve ser > 0');
    }

    final res = await conn.runTx((tx) async {
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

      // pega saldo (lock)
      final rows = (lote == null || lote.isEmpty)
          ? await tx.execute(
              Sql.named('''
                SELECT id, qt_disp::float8
                  FROM estoque_saldos
                 WHERE material_id=@mid AND local_id=@lid AND lote IS NULL
                 FOR UPDATE
              '''),
              parameters: {'mid': materialId, 'lid': localId},
            )
          : await tx.execute(
              Sql.named('''
                SELECT id, qt_disp::float8
                  FROM estoque_saldos
                 WHERE material_id=@mid AND local_id=@lid AND lote=@lote
                 FOR UPDATE
              '''),
              parameters: {'mid': materialId, 'lid': localId, 'lote': lote},
            );

      if (rows.isEmpty) throw _BadRequest('saldo inexistente para saída');
      final saldoId = rows.first[0] as int;
      final atual = rows.first[1] as double;
      if (atual < quantidade) {
        throw _BadRequest('saldo insuficiente (disp: $atual, req: $quantidade)');
      }

      final up = await tx.execute(
        Sql.named('''
          UPDATE estoque_saldos
             SET qt_disp = qt_disp - @qtd
           WHERE id=@sid
       RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
        '''),
        parameters: {'qtd': quantidade, 'sid': saldoId},
      );
      final r = up.first;

      await _logMov(
        tx,
        tipo: 'saida',
        materialId: materialId,
        origemLocalId: localId,
        destinoLocalId: null,
        lote: lote?.isEmpty == true ? null : lote,
        quantidade: quantidade,
        observacao: observacao,
        usuarioId: null, // TODO
      );

      return {'saldo_id': r[0], 'lote': r[1], 'qt_disp': r[2], 'minimo': r[3]};
    });

    return jsonOk(res);
  } on _BadRequest catch (e) {
    return jsonBad({'error': e.message});
  } on _NotFound catch (e) {
    return jsonNotFound(e.message);
  } on PgException catch (e, st) {
    print('POST /movimentacoes/saida pg error: $e\n$st');
    return jsonServer({'error': 'internal', 'detail': e.message});
  } catch (e, st) {
    print('POST /movimentacoes/saida error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

Future<void> _logMov(
  dynamic tx, {
  required String tipo,
  required int materialId,
  int? origemLocalId,
  int? destinoLocalId,
  String? lote,
  required num quantidade,
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
      'uid': usuarioId,
      'obs': observacao,
    },
  );
}
