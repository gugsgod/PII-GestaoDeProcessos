// ARQUIVO: routes/movimentacoes/pendentes/index.dart (Corrigido)

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:convert'; // Para o jsonEncode

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

  // Protegido: Pega o ID do usuário logado
  final uid = _userIdFromContext(context);
  if (uid == null) return jsonUnauthorized('Token inválido ou ausente.');

  final conn = context.read<Connection>();
  
  try {
    // Lista final que será enviada
    final pendencias = <Map<String, dynamic>>[];

    // === 1. BUSCAR INSTRUMENTOS PENDENTES ===
    final instrumentos = await conn.execute(
      Sql.named('''
        SELECT 
          id, 
          descricao, 
          patrimonio, 
          updated_at, 
          previsao_devolucao
        FROM instrumentos
        WHERE 
          responsavel_atual_id = @uid AND status = 'em_uso'
      '''),
      parameters: {'uid': uid},
    );

    // Formata os instrumentos para o JSON que o app espera
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
      });
    }

    // === 2. BUSCAR MATERIAIS PENDENTES ===
    final materiais = await conn.execute(
      Sql.named('''
        SELECT 
          mm.id, 
          m.descricao, 
          m.cod_sap, 
          lf.nome as local_origem,
          mm.created_at, -- A "data de retirada"
          mm.previsao_devolucao
        FROM movimentacao_material mm
        JOIN materiais m ON m.id = mm.material_id
        JOIN locais_fisicos lf ON lf.id = mm.origem_local_id
        WHERE 
          mm.responsavel_id = @uid AND mm.operacao = 'saida'
      '''),
      parameters: {'uid': uid},
    );

    // Formata os materiais para o JSON que o app espera
    for (final row in materiais) {
      final data = row.toColumnMap();
      pendencias.add({
        'idMovimentacao': 'mat-${data['id']}', 
        'nomeMaterial': data['descricao'],
        'idMaterial': 'MAT${data['cod_sap']}', 
        'status': true,
        'localizacao': 'Retirado de: ${data['local_origem']}', 
        'dataRetirada': (data['created_at'] as DateTime).toIso8601String(),
        'dataDevolucao': (data['previsao_devolucao'] as DateTime).toIso8601String(),
      });
    }

    pendencias.sort((a, b) => 
      DateTime.parse(a['dataDevolucao'] as String).compareTo(DateTime.parse(b['dataDevolucao'] as String))
    );

    // Usamos jsonEncode aqui para tratar as datas (evitar o erro de DateTime)
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