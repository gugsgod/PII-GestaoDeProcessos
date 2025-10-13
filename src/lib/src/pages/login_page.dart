import 'package:flutter/material.dart';
import 'animated_network_background.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // efeito azul do fundo
          Container(color: const Color.fromARGB(255, 0, 14, 92)),
          const AnimatedNetworkBackground(),
          // caixa de login
          Center(
            child: Container(
              width: 600,
              height: 500,
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
                children: [
                  // logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Image.asset('assets/images/logo_metroSP.png', height: 60),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Spacer(),

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
                    obscureText: false,
                    cursorColor: const Color(0xFF002776),
                    decoration: InputDecoration(
                      hintText: 'Digite seu email...',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Color(0xFF002776), width: 2.0), // Cor azul e mais grossa
                        ),
                      contentPadding: EdgeInsets.symmetric(
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
                    obscureText: true,
                    cursorColor: const Color(0xFF002776),
                    decoration: InputDecoration(
                      hintText: 'Digite sua senha...',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Color(0xFF002776), width: 2.0), // Cor azul e mais grossa
                        ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Spacer(),

                  // botao de entrar
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002776),
                      padding: const EdgeInsets.symmetric(
                        vertical: 17,
                        horizontal: 47,
                      ),
                      overlayColor: Colors.black.withOpacity(0.3),
                    ),
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/admin');
                    },
                    child: const Text(
                      'Entrar',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
