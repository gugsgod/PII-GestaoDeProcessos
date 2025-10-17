import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

const int _SAP_MIN = 15000000;
const int _SAP_MAX = 15999999;
bool _isValidSap(int v) => v >= _SAP_MIN && v <= _SAP_MAX;

Future<Response> onRequest(RequestContext context, String idStr) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _get(context, idStr);
    case HttpMethod.patch:
      final guard = await requireAdmin(context);
      if (guard != null) return guard;
      return _patch(context, idStr);
    // Se quiser hard delete, mantenha admin only:
    // case HttpMethod.delete:
    //   final g2 = await requireAdmin(context);
    //   if (g2 != null) return g2;
    //   return _delete(context, idStr);
    default:
      return Response(statusCode: 405);
  }
}

Future<Response> _get(RequestContext context, String idStr) async {
  final conn = context.read<Connection>();
  final id = int.tryParse(idStr);
  if (id == null) return jsonBad({'error': 'id inválido'});

  final rows = await conn.execute(
    Sql.named('''
      SELECT id, cod_sap, descricao, apelido, categoria, unidade, ativo
        FROM materiais
       WHERE id=@id
    '''), parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonNotFound('material não encontrado');

  final r = rows.first;
  return jsonOk({
    'id'       : r[0],
    'cod_sap'  : r[1],
    'descricao': r[2],
    'apelido'  : r[3],
    'categoria': r[4],
    'unidade'  : r[5],
    'ativo'    : r[6],
  });
}

Future<Response> _patch(RequestContext context, String idStr) async {
  final conn = context.read<Connection>();
  final id = int.tryParse(idStr);
  if (id == null) return jsonBad({'error': 'id inválido'});

  try {
    final body = await readJson(context);

    final codSap = body['cod_sap'];
    if (codSap != null) {
      if (codSap is! int) return jsonBad({'error': 'cod_sap deve ser int'});
      if (!_isValidSap(codSap)) {
        return jsonUnprocessable({'error': 'cod_sap fora do range SAP 15000000–15999999'});
      }
    }

    final rows = await conn.execute(
      Sql.named('''
        UPDATE materiais
           SET cod_sap  = COALESCE(@cod_sap, cod_sap),
               descricao= COALESCE(@descricao, descricao),
               apelido  = COALESCE(@apelido, apelido),
               categoria= COALESCE(@categoria, categoria),
               unidade  = COALESCE(@unidade, unidade),
               ativo    = COALESCE(@ativo, ativo),
               updated_at = now()
         WHERE id = @id
     RETURNING id, cod_sap, descricao, apelido, categoria, unidade, ativo
      '''), parameters: {
        'id': id,
        'cod_sap': codSap,
        'descricao': (body['descricao'] as String?),
        'apelido':   (body['apelido'] as String?),
        'categoria': (body['categoria'] as String?),
        'unidade':   (body['unidade'] as String?),
        'ativo':     (body['ativo'] as bool?),
      },
    );

    if (rows.isEmpty) return jsonNotFound('material não encontrado');
    final r = rows.first;
    return jsonOk({
      'id'       : r[0],
      'cod_sap'  : r[1],
      'descricao': r[2],
      'apelido'  : r[3],
      'categoria': r[4],
      'unidade'  : r[5],
      'ativo'    : r[6],
    });
  } on PgException catch (e, st) {
    if (e.message.contains('23505') == true) {
      return jsonServer({'error': 'cod_sap já existente'});
    }
    print('PATCH /materiais/$id pg error: $e\n$st');
    return jsonServer({'error': 'internal'});
  } catch (e, st) {
    print('PATCH /materiais/$id error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}

// Opcional: transformar DELETE em desativação
// Future<Response> _delete(RequestContext context, String idStr) async {
//   final conn = context.read<Connection>();
//   final id = int.tryParse(idStr);
//   if (id == null) return jsonBad({'error': 'id inválido'});
//
//   final rows = await conn.execute(
//     Sql.named('UPDATE materiais SET ativo=false, updated_at=now() WHERE id=@id RETURNING id'),
//     parameters: {'id': id},
//   );
//   if (rows.isEmpty) return jsonNotFound('material não encontrado');
//   return jsonOk({'ok': true});
// }
