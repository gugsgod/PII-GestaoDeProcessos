import 'package:flutter/material.dart';
import 'package:src/auth/auth_store.dart';
import 'animated_network_background.dart';
import 'package:src/services/auth_api.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPasswordVisible = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _successMessage; // <-- Controla a mensagem de sucesso
  String? _error;

  Future<void> _onEntrar() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null; // <-- Reseta a mensagem de sucesso
    });

    try {
      final email = _emailController.text.trim();
      final senha = _passwordController.text;

      final result = await login(email, senha);

      if (!mounted) return;

      if (result.ok && result.token != null) {
        // --- LÓGICA DE SUCESSO CORRIGIDA (ORDEM INVERTIDA) ---

        // 1. Atualiza o estado para mostrar a mensagem de sucesso
        setState(() {
          _isLoading = false;
          _successMessage = 'Login feito com sucesso!';
        });

        // 2. Espera 2 segundos (o usuário VÊ a mensagem)
        // Usamos um future.delayed aqui, que funciona bem após um setState
        await Future.delayed(const Duration(seconds: 2));

        if (!mounted) return;

        // 3. SÓ AGORA, salva o token (o que pode disparar o listener global)
        final auth = context.read<AuthStore>();
        await auth.setToken(result.token!);

        // 4. Navega (garante a navegação caso o listener não o faça)
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      } else {
        // A API respondeu, mas informou um erro (ex: 401 - Não autorizado)
        setState(() {
          _isLoading = false;
          _error = result.error ?? 'Usuário ou senha inválidos.';
        });
      }
    } catch (e) {
      // A API não foi alcançada (falha de rede, timeout, etc.)
      if (!mounted) return;
      // Log do erro para debug
      print('Falha na conexão durante o login: $e');
      setState(() {
        _isLoading = false;
        _error = 'Falha na conexão. Verifique sua internet e tente novamente.';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // fundo e animação
          Container(color: const Color.fromARGB(255, 0, 14, 92)),
          const AnimatedNetworkBackground(
            numberOfParticles: 170,
            maxDistance: 120.0,
          ),

          // caixa de login
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(217),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 1, 1, 2).withAlpha(102),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // logo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/images/logo_metroSP.png',
                          height: 60,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // campo de login
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Login:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      cursorColor: const Color(0xFF002776),
                      decoration: InputDecoration(
                        hintText: 'Digite seu email...',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(
                            color: Color(0xFF002776),
                            width: 2.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // campo de senha
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Senha:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      cursorColor: const Color(0xFF002776),
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: 'Digite sua senha...',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(
                            color: Color(0xFF002776),
                            width: 2.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    // --- WIDGET DE SUCESSO ADICIONADO ---
                    if (_successMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: TextStyle(
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // --- FIM DO WIDGET DE SUCESSO ---

                    // --- WIDGET DE ERRO ADICIONADO ---
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 24.0), // Espaço acima da msg de erro
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // --- FIM DO WIDGET DE ERRO ---

                    const SizedBox(height: 30),

                    // botao de entrar
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        // A cor agora é estática, não muda mais com o sucesso
                        backgroundColor: const Color(0xFF002776),
                        padding: const EdgeInsets.symmetric(
                          vertical: 17,
                          horizontal: 47,
                        ),
                        overlayColor: Colors.black.withOpacity(0.1),
                      ),
                      // Desabilita se estiver carregando OU se a msg de sucesso estiver visível
                      onPressed: (_isLoading || _successMessage != null)
                          ? null
                          : _onEntrar,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          // Remove a lógica do ícone de check daqui
                          : const Text(
                              'Entrar',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

