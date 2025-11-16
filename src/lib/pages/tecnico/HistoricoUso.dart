import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:src/pages/admin/animated_network_background.dart';
import 'package:src/widgets/tecnico/home_tecnico/tecnico_drawer.dart';

class _HistoricoItem {
  final String idMovimentacao;
  final String nome;
  final String idDisplay; // Ex: INST0113 ou MAT001
  final String? categoria; // Ex: "Cabos"
  final String statusTag; // Ex: "Em Uso" ou "Devolvido"
  final bool isInstrumento;

  // Campos de Informação
  final String destino;
  final String finalidade;
  final DateTime dataRetirada;
  final DateTime previsaoDevolucao;
  final DateTime? dataDevolucaoReal; // NULL se estiver "Em Uso"

  _HistoricoItem({
    required this.idMovimentacao,
    required this.nome,
    required this.idDisplay,
    this.categoria,
    required this.statusTag,
    required this.isInstrumento,
    required this.destino,
    required this.finalidade,
    required this.dataRetirada,
    required this.previsaoDevolucao,
    this.dataDevolucaoReal,
  });

  // Se a devolução real for nula, o item está "Em Uso"
  bool get emUso => dataDevolucaoReal == null;
}

enum HistoricoTab { emUso, historico }

class HistoricoUso extends StatefulWidget {
  const HistoricoUso({Key? key}) : super(key: key);

  State<HistoricoUso> createState() => HistoricoUsoState();
}

class HistoricoUsoState extends State<HistoricoUso> {
  
  HistoricoTab _selectedTab = HistoricoTab.emUso;
  final TextEditingController _searchController = TextEditingController();

