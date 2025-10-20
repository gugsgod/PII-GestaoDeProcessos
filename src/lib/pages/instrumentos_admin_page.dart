import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


// import 'package:http/retry.dart';
// import 'package:src/pages/home_admin.dart';
import 'package:src/widgets/admin/materiais_admin/filter_bar.dart';
// import 'dart:math';
import '../widgets/admin/home_admin/admin_drawer.dart';
// import '../widgets/admin/home_admin/dashboard_card.dart';
// import '../widgets/admin/home_admin/recent_movements.dart';
import '../widgets/admin/home_admin/update_status_bar.dart';
// import '../widgets/admin/home_admin/quick_actions.dart';
import 'animated_network_background.dart';

// Enum para o status do instrumento, facilita o controle
enum InstrumentStatus { ativo, inativo }

// Modelo de dados para representar um instrumento
class Instrument {
  final String codigo;
  final String nome;
  final InstrumentStatus status;
  final String baseAtual;
  final DateTime dataCalibracao;

  Instrument({
    required this.codigo,
    required this.nome,
    required this.status,
    required this.baseAtual,
    required this.dataCalibracao,
  });
}

class InstrumentosAdminPage extends StatefulWidget{
  const InstrumentosAdminPage({super.key});

  @override
  State<InstrumentosAdminPage> createState() => _InstrumentosAdminPageState();
}

class _InstrumentosAdminPageState extends State<InstrumentosAdminPage>{

  late DateTime _lastUpdated;
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = "Todas as Categorias";
  final TextEditingController _searchController = TextEditingController();

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

  final List<Instrument> _instruments = [
    // Adicionei uma data vencida para testar a tag "Vencido"
    Instrument(codigo: 'INSTR001', nome: 'Multímetro Digital Fluke', status: InstrumentStatus.ativo, baseAtual: 'BASE01', dataCalibracao: DateTime(2023, 1, 14)),
    Instrument(codigo: 'INSTR002', nome: 'Osciloscópio Tektronix', status: InstrumentStatus.ativo, baseAtual: 'BASE01', dataCalibracao: DateTime(2025, 1, 14)),
    Instrument(codigo: 'INSTR003', nome: 'Megôhmetro 5kV', status: InstrumentStatus.ativo, baseAtual: 'BASE01', dataCalibracao: DateTime(2025, 1, 14)),
    Instrument(codigo: 'INSTR004', nome: 'Detector de Gás Portátil', status: InstrumentStatus.ativo, baseAtual: 'BASE01', dataCalibracao: DateTime(2025, 1, 14)),
    Instrument(codigo: 'INSTR005', nome: 'Analisador de Energia', status: InstrumentStatus.inativo, baseAtual: 'BASE01', dataCalibracao: DateTime(2025, 1, 14)),
    Instrument(codigo: 'INSTR006', nome: 'Megôhmetro 10kV', status: InstrumentStatus.inativo, baseAtual: 'BASE01', dataCalibracao: DateTime(2024, 3, 20)),
    Instrument(codigo: 'INSTR007', nome: 'Multímetro Analógico Fluke', status: InstrumentStatus.ativo, baseAtual: 'BASE01', dataCalibracao: DateTime(2025, 1, 14)),
    Instrument(codigo: 'INSTR008', nome: 'Analisador de Termostática', status: InstrumentStatus.ativo, baseAtual: 'BASE01', dataCalibracao: DateTime(2025, 1, 14)),
  ];

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
        flexibleSpace: const AnimatedNetworkBackground(numberOfParticles: 35, maxDistance: 50.0),
        title: const Text('Instrumentos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Image.asset('assets/images/logo_metroSP.png', height: 50),
          ),
        ],
      ),

      // Chamada do widget para o Drawer
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

              // Cabeçalho da página
              const Text(
                "Gestão de Instrumentos",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                "Controle retiradas, devoluções e calibrações dos instrumentos",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 24),

              // Barra de Ações Rápidas
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Lógica para adicionar um novo instrumento
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Criar Novo Instrumento"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    )
                  )
                ],
              ),
              const SizedBox(height: 24),

              // Filtro de busca
              FilterBar(
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                selectedCategory: _selectedCategory,
                onCategoryChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Tabela de Dados
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(209, 255, 255, 255),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Cabeçalho da tabela
                    _buildTableHeader(),
                    // Linhas da tabela
                    const Divider (color: Color.fromARGB(59, 102, 102, 102), height: 1),
                    // Lista rolavel com os dados
                    ListView.separated(
                      controller: _scrollController,
                      // Estas duas linhas são importantes para a lista funcionar dentro de um SingleChildScrollView
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _instruments.length,
                      separatorBuilder: (context, index) => const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
                      itemBuilder: (context, index) {
                        return _buildMaterialRow(_instruments[index]);
                      },
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      )
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.black54);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Código', style: headerStyle)),
          Expanded(flex: 4, child: Text('Nome', style: headerStyle)),
          Expanded(flex: 3, child: Text('Status', style: headerStyle)),
          Expanded(flex: 3, child: Text('Base atual', style: headerStyle)),
          Expanded(flex: 2, child: Text('Venc. Calibração', style: headerStyle)),
          // Apenas a coluna de Ações continua centralizada
          SizedBox(width: 56, child: Center(child: Text('Ações', style: headerStyle))),
        ],
      ),
    );
  }

   Widget _buildMaterialRow(Instrument item) {
    const cellStyle = TextStyle(color: Colors.black87);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item.codigo, style: cellStyle)),
          Expanded(flex: 4, child: Text(item.nome, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: _StatusChip(status: item.status)),
          Expanded(flex: 3, child: Text(item.baseAtual, style: cellStyle)),
          Expanded(flex: 2, child: _CalibrationCell(date: item.dataCalibracao)),
          // coluna de ações centralizada
          SizedBox(width: 56, child: Center(child: IconButton(icon: const Icon(Icons.more_horiz, color: Colors.black54), onPressed: () {}))),
        ],
      ),
    );
  }
}

// Widget para o chip de status (Ativo/Inativo)
class _StatusChip extends StatelessWidget {
  final InstrumentStatus status;
  const _StatusChip({required this.status});
  
  @override
  Widget build(BuildContext context) {
    final bool isAtivo = status == InstrumentStatus.ativo;
    // Usando as cores do seu design original para os chips de status
    final backgroundColor = isAtivo ? Colors.green.shade100 : Colors.red.shade100;
    final textColor = isAtivo ? Colors.green.shade800 : Colors.red.shade800;
    final text = isAtivo ? 'Ativo' : 'Inativo';
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// Widget para a célula de data de calibração
class _CalibrationCell extends StatelessWidget {
  final DateTime date;
  const _CalibrationCell({required this.date});

  @override
  Widget build(BuildContext context) {
    final bool isExpired = date.isBefore(DateTime.now());
    
    return Row(
      children: [
        // Usando o estilo de célula original
        Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(color: Colors.black87)),
        if (isExpired) ...[
          const SizedBox(width: 8),
          const _ExpirationTag(),
        ]
      ],
    );
  }
}

// Widget para a tag "Vencido"
class _ExpirationTag extends StatelessWidget {
  const _ExpirationTag();

  @override
  Widget build(BuildContext context) {
    final Color color = Colors.red.shade800;
    final Color backgroundColor = Colors.red.shade100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Vencido',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}

