import 'package:backend/api_utils.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/expect.dart'; // NECESSÁRIO PARA JWT

const int _SAP_MIN = 15000000;
const int _SAP_MAX = 15999999;

bool _isValidSap(int v) => v >= _SAP_MIN && v <= _SAP_MAX;

// FUNÇÃO _userIdFromContext (ADICIONADA)
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
  switch (context.request.method) {
    case HttpMethod.get:
      return _list(context);
    case HttpMethod.post:
      final guard = await requireAdmin(context);
      if (guard != null) return guard;
      return _create(context);
    case HttpMethod.patch:
      final guard = await requireAdmin(context);
      if (guard != null) return guard;
      return _patch(context);
    case HttpMethod.delete:
      final guard2 = await requireAdmin(context);
      if (guard2 != null) return guard2;
      return _delete(context);
    default:
      return Response(statusCode: 405);
  }
}

Future<Response> _list(RequestContext context) async {
  final conn = context.read<Connection>();
  final qp = context.request.uri.queryParameters;
  final pg = readPagination(context.request);

  final q = qp['q']?.trim(); // busca em descricao/apelido
  final categoria = qp['categoria']?.trim();
  final ativoStr = qp['ativo']?.trim();
  final codSap = int.tryParse(qp['cod_sap'] ?? '');
  final codPrefix = qp['cod_prefix']?.trim(); // opcional: prefixo (ex: "1500")

  final where = <String>[];
  final params = <String, Object?>{};

  // sempre garantir range SAP
  where.add('cod_sap BETWEEN $_SAP_MIN AND $_SAP_MAX');

  if (q != null && q.isNotEmpty) {
    where.add('(descricao ILIKE @q OR apelido ILIKE @q)');
    params['q'] = '%$q%';
  }
  if (categoria != null && categoria.isNotEmpty) {
    where.add('categoria ILIKE @categoria');
    params['categoria'] = '%$categoria%';
  }
  if (ativoStr != null) {
    final ativo =
        (ativoStr == 'true') ? true : (ativoStr == 'false' ? false : null);
    if (ativo != null) {
      where.add('ativo = @ativo');
      params['ativo'] = ativo;
    }
  }
  if (codSap != null) {
    where.add('cod_sap = @cod_sap');
    params['cod_sap'] = codSap;
  } else if (codPrefix != null && codPrefix.isNotEmpty) {
    // prefixo por LIKE (ex.: 1500%)
    where.add('cod_sap::text LIKE @cod_prefix');
    params['cod_prefix'] = '$codPrefix%';
  }

  final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

  try {
    final totalRows = await conn.execute(
      Sql.named('SELECT COUNT(*) FROM materiais $whereSql'),
      parameters: params,
    );
    final total = totalRows.first[0] as int;

    final rows = await conn.execute(
      Sql.named('''
        SELECT id, cod_sap, descricao, apelido, categoria, unidade, ativo
          FROM materiais
          $whereSql
         ORDER BY cod_sap
         LIMIT @limit OFFSET @offset
      '''),
      parameters: {...params, 'limit': pg.limit, 'offset': pg.offset},
    );

    final data = rows
        .map((r) => {
              'id': r[0],
              'cod_sap': r[1],
              'descricao': r[2],
              'apelido': r[3],
              'categoria': r[4],
              'unidade': r[5],
              'ativo': r[6],
            })
        .toList();

    return jsonOk(
        {'page': pg.page, 'limit': pg.limit, 'total': total, 'data': data});
  } catch (e, st) {
    print('GET /materiais error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

Future<Response> _create(RequestContext context) async {
  final connection = context.read<Connection>();
  // O PROBLEMA FOI CORRIGIDO AQUI
  final uid = _userIdFromContext(context);
  if (uid == null) return jsonUnauthorized('Usuário não autenticado ou inválido.');

  try {
    final body = await readJson(context);
    final codSap = body['cod_sap'] as int?;
    final descricao = (body['descricao'] as String?)?.trim();
    final apelido = (body['apelido'] as String?)?.trim();
    final categoria = (body['categoria'] as String?)?.trim();
    final unidade = (body['unidade'] as String?)?.trim();
    final ativo = body['ativo'] as bool? ?? true;

    // NOVOS PARÂMETROS
    final quantidadeInicial = body['quantidade_inicial']; // num (int/double)
    final localId = body['local_id'] as int?;
    final lote = (body['lote'] as String?)?.trim();

    // Validação Básica (Antiga)
    if (codSap == null || !_isValidSap(codSap)) {
      return jsonBad({'error': 'cod_sap inválido (fora do range permitido)'});
    }
    if (descricao == null || descricao.isEmpty) {
      return jsonBad({'error': 'descricao é obrigatória'});
    }
    
    // NOVA VALIDAÇÃO
    if (quantidadeInicial is! num || quantidadeInicial <= 0) {
      return jsonBad({'error': 'quantidade_inicial deve ser um número positivo.'});
    }
    if (localId == null) {
      return jsonBad({'error': 'local_id é obrigatório para entrada inicial de estoque.'});
    }

    // ==========================================================
    // ===== INICIA A TRANSAÇÃO =================================
    // ==========================================================
    final materialResult = await connection.runTx((tx) async {
      // 1. CRIA O NOVO MATERIAL
      final matResult = await tx.execute(
        Sql.named('''
          INSERT INTO materiais (cod_sap, descricao, apelido, categoria, unidade, ativo)
          VALUES (@codSap, @descricao, @apelido, @categoria, @unidade, @ativo)
          RETURNING id, cod_sap, descricao, apelido, categoria, unidade, ativo
        '''),
        parameters: {
          'codSap': codSap,
          'descricao': descricao,
          'apelido': apelido,
          'categoria': categoria,
          'unidade': unidade,
          'ativo': ativo,
        },
      );
      
      if (matResult.isEmpty) {
        throw PgException('Erro desconhecido ao inserir material');
      }
      final materialId = matResult.first[0] as int; 
      
      // 2. CRIA A ENTRADA DE ESTOQUE INICIAL (MOVIMENTAÇÃO)
      // Operação 'entrada' usa destino_local_id
      await tx.execute(
        Sql.named('''
          INSERT INTO movimentacao_material 
            (operacao, material_id, destino_local_id, responsavel_id, lote, quantidade)
          VALUES 
            ('entrada', @materialId, @localId, @uid, @lote, @quantidadeInicial)
          RETURNING id
        '''),
        parameters: {
          'materialId': materialId,
          'localId': localId,
          'uid': uid,
          'lote': (lote?.isEmpty ?? true) ? null : lote, // Garante que lote vazio é NULL
          'quantidadeInicial': quantidadeInicial,
        },
      );
      
      // 3. ATUALIZA/CRIA O SALDO (UPSERT)
      final finalLote = (lote?.isEmpty ?? true) ? null : lote;

      // Tenta atualizar o saldo existente
      final up = await tx.execute(
        Sql.named('''
          UPDATE estoque_saldos
             SET qt_disp = qt_disp + @qtd
           WHERE material_id=@mid AND local_id=@lid AND lote=@lote
       RETURNING id
        '''),
        parameters: {
          'mid': materialId, 
          'lid': localId, 
          'lote': finalLote, 
          'qtd': quantidadeInicial
        },
      );
      
      // Se não atualizou, insere um novo saldo
      if (up.isEmpty) {
        await tx.execute(
          Sql.named('''
            INSERT INTO estoque_saldos (material_id, local_id, lote, qt_disp, minimo)
            VALUES (@mid, @lid, @lote, @qtd, 0)
            RETURNING id
          '''),
          parameters: {
            'mid': materialId, 
            'lid': localId, 
            'lote': finalLote, 
            'qtd': quantidadeInicial
          },
        );
      }
      
      // Retorna os dados do material criado no final da transação
      return matResult.first.toColumnMap();
    });

    // Se a transação for bem-sucedida, retorna 201 Created
    return Response.json(
      statusCode: 201, 
      body: materialResult,
    );

  } on PgException catch (e) {
    print('POST /materiais pg error: $e');
    // if (e.code == '23505') { // Código de violação de chave única
    //    return jsonBad({'error': 'Código SAP já cadastrado.'});
    // }
    // Para qualquer outro erro de banco que a transação não tratou (ex: foreign key)
    return jsonServer({'error': 'Erro no banco de dados. Verifique o local_id e outros campos.'});
  } catch (e, st) {
    print('POST /materiais error: $e\n$st');
    return jsonServer({'error': 'Erro interno ao criar material.'});
  }
}

Future<Response> _patch(RequestContext context) async {
  final connection = context.read<Connection>();
  
  try {
    final body = await readJson(context);
    
    // O ID (interno do banco) é obrigatório para saber quem editar
    final id = body['id'] as int?; 
    if (id == null) {
      return jsonBad({'error': 'ID do material é obrigatório.'});
    }

    // Campos atualizáveis
    final codSap = body['cod_sap'] as int?;
    final descricao = (body['descricao'] as String?)?.trim();
    final apelido = (body['apelido'] as String?)?.trim();
    final categoria = (body['categoria'] as String?)?.trim();
    final unidade = (body['unidade'] as String?)?.trim();
    final ativo = body['ativo'] as bool?; // Pode reativar/desativar

    // Validações básicas se os campos forem enviados
    if (codSap != null && !_isValidSap(codSap)) {
      return jsonBad({'error': 'cod_sap inválido.'});
    }
    if (descricao != null && descricao.isEmpty) {
      return jsonBad({'error': 'Descrição não pode ser vazia.'});
    }

    // Query dinâmica (só atualiza o que foi enviado)
    // Monta a lista de SETs
    final sets = <String>[];
    final params = <String, dynamic>{'id': id};

    if (codSap != null) { sets.add('cod_sap = @codSap'); params['codSap'] = codSap; }
    if (descricao != null) { sets.add('descricao = @descricao'); params['descricao'] = descricao; }
    if (apelido != null) { sets.add('apelido = @apelido'); params['apelido'] = apelido; }
    if (categoria != null) { sets.add('categoria = @categoria'); params['categoria'] = categoria; }
    if (unidade != null) { sets.add('unidade = @unidade'); params['unidade'] = unidade; }
    if (ativo != null) { sets.add('ativo = @ativo'); params['ativo'] = ativo; }

    if (sets.isEmpty) {
      return jsonOk({'message': 'Nada a atualizar.'});
    }

    final result = await connection.execute(
      Sql.named('''
        UPDATE materiais
        SET ${sets.join(', ')}
        WHERE id = @id
        RETURNING id, descricao
      '''),
      parameters: params,
    );

    if (result.isEmpty) {
      return jsonNotFound('Material não encontrado.');
    }

    return jsonOk({'message': 'Material atualizado com sucesso.'});

  } on PgException catch (e) {
    // if (e.code == '23505') { // Unique violation (cod_sap duplicado)
    //    return jsonBad({'error': 'Código SAP já existe em outro material.'});
    // }
    return jsonServer({'error': 'Erro no banco de dados', 'detail': e.message});
  } catch (e) {
    return jsonServer({'error': 'Erro interno: $e'});
  }
}

Future<Response> _delete(RequestContext context) async {
  final connection = context.read<Connection>();

  Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (e) {
    return Response(statusCode: 400, body: 'Corpo JSON inválido.');
  }

  final cod_sap = body['cod_sap'] as int?;

  if (cod_sap == null) {
    return Response(
      statusCode: 400, body: 'O campo sap_cod (str) é obrigatório no corpo');
  }

  try {
    final result = await connection.execute(
      Sql.named("UPDATE materiais SET ativo = false WHERE cod_sap = @cod_sap"),
      parameters: {'cod_sap': cod_sap},
    );

    if (result.affectedRows == 0) {
      return Response(
          statusCode: 404,
          body: 'Material com sap_cod $cod_sap não encontrado.');
    }

    return Response(statusCode: 204);
  } on PgException catch (e) {
    print('Erro no banco de dados ao deletar: $e');
    return Response(
        statusCode: 500, body: 'Erro no banco de dados: ${e.message}');
  } catch (e, st) {
    print('Erro inesperado ao deletar: $e\n$st');
    return Response(
        statusCode: 500, body: 'Erro interno ao deletar instrumento.');
  }
}