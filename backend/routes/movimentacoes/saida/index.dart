import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:async'; 

class _BadRequest implements Exception {
  final String message;
  _BadRequest(this.message);
}

class _NotFound implements Exception {
  final String message;
  _NotFound(this.message);
}

// Extrai o ID de 'usuarios(id_usuario)'
int? _userIdFromContext(RequestContext ctx) {
  try {
    final cfg = ctx.read<Map<String, String>>();
    final secret = cfg['JWT_SECRET'] ?? '';
    final auth = ctx.request.headers['authorization'];
    if (auth == null || !auth.startsWith('Bearer ')) return null;
    final token = auth.substring(7);
    final jwt = JWT.verify(token, SecretKey(secret));
    final payload = jwt.payload;
    final sub = (payload is Map) ? payload['sub'] : null;
    if (sub is int) return sub;
    if (sub is num) return sub.toInt();
    return int.tryParse(sub?.toString() ?? '');
  } catch (_) {
    return null;
  }
}

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final uid = _userIdFromContext(context);
  if (uid == null) return jsonUnauthorized('Token inválido ou ausente.');

  final conn = context.read<Connection>();

  try {
    final body = await readJson(context);
    final materialId = body['material_id'];
    final instrumentoId = body['instrumento_id'];
    final previsaoDevolucaoRaw = body['previsao_devolucao'] as String?;

    if (previsaoDevolucaoRaw == null) {
      throw _BadRequest('previsao_devolucao (ISO 8601) obrigatória');
    }
    final previsaoDevolucao = DateTime.tryParse(previsaoDevolucaoRaw);
    if (previsaoDevolucao == null) {
      throw _BadRequest('Formato de data inválido para previsao_devolucao');
    }

    // ==========================================================
    // ===== ROTA 1: SAÍDA DE INSTRUMENTO =======================
    // ==========================================================
    if (instrumentoId != null) {
      final rows = await conn.execute(
        Sql.named('''
          UPDATE instrumentos
          SET 
            status = 'em_uso',
            responsavel_atual_id = @uid,
            local_atual_id = NULL, 
            previsao_devolucao = @previsao
          WHERE
            id = @id AND status = 'disponivel'
        RETURNING id, patrimonio, status::text, previsao_devolucao
        '''),
        parameters: {
          'uid': uid,
          'previsao': previsaoDevolucao,
          'id': instrumentoId,
        },
      );
      
      if (rows.isEmpty) {
        throw _NotFound('Instrumento não encontrado ou indisponível para retirada.');
      }

      // --- CORREÇÃO ---
      // Converte o DateTime para uma String JSON-safe (ISO 8601)
      final instrumentoData = rows.first.toColumnMap();
      final previsao = instrumentoData['previsao_devolucao'] as DateTime;
      instrumentoData['previsao_devolucao'] = previsao.toIso8601String();

      return jsonOk({'instrumento': instrumentoData});
      // --- FIM DA CORREÇÃO ---
    }

    // ==========================================================
    // ===== ROTA 2: SAÍDA DE MATERIAL ==========================
    // ==========================================================
    else if (materialId != null) {
      final origemLocalId = body['local_id']; 
      final lote = (body['lote'] as String?)?.trim();
      final quantidade = body['quantidade'];

      if (materialId is! int) throw _BadRequest('material_id obrigatório');
      if (origemLocalId is! int) throw _BadRequest('local_id obrigatório');
      if (quantidade is! num || quantidade <= 0) {
        throw _BadRequest('quantidade deve ser > 0');
      }

      // CORRIGIDO: Usando 'retirada' (o valor do seu enum) em vez de 'saida'
      final ins = await conn.execute(
        Sql.named('''
          INSERT INTO movimentacao_material
            (operacao, material_id, origem_local_id, responsavel_id, lote, quantidade, previsao_devolucao)
          VALUES
            ('retirada', @mid, @origem, @uid, @lote, @qtd, @previsao)
          RETURNING id, created_at
        '''),
        parameters: {
          'mid': materialId,
          'origem': origemLocalId,
          'uid': uid,
          'lote': (lote?.isEmpty ?? true) ? null : lote,
          'qtd': quantidade,
          'previsao': previsaoDevolucao, // <-- Usando o DateTime
        },
      );
      
      // NOTA: A Rota 2 não falha porque você (corretamente) não incluiu
      // o 'created_at' (que também é um DateTime) na resposta JSON.
      return jsonOk({'mov_id': ins.first[0]});
    }
    
    // ==========================================================
    // ===== ROTA 3: ERRO (NENHUM ID) ===========================
    // ==========================================================
    else {
      throw _BadRequest('instrumento_id ou material_id deve ser fornecido.');
    }

  } on _BadRequest catch (e) {
    return jsonBad({'error': e.message});
  } on _NotFound catch (e) {
    return jsonNotFound(e.message);
  } on PgException catch (e, st) {
    print('POST /movimentacoes/saida pg error: $e\n$st');
    // if (e.code == 'P0001') { // Erro da Trigger (ex: estoque negativo)
    //    return jsonBad({'error': e.message});
    // }
    return jsonServer({'error': 'internal', 'detail': e.message});
  } catch (e, st) {
    print('POST /movimentacoes/saida error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}