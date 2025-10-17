import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context, String materialIdStr) async {
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405);
  }

  // admin only
  final guard = await requireAdmin(context);
  if (guard != null) return guard;

  final conn = context.read<Connection>();
  final mid = int.tryParse(materialIdStr);
  if (mid == null) return jsonBad({'error': 'material_id inválido'});

  try {
    final body = await readJson(context);

    // valida mínimo
    final minimo = body['minimo'];
    if (minimo is! num || minimo < 0) {
      return jsonBad({'error': 'minimo deve ser >= 0'});
    }

    // --------- Resolver local (local_id direto OU contexto/base/veiculo+nome) ---------
    int? localId = (body['local_id'] is int) ? body['local_id'] as int : null;
    final String? lote = (body['lote'] as String?)?.trim();

    if (localId == null) {
      final contexto = (body['contexto'] as String?)?.trim(); // 'base' | 'veiculo'
      final baseId   = body['base_id'];
      final veiculoId= body['veiculo_id'];
      final nome     = (body['nome'] as String?)?.trim();

      if (contexto != 'base' && contexto != 'veiculo') {
        return jsonBad({
          'error': 'informe local_id OU (contexto + base_id/veiculo_id + nome)'
        });
      }
      if (nome == null || nome.isEmpty) {
        return jsonBad({'error': 'nome do local é obrigatório quando usar contexto'});
      }
      if (contexto == 'base' && baseId is! int) {
        return jsonBad({'error': 'base_id é obrigatório quando contexto=base'});
      }
      if (contexto == 'veiculo' && veiculoId is! int) {
        return jsonBad({'error': 'veiculo_id é obrigatório quando contexto=veiculo'});
      }

      // tenta encontrar local existente
      final q = await conn.execute(
        Sql.named('''
          SELECT id
            FROM locais_fisicos
           WHERE contexto = @ctx
             AND ((@ctx='base' AND base_id=@bid) OR (@ctx='veiculo' AND veiculo_id=@vid))
             AND nome = @nome
           LIMIT 1
        '''),
        parameters: {
          'ctx': contexto,
          'bid': contexto == 'base' ? baseId as int : null,
          'vid': contexto == 'veiculo' ? veiculoId as int : null,
          'nome': nome,
        },
      );

      if (q.isNotEmpty) {
        localId = q.first[0] as int;
      } else {
        // cria local automaticamente
        final insLoc = await conn.execute(
          Sql.named('''
            INSERT INTO locais_fisicos (contexto, base_id, veiculo_id, nome)
            VALUES (@ctx, @bid, @vid, @nome)
            RETURNING id
          '''),
          parameters: {
            'ctx': contexto,
            'bid': contexto == 'base' ? baseId as int : null,
            'vid': contexto == 'veiculo' ? veiculoId as int : null,
            'nome': nome,
          },
        );
        localId = insLoc.first[0] as int;
      }
    } else {
      // valida local_id explícito
      final l = await conn.execute(
        Sql.named('SELECT 1 FROM locais_fisicos WHERE id=@id'),
        parameters: {'id': localId},
      );
      if (l.isEmpty) return jsonNotFound('local não encontrado');
    }

    // ----------------- ATUALIZAÇÃO/CRIAÇÃO DO SALDO -----------------
    if (lote == null || lote.isEmpty) {
      // caminho SEM lote -> não passar @lote nulo (evita 42P08)
      final up = await conn.execute(
        Sql.named('''
          UPDATE estoque_saldos
             SET minimo = @minimo
           WHERE material_id = @mid
             AND local_id    = @lid
             AND lote IS NULL
       RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
        '''),
        parameters: {'mid': mid, 'lid': localId, 'minimo': minimo},
      );

      if (up.isNotEmpty) {
        final r = up.first;
        return jsonOk({
          'saldo_id': r[0],
          'lote': r[1],
          'qt_disp': r[2],
          'minimo': r[3],
        });
      }

      final ins = await conn.execute(
        Sql.named('''
          INSERT INTO estoque_saldos (material_id, local_id, lote, qt_disp, minimo)
          VALUES (@mid, @lid, NULL, 0, @minimo)
          RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
        '''),
        parameters: {'mid': mid, 'lid': localId, 'minimo': minimo},
      );
      final r2 = ins.first;
      return Response.json(
        statusCode: 201,
        body: {
          'saldo_id': r2[0],
          'lote': r2[1],
          'qt_disp': r2[2],
          'minimo': r2[3],
        },
      );
    } else {
      // caminho COM lote -> comparar por igualdade
      final up = await conn.execute(
        Sql.named('''
          UPDATE estoque_saldos
             SET minimo = @minimo
           WHERE material_id = @mid
             AND local_id    = @lid
             AND lote        = @lote
       RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
        '''),
        parameters: {'mid': mid, 'lid': localId, 'lote': lote, 'minimo': minimo},
      );

      if (up.isNotEmpty) {
        final r = up.first;
        return jsonOk({
          'saldo_id': r[0],
          'lote': r[1],
          'qt_disp': r[2],
          'minimo': r[3],
        });
      }

      final ins = await conn.execute(
        Sql.named('''
          INSERT INTO estoque_saldos (material_id, local_id, lote, qt_disp, minimo)
          VALUES (@mid, @lid, @lote, 0, @minimo)
          RETURNING id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
        '''),
        parameters: {'mid': mid, 'lid': localId, 'lote': lote, 'minimo': minimo},
      );
      final r2 = ins.first;
      return Response.json(
        statusCode: 201,
        body: {
          'saldo_id': r2[0],
          'lote': r2[1],
          'qt_disp': r2[2],
          'minimo': r2[3],
        },
      );
    }
  } on PgException catch (e, st) {
    print('PATCH /estoque/minimo/$materialIdStr pg error: $e\n$st');
    return jsonServer({'error': 'internal', 'detail': e.message});
  } catch (e, st) {
    print('PATCH /estoque/minimo/$materialIdStr error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}
