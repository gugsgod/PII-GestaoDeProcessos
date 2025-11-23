import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    };

    try {
      // Executa as duas chamadas em paralelo para ser mais rápido
      final responses = await Future.wait([
        // 1. Busca Calibrações Vencidas
        http.get(
          Uri.parse('$_apiHost/instrumentos/catalogo').replace(queryParameters: {'vencidos': 'true', 'ativo': 'true'}),
          headers: headers
        ).timeout(const Duration(seconds: 5)),

        // 2. Busca Pendências (Para checar atraso na devolução)
        http.get(
          Uri.parse('$_apiHost/movimentacoes/pendentes'),
          headers: headers
        ).timeout(const Duration(seconds: 5)),
      ]);

      final calibracaoResponse = responses[0];
      final pendenciasResponse = responses[1];

      final List<_Alerta> alertas = [];
      final agora = DateTime.now();

      // --- Processa Calibração ---
      if (calibracaoResponse.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(calibracaoResponse.bodyBytes));
        for (var jsonItem in data) {
          final dataVencimentoStr = jsonItem['proxima_calibracao_em'];
          if (dataVencimentoStr != null) {
            final dataVencimento = DateTime.tryParse(dataVencimentoStr);
            if (dataVencimento != null && dataVencimento.isBefore(agora)) {
              alertas.add(_Alerta(
                titulo: 'Calibração Vencida',
                nomeMaterial: jsonItem['descricao'] ?? 'Instrumento',
                diasAtraso: agora.difference(dataVencimento).inDays,
              ));
            }
          }
        }
      } else {
        throw Exception('Erro ${calibracaoResponse.statusCode}: Falha ao buscar calibrações.');
      }

      // --- Processa Devoluções Atrasadas ---
      if (pendenciasResponse.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(pendenciasResponse.bodyBytes));
        
        for (var jsonItem in data) {
          final previsaoStr = jsonItem['dataDevolucao'];
          if (previsaoStr != null) {
            final previsao = DateTime.tryParse(previsaoStr);
            // Se a data de previsão for ANTERIOR a agora, está atrasado
            if (previsao != null && previsao.isBefore(agora)) {
              final nome = jsonItem['nomeMaterial'] ?? 'Item desconhecido';
              final tipo = (jsonItem['idMaterial'] as String?)?.startsWith('MAT') == true ? 'Material' : 'Instrumento';
              
              alertas.add(_Alerta(
                titulo: 'Devolução Atrasada',
                nomeMaterial: nome,
                diasAtraso: agora.difference(previsao).inDays,
              ));
            }
          }
        }
      } else {
        throw Exception('Erro ${pendenciasResponse.statusCode}: Falha ao buscar pendências.');
      }

      // Ordena: Mais atrasados primeiro
      alertas.sort((a, b) => b.diasAtraso.compareTo(a.diasAtraso));

      return alertas;

    } on TimeoutException {
      throw Exception('Tempo esgotado. Verifique sua conexão.');
    } on SocketException {
      throw Exception('Sem conexão com o servidor.');
    } on http.ClientException catch (e) {
      throw Exception('Erro de rede: ${e.message}');
    } catch (e) {
      throw Exception('Erro desconhecido: $e');
    }
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
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                        const SizedBox(height: 16),
                        Text(
                          snapshot.error.toString().replaceAll("Exception: ", ""),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _carregar, // Botão de Tentar Novamente
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white
                          ),
                          child: const Text("Tentar Novamente"),
                        )
                      ],
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
    const Color cardColor = Color(0xFFFEE2E2);
    const Color borderColor = Color(0xFFFCA5A5); 
    const Color iconColor = Color(0xFFEF4444); 
    const Color iconBgColor = Color(0xFFFEE2E2); 
    const Color titleColor = Color(0xFF7F1D1D); 
    const Color subtitleColor = Color(0xFF991B1B); 

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