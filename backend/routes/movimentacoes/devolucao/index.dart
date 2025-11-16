// ARQUIVO: routes/movimentacoes/devolucao/index.dart (Log Corrigido)

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:async'; 

// ... (Classes _BadRequest, _NotFound, e _userIdFromContext permanecem as mesmas) ...
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
  Map<String, dynamic> body = {}; 

  try {
    body = await readJson(context);
    print('======================================================');
    print('=== POST /movimentacoes/devolucao (BODY RECEBIDO) ===');
    print(body);
    print('======================================================');
    
    final idMovimentacao = body['idMovimentacao'] as String?;
    
    if (idMovimentacao == null || idMovimentacao.isEmpty) {
      throw _BadRequest('idMovimentacao é obrigatório.');
    }

    final parts = idMovimentacao.split('-');
    if (parts.length != 2) throw _BadRequest('Formato de idMovimentacao inválido.');
    
    final tipo = parts[0];
    final idStr = parts[1];
    final id = int.tryParse(idStr);

    if (id == null) throw _BadRequest('ID numérico inválido.');
    
    String? mensagemSucesso = 'Devolução registrada com sucesso.';

    // ==========================================================
    // ===== ROTA 1: DEVOLUÇÃO DE INSTRUMENTO ===================
    // ==========================================================
    if (tipo == 'inst') {
      final rows = await conn.execute(
        Sql.named('''
          UPDATE instrumentos
          SET status = 'disponivel', responsavel_atual_id = NULL, previsao_devolucao = NULL, updated_at = NOW()
          WHERE id = @id AND responsavel_atual_id = @uid AND status = 'em_uso'
          RETURNING id, patrimonio
        '''),
        parameters: { 'uid': uid, 'id': id },
      );
      
      if (rows.isEmpty) {
        throw _NotFound('Instrumento ID $id não encontrado, já devolvido ou não sob sua responsabilidade.');
      }
      mensagemSucesso = 'Instrumento ${rows.first.toColumnMap()['patrimonio']} devolvido.';
    
    // ==========================================================
    // ===== ROTA 2: DEVOLUÇÃO DE MATERIAL (COM LOTE) ===========
    // ==========================================================
    } else if (tipo == 'mat') {
      final quantidadeInput = body['quantidade'];
      final destinoLocalId = body['destino_local_id'];
      // NÃO precisamos do lote do body, vamos buscar no banco.
      
      if (destinoLocalId is! int) throw _BadRequest('destino_local_id (int) é obrigatório.');

      final double? quantidadeADevolver = double.tryParse(quantidadeInput.toString());

      if (quantidadeADevolver == null || quantidadeADevolver <= 0) {
        throw _BadRequest('Quantidade inválida, nula ou não fornecida.');
      }

      // --- PASSO 1: BUSCAR DADOS DA SAÍDA ORIGINAL ---
      // 'id' (ex: 33) é o ID da *movimentação de saída*.
      // Precisamos do material_id e lote reais associados a ela.
      final movOriginalRows = await conn.execute(
        Sql.named('''
          SELECT material_id, lote 
          FROM movimentacao_material 
          WHERE id = @id AND operacao = 'saida' AND responsavel_id = @uid
        '''),
        parameters: { 'id': id, 'uid': uid },
      );

      if (movOriginalRows.isEmpty) {
        throw _NotFound('Movimentação de saída original (ID $id) não encontrada ou não pertence a você.');
      }
      
      final movData = movOriginalRows.first.toColumnMap();
      final int materialIdCorreto = movData['material_id'] as int;
      final String? loteCorreto = movData['lote'] as String?;
      // --- FIM DO PASSO 1 ---

      // --- PASSO 2: GUARDRAIL (COM DADOS CORRETOS) ---
      final pendingRows = await conn.execute(
        Sql.named('''
          WITH UserBalance AS (
              SELECT 
                  SUM(CASE WHEN operacao = 'saida' THEN quantidade ELSE 0 END) - 
                  SUM(CASE WHEN operacao = 'devolucao' THEN quantidade ELSE 0 END) AS saldo_pendente
              FROM movimentacao_material
              WHERE responsavel_id = @uid 
                AND material_id = @mid -- Usando o material_id (ex: 18)
                AND (lote IS NOT DISTINCT FROM @lote) -- Usando o lote (ex: Lote A)
          )
          SELECT saldo_pendente FROM UserBalance;
        '''),
        parameters: { 
          'uid': uid, 
          'mid': materialIdCorreto, // <-- Corrigido
          'lote': loteCorreto       // <-- Corrigido
        },
      );

      final saldoResult = pendingRows.first.toColumnMap()['saldo_pendente'];
      final double currentPendingBalance = double.tryParse(saldoResult.toString()) ?? 0.0;
      
      if (quantidadeADevolver > currentPendingBalance) {
        throw _BadRequest('Quantidade a devolver ($quantidadeADevolver) excede o saldo pendente ($currentPendingBalance) em sua posse.');
      }
      if (currentPendingBalance <= 0) {
          throw _BadRequest('Não há saldo pendente para devolução deste material.');
      }
      // --- FIM DO PASSO 2 ---

      // --- PASSO 3: INSERT (COM DADOS CORRETOS) ---
      final ins = await conn.execute(
        Sql.named('''
          INSERT INTO movimentacao_material
            (operacao, material_id, destino_local_id, responsavel_id, quantidade, lote) 
          VALUES ('devolucao', @mid, @destino, @uid, @qtd, @lote)
          RETURNING id
        '''),
        parameters: {
          'mid': materialIdCorreto, // <-- Corrigido
          'destino': destinoLocalId,
          'uid': uid,
          'qtd': quantidadeADevolver,
          'lote': loteCorreto       // <-- Corrigido
        },
      );
      
      if (ins.isEmpty) { throw Exception('Falha ao registrar a devolução.'); }
      mensagemSucesso = 'Material (ID $materialIdCorreto) devolvido com $quantidadeADevolver unidades.';
    
    } else {
      throw _BadRequest('Tipo de movimentação desconhecido: $tipo.');
    }

    return jsonOk({'message': mensagemSucesso});

  } on _BadRequest catch (e) {
    print('>>> ERRO DE LÓGICA (BAD REQUEST): ${e.message}');
    return jsonBad({'error': e.message});
  } on _NotFound catch (e) {
    print('>>> ERRO DE LÓGICA (NOT FOUND): ${e.message}');
    return jsonNotFound(e.message);
  
  // ==========================================================
  // ===== BLOCO DE CAPTURA (CORRIGIDO) =======================
  // ==========================================================
  } on PgException catch (e, st) {
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    print('!!! ERRO DE BANCO DE DADOS (PgException) !!!');
    print('BODY QUE CAUSOU O ERRO: $body');
    // MENSAGEM: e.message é padrão e deve funcionar
    print('MENSAGEM: ${e.message}');
    // DADOS COMPLETOS: e.toString() incluirá code, detail, etc.
    print('DADOS COMPLETOS DA EXCEÇÃO: ${e.toString()}');
    print('STACK TRACE: \n$st');
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    return jsonServer({'error': 'Falha na transação de devolução', 'detail': e.message});
  
  // --- LOG DETALHO DE ERRO DE DART ---
  } catch (e, st) {
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    print('!!! ERRO DE RUNTIME DO DART (Cast, Null, etc.) !!!');
    print('BODY QUE CAUSOU O ERRO: $body');
    print('TIPO DO ERRO: ${e.runtimeType}');
    print('MENSAGEM: $e');
    print('STACK TRACE: \n$st');
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    return jsonServer({'error': 'Erro desconhecido ao processar devolução'});
  }
}