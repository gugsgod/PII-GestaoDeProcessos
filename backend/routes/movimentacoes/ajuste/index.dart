// ARQUIVO: routes/movimentacoes/ajuste/index.dart

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

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

  // Apenas Admin pode ajustar estoque manualmente (Auditabilidade)
  final guard = await requireAdmin(context);
  if (guard != null) return guard;

  final uid = _userIdFromContext(context);
  final conn = context.read<Connection>();

  try {
    final body = await readJson(context);
    
    final materialId = body['material_id'] as int?;
    final localId = body['local_id'] as int?;
    final quantidade = body['quantidade']; // num
    final tipoAjuste = body['tipo']; // 'adicionar' ou 'remover'
    final motivo = body['motivo'] as String?;
    final lote = body['lote'] as String?;

    if (materialId == null || localId == null) {
      return jsonBad({'error': 'Material e Local são obrigatórios.'});
    }
    if (quantidade is! num || quantidade <= 0) {
      return jsonBad({'error': 'Quantidade deve ser positiva.'});
    }
    if (tipoAjuste != 'adicionar' && tipoAjuste != 'remover') {
      return jsonBad({'error': 'Tipo de ajuste inválido.'});
    }
    if (motivo == null || motivo.isEmpty) {
      return jsonBad({'error': 'Motivo do ajuste é obrigatório (Auditoria).'});
    }

    // Define a operação de banco baseada no tipo de ajuste
    // 'entrada' -> Soma no estoque (Trigger)
    // 'consumo' -> Subtrai do estoque (Trigger)
    final String operacao = (tipoAjuste == 'adicionar') ? 'entrada' : 'consumo';

    // Se for 'consumo', precisamos verificar se tem saldo suficiente antes?
    // O Trigger 'upsert_saldo' geralmente cuida disso ou permite negativo dependendo da config.
    // Vamos adicionar um guardrail simples aqui se for remoção.
    if (operacao == 'consumo') {
      final saldoRows = await conn.execute(
        Sql.named('SELECT qt_disp FROM estoque_saldos WHERE material_id=@m AND local_id=@l AND (lote IS NOT DISTINCT FROM @lt)'),
        parameters: {'m': materialId, 'l': localId, 'lt': lote},
      );
      final saldoAtual = saldoRows.isEmpty ? 0.0 : (saldoRows.first[0] as num).toDouble();
      
      if (quantidade > saldoAtual) {
        return jsonBad({'error': 'Saldo insuficiente para realizar a baixa. Atual: $saldoAtual'});
      }
    }

    // Executa a Movimentação
    await conn.execute(
      Sql.named('''
        INSERT INTO movimentacao_material 
          (operacao, material_id, origem_local_id, destino_local_id, responsavel_id, lote, quantidade, observacao)
        VALUES 
          (@op, @mid, @origem, @destino, @uid, @lote, @qtd, @obs)
      '''),
      parameters: {
        'op': operacao,
        'mid': materialId,
        // Para 'consumo', a origem é o local onde estava. Para 'entrada', o destino é onde vai entrar.
        'origem': (operacao == 'consumo') ? localId : null,
        'destino': (operacao == 'entrada') ? localId : null,
        'uid': uid,
        'lote': (lote?.isEmpty ?? true) ? null : lote,
        'qtd': quantidade,
        'obs': "AJUSTE MANUAL: $motivo",
      },
    );

    return jsonOk({'message': 'Estoque ajustado com sucesso.'});

  } on PgException catch (e) {
    print('Ajuste Error: $e');
    return jsonServer({'error': 'Erro de banco de dados', 'detail': e.message});
  } catch (e, st) {
    print('Ajuste Fatal: $e\n$st');
    return jsonServer({'error': 'Erro interno'});
  }
}