// ARQUIVO: routes/movimentacoes/historico/index.dart

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:convert';

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
  print('=== INICIANDO GET /movimentacoes/historico ===');

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final uid = _userIdFromContext(context);
  if (uid == null) return jsonUnauthorized('Token inválido ou ausente.');

  print('USUÁRIO IDENTIFICADO: ID $uid');

  final conn = context.read<Connection>();
  
  try {
    final historico = <Map<String, dynamic>>[];

    // ==================================================
    // 1. HISTÓRICO DE INSTRUMENTOS (Ciclos Fechados)
    // ==================================================
    // Buscamos eventos de 'devolucao' e tentamos achar a 'retirada' correspondente

    print('>>> EXECUTANDO QUERY INSTRUMENTOS...');

    final instrumentos = await conn.execute(
      Sql.named('''
        SELECT 
          mi.id AS mov_id,
          i.descricao, 
          i.patrimonio, 
          i.categoria,
          mi.created_at AS data_devolucao,
          -- Subquery para tentar achar a data da retirada anterior mais próxima
          (
            SELECT created_at 
            FROM movimentacao_instrumento mi2
            WHERE mi2.instrumento_id = mi.instrumento_id
              AND mi2.responsavel_id = mi.responsavel_id
              AND mi2.operacao = 'retirada'
              AND mi2.created_at < mi.created_at
            ORDER BY mi2.created_at DESC 
            LIMIT 1
          ) AS data_retirada
        FROM movimentacao_instrumento mi
        JOIN instrumentos i ON i.id = mi.instrumento_id
        WHERE 
          mi.responsavel_id = @uid 
          AND mi.operacao = 'devolucao'
        ORDER BY mi.created_at DESC
      '''),
      parameters: {'uid': uid},
    );

    print('>>> QUERY INSTRUMENTOS SUCESSO. LINHAS: ${instrumentos.length}');

    for (final row in instrumentos) {
      final data = row.toColumnMap();
      final dtDev = data['data_devolucao'] as DateTime;
      final dtRet = (data['data_retirada'] as DateTime?) ?? dtDev;

      historico.add({
        'idMovimentacao': 'inst-hist-${data['mov_id']}',
        'nomeMaterial': data['descricao'],
        'idMaterial': data['patrimonio'],
        'categoria': data['categoria'],
        'isInstrumento': true,
        'statusTag': 'Devolvido',
        'localizacao': 'Almoxarifado / Base', // Histórico não tem local exato salvo no log simplificado
        'dataRetirada': dtRet.toIso8601String(),
        'dataDevolucaoReal': dtDev.toIso8601String(),
        'previsaoDevolucao': dtDev.toIso8601String(), // No histórico, a previsão vira a real
        'quantidade': 1,
      });
    }

    // ==================================================
    // 2. HISTÓRICO DE MATERIAIS (Devoluções)
    // ==================================================

    print('>>> EXECUTANDO QUERY MATERIAIS...');
    final materiais = await conn.execute(
      Sql.named('''
        SELECT 
          mm.id, 
          m.descricao, 
          m.cod_sap, 
          m.categoria,
          lf.nome as local_destino,
          mm.created_at AS data_devolucao,
          mm.quantidade,
          -- Tenta achar a data de retirada mais recente para contexto
          (
            SELECT created_at 
            FROM movimentacao_material mm2
            WHERE mm2.material_id = mm.material_id
              AND mm2.responsavel_id = mm.responsavel_id
              AND mm2.operacao = 'saida'
              AND mm2.created_at < mm.created_at
            ORDER BY mm2.created_at DESC 
            LIMIT 1
          ) AS data_retirada_estimada
        FROM movimentacao_material mm
        JOIN materiais m ON m.id = mm.material_id
        LEFT JOIN locais_fisicos lf ON lf.id = mm.destino_local_id
        WHERE 
          mm.responsavel_id = @uid 
          AND mm.operacao = 'devolucao'
      '''),
      parameters: {'uid': uid},
    );

    print('>>> QUERY MATERIAIS SUCESSO. LINHAS: ${materiais.length}');

    for (final row in materiais) {
      final data = row.toColumnMap();
      final dtDev = data['data_devolucao'] as DateTime;
      final dtRet = (data['data_retirada_estimada'] as DateTime?) ?? dtDev;
      final qtd = data['quantidade'];

      historico.add({
        'idMovimentacao': 'mat-hist-${data['id']}',
        'nomeMaterial': data['descricao'],
        'idMaterial': 'MAT${data['cod_sap']}',
        'categoria': data['categoria'],
        'isInstrumento': false,
        'statusTag': 'Devolvido ($qtd)',
        'localizacao': data['local_destino'] ?? 'N/A',
        'dataRetirada': dtRet.toIso8601String(),
        'dataDevolucaoReal': dtDev.toIso8601String(),
        'previsaoDevolucao': dtDev.toIso8601String(),
        'quantidade': qtd,
      });
    }

    // Ordenação final: Mais recentes primeiro
    String _asString(dynamic v) => v is String ? v : v?.toString() ?? '';
    historico.sort((a, b) {
      final dA = DateTime.parse(_asString(a['dataDevolucaoReal']));
      final dB = DateTime.parse(_asString(b['dataDevolucaoReal']));
      return dB.compareTo(dA);
    });

    print('=== FINALIZANDO COM SUCESSO ===');

    return Response.bytes(
      body: utf8.encode(jsonEncode(historico)),
      headers: {'Content-Type': 'application/json'},
    );

  } on PgException catch (e, st) {
    print('GET /movimentacoes/historico pg error: $e\n$st');
    return jsonServer({'error': 'internal', 'detail': e.message});
  } catch (e, st) {
    print('GET /movimentacoes/historico error: $e\n$st');
    return jsonServer({'error': 'internal', 'detail': e.toString()});
  }
}