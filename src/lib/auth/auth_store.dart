import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStore {
  String? _token;
  Map<String, dynamic>? _claims;

  String? get token => _token;
  Map<String, dynamic>? get claims => _claims;

  String? get name => _claims?['name'] as String?;
  String? get role => _claims?['role'] as String?;
  String? get email => _claims?['email'] as String?;

  // sub pode ser int ou String dependendo do backend
  int? get userId {
    final sub = _claims?['sub'];
    if (sub is int) return sub;
    if (sub is String) return int.tryParse(sub);
    return null;
  }

  /// Carrega token do storage e popula claims (se não expirou).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('auth_token');

    if (t != null && t.isNotEmpty && !JwtDecoder.isExpired(t)) {
      _token = t;
      _claims = JwtDecoder.decode(t);
    } else {
      _token = null;
      _claims = null;
    }
  }

  /// Salva token recém-recebido do backend e popula claims.
  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    _token = token;
    _claims = JwtDecoder.decode(token);
  }

  /// Limpa tudo.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _token = null;
    _claims = null;
  }

  bool get isAuthenticated =>
      _token != null && _claims != null && !JwtDecoder.isExpired(_token!);
}
