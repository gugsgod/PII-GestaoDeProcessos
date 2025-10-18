import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/admin/home_admin/admin_drawer.dart';
import 'animated_network_background.dart';
import '../widgets/admin/home_admin/update_status_bar.dart';
import '../widgets/admin/materiais_admin/filter_bar.dart';

class MaterialItem {
  final String codigo;
  final String nome;
  final String categoria;
  final int estoqueMinimo;
  final String status;

  MaterialItem({
    required this.codigo,
    required this.nome,
    required this.categoria,
    required this.estoqueMinimo,
    required this.status,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      codigo: json['codigo'] ?? 'N/A',
      nome: json['nome'] ?? 'Sem nome',
      categoria: json['categoria'] ?? 'Sem categoria',
      estoqueMinimo: json['estoqueMinimo'] ?? 0,
      status: json['status'] ?? 'Inativo',
    );
  }
}



class MateriaisAdminPage extends StatefulWidget {
  MateriaisAdminPage({super.key});

  @override
  State<MateriaisAdminPage> createState() => _MateriaisAdminPageState();
}

class _MateriaisAdminPageState extends State<MateriaisAdminPage> {
  // Estado da página
  late DateTime _lastUpdated;
  String _selectedCategory = 'Todas as Categorias';
  final ScrollController _scrollController = ScrollController();

  // Estados para controlar o carregamento e erros da API
  bool _isLoading = true;
  String? _erroMessage;
  List<MaterialItem> _materiais = [];


  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    _featchMateriais();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _atualizarDados() {
    setState(() {
      _lastUpdated = DateTime.now();
      // vai carregar aq os dados da API
    });
  }

  // Função para buscar os dados no backend
  Future<void> _featchMateriais() async {
    setState(() {
      _isLoading = true;
      _erroMessage = null;
    });

    const String apiUrl = "";

    try {
      final response = await http.get(Uri.parse(apiUrl));
    }

  }

  // final List<MaterialItem> _materiais = [
  //   MaterialItem(codigo: 'MAT001', nome: 'Cabo Ethernet Cat6', categoria: 'Cabos', estoqueMinimo: 100, status: 'Ativo'),
  //   MaterialItem(codigo: 'MAT001', nome: 'Relé de Proteção 24V', categoria: 'Relés', estoqueMinimo: 100, status: 'Ativo'),
  //   MaterialItem(codigo: 'MAT001', nome: 'Conector DB9 Macho', categoria: 'Conectores', estoqueMinimo: 100, status: 'Ativo'),
  //   MaterialItem(codigo: 'MAT001', nome: 'Luva de Segurança Isolante', categoria: 'EPIs', estoqueMinimo: 100, status: 'Ativo'),
  //   MaterialItem(codigo: 'MAT001', nome: 'Chave Philips 1/4', categoria: 'Ferramentas', estoqueMinimo: 100, status: 'Ativo'),
  //   MaterialItem(codigo: 'MAT001', nome: 'Fusível 10A', categoria: 'Peças', estoqueMinimo: 100, status: 'Inativo'),
  //   MaterialItem(codigo: 'MAT001', nome: 'Capacete de Segurança', categoria: 'EPIs', estoqueMinimo: 100, status: 'Ativo'),
  //   MaterialItem(codigo: 'MAT001', nome: 'Óculos de Segurança', categoria: 'EPIs', estoqueMinimo: 100, status: 'Ativo'),
  // ];

  

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
        title: const Text('Materiais', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              UpdateStatusBar(
                isDesktop: isDesktop,
                lastUpdated: _lastUpdated,
                onUpdate: _atualizarDados,
              ),
              const SizedBox(height: 24),

              // Cabeçalho da página
              const Text('Gestão de Materiais', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Cadastre, edite e controle os materiais de consumo e giro', style: TextStyle(color: Colors.white70, fontSize: 16)),
              
              const SizedBox(height: 24),

              // Barra de Ações (Exportar, Criar Novo)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.upload_file, color: Colors.white70),
                    label: const Text('Exportar', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Criar Novo Material'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              FilterBar(
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
                    // Cabeçalho da Tabela
                    _buildTableHeader(),
                    // Linha divisória
                    const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
                    // Lista rolável com altura fixa
                    SizedBox(
                      height: 500,
                      child: ScrollbarTheme(
                        data: ScrollbarThemeData(
                          thumbColor: WidgetStateProperty.all(Color.fromARGB(255, 44, 44, 44)),
                          mainAxisMargin: 8.0,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            interactive: true,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: EdgeInsets.zero,
                              itemCount: _materiais.length,
                              separatorBuilder: (context, index) => const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1, indent: 16, endIndent: 16),
                              itemBuilder: (context, index) {
                                return _buildMaterialRow(_materiais[index]);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Cabeçalho da Tabela
  Widget _buildTableHeader() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.black54);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Código', style: headerStyle)),
          Expanded(flex: 4, child: Text('Nome', style: headerStyle)),
          Expanded(flex: 3, child: Text('Categoria', style: headerStyle)),
          Expanded(flex: 3, child: Text('Estoque Mínimo', style: headerStyle)),
          Expanded(flex: 2, child: Text('Status', style: headerStyle)),
          // Apenas a coluna de Ações continua centralizada
          SizedBox(width: 56, child: Center(child: Text('Ações', style: headerStyle))),
        ],
      ),
    );
  }

  Widget _buildMaterialRow(MaterialItem item) {
    const cellStyle = TextStyle(color: Colors.black87);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item.codigo, style: cellStyle)),
          Expanded(flex: 4, child: Text(item.nome, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: _buildChip(item.categoria, Colors.grey.shade300, Colors.black54)),
          Expanded(flex: 3, child: Text(item.estoqueMinimo.toString(), style: cellStyle)),
          Expanded(flex: 2, child: _buildStatusChip(item.status)),
          // coluna de ações centralizada
          SizedBox(width: 56, child: Center(child: IconButton(icon: const Icon(Icons.more_horiz, color: Colors.black54), onPressed: () {}))),
        ],
      ),
    );
  }
  
  Widget _buildChip(String label, Color color, Color textColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final bool isAtivo = status == 'Ativo';
    final backgroundColor = isAtivo ? Colors.green.shade100 : Colors.red.shade100;
    final textColor = isAtivo ? Colors.green.shade800 : Colors.red.shade800;
    
    return _buildChip(status, backgroundColor, textColor);
  }
}