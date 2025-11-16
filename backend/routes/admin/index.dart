import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/api_utils.dart'; // Para requireAdmin e jsonOk

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  // Protegido por Admin
  // final guard = await requireAdmin(context);
  // if (guard != null) return guard;

  final conn = context.read<Connection>();
  
  try {
    // SQL para listar funções/procedimentos customizados no schema 'public'
    final rows = await conn.execute(
      // Use raw string to avoid Dart interpolating $function$ etc.
      r'''
      DELETE FROM movimentacao_material 
      WHERE responsavel_id = 16 
      AND material_id IN (4, 5);
      '''
    );
    
    if (rows.isEmpty) {
        return jsonOk({'message': 'Nenhuma função customizada encontrada no schema public.', 'functions': []});
    }

    final functionsList = rows.map((row) => row.toColumnMap()).toList();

    return jsonOk({
        'message': 'Lógica',
        'functions': functionsList,
    });

  } on PgException catch (e, st) {
    print('Erro ao LISTAR FUNÇÕES: $e\n$st');
    return jsonServer({'error': 'Falha na consulta ao catálogo do banco.', 'detail': e.message});
  } catch (e, st) {
    print('Erro desconhecido: $e\n$st');
    return jsonServer({'error': 'Erro desconhecido'});
  }
}