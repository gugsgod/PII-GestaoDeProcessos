import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _list(context);
    case HttpMethod.post:
      final guard = await requireAdmin(context);
      if (guard != null) return guard;
      return _create(context);
    default:
      return Response(statusCode: 405);
  }
}

Future<Response> _list(RequestContext context) async {
  final conn = context.read<Connection>();
  final qp = context.request.uri.queryParameters;
  final baseId = int.tryParse(qp['base_id'] ?? '');
  final veicId = int.tryParse(qp['veiculo_id'] ?? '');
  final q = qp['q']?.trim();
  final pg = readPagination(context.request);

  final where = <String>[];
  final params = <String, Object?>{};

  if (baseId != null) {
    where.add('contexto = \'base\' AND base_id = @base_id');
    params['base_id'] = baseId;
  }
  if (veicId != null) {
    where.add('contexto = \'veiculo\' AND veiculo_id = @veiculo_id');
    params['veiculo_id'] = veicId;
  }
  if (q != null && q.isNotEmpty) {
    where.add('nome ILIKE @q');
    params['q'] = '%$q%';
  }
  final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

  try {
    final totalRows = await conn.execute(
      Sql.named('SELECT COUNT(*) FROM locais_fisicos $whereSql'),
      parameters: params,
    );
    final total = totalRows.first[0] as int;

    final rows = await conn.execute(
      Sql.named('''
        SELECT id, contexto::text AS contexto, base_id, veiculo_id, nome
          FROM locais_fisicos
          $whereSql
         ORDER BY nome
         LIMIT @limit OFFSET @offset
      '''),
      parameters: {...params, 'limit': pg.limit, 'offset': pg.offset},
    );

    final data = rows
        .map((r) => {
              'id': r[0],
              'contexto': r[1],
              'base_id': r[2],
              'veiculo_id': r[3],
              'nome': r[4],
            })
        .toList();

    return jsonOk(
        {'page': pg.page, 'limit': pg.limit, 'total': total, 'data': data});
  } catch (e, st) {
    print('GET /locais error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

// routes/locais/index.dart (método _create)
Future<Response> _create(RequestContext context) async {
  final conn = context.read<Connection>();
  try {
    final body = await readJson(context);

    final contexto = (body['contexto'] as String?)?.trim(); // 'base' | 'veiculo'
    final baseId = body['base_id'];
    final veiculoId = body['veiculo_id'];
    final nome = (body['nome'] as String?)?.trim();

    if (contexto != 'base' && contexto != 'veiculo') {
      return jsonBad({'error': 'contexto deve ser "base" ou "veiculo"'});
    }
    if (nome == null || nome.isEmpty) {
      return jsonBad({'error': 'nome é obrigatório'});
    }
    if (contexto == 'base' && (baseId is! int)) {
      return jsonBad({'error': 'base_id é obrigatório quando contexto=base'});
    }
    if (contexto == 'veiculo' && (veiculoId is! int)) {
      return jsonBad({'error': 'veiculo_id é obrigatório quando contexto=veiculo'});
    }

    // Tenta encontrar existente (find-or-create)
    final existing = await conn.execute(
      Sql.named('''
        SELECT id, contexto::text AS contexto, base_id, veiculo_id, nome
          FROM locais_fisicos
         WHERE contexto = @ctx
           AND nome = @nome
           AND (
                 (@ctx='base'   AND base_id=@bid AND veiculo_id IS NULL)
              OR (@ctx='veiculo' AND veiculo_id=@vid AND base_id IS NULL)
           )
         LIMIT 1
      '''),
      parameters: {
        'ctx': contexto,
        'nome': nome,
        'bid': contexto == 'base' ? baseId as int : null,
        'vid': contexto == 'veiculo' ? veiculoId as int : null,
      },
    );

    if (existing.isNotEmpty) {
      final r = existing.first;
      return jsonOk({
        'id': r[0],
        'contexto': r[1],
        'base_id': r[2],
        'veiculo_id': r[3],
        'nome': r[4],
        'already_existed': true,
      });
    }

    // Cria se não existir
    final rows = await conn.execute(
      Sql.named('''
        INSERT INTO locais_fisicos (contexto, base_id, veiculo_id, nome)
        VALUES (@ctx, @bid, @vid, @nome)
        RETURNING id, contexto::text AS contexto, base_id, veiculo_id, nome
      '''),
      parameters: {
        'ctx': contexto,
        'bid': contexto == 'base' ? baseId as int : null,
        'vid': contexto == 'veiculo' ? veiculoId as int : null,
        'nome': nome,
      },
    );

    final r = rows.first;
    return jsonCreated({
      'id': r[0],
      'contexto': r[1],
      'base_id': r[2],
      'veiculo_id': r[3],
      'nome': r[4],
    });
  } on PgException catch (e, st) {
    // Violação de UNIQUE (concorrência): retorna o existente
    if (e.message.contains('23505') == true){
      try {
        final dup = await conn.execute(
          Sql.named('''
            SELECT id, contexto::text AS contexto, base_id, veiculo_id, nome
              FROM locais_fisicos
             WHERE contexto = @ctx
               AND nome = @nome
               AND (
                     (@ctx='base'   AND base_id=@bid AND veiculo_id IS NULL)
                  OR (@ctx='veiculo' AND veiculo_id=@vid AND base_id IS NULL)
               )
             LIMIT 1
          '''),
          parameters: {
            // usamos as MESMAS variáveis lidas no try:
            'ctx': (await readJson(context))['contexto'], // se preferir, remova e guarde em variáveis superiores
            'nome': (await readJson(context))['nome'],
            'bid': (await readJson(context))['base_id'],
            'vid': (await readJson(context))['veiculo_id'],
          },
        );
        if (dup.isNotEmpty) {
          final r = dup.first;
          return Response.json(
            statusCode: 200,
            body: {
              'id': r[0],
              'contexto': r[1],
              'base_id': r[2],
              'veiculo_id': r[3],
              'nome': r[4],
              'already_existed': true,
            },
          );
        }
        // fallback
        return Response.json(statusCode: 409, body: {'error': 'local já existe'});
      } catch (_) {
        return Response.json(statusCode: 409, body: {'error': 'local já existe'});
      }
    }
    print('POST /locais pg error: $e\n$st');
    return jsonServer({'error': 'internal'});
  } catch (e, st) {
    print('POST /locais error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}
