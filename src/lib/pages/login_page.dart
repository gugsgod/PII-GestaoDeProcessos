import 'package:flutter/material.dart';
import 'animated_network_background.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPasswordVisible = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Variável de estado para controlar o loading
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  // Função principal para a chamada de login
  Future<void> _fazerLogin() async {
    // Não faz nada se já estiver carregando
    if (_isLoading) return;

    // Mostra o indicador de loading e desabilita o botão
    setState(() {
      _isLoading = true;
    });

    // URL do back
    final url = Uri.parse('https://sua-api.com/login'); 

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json', 
        },
        body: json.encode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      // Esconde o indicador de loading
      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {   
        // Navega para a tela de admin
        Navigator.pushReplacementNamed(context, '/admin');

      } else {
        _mostrarErro('Email ou senha inválidos.');
      }

    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _mostrarErro('Não foi possível conectar ao servidor. Verifique sua internet.');
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.redAccent,
      ),
    );
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
                constraints: const BoxConstraints(
                  maxWidth: 500, 
                ),
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
                        Image.asset('assets/images/logo_metroSP.png', height: 60),
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
                  const SizedBox(height: 30),

                  // botao de entrar
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF002776),
                        padding: const EdgeInsets.symmetric(
                          vertical: 17,
                          horizontal: 47,
                        ),
                        overlayColor: Colors.black.withOpacity(0.1),
                      ),
                      onPressed: _fazerLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Entrar',
                              style: TextStyle(fontSize: 16, color: Colors.white),
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