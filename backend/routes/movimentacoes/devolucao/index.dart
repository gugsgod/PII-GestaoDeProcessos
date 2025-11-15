// ARQUIVO: routes/movimentacoes/devolucao/index.dart

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:async'; 

// --- Exceções locais e Helper de Autenticação ---
class _BadRequest implements Exception {
  final String message;
  _BadRequest(this.message);
}

class _NotFound implements Exception {
  final String message;
  _NotFound(this.message);
}

// Helper para extrair o ID do usuário do token JWT
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
    final idMovimentacao = body['idMovimentacao'] as String?;
    
    if (idMovimentacao == null || idMovimentacao.isEmpty) {
      throw _BadRequest('idMovimentacao é obrigatório.');
    }

    final parts = idMovimentacao.split('-');
    if (parts.length != 2) {
      throw _BadRequest('Formato de idMovimentacao inválido (esperado: tipo-id).');
    }

    final tipo = parts[0];
    final idStr = parts[1];
    final id = int.tryParse(idStr);

    if (id == null) {
      throw _BadRequest('ID numérico inválido em idMovimentacao.');
    }

    // Executa diretamente sem usar transaction, como em routes/movimentacoes/saida
    if (tipo == 'inst') {
      final rows = await conn.execute(
        Sql.named('''
          UPDATE instrumentos
          SET 
            status = 'disponivel',
            responsavel_atual_id = NULL,
            previsao_devolucao = NULL,
            updated_at = NOW()
          WHERE
            id = @id AND responsavel_atual_id = @uid AND status = 'em_uso'
          RETURNING id, patrimonio
        '''),
        parameters: {
          'uid': uid,
          'id': id,
        },
      );

      if (rows.isEmpty) {
        throw _NotFound(
          'Instrumento ID $id não encontrado, já devolvido ou não sob sua responsabilidade.'
        );
      }

    } else if (tipo == 'mat') {
      // Campos adicionais necessários para a devolução de material
      final quantidade = body['quantidade'];
      final destinoLocalId = body['destino_local_id'];
      
      if (quantidade is! num || quantidade <= 0) {
        throw _BadRequest('quantidade deve ser um número maior que 0.');
      }
      if (destinoLocalId is! int) {
        throw _BadRequest('destino_local_id (int) é obrigatório para devolução de material.');
      }
      
      // O ID aqui é o material_id. Fazemos um INSERT de 'devolucao'.
      final ins = await conn.execute(
        Sql.named('''
          INSERT INTO movimentacao_material
            (operacao, material_id, destino_local_id, responsavel_id, quantidade)
          VALUES
            ('devolucao', @mid, @destino, @uid, @qtd)
          RETURNING id, created_at
        '''),
        parameters: {
          'mid': id, // ID do Material
          'destino': destinoLocalId,
          'uid': uid,
          'qtd': quantidade,
        },
      );
      
      if (ins.isEmpty) {
        throw Exception('Falha ao registrar a devolução de material. Movimentação vazia.');
      }

    } else {
      throw _BadRequest('Tipo de movimentação desconhecido: $tipo.');
    }
 
    return jsonOk({'message': 'Devolução registrada com sucesso.'});

  } on _BadRequest catch (e) {
    return jsonBad({'error': e.message});
  } on _NotFound catch (e) {
    return jsonNotFound(e.message);
  } on PgException catch (e, st) {
    print('POST /movimentacoes/devolucao pg error: $e\n$st');
    return jsonServer({'error': 'Falha na transação de devolução', 'detail': e.message});
  } catch (e, st) {
    print('POST /movimentacoes/devolucao error: $e\n$st');
    return jsonServer({'error': 'Erro desconhecido ao processar devolução'});
  }
}