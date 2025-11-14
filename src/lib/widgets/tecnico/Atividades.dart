import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';

class _Atividade {
  final String nomeMaterial;
  final String idMaterial;
  final bool status;
  final String localizacao;
  final DateTime dataRetirada;
  final DateTime dataDevolucao;

  _Atividade({
    required this.nomeMaterial,
    required this.idMaterial,
    required this.status,
    required this.localizacao,
    required this.dataRetirada,
    required this.dataDevolucao,
  });

  factory _Atividade.fromJson(Map<String, dynamic> json) {
    return _Atividade(
      nomeMaterial: json['nomeMaterial'],
      idMaterial: json['idMaterial'],
      status: json['status'],
      localizacao: json['localizacao'],
      dataRetirada: DateTime.parse(json['dataRetirada']),
      dataDevolucao: DateTime.parse(json['dataDevolucao']),
    );
  }
}

class AtividadesRecentes extends StatefulWidget {
  final ScrollController scrollController;
  final bool isDesktop;

  const AtividadesRecentes({
    super.key,
    required this.scrollController,
    required this.isDesktop,
  });

  @override
  State<AtividadesRecentes> createState() => _AtividadesRecentesState();
}

class _AtividadesRecentesState extends State<AtividadesRecentes> {
  static const String _apiHost = 'http://localhost:8080';

  Future<List<_Atividade>>? _future;

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
        _future = Future.error(
          'missing/invalid token (faça login novamente para ver as movimentações).',
        );
      });
      return;
    }

    setState(() {
      _future = _fetchRecent(token);
    });
  }

  Future<List<_Atividade>> _fetchRecent(String token) async {
    // TODO: Implementar chamada à API para buscar atividades recentes
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.timer, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Atividades Recentes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: FutureBuilder<List<_Atividade>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _future == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Erro ao carregar atividades: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final atividades = snapshot.data ?? [];

              if (atividades.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma atividade recente encontrada.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                );
              }

              return ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbColor: MaterialStateProperty.all(
                    Colors.white.withOpacity(0.3),
                  ),
                  mainAxisMargin: 16.0,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Scrollbar(
                    controller: widget.scrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: widget.scrollController,
                      itemCount: atividades.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final atividade = atividades[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            atividade.nomeMaterial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'ID: ${atividade.idMaterial}\n'
                            'Localização: ${atividade.localizacao}\n'
                            'Retirada: ${atividade.dataRetirada.toLocal().toString().split(' ')[0]}\n'
                            'Devolução: ${atividade.dataDevolucao.toLocal().toString().split(' ')[0]}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Icon(
                            atividade.status
                                ? Icons.check_circle
                                : Icons.pending,
                            color:
                                atividade.status ? Colors.green : Colors.orange,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
