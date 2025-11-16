// ARQUIVO: routes/movimentacoes/pendentes/index.dart (CORREÇÃO FINAL DE FLUXO)

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:convert';

// Função para pegar o ID do usuário (da tabela 'usuarios')
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
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final uid = _userIdFromContext(context);
  if (uid == null) return jsonUnauthorized('Token inválido ou ausente.');

  final conn = context.read<Connection>();
  
  try {
    final pendencias = <Map<String, dynamic>>[];

    // === 1. BUSCAR INSTRUMENTOS PENDENTES (Lógica 1:1, status) ===
    final instrumentos = await conn.execute(
      Sql.named('''
        SELECT 
          id, descricao, patrimonio, updated_at, previsao_devolucao
        FROM instrumentos
        WHERE 
          responsavel_atual_id = @uid AND status = 'em_uso'
      '''),
      parameters: {'uid': uid},
    );

    for (final row in instrumentos) {
      final data = row.toColumnMap();
      pendencias.add({
        'idMovimentacao': 'inst-${data['id']}', 
        'nomeMaterial': data['descricao'],
        'idMaterial': data['patrimonio'], 
        'status': true, 
        'localizacao': 'Em sua posse', 
        'dataRetirada': (data['updated_at'] as DateTime).toIso8601String(),
        'dataDevolucao': (data['previsao_devolucao'] as DateTime).toIso8601String(),
        'quantidade_original': 1, // Instrumento é sempre 1
        'quantidade_pendente': 1,
      });
    }

    // === 2. BUSCAR MATERIAIS PENDENTES (Lógica N:M, saldo líquido) ===
    
    // 2.1. CTE: Calcula o saldo líquido de cada item retirado (saída - devolução)
    const String materialQuery = '''
    WITH NetBalance AS (
        SELECT 
            mm.material_id,
            mm.lote,
            -- Calcula o saldo que o usuário ainda deve (GLOBAL)
            SUM(CASE WHEN mm.operacao = 'saida' THEN mm.quantidade ELSE 0 END) - 
            SUM(CASE WHEN mm.operacao = 'devolucao' THEN mm.quantidade ELSE 0 END) AS saldo_pendente
        FROM 
            movimentacao_material mm
        WHERE 
            mm.responsavel_id = @uid 
        GROUP BY 
            mm.material_id, mm.lote -- NÃO AGRUPA POR LOCAL
        HAVING 
            SUM(CASE WHEN mm.operacao = 'saida' THEN mm.quantidade ELSE 0 END) > SUM(CASE WHEN mm.operacao = 'devolucao' THEN mm.quantidade ELSE 0 END)
    )
    -- Seleciona o registro de saída original mais recente (para dados do card)
    SELECT 
        (SELECT id FROM movimentacao_material m_inner 
            WHERE m_inner.responsavel_id = @uid 
            AND m_inner.material_id = nb.material_id 
            AND (m_inner.lote IS NOT DISTINCT FROM nb.lote)
            AND m_inner.operacao = 'saida' 
            ORDER BY m_inner.created_at DESC LIMIT 1) AS id_movimentacao_saida,
            
        nb.saldo_pendente AS quantidade_pendente,
        
        (SELECT previsao_devolucao FROM movimentacao_material m_inner 
            WHERE m_inner.responsavel_id = @uid 
            AND m_inner.material_id = nb.material_id 
            AND (m_inner.lote IS NOT DISTINCT FROM nb.lote)
            AND m_inner.operacao = 'saida' 
            ORDER BY m_inner.created_at DESC LIMIT 1) AS previsao_devolucao,

        (SELECT created_at FROM movimentacao_material m_inner 
            WHERE m_inner.responsavel_id = @uid 
            AND m_inner.material_id = nb.material_id 
            AND (m_inner.lote IS NOT DISTINCT FROM nb.lote)
            AND m_inner.operacao = 'saida' 
            ORDER BY m_inner.created_at DESC LIMIT 1) AS data_retirada,
            
        (SELECT lf.nome FROM movimentacao_material m_inner 
            JOIN locais_fisicos lf ON lf.id = m_inner.origem_local_id
            WHERE m_inner.responsavel_id = @uid 
            AND m_inner.material_id = nb.material_id 
            AND (m_inner.lote IS NOT DISTINCT FROM nb.lote)
            AND m_inner.operacao = 'saida' 
            ORDER BY m_inner.created_at DESC LIMIT 1) AS local_origem,
            
        m.descricao, 
        m.cod_sap
    FROM 
        NetBalance nb
    JOIN 
        materiais m ON m.id = nb.material_id;
    ''';
    
    final materiais = await conn.execute(
        Sql.named(materialQuery),
        parameters: {'uid': uid}
    );

    // Formata os materiais (CORRIGIDO PARA OS NOVOS NOMES DE COLUNA)
    for (final row in materiais) {
      final data = row.toColumnMap();
      pendencias.add({
        'idMovimentacao': 'mat-${data['id_movimentacao_saida']}',
        'nomeMaterial': data['descricao'],
        'idMaterial': 'MAT${data['cod_sap']}', 
        'status': true,
        'localizacao': 'Retirado de: ${data['local_origem']}', 
        'dataRetirada': (data['data_retirada'] as DateTime).toIso8601String(),
        'dataDevolucao': (data['previsao_devolucao'] as DateTime).toIso8601String(),
        'quantidade_pendente': double.parse(data['quantidade_pendente'].toString()),
        'lote': data['lote'], // <--- PASSO 1: ADICIONA O LOTE AO JSON
      });
    }
    // Ordena pela data de devolução
    pendencias.sort((a, b) => 
      DateTime.parse(a['dataDevolucao'] as String).compareTo(DateTime.parse(b['dataDevolucao'] as String))
    );

    // Retorna a lista
    return Response.bytes(
      body: utf8.encode(jsonEncode(pendencias)),
      headers: {'Content-Type': 'application/json'},
    );

  } on PgException catch (e, st) {
    print('GET /movimentacoes/pendentes pg error: $e\n$st');
    return jsonServer({'error': 'internal', 'detail': e.message});
  } catch (e, st) {
    print('GET /movimentacoes/pendentes error: $e\n$st');
    return jsonServer({'error': 'internal', 'detail': e.toString()});
  }
}