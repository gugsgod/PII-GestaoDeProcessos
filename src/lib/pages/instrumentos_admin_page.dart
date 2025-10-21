import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

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
  final String id;
  final String patrimonio;
  final String descricao;
  final String categoria;
  final InstrumentStatus status;
  final String localAtual; // Armazenará o ID como String
  final String responsavelAtual; // Armazenará o ID como String
  final DateTime proximaCalibracaoEm;
  final bool ativo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Instrument({
    required this.id,
    required this.patrimonio,
    required this.descricao,
    required this.categoria,
    required this.status,
    required this.localAtual,
    required this.responsavelAtual,
    required this.proximaCalibracaoEm,
    required this.ativo,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor AJUSTADO para corresponder ao backend real.
  factory Instrument.fromMap(Map<String, dynamic> map) {
    // Helper para converter datas de forma segura
    DateTime _parseDate(dynamic dateString, {required DateTime fallback}) {
      if (dateString is String) {
        return DateTime.tryParse(dateString) ?? fallback;
      }
      return fallback;
    }

    return Instrument(
      id: map['id']?.toString() ?? 'N/A',
      patrimonio: map['patrimonio']?.toString() ?? 'N/A',
      descricao: map['descricao']?.toString() ?? 'N/A',
      categoria: map['categoria']?.toString() ?? 'N/A',
      status: (map['status']?.toString() ?? 'inativo') == 'ativo'
          ? InstrumentStatus.ativo
          : InstrumentStatus.inativo,
      // CORREÇÃO: Lendo os campos _id e convertendo para String para exibição.
      localAtual: map['local_atual_id']?.toString() ?? 'N/A',
      responsavelAtual: map['responsavel_atual_id']?.toString() ?? 'N/A',
      proximaCalibracaoEm: _parseDate(map['proxima_calibracao_em'], fallback: DateTime.now()),
      ativo: map['ativo'] as bool? ?? false,
      createdAt: _parseDate(map['created_at'], fallback: DateTime.now()),
      updatedAt: _parseDate(map['updated_at'], fallback: DateTime.now()),
    );
  }
}

class InstrumentosAdminPage extends StatefulWidget {
  const InstrumentosAdminPage({super.key});

  @override
  State<InstrumentosAdminPage> createState() => _InstrumentosAdminPageState();
}

class _InstrumentosAdminPageState extends State<InstrumentosAdminPage> {
  late DateTime _lastUpdated;
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = "Todas as Categorias";
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<Instrument> _instruments = [];

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    fetchInstruments();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchInstruments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    const String baseUrl = "http://localhost:8080";
    final queryParams = <String, String>{};
    final searchQuery = _searchController.text.trim();

    if (searchQuery.isNotEmpty) {
      queryParams["q"] = searchQuery;
    }
    if (_selectedCategory != "Todas as Categorias") {
      queryParams["categoria"] = _selectedCategory;
    }

    final uri = Uri.parse("$baseUrl/instrumentos").replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    try {
      final response = await http.get(uri, headers: {"Accept": "application/json"});

      if (response.statusCode == 200) {
        // O backend retorna uma lista diretamente, não um objeto com 'data'.
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _instruments = data.map((json) => Instrument.fromMap(json as Map<String, dynamic>)).toList();
        });
      } else {
        // Tentativa de decodificar uma mensagem de erro do corpo da resposta
        String errorMsg = "Código de erro: ${response.statusCode}";
        try {
          final errorBody = json.decode(utf8.decode(response.bodyBytes));
          errorMsg = errorBody['error'] ?? errorBody['message'] ?? errorMsg;
        } catch (_) {
          // Mantém a mensagem de erro original se o corpo não for JSON
        }
        throw Exception("Falha ao carregar instrumentos: $errorMsg");
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erro: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });
    }
  }

  void _onSearchChanged(String query) {
    fetchInstruments();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023);
    const Color secondaryColor = Color.fromARGB(255, 0, 14, 92);
    final isDesktop = MediaQuery.of(context).size.width > 768;

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
      drawer: AdminDrawer(primaryColor: primaryColor, secondaryColor: secondaryColor),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UpdateStatusBar(isDesktop: isDesktop, lastUpdated: _lastUpdated, onUpdate: fetchInstruments),
              const SizedBox(height: 48),
              const Text("Gestão de Instrumentos", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Controle retiradas, devoluções e calibrações dos instrumentos", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Criar Novo Instrumento"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilterBar(
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                selectedCategory: _selectedCategory,
                onCategoryChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                    fetchInstruments();
                  });
                },
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: _buildDataTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))));
    }
    if (_instruments.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('Nenhum instrumento encontrado.')));
    }
    return Column(
      children: [
        _buildTableHeader(),
        const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
        ListView.separated(
          controller: _scrollController,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _instruments.length,
          separatorBuilder: (context, index) => const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
          itemBuilder: (context, index) => _buildMaterialRow(_instruments[index]),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.black54);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('ID', style: headerStyle)),
          Expanded(flex: 3, child: Text('Patrimônio', style: headerStyle)),
          Expanded(flex: 2, child: Text('Status', style: headerStyle)),
          Expanded(flex: 2, child: Text('ID Local', style: headerStyle)),
          Expanded(flex: 2, child: Text('ID Resp.', style: headerStyle)),
          Expanded(flex: 3, child: Text('Venc. Calibração', style: headerStyle)),
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
          Expanded(flex: 2, child: Text(item.id, style: cellStyle, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Text(item.patrimonio, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: _StatusChip(status: item.status)),
          Expanded(flex: 2, child: Text(item.localAtual, style: cellStyle)),
          Expanded(flex: 2, child: Text(item.responsavelAtual, style: cellStyle)),
          Expanded(flex: 3, child: _CalibrationCell(date: item.proximaCalibracaoEm)),
          SizedBox(
            width: 56,
            child: Center(child: IconButton(icon: const Icon(Icons.more_horiz, color: Colors.black54), onPressed: () {})),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final InstrumentStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool isAtivo = status == InstrumentStatus.ativo;
    final backgroundColor = isAtivo ? Colors.green.shade100 : Colors.red.shade100;
    final textColor = isAtivo ? Colors.green.shade800 : Colors.red.shade800;
    final text = isAtivo ? 'Ativo' : 'Inativo';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _CalibrationCell extends StatelessWidget {
  final DateTime date;
  const _CalibrationCell({required this.date});

  @override
  Widget build(BuildContext context) {
    final bool isExpired = date.isBefore(DateTime.now());
    return Row(
      children: [
        Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(color: Colors.black87)),
        if (isExpired) ...[const SizedBox(width: 8), const _ExpirationTag()],
      ],
    );
  }
}

class _ExpirationTag extends StatelessWidget {
  const _ExpirationTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
      child: Text('Vencido', style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}

