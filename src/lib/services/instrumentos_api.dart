import 'dart:convert';
import 'package:http/http.dart' as http;

const String BASE_URL = 'http://localhost:8080'; // ajuste se precisar

Future<List<Map<String, dynamic>>> fetchInstrumentos(String token) async {
  final uri = Uri.parse('$BASE_URL/instrumentos');

  final res = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  final body = utf8.decode(res.bodyBytes);

  if (res.statusCode == 200) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    throw Exception('Resposta inesperada do servidor.');
  }

  if (res.statusCode == 401) {
    throw Exception('missing/invalid token');
  }

  throw Exception('Erro ${res.statusCode}: $body');
}
