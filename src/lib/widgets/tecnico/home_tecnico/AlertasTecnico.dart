import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';

// --- Modelo de Dados (Mock) ---
class _Alerta {
  final String titulo;
  final String nomeMaterial;
  final int diasAtraso;

  _Alerta({
    required this.titulo,
    required this.nomeMaterial,
    required this.diasAtraso,
  });

  String get subtitulo => '$nomeMaterial - Atrasado há $diasAtraso dias';
}

// --- O Widget Principal ---
class AlertasTecnico extends StatefulWidget {
  final ScrollController scrollController;
  final bool isDesktop;

  const AlertasTecnico({
    super.key,
    required this.scrollController,
    required this.isDesktop,
  });

  @override
  State<AlertasTecnico> createState() => _AlertasTecnicoState();
}

class _AlertasTecnicoState extends State<AlertasTecnico> {
  static const String _apiHost = 'http://localhost:8080';
  Future<List<_Alerta>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregar();
    });
  }

  void _carregar() {
    final auth = context.read<AuthStore>();
    final token = auth.token;

    if (token == null || !auth.isAuthenticated) {
      setState(() {
        _future = Future.error('Token de autenticação ausente.');
      });
      return;
    }

    setState(() {
      _future = _fetchAlertas(token);
    });
  }

  // (Mockado para fins de UI, de acordo com a imagem)
  Future<List<_Alerta>> _fetchAlertas(String token) async {
    // Simula a chamada de API
    await Future.delayed(const Duration(milliseconds: 1200));

    // Para testar a UI de "lista vazia", retorne []
    return [];

    // Mock
    // return List.generate(
    //   5,
    //   (index) => _Alerta(
    //     titulo: 'Devolução Atrasada',
    //     nomeMaterial: 'Cabo Ethernet Cat6',
    //     diasAtraso: 345,
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Meus alertas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // --- Container da Lista ---
        Container(
          height: 400, // Altura fixa para a lista
          decoration: BoxDecoration(
            color: const Color.fromARGB(209, 255, 255, 255),
            borderRadius: BorderRadius.circular(16),
          ),
          child: FutureBuilder<List<_Alerta>>(
            future: _future,
            builder: (context, snapshot) {
              // 1. Estado de Loading
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _future == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              // 2. Estado de Erro
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Erro ao carregar alertas: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final alertas = snapshot.data ?? [];

              // 3. Estado de Lista Vazia
              if (alertas.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.schedule_outlined,
                          color: Colors.green.shade300,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Tudo em ordem!",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Você não possui nenhum alerta.",
                        style: TextStyle(color: Colors.blueGrey, fontSize: 15),
                      ),
                    ],
                  ),
                );
              }

              // 4. Estado com Dados (A Lista)
              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: alertas.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _AlertaCard(alerta: alertas[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- WIDGET DO CARD DE ALERTA ---
class _AlertaCard extends StatelessWidget {
  final _Alerta alerta;

  const _AlertaCard({required this.alerta});

  @override
  Widget build(BuildContext context) {
    // Cores exatas da imagem (fundo e borda)
    const Color cardColor = Color(0xFFFEE2E2); // Fundo rosa/salmão claro
    const Color borderColor = Color(0xFFFCA5A5); // Borda vermelha clara
    const Color iconColor = Color(0xFFEF4444); // Ícone vermelho
    const Color iconBgColor = Color(0xFFFEE2E2); // Fundo do ícone (igual ao card)
    const Color titleColor = Color(0xFF7F1D1D); // Título vermelho escuro
    const Color subtitleColor = Color(0xFF991B1B); // Subtítulo vermelho escuro

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          // --- Ícone de Alerta ---
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: iconBgColor, // Fundo do ícone
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: iconColor, // Ícone
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // --- Textos ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerta.titulo,
                  style: const TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alerta.subtitulo,
                  style: const TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}