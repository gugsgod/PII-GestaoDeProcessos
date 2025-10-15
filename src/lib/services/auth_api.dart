import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthResult {
  final bool ok;
  final String? token;
  final Map<String, dynamic>? user;
  final String? error;

  AuthResult({required this.ok, this.token, this.user, this.error});
}

const String BASE_URL = 'http://localhost:8080';

Future<AuthResult> login(String email, String senha) async {
  final url = Uri.parse('$BASE_URL/auth/login');

  try {
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'senha': senha}),
    );

    final body = utf8.decode(res.bodyBytes);
    final decoded = jsonDecode(body);

    if (decoded is! Map) {
      return AuthResult(ok: false, error: 'Resposta inesperada do servidor.');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode == 200 && (data['ok'] == true)) {
      return AuthResult(
        ok: true,
        token: data['token'] as String?,
        user: data['user'] as Map<String, dynamic>?,
      );
    } else {
      print('LOGIN FAIL: ${res.statusCode} $body');
    }

    return AuthResult(
      ok: false,
      error: (data['error'] ?? 'Falha no login') as String,
    );
  } catch (e) {
    return AuthResult(ok: false, error: 'Erro de rede: $e');
  }
}
