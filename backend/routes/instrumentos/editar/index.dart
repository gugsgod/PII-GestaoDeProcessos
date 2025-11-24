import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405);
  }

  final connection = context.read<Connection>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;

    // O ID continua obrigatório para saber qual linha alterar
    final id = body['id'];
    if (id == null) {
      return Response(
        statusCode: 400,
        body: 'O campo "id" é obrigatório para atualização.',
      );
    }

    final updateClauses = <String>[];
    final parameters = <String, dynamic>{'id': id};

    // --- AQUI ESTÁ A MUDANÇA: Só verificamos descricao e status ---

    if (body.containsKey('descricao')) {
      updateClauses.add('descricao = @descricao');
      parameters['descricao'] = body['descricao'];
    }

    if (body.containsKey('status')) {
      updateClauses.add('status = @status');
      parameters['status'] = body['status'];
    }

    if (updateClauses.isEmpty) {
      return Response(
        statusCode: 400,
        body: 'Nenhum campo válido enviado. Informe "descricao" ou "status".',
      );
    }

    final query =
        'UPDATE instrumentos SET ${updateClauses.join(', ')} WHERE id = @id';

    final result = await connection.execute(
      Sql.named(query),
      parameters: parameters,
    );

    if (result.affectedRows == 0) {
      return Response(
        statusCode: 404,
        body: 'Instrumento com id $id não encontrado.',
      );
    }

    return Response.json(
      body: {'message': 'Instrumento atualizado com sucesso!'},
    );
  } catch (e, st) {
    print('Erro ao atualizar instrumento: $e\n$st');
    return Response(
      statusCode: 500,
      body: 'Erro interno ao atualizar instrumento.',
    );
  }
}

// No front end fazer popup com instrucoes Status com enum : "disponivel, manutencao, inativo"
