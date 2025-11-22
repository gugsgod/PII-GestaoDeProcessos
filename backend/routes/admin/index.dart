import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) return Response(statusCode: 405);
  final conn = context.read<Connection>();
  
  try {
    // Busca a definição da regra problemática
    final result = await conn.execute(
      Sql.named('''
        TRUNCATE TABLE movimentacao_instrumento RESTART IDENTITY;
      ''')
    );

    if (result.isEmpty) return jsonOk({'message': 'Constraint não encontrada.'});

    return jsonOk({'regra_atual': result.first[0]});
  } catch (e) {
    return jsonServer({'error': e.toString()});
  }
}