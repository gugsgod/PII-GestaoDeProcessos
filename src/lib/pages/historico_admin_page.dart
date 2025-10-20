import 'package:flutter/material.dart';
import 'package:src/widgets/admin/home_admin/update_status_bar.dart';
import '../widgets/admin/home_admin/admin_drawer.dart';
import 'animated_network_background.dart';
import 'package:intl/intl.dart';

class AlertItem {
  final String titulo;
  final String subtitulo;
  final String codigo;
  final DateTime data;
  final IconData icon;
  final Color iconColor;

  AlertItem({
    required this.titulo,
    required this.subtitulo,
    required this.codigo,
    required this.data,
    this.icon = Icons.warning_amber_rounded,
    this.iconColor = const Color(0xFF6466F1),
  });
}

class HistoricoAdminPage extends StatefulWidget {
  const HistoricoAdminPage({Key? key}) : super(key: key);

  @override
  _HistoricoAdminPageState createState() => _HistoricoAdminPageState();
}



class _HistoricoAdminPageState extends State<HistoricoAdminPage> {

  late DateTime _lastUpdated;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final List<AlertItem> _alerts = [
    AlertItem(titulo: 'Calibração Vencida', subtitulo: 'Detector de Gás Portátil', codigo: 'INSTR001', data: DateTime(2025, 1, 14)),
    AlertItem(titulo: 'Calibração Vencida', subtitulo: 'Multímetro Digital Fluke', codigo: 'INSTR001', data: DateTime(2025, 1, 14)),
    AlertItem(titulo: 'Calibração Vencida', subtitulo: 'Detector de Gás Portátil', codigo: 'INSTR001', data: DateTime(2025, 1, 14)),
    AlertItem(titulo: 'Calibração Vencida', subtitulo: 'Multímetro Digital Fluke', codigo: 'INSTR001', data: DateTime(2025, 1, 14)),
    AlertItem(titulo: 'Calibração Vencida', subtitulo: 'Megôhmetro 5kV', codigo: 'INSTR001', data: DateTime(2025, 1, 14)),
    AlertItem(titulo: 'Calibração Vencida', subtitulo: 'Detector de Gás Portátil', codigo: 'INSTR001', data: DateTime(2025, 1, 14)),
    AlertItem(titulo: 'Calibração Vencida', subtitulo: 'Multímetro Digital Fluke', codigo: 'INSTR001', data: DateTime(2025, 1, 14)),
    AlertItem(titulo: 'Estoque Baixo', subtitulo: 'Conector DB9 Macho', codigo: 'MAT003', data: DateTime(2025, 1, 14), icon: Icons.inventory_2_outlined, iconColor: Colors.orange.shade700),
  ];

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _atualizarDados() {
    setState(() {
      _lastUpdated = DateTime.now();
      // Aqui você pode adicionar a lógica para atualizar os dados reais
    });
  }

  void _onSearchChanged(String query) {
    print("Buscando por: $query");
  }

  @override
  Widget build(BuildContext context) {

    const Color primaryColor = Color(0xFF080023); //cor de fundo
    const Color secondaryColor = Color.fromARGB( 255, 0, 14, 92,); //cor do app bar
    final isDesktop = MediaQuery.of(context).size.width > 768; // define se a tela é grande o suficiente p duas colunas

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: secondaryColor,
        elevation: 0,
        flexibleSpace: const AnimatedNetworkBackground(numberOfParticles: 35, maxDistance: 50),
        title: const Text("Histórico de Alertas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Image.asset('assets/images/logo_metroSP.png', height: 50),
          )
        ],
      ),

      // Chamada do wigdet para o Drawer
      drawer: AdminDrawer(
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chamada do widget para a barra de status
              UpdateStatusBar(
                isDesktop: isDesktop,
                lastUpdated: _lastUpdated,
                onUpdate: _atualizarDados,
              ),
              const SizedBox(height: 48),

              // Cabeçalho da seção de histórico
              const Text(
                "Histórico de Alertas",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                "Visão geral das notificações do sistema",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 24),

              // Tabela de histórico de alertas
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color.fromARGB(209, 255, 255, 255),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Implemente a tabela de histórico aqui
                    _buildAlertsTable(),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- Widgets da Tabela de Histórico ------------------ //
  Widget _buildAlertsTable() {
    return Column(
      children: [
        _buildTableHeader(),
        const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
        SizedBox(
          height: 600, // Altura fixa para a lista rolável
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount: _alerts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildAlertRow(_alerts[index]);
            },
          ),
        ),
      ],
    );
  }

  /// Constrói o cabeçalho da tabela.
  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Todos os Alertas',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 18,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _alerts.length.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói uma única linha da tabela de alertas.
  Widget _buildAlertRow(AlertItem item) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(item.icon, color: item.iconColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      item.subtitulo,
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    _AlertTag(code: item.codigo),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            DateFormat('dd/MM/yyyy').format(item.data),
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Widget para a tag cinza com o código do item.
class _AlertTag extends StatelessWidget {
  final String code;
  const _AlertTag({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

}