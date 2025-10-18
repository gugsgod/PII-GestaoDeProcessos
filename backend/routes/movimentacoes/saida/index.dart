import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

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

  final guard = await requireAdmin(context);
  if (guard != null) return guard;

  final uid = _userIdFromContext(context);
  if (uid == null) return jsonUnauthorized('token inválido');

  final conn = context.read<Connection>();

  try {
    final body = await readJson(context);
    final materialId = body['material_id'];
    final origemLocalId = body['local_id']; // origem
    final lote = (body['lote'] as String?)?.trim();
    final quantidade = body['quantidade'];
    final observacao = (body['observacao'] as String?)?.trim();
    final finalidade = (body['finalidade'] as String?)?.trim();

    if (materialId is! int) throw _BadRequest('material_id obrigatório');
    if (origemLocalId is! int) throw _BadRequest('local_id obrigatório');
    if (quantidade is! num || quantidade <= 0) {
      throw _BadRequest('quantidade deve ser > 0');
    }

    // valida material/local
    final m = await conn.execute(
      Sql.named('SELECT 1 FROM materiais WHERE id=@id'),
      parameters: {'id': materialId},
    );
    if (m.isEmpty) throw _BadRequest('material não encontrado');

    final l = await conn.execute(
      Sql.named('SELECT 1 FROM locais_fisicos WHERE id=@id'),
      parameters: {'id': origemLocalId},
    );
    if (l.isEmpty) throw _NotFound('local não encontrado');

    // Apenas insere; trigger valida/aplica débito no saldo
    final ins = await conn.execute(
      Sql.named('''
        INSERT INTO movimentacao_material
          (operacao, material_id, origem_local_id, destino_local_id, lote, quantidade, finalidade, responsavel_id, observacao)
        VALUES
          ('saida', @mid, @origem, NULL, @lote, @qtd, @fin, @uid, @obs)
        RETURNING id, created_at
      '''),
      parameters: {
        'mid': materialId,
        'origem': origemLocalId,
        'lote': (lote?.isEmpty ?? true) ? null : lote,
        'qtd': quantidade,
        'fin': (finalidade?.isEmpty ?? true) ? null : finalidade,
        'uid': uid,
        'obs': (observacao?.isEmpty ?? true) ? null : observacao,
      },
    );

// opcional: saldo após trigger (na origem)
    Result saldo;
    if (lote == null || lote.isEmpty) {
      saldo = await conn.execute(
        Sql.named('''
      SELECT id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
        FROM estoque_saldos
       WHERE material_id=@mid AND local_id=@lid AND lote IS NULL
       LIMIT 1
    '''),
        parameters: {'mid': materialId, 'lid': origemLocalId},
      );
    } else {
      saldo = await conn.execute(
        Sql.named('''
      SELECT id, lote, qt_disp::float8 AS qt_disp, minimo::float8 AS minimo
        FROM estoque_saldos
       WHERE material_id=@mid AND local_id=@lid AND lote = @lote
       LIMIT 1
    '''),
        parameters: {'mid': materialId, 'lid': origemLocalId, 'lote': lote},
      );
    }

    final s = saldo.isNotEmpty ? saldo.first : null;

    return jsonOk({
      'mov_id': ins.first[0],
      'saldo_origem': s == null
          ? null
          : {
              'saldo_id': s[0],
              'lote': s[1],
              'qt_disp': s[2],
              'minimo': s[3],
            }
    });
  } on _BadRequest catch (e) {
    return jsonBad({'error': e.message});
  } on _NotFound catch (e) {
    return jsonNotFound(e.message);
  } on PgException catch (e, st) {
    print('POST /movimentacoes/saida pg error: $e\n$st');
    return jsonServer({'error': 'internal', 'detail': e.message});
  } catch (e, st) {
    print('POST /movimentacoes/saida error: $e\n$st');
    return jsonServer({'error': 'internal'});
  }
}
