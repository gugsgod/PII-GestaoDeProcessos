import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  final connection = context.read<Connection>();

  try {
    // Postgres 3.x: execute() retorna um Result que é Iterable<Row>
    final result = await connection.execute(
      'SELECT id_usuario, nome, funcao FROM usuario',
    );

    final usersList = result.map((row) {
      // Acessa por índice (ou row.toColumnMap() se preferir por nome)
      return {
        'id': row[0],
        'nome': row[1],
        'funcao': row[2],
      };
    }).toList();

    return Response.json(body: usersList);
  } catch (e, st) {
    print('Erro na consulta: $e\n$st');
    return Response(statusCode: 500, body: 'Erro ao buscar usuários.');
  }
}
