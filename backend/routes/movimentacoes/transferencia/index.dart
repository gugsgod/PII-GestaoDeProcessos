import 'package:backend/api_utils.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

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

  final guard = await requireAdmin(context); // troque por requireAdmin se quiser
  if (guard != null) return guard;

  final conn = context.read<Connection>();

  try {
    final body = await readJson(context);
    final materialId = body['material_id'];
    final origemLocalId = body['origem_local_id'];
    final destinoLocalId = body['destino_local_id'];
    final lote = (body['lote'] as String?)?.trim();
    final quantidade = body['quantidade'];
    final observacao = (body['observacao'] as String?)?.trim();

    if (materialId is! int) {
      throw _BadRequest('material_id obrigatório');
    }
    if (origemLocalId is! int) {
      throw _BadRequest('origem_local_id obrigatório');
    }
    if (destinoLocalId is! int) {
      throw _BadRequest('destino_local_id obrigatório');
    }
    if (origemLocalId == destinoLocalId) {
      throw _BadRequest('origem e destino não podem ser iguais');
    }
    if (quantidade is! num || quantidade <= 0) {
      throw _BadRequest('quantidade deve ser > 0');
    }

    final out = await conn.runTx((tx) async {
      // valida material
      final Result m = await tx.execute(
        Sql.named('SELECT 1 FROM materiais WHERE id=@id'),
        parameters: {'id': materialId},
      );
      if (m.isEmpty) throw _BadRequest('material não encontrado');

      // valida locais
      final Result lo = await tx.execute(
        Sql.named('SELECT 1 FROM locais_fisicos WHERE id=@id'),
        parameters: {'id': origemLocalId},
      );
      if (lo.isEmpty) throw _NotFound('origem não encontrada');

      final Result ld = await tx.execute(
        Sql.named('SELECT 1 FROM locais_fisicos WHERE id=@id'),
        parameters: {'id': destinoLocalId},
      );
      if (ld.isEmpty) throw _NotFound('destino não encontrada');

      // debita origem (com lock)
      late final Result rows;
      if (lote == null || lote.isEmpty) {
        rows = await tx.execute(
          Sql.named('''
            SELECT id, qt_disp::float8
              FROM estoque_saldos
             WHERE material_id=@mid AND local_id=@lid AND lote IS NULL
             FOR UPDATE
          '''),
          parameters: {'mid': materialId, 'lid': origemLocalId},
        );
      } else {
        rows = await tx.execute(
          Sql.named('''
            SELECT id, qt_disp::float8
              FROM estoque_saldos
             WHERE material_id=@mid AND local_id=@lid AND lote=@lote
             FOR UPDATE
          '''),
          parameters: {'mid': materialId, 'lid': origemLocalId, 'lote': lote},
        );
      }

      if (rows.isEmpty) throw _BadRequest('saldo inexistente na origem');
      final int saldoOrigemId = rows.first[0] as int;
      final double dispOrigem = rows.first[1] as double;
      if (dispOrigem < quantidade) {
        throw _BadRequest(
            'saldo insuficiente na origem (disp: $dispOrigem, req: $quantidade)');
      }

      // atualiza origem
      final Result upOrigem = await tx.execute(
        Sql.named('''
          UPDATE estoque_saldos
             SET qt_disp = qt_disp - @qtd
           WHERE id=@sid
       RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
        '''),
        parameters: {'qtd': quantidade, 'sid': saldoOrigemId},
      );

      // credita destino (upsert)
      final Result dest = (lote == null || lote.isEmpty)
          ? await _upsertDestinoSemLote(
              tx, materialId, destinoLocalId, quantidade)
          : await _upsertDestinoComLote(
              tx, materialId, destinoLocalId, lote, quantidade);

      // log
      await _logMov(
        tx,
        tipo: 'transferencia',
        materialId: materialId,
        origemLocalId: origemLocalId,
        destinoLocalId: destinoLocalId,
        lote: (lote?.isEmpty == true) ? null : lote,
        quantidade: quantidade,
        observacao: observacao,
        usuarioId: null, // TODO: usar id do JWT se necessário
      );

      final rO = upOrigem.first;
      final rD = dest.first;
      return {
        'origem': {
          'saldo_id': rO[0],
          'lote': rO[1],
          'qt_disp': rO[2],
          'minimo': rO[3],
        },
        'destino': {
          'saldo_id': rD[0],
          'lote': rD[1],
          'qt_disp': rD[2],
          'minimo': rD[3],
        },
      };
    });

    return jsonOk(out);
  } on _BadRequest catch (e) {
    return jsonBad({'error': e.message});
  } on _NotFound catch (e) {
    return jsonNotFound(e.message);
  } on PgException catch (e, st) {
    print('POST /movimentacoes/transferencia pg error: $e\n$st');
    return jsonServer({'error': 'internal', 'detail': e.message});
  } catch (e, st) {
    print('POST /movimentacoes/transferencia error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

Future<Result> _upsertDestinoSemLote(
  dynamic tx,
  int materialId,
  int localId,
  num qtd,
) async {
  final up = await tx.execute(
    Sql.named('''
      UPDATE estoque_saldos
         SET qt_disp = qt_disp + @qtd
       WHERE material_id=@mid AND local_id=@lid AND lote IS NULL
   RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
    '''),
    parameters: {'mid': materialId, 'lid': localId, 'qtd': qtd},
  ) as Result;
  if (up.isNotEmpty) return up;

  final ins = await tx.execute(
    Sql.named('''
      INSERT INTO estoque_saldos (material_id, local_id, lote, qt_disp, minimo)
      VALUES (@mid, @lid, NULL, @qtd, 0)
      RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
    '''),
    parameters: {'mid': materialId, 'lid': localId, 'qtd': qtd},
  ) as Result;
  return ins;
}

Future<Result> _upsertDestinoComLote(
  dynamic tx,
  int materialId,
  int localId,
  String lote,
  num qtd,
) async {
  final up = await tx.execute(
    Sql.named('''
      UPDATE estoque_saldos
         SET qt_disp = qt_disp + @qtd
       WHERE material_id=@mid AND local_id=@lid AND lote=@lote
   RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
    '''),
    parameters: {'mid': materialId, 'lid': localId, 'lote': lote, 'qtd': qtd},
  ) as Result;
  if (up.isNotEmpty) return up;

  final ins = await tx.execute(
    Sql.named('''
      INSERT INTO estoque_saldos (material_id, local_id, lote, qt_disp, minimo)
      VALUES (@mid, @lid, @lote, @qtd, 0)
      RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
    '''),
    parameters: {'mid': materialId, 'lid': localId, 'lote': lote, 'qtd': qtd},
  ) as Result;
  return ins;
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
      'uid': usuarioId,
      'obs': observacao,
    },
  );
}