  // --- Controle da API ---
  late Future<void> _loadFuture;
  bool _isLoading = true;
  String? _error;
  List<_HistoricoItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadFuture = _fetchData();
  }

  // ================== LÓGICA DE DADOS (API) ==================

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Simulação de chamada de API
      await Future.delayed(const Duration(milliseconds: 700));

      // TODO: Implementar chamada de API real
      if (_selectedTab == HistoricoTab.emUso) {
        // API REAL: Chamar GET /movimentacoes/pendentes
        // Por agora, usamos mock
        _items = _getMockData(emUso: true);
      } else {
        // API REAL: Chamar GET /movimentacoes/historico_usuario
        // Por agora, usamos mock
        _items = _getMockData(emUso: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Falha ao carregar dados: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Recarrega os dados ao mudar de aba ou atualizar
  void _reloadData() {
    setState(() {
      _loadFuture = _fetchData();
    });
  }

  // Alterna a aba selecionada
  void _onToggleChanged(HistoricoTab tab) {
    if (_selectedTab != tab) {
      setState(() {
        _selectedTab = tab;
      });
      _reloadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023);
    const Color secondaryColor = Color.fromARGB(255, 0, 14, 92);

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: secondaryColor,
        elevation: 0,
        flexibleSpace: const AnimatedNetworkBackground(numberOfParticles: 30, maxDistance: 50.0),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Image.asset('assets/images/logo_metroSP.png', height: 50),
          ),
        ],
      ),
      drawer: const TecnicoDrawer(primaryColor: primaryColor, secondaryColor: secondaryColor),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Títulos
              const Text(
                'Histórico de Uso',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Histórico completo de retiradas e devoluções',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),

              // --- Barra de Toggle (IMPLEMENTADA) ---
              _buildToggleButtons(),
              const SizedBox(height: 24),

              // --- Conteúdo Principal (Lista) (IMPLEMENTADO) ---
              _buildBodyContent(),
            ],
          ),
        ),
      ),
    );
  }

  // Constrói os botões de toggle (Em Uso / Histórico)
  Widget _buildToggleButtons() {
    bool isEmUso = _selectedTab == HistoricoTab.emUso;
    bool isHistorico = _selectedTab == HistoricoTab.historico;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleItem("Em uso", isEmUso, () => _onToggleChanged(HistoricoTab.emUso)),
          _buildToggleItem("Histórico", isHistorico, () => _onToggleChanged(HistoricoTab.historico)),
        ],
      ),
    );
  }

  // Item individual do toggle
  Widget _buildToggleItem(String titulo, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              titulo,
              style: TextStyle(
                color: isSelected ? const Color(0xFF080023) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Constrói o corpo principal (Loading, Erro, ou Lista)
  Widget _buildBodyContent() {
    return FutureBuilder(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (_isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (_error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ),
          );
        }

        if (_items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 64.0),
              child: Column(
                children: [
                  Icon(Icons.search_off, color: Colors.white30, size: 48),
                  SizedBox(height: 16),
                  Text(
                    "Nenhum item encontrado",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        // Constrói a lista
        return ListView.separated(
          itemCount: _items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _HistoricoCard(
              item: _items[index],
              onDevolver: () {
                // TODO: Chamar o modal de devolução (Atividades.dart)
                // A lógica de devolução pode ser extraída para um service
                // ou o modal pode ser chamado aqui.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('TODO: Chamar devolução para ${ _items[index].idMovimentacao}')),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _HistoricoCard extends StatelessWidget {
  final _HistoricoItem item;
  final VoidCallback onDevolver;

  const _HistoricoCard({required this.item, required this.onDevolver});

  String _formatarData(DateTime data) {
    // Correção de fuso horário
    final localData = data.toLocal(); 
    return DateFormat('dd/MM/yyyy \'às\' HH:mm').format(localData);
  }

  @override
  Widget build(BuildContext context) {
    // Define a cor de fundo (clara) e a cor do texto (escura)
    // conforme a imagem (image_7728a3.png)
    const Color cardColor = Color(0xFFE0E0E0); // Cinza claro
    const Color textColor = Colors.black87;
    const Color titleColor = Colors.black;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Linha 1: Título e Tags ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone
              Icon(
                item.isInstrumento ? Icons.construction : Icons.inventory_2_outlined,
                color: item.isInstrumento ? Colors.green.shade700 : Colors.blue.shade700,
                size: 32,
              ),
              const SizedBox(width: 12),
              // Título e ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nome,
                      style: const TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      item.idDisplay,
                      style: const TextStyle(color: textColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Tags
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.categoria != null) ...[
                    _TagChip(
                      label: item.categoria!,
                      backgroundColor: Colors.black.withOpacity(0.1),
                      textColor: Colors.black54,
                    ),
                    const SizedBox(height: 4),
                  ],
                  _TagChip(
                    label: item.statusTag,
                    backgroundColor: item.emUso ? Colors.yellow.shade700.withOpacity(0.3) : Colors.green.withOpacity(0.2),
                    textColor: item.emUso ? Colors.yellow.shade900 : Colors.green.shade800,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // --- Linhas de Informação ---
          _InfoLinha(
            icon: Icons.location_on_outlined,
            title: "Destino:",
            value: item.destino,
          ),
          const SizedBox(height: 8),
          _InfoLinha(
            icon: Icons.schedule_outlined,
            title: "Previsão de devolução:",
            value: _formatarData(item.previsaoDevolucao),
            // Destaque se estiver atrasado (apenas se 'emUso')
            valueColor: (item.emUso && item.previsaoDevolucao.isBefore(DateTime.now()))
                ? Colors.red.shade700
                : null,
          ),
          const SizedBox(height: 8),
          _InfoLinha(
            icon: Icons.article_outlined,
            title: "Finalidade:",
            value: item.finalidade,
          ),
          const SizedBox(height: 8),
          _InfoLinha(
            icon: Icons.calendar_today_outlined,
            title: "Retirado em:",
            value: _formatarData(item.dataRetirada),
          ),
          // Mostra a data de devolução real se o item não estiver "Em Uso"
          if (!item.emUso && item.dataDevolucaoReal != null) ...[
            const SizedBox(height: 8),
            _InfoLinha(
              icon: Icons.check_circle_outline,
              title: "Devolvido em:",
              value: _formatarData(item.dataDevolucaoReal!),
              iconColor: Colors.green.shade700,
              valueColor: Colors.green.shade800,
            ),
          ],
          
          // --- Botão Devolver (Condicional) ---
          if (item.emUso) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onDevolver,
                icon: const Icon(Icons.arrow_downward, size: 16, color: Colors.white),
                label: Text(item.isInstrumento ? "Devolver Instrumento" : "Devolver Material"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }
}

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
    const Color defaultColor = Colors.black54; // Cor padrão escura
    
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
              color: valueColor ?? Colors.black87, // Valor padrão mais escuro
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================================
// ===== DADOS MOCKADOS (PARA PREPARAÇÃO) ===================
// ==========================================================
List<_HistoricoItem> _getMockData({required bool emUso}) {
  if (emUso) {
    return [
      _HistoricoItem(
        idMovimentacao: 'inst-113',
        nome: 'Osciloscópio Tektronix',
        idDisplay: 'INST0113',
        statusTag: 'Em Uso',
        isInstrumento: true,
        destino: 'Túnel Linha 3 - Km 8',
        finalidade: 'Inspeção de segurança em espaço confinado durante manutenção de ventilação',
        dataRetirada: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
        previsaoDevolucao: DateTime.now().subtract(const Duration(days: 1)), // Atrasado
      ),
      _HistoricoItem(
        idMovimentacao: 'mat-33',
        nome: 'Cabo Ethernet Cat6',
        idDisplay: 'MAT001',
        categoria: 'Cabos',
        statusTag: 'Em Uso',
        isInstrumento: false,
        destino: 'Túnel Linha 3 - Km 8',
        finalidade: 'Reparos de conexão da linha XYZ',
        dataRetirada: DateTime.now().subtract(const Duration(days: 1)),
        previsaoDevolucao: DateTime.now().add(const Duration(days: 1)), // No prazo
      ),
    ];
  } else {
    // Dados do Histórico (itens já devolvidos)
    return [
      _HistoricoItem(
        idMovimentacao: 'inst-105',
        nome: 'Analisador de Energia',
        idDisplay: 'INST0105',
        statusTag: 'Devolvido',
        isInstrumento: true,
        destino: 'Pátio Jabaquara - Manutenção',
        finalidade: 'Análise de consumo do Bloco C',
        dataRetirada: DateTime.now().subtract(const Duration(days: 10)),
        previsaoDevolucao: DateTime.now().subtract(const Duration(days: 8)),
        dataDevolucaoReal: DateTime.now().subtract(const Duration(days: 7)), // Data de devolução
      ),
      _HistoricoItem(
        idMovimentacao: 'mat-20',
        nome: 'Conector DB9 Macho',
        idDisplay: 'MAT002',
        categoria: 'Conectores',
        statusTag: 'Devolvido',
        isInstrumento: false,
        destino: 'Sala de Controle (CCO)',
        finalidade: 'Manutenção de console',
        dataRetirada: DateTime.now().subtract(const Duration(days: 5)),
        previsaoDevolucao: DateTime.now().subtract(const Duration(days: 4)),
        dataDevolucaoReal: DateTime.now().subtract(const Duration(days: 4)), // Data de devolução
      ),
    ];
  }
}