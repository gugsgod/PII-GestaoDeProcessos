import 'dart:async'; // Importado para TimeoutException
import 'dart:convert';
import 'dart:io'; // Importado para SocketException
import 'package:http/http.dart' as http;

const String BASE_URL = 'http://localhost:8080'; // ajuste se precisar

Future<List<Map<String, dynamic>>> fetchInstrumentos(String token) async {
  final uri = Uri.parse('$BASE_URL/instrumentos');

  // Adicionado Try/Catch para lidar com falhas de rede (servidor offline)
  try {
    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
      },
      // Adiciona um timeout de 5 segundos
    ).timeout(const Duration(seconds: 5));


    final body = utf8.decode(res.bodyBytes);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      throw Exception('Resposta inesperada do servidor.');
    }

    if (res.statusCode == 401) {
      throw Exception('Token de acesso inválido ou ausente');
    }

    throw Exception('Erro ${res.statusCode}: $body');

  } on TimeoutException {
    // Servidor demorou demais
    throw Exception('Servidor não respondeu a tempo (Timeout).');
  } on SocketException {
    // Servidor offline ou sem rede (ex: "Connection refused")
    throw Exception('Falha ao conectar. Verifique a rede ou o servidor.');
  } on http.ClientException catch (e) {
     // Outros erros de cliente HTTP
    throw Exception('Erro de conexão: ${e.message}');
  } catch (e) {
    // Pega qualquer outro erro e repassa
    throw Exception('Erro desconhecido ao buscar instrumentos: ${e.toString()}');
  }
}