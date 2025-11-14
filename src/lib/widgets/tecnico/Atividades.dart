import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  bool get isAtrasado => dataDevolucao.isBefore(DateTime.now());
  bool get isInstrumento => idMaterial.startsWith('INST');

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
            Icon(Icons.schedule_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Minhas atividades',
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
            color: const Color.fromARGB(209, 255, 255, 255),
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
                // TODO: UI quando nenhuma atividade for encontrada
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.schedule_outlined,
                          color: Colors.green.shade300,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Tudo em ordem!",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Você não possui instrumentos ou materiais em uso no momento.",
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // TODO: Construir a lista de atividades recentes
              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: atividades.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _AtividadeCard(atividade:  atividades[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AtividadeCard extends StatelessWidget {
  final _Atividade atividade;

  const _AtividadeCard({required this.atividade});

  // Formata a data para o padrão "dd/MM/yyyy 'às' HH:mm"
  String _formatarData(DateTime data) {
    return DateFormat('dd/MM/yyyy \'às\' HH:mm').format(data);
  }

  @override
  Widget build(BuildContext context) {
    final bool isAtrasado = atividade.isAtrasado;
    final bool isInstrumento = atividade.isInstrumento;
    final String buttonText =
        isInstrumento ? 'Devolver Instrumento' : 'Devolver Material';
    
    // Define a cor do card (vermelho se atrasado)
    final Color cardColor = isAtrasado
        ? Colors.red.withOpacity(0.08)
        : Colors.white.withOpacity(0.1);
    
    // Define a cor da borda (vermelha se atrasado)
    final Color borderColor = isAtrasado
        ? Colors.red.shade400.withOpacity(0.7)
        : Colors.transparent;
        
    // Define a cor do texto de devolução (vermelho se atrasado)
    final Color devolucaoColor = isAtrasado
        ? Colors.red.shade300
        : Colors.white70;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5), // Borda
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Linha 1: Título e Tags ---
          Row(
            children: [
              Text(
                atividade.nomeMaterial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              _TagChip(
                label: atividade.idMaterial,
                backgroundColor: Colors.white.withOpacity(0.2),
                textColor: Colors.white,
              ),
              const Spacer(),
              if (isAtrasado)
                const _TagChip(
                  label: "Atrasado",
                  backgroundColor: Color(0xFFFEE2E2), // Fundo do chip "Atrasado"
                  textColor: Color(0xFFB91C1C), // Texto do chip "Atrasado"
                ),
            ],
          ),
          const SizedBox(height: 16),
          // --- Linha 2: Destino ---
          _InfoLinha(
            icon: Icons.location_on_outlined,
            title: "Destino:",
            value: atividade.localizacao,
            valueColor: Colors.white, // Cor do valor
          ),
          const SizedBox(height: 8),
          // --- Linha 3: Retirado em ---
          _InfoLinha(
            icon: Icons.calendar_today_outlined,
            title: "Retirado em:",
            value: _formatarData(atividade.dataRetirada),
          ),
          const SizedBox(height: 8),
          // --- Linha 4: Previsão de Devolução ---
          _InfoLinha(
            icon: Icons.schedule,
            title: "Previsão de devolução:",
            value: _formatarData(atividade.dataDevolucao),
            iconColor: devolucaoColor, // Icone fica vermelho
            valueColor: devolucaoColor, // Texto fica vermelho
          ),
          const SizedBox(height: 16),
          // --- Linha 5: Botão Devolver ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Implementar lógica de devolução
              },
              icon: const Icon(Icons.arrow_downward, size: 16),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600, // Fundo verde
                foregroundColor: Colors.white, // Texto branco
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// --- WIDGET HELPER PARA AS TAGS (MAT001, Atrasado) ---
class _TagChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _TagChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

// --- WIDGET HELPER PARA AS LINHAS DE INFO (Icon + Título + Valor) ---
class _InfoLinha extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;
  final Color? valueColor;

  const _InfoLinha({
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    const Color defaultColor = Colors.white70; // Cor padrão
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor ?? defaultColor, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(color: defaultColor),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? defaultColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}