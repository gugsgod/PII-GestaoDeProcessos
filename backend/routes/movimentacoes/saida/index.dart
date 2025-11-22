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
    
    // Lemos o local_id aqui, pois agora ele é usado para AMBOS (Materiais e Instrumentos)
    final localIdRaw = body['local_id'];
    
    final previsaoDevolucaoRaw = body['previsao_devolucao'] as String?;

    if (previsaoDevolucaoRaw == null) {
      throw _BadRequest('previsao_devolucao (ISO 8601) obrigatória');
    }
    final previsaoDevolucao = DateTime.tryParse(previsaoDevolucaoRaw);
    if (previsaoDevolucao == null) {
      throw _BadRequest('Formato de data inválido para previsao_devolucao');
    }
    
    // Força UTC para evitar problema de fuso horário no banco
    final previsaoDevolucaoUtc = previsaoDevolucao.toUtc();

    // ==========================================================
    // ===== ROTA 1: SAÍDA DE INSTRUMENTO =======================
    // ==========================================================
    if (instrumentoId != null) {
      
      // VALIDAÇÃO DO LOCAL DE ORIGEM (Vindo do Frontend)
      if (localIdRaw == null || localIdRaw is! int) {
        throw _BadRequest('Para retirar um instrumento, você deve informar o local de origem (local_id).');
      }
      final int origemLocalId = localIdRaw;

      // 1. Atualiza o status atual
      final rows = await conn.execute(
        Sql.named('''
          UPDATE instrumentos
          SET 
            status = 'em_uso',
            responsavel_atual_id = @uid,
            local_atual_id = NULL, -- O instrumento sai do local
            previsao_devolucao = @previsao,
            updated_at = NOW()
          WHERE
            id = @id AND status = 'disponivel'
          RETURNING id, patrimonio, status::text, previsao_devolucao, updated_at
        '''),
        parameters: {
          'uid': uid,
          'previsao': previsaoDevolucaoUtc,
          'id': instrumentoId,
        },
      );
      
      if (rows.isEmpty) {
        throw _NotFound('Instrumento não encontrado ou indisponível para retirada.');
      }

      // 2. Grava no Histórico (Agora usando o local fornecido pelo usuário)
      await conn.execute(
        Sql.named('''
          INSERT INTO movimentacao_instrumento 
            (instrumento_id, responsavel_id, operacao, created_at, origem_local_id, previsao_devolucao)
          VALUES 
            (@instId, @uid, 'retirada', NOW(), @origemId, @previsao)
        '''),
        parameters: {
          'instId': instrumentoId,
          'uid': uid,
          'origemId': origemLocalId, // <--- USA O ID DO DROPDOWN
          'previsao': previsaoDevolucaoUtc,
        }
      );

      // Formata resposta
      final instrumentoData = rows.first.toColumnMap();
      
      // Tratamento seguro de datas para retorno
      if (instrumentoData['previsao_devolucao'] is DateTime) {
         instrumentoData['previsao_devolucao'] = (instrumentoData['previsao_devolucao'] as DateTime).toIso8601String();
      }
      if (instrumentoData['updated_at'] is DateTime) {
         instrumentoData['updated_at'] = (instrumentoData['updated_at'] as DateTime).toIso8601String();
      }

      return jsonOk({'instrumento': instrumentoData});
    }

    // ==========================================================
    // ===== ROTA 2: SAÍDA DE MATERIAL ==========================
    // ==========================================================
    else if (materialId != null) {
      // Validação específica de material
      if (localIdRaw == null || localIdRaw is! int) {
         throw _BadRequest('local_id obrigatório para retirada de material.');
      }
      final int origemLocalId = localIdRaw;
      
      final lote = (body['lote'] as String?)?.trim();
      final quantidade = body['quantidade'];

      if (materialId is! int) throw _BadRequest('material_id obrigatório');
      if (quantidade is! num || quantidade <= 0) {
        throw _BadRequest('quantidade deve ser > 0');
      }

      final ins = await conn.execute(
        Sql.named('''
          INSERT INTO movimentacao_material
            (operacao, material_id, origem_local_id, responsavel_id, lote, quantidade, previsao_devolucao)
          VALUES
            ('saida', @mid, @origem, @uid, @lote, @qtd, @previsao)
          RETURNING id, created_at
        '''),
        parameters: {
          'mid': materialId,
          'origem': origemLocalId,
          'uid': uid,
          'lote': (lote?.isEmpty ?? true) ? null : lote,
          'qtd': quantidade,
          'previsao': previsaoDevolucaoUtc,
        },
      );
      
      return jsonOk({'mov_id': ins.first[0]});
    }
    
    else {
      throw _BadRequest('instrumento_id ou material_id deve ser fornecido.');
    }

  } on _BadRequest catch (e) {
    return jsonBad({'error': e.message});
  } on _NotFound catch (e) {
    return jsonNotFound(e.message);
  } on PgException catch (e, st) {
    print('POST /movimentacoes/saida pg error: $e\n$st');
    // Se violar check constraint (estoque negativo ou regra de fluxo)
    // if (e.code == '23514') { 
    //    return jsonBad({'error': 'Operação inválida: violação de regra de estoque ou fluxo.'});
    // }
    return jsonServer({'error': 'internal', 'detail': e.message});
  } catch (e, st) {
    print('POST /movimentacoes/saida error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}